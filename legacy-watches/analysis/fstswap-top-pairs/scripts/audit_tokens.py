#!/usr/bin/env python3
"""
audit_tokens.py — local analysis helper (READ-ONLY) for fstswap-top-pairs.
For each token: Etherscan V2 verified source/ABI (chainid=56), on-chain name/symbol/decimals/
totalSupply/owner, bytecode selector scan (mint/burn/blacklist), and eth_call mint probes
from an unprivileged address (success => publicly callable).

Usage: python3 audit_tokens.py TOKENS.json OUT.json [--rpc URL]
TOKENS.json: {"label": "0xaddr", ...}
Secrets: reads ETHERSCANV2_API_KEY from env (source /home/heisenberg/CA/.env outside); never logs it.
"""
import json, os, sys, time, urllib.request, urllib.parse

RPC = os.environ.get("BSC_RPC", "https://bsc.publicnode.com")
MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"

def post(url, payload, timeout=45):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "h2-09-recon/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

RPCS = [os.environ.get("BSC_RPC"), "https://bsc.publicnode.com", "https://bsc-dataseed.binance.org"]
RPCS = [u for u in RPCS if u and u.startswith("http")]
_good = [None]

def rpc(method, params):
    order = ([_good[0]] if _good[0] else []) + [u for u in RPCS if u != _good[0]]
    last = None
    for url in order:
        try:
            d = post(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
            if "error" in d: raise RuntimeError(d["error"])
            _good[0] = url
            return d.get("result")
        except Exception as e:
            last = e
            time.sleep(0.5)
    raise RuntimeError(f"rpc failed: {last}")

def call(to, data, frm=None, block="latest"):
    o = {"to": to, "data": data}
    if frm: o["from"] = frm
    time.sleep(0.25)  # pace to avoid public-RPC throttling
    return rpc("eth_call", [o, block])

def pad(v): return f"{v:064x}"
def dec_u(res):
    if not isinstance(res, str) or res in ("0x", ""): return None
    h = res[2:] if res.startswith("0x") else res
    return int(h, 16) if 0 < len(h) <= 66 else None
def dec_addr(res):
    if not isinstance(res, str): return None
    h = res[2:] if res.startswith("0x") else res
    return "0x" + h[-40:] if len(h) == 64 else None
def dec_str(res):
    if not isinstance(res, str) or res in ("0x", ""): return None
    try:
        raw = bytes.fromhex(res[2:] if res.startswith("0x") else res)
        if len(raw) >= 64:
            off = int.from_bytes(raw[:32], "big"); ln = int.from_bytes(raw[off:off+32], "big")
            return raw[off+32:off+32+ln].decode("utf-8", "replace")
        return raw.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return None

SEL = {"name": "0x06fdde03", "symbol": "0x95d89b41", "decimals": "0x313ce567",
       "totalSupply": "0x18160ddd", "owner": "0x8da5cb5b", "getOwner": "0x893d20e8"}

# selector -> (name, arg template builder)
MINT_SIGS = {
    "40c10f19": ("mint(address,uint256)", lambda a: pad(int(a, 16)) + pad(10**18)),
    "a0712d68": ("mint(uint256)", lambda a: pad(10**18)),
    "449a52f8": ("mintTo(address,uint256)", lambda a: pad(int(a, 16)) + pad(10**18)),
    "94bf804d": ("mint(uint256,address)", lambda a: pad(10**18) + pad(int(a, 16))),
    "2b4710d2": ("mint(address,uint256,bytes)", lambda a: pad(int(a, 16)) + pad(10**18) + pad(0x60) + pad(0)),
}
BLACK_SIGS = {"44337ea1": "addBlackList(address)", "0ecb93c0": "addBlackList(address)",
              "e49954d4": "setBlackList(address,bool)", "f9f92be4": "blacklist(address)",
              "8b7a5f8e": "addBotToBlackList(address)", "15365109": "blacklist(address)"}
FEE_SIGS = {"c49b9b53": "setTaxFeePercent(uint256)", "5c85974f": "setFees(uint256,uint256)",
            "f2fde38b": "transferOwnership(address)"}

def scan_selectors(code_hex):
    h = code_hex[2:] if code_hex.startswith("0x") else code_hex
    found = {}
    for sig, name in {**MINT_SIGS, **BLACK_SIGS, **FEE_SIGS}.items():
        if sig in h:
            found[sig] = name
    return found

def scan_strings(code_hex):
    h = code_hex[2:] if code_hex.startswith("0x") else code_hex
    raw = bytes.fromhex(h)
    import re
    strs = set()
    for m in re.finditer(rb"[ -~]{5,64}", raw):
        s = m.group().decode()
        if any(k in s.lower() for k in ("tax", "fee", "black", "bot", "max", "limit", "trading", "paus", "mint", "owner")):
            strs.add(s)
    return sorted(strs)[:40]

def etherscan_source(key, addr):
    q = {"chainid": "56", "module": "contract", "action": "getsourcecode", "address": addr, "apikey": key}
    url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(q)
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "h2-09-recon/1.0"}), timeout=45) as r:
        return json.loads(r.read())

def main():
    tokens = json.load(open(sys.argv[1]))
    out_path = sys.argv[2]
    rpc_override = None
    if "--rpc" in sys.argv:
        rpc_override = sys.argv[sys.argv.index("--rpc") + 1]
    global RPC
    if rpc_override: RPC = rpc_override
    key = os.environ.get("ETHERSCANV2_API_KEY")
    blk = int(rpc("eth_blockNumber", []), 16)
    results = {}
    probe_from = "0x00000000000000000000000000000000DeadBeef"
    for label, addr in tokens.items():
        addr = addr.lower()
        r = {"address": addr, "block": blk}
        try:
            r["code_size"] = (len(rpc("eth_getCode", [addr, hex(blk)])) - 2) // 2
        except Exception as e:
            r["code_size"] = None; r["code_err"] = str(e)
        for f, sig in SEL.items():
            try:
                res = call(addr, sig, block=hex(blk))
                r[f] = dec_str(res) if f in ("name", "symbol") else (dec_u(res) if f in ("decimals", "totalSupply") else dec_addr(res))
            except Exception:
                pass
        # mint probes
        r["mint_probes"] = {}
        try:
            code = rpc("eth_getCode", [addr, hex(blk)])
            r["selectors_in_bytecode"] = scan_selectors(code)
            r["strings_sample"] = scan_strings(code)
            for sig in list(MINT_SIGS):
                if sig in code[2:]:
                    name, build = MINT_SIGS[sig]
                    try:
                        res = call(addr, "0x" + sig + build(probe_from), frm=probe_from, block=hex(blk))
                        r["mint_probes"][name] = {"result": "SUCCESS", "ret": (res or "")[:80]}
                    except Exception as e:
                        msg = str(e)[:200]
                        r["mint_probes"][name] = {"result": "revert/err", "err": msg}
        except Exception as e:
            r["selector_scan_err"] = str(e)
        # owner code
        owner = r.get("owner") or r.get("getOwner")
        if owner:
            try:
                oc = rpc("eth_getCode", [owner, hex(blk)])
                r["owner_is_contract"] = oc not in ("0x", "0x0")
                r["owner_code_size"] = (len(oc) - 2) // 2
            except Exception as e:
                r["owner_code_err"] = str(e)
        # verified source
        if key:
            try:
                d = etherscan_source(key, addr)
                res = (d.get("result") or [{}])[0]
                src = res.get("SourceCode") or ""
                abi = res.get("ABI") or ""
                r["verified"] = bool(src)
                r["contract_name"] = res.get("ContractName")
                r["compiler"] = res.get("CompilerVersion")
                r["proxy"] = res.get("Proxy")
                r["source_len"] = len(src)
                if src:
                    open(out_path + f".{label}.source.json", "w").write(json.dumps(
                        {"address": addr, "ContractName": res.get("ContractName"), "SourceCode": src, "ABI": abi}, indent=1))
                    try:
                        abi_j = json.loads(abi)
                        r["abi_fns"] = sorted({x.get("name") for x in abi_j if x.get("type") == "function"})
                    except Exception:
                        pass
                time.sleep(0.3)
            except Exception as e:
                r["etherscan_err"] = str(e)[:200]
        results[label] = r
        print(f"[{label}] {addr} verified={r.get('verified')} owner={owner} mint_probes={r.get('mint_probes')}", flush=True)
    json.dump({"block": blk, "tokens": results}, open(out_path, "w"), indent=1)
    print("wrote", out_path, flush=True)

if __name__ == "__main__":
    main()

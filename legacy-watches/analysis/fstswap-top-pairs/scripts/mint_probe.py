#!/usr/bin/env python3
"""
mint_probe.py — READ-ONLY deployed-bytecode audit for fstswap-top-pairs.
For each token: fetch deployed code (paced, RPC fallback), scan for mint/burn/blacklist/fee
selectors, and eth_call every mint selector found FROM an unprivileged address.
SUCCESS (no revert) => publicly callable mint => extraction path.
Usage: python3 mint_probe.py TOKENS.json OUT.json
"""
import json, os, sys, time, urllib.request

RPCS = [os.environ.get("BSC_RPC"), "https://bsc.publicnode.com", "https://bsc-dataseed.binance.org"]
RPCS = [u for u in RPCS if u and u.startswith("http")]
_good = [None]

def post(url, payload, timeout=45):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "h2-09-recon/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

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

def pad(v): return f"{v:064x}"
ATT = "0x000000000000000000000000000000000000bEEf"

MINT = {
    "40c10f19": ("mint(address,uint256)", lambda: pad(int(ATT, 16)) + pad(10 ** 18)),
    "a0712d68": ("mint(uint256)", lambda: pad(10 ** 18)),
    "449a52f8": ("mintTo(address,uint256)", lambda: pad(int(ATT, 16)) + pad(10 ** 18)),
    "94bf804d": ("mint(uint256,address)", lambda: pad(10 ** 18) + pad(int(ATT, 16))),
    "6a627842": ("mint(address)", lambda: pad(int(ATT, 16))),
    "2b4710d2": ("mint(address,uint256,bytes)", lambda: pad(int(ATT, 16)) + pad(10 ** 18) + pad(0x60) + pad(0)),
    "1249c58b": ("mint()", lambda: ""),
}
BLACK = {"44337ea1": "addBlackList(address)", "0ecb93c0": "addBlackList(address)",
         "e49954d4": "setBlackList(address,bool)", "f9f92be4": "blacklist(address)"}
FEECFG = {"c49b9b53": "setTaxFeePercent(uint256)", "3f24c8b8": "setFees(uint256,uint256)"}

def main():
    tokens = json.load(open(sys.argv[1])); out_path = sys.argv[2]
    out = {"attacker": ATT, "results": {}}
    EIP1167 = "363d3d373d3d3d363d73"
    EIP1967_IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    for label, addr in tokens.items():
        addr = addr.lower(); r = {"address": addr}
        try:
            time.sleep(0.3)
            code = rpc("eth_getCode", [addr, "latest"])
            r["code_size"] = (len(code) - 2) // 2 if code else 0
            impl = None
            h = code[2:] if code else ""
            if EIP1167 in h:
                i = h.find(EIP1167); impl = "0x" + h[i + 20:i + 60]
                r["proxy_type"] = "eip1167"
            else:
                try:
                    time.sleep(0.2)
                    slot = rpc("eth_getStorageAt", [addr, EIP1967_IMPL, "latest"])
                    if slot and int(slot, 16) != 0:
                        impl = "0x" + slot[-40:]; r["proxy_type"] = "eip1967"
                except Exception:
                    pass
            if impl:
                time.sleep(0.3)
                icode = rpc("eth_getCode", [impl, "latest"])
                r["impl"] = impl; r["impl_size"] = (len(icode) - 2) // 2 if icode else 0
                scan_code = icode
            else:
                scan_code = code
            h2 = (scan_code or "")[2:]
            r["mint_selectors"] = {s: n for s, n in {k: v[0] for k, v in MINT.items()}.items() if s in h2}
            r["blacklist_selectors"] = {s: n for s, n in BLACK.items() if s in h2}
            r["fee_selectors"] = {s: n for s, n in FEECFG.items() if s in h2}
            # unconditional probe of ALL mint selectors against the token (through proxy delegatecall if proxied)
            probes = {}
            for s, (name, build) in MINT.items():
                try:
                    time.sleep(0.3)
                    res = rpc("eth_call", [{"from": ATT, "to": addr, "data": "0x" + s + build()}, "latest"])
                    probes[name] = {"result": "SUCCESS", "ret": (res or "")[:66]}
                except Exception as e:
                    probes[name] = {"result": "revert", "err": str(e)[:90]}
            r["mint_probes"] = probes
        except Exception as e:
            r["err"] = str(e)[:200]
        out["results"][label] = r
        any_success = [k for k, v in (r.get("mint_probes") or {}).items() if v.get("result") == "SUCCESS"]
        print(f"[{label}] {addr} size={r.get('code_size')} impl={r.get('impl')} "
              f"mint_sels={list((r.get('mint_selectors') or {}).values())} "
              f"probe_SUCCESS={any_success}", flush=True)
    json.dump(out, open(out_path, "w"), indent=1)
    print("wrote", out_path)

if __name__ == "__main__":
    main()

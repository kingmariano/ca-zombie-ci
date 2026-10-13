#!/usr/bin/env python3
"""QC-5 independent fingerprint of all known + suspected Nerve pools (BSC).
Read-only. No secrets printed."""
import json, urllib.request, os, hashlib

def pick_rpc():
    cands = []
    if os.environ.get("QC_RPC"): cands.append(os.environ["QC_RPC"])
    if os.environ.get("ANKR_API_KEY"): cands.append(f"https://rpc.ankr.com/bsc/{os.environ['ANKR_API_KEY']}")
    cands.append("https://bsc-rpc.publicnode.com")
    for u in cands:
        try:
            r = rpc_raw(u, "eth_blockNumber", [])
            if r.get("result"): return u
        except Exception:
            continue
    raise SystemExit("no working RPC")

def rpc_raw(url, m, p):
    req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),
                                 headers={"Content-Type":"application/json"})
    return json.load(urllib.request.urlopen(req, timeout=45))

RPC = pick_rpc()

def rpc(m, p):
    r = rpc_raw(RPC, m, p)
    return r.get("result")

def u256(x): return hex(int(x))[2:].rjust(64, "0")
def padaddr(a): return a.lower().replace("0x","").rjust(64,"0")

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def call_int(to, data):
    r = call(to, data)
    try: return int(r, 16) if r and r != "0x" else None
    except Exception: return None

def get_code(addr, blk="latest"):
    return rpc("eth_getCode", [addr, blk])

EIP1967_IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
EIP1967_ADMIN = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"

SEL = {
    "owner()": "0x8da5cb5b",
    "paused()": "0x5c975abb",
    "admin()": "0xf851a440",
    "getVirtualPrice()": "0xe25aa5fa",
    "metaSwapStorage()": "0x2d74d4e9",
}

def readaddr(word):
    if word is None or not isinstance(word, str) or len(word) < 66: return None
    a = "0x" + word[2:][24:64]
    return None if int(a,16) == 0 else a

P3  = "0x1B3771a66ee31180906972580adE9b81AFc5fCDc"
BTC = "0x6C341938bB75dDe823FAAfe7f446925c66E6270c"
ETH = "0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0"
USTM = "0x2dcCe1586b1664f41C72206900e404Ec3cA130e0"
FUSM = "0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3"
NRVM = "0x96b849a73db2cc769b4Abe770aAb141aAC9014d6"
EXTRA = [
 "0x97B9054122eF8888590934F0eC8E10580232E85d",
 "0xC80Cc653392f4734201331E39a66aA8a483D29BD",
 "0xCa9d9C7800b7d1D3A1988A7d93927424a1BBEA7f",
 "0xb1669A60a7Db67AA84e5fAF2AE3123AA99237459",
 "0xF100326c19996eaf2d8E93A503725F643e36099C",
 "0x0144E7d25644C7ca6038F4AFBfcD3b1A119Ab3cE",
 "0xbC7477e46A95758dE5012744f7A350A4E0d03484",
 "0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114",
]
FARM = "0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E"

def fp_pool(addr):
    out = {"addr": addr}
    code = get_code(addr)
    out["code_len"] = (len(code)//2 - 1) if isinstance(code, str) and code.startswith("0x") else 0
    out["impl"] = readaddr(call(addr, EIP1967_IMPL))
    out["proxy_admin"] = readaddr(call(addr, EIP1967_ADMIN))
    out["admin_fn"] = readaddr(call(addr, SEL["admin()"]))
    out["owner"] = readaddr(call(addr, SEL["owner()"]))
    out["paused"] = call_int(addr, SEL["paused()"])
    out["vprice"] = call_int(addr, SEL["getVirtualPrice()"])
    ms = call(addr, SEL["metaSwapStorage()"])
    if isinstance(ms, str) and len(ms) >= 194:
        out["baseSwap"] = readaddr(ms)
        out["baseVirtualPrice"] = int(ms[2:][64:128], 16)
        out["baseCacheLastUpdated"] = int(ms[2:][128:192], 16)
    toks = []
    for i in range(4):
        t = readaddr(call(addr, "0x82b86600" + u256(i)))
        if t is None: break
        toks.append({"i": i, "token": t,
                     "dec": call_int(t, "0x313ce567"),
                     "internal": call_int(addr, "0x91ceb3eb" + u256(i)),
                     "admin": call_int(addr, "0xef0a712f" + u256(i)),
                     "actual": call_int(t, "0x70a08231" + padaddr(addr))})
    out["tokens"] = toks
    # impl code hash
    if out["impl"]:
        ic = get_code(out["impl"])
        if isinstance(ic, str) and ic.startswith("0x"):
            out["impl_code_len"] = len(ic)//2 - 1
            out["impl_code_sha256"] = hashlib.sha256(bytes.fromhex(ic[2:])).hexdigest()
    return out

def main():
    blk = int(rpc("eth_blockNumber", []), 16)
    print(f"# RPC={RPC.split('/bsc/')[0][:30]} block={blk}")
    result = {"rpc": RPC.split('/bsc/')[0], "block": blk, "pools": {}}
    allp = {"POOL3": P3, "BTCPOOL": BTC, "ETHPOOL": ETH, "USTMETA": USTM, "FUSDTMETA": FUSM, "NRVMETA": NRVM}
    for i, a in enumerate(EXTRA): allp[f"EXTRA{i}"] = a
    for name, a in allp.items():
        try:
            fp = fp_pool(a)
            result["pools"][name] = fp
            resid = ",".join(f"[{t['i']}]int={t['internal']},adm={t['admin']}" for t in fp["tokens"])
            print(f"{name:12s} paused={fp['paused']} owner={(fp['owner'] or 'SELF')[:10]} impl={(fp.get('impl') or 'self')[:12]} vp={fp.get('vprice')}")
            print(f"             {resid}")
        except Exception as e:
            print(f"{name} ERROR {type(e).__name__} {e}")
            result["pools"][name] = {"addr": a, "error": str(e)}
    with open("/home/heisenberg/CA/nerve-qc/analysis/fingerprint.json", "w") as f:
        json.dump(result, f, indent=2)
    print("saved fingerprint.json")

if __name__ == "__main__":
    main()

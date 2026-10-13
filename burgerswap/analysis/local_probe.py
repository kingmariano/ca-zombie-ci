#!/usr/bin/env python3
"""
BurgerSwap local state probe (light): top pairs from the triage sample + key actors.
Read-only. Public BSC RPC only. No secrets.
"""
import json, urllib.request, subprocess, sys, time

UA = {"User-Agent": "Mozilla/5.0 zombie-ci", "Content-Type": "application/json"}
RPC = "https://bsc-rpc.publicnode.com"

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    return json.loads(urllib.request.urlopen(req, timeout=30).read())

def call(to, data):
    r = rpc("eth_call", [{"to": to, "data": data}, "latest"])
    return r.get("result")

def batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": t, "data": d}, "latest"]} for i, (t, d) in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers=UA)
    d = json.loads(urllib.request.urlopen(req, timeout=120).read())
    out = [None] * len(calls)
    for it in d:
        i = it.get("id")
        if isinstance(i, int):
            out[i] = it.get("result")
    return out

def sig(s):
    return subprocess.run(["cast", "sig", s], capture_output=True, text=True).stdout.strip()

SEL = {s: sig(s) for s in [
    "token0()", "token1()", "getReserves()", "totalSupply()", "balanceOf(address)",
    "symbol()", "decimals()", "remainReward()", "swapPrecondition(address)",
    "getAmountsOut(uint256,address[])", "takeWithAddress(address)",
]}

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def enc_uint(n):
    return hex(n)[2:].rjust(64, "0")

def addr(h):
    return "0x" + h[-40:] if isinstance(h, str) and len(h) >= 42 else None

def dec_str(h):
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], "big")
            return b[64:64 + ln].decode("utf-8", "replace")
        return b.rstrip(b"\x00").decode()
    except Exception:
        return "?"

def main():
    PLAT = "0xB099D7dbC415bf5491B0ca6fdCcFddF8b7EDCE12"
    BURGER = "0xae9269f27437f0fcbc232d39ec814844a51d6b8f"
    block = int(rpc("eth_blockNumber", [])["result"], 16)
    print("BSC block:", block)
    # top pairs from triage factory sample
    tri = json.load(open("/home/heisenberg/CA/l2-triage-a/ci-out/factories.json"))
    top = []
    for k, v in tri.items():
        if "burger" in k:
            top = [x["pair"] for x in v.get("top_pairs", [])]
    extra = ["0x8d118fb789d8330f24aff16f8278a81e859512ee", "0x7ac55ac530f2C29659573Bde0700c6758D69e677"]
    pairs = list(dict.fromkeys(top + extra))
    print(f"probing {len(pairs)} pairs")
    rows = []
    for p in pairs:
        t0 = addr(call(p, SEL["token0()"]))
        t1 = addr(call(p, SEL["token1()"]))
        rr = call(p, SEL["getReserves()"])
        r0 = int(rr[2:66], 16); r1 = int(rr[66:130], 16)
        ts = int(call(p, SEL["totalSupply()"]), 16)
        b0 = int(call(t0, SEL["balanceOf(address)"] + enc_addr(p)), 16)
        b1 = int(call(t1, SEL["balanceOf(address)"] + enc_addr(p)), 16)
        rem = 0
        if t0.lower() == BURGER or t1.lower() == BURGER:
            rem = int(call(p, SEL["remainReward()"]), 16)
        a0 = b0 - rem if t0.lower() == BURGER else b0
        a1 = b1 - rem if t1.lower() == BURGER else b1
        e0 = max(0, a0 - r0); e1 = max(0, a1 - r1)
        s0 = dec_str(call(t0, SEL["symbol()"])); s1 = dec_str(call(t1, SEL["symbol()"]))
        sp0 = int(call(PLAT, SEL["swapPrecondition(address)"] + enc_addr(t0)), 16)
        sp1 = int(call(PLAT, SEL["swapPrecondition(address)"] + enc_addr(t1)), 16)
        # quote 1e18 of token0 -> token1
        path_enc = "0x" + enc_uint(32) + enc_uint(2) + enc_addr(t0) + enc_addr(t1)
        quote = call(PLAT, SEL["getAmountsOut(uint256,address[])"] + enc_uint(10**18) + path_enc[2:])
        q = int(quote[-64:], 16) if quote and len(quote) >= 130 else None
        rows.append({"pair": p, "t0": t0, "t1": t1, "s0": s0, "s1": s1, "r0": r0, "r1": r1,
                     "b0": b0, "b1": b1, "e0": e0, "e1": e1, "lp": ts, "rem": rem,
                     "sp0": sp0, "sp1": sp1, "quote01": q})
    json.dump(rows, open("/home/heisenberg/CA/burgerswap/analysis/local_top_pairs.json", "w"), indent=1)
    for r in rows:
        print(f"{r['pair']} {r['s0']}/{r['s1']} r=({r['r0']},{r['r1']}) bal=({r['b0']},{r['b1']}) excess=({r['e0']},{r['e1']}) lp={r['lp']} sp=({r['sp0']},{r['sp1']}) q01={r['quote01']}")
    # DGAS token level
    print("\n== BURGER (Dgas) token:")
    print(" amountPerBlock:", int(call(BURGER, sig("amountPerBlock()")), 16))
    print(" balanceOf(self):", int(call(BURGER, SEL["balanceOf(address)"] + enc_addr(BURGER)), 16))
    for p in pairs[:6]:
        r = call(BURGER, SEL["takeWithAddress(address)"] + enc_addr(p))
        prod = call(BURGER, sig("getProductivity(address)") + enc_addr(p))
        pr = int(prod[2:66], 16); pt = int(prod[66:130], 16)
        print(f"  takeWithAddress({p}) = {int(r,16) if r and r!='0x' else 0}  productivity=({pr},{pt})")
    # governance
    G = "0x9154c2684aeF8d106babcB19Aa81d4FabF7581ec"
    print("\n== DemaxGovernance:")
    for s in ["totalSupply()", "stakingSupply()", "lockTime()"]:
        print(" ", s, int(call(G, sig(s)), 16))
    for a in ["0x86A327715d707BCa24983b1145D1F6c40C5d4A74"]:
        print("  rewardOf(pool):", int(call(G, sig("rewardOf(address)") + enc_addr(a)), 16))
    print("\n== DemaxPool:")
    POOL = "0x86A327715d707BCa24983b1145D1F6c40C5d4A74"
    for s in ["totalReward()"]:
        print(" ", s, int(call(POOL, sig(s)), 16))

if __name__ == "__main__":
    main()

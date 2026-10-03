#!/usr/bin/env python3
"""Verify value of top LP positions held by a DxSale locker.

Reads pair token0/token1/reserves/totalSupply + locker LP balance, prices tokens
via DefiLlama, and computes underlying value of the locker's share.
"""
import json, sys, time, urllib.request

RPC = "https://bsc-rpc.publicnode.com"
LLAMA = "https://coins.llama.fi/prices/current/"

def rpc_batch(calls):
    payload = []
    for i, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "zombie-research/1.0"})
    out = []
    with urllib.request.urlopen(req, timeout=60) as r:
        res = json.load(r)
    res = sorted(res, key=lambda x: x["id"])
    for x in res:
        out.append(x.get("result"))
    return out

def enc_sel(sig):
    # keccak not available; use known selectors
    known = {
        "token0()": "0x0dfe1681",
        "token1()": "0xd21220a7",
        "getReserves()": "0x0902f1ac",
        "totalSupply()": "0x18160ddd",
        "balanceOf(address)": "0x70a08231",
        "decimals()": "0x313ce567",
        "symbol()": "0x95d89b41",
    }
    return known[sig]

def addr_arg(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def call(to, sig, arg=None, latest="latest"):
    data = enc_sel(sig) + (addr_arg(arg) if arg else "")
    return [(to, data)]

def u256(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    return int(hexstr, 16)

def main():
    locker = sys.argv[1]
    lp_file = sys.argv[2]
    lps = json.load(open(lp_file))
    print(f"locker {locker}, {len(lps)} LP tokens")

    # per LP: token0, token1, reserves, totalSupply, locker balance
    meta = {}
    calls = []
    for lp in lps:
        calls.append((lp, enc_sel("totalSupply()")))
    res = rpc_batch(calls)
    for lp, r in zip(lps, res):
        meta[lp] = {"totalSupply": u256(r)}

    for lp in lps:
        res = rpc_batch([(lp, enc_sel("token0()")), (lp, enc_sel("token1()"))])
        meta[lp]["token0"] = "0x" + res[0][-40:] if res[0] and res[0] != "0x" else None
        meta[lp]["token1"] = "0x" + res[1][-40:] if res[1] and res[1] != "0x" else None

    for lp in lps:
        res = rpc_batch([(lp, enc_sel("getReserves()")),
                         (lp, enc_sel("balanceOf(address)") + addr_arg(locker))])
        r0 = u256(res[0][:66]) if res[0] and res[0] != "0x" else None
        r1 = u256(("0x" + res[0][66:130])) if res[0] and res[0] != "0x" else None
        meta[lp]["reserve0"] = r0
        meta[lp]["reserve1"] = r1
        meta[lp]["lockerBal"] = u256(res[1])

    # collect tokens for pricing
    toks = set()
    for lp, m in meta.items():
        for t in (m.get("token0"), m.get("token1")):
            if t:
                toks.add(t.lower())
    prices = {}
    toks = list(toks)
    for i in range(0, len(toks), 50):
        chunk = toks[i:i+50]
        url = LLAMA + ",".join(f"bsc:{t}" for t in chunk)
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                d = json.load(r)
            for k, v in d.get("coins", {}).items():
                prices[k.split(":")[1].lower()] = v.get("price")
        except Exception as e:
            print("price err", e)
        time.sleep(0.3)

    total_usd = 0.0
    rows = []
    for lp, m in meta.items():
        ts = m.get("totalSupply") or 0
        bal = m.get("lockerBal") or 0
        r0 = m.get("reserve0") or 0
        r1 = m.get("reserve1") or 0
        p0 = prices.get((m.get("token0") or "").lower()) or 0
        p1 = prices.get((m.get("token1") or "").lower()) or 0
        share = (bal / ts) if ts else 0
        usd = share * (r0 * p0 + r1 * p1)
        total_usd += usd
        rows.append({"lp": lp, "lockerBal": bal, "totalSupply": ts, "share": share,
                     "token0": m.get("token0"), "token1": m.get("token1"),
                     "r0": r0, "r1": r1, "p0": p0, "p1": p1, "usd": usd})
    rows.sort(key=lambda x: -x["usd"])
    for r in rows:
        print(f"  ${r['usd']:>14,.2f} share={r['share']:.6f} bal={r['lockerBal']} ts={r['totalSupply']} "
              f"t0={r['token0']} r0={r['r0']} p0={r['p0']} t1={r['token1']} r1={r['r1']} p1={r['p1']}")
    print(f"TOTAL verified-share USD (top set): {total_usd:,.2f}")
    json.dump(rows, open(f"/tmp/lp_verify_{locker[:8]}.json", "w"), indent=1)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Phase 4 supplement: per-CL-pool stakedLiquidity/liquidity/reward state for all 194 pools."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ve33_rpc as rp

D = os.path.dirname(os.path.abspath(__file__))
SIG = json.load(open(os.path.join(D, "sigs.json")))
d = json.load(open(os.path.join(D, "ve33_probe.json")))
BLK = d["block"]
hb = json.load(open(os.path.join(D, "hybra_pools.json")))

def du(o):
    return int(o, 16) if o and o != "0x" else None

def main():
    pools = sorted(set(x["pool"].lower() for x in hb) | set((d.get("pools") or {}).keys()))
    print("pools:", len(pools), flush=True)
    sigs = ["stakedLiquidity()", "liquidity()", "rewardRate()", "rewardReserve()", "periodFinish()", "rollover()", "gauge()"]
    raw = rp.batch([("eth_call", [{"to": p, "data": SIG[s]}, hex(BLK)]) for p in pools for s in sigs], chunk=15)
    out = {}
    k = 0
    staked = 0
    liq = 0
    reserve = 0
    for p in pools:
        rec = {}
        for s in sigs:
            r = raw[k]; k += 1
            v = du(r)
            if s == "gauge()":
                rec[s] = ("0x" + r[-40:]) if r and r != "0x" and len(r) >= 42 else None
            else:
                rec[s] = v or 0
        out[p] = rec
        staked += rec["stakedLiquidity()"]
        liq += rec["liquidity()"]
        reserve += rec["rewardReserve()"]
    d["poolState"] = out
    json.dump(d, open(os.path.join(D, "ve33_probe.json"), "w"), indent=1)
    print("sum stakedLiquidity:", staked)
    print("sum liquidity:", liq)
    print("sum rewardReserve (HYBR raw):", reserve, "=", reserve / 1e18, "HYBR")
    # gauged pools count
    g = sum(1 for p, r in out.items() if r["gauge()"] and int(r["gauge()"], 16) != 0)
    print("pools with gauge:", g, "/", len(out))
    print("pools with nonzero stakedLiquidity:", sum(1 for r in out.values() if r["stakedLiquidity()"]))
    print("pools with nonzero rewardReserve:", sum(1 for r in out.values() if r["rewardReserve()"]))

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Compute USD value of LP staked in MasterChefV2 pools from scan outputs."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CIOUT = os.path.join(ROOT, "ci-out")
pairs = {p["pair"].lower(): p for p in json.load(open(os.path.join(CIOUT, "pairs.json")))}
mc = json.load(open(os.path.join(CIOUT, "masterchef.json")))
rows = []
tot = 0.0
for p in mc["pools"]:
    lp = (p.get("lpToken") or "").lower()
    pr = pairs.get(lp)
    tvl = pr["tvl_usd"] if pr else None
    ts = pr["totalSupply"] if pr else None
    bal = p.get("mcBalance") or 0
    val = (tvl * bal / ts) if (tvl and ts) else None
    tot += val or 0
    rows.append({"pid": p["pid"], "lpToken": p["lpToken"],
                 "sym0": pr.get("sym0") if pr else None, "sym1": pr.get("sym1") if pr else None,
                 "allocPoint": p["allocPoint"], "totalDeposit": p["totalDeposit"],
                 "mcBalance": bal, "pair_tvl_usd": tvl, "staked_usd": round(val, 2) if val else None,
                 "is_v2_pair": bool(pr)})
out = {"pools": rows, "total_staked_usd": round(tot, 2),
       "bswap_held": mc.get("bswapBalance"), "bswapPerSec": mc.get("bswapPerSec")}
json.dump(out, open(os.path.join(ROOT, "analysis", "mc_pools.json"), "w"), indent=1)
for r in rows:
    print(f"pid {r['pid']:2d} {str(r['sym0'])}/{str(r['sym1']):<8} alloc {r['allocPoint']:>12} "
          f"staked ${r['staked_usd'] if r['staked_usd'] is not None else 0:>10,.2f} "
          f"pairTVL ${r['pair_tvl_usd'] if r['pair_tvl_usd'] is not None else 0:>10,.2f}")
print("TOTAL MasterChef staked USD:", out["total_staked_usd"])

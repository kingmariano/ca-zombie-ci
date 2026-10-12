#!/usr/bin/env python3
"""Split Dfyn pool value by claim holder: feeTo (P), farms (H-O), free LP (H-O)."""
import json

BASE = "/home/heisenberg/CA/dfyn-network/"
art = BASE + "ci-artifacts/result-dfyn-network/ci-out/"

pairs = {}
for ch in ["polygon", "fantom", "okc"]:
    d = json.load(open(art + f"pairs-{ch}.json"))
    for r in d["rows"]:
        pairs[r["pair"].lower()] = {"chain": ch, "r0": r["r0"] or 0, "r1": r["r1"] or 0, "ts": r["ts"] or 0,
                                    "p0": r["p0"], "p1": r["p1"], "d0": r["d0"], "d1": r["d1"],
                                    "reserves_usd": r["reserves_usd"]}

feeTo = {}
fp = json.load(open(BASE + "analysis/feeto-poly.json")) if __import__("os").path.exists(BASE + "analysis/feeto-poly.json") else {}
fo = json.load(open(BASE + "analysis/feeto-lp-other.json"))
for p, b in fp.items(): feeTo[p.lower()] = b or 0
for ch in ["fantom", "okc"]:
    for p, b in fo.get(ch, {}).items(): feeTo[p.lower()] = b or 0

farm_bal = json.load(open(BASE + "analysis/farms-balances.json"))
farm_lp = {}
for farm, v in farm_bal.items():
    st = (v.get("stakingToken") or "").lower()
    staked = v.get("staked") or 0
    if st and staked:
        farm_lp[st] = farm_lp.get(st, 0) + staked

tot_res = sum(p["reserves_usd"] for p in pairs.values())
fee_val = 0.0
fee_rows = []
farm_val = 0.0
farm_rows = []
for p, v in pairs.items():
    ts = v["ts"]
    if ts <= 0: continue
    fb = feeTo.get(p, 0)
    if fb:
        val = v["reserves_usd"] * min(1.0, fb / ts)
        fee_val += val
        if val > 1: fee_rows.append((p, v["chain"], val, fb, ts))
    sb = farm_lp.get(p, 0)
    if sb:
        val = v["reserves_usd"] * min(1.0, sb / ts)
        farm_val += val
        if val > 1: farm_rows.append((p, v["chain"], val, sb, ts))

print(f"TOTAL pool reserves (CI llama pricing): ${tot_res:,.2f}")
print(f"feeTo EOA LP value (P):                 ${fee_val:,.2f}")
print(f"Farm-staked LP value (H-O):             ${farm_val:,.2f}")
print(f"Free LP value (H-O):                    ${tot_res - fee_val - farm_val:,.2f}")
print("\nTop feeTo positions:")
for r in sorted(fee_rows, key=lambda x: -x[2])[:12]:
    print(f"  {r[0]} {r[1]} ${r[2]:,.2f} lp={r[3]}/{r[4]}")
print("\nTop farm-staked positions:")
for r in sorted(farm_rows, key=lambda x: -x[2])[:12]:
    print(f"  {r[0]} {r[1]} ${r[2]:,.2f} lp={r[3]}/{r[4]}")

out = {"total_reserves_usd": round(tot_res, 2), "feeto_lp_usd": round(fee_val, 2),
       "farm_staked_lp_usd": round(farm_val, 2), "free_lp_usd": round(tot_res - fee_val - farm_val, 2),
       "feeto_top": [{"pair": r[0], "chain": r[1], "usd": round(r[2], 2)} for r in sorted(fee_rows, key=lambda x: -x[2])[:20]],
       "farm_top": [{"pair": r[0], "chain": r[1], "usd": round(r[2], 2)} for r in sorted(farm_rows, key=lambda x: -x[2])[:20]]}
json.dump(out, open(BASE + "analysis/value-split.json", "w"), indent=1)

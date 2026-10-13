#!/usr/bin/env python3
"""Categorize pair LP ownership: team/feeTo (P), burn address + locked minimum (S),
third parties (H-O). Outputs analysis/ownership.json"""
import json, os

D = os.path.dirname(os.path.abspath(__file__))
st = json.load(open(os.path.join(D, "live_state.json")))
pr = json.load(open(os.path.join(D, "prices.json")))
lh = json.load(open(os.path.join(D, "lp_holders.json")))

TEAM = {
    "0x27160d3b618ee073efaaee596b6be37018d18e4a": "team-treasury",
    "0x68586610448bb167d56b92d6b25dc7f196042679": "team-2",
    "0xbe4ec6286bf4b557d098e303fa3570584bda1eb9": "feeTo-EOA",
    "0x9973eddb50d3f22c2523862ea8a415f7f43d5cd7": "feeToSetter-EOA",
}
BURN = {
    "0x1239660af62d515bfecd4ee09c58d2cd32504605": "burn-or-locked",
    "0x0000000000000000000000000000000000000000": "MINIMUM_LIQUIDITY",
    "0x000000000000000000000000000000000000dead": "dead",
}
byp = {x["pair"]: x for x in pr["pairs"]}

cat = {"P": 0.0, "S": 0.0, "H-O": 0.0, "other": 0.0}
rows = []
for pv, p in st["pairs"].items():
    v = byp[pv]["usd_total"]
    ts = int(p["lp_totalSupply"])
    rec = {"pair": pv, "symbols": f"{p['symbol0']}/{p['symbol1']}", "usd_total": round(v, 2),
           "lp_totalSupply": ts, "P": 0.0, "S": 0.0, "H-O": 0.0, "unaccounted": 0.0, "holders": []}
    holders = (lh["holders"].get(pv) or {}).get("holders") or []
    acc = 0
    for h in holders:
        a = h["address"].lower()
        b = int(h["balance"])
        acc += b
        share = (b / ts * v) if ts > 0 else 0
        if a in TEAM:
            rec["P"] += share; who = TEAM[a]
        elif a in BURN:
            rec["S"] += share; who = BURN[a]
        elif a == pv.lower():
            rec["S"] += share; who = "pair-itself(stuck)"
        elif a == "0x0000000000000000000000000000000000000000":
            rec["S"] += share; who = "zero"
        else:
            rec["H-O"] += share; who = "third-party"
        rec["holders"].append({"address": h["address"], "bal": str(b), "usd": round(share, 2), "class": who})
    # unaccounted = totalSupply - sum(holders) ; attribute to S (locked min likely)
    diff = ts - acc
    if diff > 0:
        rec["unaccounted"] = round(diff / ts * v, 2) if ts else 0
        rec["S"] += rec["unaccounted"]
    for k in ("P", "S", "H-O"):
        cat[k] += rec[k]
        rec[k] = round(rec[k], 2)
    rows.append(rec)

rows.sort(key=lambda r: -r["usd_total"])
print(f"{'pair':<14}{'symbols':<22}{'USD':>10} {'P':>9} {'S':>10} {'H-O':>9}")
for r in rows[:30]:
    print(f"{r['pair'][:12]:<14}{r['symbols'][:20]:<22}{r['usd_total']:>10,.0f} {r['P']:>9,.0f} {r['S']:>10,.0f} {r['H-O']:>9,.0f}")
tot = sum(r["usd_total"] for r in rows)
print(f"TOTAL USD {tot:,.0f} | P {cat['P']:,.0f} | S {cat['S']:,.0f} | H-O {cat['H-O']:,.0f}")
json.dump({"totals": {k: round(v, 2) for k, v in cat.items()}, "rows": rows},
          open(os.path.join(D, "ownership.json"), "w"), indent=1)
print("wrote ownership.json")

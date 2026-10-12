#!/usr/bin/env python3
"""For each pair, fetch LP holders from promscan; flag contract holders (farms)."""
import json, urllib.request, time
from prom import *

def api(path):
    req = urllib.request.Request("https://promscan.io" + path, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

d = json.load(open("/home/heisenberg/CA/savmswap/analysis/pair_table.json"))
rows = d["rows"]
out = {}
for r in rows:
    p = r["pair"]
    try:
        info = api(f"/api/v2/tokens/{p}/holders")
    except Exception as e:
        out[p] = {"error": str(e)}
        continue
    items = info.get("items", [])
    # holders endpoint returns paginated; take first page (top holders)
    hold = []
    for i in items:
        hold.append({
            "addr": i["address"]["hash"],
            "value": int(i["value"]),
            "is_contract": i["address"]["is_contract"],
            "verified": i["address"].get("is_verified"),
            "name": i["address"].get("name"),
        })
    out[p] = {"lp": r["lp"], "holders": hold, "next": info.get("next_page_params") is not None,
              "sym0": r["sym0"], "sym1": r["sym1"], "A0": r["A0"], "A1": r["A1"]}
    time.sleep(0.1)
json.dump(out, open("/home/heisenberg/CA/savmswap/analysis/lp_holders.json", "w"), indent=1)

# report: contract holders of LP
print("== LP held by CONTRACTS ==")
for p, v in out.items():
    if "holders" not in v:
        continue
    for h in v["holders"]:
        if h["is_contract"]:
            print(f"{p} {v['sym0']}/{v['sym1']} LPtotal={v['lp']} holder={h['addr']} val={h['value']} share={h['value']/v['lp']*100:.2f}% name={h['name']} verified={h['verified']}")
print()
print("== top LP holder is EOA, snapshot ==")
for p, v in out.items():
    if "holders" not in v or not v["holders"]:
        continue
    h = v["holders"][0]
    share = h["value"] / v["lp"] * 100 if v["lp"] else 0
    if share > 50 and v["A0"] + v["A1"] > 0:
        print(f"{p} {v['sym0']}/{v['sym1']} top={h['addr']} ({'C' if h['is_contract'] else 'EOA'}) {share:.1f}%  A0={v['A0']:.3f} A1={v['A1']:.3f}")

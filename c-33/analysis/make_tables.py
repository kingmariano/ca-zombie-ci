#!/usr/bin/env python3
"""Generate README tables + checker CSV from the final ci-out/scan.json."""
import json, os, csv
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
d = json.load(open(os.path.join(ROOT, "ci-out", "scan.json")))
results = d["results"]
summary = d["summary"]

# per protocol+chain aggregation
agg = defaultdict(lambda: dict(markets=0, empty=0, tiny=0, empty_atk=0, direct=0,
                               borrowable=0.0, flagged_cash=0.0, statuses=set()))
for t in results:
    key = (t["protocol"], t["chain"])
    a = agg[key]
    a["statuses"].add(t.get("status", "?"))
    for m in t.get("markets", []):
        a["markets"] += 1
        if m.get("empty"):
            a["empty"] += 1
        if m.get("tinySupply"):
            a["tiny"] += 1
        if m.get("emptyBorrowAttack"):
            a["empty_atk"] += 1
        if m.get("directDrain"):
            a["direct"] += 1
            a["flagged_cash"] += m.get("cashUSD") or 0
        if m.get("emptyBorrowAttack"):
            a["flagged_cash"] += m.get("cashUSD") or 0
    a["borrowable"] += t.get("borrowableCashUSD") or 0

rows = []
for (proto, chain), a in sorted(agg.items(), key=lambda kv: -(kv[1]["empty_atk"] * 1e12 + kv[1]["direct"] * 1e9 + kv[1]["borrowable"])):
    if a["empty_atk"] or a["direct"] or a["borrowable"] > 100:
        if a["empty_atk"] and a["borrowable"] > 0:
            verdict = "LIVE (empty+funded)"
        elif a["empty_atk"]:
            verdict = "empty market, no unpaused cash"
        elif a["direct"]:
            verdict = "direct truncation drain"
        else:
            verdict = "cash but no empty market"
    else:
        verdict = "closed/no cash"
    rows.append(dict(protocol=proto, chain=chain, markets=a["markets"], empty=a["empty"],
                     tiny=a["tiny"], empty_atk=a["empty_atk"], direct=a["direct"],
                     borrowable_usd=round(a["borrowable"], 2), verdict=verdict,
                     status=";".join(sorted(a["statuses"]))))

with open(os.path.join(HERE, "checker_table.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

md = ["| Protocol | Chain | Mkts | Empty | Tiny | Empty+CF>0+unpaused | Direct drain | Unpaused borrowable USD | Verdict |",
      "|---|---|---:|---:|---:|---:|---:|---:|---|"]
for r in rows:
    md.append(f"| {r['protocol']} | {r['chain']} | {r['markets']} | {r['empty']} | {r['tiny']} | "
              f"{r['empty_atk']} | {r['direct']} | {r['borrowable_usd']:,.2f} | {r['verdict']} |")
open(os.path.join(HERE, "checker_table.md"), "w").write("\n".join(md) + "\n")

# exposure table
ex = summary.get("exposure", [])
md2 = ["| Protocol | Chain | Mode | Direct-drain USD | Unpaused borrowable USD | Potential USD |",
       "|---|---|---|---:|---:|---:|"]
for e in ex:
    md2.append(f"| {e['protocol']} | {e['chain']} | {e['mode']} | {e.get('directDrainUSD',0):,.2f} | "
               f"{e.get('borrowableCashUSD',0):,.2f} | {e.get('potentialUSD',0):,.2f} |")
open(os.path.join(HERE, "exposure_table.md"), "w").write("\n".join(md2) + "\n")

print(f"checker rows: {len(rows)}")
for r in rows[:15]:
    print(r)
print("exposure:", len(ex))
for e in ex[:10]:
    print(e["protocol"], e["chain"], e["mode"], e["potentialUSD"])

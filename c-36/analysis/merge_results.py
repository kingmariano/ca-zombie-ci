#!/usr/bin/env python3
"""Merge child segment results + parent worklist into the final 295-row verdict table."""
import json, os, sys

BASE = "/home/heisenberg/CA/c-36/analysis"
WL = json.load(open(f"{BASE}/worklist.json"))

# collect child results
child_results = {}
for seg in "ABCDE":
    p = f"{BASE}/seg-{seg}/results.json"
    if os.path.exists(p):
        try:
            data = json.load(open(p))
            if isinstance(data, dict):
                data = data.get("results") or []
            if isinstance(data, list):
                for r in data:
                    a = (r.get("address") or "").lower()
                    if a:
                        r["_seg"] = seg
                        child_results[a] = r
        except Exception as e:
            print(f"WARN: cannot parse {p}: {e}", file=sys.stderr)

rows = []
for a, w in WL.items():
    cr = child_results.get(a.lower(), {})
    rows.append({
        "address": a,
        "name": w.get("name"),
        "category": w.get("category"),
        "source": w.get("source"),
        "live_eth": w.get("live_eth"),
        "mapped": w.get("mapped"),
        "coverage_pct": w.get("coverage_pct"),
        "verified": w.get("verified"),
        "seg": cr.get("_seg"),
        "classification": cr.get("classification", "UNREVIEWED"),
        "claim_model": cr.get("claim_model", ""),
        "eu_candidate": cr.get("eu_candidate"),
        "confidence": cr.get("confidence", ""),
        "notes": cr.get("notes", ""),
    })

# classification counts + value by class
from collections import defaultdict
counts = defaultdict(int); eth_by = defaultdict(float); mapped_by = defaultdict(float)
for r in rows:
    c = r["classification"] or "UNREVIEWED"
    counts[c] += 1
    eth_by[c] += r["live_eth"] or 0
    mapped_by[c] += r["mapped"] or 0

print("classification counts:")
for c, n in sorted(counts.items(), key=lambda kv: -kv[1]):
    print(f"  {c:12s} {n:3d}  live_eth={eth_by[c]:10.2f}  mapped={mapped_by[c]:10.2f}")

json.dump(rows, open(f"{BASE}/final_table.json", "w"), indent=1)
# CSV
import csv
with open(f"{BASE}/final_table.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["address","name","category","source","live_eth","mapped","coverage_pct","verified","seg","classification","claim_model","eu_candidate","confidence","notes"])
    for r in sorted(rows, key=lambda x: -(x["live_eth"] or 0)):
        w.writerow([r["address"], r["name"], r["category"], r["source"], f"{r['live_eth'] or 0:.6f}",
                    f"{r['mapped'] or 0:.6f}", r["coverage_pct"], r["verified"], r["seg"], r["classification"],
                    (r["claim_model"] or "").replace("\n"," ")[:200],
                    json.dumps(r["eu_candidate"]) if r["eu_candidate"] else "",
                    r["confidence"], (r["notes"] or "").replace("\n"," ")[:200]])
print("wrote final_table.json / .csv")
print("unreviewed:", sum(1 for r in rows if r['classification']=='UNREVIEWED'))

#!/usr/bin/env python3
"""Merge ci-out/deep-results.json (deep pass) into ci-out/results.json for the deep-scanned protocols."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
base_p = os.path.join(ROOT, "ci-out/results.json")
deep_p = os.path.join(ROOT, "ci-out/deep-results.json")
if not os.path.exists(deep_p):
    print("no deep-results.json — nothing to merge"); sys.exit(0)
base = json.load(open(base_p))
deep = json.load(open(deep_p))
deep_by = {p["slug"]: p for p in deep["protocols"]}
merged = 0
for i, p in enumerate(base["protocols"]):
    if p["slug"] in deep_by:
        d = deep_by[p["slug"]]
        ok = all(t.get("ok") for t in d["targets"])
        print(f"merging {p['slug']}: old ${p['total_usd']:,.0f} -> new ${d['total_usd']:,.0f} (all_ok={ok})")
        base["protocols"][i] = d
        merged += 1
base["deep_pass"] = {"generated_at": deep.get("generated_at"), "protocols": sorted(deep_by.keys())}
json.dump(base, open(base_p, "w"), indent=1)
print("merged", merged)

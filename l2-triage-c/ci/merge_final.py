#!/usr/bin/env python3
"""Merge: run-3 CI results (all rows) + local re-scans of the 4 fixed collectors."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
base = json.load(open(os.path.join(ROOT, "analysis", "results-ci-run3.json")))
rows = {r["slug"]: r for r in base["rows"]}
FIXED = ["jediswap-v1", "bluemove-dex", "10kswap", "dojoswap-amm"]
LOCAL = {"jediswap-v1": "local-jediswap.json", "bluemove-dex": "local-bluemove.json",
         "10kswap": "local-10kswap.json", "dojoswap-amm": "local-dojoswap.json"}
for slug, fn in LOCAL.items():
    p = os.path.join(ROOT, "analysis", fn)
    if not os.path.exists(p):
        print("missing", fn); continue
    d = json.load(open(p))
    r = d["rows"][0]
    r["notes"] = (r.get("notes") or []) + ["re-scanned locally with fixed scanner code (CI run 38130226961 was cancelled mid-Sui enumeration)"]
    rows[slug] = r
out = {"generated_at_utc": base.get("generated_at_utc"), "rows": list(rows.values()),
       "provenance": "run-3 CI artifact + local re-scans for 4 fixed collectors (see README)"}
json.dump(out, open(os.path.join(ROOT, "ci-out", "results.json"), "w"), indent=2)
print("merged rows:", len(out["rows"]))
for r in sorted(out["rows"], key=lambda x: -(x.get("live_usd") or 0)):
    print(f"{r['slug']:24s} {r['status']:12s} {r.get('live_usd') or 0:>16,.2f}")

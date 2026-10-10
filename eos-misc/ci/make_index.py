#!/usr/bin/env python3
"""Build analysis/index.json — an index of the H2-05 evidence tree (per protocol)."""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "analysis")
GROUPS = {
    "whaleex": "WhaleEx / whaleextrust (EOS)",
    "dmd": "DMD Finance pools 11/12/13 (EOS)",
    "plasma_fluent": "CHATEAU chUSD (Plasma) + Vena Finance (Fluent)",
    "tron": "JustLend V2 (TRON)",
    "vigor": "Vigor (EOS)",
    "strato": "STRATO / Mercata",
}

out = {}
for folder, title in GROUPS.items():
    d = os.path.join(ROOT, folder)
    files = []
    if os.path.isdir(d):
        for base, _, fnames in os.walk(d):
            for f in fnames:
                p = os.path.join(base, f)
                files.append({"path": os.path.relpath(p, ROOT), "bytes": os.path.getsize(p)})
    out[folder] = {"title": title, "files": sorted(files, key=lambda x: x["path"])}
with open(os.path.join(ROOT, "index.json"), "w") as fh:
    json.dump(out, fh, indent=2)
print("indexed", sum(len(v["files"]) for v in out.values()), "files")

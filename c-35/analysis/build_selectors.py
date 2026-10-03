#!/usr/bin/env python3
"""Build signature->selector map from fetched ABIs using `cast sig` (cached)."""
import json, glob, os, subprocess, sys

here = os.path.dirname(__file__)
cache_path = os.path.join(here, "abi_selectors.json")
cache = json.load(open(cache_path)) if os.path.exists(cache_path) else {}

sigs = set()
for f in glob.glob(os.path.join(here, "src", "*.json")):
    try:
        abi = json.loads(json.load(open(f)).get("ABI") or "[]")
    except Exception:
        continue
    for e in abi:
        if e.get("type") == "function":
            sigs.add(e["name"] + "(" + ",".join(i["type"] for i in e["inputs"]) + ")")

new = sorted(s for s in sigs if s not in cache)
for s in new:
    try:
        r = subprocess.run(["cast", "sig", s], capture_output=True, text=True, timeout=10)
        cache[s] = r.stdout.strip().replace("0x", "")
    except Exception:
        cache[s] = None
json.dump(cache, open(cache_path, "w"), indent=0, sort_keys=True)

# map selector -> [sigs]
rev = {}
for s, sel in cache.items():
    if sel:
        rev.setdefault(sel, []).append(s)
json.dump(rev, open(os.path.join(here, "selector_to_sig.json"), "w"), indent=0, sort_keys=True)
print(f"{len(new)} new signatures; {len(rev)} selectors total")

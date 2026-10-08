#!/usr/bin/env python3
"""Compare exposed-function sets across Suilend package versions."""
import json, os, sys

d = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "version_modules.json")))
vers = sorted(int(v) for v in d["versions"])

def fns(v, mod):
    return d["versions"][str(v)]["functions"].get(mod, {})

for mod in ["lending_market", "obligation"]:
    print(f"\n########## {mod} ##########")
    prev = None
    for v in vers:
        cur = fns(v, mod)
        if prev is not None:
            added = sorted(set(cur) - set(prev))
            removed = sorted(set(prev) - set(cur))
            changed = sorted(k for k in set(cur) & set(prev) if cur[k] != prev[k])
            if added or removed or changed:
                print(f"--- v{v-1} -> v{v} ---")
                if added: print("  ADDED:", added)
                if removed: print("  REMOVED:", removed)
                if changed:
                    for k in changed:
                        print(f"  CHANGED: {k} {prev[k]} -> {cur[k]}")
        prev = cur

    # final: full list for v25 with signature
    print(f"\n== {mod} v25 public/entry function signatures ==")
    for name, f in sorted(fns(25, mod).items()):
        if f["vis"] in ("Public",) or f["entry"]:
            print(f"  {name}: vis={f['vis']} entry={f['entry']} tp={f['tp']} params={f['params']} ret={f['ret']}")

# reserve and oracles quick change maps
for mod in ["reserve", "oracles", "reserve_config"]:
    print(f"\n########## {mod} ##########")
    prev = None
    for v in vers:
        cur = fns(v, mod)
        if prev is not None:
            added = sorted(set(cur) - set(prev))
            removed = sorted(set(prev) - set(cur))
            changed = sorted(k for k in set(cur) & set(prev) if cur[k] != prev[k])
            if added or removed or changed:
                print(f"--- v{v-1} -> v{v} ---")
                if added: print("  ADDED:", added)
                if removed: print("  REMOVED:", removed)
                if changed:
                    for k in changed:
                        print(f"  CHANGED: {k} {prev[k]} -> {cur[k]}")
        prev = cur

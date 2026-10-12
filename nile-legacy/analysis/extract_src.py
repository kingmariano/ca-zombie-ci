#!/usr/bin/env python3
"""Extract Solidity sources from Etherscan source bundles into analysis/src_flat/."""
import json, os, sys, re

SRC = os.path.join(os.path.dirname(__file__), "src")
OUT = os.path.join(os.path.dirname(__file__), "src_flat")
os.makedirs(OUT, exist_ok=True)

def extract(raw):
    if raw.startswith("{{"):
        raw = raw[1:-1]  # strip the extra braces Etherscan adds
    try:
        d = json.loads(raw)
    except Exception:
        return None
    if isinstance(d, dict) and "sources" in d:
        return d["sources"]
    return None

for fn in sorted(os.listdir(SRC)):
    path = os.path.join(SRC, fn)
    raw = open(path).read()
    sources = extract(raw)
    if not sources:
        # plain source
        open(os.path.join(OUT, fn + ".sol"), "w").write(raw)
        continue
    for name, c in sources.items():
        content = c.get("content") if isinstance(c, dict) else c
        safe = name.replace("/", "__")
        open(os.path.join(OUT, safe), "w").write(content)

print("done:", len(os.listdir(OUT)), "files in", OUT)

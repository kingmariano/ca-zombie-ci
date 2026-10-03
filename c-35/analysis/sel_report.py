#!/usr/bin/env python3
"""Diff live selectors of a contract against the known selector->signature map.
Usage: python3 sel_report.py 0xaddr [extra_sig...]
"""
import json, os, sys, subprocess
sys.path.insert(0, os.path.dirname(__file__))
import importlib
se = importlib.import_module("sel_extract")

here = os.path.dirname(__file__)
rev = json.load(open(os.path.join(here, "selector_to_sig.json")))

addr = sys.argv[1]
extra = sys.argv[2:]
code = se.rpc("eth_getCode", [addr, "latest"])
sels = se.extract(code)
print(f"== {addr} code={len(code)//2-1}B selectors={len(sels)} ==")
unknown = []
for s in sels:
    sigs = rev.get(s, [])
    if not sigs and extra:
        for e in extra:
            r = subprocess.run(["cast", "sig", e], capture_output=True, text=True)
            if r.stdout.strip() == s:
                sigs = [e]
    if sigs:
        print(f"  {s}  {' | '.join(sigs)}")
    else:
        unknown.append(s)
print(f"-- unknown/wrapper selectors ({len(unknown)}):")
print("  " + " ".join(unknown))

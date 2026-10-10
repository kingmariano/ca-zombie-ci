#!/usr/bin/env python3
"""Map entry-point selectors to ABI names via sn_keccak for Haiko classes."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import selector_from_name  # noqa

CLASSES = os.path.join(os.path.dirname(__file__), "classes")

for name in ["ReplicatingStrategy", "MarketManager", "ReplicatingSolver", "Quoter", "Distributor"]:
    d = json.load(open(os.path.join(CLASSES, f"{name}.json")))
    abi = json.loads(d["abi"])
    ext = d["entry_points_by_type"]["EXTERNAL"]

    # collect all external function names from abi (top-level + interface items)
    names = []
    for e in abi:
        items = []
        if e.get("type") == "function":
            items = [e]
        elif e.get("type") == "interface":
            items = e.get("items", [])
        for f in items:
            if f.get("type") == "function" and f.get("state_mutability") == "external":
                names.append(f["name"])

    name2sel = {}
    for n in names:
        s = selector_from_name(n)
        if s:
            name2sel[n] = s
    sel2name = {v: k for k, v in name2sel.items()}

    matched, unmatched = [], []
    for x in ext:
        sel = x["selector"]
        if sel in sel2name:
            matched.append((sel2name[sel], sel))
        else:
            unmatched.append(sel)

    print(f"== {name}: EXTERNAL={len(ext)}; ABI external names={len(names)}; matched={len(matched)}; unmatched={len(unmatched)}")
    print("   matched:", ", ".join(sorted(n for n, _ in matched)))
    if unmatched:
        print("   UNMATCHED:", unmatched)
    print()

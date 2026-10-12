#!/usr/bin/env python3
"""Decode flat UPLC reference scripts from koios_reference_scripts.json into v2/."""
import sys, json, re
sys.setrecursionlimit(300000)
import uplc

V2 = "/home/heisenberg/CA/lenfi/analysis/v2"
D = "/home/heisenberg/CA/lenfi/analysis"
refs = json.load(open(f"{D}/koios_reference_scripts.json"))

hashes = sys.argv[1:]
for h in hashes:
    v = refs.get(h)
    if not v:
        print(f"{h}: NOT IN koios_reference_scripts.json")
        continue
    raw = bytes.fromhex(v["bytes"])
    # uplc.unflatten takes the CBOR-wrapped flat encoding directly (cbor2.loads inside)
    term = uplc.unflatten(raw)
    txt = uplc.dumps(term)
    open(f"{V2}/decoded_{h}.uplc", "w").write(txt)
    strs = sorted(set(re.findall(r'"((?:[^"\\]|\\.)*)"', txt)))
    print(f"=== {h} size={v['size']} decoded_chars={len(txt)}")
    for s in strs[:60]:
        print("   STR:", s)

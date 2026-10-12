#!/usr/bin/env python3
"""Complete factory2 (0x0e2b8eE0) pair dump with token metadata."""
import json
from prom import *

F2 = "0x0e2b8eE0A672AD9A0eA0434cC93557CDb5eF3f19"
W = "0x04a21a38d5e275d6023b27504beb3095dc43b0c0"
U = "0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed"
blk = hex(block_number())
rows = json.load(open("pairs_factory2.json"))["pairs"]
toks = set()
for r in rows:
    toks.add(r["t0"]); toks.add(r["t1"])
meta = {}
for t in toks:
    meta[t] = {"sym": call_str(t, "symbol()"), "dec": call_uint(t, "decimals()")}
print("block", int(blk, 16), "pairs", len(rows))
for r in rows:
    m0, m1 = meta[r["t0"]], meta[r["t1"]]
    a0 = r["r0"] / 10**m0["dec"]; a1 = r["r1"] / 10**m1["dec"]
    x0 = r["b0"] - r["r0"]; x1 = r["b1"] - r["r1"]
    mark = ""
    if r["t0"] in (W, U) or r["t1"] in (W, U):
        mark = " <== REAL-ASSET LEG"
    print(f"{r['pair']} {m0['sym']}/{m1['sym']} A0={a0:.6f} A1={a1:.6f} excess=({x0},{x1}){mark}")
json.dump(meta, open("factory2_tokens.json", "w"), indent=1)

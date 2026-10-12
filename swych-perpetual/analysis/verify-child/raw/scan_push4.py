#!/usr/bin/env python3
"""Scan ENTIRE runtime bytecode for all PUSH4 constants, with a 4-op context window."""
import sys

OPS_PUSH = {0x60 + i: i + 1 for i in range(32)}

def decode(hexstr):
    b = bytes.fromhex(hexstr[2:] if hexstr.startswith('0x') else hexstr)
    out = []
    i = 0
    while i < len(b):
        op = b[i]
        if op in OPS_PUSH:
            n = OPS_PUSH[op]
            out.append((i, op, b[i+1:i+1+n]))
            i += 1 + n
        else:
            out.append((i, op, None))
            i += 1
    return out

path = sys.argv[1]
raw = open(path).read().strip()
ops = decode(raw)
from collections import Counter
seen = {}
for idx, (off, op, payload) in enumerate(ops):
    if op == 0x63:
        ctx = ' '.join(f"{o[1]:02x}" + (o[2].hex() if o[2] is not None else '') for o in ops[idx-1:idx+3])
        seen.setdefault(payload.hex(), []).append((hex(off), ctx))
print(f"# {path}: {len(seen)} distinct PUSH4 constants")
for sel, occ in sorted(seen.items()):
    print(f"0x{sel}: {len(occ)} occurrence(s)")
    for off, ctx in occ:
        print(f"    at {off}: ... {ctx} ...")

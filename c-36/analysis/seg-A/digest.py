#!/usr/bin/env python3
"""Digest seg-A sources: print refund/withdraw/claim function bodies compactly for classification."""
import json, os, re

BASE = "/home/heisenberg/CA/c-36/analysis"
segA = json.load(open(f"{BASE}/seg_A_addrs.json"))
wl = json.load(open(f"{BASE}/worklist.json"))
srcdir = f"{BASE}/seg-A/raw/src"

def load(a):
    for f in os.listdir(srcdir):
        if f.lower() == a.lower() + ".json":
            return json.load(open(os.path.join(srcdir, f)))
    return None

def bodies(sc, names=("refund", "withdraw", "claim", "redeem", "cancel", "finalize", "payout", "reclaim", "enableRefund", "withdrawAll", "manualRefund")):
    out = []
    # naive function extraction: from 'function name' to the next 'function' or '}' at same indent
    for m in re.finditer(r'function\s+(\w+)\s*\(([^)]*)\)([^{;]*)\{', sc):
        name, args, mods = m.group(1), m.group(2), m.group(3)
        if not any(n.lower() in name.lower() for n in names):
            continue
        start = m.end()
        # find matching closing brace
        depth = 1; i = start
        while i < len(sc) and depth:
            if sc[i] == '{': depth += 1
            elif sc[i] == '}': depth -= 1
            i += 1
        body = sc[start:i-1]
        # strip comments and blank lines
        body = re.sub(r'//[^\n]*', '', body)
        body = re.sub(r'/\*.*?\*/', '', body, flags=re.S)
        lines = [l.strip() for l in body.split('\n') if l.strip()]
        out.append(f"  fn {name}({args.strip()[:40]}){(' ' + mods.strip()[:50]) if mods.strip() else ''} :: " + " | ".join(lines[:6])[:260])
    return out

for a in segA:
    r = wl[a]
    d = load(a)
    print("=" * 120)
    print(f"{str(r.get('name'))[:40]:42s} live={r.get('live_eth') or 0:9.3f} {a}")
    print(f"  index: {(r.get('desc') or '')[:160]}")
    if not d:
        print("  (no source)")
        continue
    sc = d.get('source_code') or ''
    if not sc.strip():
        print("  (unverified / empty source)")
        continue
    for b in bodies(sc)[:8]:
        print(b)

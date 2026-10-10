#!/usr/bin/env python3
"""Show context windows around patterns in .uplc files. Usage: python3 ctx.py <file> <pattern> [window] [maxhits]"""
import sys, re
f, pat = sys.argv[1], sys.argv[2]
win = int(sys.argv[3]) if len(sys.argv) > 3 else 1500
maxhits = int(sys.argv[4]) if len(sys.argv) > 4 else 3
txt = open(f).read()
flat = re.sub(r'\s+', ' ', txt)
hits = [m.start() for m in re.finditer(re.escape(pat), flat)]
print(f"{len(hits)} hits of {pat!r} in {f}")
for i, h in enumerate(hits[:maxhits]):
    print(f"----- hit {i+1} -----")
    print(flat[max(0, h-win//2):h+win//2])

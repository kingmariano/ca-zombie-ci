#!/usr/bin/env python3
"""Token-level semantic diff of two Solidity files (comments/whitespace-insensitive)."""
import re, sys, difflib

def toks(path):
    s = open(path).read()
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//[^\n]*', '', s)
    out = []
    for t in re.findall(r'[A-Za-z_$][A-Za-z0-9_$]*|\d+(?:\.\d+)?|0[xX][0-9a-fA-F]+|[^\s]', s):
        if not t.isspace():
            out.append(t)
    return out

a = toks(sys.argv[1]); b = toks(sys.argv[2])
sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
n = 0
for op, i1, i2, j1, j2 in sm.get_opcodes():
    if op == 'equal':
        continue
    old = ' '.join(a[i1:i2])[:300]
    new = ' '.join(b[j1:j2])[:300]
    print(f"{op} OLD[{i1}:{i2}]: {old}")
    print(f"{op} NEW[{j1}:{j2}]: {new}")
    n += 1
    if n > 80:
        print('... more diffs suppressed')
        break
print(f"== {n} opcodes shown / ratio={sm.ratio():.4f}")

#!/usr/bin/env python3
"""Parse exported function names from a wasm binary (read-only static analysis)."""
import sys, struct

def leb(data, pos):
    r = 0; s = 0
    while True:
        b = data[pos]; pos += 1
        r |= (b & 0x7f) << s
        if not (b & 0x80): return r, pos
        s += 7

path = sys.argv[1]
data = open(path, "rb").read()
assert data[:4] == b"\x00asm", "not wasm"
pos = 8
names = []
while pos < len(data):
    sid = data[pos]; pos += 1
    size, pos = leb(data, pos)
    end = pos + size
    if sid == 7:  # export section
        cnt, p = leb(data, pos)
        for _ in range(cnt):
            n, p = leb(data, p)
            name = data[p:p+n].decode("utf-8", "replace"); p += n
            kind = data[p]; p += 1
            idx, p = leb(data, p)
            if kind == 0:
                names.append(name)
    pos = end
print("\n".join(sorted(set(names))))

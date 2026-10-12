#!/usr/bin/env python3
"""Analyze deployed locker wasm (code 1178): find data offsets of key strings,
locate the functions referencing them, and check whether the `unstake` handler
calls the `check_owner` guard function."""
import re, struct, sys

WASM = "/tmp/opencode/code-1178.wasm"
WAT = "/tmp/opencode/l1178.wat"

def leb(data, i):
    r = s = 0
    while True:
        b = data[i]; i += 1
        r |= (b & 0x7f) << s
        if not (b & 0x80): break
        s += 7
    return r, i

def sections(data):
    i = 8
    out = {}
    while i < len(data):
        sid = data[i]; i += 1
        size, i = leb(data, i)
        out.setdefault(sid, []).append(data[i:i+size])
        i += size
    return out

data = open(WASM, "rb").read()
secs = sections(data)
# data section id = 11; entries: count, then each: flags, offset expr, size, bytes
datasec = secs[11][0]
i = 0
n, i = leb(datasec, i)
strings = {}
for _ in range(n):
    flags, i = leb(datasec, i)
    if flags == 0:
        # offset expr: i32.const N end
        op = datasec[i]; i += 1
        assert op == 0x41
        off, i = leb(datasec, i)
        end = datasec[i]; i += 1
        assert end == 0x0b
        size, i = leb(datasec, i)
        blob = datasec[i:i+size]; i += size
        for key in [b"execute_unstake", b"check_owner", b"update_config", b"Unauthorized",
                    b"Invalid Owner", b"Locktime. Send Unstake Fee", b"extend_by",
                    b"update_fee_address", b"unstake", b"lp_id"]:
            pos = blob.find(key)
            if pos >= 0:
                strings.setdefault(key.decode(), []).append(off + pos)
    else:
        break
print("string offsets:")
for k, v in strings.items():
    print(f"  {k}: {[hex(x) for x in v]}")

# parse WAT: map func index -> body text; find refs
funcs = {}
cur = None
depth = 0
for line in open(WAT):
    m = re.match(r"\s*\(func \(;(\d+);\)", line)
    if m:
        cur = int(m.group(1)); funcs[cur] = []
    if cur is not None:
        funcs[cur].append(line)
        if line.strip().startswith("(func") and line.rstrip().endswith(")"):
            cur = None
        elif line.strip() == ")" and cur is not None and len(funcs[cur]) > 1:
            # crude end detection
            pass

print(f"parsed funcs: {len(funcs)}")
def find_refs(off):
    pat = f"i32.const {off}"
    hits = []
    for idx, body in funcs.items():
        if any(pat in l for l in body):
            hits.append(idx)
    return hits

for k in ["execute_unstake", "check_owner", "Unauthorized", "Invalid Owner", "extend_by"]:
    for off in strings.get(k, []):
        print(f"{k} @ {off}: funcs {find_refs(off)}")

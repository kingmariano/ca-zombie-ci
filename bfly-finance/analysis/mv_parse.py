#!/usr/bin/env python3
"""Minimal Move (Starcoin fork) module parser: resolve function-handle call targets.
Header: magic u32, version u32, table_count ULEB128, then per table:
kind u8, offset ULEB128, SIZE(byte size) ULEB128. Table data starts after headers;
offsets are relative to that point. Index widths: u8 if referenced table count <= 255 else u16.
"""
import sys, struct

def uleb(b, p):
    x = 0; s = 0
    while True:
        byte = b[p]; p += 1
        x |= (byte & 0x7f) << s
        if byte < 0x80: return x, p
        s += 7

def parse(path):
    b = open(path, "rb").read()
    assert b[:4] == bytes.fromhex("a11ceb0b"), "bad magic"
    ver = struct.unpack_from("<I", b, 4)[0]
    p = 8
    n, p = uleb(b, p)
    tables = {}
    for _ in range(n):
        kind = b[p]; p += 1
        t_off, p = uleb(b, p)
        t_size, p = uleb(b, p)
        tables[kind] = (t_off, t_size)
    base = p

    def iw(count): return 2 if count > 255 else 1
    def rd(pos, count):
        if iw(count) == 1: return b[pos], pos + 1
        return struct.unpack_from("<H", b, pos)[0], pos + 2

    # identifiers (self-delimiting)
    idents = []
    if 0x7 in tables:
        off, size = tables[0x7]; q = base + off; end = q + size
        while q < end:
            ln, q = uleb(b, q)
            idents.append(b[q:q+ln].decode("utf-8", "replace")); q += ln
    # addresses
    addrs = []
    if 0x8 in tables:
        off, size = tables[0x8]; q = base + off
        for _ in range(size // 16):
            addrs.append("0x" + b[q:q+16].hex()); q += 16
    # module handles
    mods = []
    if 0x1 in tables:
        off, size = tables[0x1]; q = base + off; end = q + size
        esz = iw(len(addrs)) + iw(len(idents))
        while q < end:
            ai, q = rd(q, len(addrs)); ni, q = rd(q, len(idents))
            mods.append((addrs[ai] if ai < len(addrs) else "?", idents[ni] if ni < len(idents) else "?"))
    # function handles: try signature-index widths 1 and 2, pick exact fit
    funcs = []
    if 0x3 in tables:
        off, size = tables[0x3]; q0 = base + off; end = q0 + size
        mi_w, ni_w = iw(len(mods)), iw(len(idents))
        best = None
        for sig_w in (1, 2):
            q = q0; out = []; ok = True
            while q < end:
                try:
                    mi = b[q]; ni = b[q+1]
                    q += 2
                    if sig_w == 1: q += 2
                    else: q += 4
                    tpc = b[q]; q += 1 + tpc
                except IndexError:
                    ok = False; break
                m = mods[mi] if mi < len(mods) else ("?", "?")
                f = idents[ni] if ni < len(idents) else "?"
                out.append((m[0], m[1], f))
            if ok and q == end:
                best = out; break
        funcs = best or []
    return ver, tables, mods, funcs, idents, addrs

if __name__ == "__main__":
    ver, tables, mods, funcs, idents, addrs = parse(sys.argv[1])
    print(f"version={ver} modules={len(mods)} funcs={len(funcs)} idents={len(idents)} addrs={len(addrs)}")
    print("addresses:", addrs)
    for i, (a, m, f) in enumerate(funcs):
        print(f"  Call[{i}] = {a}::{m}::{f}")

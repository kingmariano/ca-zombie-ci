#!/usr/bin/env python3
"""Call-graph + identifier scan across all BFly (30) and Starswap (52) modules.
Resolves every function-handle call target and searches for flash/lending/borrow patterns.
Evidence for the flash-liquidity negative result."""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mv_parse import parse

BF = "0x4ffcc98f43ce74668264a0cf6eebe42b"
DEX = "0x8c109349c6bd91411d6bc962e080c4a3"

def strings_of(path):
    b = open(path, "rb").read()
    out, cur = [], b""
    for byte in b:
        if 32 <= byte < 127: cur += bytes([byte])
        else:
            if len(cur) >= 3: out.append(cur.decode())
            cur = b""
    if len(cur) >= 3: out.append(cur.decode())
    return out

def scan_dir(d, label, own_addr):
    files = sorted(f for f in os.listdir(d) if f.endswith(".mv"))
    ext = {}
    flags = {}
    print(f"== {label}: {len(files)} modules")
    for f in files:
        path = os.path.join(d, f)
        mod = f[:-3]
        try:
            ver, tables, mods, funcs, idents, addrs = parse(path)
        except Exception as e:
            print(f"  PARSE FAIL {mod}: {e}"); continue
        ids = strings_of(path)
        hits = sorted(set(s for s in ids if re.search(r"flash|hot_?potato|callback|skim|callee|loan|lend", s, re.I)))
        if hits:
            flags[mod] = hits
        for (a, m, fn) in funcs:
            if a.lower() not in (own_addr, "0x00000000000000000000000000000001"):
                key = f"{a}::{m}::{fn}"
                ext.setdefault(key, []).append(mod)
    print(f"  external (non-0x1, non-self) call targets: {len(ext)}")
    for k in sorted(ext):
        print(f"    {k}   <- {','.join(sorted(set(ext[k])))}")
    if flags:
        print(f"  !! flash/lending identifier hits: {json.dumps(flags)}")
    else:
        print("  flash/hot-potato/callback/skim/loan/lend identifier hits: NONE")
    return ext, flags

if __name__ == "__main__":
    e1, f1 = scan_dir(os.path.join(HERE, "modules"), "BFly", BF)
    e2, f2 = scan_dir(os.path.join(HERE, "dex_modules"), "Starswap", DEX)
    json.dump({"bfly_external": {k: sorted(set(v)) for k, v in e1.items()},
               "bfly_flags": f1, "dex_external": {k: sorted(set(v)) for k, v in e2.items()},
               "dex_flags": f2},
              open(os.path.join(HERE, "callgraph_scan.json"), "w"), indent=1)
    print("\nwrote callgraph_scan.json")

#!/usr/bin/env python3
"""Enumerate all BlueMove pools (registry dynamic fields) — read-only, public GraphQL only."""
import json, sys, time
from sui import dynamic_fields

AMM = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
STABLE = "0x5a7eca40df453efe6bb1feae99e5b8fc072d1252cbd1979eb187d625dc9b47c9"

def enumerate_registry(addr, out_file):
    out, cursor, pages = [], None, 0
    t0 = time.time()
    while True:
        df = dynamic_fields(addr, first=50, after=cursor)
        for n in df.get("nodes") or []:
            v = n.get("value") or {}
            c = v.get("contents") or {}
            out.append({
                "name": (n.get("name") or {}).get("json"),
                "name_type": ((n.get("name") or {}).get("type") or {}).get("repr"),
                "value_addr": v.get("address"),
                "type": (c.get("type") or {}).get("repr"),
                "json": c.get("json"),
            })
        pages += 1
        pi = df.get("pageInfo") or {}
        if not pi.get("hasNextPage"):
            break
        cursor = pi.get("endCursor")
        if pages % 25 == 0:
            print(f"[{addr[:10]}] page {pages}, fields {len(out)}, {time.time()-t0:.0f}s", flush=True)
    with open(out_file, "w") as f:
        json.dump(out, f)
    print(f"DONE {addr}: {len(out)} fields in {pages} pages, {time.time()-t0:.0f}s", flush=True)
    return out

if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "amm"
    if which == "amm":
        enumerate_registry(AMM, "pools_all.json")
    else:
        enumerate_registry(STABLE, "stable_all.json")

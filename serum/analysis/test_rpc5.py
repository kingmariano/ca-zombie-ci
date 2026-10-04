#!/usr/bin/env python3
"""Test filter cap (max 4?) and nonce4 single query."""
import json, sys, time, urllib.request
sys.path.insert(0, "/home/heisenberg/CA/serum/analysis")
from rpc import bytes_to_b58, u64le

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"
MB = "https://api.mainnet-beta.solana.com"

def raw_rpc(method, params, timeout=180):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(MB, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw, time.time() - t0

def gpa(filters, slen=328, timeout=180):
    p = [PROGRAM, {"filters": filters, "encoding": "base64",
                   "dataSlice": {"offset": 53, "length": slen}, "commitment": "finalized"}]
    raw, dt = raw_rpc("getProgramAccounts", p, timeout=timeout)
    j = json.loads(raw)
    if "error" in j:
        raise RuntimeError(str(j["error"])[:200])
    return j["result"], len(raw), dt

FL = {"dataSize": 388}
F3 = {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(3))}}
N0 = {"memcmp": {"offset": 45, "bytes": bytes_to_b58(u64le(0))}}
B0 = {"memcmp": {"offset": 13, "bytes": bytes_to_b58(b"\x00")}}
B1 = {"memcmp": {"offset": 14, "bytes": bytes_to_b58(b"\x00")}}

tests = [
    ("4f no-nonce b0=0 b1=0", [FL, F3, B0, B1]),
    ("4f nonce0 b1=0", [FL, F3, N0, B1]),
    ("3f nonce0 (baseline)", [FL, F3, N0]),
]
for name, f in tests:
    try:
        res, nraw, dt = gpa(f, slen=0)
        print(f"{name}: n={len(res)} {nraw/1e3:.1f}KB {dt:.1f}s")
    except Exception as e:
        print(f"{name}: EXC {str(e)[:150]}")
    time.sleep(1.5)

print("--- nonce4 full ---")
try:
    res, nraw, dt = gpa([FL, F3, {"memcmp": {"offset": 45, "bytes": bytes_to_b58(u64le(4))}}], slen=328)
    print(f"nonce4: n={len(res)} {nraw/1e6:.2f}MB {dt:.1f}s")
except Exception as e:
    print(f"nonce4 EXC {str(e)[:200]}")

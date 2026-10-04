#!/usr/bin/env python3
"""Test getProgramAccounts capabilities across Solana endpoints (read-only)."""
import json, os, sys, time, urllib.request, urllib.error, base64

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import rpc, bytes_to_b58, b58_to_bytes, u64le

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"

def load_env(path="/home/heisenberg/CA/.env"):
    env = {}
    try:
        for line in open(path):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    except Exception as e:
        print("env load failed:", e)
    return env

E = load_env()

def endpoints():
    eps = []
    if E.get("ALCHEMY_API_KEY"):
        eps.append(("alchemy", f"https://solana-mainnet.g.alchemy.com/v2/{E['ALCHEMY_API_KEY']}"))
    if E.get("ANKR_API_KEY"):
        eps.append(("ankr", f"https://rpc.ankr.com/solana/{E['ANKR_API_KEY']}"))
    eps.append(("publicnode", "https://solana-rpc.publicnode.com"))
    eps.append(("mainnet-beta", "https://api.mainnet-beta.solana.com"))
    return eps

def raw_rpc(ep, method, params, timeout=60):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(ep, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw, time.time() - t0

def trial(name, ep, label):
    flags = bytes_to_b58(u64le(3))
    nonce0 = bytes_to_b58(u64le(0))
    filt = [
        {"dataSize": 388},
        {"memcmp": {"offset": 5, "bytes": flags}},
        {"memcmp": {"offset": 45, "bytes": nonce0}},
        {"memcmp": {"offset": 13, "bytes": bytes_to_b58(b"\x00")}},
    ]
    params = [PROGRAM, {"filters": filt, "encoding": "base64",
                        "dataSlice": {"offset": 53, "length": 0},
                        "commitment": "finalized"}]
    try:
        raw, dt = raw_rpc(ep, "getProgramAccounts", params, timeout=90)
        j = json.loads(raw)
        if "error" in j:
            print(f"[{label}] ERROR {str(j['error'])[:200]} ({dt:.1f}s)")
            return
        res = j.get("result")
        n = len(res) if isinstance(res, list) else "?"
        print(f"[{label}] OK count={n} raw={len(raw)/1e6:.2f}MB {dt:.1f}s")
    except Exception as e:
        print(f"[{label}] EXC {str(e)[:200]}")

if __name__ == "__main__":
    for name, ep in endpoints():
        trial(name, ep, name)

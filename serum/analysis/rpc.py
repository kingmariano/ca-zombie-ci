#!/usr/bin/env python3
"""Minimal Solana JSON-RPC helper (read-only). Endpoints from env or defaults.
No secrets are printed. Used by the H-22 Serum/OpenBook audit."""
import json, os, sys, time, urllib.request, urllib.error

ENDPOINTS = []
for name in ("SOLANA_RPC_URLS", "SOLANA_RPC_URL"):
    v = os.environ.get(name)
    if v:
        ENDPOINTS += [u.strip() for u in v.split(",") if u.strip()]
ENDPOINTS += [
    "https://solana-rpc.publicnode.com",
    "https://api.mainnet-beta.solana.com",
]
# dedupe preserve order
seen = set(); EPS = []
for e in ENDPOINTS:
    if e not in seen:
        seen.add(e); EPS.append(e)

def rpc(method, params, tries=4, timeout=120, endpoints=None):
    eps = endpoints or EPS
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for attempt in range(tries):
        for ep in eps:
            try:
                req = urllib.request.Request(ep, data=body, headers={
                    "Content-Type": "application/json",
                    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    j = json.loads(r.read().decode())
                if "error" in j:
                    last = (ep, j["error"])
                    # rate-limited or excluded -> back off / next endpoint
                    continue
                return j.get("result")
            except Exception as e:  # noqa
                last = (ep, str(e))
        time.sleep(2.0 * (attempt + 1) + 1.0)
    raise RuntimeError(f"rpc {method} failed; last={last}")

def b58_to_bytes(s):
    alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    n = 0
    for ch in s:
        n = n * 58 + alpha.index(ch)
    b = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    pad = len(s) - len(s.lstrip("1"))
    return b"\x00" * pad + b

def bytes_to_b58(b):
    alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    n = int.from_bytes(b, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = alpha[r] + out
    pad = len(b) - len(b.lstrip(b"\x00"))
    return "1" * pad + out

def u64le(x):
    return x.to_bytes(8, "little")

if __name__ == "__main__":
    # CLI: python3 rpc.py <method> '<json params>'
    m = sys.argv[1]
    p = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
    print(json.dumps(rpc(m, p), indent=1)[:200000])

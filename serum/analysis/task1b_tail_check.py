#!/usr/bin/env python3
"""Tail check: verify no initialized markets exist at large/edge nonce values.
Counts only (dataSlice len 0, own byte0 chunking where needed)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import bytes_to_b58, u64le

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"
RPC = "https://api.mainnet-beta.solana.com"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nonce_tail_check.json")

def rpc(method, params, timeout=180, tries=6):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                j = json.loads(r.read().decode())
            if "error" in j:
                raise RuntimeError(str(j["error"])[:200])
            return j["result"]
        except Exception as e:
            last = e
            time.sleep(min(45, 2 * (2 ** a)))
    raise RuntimeError(str(last))

def count_nonce(n):
    p = [PROGRAM, {"filters": [{"dataSize": 388},
                               {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(3))}},
                               {"memcmp": {"offset": 45, "bytes": bytes_to_b58(u64le(n))}}],
                   "encoding": "base64", "dataSlice": {"offset": 0, "length": 0},
                   "commitment": "finalized"}]
    return len(rpc("getProgramAccounts", p))

def main():
    out = {}
    for n in (22, 23, 24, 25, 30, 32, 40, 64, 100, 255, 256, 1000, 65535, 1000000,
              2**32, 2**32 + 7, 2**63, 2**64 - 1):
        try:
            out[str(n)] = count_nonce(n)
            print(f"nonce {n}: {out[str(n)]}", flush=True)
        except Exception as e:
            out[str(n)] = f"ERR {str(e)[:80]}"
            print(f"nonce {n}: ERR {str(e)[:80]}", flush=True)
        time.sleep(0.3)
    with open(OUT, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", OUT)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Tiny JSON-RPC batch helper for C-25 analysis (read-only)."""
import json, sys, time, urllib.request

URL = sys.argv[1] if len(sys.argv) > 1 else "https://ethereum-rpc.publicnode.com"

def rpc_batch(calls, url=URL, retries=4):
    payload = []
    for i, (method, params) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i + 1, "method": method, "params": params})
    data = json.dumps(payload).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(url, data=data, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 c25-research",
            })
            with urllib.request.urlopen(req, timeout=45) as r:
                out = json.loads(r.read().decode())
            byid = {o["id"]: o.get("result") for o in out}
            return [byid.get(i + 1) for i in range(len(calls))]
        except Exception as e:
            if a == retries - 1:
                raise
            time.sleep(1.5 * (a + 1))

def call(to, data, block="latest"):
    return ("eth_call", [{"to": to, "data": data}, block])

def slot(addr, s, block="latest"):
    return ("eth_getStorageAt", [addr, s, block])

if __name__ == "__main__":
    calls = json.load(sys.stdin)
    res = rpc_batch([(c[0], c[1]) for c in calls])
    print(json.dumps(res, indent=2))

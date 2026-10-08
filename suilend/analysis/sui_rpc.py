#!/usr/bin/env python3
"""Minimal Sui JSON-RPC helper with endpoint failover (read-only)."""
import json, sys, urllib.request

ENDPOINTS = [
    "https://sui.publicnode.com",
    "https://mainnet.sui.rpcpool.com",
    "https://sui-rpc.publicnode.com",
]

def rpc(method, params, endpoint=None):
    eps = [endpoint] if endpoint else ENDPOINTS
    last = None
    for ep in eps:
        if not ep:
            continue
        try:
            req = urllib.request.Request(
                ep,
                data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=35) as r:
                j = json.loads(r.read())
            if "error" in j:
                last = j
                continue
            return j.get("result")
        except Exception as e:  # noqa
            last = str(e)
    return {"_error": last}

if __name__ == "__main__":
    method = sys.argv[1]
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
    print(json.dumps(rpc(method, params), indent=1))

#!/usr/bin/env python3
"""Batch JSON-RPC helper for Hedera (public endpoints only; no keys).
Usage: python3 rpc.py <batch.json>   or import and use call_batch().
Respects rate limits with small sleeps. Never prints secrets (none used)."""
import json, sys, time, urllib.request

RPC = "https://mainnet.hashio.io/api"
MIRROR = "https://mainnet-public.mirrornode.hedera.com"

def rpc_batch(calls, rpc=RPC, chunk=10, sleep=0.4):
    """calls: list of (method, params). returns list of results (or {'error':...})"""
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc":"2.0","id":j,"method":m,"params":p} for j,(m,p) in enumerate(part)]
        data = json.dumps(payload).encode()
        req = urllib.request.Request(rpc, data=data, headers={"Content-Type":"application/json","User-Agent":"zombie-research/1.0"})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.loads(r.read().decode())
                break
            except Exception as e:
                if attempt == 3: raise
                time.sleep(1.5*(attempt+1))
        byid = {x.get("id"): x for x in res}
        for j in range(len(part)):
            x = byid.get(j, {})
            out.append(x.get("result") if "result" in x else {"error": x.get("error")})
        time.sleep(sleep)
    return out

def eth_call(to, data, block="latest"):
    return ("eth_call", [{"to": to, "data": data}, block])

def call_batch(calls, **kw):
    return rpc_batch(calls, **kw)

if __name__ == "__main__":
    src = json.load(open(sys.argv[1]))
    calls = [(c["method"], c["params"]) for c in src]
    res = rpc_batch(calls)
    print(json.dumps(res, indent=1))

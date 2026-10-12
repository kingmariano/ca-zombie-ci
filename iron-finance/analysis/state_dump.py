#!/usr/bin/env python3
"""Read-only Iron Finance state dump via PUBLIC RPCs (no keys). Polygon focus.
Writes JSON to stdout; caller redirects into analysis/.
"""
import json, urllib.request, sys, time

RPCS = {
    "polygon": "https://polygon-bor-rpc.publicnode.com",
    "avalanche": "https://avalanche-c-chain-rpc.publicnode.com",
}

def rpc(url, calls):
    """calls: list of (to, data). Batch JSON-RPC."""
    batch = []
    for i, (to, data) in enumerate(calls):
        batch.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                      "params": [{"to": to, "data": data}, "latest"]})
    req = urllib.request.Request(url, data=json.dumps(batch).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0 (research; read-only)"})
    out = json.load(urllib.request.urlopen(req, timeout=60))
    res = {}
    for r in out:
        res[r["id"]] = r.get("result", r.get("error"))
    return res

def sel(sig):
    import hashlib
    return "0x" + hashlib.sha3_256(sig.encode()).hexdigest()[:8] if False else None

# keccak via eth_hash alternative: use precomputed selectors
SEL = {
    "paused()": "0x5c975abb",
    "owner()": "0x8da5cb5b",
    "feeController()": "0x8db3dcda",  # guess? verify below
    "feeDistributor()": "0xbf0c22c4",  # guess? verify below
    "getVirtualPrice()": "0xbb7b8b80",  # guess
    "getA()": "0x1ef1192e",  # guess
    "getLpToken()": "0x1c9e31b9",  # guess
    "getTokens()": "0xaa6ca808",  # guess
    "getTokenBalances()": "0xd4b0c4c2",  # guess
    "getAdminBalances()": "0x4c1a1e37",  # guess
    "totalSupply()": "0x18160ddd",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "name()": "0x06fdde03",
    "swapStorage()": "0x0099a6ea",  # guess
}

if __name__ == "__main__":
    print("placeholder")

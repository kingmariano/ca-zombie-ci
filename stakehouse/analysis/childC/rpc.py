#!/usr/bin/env python3
"""Lightweight JSON-RPC helper for read-only research (no secrets written to disk).
Reads endpoints from env at runtime; never logs the endpoint URL."""
import json, os, sys, time, urllib.request

ENDPOINTS = ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org"]
for k in ("RPC_URL", "BLOCKPI_RPC_URL", "NODEREAL_ETH_RPC_URL"):
    v = os.environ.get(k)
    if v:
        ENDPOINTS.append(v)

def _post(url, payload, timeout=25):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "zombie-research/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def rpc(method, params, tries=6):
    last = None
    for i in range(tries):
        url = ENDPOINTS[i % len(ENDPOINTS)]
        try:
            out = _post(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
            if "result" in out:
                return out["result"]
            last = out.get("error")
        except Exception as e:
            last = str(e)
        time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"rpc {method} failed: {last}")

def batch(calls, tries=6):
    """calls: list of (method, params) -> list of results (None on per-call error)"""
    last = None
    for i in range(tries):
        url = ENDPOINTS[i % len(ENDPOINTS)]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(calls)]
        try:
            out = _post(url, payload, timeout=40)
            if isinstance(out, list):
                res = [None] * len(calls)
                for item in out:
                    res[item["id"]] = item.get("result")
                return res
            last = out
        except Exception as e:
            last = str(e)
        time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"batch failed: {last}")

def block_number():
    return int(rpc("eth_blockNumber", []), 16)

def balance(addr, block="latest"):
    return int(rpc("eth_getBalance", [addr, block]), 16)

def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])

def code(addr, block="latest"):
    return rpc("eth_getCode", [addr, block])

if __name__ == "__main__":
    print("block", block_number())

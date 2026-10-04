#!/usr/bin/env python3
"""Read-only JSON-RPC helper for multi-chain state reads. No signing, no sending."""
import json, sys, time, urllib.request

RPC = {
    "pulse": "https://rpc.pulsechain.com",
    "sonic": "https://rpc.soniclabs.com",
    "hyper": "https://rpc.hyperliquid.xyz/evm",
    "eth": "https://ethereum-rpc.publicnode.com",
}

def rpc(url, method, params, _id=1):
    req = urllib.request.Request(url, data=json.dumps({
        "jsonrpc": "2.0", "id": _id, "method": method, "params": params
    }).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        out = json.load(r)
    if "error" in out:
        return {"error": out["error"]}
    return out.get("result")

def batch(url, calls, chunk=30):
    """calls: list of (method, params). Returns list of results (or {'error':..}). Chunked."""
    results = []
    for start in range(0, len(calls), chunk):
        part = calls[start:start+chunk]
        payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
                   for i, (m, p) in enumerate(part)]
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=180) as r:
                    out = json.load(r)
                break
            except Exception as e:
                if attempt == 2:
                    raise
                time.sleep(2)
        res = [None] * len(part)
        for item in out:
            if "error" in item:
                res[item["id"]] = {"error": item["error"]}
            else:
                res[item["id"]] = item.get("result")
        results.extend(res)
    return results

def eth_call(url, to, data, block="latest"):
    return rpc(url, "eth_call", [{"to": to, "data": data}, block])

def eth_getCode(url, addr, block="latest"):
    return rpc(url, "eth_getCode", [addr, block])

def eth_getBalance(url, addr, block="latest"):
    return rpc(url, "eth_getBalance", [addr, block])

def addr(x):
    return "0x" + x[-40:].lower()

if __name__ == "__main__":
    for name, url in RPC.items():
        print(name, rpc(url, "eth_blockNumber", []))

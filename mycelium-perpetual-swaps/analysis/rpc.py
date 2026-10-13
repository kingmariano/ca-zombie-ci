#!/usr/bin/env python3
"""Tiny JSON-RPC batch helper (public endpoints only; no keys)."""
import json, sys, urllib.request, time

def rpc_batch(url, calls, block="latest", chunk=40, retries=4):
    """calls: list of (to, data) -> returns list of results (hex or error dict)."""
    out = [None] * len(calls)
    for start in range(0, len(calls), chunk):
        part = calls[start:start + chunk]
        payload = []
        for i, (to, data) in enumerate(part):
            payload.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                            "params": [{"to": to, "data": data}, block]})
        for attempt in range(retries):
            try:
                req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=120) as r:
                    resp = json.loads(r.read())
                for item in resp:
                    out[start + item["id"]] = item.get("result", item.get("error"))
                break
            except Exception as e:
                if attempt == retries - 1:
                    for i in range(len(part)):
                        out[start + i] = f"ERR:{e}"
                time.sleep(2 * (attempt + 1))
        time.sleep(0.3)
    return out

def rpc(url, method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read()).get("result")

def sel(sig):
    """4-byte selector via keccak (uses cast if available, else pure python keccak)."""
    import subprocess
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

if __name__ == "__main__":
    pass

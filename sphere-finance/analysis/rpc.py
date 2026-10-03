#!/usr/bin/env python3
"""Batched JSON-RPC helper for Polygon reads."""
import json, os, sys, time, urllib.request

RPCS = []
_env = "/home/heisenberg/CA/.env"
if os.path.exists(_env):
    for line in open(_env):
        line = line.strip()
        if "=" not in line or line.startswith("#"):
            continue
        name, val = line.split("=", 1)
        val = val.strip().strip('"').strip("'")
        if name == "ALCHEMY_API_KEY" and val:
            RPCS.append(f"https://polygon-mainnet.g.alchemy.com/v2/{val}")
        if name == "QUICKNODE_API_KEY" and val:
            RPCS.append(f"https://falling-withered-morning.matic.quiknode.pro/{val}")
        if name == "DRPC_API_KEY" and val:
            RPCS.append(f"https://polygon.drpc.org?dkey={val}")
RPCS.append("https://polygon.gateway.tenderly.co")
RPCS.append("https://polygon-bor-rpc.publicnode.com")
RPCS.append("https://polygon.llamarpc.com")

def _post(url, payload, timeout=90):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)

def rpc(method, params, url=None):
    urls = [url] if url else RPCS
    last = None
    for u in urls:
        try:
            d = _post(u, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
            if "result" in d:
                return d["result"]
            last = d
        except Exception as e:
            last = e
    raise RuntimeError(f"all RPCs failed for {method}: {last}")

def batch(calls, url=None):
    """calls: list of (method, params). Returns list of results in order. Falls back to per-call."""
    urls = [url] if url else RPCS
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    last = None
    for u in urls:
        for attempt in range(2):
            try:
                d = _post(u, payload)
                if isinstance(d, list):
                    out = {x["id"]: x.get("result") for x in d if "id" in x}
                    return [out.get(i) for i in range(len(calls))]
                last = d
                break
            except Exception as e:
                last = e
                time.sleep(0.4 * (attempt + 1))
    # fallback: individual calls
    res = []
    ok = True
    for m, p in calls:
        try:
            res.append(rpc(m, p, url=urls[0] if url else None))
        except Exception as e:
            res.append(None)
            ok = False
            last = e
    if not ok and all(x is None for x in res):
        raise RuntimeError(f"all RPCs failed for batch: {last}")
    return res

def call(to, data, block="latest", url=None):
    return rpc("eth_call", [{"to": to, "data": data}, block], url)

def block_number(url=None):
    return int(rpc("eth_blockNumber", [], url), 16)

def bal(addr, block="latest", url=None):
    return int(rpc("eth_getBalance", [addr, block], url), 16)

def code(addr, block="latest", url=None):
    return rpc("eth_getCode", [addr, block], url)

def storage(addr, slot, block="latest", url=None):
    return rpc("eth_getStorageAt", [addr, slot, block], url)

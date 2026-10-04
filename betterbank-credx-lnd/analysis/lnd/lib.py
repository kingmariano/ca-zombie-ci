#!/usr/bin/env python3
import json, sys, time, urllib.request

SONIC_ENDPOINTS = [
    "https://sonic-rpc.publicnode.com",
    "https://sonic.drpc.org",
    "https://146.rpc.thirdweb.com",
    "https://rpc.soniclabs.com",
]
HL_ENDPOINTS = [
    "https://rpc.hyperliquid.xyz/evm",
    "https://rpc.hyperliquid-evm.xyz",  # may not exist
]
SONIC = SONIC_ENDPOINTS[0]
HL = HL_ENDPOINTS[0]

def _post(url, method, params, timeout=60):
    payload = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=payload, headers={"Content-Type":"application/json","User-Agent":"curl/8.5.0","Accept":"application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def rpc(url, method, params, retries=6, timeout=60):
    endpoints = SONIC_ENDPOINTS if "sonic" in url else ([url] if url else HL_ENDPOINTS)
    last = None
    for i in range(retries):
        u = endpoints[i % len(endpoints)]
        try:
            out = _post(u, method, params, timeout)
            if "error" in out:
                # don't retry on deterministic errors (revert etc.)
                if isinstance(out["error"], dict) and out["error"].get("code") in (-32000, 3):
                    raise RuntimeError(f"RPC error {method} {params}: {out['error']}")
                raise RuntimeError(f"RPC retryable error {method}: {out['error']}")
            return out.get("result")
        except RuntimeError:
            raise
        except Exception as e:
            last = e
            time.sleep(1.2 * (i + 1))
    raise last

def call(url, to, data, block="latest", frm=None):
    p = {"to": to, "data": data}
    if frm: p["from"] = frm
    return rpc(url, "eth_call", [p, hex(block) if isinstance(block,int) else block])

def balance(url, addr, block="latest"):
    return rpc(url, "eth_getBalance", [addr, hex(block) if isinstance(block,int) else block])

def storage(url, addr, slot, block="latest"):
    return rpc(url, "eth_getStorageAt", [addr, hex(slot), hex(block) if isinstance(block,int) else block])

def blocknum(url):
    return int(rpc(url, "eth_blockNumber", []), 16)

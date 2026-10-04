#!/usr/bin/env python3
"""Batch JSON-RPC helper for read-only state pulls. No writes."""
import json, sys, time
import requests
from eth_abi import decode as abi_decode
from eth_utils import keccak

RPCS = ["https://andromeda.metis.io/?owner=1088", "https://metis.drpc.org"]

def selector(sig):
    return keccak(text=sig)[:4].hex()

BLOCK = hex(23238719)

def rpc_batch(calls, block=BLOCK, batch_size=100, rpc=None):
    """calls: list of (to, data_hex_without_0x). Returns list of results (hex or None)."""
    urls = [rpc] if rpc else RPCS
    out = []
    for url in urls:
        try:
            for i in range(0, len(calls), batch_size):
                chunk = calls[i:i+batch_size]
                payload = []
                for j, (to, data) in enumerate(chunk):
                    payload.append({
                        "jsonrpc": "2.0", "id": i+j, "method": "eth_call",
                        "params": [{"to": to, "data": "0x"+data}, block],
                    })
                r = requests.post(url, json=payload, timeout=60)
                r.raise_for_status()
                res = r.json()
                by_id = {x["id"]: x for x in res}
                for j in range(len(chunk)):
                    x = by_id.get(i+j)
                    out.append(x.get("result") if x and "result" in x else None)
                time.sleep(0.05)
            return out
        except Exception as e:
            print(f"[rpc_batch] {url} failed: {e}", file=sys.stderr)
            out = []
    return out

def call(to, sig, args_hex=""):
    return (to, selector(sig) + args_hex)

def enc_addr(a):
    return "0"*24 + a.lower().replace("0x", "")

def dec_uints(results):
    out = []
    for r in results:
        if r and r != "0x":
            out.append(int(r, 16))
        else:
            out.append(None)
    return out

if __name__ == "__main__":
    # quick self-test: METIS totalSupply at pinned block
    to = "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000"
    calls = [call(to, "totalSupply()")]
    res = rpc_batch(calls, block=hex(23238719))
    print("totalSupply result:", res)
    if res and res[0]:
        print("decoded:", int(res[0], 16))

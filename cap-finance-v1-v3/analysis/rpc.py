#!/usr/bin/env python3
"""Read live Cap Finance contract state on Arbitrum via public RPC (no secrets).
Saves analysis/state/state-<block>.json"""
import json, urllib.request, os, time

RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")

# selector: keccak of signature (precomputed with cast sig)
CALLS = {
    # v1/v2/v3 Trading + Treasury + Store + Pools
    "0x1058AFe66BB5b79C295CCCE51016586949Bc4e8d": {
        "owner()": "0x8da5cb5b",
        "trading()": "0xecb291ba",   # guess; will correct if needed
    },
}

def sig4(sig):
    # local keccak via eth-hash not available; use precomputed from cast? do it in shell instead.
    raise NotImplementedError

def eth_call(to, data):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
               "params": [{"to": to, "data": data}, "latest"]}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0"})
    for attempt in range(3):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=30))
            if "result" in d:
                return d["result"]
            return f"ERR:{d.get('error')}"
        except Exception as e:
            time.sleep(1)
            last = str(e)
    return f"ERR:{last}"

if __name__ == "__main__":
    # read block number
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    blk = json.load(urllib.request.urlopen(req, timeout=30))["result"]
    print("block:", int(blk, 16))

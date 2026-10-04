#!/usr/bin/env python3
"""Small JSON-RPC helper for Silicon L2 + Ethereum reads. Read-only."""
import json, sys, urllib.request

SILICON = "https://rpc.silicon.network"
ETH = "https://ethereum-rpc.publicnode.com"
FALLBACK_ETH = ["https://eth.drpc.org", "https://1rpc.io/eth", "https://ethereum-rpc.publicnode.com"]

def rpc(url, method, params, timeout=30):
    req = urllib.request.Request(
        url,
        data=json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
    )
    return json.load(urllib.request.urlopen(req, timeout=timeout))

def eth_call(url, to, data, block="latest"):
    return rpc(url, "eth_call", [{"to": to, "data": data}, block])["result"]

def eth_getCode(url, addr, block="latest"):
    return rpc(url, "eth_getCode", [addr, block])["result"]

def eth_getStorageAt(url, addr, slot, block="latest"):
    return rpc(url, "eth_getStorageAt", [addr, slot, block])["result"]

def block_number(url):
    return int(rpc(url, "eth_blockNumber", [])["result"], 16)

def pad32(hexstr):
    h = hexstr[2:] if hexstr.startswith("0x") else hexstr
    return h.rjust(64, "0")

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "code":
        print(eth_getCode(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "latest"))
    elif cmd == "call":
        print(eth_call(sys.argv[2], sys.argv[3], sys.argv[4]))
    elif cmd == "storage":
        print(eth_getStorageAt(sys.argv[2], sys.argv[3], sys.argv[4]))
    elif cmd == "block":
        print(block_number(sys.argv[2] if len(sys.argv) > 2 else SILICON))

#!/usr/bin/env python3
"""Batch-read storage slots of a contract via public RPC. Read-only. No secrets."""
import json, sys, urllib.request

RPCS = {
 "ethereum": "https://ethereum-rpc.publicnode.com",
 "polygon": "https://polygon-bor-rpc.publicnode.com",
 "bsc": "https://bsc-rpc.publicnode.com",
 "optimism": "https://optimism-rpc.publicnode.com",
 "arbitrum": "https://arbitrum-one-rpc.publicnode.com",
 "avalanche": "https://api.avax.network/ext/bc/C/rpc",
}
def rpc(url, method, params):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=30))["result"]

def main():
    chain, addr, start, end = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    url = RPCS[chain]
    for i in range(start, end+1):
        slot = "0x" + format(i, "064x")
        v = rpc(url, "eth_getStorageAt", [addr, slot, "latest"])
        if v != "0x" + "00"*32:
            # annotate if it looks like an address
            ann = ""
            hv = v[2:]
            if hv[:24] == "0"*24 and hv[24:] != "0"*40:
                ann = "  addr=0x"+hv[24:]
            print(f"slot {i:3d} = {v}{ann}")
        else:
            print(f"slot {i:3d} = 0x0")

if __name__ == "__main__":
    main()

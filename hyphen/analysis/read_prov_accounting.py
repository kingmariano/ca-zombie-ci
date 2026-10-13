#!/usr/bin/env python3
"""Read LiquidityProviders accounting mappings for a token list. Read-only, public RPCs."""
import json, sys, urllib.request, subprocess

RPCS = {
 "ethereum": "https://ethereum-rpc.publicnode.com",
 "polygon": "https://polygon-bor-rpc.publicnode.com",
 "bsc": "https://bsc-rpc.publicnode.com",
 "optimism": "https://optimism-rpc.publicnode.com",
 "arbitrum": "https://arbitrum-one-rpc.publicnode.com",
 "avalanche": "https://api.avax.network/ext/bc/C/rpc",
}
PROV = {
 "ethereum": "0xebab24f13de55789ec1f3ffe99a285754e15f7b9",
 "polygon": "0xebab24f13de55789ec1f3ffe99a285754e15f7b9",
 "avalanche": "0xebab24f13de55789ec1f3ffe99a285754e15f7b9",
 "bsc": "0x279ac60785a2fcb85550eb243b9a42a543171cc7",
 "optimism": "0xb4778f5aefeb4605ed96e893417271d4a55e32ee",
 "arbitrum": "0xb4778f5aefeb4605ed96e893417271d4a55e32ee",
}
NATIVE = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

def rpc(url, method, params):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=40))["result"]

def map_slot(key_hex, slot):
    # keccak256(abi.encode(key, slot)) -> storage slot
    out = subprocess.check_output(["cast", "keccak", key_hex + format(slot,"064x")]).decode().strip()
    return out

def main():
    chain = sys.argv[1]; tokens = sys.argv[2:]
    url = RPCS[chain]; prov = PROV[chain]
    slots = {"totalReserve":256,"totalLiquidity":257,"currentLiquidity":258,"totalLPFees":259,"totalSharesMinted":260}
    print(f"== {chain} providers={prov}")
    for tok in tokens:
        key = tok[2:].lower().rjust(64,"0")
        row = [tok]
        for name, slot in slots.items():
            s = map_slot(key, slot)
            v = rpc(url, "eth_getStorageAt", [prov, s, "latest"])
            row.append(f"{name}={int(v,16)}")
        print("  " + "  ".join(row))

if __name__ == "__main__":
    main()

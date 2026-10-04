#!/usr/bin/env python3
"""Check which chains have code at Orbit Bridge addresses (read-only)."""
import json, urllib.request

RPCS = {
 "ethereum": "https://ethereum-rpc.publicnode.com",
 "bsc": "https://bsc-rpc.publicnode.com",
 "polygon": "https://polygon-bor-rpc.publicnode.com",
 "kaia": "https://public-en.node.kaia.io",
 "avalanche": "https://avalanche-c-chain-rpc.publicnode.com",
 "fantom": "https://fantom-rpc.publicnode.com",
 "celo": "https://celo-rpc.publicnode.com",
 "gnosis": "https://gnosis-rpc.publicnode.com",
}
ADDRS = {
 "OrbitHub": "0xb5680a55d627c52de992e3ea52a86f19da475399",
 "EthBridge": "0x78d80c33f23a3395c52b3a8c0d0b12253771b9f7",
 "BscBridge": "0x89c527764f03BCb7dC469707B23b79C1D7Beb780",
 "KlaytnBridge": "0x1af95905bb0042803f90e36d79d13aea6cd58969",
 "PolygonBridge": "0x1Fc5A2cE72c71563E6EFC1fc35F326D4CCd23B93",
 "HecoBridge": "0xE7688F64e96A733EaDdCb5850392347e67Bb197f",
 "CeloBridge": "0x9fae958393B59ccb5e707B274615e214c8BD0AE1",
 "CommonMinter": "0x6BD8E3beEC87176BA9c705c9507Aa5e6F0E6706f",
 "EthVault": "0x1Bf68A9d1EaEe7826b3593C20a0Ca93293cb489a",
 "ORC": "0x662b67d00a13faf93254714dd601f5ed49ef2f51",
}
_id=[0]
def rpc(url, method, params):
    _id[0]+=1
    req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":_id[0],"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (X11; Linux x86_64) research/1.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)

if __name__ == "__main__":
    for chain, url in RPCS.items():
        try:
            bn = rpc(url, "eth_chainId", [])["result"]
        except Exception as e:
            print(f"{chain:10} RPC ERR {str(e)[:60]}"); continue
        row=[]
        for name, addr in ADDRS.items():
            try:
                c = rpc(url, "eth_getCode", [addr, "latest"])["result"]
                if c and c != "0x":
                    row.append(f"{name}({len(c)//2-1})")
            except Exception as e:
                row.append(f"{name}=ERR")
        print(f"{chain:10} chainId={int(bn,16):7} code: {', '.join(row) if row else '-'}")

#!/usr/bin/env python3
"""Compare locally compiled runtime bytecode vs on-chain code.
Strips the CBOR metadata suffix before comparing. Read-only, public RPC."""
import json, urllib.request, sys

RPC = "https://polygon-bor-rpc.publicnode.com"

def getcode(addr):
    req = urllib.request.Request(RPC, data=json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": "eth_getCode",
        "params": [addr, "latest"]}).encode(),
        headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=60))["result"]

def strip_metadata(code_hex):
    b = bytes.fromhex(code_hex[2:])
    # metadata: ...0xa2 0x64 'ipfs' 0x58 0x22 0x12 0x20 <32B> 0x64 'solc' 0x43 <version> 0x00 0x33
    # find last occurrence of the ipfs marker
    idx = b.rfind(bytes.fromhex("a26469706673"))  # 0xa2 0x64 'ipfs'
    if idx > 0:
        return b[:idx].hex()
    return b.hex()

def main():
    art = json.load(open("poc/out/IronSwap.sol/IronSwap.json"))
    local = art["deployedBytecode"]["object"]
    if local.startswith("0x"):
        local = local[2:]
    onchain = getcode("0x837503e8a8753ae17fb8c8151b8e6f586defcb57")
    l = strip_metadata(local)
    o = strip_metadata(onchain)
    print("local len:", len(l)//2, "onchain len:", len(o)//2)
    if l == o:
        print("MATCH: runtime bytecode identical (excluding metadata)")
    else:
        # find first difference
        n = min(len(l), len(o))
        i = 0
        while i < n and l[i] == o[i]:
            i += 1
        print(f"DIFFER at byte offset {i//2} (hex char {i})")
        print("local  :", l[max(0,i-40):i+40])
        print("onchain:", o[max(0,i-40):i+40])
        # check if one is prefix of other
        print("local is prefix of onchain:", o.startswith(l))
        print("onchain is prefix of local:", l.startswith(o))

if __name__ == "__main__":
    main()

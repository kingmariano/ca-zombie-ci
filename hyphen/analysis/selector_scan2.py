#!/usr/bin/env python3
"""Compare selectors present in deployed runtime bytecode against verified ABI.
Handles tuple types canonically. Read-only. Public RPC only."""
import json, sys, urllib.request, subprocess

RPCS = {
 "ethereum": "https://ethereum-rpc.publicnode.com",
 "polygon": "https://polygon-bor-rpc.publicnode.com",
 "bsc": "https://bsc-rpc.publicnode.com",
 "optimism": "https://optimism-rpc.publicnode.com",
 "arbitrum": "https://arbitrum-one-rpc.publicnode.com",
 "avalanche": "https://api.avax.network/ext/bc/C/rpc",
}

def canon_type(inp):
    t = inp["type"]
    if t.startswith("tuple"):
        inner = ",".join(canon_type(c) for c in inp["components"])
        suffix = t[len("tuple"):]
        return "(" + inner + ")" + suffix
    return t

def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()[2:10]

def main():
    chain, addr, abipath = sys.argv[1], sys.argv[2], sys.argv[3]
    url = RPCS[chain]
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":[addr,"latest"]}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    code = json.load(urllib.request.urlopen(req, timeout=40))["result"]
    b = bytes.fromhex(code[2:])
    push4 = set()
    i = 0
    while i < len(b):
        op = b[i]
        if op == 0x63 and i+4 < len(b):
            push4.add(b[i+1:i+5].hex()); i += 5
        elif 0x60 <= op <= 0x7f:
            i += 1 + (op - 0x5f)
        else:
            i += 1
    abi = json.load(open(abipath))
    abi_sels = {}
    for e in abi:
        if e.get("type") == "function":
            sig = e["name"] + "(" + ",".join(canon_type(i) for i in e["inputs"]) + ")"
            abi_sels[sel(sig)] = sig
    missing = sorted(set(abi_sels.keys()) - push4)
    print(f"== {chain} {addr} code_len={len(b)} ABI={len(abi_sels)} found={len(set(abi_sels)&push4)} missing={len(missing)}")
    for m in missing:
        print("  MISSING:", m, abi_sels[m])
    # selector-only diffs (dispatcher scan: PUSH4 followed by EQ pattern is harder; report PUSH4 not in ABI as info)
    extras = sorted(push4 - set(abi_sels.keys()))
    print("  PUSH4-not-in-ABI:", extras)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Compare selectors present in deployed runtime bytecode (PUSH4 constants in dispatcher)
against the verified ABI function selectors. Read-only. Public RPC only."""
import json, sys, urllib.request, subprocess

RPCS = {
 "ethereum": "https://ethereum-rpc.publicnode.com",
 "polygon": "https://polygon-bor-rpc.publicnode.com",
 "bsc": "https://bsc-rpc.publicnode.com",
 "optimism": "https://optimism-rpc.publicnode.com",
 "arbitrum": "https://arbitrum-one-rpc.publicnode.com",
 "avalanche": "https://api.avax.network/ext/bc/C/rpc",
}

def keccak_selector(sig):
    import hashlib
    # use cast for keccak
    out = subprocess.check_output(["cast", "sig", sig]).decode().strip()
    return out[2:10]

def main():
    chain, addr, abipath = sys.argv[1], sys.argv[2], sys.argv[3]
    url = RPCS[chain]
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":[addr,"latest"]}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    code = json.load(urllib.request.urlopen(req, timeout=40))["result"]
    b = bytes.fromhex(code[2:])
    # collect all PUSH4 (0x63) operands
    push4 = set()
    i = 0
    while i < len(b):
        op = b[i]
        if op == 0x63 and i+4 < len(b):
            push4.add(b[i+1:i+5].hex())
            i += 5
        elif 0x60 <= op <= 0x7f:  # PUSH1..PUSH32
            i += 1 + (op - 0x5f)
        else:
            i += 1
    abi = json.load(open(abipath))
    abi_sels = {}
    for e in abi:
        if e.get("type") == "function":
            ins = ",".join(i["type"] for i in e["inputs"])
            sig = f"{e['name']}({ins})"
            abi_sels[keccak_selector(sig)] = sig
    in_code = sorted(push4 & set(abi_sels.keys()))
    not_in_abi = sorted(push4 - set(abi_sels.keys()))
    missing = sorted(set(abi_sels.keys()) - push4)
    print(f"== {chain} {addr} code_len={len(b)}")
    print(f"ABI selectors: {len(abi_sels)}; found in bytecode: {len(in_code)}; missing from bytecode: {len(missing)}")
    for m in missing:
        print("  MISSING (in ABI not in code):", m, abi_sels[m])
    print(f"PUSH4 constants not in ABI: {len(not_in_abi)} (dispatcher may include others; check list)")
    for s in not_in_abi[:80]:
        print("  EXTRA:", s)

if __name__ == "__main__":
    main()

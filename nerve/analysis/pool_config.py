#!/usr/bin/env python3
"""Detailed pool config reads for Nerve pools (BSC)."""
import json, urllib.request

RPC = "https://bsc-rpc.publicnode.com"
POOLS = {
    "3pool_1b37":  "0x1b3771a66ee31180906972580ade9b81afc5fcdc",
    "btc_6C34":    "0x6C341938bB75dDe823FAAfe7f446925c66E6270c",
    "eth_146C":    "0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0",
    "meta_2dcC":   "0x2dcCe1586b1664f41C72206900e404Ec3cA130e0",
}
SEL = {
    "owner()": "0x8da5cb5b",
    "paused()": "0x5c975abb",
    "getVirtualPrice()": "0xe25aa5fa",
    "getA()": "0xd46300fd",
    "getAPrecise()": "0x0ba81959",
    "swapStorage()": "0x5fd65f0f",
    "metaSwapStorage()": "0x2d74d4e9",
}
def pad(addr): return addr.lower().replace("0x", "").rjust(64, "0")
def sel_sig(sig):  # keccak via cast is easier; precomputed here
    return sig

def rpc_batch(calls, url=RPC):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    with urllib.request.urlopen(req, timeout=90) as r:
        out = json.load(r)
    out.sort(key=lambda x: x["id"])
    return [o.get("result") for o in out]

def main():
    block_hex = rpc_batch([("eth_blockNumber", [])])[0]
    block = int(block_hex, 16)
    calls, meta = [], []
    for name, addr in POOLS.items():
        for fname, sel in SEL.items():
            calls.append(("eth_call", [{"to": addr, "data": sel}, block_hex])); meta.append((name, fname))
        for i in range(4):
            data = "0x82b86600" + pad(hex(i)[2:])  # getToken(uint8)
            calls.append(("eth_call", [{"to": addr, "data": data}, block_hex])); meta.append((name, f"getToken({i})"))
            data = "0x91ceb3eb" + pad(hex(i)[2:])  # getTokenBalance(uint8)
            calls.append(("eth_call", [{"to": addr, "data": data}, block_hex])); meta.append((name, f"getTokenBalance({i})"))
    res = rpc_batch(calls)
    out = {}
    for (n, k), v in zip(meta, res):
        out.setdefault(n, {})[k] = v
    print(json.dumps({"block": block, "pools": out}, indent=2))
    with open("/home/heisenberg/CA/nerve/analysis/pool_config.json", "w") as f:
        json.dump({"block": block, "pools": out}, f, indent=2)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Read-only on-chain state reader for Nerve (BSC). Uses public RPC; no secrets.
Batch JSON-RPC calls for balances + basic pool state.
"""
import json, sys, urllib.request

RPC = "https://bsc-rpc.publicnode.com"

TOKENS = {
    "USDT": "0x55d398326f99059fF775485246999027B3197955",
    "BUSD": "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
    "USDC": "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",
    "BTCB": "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
    "ETH":  "0x2170Ed0880ac9A755fd29B2688956BD959F933F8",
    "UST":  "0x23396cF899Ca06c4472205fC903bDB4de249D6fC",
    "WBNB": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
}
TARGETS = [
    "0x1b3771a66ee31180906972580ade9b81afc5fcdc",
    "0x6C341938bB75dDe823FAAfe7f446925c66E6270c",
    "0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0",
    "0x2dcCe1586b1664f41C72206900e404Ec3cA130e0",
]

SEL = {
    "owner()": "0x8da5cb5b",
    "admin()": "0xf851a440",
    "fee()": "0xddca3f43",
    "A()": "0xf446c1d0",
    "getA()": "0xf446c1d0",
    "totalSupply()": "0x18160ddd",
    "paused()": "0x5c975abb",
    "swapStorage()": "0x5fd65f0f",
}

def rpc_batch(calls, url=RPC):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        out = json.load(r)
    out.sort(key=lambda x: x["id"])
    return [o.get("result") for o in out]

def pad(addr):
    return addr.lower().replace("0x", "").rjust(64, "0")

def main():
    block_hex = rpc_batch([("eth_blockNumber", [])])[0]
    block = int(block_hex, 16)
    print(f"# BSC block {block} ({block_hex})")
    calls = []
    meta = []
    for t in TARGETS:
        calls.append(("eth_getBalance", [t, block_hex])); meta.append((t, "BNB_native"))
        for name, addr in TOKENS.items():
            data = "0x70a08231" + pad(t)
            calls.append(("eth_call", [{"to": addr, "data": data}, block_hex])); meta.append((t, "bal:" + name))
        for fname, sel in SEL.items():
            calls.append(("eth_call", [{"to": t, "data": sel}, block_hex])); meta.append((t, fname))
    res = rpc_batch(calls)
    out = {}
    for (t, k), v in zip(meta, res):
        out.setdefault(t, {})[k] = v
    print(json.dumps(out, indent=2))
    with open("/home/heisenberg/CA/nerve/analysis/state_latest.json", "w") as f:
        json.dump({"block": block, "data": out}, f, indent=2)

if __name__ == "__main__":
    main()

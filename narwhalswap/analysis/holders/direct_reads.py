#!/usr/bin/env python3
"""Direct on-chain balanceOf reads for candidate addresses across the Narwhalswap token set."""
import sys, json
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
import bsc

TOKENS = {
    "NAR": "0xa1303e6199b319a891b79685f0537d289af1fc83",
    "NLP_NARWBNB": "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
    "LP_WBNBTHUGS": "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
    "LP_WBNBBUSD": "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
    "rNLP5": "0x6451571cb5bee9fd575ad98506e96f3d09c66f91",
    "rNLP6": "0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a",
    "THUGS": "0xe10e9822a5de22f8761919310dda35cd997d63c0",
}
CANDS = {
    "zero": "0x0000000000000000000000000000000000000000",
    "dead": "0x000000000000000000000000000000000000dead",
    "7777": "0x7777777777777777777777777777777777777777",
    "NLP_pair": "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
    "WBNBTHUGS_pair": "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
    "WBNBBUSD_pair": "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
    "farm5": "0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f",
    "farm6": "0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B",
    "rNLP5_ctr": "0x6451571cb5bee9fd575ad98506e96f3d09c66f91",
    "rNLP6_ctr": "0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a",
    "collector": "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9",
    "factory": "0xb9fa84912ff2383a617d8b433e926adf0dd3fea1",
    "powerStrategy": "0x1d791eaa684a21de92618dedea7bf373e2486956",
    "governance": "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5",
    "team": "0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9",
    "NAR_ctr": "0xa1303e6199b319a891b79685f0537d289af1fc83",
    "THUGS_ctr": "0xe10e9822a5de22f8761919310dda35cd997d63c0",
}

def main():
    blk = bsc.block_number()
    print("block", blk)
    b32 = int
    calls = []
    idx = []
    for tname, taddr in TOKENS.items():
        for cname, caddr in CANDS.items():
            data = bsc.SEL["balanceOf"] + bsc.word(caddr)
            calls.append(("eth_call", [{"to": taddr, "data": data}, hex(blk)]))
            idx.append((tname, cname))
    out = {}
    CH = 40
    for i in range(0, len(calls), CH):
        res = bsc.rpc_batch(calls[i:i+CH])
        for (tname, cname), r in zip(idx[i:i+CH], res):
            v = int(r, 16) if r and r != "0x" else None
            out.setdefault(tname, {})[cname] = v
    for tname in TOKENS:
        print("==", tname, "==")
        for cname in CANDS:
            v = out[tname][cname]
            print(f"  {cname:16s} {cname if False else ''}{v/1e18 if v is not None else 'REVERT':>22}" if v is None or True else "")
    json.dump({"block": blk, "balances": out}, open('direct_balances.json', 'w'), indent=1)

if __name__ == "__main__":
    main()

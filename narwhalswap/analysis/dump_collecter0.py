#!/usr/bin/env python3
"""Dump NarwhalCollecter (feeTo) holdings: LP per pair, token balances, threshold."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bsc import rpc_batch, SEL, words, word, b32_to_addr, dec_str, hexint

HERE = os.path.dirname(os.path.abspath(__file__))
COLLECTER = "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9"

d = json.load(open(os.path.join(HERE, "state-dump.json")))
pairs = list(d["pairs"].keys())
tokens = sorted(d["tokens"].keys())
blk = None

def main():
    out = rpc_batch([
        ("eth_call", [{"to": COLLECTER, "data": bytes.fromhex("c45a015500000000000000000000000000000000000000000000000000000000")[:0].hex() if False else "0xc45a0155"}, "latest"]),
        ("eth_call", [{"to": COLLECTER, "data": "0x8da5cb5b"}, "latest"]),  # owner
    ] + [("eth_call", [{"to": COLLECTER, "data": sel}, "latest"]) for sel in ["0x7d2b48bb", "0x8ca3e6db", "0xc0f2b6b9"]])
    # we don't know the exact getters; instead use known selectors:
    # factory() = 0xc45a0155 ; nar() = ? ; wbnb() = ? ; threshold() = ?
    print("factory:", b32_to_addr(out[0]))
    print("owner:", b32_to_addr(out[1]))

    # Get getters via cast-equivalent: compute keccak selectors offline in JS? Use cast at shell instead.
    json.dump({"collecter": COLLECTER, "factory": b32_to_addr(out[0]), "owner": b32_to_addr(out[1])},
              open(os.path.join(HERE, "collecter-basic.json"), "w"), indent=1)

if __name__ == "__main__":
    main()

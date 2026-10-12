#!/usr/bin/env python3
"""Dump NarwhalCollecter (feeTo) holdings: LP per pair, token balances, threshold."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bsc import rpc_batch, words, word, b32_to_addr, dec_str, hexint

HERE = os.path.dirname(os.path.abspath(__file__))
COLLECTER = "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9"
SEL_FACTORY = "0xc45a0155"
SEL_NAR = "0x86c2ef68"
SEL_WBNB = "0x8d72647e"
SEL_THRESHOLD = "0x42cde4e8"
SEL_OWNER = "0x8da5cb5b"
SEL_BAL = "0x70a08231"
SEL_TS = "0x18160ddd"

d = json.load(open(os.path.join(HERE, "state-dump.json")))
pairs = list(d["pairs"].keys())
tokens = sorted(d["tokens"].keys())

def main():
    out = rpc_batch([
        ("eth_call", [{"to": COLLECTER, "data": SEL_FACTORY}, "latest"]),
        ("eth_call", [{"to": COLLECTER, "data": SEL_NAR}, "latest"]),
        ("eth_call", [{"to": COLLECTER, "data": SEL_WBNB}, "latest"]),
        ("eth_call", [{"to": COLLECTER, "data": SEL_THRESHOLD}, "latest"]),
        ("eth_call", [{"to": COLLECTER, "data": SEL_OWNER}, "latest"]),
    ])
    res = {"collecter": COLLECTER, "factory": b32_to_addr(out[0]), "nar": b32_to_addr(out[1]),
           "wbnb": b32_to_addr(out[2]), "threshold": hexint(out[3]), "owner": b32_to_addr(out[4])}
    print(json.dumps(res, indent=1))

    # LP balances of the collecter in each pair + token balances
    B = 12
    lp = {}
    for i in range(0, len(pairs), B):
        chunk = pairs[i:i+B]
        calls = [("eth_call", [{"to": p, "data": SEL_BAL + word(COLLECTER)}, "latest"]) for p in chunk]
        r = rpc_batch(calls, timeout=90)
        for j, p in enumerate(chunk):
            lp[p] = hexint(r[j])
    res["lp_balances"] = {p: v for p, v in lp.items() if v}

    tb = {}
    for i in range(0, len(tokens), B):
        chunk = tokens[i:i+B]
        calls = [("eth_call", [{"to": t, "data": SEL_BAL + word(COLLECTER)}, "latest"]) for t in chunk]
        r = rpc_batch(calls, timeout=90)
        for j, t in enumerate(chunk):
            tb[t] = hexint(r[j])
    res["token_balances"] = {t: v for t, v in tb.items() if v and v > 0}

    # native BNB
    from bsc import rpc
    res["bnb"] = int(rpc("eth_getBalance", [COLLECTER, "latest"]), 16)

    json.dump(res, open(os.path.join(HERE, "collecter-state.json"), "w"), indent=1)
    print("\ntotal pairs with LP:", len(res["lp_balances"]))
    print("token balances:", len(res["token_balances"]))
    print("bnb:", res["bnb"])

if __name__ == "__main__":
    main()

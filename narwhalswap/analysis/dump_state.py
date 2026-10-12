#!/usr/bin/env python3
"""Dump Narwhalswap factory + all pairs live state on BSC. Read-only."""
import json, sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bsc import rpc_batch, call, code, block_number, SEL, words, word, b32_to_addr, dec_str, hexint

FACTORY = "0xb9fa84912ff2383a617d8b433e926adf0dd3fea1"

def main():
    blk = block_number()
    print("block", blk)
    fcode = code(FACTORY)
    print("factory code len", len(fcode) - 2)

    # factory globals
    out = rpc_batch([
        ("eth_call", [{"to": FACTORY, "data": SEL["allPairsLength"]}, "latest"]),
        ("eth_call", [{"to": FACTORY, "data": SEL["feeTo"]}, "latest"]),
        ("eth_call", [{"to": FACTORY, "data": SEL["feeToSetter"]}, "latest"]),
    ])
    n = hexint(out[0])
    fee_to = b32_to_addr(out[1])
    fee_setter = b32_to_addr(out[2])
    print("allPairsLength", n, "feeTo", fee_to, "feeToSetter", fee_setter)

    # enumerate all pairs
    calls = [("eth_call", [{"to": FACTORY, "data": SEL["allPairs"] + word(i)}, "latest"]) for i in range(n)]
    res = rpc_batch(calls, timeout=90)
    pairs = [b32_to_addr(r) for r in res]
    print("pairs", len(pairs))

    dump = {"block": blk, "factory": FACTORY, "n_pairs": n, "feeTo": fee_to,
            "feeToSetter": fee_setter, "factory_code_len": len(fcode) - 2, "pairs": {}}

    # per-pair: token0, token1, reserves, totalSupply, balances, kLast
    B = 8
    for i in range(0, len(pairs), B):
        chunk = pairs[i:i+B]
        calls = []
        for p in chunk:
            calls += [
                ("eth_call", [{"to": p, "data": SEL["token0"]}, "latest"]),
                ("eth_call", [{"to": p, "data": SEL["token1"]}, "latest"]),
                ("eth_call", [{"to": p, "data": SEL["getReserves"]}, "latest"]),
                ("eth_call", [{"to": p, "data": SEL["totalSupply"]}, "latest"]),
                ("eth_call", [{"to": p, "data": SEL["kLast"]}, "latest"]),
            ]
        res = rpc_batch(calls, timeout=90)
        for j, p in enumerate(chunk):
            r = res[j*5:j*5+5]
            t0 = b32_to_addr(r[0]); t1 = b32_to_addr(r[1])
            rv = r[2]
            if rv and len(rv) >= 2 + 192:
                b = bytes.fromhex(rv[2:])
                r0 = int.from_bytes(b[0:32], "big"); r1 = int.from_bytes(b[32:64], "big")
                ts = int.from_bytes(b[64:96], "big")
            else:
                r0 = r1 = ts = None
            dump["pairs"][p] = {"token0": t0, "token1": t1, "reserve0": r0, "reserve1": r1,
                                "totalSupply": hexint(r[3]), "kLast": hexint(r[4])}
        print("scanned pairs", min(i+B, len(pairs)), "/", len(pairs), flush=True)

    # balances of pair contracts in both tokens + token metadata
    tokens = set()
    for p, d in dump["pairs"].items():
        tokens.add(d["token0"]); tokens.add(d["token1"])
    tokens = sorted(t for t in tokens if t)

    tok = {}
    B = 10
    for i in range(0, len(tokens), B):
        chunk = tokens[i:i+B]
        calls = []
        for t in chunk:
            calls += [
                ("eth_call", [{"to": t, "data": SEL["decimals"]}, "latest"]),
                ("eth_call", [{"to": t, "data": SEL["symbol"]}, "latest"]),
                ("eth_call", [{"to": t, "data": SEL["totalSupply"]}, "latest"]),
                ("eth_call", [{"to": t, "data": SEL["owner"]}, "latest"]),
            ]
        res = rpc_batch(calls, timeout=90)
        for j, t in enumerate(chunk):
            r = res[j*4:j*4+4]
            tok[t] = {"decimals": hexint(r[0]), "symbol": dec_str(r[1]),
                      "totalSupply": hexint(r[2]), "owner": b32_to_addr(r[3])}
        print("tokens", min(i+B, len(tokens)), "/", len(tokens), flush=True)

    # pair balances (2 calls per pair)
    for i in range(0, len(pairs), B):
        chunk = pairs[i:i+B]
        calls = []
        for p in chunk:
            d = dump["pairs"][p]
            calls += [
                ("eth_call", [{"to": d["token0"], "data": SEL["balanceOf"] + word(p)}, "latest"]),
                ("eth_call", [{"to": d["token1"], "data": SEL["balanceOf"] + word(p)}, "latest"]),
            ]
        res = rpc_batch(calls, timeout=90)
        for j, p in enumerate(chunk):
            d = dump["pairs"][p]
            d["bal0"] = hexint(res[j*2]); d["bal1"] = hexint(res[j*2+1])

    dump["tokens"] = tok
    outp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state-dump.json")
    json.dump(dump, open(outp, "w"), indent=1)
    print("wrote", outp)

if __name__ == "__main__":
    main()

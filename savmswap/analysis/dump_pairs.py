#!/usr/bin/env python3
"""Dump all savmSwap pairs on Prom: reserves vs actual balances (skim excess), LP supply/holders."""
import json, sys
from prom import *

FACTORY = "0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9"
BATCH = 10

def rpc_batch(calls):
    body = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    import urllib.request
    req = urllib.request.Request(RPC, data=json.dumps(body).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        out = json.loads(r.read())
    res = {}
    for item in out:
        res[item["id"]] = item.get("result")
    return [res.get(i) for i in range(len(calls))]

def main():
    blk = int(rpc("eth_blockNumber", []), 16)
    n = call_uint(FACTORY, "allPairsLength()", block=hex(blk))
    pairs = []
    for i in range(0, n, BATCH):
        calls = [("eth_call", [{"to": FACTORY, "data": SEL["allPairs(uint256)"] + enc_uint(j)}, hex(blk)]) for j in range(i, min(i+BATCH, n))]
        for r in rpc_batch(calls):
            pairs.append(dec_addr(r))
    out = {"block": blk, "factory": FACTORY, "pair_count": len(pairs), "pairs": []}
    # per-pair reads
    for p in pairs:
        calls = [
            ("eth_call", [{"to": p, "data": SEL["token0()"]}, hex(blk)]),
            ("eth_call", [{"to": p, "data": SEL["token1()"]}, hex(blk)]),
            ("eth_call", [{"to": p, "data": SEL["getReserves()"]}, hex(blk)]),
            ("eth_call", [{"to": p, "data": SEL["totalSupply()"]}, hex(blk)]),
            ("eth_call", [{"to": p, "data": SEL["kLast()"]}, hex(blk)]),
        ]
        r = rpc_batch(calls)
        t0 = dec_addr(r[0]); t1 = dec_addr(r[1])
        b = bytes.fromhex(r[2][2:])
        r0 = int.from_bytes(b[0:32], "big"); r1 = int.from_bytes(b[32:64], "big"); ts = int.from_bytes(b[64:96], "big")
        call = r[2]
        # balances of pair
        calls2 = [
            ("eth_call", [{"to": t0, "data": SEL["balanceOf(address)"] + enc_addr(p)}, hex(blk)]),
            ("eth_call", [{"to": t1, "data": SEL["balanceOf(address)"] + enc_addr(p)}, hex(blk)]),
            ("eth_call", [{"to": p, "data": SEL["balanceOf(address)"] + enc_addr(p)}, hex(blk)]),  # LP held by pair itself (should be 0)
        ]
        r2 = rpc_batch(calls2)
        b0 = dec_uint(r2[0]); b1 = dec_uint(r2[1]); lp_self = dec_uint(r2[2])
        out["pairs"].append({
            "pair": p, "t0": t0, "t1": t1,
            "r0": r0, "r1": r1, "ts": ts, "b0": b0, "b1": b1,
            "x0": b0 - r0, "x1": b1 - r1, "lp_self": lp_self,
        })
    # token metadata
    toks = sorted({x["t0"] for x in out["pairs"]} | {x["t1"] for x in out["pairs"]})
    meta = {}
    for t in toks:
        calls = [
            ("eth_call", [{"to": t, "data": SEL["symbol()"]}, hex(blk)]),
            ("eth_call", [{"to": t, "data": SEL["name()"]}, hex(blk)]),
            ("eth_call", [{"to": t, "data": SEL["decimals()"]}, hex(blk)]),
        ]
        r = rpc_batch(calls)
        meta[t] = {"symbol": read_str(r[0]), "name": read_str(r[1]), "decimals": dec_uint(r[2])}
    out["tokens"] = meta
    # feeTo LP balances across pairs
    FEETO = call_addr(FACTORY, "feeTo()", block=hex(blk))
    out["feeTo"] = FEETO
    fbal = {}
    for x in out["pairs"]:
        fbal[x["pair"]] = call_uint(x["pair"], "balanceOf(address)", [FEETO], block=hex(blk))
    out["feeTo_lp"] = fbal
    json.dump(out, open("/home/heisenberg/CA/savmswap/analysis/pairs_prom.json", "w"), indent=1)

    # summary
    import math
    print("block", blk, "pairs", len(pairs))
    tot = 0
    for x in sorted(out["pairs"], key=lambda z: -(z["x0"] > 0 and z["x0"] or 0)):
        pass
    print("pairs with positive excess (element0):")
    for x in out["pairs"]:
        if x["x0"] > 0 or x["x1"] > 0:
            print(" ", x["pair"], "x0", x["x0"], "x1", x["x1"], meta[x["t0"]]["symbol"], meta[x["t1"]]["symbol"])
    print("pairs with negative excess (reserve>balance):")
    for x in out["pairs"]:
        if x["x0"] < 0 or x["x1"] < 0:
            print(" ", x["pair"], "x0", x["x0"], "x1", x["x1"], meta[x["t0"]]["symbol"], meta[x["t1"]]["symbol"])

if __name__ == "__main__":
    main()

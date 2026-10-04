#!/usr/bin/env python3
"""Pinned live-state dump for the GRXswap deployment (GRX Chain, chainId 1110).

Read-only JSON-RPC only (no explorer dependency), single pinned block for atomicity.
Writes JSON to stdout; ci/run.sh redirects it to ci-out/state.json.
"""
import json, urllib.request, time, os

RPC = os.environ.get("GRX_RPC_URL", "https://rpc.grxchain.io")
FACTORY = "0xc7316818841f355c5107753a3f3fdea799bd25f6"
ROUTER = "0x28fc93b8a20570f2b59d5ca9f8a1da02c4dbcdf5"
TOKENS = {
    "WGRX_a": "0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5",
    "ST": "0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081",
    "USDT18_a": "0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",
    "BTC": "0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275",
    "USDT6": "0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20",
    "ETH": "0x02D129c8A26839c814925eE0f1D320F63114E1FE",
    "USDT18_b": "0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75",
    "WGRX_b": "0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212",
    "SAFE": "0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F",
}
OWNER = "0x53e6A26f382e6b6d50a183C747cb0C7607ba8043"
MINTER2 = "0x0eDC1BbC571bAF713E86a7E2475fb43ae62D6D39"
FEE_TO = "0xDb9011614CC30136Af7EBBa4e314641e07c10221"
MINTER_ROLE = "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
ADMIN_ROLE = "0x" + "00" * 32

SEL = {
    "token0": "0x0dfe1681", "token1": "0xd21220a7", "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd", "balanceOf": "0x70a08231", "kLast": "0x7464fc3d",
    "factory": "0xc45a0155", "allPairsLength": "0x574f2ba3", "allPairs": "0x1e3dd18b",
    "feeTo": "0x017e7e58", "feeToSetter": "0x094b7415", "owner": "0x8da5cb5b",
    "decimals": "0x313ce567", "symbol": "0x95d89b41", "hasRole": "0x91d14854",
    "depositor_slot7": None,
}

def pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def rpc_batch(items):
    reqs = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(items)]
    out = {}
    for j in range(0, len(reqs), 10):
        ch = reqs[j:j + 10]
        r = urllib.request.Request(RPC, data=json.dumps(ch).encode(),
                                   headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        resp = None
        for _ in range(3):
            try:
                resp = json.load(urllib.request.urlopen(r, timeout=90))
                break
            except Exception:
                time.sleep(2)
        if resp is None:
            continue
        for x in resp:
            out[x["id"]] = x.get("result") or str(x.get("error"))
    return out

def main():
    items, labels = [], []
    items.append(("eth_blockNumber", [])); labels.append("block")
    items.append(("eth_call", [{"to": FACTORY, "data": SEL["allPairsLength"]}, "latest"])); labels.append("allPairsLength")
    items.append(("eth_call", [{"to": FACTORY, "data": SEL["feeTo"]}, "latest"])); labels.append("feeTo")
    items.append(("eth_call", [{"to": FACTORY, "data": SEL["feeToSetter"]}, "latest"])); labels.append("feeToSetter")
    for i in range(8):
        items.append(("eth_call", [{"to": FACTORY, "data": SEL["allPairs"] + hex(i)[2:].rjust(64, "0")}, "latest"]))
        labels.append(f"allPairs[{i}]")
    for n, a in TOKENS.items():
        for fn in ("owner", "totalSupply", "decimals", "symbol"):
            items.append(("eth_call", [{"to": a, "data": SEL[fn]}, "latest"])); labels.append(f"{n}.{fn}")
    for n, a in (("OWNER", OWNER), ("MINTER2", MINTER2), ("FEE_TO", FEE_TO)):
        items.append(("eth_getBalance", [a, "latest"])); labels.append(f"{n}.native")
        items.append(("eth_getCode", [a, "latest"])); labels.append(f"{n}.code")
    for tn in ("BTC", "ETH", "USDT6"):
        for role, rn in ((MINTER_ROLE, "MINTER"), (ADMIN_ROLE, "ADMIN")):
            for cn, ca in (("OWNER", OWNER), ("MINTER2", MINTER2)):
                items.append(("eth_call", [{"to": TOKENS[tn], "data": SEL["hasRole"] + role[2:] + pad(ca)}, "latest"]))
                labels.append(f"{tn}.hasRole.{rn}.{cn}")
    out = rpc_batch(items)
    res = {"rpc": RPC, "chainId": 1110}
    blk = out.get(0)
    res["block"] = int(blk, 16) if isinstance(blk, str) and blk.startswith("0x") else blk
    for i, l in enumerate(labels):
        if l == "block":
            continue
        v = out.get(i)
        res[l] = v
    pairs = []
    for i in range(8):
        p = res.get(f"allPairs[{i}]")
        if isinstance(p, str) and len(p) == 66:
            pairs.append("0x" + p[-40:])
    res["pairs"] = pairs
    # second call wave: pair details at the same pinned block
    blk_hex = hex(res["block"])
    items, labels = [], []
    for i, p in enumerate(pairs):
        items.append(("eth_call", [{"to": p, "data": SEL["token0"]}, blk_hex])); labels.append(f"p{i}.token0")
        items.append(("eth_call", [{"to": p, "data": SEL["token1"]}, blk_hex])); labels.append(f"p{i}.token1")
        items.append(("eth_call", [{"to": p, "data": SEL["getReserves"]}, blk_hex])); labels.append(f"p{i}.reserves")
        items.append(("eth_call", [{"to": p, "data": SEL["totalSupply"]}, blk_hex])); labels.append(f"p{i}.lpTotalSupply")
        items.append(("eth_call", [{"to": p, "data": SEL["kLast"]}, blk_hex])); labels.append(f"p{i}.kLast")
        items.append(("eth_call", [{"to": p, "data": SEL["factory"]}, blk_hex])); labels.append(f"p{i}.factory")
    o = rpc_batch(items)
    for i, p in enumerate(pairs):
        d = {"pair": p, "factory": o.get(i * 6 + 5)}
        t0, t1 = o.get(i * 6), o.get(i * 6 + 1)
        d["token0"] = "0x" + t0[-40:] if isinstance(t0, str) and len(t0) == 66 else t0
        d["token1"] = "0x" + t1[-40:] if isinstance(t1, str) and len(t1) == 66 else t1
        rv = o.get(i * 6 + 2)
        if isinstance(rv, str) and len(rv) == 2 + 64 * 3:
            d["reserve0"] = str(int(rv[2:66], 16))
            d["reserve1"] = str(int(rv[66:130], 16))
            d["reserve_ts"] = int(rv[130:], 16)
        d["lpTotalSupply"] = o.get(i * 6 + 3)
        d["kLast"] = o.get(i * 6 + 4)
        res.setdefault("pair_state", []).append(d)
    # balances of pair in its own tokens, same pinned block
    items, labels = [], []
    for i, d in enumerate(res.get("pair_state", [])):
        for tk in ("token0", "token1"):
            ta = d.get(tk)
            if isinstance(ta, str) and ta.startswith("0x") and len(ta) == 42:
                items.append(("eth_call", [{"to": ta, "data": SEL["balanceOf"] + pad(d["pair"])}, blk_hex]))
                labels.append(f"p{i}.balance.{tk}")
    o = rpc_batch(items)
    for l, v in o.items():
        i = int(labels[l].split(".")[0][1:])
        tk = labels[l].split(".")[2]
        res["pair_state"][i][f"balance_{tk}"] = v
    print(json.dumps(res, indent=1))

if __name__ == "__main__":
    main()

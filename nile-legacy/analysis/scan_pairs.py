#!/usr/bin/env python3
"""
Scan all Nile Legacy cAMM pairs for skim()-extractable excess:
  excess = balanceOf(pair, token) - reserve(pair, token)   [when > 0]
Also flags stale reserves (reserve > balance) and records stable flag + LP supply.
Uses only the keyless public Linea RPC (no secrets).
Output: analysis/pair_scan.json
"""
import json, time, urllib.request, sys

import os
RPC = os.environ.get("LINEA_RPC_URL", "https://rpc.linea.build")
FACTORY = "0xAAA16c016BF556fcD620328f0759252E29b1AB57"
OUT = "analysis/pair_scan.json"

def rpc_batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": c[0], "data": c[1]}, "latest"]} for i, c in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        res = json.load(r)
    out = {}
    for item in res:
        out[item["id"]] = item.get("result")
    return [out.get(i) for i in range(len(calls))]

def enc_addr(a):
    return "0x" + a.lower().replace("0x", "").rjust(64, "0")

def dec_uint(h):
    if not h or h == "0x":
        return None
    return int(h, 16)

def selector(sig):
    # keccak via cast is slow; hardcode selectors we need
    table = {
        "allPairsLength()": "0x574f2ba3",
        "allPairs(uint256)": "0x1e3dd18b",
        "token0()": "0x0dfe1681",
        "token1()": "0xd21220a7",
        "getReserves()": "0x0902f1ac",
        "totalSupply()": "0x18160ddd",
        "stable()": "0x22be3de1",
        "balanceOf(address)": "0x70a08231",
    }
    return table[sig]

def call_one(to, data):
    r = rpc_batch([(to, data)])
    return r[0]

# 1. pair count
n = dec_uint(call_one(FACTORY, selector("allPairsLength()")))
print("pairs:", n, flush=True)

# 2. enumerate pairs (batch)
pairs = []
i = 0
while i < n:
    chunk = list(range(i, min(i + 10, n)))
    res = rpc_batch([(FACTORY, selector("allPairs(uint256)") + hex(x)[2:].rjust(64, "0")) for x in chunk])
    for j, r in enumerate(res):
        pairs.append("0x" + r[-40:])
    i += 10
pairs = sorted(set(pairs))
print("enumerated:", len(pairs), flush=True)

# 3. per pair: token0/token1/reserves/totalSupply/stable
info = {}
for k in range(0, len(pairs), 10):
    chunk = pairs[k:k + 10]
    calls = []
    for p in chunk:
        calls += [(p, selector("token0()")), (p, selector("token1()")),
                  (p, selector("getReserves()")), (p, selector("totalSupply()")),
                  (p, selector("stable()"))]
    res = rpc_batch(calls)
    for j, p in enumerate(chunk):
        t0 = "0x" + res[j * 5][-40:] if res[j * 5] else None
        t1 = "0x" + res[j * 5 + 1][-40:] if res[j * 5 + 1] else None
        rv = res[j * 5 + 2]
        if rv and len(rv) >= 2 + 64 * 3:
            r0 = int(rv[2:66], 16); r1 = int(rv[66:130], 16)
        else:
            r0 = r1 = None
        ts = dec_uint(res[j * 5 + 3])
        st = dec_uint(res[j * 5 + 4])
        info[p] = {"t0": t0, "t1": t1, "r0": r0, "r1": r1, "lp": ts, "stable": st}
    print("info", k, flush=True)

# 4. balances of both tokens held by each pair
for k in range(0, len(pairs), 10):
    chunk = pairs[k:k + 10]
    calls = []
    for p in chunk:
        calls += [(info[p]["t0"], selector("balanceOf(address)") + enc_addr(p)[2:]),
                  (info[p]["t1"], selector("balanceOf(address)") + enc_addr(p)[2:])]
    res = rpc_batch(calls)
    for j, p in enumerate(chunk):
        info[p]["b0"] = dec_uint(res[j * 2])
        info[p]["b1"] = dec_uint(res[j * 2 + 1])
    print("bal", k, flush=True)

# 5. classify
rows = []
for p, d in info.items():
    x0 = (d["b0"] - d["r0"]) if (d["b0"] is not None and d["r0"] is not None) else None
    x1 = (d["b1"] - d["r1"]) if (d["b1"] is not None and d["r1"] is not None) else None
    rows.append({
        "pair": p, "token0": d["t0"], "token1": d["t1"],
        "reserve0": d["r0"], "reserve1": d["r1"],
        "balance0": d["b0"], "balance1": d["b1"],
        "excess0": x0, "excess1": x1,
        "lp_totalSupply": d["lp"], "stable": d["stable"],
    })

json.dump({"rpc": "https://rpc.linea.build", "factory": FACTORY, "pairs": rows},
          open(OUT, "w"), indent=1)

ex0 = [r for r in rows if (r["excess0"] or 0) > 0]
ex1 = [r for r in rows if (r["excess1"] or 0) > 0]
print("pairs with excess0>0:", len(ex0), "excess1>0:", len(ex1))
for r in ex0 + ex1:
    print(json.dumps(r))

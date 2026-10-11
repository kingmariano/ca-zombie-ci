#!/usr/bin/env python3
"""Full pair-state enumeration for JediSwap V1 (read-only, public RPC).
For every pair: get_reserves, totalSupply, token0, token1, and token balances held by the pair.
Detects: zero reserves, totalSupply==0 with balances>0, balance>reserve (skim excess), balance<reserve.
"""
import json, sys, time
sys.path.insert(0, "/home/heisenberg/CA/jediswap-v1/analysis")
import sn

OUT = "/home/heisenberg/CA/jediswap-v1/analysis/pair_state.json"
pairs = json.load(open("/home/heisenberg/CA/jediswap-v1/analysis/pairs_list.json"))
print("pairs:", len(pairs))
block = sn.rpc("starknet_blockNumber", [])
print("block:", block)

SEL = {k: sn.selector(k) for k in ["get_reserves", "totalSupply", "token0", "token1", "balanceOf", "factory", "klast", "get_fee_to"]}

# phase 1: reserves, totalSupply, token0, token1
calls = []
for p in pairs:
    calls.append((p, SEL["get_reserves"], []))
    calls.append((p, SEL["totalSupply"], []))
    calls.append((p, SEL["token0"], []))
    calls.append((p, SEL["token1"], []))
print("phase1 calls:", len(calls))
res = sn.batch_calls(calls, chunk=100)
print("phase1 done")

state = []
for i, p in enumerate(pairs):
    r = res[4*i:4*i+4]
    def val(x):
        return x if isinstance(x, list) else None
    rr, ts, t0, t1 = (val(r[0]), val(r[1]), val(r[2]), val(r[3]))
    rec = {"pair": p, "get_reserves_raw": rr, "totalSupply_raw": ts, "token0_raw": t0, "token1_raw": t1}
    if rr and len(rr) >= 5:
        rec["reserve0"] = str(int(rr[0], 16) + (int(rr[1], 16) << 128))
        rec["reserve1"] = str(int(rr[2], 16) + (int(rr[3], 16) << 128))
        rec["ts_last"] = int(rr[4], 16)
    if ts and len(ts) >= 2:
        rec["totalSupply"] = str(int(ts[0], 16) + (int(ts[1], 16) << 128))
    if t0: rec["token0"] = t0[0]
    if t1: rec["token1"] = t1[0]
    state.append(rec)
json.dump(state, open(OUT + ".phase1", "w"))
print("phase1 saved")

# phase 2: balanceOf(pair) for both tokens
calls = []
idx = []
for i, rec in enumerate(state):
    if "token0" in rec:
        calls.append((rec["token0"], SEL["balanceOf"], [int(rec["pair"], 16)]))
        idx.append((i, 0))
    if "token1" in rec:
        calls.append((rec["token1"], SEL["balanceOf"], [int(rec["pair"], 16)]))
        idx.append((i, 1))
print("phase2 calls:", len(calls))
res2 = sn.batch_calls(calls, chunk=100)
print("phase2 done")
for (i, side), r in zip(idx, res2):
    if isinstance(r, list) and len(r) >= 2:
        state[i][f"balance{side}"] = str(int(r[0], 16) + (int(r[1], 16) << 128))
    else:
        state[i][f"balance{side}_err"] = str(r)[:80]

json.dump({"block": block, "count": len(state), "pairs": state}, open(OUT, "w"))
print("saved", OUT)

# anomalies
anom = []
for rec in state:
    p = rec["pair"]
    r0 = int(rec.get("reserve0", 0)); r1 = int(rec.get("reserve1", 0))
    b0 = int(rec.get("balance0", 0)); b1 = int(rec.get("balance1", 0))
    ts = int(rec.get("totalSupply", 0))
    tags = []
    if ts == 0 and (b0 > 0 or b1 > 0): tags.append("TS0_WITH_BALANCE")
    if (r0 == 0) != (r1 == 0): tags.append("ONE_ZERO_RESERVE")
    if b0 > r0 or b1 > r1: tags.append("BALANCE_GT_RESERVE")
    if b0 < r0 or b1 < r1: tags.append("BALANCE_LT_RESERVE")
    if r0 == 0 and r1 == 0 and (b0 > 0 or b1 > 0): tags.append("ZERO_RESERVES_WITH_BALANCE")
    if tags:
        anom.append({"pair": p, "tags": tags, "r0": r0, "r1": r1, "b0": b0, "b1": b1, "ts": ts})
json.dump(anom, open(OUT + ".anomalies", "w"), indent=1)
print("anomalies:", len(anom))
from collections import Counter
print(Counter(t for a in anom for t in a["tags"]))

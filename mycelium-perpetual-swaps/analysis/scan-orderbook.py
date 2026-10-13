#!/usr/bin/env python3
"""Find pending OrderBook orders via explicit getters (public RPC)."""
import json, subprocess, sys
sys.path.insert(0, '.')
from rpc import rpc_batch, rpc

ARB = "https://arb1.arbitrum.io/rpc"
BLK = rpc(ARB, "eth_blockNumber", [])
print("block", int(BLK, 16))
OB = "0x2eeef7852a306a580acf94f7c18c3ff124a59d4f"

def sel(s):
    return subprocess.check_output(["cast", "sig", s]).decode().strip()

def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def encu(v):
    return hex(v)[2:].rjust(64, "0")

pairs = {"swap": [], "increase": [], "decrease": []}
for kind, f in [("swap", "logs-ob-CreateSwapOrder.json"),
                ("increase", "logs-ob-CreateIncreaseOrder.json"),
                ("decrease", "logs-ob-CreateDecreaseOrder.json")]:
    d = json.load(open(f))
    for r in d["result"]:
        acct = "0x" + r["topics"][1][-40:]
        idx = int(r["data"][2:66], 16)
        if (acct, idx) not in pairs[kind]:
            pairs[kind].append((acct, idx))

calls, meta = [], []
for kind, lst in pairs.items():
    for acct, idx in lst:
        data = sel(f"get{kind.capitalize()}Order(address,uint256)") + enc(acct) + encu(idx)
        calls.append((OB, data))
        meta.append((kind, acct, idx))

res = rpc_batch(ARB, calls, BLK)
pending = []
for (kind, acct, idx), r in zip(meta, res):
    if not isinstance(r, str) or not r.startswith("0x") or len(r) < 66:
        print("no result", kind, acct, idx, r)
        continue
    words = [int(r[2 + 64 * i: 2 + 64 * (i + 1)], 16) for i in range(len(r[2:]) // 64)]
    if kind == "swap":
        amountIn, fee = words[3], words[8]
        pend = amountIn > 0
        extra = {"path0": hex(words[0]), "path1": hex(words[1]), "path2": hex(words[2]),
                 "amountIn": amountIn, "minOut": words[4], "triggerRatio": words[5],
                 "triggerAbove": bool(words[6]), "unwrap": bool(words[7])}
    elif kind == "increase":
        amountIn, fee = words[1], words[8]
        pend = amountIn > 0
        extra = {"purchaseToken": hex(words[0]), "purchaseAmount": amountIn,
                 "collateralToken": hex(words[2]), "indexToken": hex(words[3]),
                 "sizeDelta": words[4], "isLong": bool(words[5]),
                 "triggerPrice": words[6], "triggerAbove": bool(words[7])}
    else:
        amountIn, fee = words[1], words[7]
        pend = fee > 0
        extra = {"collateralToken": hex(words[0]), "collateralDelta": amountIn,
                 "indexToken": hex(words[2]), "sizeDelta": words[3], "isLong": bool(words[4]),
                 "triggerPrice": words[5], "triggerAbove": bool(words[6])}
    if pend:
        pending.append({"kind": kind, "account": acct, "index": idx,
                        "fee_wei": fee, "fee_eth": fee / 1e18, **extra})

print("PENDING orders:", len(pending))
tot = 0
for p in pending:
    tot += p["fee_eth"]
    print(json.dumps(p))
print("total pending execution fees: %.6f ETH" % tot)
json.dump({"block": int(BLK, 16), "pending": pending, "total_fee_eth": tot},
          open("orderbook-pending.json", "w"), indent=1)

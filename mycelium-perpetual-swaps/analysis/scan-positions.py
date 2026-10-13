#!/usr/bin/env python3
"""Enumerate live Vault positions from IncreasePosition logs (bounded scan)."""
import json, subprocess, sys, glob
sys.path.insert(0, '.')
from rpc import rpc_batch, rpc

ARB = "https://arb1.arbitrum.io/rpc"
BLK = rpc(ARB, "eth_blockNumber", [])
V = "0xDfbA8AD57d2c62F61F0a60B2C508bCdeb182f855"

cands = []
seen = set()
for f in sorted(glob.glob("logs-incpos-*.json")) + ["logs-incpos.json"]:
    try:
        d = json.load(open(f))
    except Exception:
        continue
    for r in d.get("result", []):
        data = r["data"][2:]
        w = [data[64 * i:64 * (i + 1)] for i in range(len(data) // 64)]
        if len(w) < 9:
            continue
        acct = "0x" + w[1][-40:]; coll = "0x" + w[2][-40:]; idx = "0x" + w[3][-40:]
        islong = bool(int(w[6], 16))
        key = (acct, coll, idx, islong)
        if key not in seen:
            seen.add(key); cands.append(key)

print("unique candidate positions:", len(cands))
sel = lambda s: subprocess.check_output(["cast", "sig", s]).decode().strip()
def enc(a): return a.lower().replace("0x", "").rjust(64, "0")

calls, meta = [], []
for acct, coll, idx, islong in cands:
    data = sel("getPosition(address,address,address,bool)") + enc(acct) + enc(coll) + enc(idx) + ("1" if islong else "0").rjust(64, "0")
    calls.append((V, data)); meta.append((acct, coll, idx, islong))

res = rpc_batch(ARB, calls, BLK)
live = []
for m, r in zip(meta, res):
    if isinstance(r, str) and r.startswith("0x") and len(r) > 130:
        size = int(r[2:66], 16)
        if size > 0:
            live.append({"account": m[0], "collateral": m[1], "index": m[2], "isLong": m[3],
                         "size_usd": size / 1e30, "collateral_usd": int(r[66:130], 16) / 1e30,
                         "reserve": int(r[194:258], 16)})
tot_coll = sum(x["collateral_usd"] for x in live)
tot_size = sum(x["size_usd"] for x in live)
print("LIVE positions:", len(live))
for x in sorted(live, key=lambda z: -z["collateral_usd"])[:15]:
    print(f'  {x["account"]} coll={x["collateral"]} idx={x["index"]} long={x["isLong"]} size=${x["size_usd"]:,.2f} collateral=${x["collateral_usd"]:,.2f}')
print(f"total live collateral (USD): ${tot_coll:,.2f}; total size: ${tot_size:,.2f}")
json.dump({"block": int(BLK, 16), "live_positions": live, "total_collateral_usd": tot_coll,
           "total_size_usd": tot_size}, open("live-positions-full.json", "w"), indent=1)

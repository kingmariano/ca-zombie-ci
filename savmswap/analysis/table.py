#!/usr/bin/env python3
"""Per-pair table for savmSwap Prom: reserves, blockTimestampLast, LP supply, feeTo LP, values."""
import json
from prom import *

d = json.load(open("/home/heisenberg/CA/savmswap/analysis/pairs_prom.json"))
meta = d["tokens"]
blk = hex(block_number())
W = "0x04a21a38d5e275d6023b27504beb3095dc43b0c0"
U = "0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed"
rows = []
for p in d["pairs"]:
    # re-read LP supply correctly
    ts = call_uint(p["pair"], "totalSupply()", block=blk)
    f = call_uint(p["pair"], "balanceOf(address)", [d["feeTo"]], block=blk)
    z = call_uint(p["pair"], "balanceOf(address)", ["0x0000000000000000000000000000000000000000"], block=blk)
    dd0 = meta[p["t0"]]["decimals"]; dd1 = meta[p["t1"]]["decimals"]
    rows.append({
        "pair": p["pair"],
        "t0": p["t0"], "t1": p["t1"],
        "sym0": meta[p["t0"]]["symbol"], "sym1": meta[p["t1"]]["symbol"],
        "r0": p["r0"], "r1": p["r1"],
        "A0": p["r0"] / 10**dd0, "A1": p["r1"] / 10**dd1,
        "tsl": p["ts"],   # blockTimestampLast
        "lp": ts, "feeTo_lp": f, "zero_lp": z,
    })
rows.sort(key=lambda r: -(r["A0"] if r["t0"] == W else (r["A1"] if r["t1"] == W else 0)))
json.dump({"block": int(blk, 16), "rows": rows}, open("/home/heisenberg/CA/savmswap/analysis/pair_table.json", "w"), indent=1)
print(f"{'pair':44s} {'pair name':28s} {'WPROM':>10s} {'other':>18s} {'blkts':>10s} {'LP':>20s} {'feeLP%':>8s}")
import datetime
for r in rows:
    w = r["A0"] if r["t0"] == W else (r["A1"] if r["t1"] == W else 0)
    other = r["A1"] if r["t0"] == W else r["A0"]
    osym = r["sym1"] if r["t0"] == W else r["sym0"]
    if w < 0.5:
        continue
    fpct = (r["feeTo_lp"] / r["lp"] * 100) if r["lp"] else 0
    dt = datetime.datetime.utcfromtimestamp(r["tsl"]).strftime("%Y-%m-%d")
    print(f"{r['pair']:44s} {r['sym0']+'/'+r['sym1']:28s} {w:10.3f} {other:18.3f} {dt:>10s} {r['lp']:20d} {fpct:8.3f}")

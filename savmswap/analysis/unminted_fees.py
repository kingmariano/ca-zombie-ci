#!/usr/bin/env python3
"""Compute unminted protocol fee LP (feeTo, P-category) per pair: the LP that would be
minted to feeTo on the next mint/burn, per UniswapV2 _mintFee:
  liquidity = totalSupply * (sqrt(k) - sqrt(kLast)) / (sqrt(k) + sqrt(kLast))
Value = liquidity / (totalSupply + liquidity) * pool_value_usd
"""
import json, math
from prom import *

PRICE_WPROM = 5.254945355604462
W = "0x04a21a38d5e275d6023b27504beb3095dc43b0c0"
U = "0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed"
blk = hex(block_number())
pt = json.load(open("pair_table.json"))
tot = 0.0
rows = []
for r in pt["rows"]:
    p = r["pair"]
    if r["lp"] == 0:
        continue
    try:
        klast = call_uint(p, "kLast()", block=blk)
    except Exception:
        klast = 0
    k = r["r0"] * r["r1"]
    if klast == 0 or k <= klast:
        continue
    rk = math.isqrt(k); rkl = math.isqrt(klast)
    liq = r["lp"] * (rk - rkl) // (rk + rkl)
    if liq <= 0:
        continue
    w = r["A0"] if r["t0"] == W else (r["A1"] if r["t1"] == W else 0.0)
    u = r["A0"] if r["t0"] == U else (r["A1"] if r["t1"] == U else 0.0)
    pool_usd = w * PRICE_WPROM + u
    fee_usd = pool_usd * liq / (r["lp"] + liq)
    tot += fee_usd
    rows.append({"pair": p, "sym": f"{r['sym0']}/{r['sym1']}", "fee_lp": liq, "fee_usd": round(fee_usd, 2), "pool_usd": round(pool_usd, 2)})
rows.sort(key=lambda x: -x["fee_usd"])
print("block", int(blk, 16))
print("unminted feeTo LP total USD: %.2f" % tot)
for x in rows[:20]:
    print("  ", x)
json.dump({"block": int(blk, 16), "unminted_fee_usd": tot, "rows": rows}, open("unminted_fees.json", "w"), indent=1)

#!/usr/bin/env python3
"""Quantify: (A) theoretical one-shot arbitrage profit per pair vs DefiLlama market prices,
(B) farm gap-mint totals per pool, (C) BRL exit liquidity. Read-only, public data only."""
import json
import os
import urllib.request

BASE = os.path.dirname(__file__)
scan = json.load(open(os.path.join(BASE, "pairs_scan.json")))
meta = json.load(open(os.path.join(BASE, "tokens_meta.json")))
pools = json.load(open(os.path.join(BASE, "mc_pools_supply.json")))
prices = json.load(open(os.path.join(BASE, "prices.json")))

BLOCK = scan["block"]
CUR = 219723846  # pinned block used for farm reads


def px(tok):
    for k, v in prices.items():
        if k.lower() == f"aurora:{tok}".lower():
            return v.get("price")
    return None


def sqrt(n):
    if n < 2:
        return n
    x = n
    y = (x + 1) // 2
    while y < x:
        x = y
        y = (x + n // x) // 2
    return x


print("=== (A) arbitrage upper bound per pair (optimal one-shot, market prices) ===")
rows = []
for p in scan["pairs"]:
    t0, t1 = p["token0"], p["token1"]
    m0, m1 = meta.get(t0, {}), meta.get(t1, {})
    d0, d1 = m0.get("decimals"), m1.get("decimals")
    p0, p1 = px(t0), px(t1)
    if None in (d0, d1) or p0 is None or p1 is None:
        continue
    x = p["reserve0"] / 10**d0
    y = p["reserve1"] / 10**d1
    if x <= 0 or y <= 0:
        continue
    k = x * y
    f = 0.997
    best = 0.0
    direction = None
    # buy token0 with token1
    rhs = p0 * k * f / p1
    if rhs > 0:
        root = sqrt(int(rhs * 10**18)) / 10**9
        if root > y:
            in1 = (root - y) / f
            out0 = x - k / (y + f * in1)
            prof = out0 * p0 - in1 * p1
            if prof > best:
                best, direction = prof, f"buy {m0.get('symbol')} with {m1.get('symbol')}"
    # buy token1 with token0
    rhs2 = p1 * k * f / p0
    if rhs2 > 0:
        root2 = sqrt(int(rhs2 * 10**18)) / 10**9
        if root2 > x:
            in0 = (root2 - x) / f
            out1 = y - k / (x + f * in0)
            prof = out1 * p1 - in0 * p0
            if prof > best:
                best, direction = prof, f"buy {m1.get('symbol')} with {m0.get('symbol')}"
    tvl = x * p0 + y * p1
    rows.append((best, direction, m0.get("symbol"), m1.get("symbol"), tvl, x, y, p0, p1))

rows.sort(reverse=True)
tot = 0.0
for best, direction, s0, s1, tvl, x, y, p0, p1 in rows[:25]:
    tot += best
    print(f"  {str(s0):>8}/{str(s1):<8} tvl ${tvl:12,.0f}  arb ${best:9.2f}  {direction}")
print(f"TOTAL theoretical arb (top25 listed): ${sum(r[0] for r in rows):,.2f}")
print(f"TOTAL arb across ALL priced pairs:    ${sum(r[0] for r in rows):,.2f}")

print()

print()
print("=== (A2) unclaimed protocol fee (LP mintable to feeTo on next mint/burn) ===")
import math
fee_tot = 0.0
for p in scan["pairs"]:
    kl = p["kLast"]
    if not kl:
        continue
    t0, t1 = p["token0"], p["token1"]
    m0, m1 = meta.get(t0, {}), meta.get(t1, {})
    d0, d1 = m0.get("decimals"), m1.get("decimals")
    if None in (d0, d1):
        continue
    r0 = p["reserve0"] / 10**d0
    r1 = p["reserve1"] / 10**d1
    ts = p["totalSupply"] / 1e18
    if r0 <= 0 or r1 <= 0 or ts <= 0:
        continue
    rootK = math.sqrt(r0 * r1)
    rootKLast = math.sqrt(kl / 10**(d0 + d1))
    if rootK <= rootKLast:
        continue
    fee_lp = ts * (rootK - rootKLast) / (3 * rootK + rootKLast)
    px0, px1 = px(t0), px(t1)
    tvl = (r0 * px0 + r1 * px1) if (px0 and px1) else None
    if tvl is None:
        continue
    val = fee_lp / ts * tvl
    if val > 0.5:
        print(f"  {str(m0.get('symbol')):>8}/{str(m1.get('symbol')):<8} feeLP {fee_lp:>16.6f}  value ${val:,.2f}")
    fee_tot += val
print(f"TOTAL unclaimed protocol fee (priced pairs): ${fee_tot:,.2f}  [owed to feeTo 0x9F67...bcAE, not attacker]")

print("=== (B) farm gap mint per pool (if updatePool called now) ===")
BRL_PER_BLOCK = 25_000_000_000_000_000  # 2.5e16
TOTAL_ALLOC = 101_000
out = []
for o in pools:
    pid = o["pid"]
    supply = o["lpSupply"]
    # need lastRewardBlock + alloc; read from mc state dump if present
    out.append(o)
# pools detail from a separate read below (hardcode from mc read)
pd_raw = json.load(open(os.path.join(BASE, "mc_pool_detail.json"))) if os.path.exists(os.path.join(BASE, "mc_pool_detail.json")) else None
pool_detail = pd_raw["pools"] if pd_raw else None
CUR = pd_raw["block"] if pd_raw else CUR
print("pool_detail present:", pool_detail is not None)
if pool_detail:
    tot_gap = 0
    for pd in pool_detail:
        pid, alloc, last, acc, supply = pd["pid"], pd["allocPoint"], pd["lastRewardBlock"], pd["accBRLPerShare"], pd["lpSupply"]
        if supply == 0 or alloc == 0:
            continue
        gap = CUR - last
        R = gap * BRL_PER_BLOCK * alloc // TOTAL_ALLOC
        tot_gap += R
        print(f"  pid {pid:>2} alloc {alloc:>6} supply {supply:>25} gap {gap:>11} R {R/1e18:>14,.2f} BRL")
    print(f"TOTAL gap mint (all pools with stakers): {tot_gap/1e18:,.2f} BRL")

print()
print("=== (C) BRL exit liquidity (non-BRL side of every BRL pair) ===")
brl = "0x12c87331f086c3c926248f964f8702c0842fd77f"
total = 0.0
for p in scan["pairs"]:
    if p["token0"] != brl and p["token1"] != brl:
        continue
    other = p["token1"] if p["token0"] == brl else p["token0"]
    res_other = p["reserve1"] if p["token0"] == brl else p["reserve0"]
    res_brl = p["reserve0"] if p["token0"] == brl else p["reserve1"]
    m = meta.get(other, {})
    d = m.get("decimals") or 18
    amt = res_other / 10**d
    pr = px(other)
    val = amt * pr if pr else None
    sym = m.get("symbol")
    print(f"  BRL/{str(sym):<10} other={amt:>20,.4f} px={pr} value={'${:,.2f}'.format(val) if val is not None else 'n/a (unpriced)'}")
    if val:
        total += val
print(f"TOTAL non-BRL side of BRL pools (exit liquidity for BRL sellers): ${total:,.2f}")
print(f"BRL implied price (weighted by other-side value): {total/max(1,sum(p['reserve0'] if p['token0']==brl else p['reserve1'] for p in scan['pairs'] if p['token0']==brl or p['token1']==brl)/1e18):.6f} USD")

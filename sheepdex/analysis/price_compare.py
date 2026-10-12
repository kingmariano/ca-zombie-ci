#!/usr/bin/env python3
"""Compute pool implied prices vs market (DefiLlama) and flag arb candidates."""
import json, math

d = json.load(open("pool-values.json"))
pools = d["pools"]

print(f"{'pool':44} {'pair':16} {'fee':5} {'liq':>12} {'usd':>10} {'pool_px':>14} {'mkt_px':>14} {'dev%':>8}")
cands = []
for p in pools:
    s0 = p.get("slot0") or {}
    sp = s0.get("sqrtPriceX96")
    if not sp: continue
    dec0, dec1 = p["dec0"], p["dec1"]
    raw = (sp / 2**96) ** 2                      # token1 raw per token0 raw
    px = raw * 10 ** (dec0 - dec1)               # human token1 per token0
    p0, p1 = p.get("price0"), p.get("price1")
    if p0 and p1 and p1 > 0:
        mkt = p0 / p1
        dev = (px / mkt - 1) * 100
    else:
        mkt = None; dev = None
    usd = p["usd"] or 0
    if usd > 50:
        print(f"{p['pool']:44} {str(p['sym0'])+'/'+str(p['sym1']):16} {p['fee']:5} {p['liquidity'] or 0:12d} {usd:10,.0f} "
              f"{px:14.6g} {(mkt if mkt else float('nan')):14.6g} {(dev if dev is not None else float('nan')):8.2f}")
    if dev is not None and abs(dev) > 1 and usd > 50:
        cands.append((p, px, mkt, dev))

print("\nARB CANDIDATES (|dev|>1%, usd>50):")
for p, px, mkt, dev in sorted(cands, key=lambda x: -x[0]["usd"]):
    print(f"{p['pool']} {p['sym0']}/{p['sym1']} usd={p['usd']:,.0f} dev={dev:+.2f}% pool_px={px:.8g} mkt={mkt:.8g} liq={p['liquidity']}")
json.dump([{**p, "pool_px": px, "mkt_px": mkt, "dev_pct": dev} for p, px, mkt, dev in cands],
          open("arb-candidates.json", "w"), indent=1)

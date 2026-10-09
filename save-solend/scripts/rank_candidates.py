#!/usr/bin/env python3
"""Rank config-rot extraction candidates: join sim-refresh results + real prices + reserve config.
Usage: python3 rank_candidates.py <sim_out.json>"""
import json, sys, collections

AN = "/home/heisenberg/CA/save-solend/analysis"
res = json.load(open(f"{AN}/reserves.json"))
px = json.load(open(f"{AN}/prices.json"))["prices"]
mkts = {m["market"]: m for m in json.load(open(f"{AN}/markets.json"))}
sim = json.load(open(sys.argv[1]))
sim_by = {s["reserve"]: s for s in sim}
U64MAX = 2**64 - 1

def sim_price(s):
    if not s or not s.get("ok") or not s.get("post"): return None, None
    mp = int(s["post"]["marketPriceWads"]) / 1e18
    sp = int(s["post"]["smoothedPriceWads"]) / 1e18
    return mp, sp

by_market = collections.defaultdict(list)
for r in res: by_market[r["market"]].append(r)

rows = []
for m, rs in by_market.items():
    mname = rs[0]["marketName"]
    mk = mkts.get(m, {})
    wl = mk.get("whitelistedLiquidator")
    mrl = mk.get("rateLimiter", {})
    for b in rs:
        sb = sim_by.get(b["reserve"])
        bmp, bsp = sim_price(sb)
        b_real = (px.get(b["mint"]) or {}).get("usd")
        if bmp is None: continue                       # borrow reserve must refresh
        if b["availableTokens"] <= 0 or not b_real or b_real <= 0: continue
        # borrow capacity limits
        bl = b["borrowLimit"]                          # base units; 0 = disabled
        if bl == 0: continue
        rem_limit_tokens = max(bl - b["borrowedTokens"] * 10**b["decimals"], 0) / 10**b["decimals"]
        cap_tokens = min(b["availableTokens"], rem_limit_tokens)
        brl = b["rateLimiter"]
        if brl["windowDuration"] != 0 and brl["maxOutflow"] < 2**63:
            cap_tokens = min(cap_tokens, brl["maxOutflow"] / 10**b["decimals"])
        # market RL in USD (market_value_upper_bound of borrow_amount)
        if mrl.get("windowDuration", 0) != 0 and mrl.get("maxOutflow", U64MAX) < 2**63:
            cap_tokens = min(cap_tokens, mrl["maxOutflow"] / bmp)
        avail_usd_real = cap_tokens * b_real
        if avail_usd_real < 50: continue
        for c in rs:
            if c["reserve"] == b["reserve"]: continue
            if c["ltv"] <= 0: continue
            if c["attributedOpen"] == 0: continue       # attribution check blocks new borrows
            sc = sim_by.get(c["reserve"])
            cmp_, csp = sim_price(sc)
            c_real = (px.get(c["mint"]) or {}).get("usd")
            if cmp_ is None or not c_real or c_real <= 0: continue
            prog_lo = min(cmp_, csp)                   # borrow power uses lower bound
            ratio = prog_lo / c_real
            if ratio < 1.15: continue
            cost_ratio = c_real / (prog_lo * c["ltv"] / 100)   # real $ collateral per $ borrowed
            rows.append({
                "market": m, "marketName": mname, "whitelistedLiquidator": wl,
                "borrowSymbol": b["symbol"], "borrowReserve": b["reserve"],
                "borrowProgPrice": bmp, "borrowRealPrice": b_real, "borrowCapTokens": cap_tokens,
                "borrowCapRealUsd": avail_usd_real,
                "borrowLimit": bl, "borrowFeeWad": b["borrowFeeWad"],
                "borrowRL": [brl["windowDuration"], brl["maxOutflow"]],
                "collSymbol": c["symbol"], "collReserve": c["reserve"],
                "collProgLo": prog_lo, "collProgMarket": cmp_, "collProgSmoothed": csp, "collRealPrice": c_real,
                "overvaluation": ratio, "collLtv": c["ltv"], "collDepositLimit": c["depositLimit"],
                "costPerBorrowUsd": cost_ratio,
                "grossProfitIfFullDrainUsd": avail_usd_real * (1 - cost_ratio) if cost_ratio < 1 else 0,
            })
rows.sort(key=lambda r: -r["grossProfitIfFullDrainUsd"])
json.dump(rows, open(f"{AN}/candidates.json", "w"), indent=1)
print(f"{'market':18} {'borrow':8} {'coll':10} {'ovr':>8} {'capReal$':>11} {'cost/$':>7} {'profit$':>11} wl")
for r in rows[:45]:
    print(f"{str(r['marketName'])[:18]:18} {str(r['borrowSymbol'])[:8]:8} {str(r['collSymbol'])[:10]:10} {r['overvaluation']:8.2f} {r['borrowCapRealUsd']:11,.0f} {r['costPerBorrowUsd']:7.3f} {r['grossProfitIfFullDrainUsd']:11,.0f} {str(r['whitelistedLiquidator'])[:8]}")
print("total candidate pairs:", len(rows))

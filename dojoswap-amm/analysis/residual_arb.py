#!/usr/bin/env python3
"""Residual arb estimate: for each pool with a priced side, compute max extractable
value if the other side is bought/sold at the external market price.
Formula (constant product, 0.3% fee ignored => upper bound):
  pool (x=base amount, y=quote amount), market price p (quote per base)
  equilibrium: x' = sqrt(k/p), y' = sqrt(k*p), k = x*y
  If p > p_pool (base cheap in pool): buy base: cost = y - y' (quote out), gain = (x - x')*p
     profit = (x - x')*p - (y - y')
  If p < p_pool: sell base into pool: gain = y - y', cost = (x - x')*p
     profit = (y - y') - (x - x')*p
Also apply 0.3% commission on the returned side.
"""
import json

MKT = {  # denom -> usd price (2026-10-11, DefiLlama / orderbook mid where noted)
    "inj": 7.719961405375492,
    "peggy0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599": 83278.67701171205,
    "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7": 0.9990592309077597,
    "peggy0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": 2526.309369639584,
    "peggy0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": 0.9996446058349336,
    "ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9": None,  # ATOM: fetch below
    "ibc/F51BB221BAA275F2EBF654F70B005627D7E713AFFD6D86AFD1E43CAA886149F4": None,  # TIA
    "ibc/2CBC2EA121AE42563B08028466F37B600F2D7D4282342DE938283CC3FB2BC00E": 0.9996,  # USDC (Noble)
}
DEC = {"inj": 18, "peggy0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599": 8,
       "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7": 6,
       "peggy0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": 18,
       "peggy0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": 6,
       "ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9": 6,
       "ibc/F51BB221BAA275F2EBF654F70B005627D7E713AFFD6D86AFD1E43CAA886149F4": 6,
       "ibc/2CBC2EA121AE42563B08028466F37B600F2D7D4282342DE938283CC3FB2BC00E": 6}

import urllib.request
req = urllib.request.Request("https://coins.llama.fi/prices/current/coingecko:cosmos,coingecko:celestia",
                             headers={"User-Agent": "Mozilla/5.0"})
d = json.loads(urllib.request.urlopen(req, timeout=25).read())
MKT["ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9"] = d["coins"]["coingecko:cosmos"]["price"]
MKT["ibc/F51BB221BAA275F2EBF654F70B005627D7E713AFFD6D86AFD1E43CAA886149F4"] = d["coins"]["coingecko:celestia"]["price"]
print("ATOM:", MKT["ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9"],
      "TIA:", MKT["ibc/F51BB221BAA275F2EBF654F70B005627D7E713AFFD6D86AFD1E43CAA886149F4"])

import math
rows = json.load(open("pools-valued.json"))
out = []
tot = 0.0
for r in rows:
    kinds = r["kinds"]; amts = r["amounts"]; usd = r["usd_known"]
    for i, k in enumerate(kinds):
        j = 1 - i
        if k not in MKT or MKT[k] is None:
            continue
        ok = kinds[j]
        if ok not in MKT or MKT[ok] is None:
            continue
        x = amts[i] / 10**DEC[k]        # base units (token k)
        y = amts[j] / 10**DEC[ok]       # quote units (token ok)
        if x <= 0 or y <= 0:
            continue
        p_pool = y / x                   # quote per base
        p_mkt = MKT[k] / MKT[ok]         # quote per base at market
        kk = x * y
        x2 = math.sqrt(kk / p_mkt); y2 = math.sqrt(kk * p_mkt)
        dx = x - x2; dy = y2 - y
        if p_mkt > p_pool:
            # buy base from pool: pay quote dy... careful: pool base decreases (x2<x), quote increases? no:
            # buy base => pool x decreases to x2, pool y increases to y2? For buy, quote flows in: y grows.
            # equilibrium after buying base: x' = sqrt(k/p), y' = sqrt(k*p) with p = p_mkt > p_pool => y' > y, x' < x.
            cost_quote = y2 - y          # quote paid in
            gain_base = x - x2           # base received
            profit_quote = gain_base * p_mkt - cost_quote
        else:
            # sell base into pool: x grows to x2, y decreases to y2
            cost_base = x2 - x
            gain_quote = y - y2
            profit_quote = gain_quote - cost_base * p_mkt
        profit_usd = profit_quote * MKT[ok]
        if profit_usd > 0.5:
            out.append((profit_usd, r["pair"], k[:46], ok[:46], p_pool, p_mkt, x, y, r["ts"]))
out.sort(reverse=True)
print(f"\nresidual arb candidates (>$0.50): {len(out)}")
for (pu, p, k, ok, pp, pm, x, y, ts) in out:
    print(f"${pu:8.2f} pool={p} base={k[:38]} quote={ok[:30]} p_pool={pp:.6g} p_mkt={pm:.6g}")
    tot += pu
print(f"TOTAL residual arb (upper bound, pre-fee): ${tot:.2f}")
json.dump([{"profit_usd": pu, "pool": p, "base": k, "quote": ok} for (pu, p, k, ok, pp, pm, x, y, ts) in out],
          open("residual-arb.json", "w"), indent=1)

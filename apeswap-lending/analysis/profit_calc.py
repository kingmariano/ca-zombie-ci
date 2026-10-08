#!/usr/bin/env python3
"""Compute liquidation profit bounds from shortfall_detail.json (stored values)."""
import json

d = json.load(open('/home/heisenberg/CA/apeswap-lending/analysis/shortfall_detail.json'))
prices = {  # oracle USD price scaled 1e18 (from getUnderlyingPriceInLen)
 '0xc2e840bdd02b4a1d970c87a912d8576a7e61d314': (1e12, 'oBANANA', 0.70, 1.12),
 '0xaa1b1e1f251610ae10e4d553b05c662e60992eed': (2442609906330000000000, 'oETH', 0.75, 1.10),
 '0x0096b6b49d13b347033438c4a699df3afd9d2f96': (1000000000000000000, 'oBUSD', 0.75, 1.10),
 '0xdbfd516d42743ca3f1c555311f7846095d85f6fd': (999140000000000000, 'oUSDT', 0.75, 1.10),
 '0x3353f5bcfd7e4b146f2ed8f1e8d875733cd754a7': (2117570310000000000, 'oCake', 0.50, 1.12),
 '0x91b66a9ef4f4cad7f8af942855c37dd53520f151': (999842320000000000, 'oUSDC', 0.75, 1.10),
 '0x34878f6a484005aa90e7188a546ea9e52b538f6f': (726916010000000000000, 'oBNB', 0.75, 1.10),
 '0x5fce5d208dc325ff602c77497dc18f8eadac8ada': (81443130000000000000000, 'oBTCB', 0.75, 1.10),
 '0x92d106c39ac068eb113b3ecb3273b23cd19e6e26': (1036760000000000000, 'oDOT', 0.60, 1.12),
 '0x3ee2bd8c244b5b3656673c2a49447e41d31f8e1e': (0, 'oBNBx', 0.60, 1.12),
}

total_coll = 0.0
total_profit = 0.0
per = []
for acct, rows in d.items():
    coll = 0.0
    debt = 0.0
    debts_by_market = {}
    colls = {}
    for m, s in rows:
        if not isinstance(s, dict):
            continue
        ml = m.lower()
        if ml not in prices:
            continue
        price, sym, lf, li = prices[ml]
        er = s['er']
        # underlying amount in wei = tokens(8dec) * er / 1e18 ; usd = amount/1e18 * price/1e18
        under_wei = s['tokens'] * er / 1e18
        val = under_wei / 1e18 * (price / 1e18)
        if s['tokens'] > 0:
            coll += val
            colls[sym] = colls.get(sym, 0) + val
        if s['borrows'] > 0:
            debt += s['borrows'] / 1e18 * (price / 1e18)
            debts_by_market[sym] = debts_by_market.get(sym, 0) + s['borrows'] / 1e18 * (price / 1e18)
    # max repay limited by close factor 50% of debt and by collateral/1.12
    max_repay = min(0.5 * debt, coll / 1.12)
    profit = 0.12 * max_repay
    total_coll += coll
    total_profit += profit
    if coll > 0.5 or profit > 0.02:
        per.append((acct, coll, debt, max_repay, profit, colls, debts_by_market))

per.sort(key=lambda x: -x[4])
print(f"accounts with shortfall: {len(d)}")
print(f"total seizeable collateral (oracle): ${total_coll:.2f}")
print(f"total max gross liquidation profit (12% of repay): ${total_profit:.2f}")
print()
for acct, coll, debt, mr, p, colls, dm in per[:25]:
    print(f"{acct} coll=${coll:.4f} debt=${debt:.2f} maxrepay=${mr:.4f} profit=${p:.4f}")
    print("   coll:", {k: round(v, 4) for k, v in colls.items()})
    print("   debt:", {k: round(v, 2) for k, v in dm.items()})

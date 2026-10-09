#!/usr/bin/env python3
"""Build the definitive Aurigami market table with USD values from markets_raw.json."""
import json

P = {"auUSDC": 0.99961, "auETH": 2483.43, "auWBTC": 82039.09, "auUSDT": 0.99929,
     "auDAI": 0.99977, "auWNEAR": 4.69569, "auSTNEAR": 6.73006, "auAURORA": 0.058863,
     "auTRI": 0.00012557, "auPLY": 0.0000369, "auUSN": 0.08758, "auNEARX": 5.24332,
     "auUSDCNative": 0.99961, "auUSDTNative": 0.99929}
DEC = {"auUSDC": 6, "auETH": 18, "auWBTC": 8, "auUSDT": 6, "auDAI": 18,
       "auWNEAR": 24, "auSTNEAR": 24, "auAURORA": 18, "auTRI": 18, "auPLY": 18,
       "auUSN": 18, "auNEARX": 24, "auUSDCNative": 6, "auUSDTNative": 6}
CF = {"auUSDC": 0.80, "auETH": 0.70, "auWBTC": 0.60, "auUSDT": 0.75, "auDAI": 0.0,
      "auWNEAR": 0.60, "auSTNEAR": 0.40, "auAURORA": 0.40, "auTRI": 0.0, "auPLY": 0.0,
      "auUSN": 0.0, "auNEARX": 0.40, "auUSDCNative": 0.70, "auUSDTNative": 0.70}
NAMES = ["auUSDC", "auETH", "auWBTC", "auUSDT", "auDAI", "auWNEAR", "auSTNEAR",
         "auAURORA", "auTRI", "auPLY", "auUSN", "auNEARX", "auUSDCNative", "auUSDTNative"]
ADDRS = {"auUSDC": "0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
         "auETH": "0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
         "auWBTC": "0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
         "auUSDT": "0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
         "auDAI": "0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
         "auWNEAR": "0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
         "auSTNEAR": "0x3195949f267702723bc614cAE037cdc8D1E94786",
         "auAURORA": "0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf",
         "auTRI": "0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca",
         "auPLY": "0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c",
         "auUSN": "0x5cCAD065400341db391FD3a4B7F50087B678D7CC",
         "auNEARX": "0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
         "auUSDCNative": "0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
         "auUSDTNative": "0xdDfd0407220026c6566979B5be6A4983d1247a3E"}

d = json.load(open('/home/heisenberg/CA/aurigami/analysis/markets_raw.json'))
block = d['block']
raw = d['markets']

rows = []
tot_cash = tot_bor = tot_res = 0.0
for name in NAMES:
    v = raw[ADDRS[name]]
    ts = int(v['totalSupply'], 16)
    tb = int(v['totalBorrows'], 16)
    tr = int(v['totalReserves'], 16)
    er = int(v['exchangeRateStored'], 16)
    und = v.get('underlying')
    ua = ('0x' + und[-40:]) if isinstance(und, str) and len(und) == 66 else '(ETH)'
    cash = int(v['cash'], 16) if isinstance(v.get('cash'), str) else None
    if name == 'auETH':
        cash = 109317552914139122429  # eth_getBalance of the AuETH contract at the read block
    dec = DEC[name]
    cash_u = cash / 10 ** dec
    tb_u = tb / 10 ** dec
    tr_u = tr / 10 ** dec
    px = P[name]
    cash_usd = cash_u * px
    bor_usd = tb_u * px
    res_usd = tr_u * px
    claim_usd = cash_usd + bor_usd - res_usd
    tot_cash += cash_usd
    tot_bor += bor_usd
    tot_res += res_usd
    rows.append((name, ADDRS[name], ua, ts, cash_u, tb_u, tr_u, er, CF[name], px, cash_usd, bor_usd, res_usd, claim_usd))

print(f"block {block}")
hdr = f"| market | address | underlying | cash | borrows | reserves | CF | oracle px | cash USD | borrows USD | reserves USD | supplier claim USD |"
print(hdr)
print("|" + "---|" * 12)
for r in rows:
    name, addr, ua, ts, cash_u, tb_u, tr_u, er, cf, px, cu, bu, ru, cl = r
    print(f"| {name} | `{addr}` | `{ua}` | {cash_u:,.4f} | {tb_u:,.4f} | {tr_u:,.4f} | {cf:.2f} | ${px:,.6f} | ${cu:,.0f} | ${bu:,.0f} | ${ru:,.0f} | ${cl:,.0f} |")
print()
print("TOTAL cash $%.0f | borrows $%.0f | reserves $%.0f | claims $%.0f" % (tot_cash, tot_bor, tot_res, tot_cash+tot_bor-tot_res))
print()
print("supplier claims = cash + borrows - reserves (recoverable by cToken holders)")
print("supplier-claim vs cash gap (net loans receivable USD): $%.0f" % (tot_cash + tot_bor - tot_res - tot_cash))

json.dump({"block": block, "total_cash_usd": round(tot_cash, 2), "total_borrows_usd": round(tot_bor, 2),
           "total_reserves_usd": round(tot_res, 2), "supplier_claims_usd": round(tot_cash + tot_bor - tot_res, 2),
           "rows": [dict(zip(["market", "address", "underlying", "totalSupply", "cash_units", "borrows_units", "reserves_units", "exchangeRate", "cf", "price_usd", "cash_usd", "borrows_usd", "reserves_usd", "claims_usd"], r)) for r in rows]},
          open('/home/heisenberg/CA/aurigami/analysis/market_table.json', 'w'), indent=1)

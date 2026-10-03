#!/usr/bin/env python3
"""Build market-by-market USD table from state dump + oracle/real prices."""
import json

state = json.load(open("/home/heisenberg/CA/c-38/analysis/state-97651394.json"))
REAL = {
    "USDC": 0.9999967, "USDT": 0.999918, "DAI": 0.99994, "TUSD": 0.99925, "USC": 1.0,
    "CRO": 0.06614218, "WBTC": 84592.60, "WETH": 2680.21, "TONIC": 8.942e-9,
    "VVS": 1.0769e-6, "XRP": 1.48327, "LTC": 68.6797, "ADA": 0.244304, "ATOM": 1.67090,
    "LCRO": 0.0844839, "CDCBTC": 84006.12, "CDCETH": 2868.70,
}
UDEC = {"USDC": 6, "USDT": 6, "DAI": 18, "TUSD": 18, "USC": 18, "CRO": 18, "WBTC": 8,
        "WETH": 18, "TONIC": 18, "VVS": 18, "XRP": 6, "LTC": 8, "ADA": 6, "ATOM": 6,
        "LCRO": 18, "CDCBTC": 8, "CDCETH": 18}

# symbol -> underlying symbol mapping from the registry
SYM = {
    "tUSDC": "USDC", "tWBTC": "WBTC", "tWETH": "WETH", "tCRO": "CRO", "tDAI": "DAI",
    "tUSDT": "USDT", "tTONIC": "TONIC", "tTUSD": "TUSD", "tATOM": "ATOM", "tADA": "ADA",
    "tVVS": "VVS", "tXRP": "XRP", "tLTC": "LTC", "tLCROd": "LCRO", "tLCRO": "LCRO",
    "tCDCBTC": "CDCBTC", "tCDCETH": "CDCETH", "tUSC": "USC",
}
rows = []
tot_cash = tot_bor = tot_res = 0.0
for m, d in state["markets"].items():
    sym = d["symbol"]
    usym = SYM.get(sym, sym[1:] if sym.startswith("t") else sym)
    ud = UDEC.get(usym, 18)
    op = d["oracle_price"]
    op_usd = op / (10 ** (36 - ud)) if op else None
    rp = REAL.get(usym)
    cash = d["getCash"] / (10 ** ud) if d["getCash"] is not None else None
    bor = d["totalBorrows"] / (10 ** ud) if d["totalBorrows"] is not None else None
    res = d["totalReserves"] / (10 ** ud) if d["totalReserves"] is not None else None
    cash_usd = cash * (rp or op_usd or 0)
    bor_usd = bor * (rp or op_usd or 0)
    res_usd = res * (rp or op_usd or 0)
    tot_cash += cash_usd
    tot_bor += bor_usd
    tot_res += res_usd
    prem = (op_usd / rp - 1) * 100 if op_usd and rp else None
    rows.append({
        "symbol": sym, "underlying": usym, "address": m,
        "cash_tok": cash, "cash_usd": cash_usd, "borrows_tok": bor, "borrows_usd": bor_usd,
        "reserves_usd": res_usd, "cf": d.get("collateralFactorMantissa", 0) / 1e18,
        "oracle_usd": op_usd, "real_usd": rp, "premium_pct": prem,
        "mint_paused": d["mintGuardianPaused"], "borrow_paused": d["borrowGuardianPaused"],
        "borrow_cap": d["borrowCaps"], "supply_cap": d["supplyCaps"],
        "listed": d.get("isListed"), "seize_share": d["protocolSeizeShareMantissa"] / 1e18,
        "accrual_blk": d["accrualBlockNumber"],
    })
rows.sort(key=lambda r: -r["cash_usd"])
print(f"{'market':9s} {'under':6s} {'cash$':>12s} {'borrows$':>12s} {'reserves$':>11s} {'CF':>5s} {'oracle$':>14s} {'real$':>14s} {'prem%':>8s} {'mintP':>5s} {'borrP':>5s}")
for r in rows:
    print(f"{r['symbol']:9s} {r['underlying']:6s} {r['cash_usd']:12,.0f} {r['borrows_usd']:12,.0f} {r['reserves_usd']:11,.0f} {r['cf']*100:4.0f}% {r['oracle_usd'] or 0:14.8g} {r['real_usd'] or 0:14.8g} {(r['premium_pct'] if r['premium_pct'] is not None else 0):8.2f} {str(r['mint_paused']):>5s} {str(r['borrow_paused']):>5s}")
print(f"\nTOTAL cash ${tot_cash:,.0f} | borrows ${tot_bor:,.0f} | reserves ${tot_res:,.0f}")
json.dump({"rows": rows, "total_cash_usd": tot_cash, "total_borrows_usd": tot_bor, "total_reserves_usd": tot_res},
          open("/home/heisenberg/CA/c-38/analysis/market_table.json", "w"), indent=1)

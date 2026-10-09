#!/usr/bin/env python3
"""Build analysis tables: markets, oracle, liquidation sweep totals (net of gas)."""
import json, csv

d = json.load(open("final_state.json"))
def u(x): return int(x, 16) if isinstance(x, str) and x.startswith("0x") else None

MARKETS = {
    "cETH":  "0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0",
    "cNEAR": "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
    "cUSDC": "0xe5308dc623101508952948b141fD9eaBd3337D99",
    "cUSDT": "0x845E15A441CFC1871B7AC610b0E922019BaD9826",
    "cWBTC": "0xfa786baC375D8806185555149235AcDb182C033b",
}
DEC = {"cETH": 18, "cNEAR": 24, "cUSDC": 6, "cUSDT": 6, "cWBTC": 8}
CF = {"cETH": 0.7, "cNEAR": 0.6, "cUSDC": 0.85, "cUSDT": 0.8, "cWBTC": 0.7}
ORACLE = {"cETH": 1848.474798, "cNEAR": 1.325163, "cUSDC": 1.000065, "cUSDT": 0.999815, "cWBTC": 68840.615}
REAL = {"cETH": 2421.2865, "cNEAR": 4.4015166, "cUSDC": 0.999590, "cUSDT": 0.999253, "cWBTC": 80702.644}
AURI = {"cETH": 2474.4035, "cNEAR": 4.47226411, "cUSDC": 0.99984812, "cUSDT": 0.99919088, "cWBTC": 81705.07}

rows = []
for m in MARKETS:
    cash = u(d[f"{m}.cash"]) / 10 ** DEC[m]
    brw = u(d[f"{m}.totalBorrows"]) / 10 ** DEC[m]
    sup = u(d[f"{m}.totalSupply"]) / 1e8
    res = u(d[f"{m}.totalReserves"]) / 10 ** DEC[m]
    xrate = u(d[f"{m}.exchangeRateStored"])
    rows.append(dict(
        market=m, ctoken=MARKETS[m], cash=cash, borrows=brw, ctoken_supply=sup, reserves=res,
        exchange_rate_stored=str(xrate),
        collateral_factor=CF[m],
        oracle_usd=ORACLE[m], defillama_usd=REAL[m], aurigami_live_usd=AURI[m],
        ratio_real_over_oracle=round(REAL[m] / ORACLE[m], 4),
        cash_usd_real=round(cash * REAL[m], 2), cash_usd_oracle=round(cash * ORACLE[m], 2),
        mint_guardian_paused=bool(u(d[f"{m}.mintPaused"])),
        borrow_guardian_paused=bool(u(d[f"{m}.borrowPaused"])),
        borrow_cap=str(u(d[f"{m}.borrowCap"])),
    ))

with open("markets_table.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)

tot_cash_real = sum(r["cash_usd_real"] for r in rows)
tot_cash_oracle = sum(r["cash_usd_oracle"] for r in rows)
tot_res_real = sum(r["reserves"] * REAL[r["market"]] for r in rows)

print(f"{'market':6} {'cash':>16} {'cash$real':>12} {'borrows$real':>12} {'reserves$real':>13} {'oracle$':>10} {'real$':>10} {'ratio':>6} {'paused':>6}")
for r in rows:
    print(f"{r['market']:6} {r['cash']:16.6f} {r['cash_usd_real']:12,.0f} {r['borrows']*REAL[r['market']]:12,.0f} {r['reserves']*REAL[r['market']]:13,.0f} {r['oracle_usd']:10.4f} {r['defillama_usd']:10.2f} {r['ratio_real_over_oracle']:6.3f} {str(r['mint_guardian_paused']):>6}")
print(f"TOTALS: cash real ${tot_cash_real:,.2f} / oracle ${tot_cash_oracle:,.2f}; reserves real ${tot_res_real:,.2f}")

# ---- liquidation sweep net of gas ----
ORACLE_NEAR = ORACLE["cNEAR"]; REAL_NEAR = REAL["cNEAR"]
LIQ_INC = 1.1; PSHARE = 1.1 * (1 - 0.028)
CFd = CF
pos = json.load(open("shortfall_positions.json"))
liqinfo = json.load(open("account_liquidity.json"))["shortfall"]
RATE = {"cETH": 2012997067845335927557450649/1e28, "cNEAR": 2041852920786852104364883499804576/1e34,
        "cUSDC": 2035350679561257/1e16, "cUSDT": 2017673644175783/1e16, "cWBTC": 200523909163181766/1e18}
ADDR = {m: a.lower() for m, a in MARKETS.items()}
GAS_USD = 0.06  # 350k gas @0.07 gwei @ $2421/ETH

sweep = []
for a, p in pos.items():
    S = liqinfo[a]["shortfall"] / 1e18
    coll = {m: p["balances"].get(m, 0) / 1e8 * RATE[m] * ORACLE[m] for m in RATE if p["balances"].get(m, 0) > 0}
    debt = {m: p["debts"].get(m, 0) / 10 ** DEC[m] * ORACLE[m] for m in RATE if p["debts"].get(m, 0) > 0}
    entered = set(x.lower() for x in p["entered"])
    best = {"profit": 0.0}
    for c, cv in coll.items():
        if ADDR[c] not in entered or cv <= 0: continue
        cap_short = S / (1 - LIQ_INC * CFd[c]) if LIQ_INC * CFd[c] < 1 else float("inf")
        for dm, dv in debt.items():
            cap = min(dv, cv / PSHARE, cap_short)
            if cap <= 0: continue
            gross = cap * PSHARE * (REAL[c] / ORACLE[c]) - cap * (REAL[dm] / ORACLE[dm])
            if gross > best["profit"]:
                calls = 1 if cap <= 0.5 * dv else 2
                best = {"profit": gross, "calls": calls, "repay": cap, "debt_mkt": dm, "coll_mkt": c}
    if best["profit"] > 0:
        net = best["profit"] - best["calls"] * GAS_USD
        sweep.append(dict(account=a, shortfall=S, gross=best["profit"], calls=best["calls"],
                          gas=best["calls"] * GAS_USD, net=net, repay_usd=best["repay"],
                          debt_mkt=best.get("debt_mkt"), coll_mkt=best.get("coll_mkt")))

with open("liquidation_econ.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(sweep[0].keys()))
    w.writeheader()
    for r in sorted(sweep, key=lambda r: -r["gross"]): w.writerow(r)

gross_total = sum(r["gross"] for r in sweep)
net_total = sum(r["net"] for r in sweep)
net_pos = sum(r["net"] for r in sweep if r["net"] > 0)
print(f"\nLIQUIDATION SWEEP: {len(sweep)} accounts; gross ${gross_total:,.2f}; net(gas) ${net_total:,.2f}; net>0 subset ${net_pos:,.2f}")
print(f"gas assumption ${GAS_USD}/liquidation call")
json.dump({"accounts": len(sweep), "gross_usd": round(gross_total, 2), "net_usd": round(net_total, 2),
           "net_positive_usd": round(net_pos, 2), "gas_usd_per_call": GAS_USD},
          open("liquidation_totals.json", "w"), indent=1)

# bad debt summary
totS = sum(liqinfo[a]["shortfall"] for a in pos) / 1e18
print(f"shortfall accounts: {len(pos)}; total shortfall ${totS:,.2f}")

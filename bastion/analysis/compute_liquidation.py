#!/usr/bin/env python3
"""Compute liquidation economics for all shortfall accounts (E-U today candidate)."""
import json

pos = json.load(open("shortfall_positions.json"))
liqinfo = json.load(open("account_liquidity.json"))
short = liqinfo["shortfall"]

ORACLE = {  # Bastion oracle cached prices (USD per whole token)
    "cETH": 1848.474798, "cNEAR": 1.325163, "cUSDC": 1.000065,
    "cUSDT": 0.999815, "cWBTC": 68840.615,
}
REAL_DL = {  # DefiLlama 2026-10-09
    "cETH": 2421.2865, "cNEAR": 4.4015166, "cUSDC": 0.999590, "cUSDT": 0.999253, "cWBTC": 80702.644,
}
REAL_AURI = {  # live Aurigami oracle on Aurora
    "cETH": 2474.4035, "cNEAR": 4.47226411, "cUSDC": 0.99984812, "cUSDT": 0.99919088, "cWBTC": 81705.07,
}
RATE = {  # underlying per cToken (whole units)
    "cETH": 2012997067845335927557450649/1e28,
    "cNEAR": 2041852920786852104364883499804576/1e34,
    "cUSDC": 2035350679561257/1e16,
    "cUSDT": 2017673644175783/1e16,
    "cWBTC": 200523909163181766/1e18,
}
DEC = {"cETH": 18, "cNEAR": 24, "cUSDC": 6, "cUSDT": 6, "cWBTC": 8}
CF = {"cETH": 0.7, "cNEAR": 0.6, "cUSDC": 0.85, "cUSDT": 0.8, "cWBTC": 0.7}
MARKET_ADDR = {
    "cETH": "0x4e8fe8fd314cfc09bdb0942c5adcc37431abdcd0",
    "cNEAR": "0x8c14ea853321028a7bb5e4fb0d0147f183d3b677",
    "cUSDC": "0xe5308dc623101508952948b141fd9eabd3337d99",
    "cUSDT": "0x845e15a441cfc1871b7ac610b0e922019bad9826",
    "cWBTC": "0xfa786bac375d8806185555149235acdb182c033b",
}
LIQ_INC = 1.1
PSHARE = 1.1 * (1 - 0.028)  # 1.0692 liquidator share per unit repaid

def compute(real):
    total = 0.0
    rows = []
    n_prof = 0
    for a, p in pos.items():
        S = short[a]["shortfall"] / 1e18
        coll = {}
        for m in RATE:
            b = p["balances"].get(m, 0)
            if b > 0:
                coll[m] = b / 1e8 * RATE[m] * ORACLE[m]
        debt = {}
        for m in RATE:
            d = p["debts"].get(m, 0)
            if d > 0:
                debt[m] = d / (10 ** DEC[m]) * ORACLE[m]
        entered = set(x.lower() for x in p["entered"])
        best = (0.0, None)
        for c, cv in coll.items():
            if MARKET_ADDR[c] not in entered or cv <= 0:
                continue
            cf = CF[c]
            cap_short = S / (1 - LIQ_INC * cf) if LIQ_INC * cf < 1 else float("inf")
            for d, dv in debt.items():
                cap = min(dv, cv / PSHARE, cap_short)
                if cap <= 0:
                    continue
                profit = cap * PSHARE * (real[c] / ORACLE[c]) - cap * (real[d] / ORACLE[d])
                if profit > best[0]:
                    best = (profit, (d, c, cap))
        if best[0] > 0.02:  # net of gas-ish (Aurora cheap)
            total += best[0]
            n_prof += 1
        rows.append({"account": a, "shortfall": S,
                     "profit": best[0], "detail": best[1],
                     "coll": {k: round(v, 4) for k, v in coll.items()},
                     "debt": {k: round(v, 4) for k, v in debt.items()}})
    return total, n_prof, rows

for label, real in [("DeFiLlama", REAL_DL), ("Aurigami-live", REAL_AURI)]:
    total, n_prof, rows = compute(real)
    print(f"=== {label} real prices ===")
    print(f"profitable accounts: {n_prof} / {len(pos)}; total net liquidation profit: ${total:,.2f}")

total, n_prof, rows = compute(REAL_DL)
rows.sort(key=lambda r: -r["profit"])
json.dump(rows, open("liquidation_econ.json", "w"), indent=1)
print("\nTop 25 by profit (DeFiLlama basis):")
for r in rows[:25]:
    d = r["detail"]
    print(f"{r['account']} shortfall ${r['shortfall']:.4f} profit ${r['profit']:.2f} repay=${d[2]:.2f} debt={d[0]} coll={d[1]} collvals={r['coll']} debts={r['debt']}")

#!/usr/bin/env python3
"""Compute live value per chain: aToken claims (supply), cash, debt, in USD at oracle prices.
Also classifies each reserve: withdrawable (cash>0), stuck (cash==0), bad-debt gap (debt>supply+cash).
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
st = json.load(open(os.path.join(HERE, "state-all.json")))
# use market prices where available for fairness (oracle == market anyway); prefer oracle for internal consistency
pc = json.load(open(os.path.join(HERE, "price-compare.json")))
mkt = {(r["chain"], r["asset"]): r for r in pc["rows"]}

out = {}
grand = {"supply": 0.0, "cash": 0.0, "debt": 0.0}
for ch, s in st.items():
    rows = []
    tot = {"supply": 0.0, "cash": 0.0, "debt": 0.0}
    for r in s.get("reserves", []):
        if not isinstance(r, dict) or "config" not in r:
            continue
        dec = r.get("assetDecimals") or 18
        scale = 10 ** dec
        m = mkt.get((ch, r["asset"]), {})
        px = r.get("oraclePrice")
        price = px / 1e8 if px else (m.get("market_price_usd") or 0)
        sup = (r.get("aTokenTotalSupply") or 0) / scale
        cash = (r.get("cash") or 0) / scale
        debt = ((r.get("stableDebtTotal") or 0) + (r.get("variableDebtTotal") or 0)) / scale
        row = {
            "symbol": r.get("assetSymbol"), "asset": r["asset"], "price_usd": round(price, 6),
            "supply_tokens": sup, "cash_tokens": cash, "debt_tokens": debt,
            "supply_usd": round(sup * price, 2), "cash_usd": round(cash * price, 2),
            "debt_usd": round(debt * price, 2),
            "frozen": r["config"]["frozen"], "paused": r["config"]["paused"],
            "ltv": r["config"]["ltv"], "liq_bonus": r["config"]["liq_bonus"],
        }
        tot["supply"] += row["supply_usd"]; tot["cash"] += row["cash_usd"]; tot["debt"] += row["debt_usd"]
        rows.append(row)
    out[ch] = {"block": s.get("block"), "pool": s.get("pool"), "paused": s.get("pool_paused"),
               "reserves": rows, "total": {k: round(v, 2) for k, v in tot.items()}}
    for k in grand: grand[k] += tot[k]
    print(f"{ch:>10} supply=${tot['supply']:>12,.2f} cash=${tot['cash']:>12,.2f} debt=${tot['debt']:>12,.2f}")
    for row in rows:
        if row["supply_usd"] > 10 or row["cash_usd"] > 10 or row["debt_usd"] > 10:
            print(f"    {str(row['symbol']):>8} px={row['price_usd']:>10} supply=${row['supply_usd']:>10,.2f} cash=${row['cash_usd']:>10,.2f} debt=${row['debt_usd']:>10,.2f} frz={row['frozen']}")
print(f"{'TOTAL':>10} supply=${grand['supply']:,.2f} cash=${grand['cash']:,.2f} debt=${grand['debt']:,.2f}")
out["_total"] = {k: round(v, 2) for k, v in grand.items()}
json.dump(out, open(os.path.join(HERE, "live-value.json"), "w"), indent=1)
print("saved live-value.json")

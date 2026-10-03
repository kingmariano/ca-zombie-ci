#!/usr/bin/env python3
"""Compute the final market table + category totals for the Ironclad README (read-only)."""
import json

st = json.load(open("/home/heisenberg/CA/ironclad-finance/analysis/state_dump.json"))
prices = json.load(open("/home/heisenberg/CA/ironclad-finance/analysis/real_prices.json"))

# real prices (DefiLlama, fetched 2026-10-03)
REAL = {
    "USDC": 0.9999363336498337, "USDT": 0.9998644614994452, "WETH": 2681.7173437160063,
    "ezETH": 2908.4466919481147, "weETH": 2961.905408501613, "wrsETH": 2811.8043513841844,
    "M-BTC": 70232.98804085898, "weETH.mode": 2961.905408501613, "MODE": 0.00008739164147996656,
    "sUSDe": 1.250710593603408, "uniBTC": 84407.4251274835,
}
rows = []
for a, e in st["reserves"].items():
    dec = e["decimals"]
    op = (e["oraclePrice"] or 0) / 1e8 if e["oraclePrice"] else None
    rp = REAL.get(e["symbol"])
    supply = int(e["aTokenTotalSupply"] or 0) / 10**dec
    vdebt = int(e["variableDebtTotalSupply"] or 0) / 10**dec
    avail = int(e["aTokenUnderlyingBalance"] or 0) / 10**dec
    rows.append({
        "symbol": e["symbol"], "asset": a, "decimals": dec,
        "oracle_price": op, "real_price": rp,
        "supply_units": supply, "vdebt_units": vdebt, "avail_units": avail,
        "supply_usd_real": supply * rp if rp else None,
        "vdebt_usd_real": vdebt * rp if rp else None,
        "avail_usd_real": avail * rp if rp else None,
        "avail_usd_oracle": avail * op if op else None,
        "frozen": e["cfg"]["frozen"], "ltv": e["cfg"]["ltv"], "liq_threshold": e["cfg"]["liqThreshold"],
        "liq_bonus": e["cfg"]["liqBonus"], "reserve_factor": e["cfg"]["reserveFactor"],
        "liq_index": int(e["liquidityIndex"]) / 1e27,
        "last_update": e["lastUpdateTimestamp"],
    })

tot_supply = sum(r["supply_usd_real"] or 0 for r in rows)
tot_debt = sum(r["vdebt_usd_real"] or 0 for r in rows)
tot_avail_real = sum(r["avail_usd_real"] or 0 for r in rows)
tot_avail_oracle = sum(r["avail_usd_oracle"] or 0 for r in rows)

print(f"block: {st['block']} | paused: {st['paused']}")
print(f"{'asset':10} {'oracle$':>10} {'real$':>10} {'supply':>16} {'vDebt':>16} {'avail':>14} {'avail$real':>11} {'frozen':>6}")
for r in rows:
    print(f"{r['symbol']:10} {str(round(r['oracle_price'],4) if r['oracle_price'] else '-'):>10} "
          f"{str(round(r['real_price'],4) if r['real_price'] else '-'):>10} "
          f"{r['supply_units']:>16,.4f} {r['vdebt_units']:>16,.4f} {r['avail_units']:>14,.6f} "
          f"{str(round(r['avail_usd_real'] or 0,0)):>11} {str(r['frozen']):>6}")
print(f"\nTOTAL supply claims (real $): {tot_supply:,.0f}")
print(f"TOTAL variable debt (real $): {tot_debt:,.0f}")
print(f"TOTAL available liquidity (real $): {tot_avail_real:,.0f}")
print(f"TOTAL available liquidity (oracle $): {tot_avail_oracle:,.0f}")

json.dump({"rows": rows, "tot_supply_real": tot_supply, "tot_debt_real": tot_debt,
           "tot_avail_real": tot_avail_real, "tot_avail_oracle": tot_avail_oracle,
           "block": st["block"], "paused": st["paused"]},
          open("/home/heisenberg/CA/ironclad-finance/analysis/final_numbers.json", "w"), indent=1)

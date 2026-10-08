#!/usr/bin/env python3
"""Normalize LaChain market scan into lachain_markets.json."""
import json

raw = json.load(open('/home/heisenberg/CA/c-13/analysis/lachain_markets_raw.json'))
ORACLE_PRICES = {  # from lachain oracle getUnderlyingPrice (1e18-scaled human price)
    "cUXD": 1.0, "cLAC": 0.009995, "cWETH": 2454.26574339,
    "cWBTC": 77971.03898169, "cUSDT": 1.0, "cUSDC": 1.0,
}
# cToken decimals 8. Underlying decimals per market.
U_DEC = {"cUXD": 18, "cLAC": 18, "cWETH": 18, "cWBTC": 8, "cUSDT": 6, "cUSDC": 6}

out = {
    "chain": {"name": "LaChain", "chain_id": 274, "native": "LAC",
              "rpc": ["https://rpc1.mainnet.lachain.network", "https://rpc2.mainnet.lachain.network"],
              "explorer": "https://explorer.lachain.network",
              "stack": "Polygon Edge v0.6.3 (Geth fork)"},
    "comptroller_proxy": raw["comptroller"],
    "comptroller_impl_from_repo": "0xB45435f4d5Fa43C8Fd59199beA39D5A023D0d20c",
    "oracle": raw["oracle"],
    "oracle_type": "SimplePriceOracle (admin/authorized-set, no bounds; owner = 4-of-7 multisig 0x8D3bdc2E35097B46Cd5Cc13808e47d79AF5FbB3C)",
    "admin": raw["admin"],
    "close_factor": 0.5, "liquidation_incentive": 0.08,
    "transfer_guardian_paused": raw["transferGuardianPaused"],
    "seize_guardian_paused": raw["seizeGuardianPaused"],
    "mint_guardian_paused_global": raw["mintGuardianPaused_global"],
    "borrow_guardian_paused_global": raw["borrowGuardianPaused_global"],
    "block": raw["block"],
    "source": "on-chain RPC reads (read-only) + HelperConfig.s.sol (LaChain/capyfi-sc) + DefiLlama compound.js registry",
    "markets": [],
}

for m in raw["markets"]:
    sym = m["symbol"]
    u = m.get("underlying")
    dec = U_DEC.get(sym, m.get("underlying_decimals") or 18)
    cash = int(m.get("cash") or 0) / 10**dec
    borrows = int(m.get("totalBorrowsCurrent") or m.get("totalBorrows") or 0) / 10**dec
    reserves = int(m.get("totalReserves") or 0) / 10**dec
    supply_underlying = cash + borrows - reserves
    exr = int(m.get("exchangeRateCurrent") or 0)
    # scaling: CErc20 1e(10+u); CEther/native 1e28
    scaling = 10**(10 + dec) if u else 10**28
    exr_human = exr / scaling
    price = ORACLE_PRICES.get(sym)
    cf = int(m.get("collateralFactorMantissa") or 0) / 1e18
    rec = {
        "symbol": sym,
        "market": m["market"],
        "underlying": u if u else "native LAC (CEther-style CLac)",
        "underlying_decimals": dec,
        "is_native": bool(m.get("isCEther")),
        "cash": cash, "cash_usd_at_oracle": round(cash * price, 2) if price else None,
        "supply_underlying": supply_underlying,
        "supply_usd_at_oracle": round(supply_underlying * price, 2) if price else None,
        "borrows_underlying": borrows,
        "borrows_usd_at_oracle": round(borrows * price, 2) if price else None,
        "reserves_underlying": reserves,
        "utilization_pct": round(borrows / (cash + borrows) * 100, 2) if (cash + borrows) > 0 else 0,
        "exchange_rate_current_human": exr_human,
        "collateral_factor": cf,
        "oracle_price_usd": price,
        "oracle_price_raw": int(m.get("oracle_price") or 0),
        "mint_paused": m.get("mintGuardianPaused"),
        "borrow_paused": m.get("borrowGuardianPaused"),
        "is_listed": m.get("isListed"),
        "borrow_cap": m.get("borrowCap"),
        "interest_rate_model": m.get("interestRateModel"),
        "admin": m.get("admin"),
        "implementation": m.get("implementation"),
        "whitelist": "none (older cToken code on LaChain; whitelist() reverts)",
        "notes": [],
    }
    if sym == "cUXD" and borrows > supply_underlying:
        rec["notes"].append("insolvent on paper: borrows (%.2f) > cash+borrows-reserves supply (%.2f); oracle fixed at $1.00" % (borrows, supply_underlying))
    if sym == "cWBTC" and m["market"].lower() == "0x25f38518dc45f6b20f716e508b8f468c97b2d4a9":
        rec["notes"].append("legacy market, fully paused, zero supply (superseded by 0x694C3940B4680504a82d6c30E64377B0D2e9d251)")
    if sym == "cLAC":
        rec["notes"].append("native-LAC CEther-style market (CLac), CF 75%, mint/borrow not paused")
    out["markets"].append(rec)

json.dump(out, open('/home/heisenberg/CA/c-13/analysis/lachain_markets.json', 'w'), indent=1)
print("wrote lachain_markets.json,", len(out["markets"]), "markets")
for m in out["markets"]:
    print(f'{m["symbol"]:6} cf={m["collateral_factor"]:.2f} cash={m["cash"]:,.2f} borrows={m["borrows_underlying"]:,.2f} px={m["oracle_price_usd"]} usd_cash={m["cash_usd_at_oracle"]}')

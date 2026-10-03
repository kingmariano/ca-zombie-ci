#!/usr/bin/env python3
import json

d = json.load(open("/home/heisenberg/CA/scream/analysis/markets.json"))
cs = d["comptroller_state"]
print("block", d["block"], "markets", d["market_count"])
print("comptroller:", json.dumps(cs, indent=1))
print()
hdr = f"{'symbol':10} {'underlying':12} {'cash':>18} {'totalSupply':>22} {'totalBorrows':>20} {'exRate':>16} {'CF':>5} {'oracleP':>14} {'bCaps':>8} {'bgP':>4} {'mgP':>4}"
print(hdr)
for a, m in d["markets"].items():
    def num(k):
        v = m.get(k)
        return v if isinstance(v, int) else -1
    sym = m.get("symbol()") or "?"
    und = m.get("underlying()")
    unds = und[-6:] if isinstance(und, str) else "?"
    dec = m.get("underlying_decimals", 18)
    cash = num("cash()") / (10 ** (dec if isinstance(dec, int) and dec < 30 else 18))
    ts = num("totalSupply()") / 1e8  # cToken 8 decimals
    tb = num("totalBorrows()") / (10 ** (dec if isinstance(dec, int) and dec < 30 else 18))
    ex = num("exchangeRateStored()")
    mk = m.get("markets(a)", {})
    cf = mk.get("collateralFactorMantissa") if isinstance(mk, dict) else None
    op = num("getUnderlyingPrice(a)")
    bc = num("borrowCaps(a)")
    bg = num("borrowGuardianPaused(a)")
    mg = num("mintGuardianPaused(a)")
    print(f"{sym:10} {unds:12} {cash:18.4f} {ts:22.4f} {tb:20.4f} {ex:16} {cf:5} {op:14} {bc:8} {bg:4} {mg:4}")

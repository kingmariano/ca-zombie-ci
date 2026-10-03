#!/usr/bin/env python3
"""C-37 valuation: turn native_scan2.json + aave scan + prices into USD tables."""
import json, sys
sys.set_int_max_str_digits(200000)
res = json.load(open("/home/heisenberg/CA/c-37/analysis/native_scan2.json"))
prices = json.load(open("/home/heisenberg/CA/c-37/analysis/prices.json"))
prices["WETH"] = prices.get("WETH") or prices.get("ETH")
prices["SAI"] = 1.0  # deprecated DAI; llama price is stale/wrong

DEC = {"USDC": 6, "WBTC": 8, "cUSDC": 8, "cDAI": 8, "cCOMP": 8, "CREAM": 18}

def human(sym, v):
    return v / 10 ** DEC.get(sym, 18)

def usd(sym, v):
    p = prices.get(sym)
    return None if p is None else human(sym, v) * p

def show(section, d):
    print(f"===== {section}")
    tot = 0.0
    unpriced = []
    for s, v in d.get("balances", {}).items():
        u = usd(s, v)
        if u is None:
            unpriced.append((s, human(s, v)))
        else:
            tot += u
            print(f"  {s:12} {human(s,v):18.4f}  ${u:,.2f}")
    if d.get("totalSupply") is not None:
        print(f"  totalSupply = {d['totalSupply']}")
    if unpriced:
        print(f"  unpriced: {unpriced}")
    print(f"  SUM priced = ${tot:,.2f}")
    return tot

totals = {}
totals["setv1_vault"] = show("SetV1 Vault", res["setv1_vault"])
totals["dpi"] = show("DPI", res["dpi"])
totals["defipp"] = show("DEFI++", res["defipp"])
totals["pipt"] = show("PIPT", res["pipt"])
totals["bdi"] = show("BDI", res["bdi"])
totals["cook_cli"] = show("Cook CLI", res["cook_cli"])
for k in res:
    if k.startswith("indexed_"):
        totals[k] = show(k, res[k])

print("\nyam_emp:", res["yam_emp"])
print("ustonks_supply:", res["ustonks_supply"])
print("\nTOTALS:", json.dumps({k: round(v, 2) for k, v in totals.items()}, indent=1))

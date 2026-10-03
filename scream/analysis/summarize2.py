#!/usr/bin/env python3
import json

d = json.load(open("/home/heisenberg/CA/scream/analysis/state.json"))
print("block", d["block"])
print("comptroller:", json.dumps(d["comptroller"]))
print("oracle:", json.dumps(d["oracle"]))
print()
hdr = f"{'symbol':10} {'und_dec':>3} {'cash':>20} {'totalSupply(ct)':>18} {'borrows':>20} {'exRate':>22} {'borrowIdx':>22} {'accrBlk':>10} {'CF':>5} {'oracleP':>16} {'agg':>14}"
print(hdr)
for a, m in d["markets"].items():
    def n(k):
        v = m.get(k)
        return v if isinstance(v, int) else -1
    sym = m.get("symbol()") or "?"
    dec = m.get("und_dec")
    dec = dec if isinstance(dec, int) and 0 < dec < 30 else 18
    cash = n("getCash()") / 10**dec
    ts = n("totalSupply()") / 1e8
    tb = n("totalBorrows()") / 10**dec
    ex = n("exchangeRateStored()")
    bi = n("borrowIndex()")
    ab = n("accrualBlockNumber()")
    mk = m.get("markets(address)", {})
    cf = mk.get("cf") if isinstance(mk, dict) else None
    op = m.get("getUnderlyingPrice(address)")
    op = op if isinstance(op, int) else -1
    agg = m.get("aggregators(address)")
    aggs = agg[-6:] if isinstance(agg, str) else "?"
    print(f"{sym:10} {dec:>3} {cash:20.4f} {ts:18.4f} {tb:20.4f} {ex:22} {bi:22} {ab:>10} {cf:5} {op:16} {aggs:>14}")
print()
# totals in USD-ish terms (cash only)
print("=== underlying balances of markets vs getCash ===")
for a, m in d["markets"].items():
    sym = m.get("symbol()") or "?"
    g = m.get("getCash()")
    b = m.get("und_bal_market")
    dec = m.get("und_dec")
    if isinstance(g, int) and isinstance(b, int) and g != b:
        print(f"{sym:10} getCash={g} balanceOf={b} dec={dec} diff={b-g}")

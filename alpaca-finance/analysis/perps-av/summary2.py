#!/usr/bin/env python3
"""Precise table: symbol, impl hex, supply, equity, cash, ratio, LP dust, isTerminated."""
import json
snap = json.load(open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/snap_vaults.json"))
r2 = json.load(open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/snap_r2.json"))
mj = json.load(open("/tmp/opencode/alpaca/mainnet.json"))
R, R2 = snap["results"], r2["results"]

def g(k, i=0):
    r = R.get(k)
    if not r or not r.get("ok") or "decoded" not in r: return None
    return r["decoded"][i]

def g2(k, i=0):
    r = R2.get(k)
    if not r or not r.get("ok") or "decoded" not in r: return None
    return r["decoded"][i]

print(f"{'symbol':<22}{'impl':<44}{'supply':>11}{'equity$':>11}{'cash':>11}{'cv':>5}{'term':>6}{'swLP':>9}{'awLP':>9}")
rows = []
for v in mj["DeltaNeutralVaults"]:
    s = v["symbol"]
    impl = g(f"{s}|impl")
    implhex = hex(int(impl)) if impl else "?"
    supply = g(f"{s}|totalSupply")
    eq = g(f"{s}|totalEquityValue")
    cash = g(f"{s}|balStable")
    sw = g(f"{s}|sw|totalLp")
    aw = g(f"{s}|aw|totalLp")
    term = g2(f"{s}|isTerminated")
    cv = (int(eq) / int(cash)) if cash and int(cash) > 0 and eq else 0
    def f(x, nd=4):
        return f"{int(x)/1e18:.{nd}f}" if x is not None else "ERR"
    print(f"{s:<22}{implhex:<44}{f(supply):>11}{f(eq):>11}{f(cash):>11}{cv:>5.3f}{str(term):>6}{f(sw,3):>9}{f(aw,3):>9}")
    rows.append({"symbol": s, "addr": v["address"], "impl": implhex, "supply": supply, "equity": eq,
                 "cash": cash, "terminated": term, "swLp": sw, "awLp": aw,
                 "stableVault": v["stableVault"], "assetVault": v["assetVault"],
                 "stableWorker": v["stableDeltaWorker"], "assetWorker": v["assetDeltaWorker"]})
json.dump(rows, open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/table_vaults2.json", "w"), indent=1)
# positions detail
print("\npositionInfo (stableEq, stableDebtVal, stableLP, assetEq, assetDebtVal, assetLP):")
for v in mj["DeltaNeutralVaults"]:
    s = v["symbol"]
    pi = R.get(f"{s}|positionInfo")
    if pi and pi.get("ok") and "decoded" in pi:
        vals = [int(x)/1e18 for x in pi["decoded"]]
        if any(abs(x) > 1e-12 for x in vals):
            print(f"  {s:<22}", [f'{x:.6f}' for x in vals])

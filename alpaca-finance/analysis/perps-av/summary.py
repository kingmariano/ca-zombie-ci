#!/usr/bin/env python3
"""Summarize snap_vaults.json into a table + key findings."""
import json
snap = json.load(open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/snap_vaults.json"))
mj = json.load(open("/tmp/opencode/alpaca/mainnet.json"))
R = snap["results"]

def d(k, i=None):
    r = R.get(k)
    if not r or not r.get("ok"):
        return None
    if "decoded" not in r:
        return None
    vals = r["decoded"]
    if i is None:
        return vals[0] if len(vals) == 1 else vals
    return vals[i]

print(f"block: {snap.get('block')}\n")
hdr = f"{'symbol':<24}{'impl':<14}{'supply':>12}{'equity$':>12}{'vStable':>12}{'vAsset':>12}{'swLP':>10}{'awLP':>10}"
print(hdr)
rows = []
for v in mj["DeltaNeutralVaults"]:
    s = v["symbol"]
    impl = d(f"{s}|impl")
    supply = d(f"{s}|totalSupply")
    eq = d(f"{s}|totalEquityValue")
    bals = d(f"{s}|balStable")
    bala = d(f"{s}|balAsset")
    swlp = d(f"{s}|sw|totalLp")
    awlp = d(f"{s}|aw|totalLp")
    def f(x, nd=6):
        if x is None: return "ERR"
        return f"{int(x)/1e18:.6f}"
    print(f"{s:<24}{(impl or '')[-12:]:<14}{f(supply):>12}{f(eq):>12}{f(bals):>12}{f(bala):>12}{f(swlp):>10}{f(awlp):>10}")
    rows.append({"symbol": s, "address": v["address"], "impl": impl, "supply": supply, "equity": eq,
                 "vStable": bals, "vAsset": bala, "swLp": swlp, "awLp": awlp})
json.dump(rows, open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/table_vaults.json", "w"), indent=1)

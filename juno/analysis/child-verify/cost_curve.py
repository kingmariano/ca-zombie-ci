#!/usr/bin/env python3
"""Cost curves for buying/selling JUNO on all constant-product venues (static, latest state).
All pool reserves and trade sizes are handled in BASE units (ujuno etc.); USD conversion divides by 1e6
(all relevant counterpart denoms - uatom, uosmo, USDC - use 6 decimals).
Fee = 0.3%. USD prices: JUNO $0.0089336, ATOM $1.786562, OSMO $0.0360588, USDC $0.999956.
"""
import json

JUNO_USD = 0.008933585044799483
ATOM_USD = 1.7865622511295747
OSMO_USD = 0.03605875532526531
USDC_USD = 0.9999564395197732
FEE = 0.003

ATOM_JUNO = "ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9"
ATOM_OSMO = "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2"
USDC_JUNO = "ibc/EAC38D55372F38F1AFD68DF7FE9EF762DCF69F26520643CF3F9D292A738D8034"
ALLUSDC = "factory/osmo147h5x9pcj7lm0cttlaefx6sqq5vdfnmwfcqxkmjd7exqm9gc7grqhr75m0/alloyed/allUSDC"
PRICE = {ATOM_JUNO: ATOM_USD, ATOM_OSMO: ATOM_USD, USDC_JUNO: USDC_USD, "uosmo": OSMO_USD, ALLUSDC: USDC_USD}

gamm = json.load(open("osmosis_gamm_all.json"))["juno_pools"]
wynd = json.load(open("wynd_juno_pools.json"))["juno_pairs"]
loop = json.load(open("loop_juno_pools.json"))["juno_pairs"]
ww = json.load(open("whitewhale_juno_pools.json"))["juno_pairs"]
cl = json.load(open("osmosis_cl_juno.json"))["juno_pools"]

cp = []
for p in gamm:
    others = [(dn, int(a)) for dn, a in p["reserves"]
              if dn != "ibc/46B44899322F3CD854D2D46DEEF881958467CDD4B3B10086DA49296BBED94BED"]
    if len(others) != 1:
        print("skip multi-asset gamm pool", p["id"])
        continue
    dn, amt = others[0]
    cp.append({"venue": "osmosis_gamm", "id": str(p["id"]), "J": p["juno_ujuno"], "R": amt, "denom": dn})
for p in wynd:
    cp.append({"venue": "wynd", "id": p["pair"], "J": p["juno_ujuno"], "R": p["other_amount"], "denom": p["other_denom"]})
for p in loop:
    cp.append({"venue": "loop", "id": p["pair"], "J": p["juno_ujuno"], "R": p["other_amount"], "denom": p["other_denom"]})
for p in ww:
    cp.append({"venue": "whitewhale", "id": p["pair"], "J": p["juno_ujuno"], "R": p["other_amount"], "denom": p["other_denom"]})
for p in json.load(open("raw/junodex_juno_pools.json")):
    others = [(dn, a) for dn, a in p["assets"].items() if dn != "ujuno"]
    if others:
        cp.append({"venue": "junodex_test", "id": p["pair"], "J": p["assets"]["ujuno"],
                   "R": others[0][1], "denom": others[0][0]})

cp_tot = sum(p["J"] for p in cp) / 1e6
cl_tot = sum(p["juno_ujuno"] for p in cl) / 1e6
for p in cp:
    pu = PRICE.get(p["denom"])
    p["usd_side"] = p["R"] / 1e6 * pu if pu else None
priced = [p for p in cp if p["usd_side"] is not None]
priced_j = sum(p["J"] for p in priced) / 1e6
priced_usd = sum(p["usd_side"] for p in priced)

def buy_cost(J, R, n, fee=FEE):
    """cost in R base units to buy n ujuno base units; None if n >= J."""
    if n >= J:
        return None
    return R * n / (J - n) / (1 - fee)

def sell_proceeds(J, R, n, fee=FEE):
    """proceeds in R base units selling n ujuno; capped at R."""
    return min(R * n / (J + n) * (1 - fee), R)

out = {"prices": {"JUNO": JUNO_USD, "ATOM": ATOM_USD, "OSMO": OSMO_USD, "USDC": USDC_USD},
       "fee": FEE, "total_juno_all_venues": cp_tot + cl_tot, "major_pools": [], "aggregate": {},
       "venue_totals": {v: sum(p["J"] for p in cp if p["venue"] == v) / 1e6
                        for v in ("osmosis_gamm", "wynd", "loop", "whitewhale", "junodex_test")} | {"osmosis_cl": cl_tot}}

print(f"CP pools: {len(cp)}, CP JUNO total: {cp_tot:,.4f}")
print(f"CL JUNO total: {cl_tot:,.4f}")
print(f"ALL VENUES JUNO total: {cp_tot + cl_tot:,.4f}")
print(f"priced CP pools: {len(priced)}, JUNO {priced_j:,.4f}, counter USD side ${priced_usd:,.2f}")

majors = [
    ("WYND JUNO/ATOM", next(p for p in cp if p["id"] == "juno17uv02azt545ag23xq7whw6z3r3chw7jwztnr9lypugy62drq3caqeyd2r3")),
    ("WYND JUNO/USDC", next(p for p in cp if p["id"] == "juno1gqy6rzary8vwnslmdavqre6jdhakcd4n2z4r803ajjmdq08r66hq7zcwrj")),
    ("OSMO GAMM 498 JUNO/ATOM", next(p for p in cp if p["id"] == "498")),
    ("OSMO GAMM 497 JUNO/OSMO", next(p for p in cp if p["id"] == "497")),
]

print("\n=== major pool cost curves (fee 0.3%) ===")
for name, p in majors:
    pu = PRICE[p["denom"]]
    row = {"name": name, "pair": p["id"], "juno": p["J"] / 1e6, "counter_denom": p["denom"],
           "counter_amount": p["R"] / 1e6, "counter_usd_side": p["usd_side"], "buys": {}, "sells": {}}
    print(f"\n{name}: J={p['J']/1e6:,.2f} JUNO, R={p['R']/1e6:,.4f} ({p['denom'][:24]}), USD side ${p['usd_side']:,.2f}")
    for N in (500_000, 1_000_000, 2_000_000):
        c = buy_cost(p["J"], p["R"], N * 1_000_000)
        if c is None:
            row["buys"][str(N)] = {"counter": None, "usd": None, "note": "N >= pool JUNO; impossible in this pool"}
            print(f"  buy {N:>9,}: IMPOSSIBLE in this pool (N >= pool JUNO)")
        else:
            usd = c / 1e6 * pu
            row["buys"][str(N)] = {"counter": c / 1e6, "usd": usd, "avg_price_usd": usd / N}
            print(f"  buy {N:>9,}: {c/1e6:,.3f} {p['denom'][:12]} = ${usd:,.2f} (avg ${usd/N:.5f}/JUNO)")
    for N in (1_000_000, 5_000_000, 20_490_612):
        pr = sell_proceeds(p["J"], p["R"], N * 1_000_000)
        usd = pr / 1e6 * pu
        row["sells"][str(N)] = {"counter": pr / 1e6, "usd": usd, "avg_price_usd": usd / N}
        print(f"  sell {N:>9,}: {pr/1e6:,.3f} {p['denom'][:12]} = ${usd:,.2f} (avg ${usd/N:.5f}/JUNO)")
    out["major_pools"].append(row)

AGG_J = sum(p["J"] for p in priced)
print("\n=== aggregate priced CP pools (split proportional to JUNO reserves) ===")
agg = {"method": "trade split across priced pools in proportion to each pool's JUNO reserve",
       "priced_pools": len(priced), "priced_juno": priced_j, "priced_counter_usd": priced_usd,
       "buys": {}, "sells": {}}
for N in (500_000, 1_000_000, 2_000_000, 3_400_000):
    tot_usd = 0; ok = True; parts = []
    for p in priced:
        share = p["J"] / AGG_J
        n = int(N * 1_000_000 * share)
        c = buy_cost(p["J"], p["R"], n)
        if c is None:
            ok = False; continue
        usd = c / 1e6 * PRICE[p["denom"]]
        tot_usd += usd
        parts.append([p["id"], round(n / 1e6), round(usd, 2)])
    agg["buys"][str(N)] = {"usd": tot_usd, "avg_price_usd": tot_usd / N, "feasible": ok, "parts": parts}
    print(f"  buy {N:>9,}: ${tot_usd:,.2f} feasible={ok} avg ${tot_usd/N:.5f}/JUNO")

for N in (1_000_000, 5_000_000, 20_490_612, 50_000_000):
    tot_usd = 0; parts = []
    for p in priced:
        share = p["J"] / AGG_J
        n = int(N * 1_000_000 * share)
        pr = sell_proceeds(p["J"], p["R"], n)
        usd = pr / 1e6 * PRICE[p["denom"]]
        tot_usd += usd
        parts.append([p["id"], round(n / 1e6), round(usd, 2)])
    agg["sells"][str(N)] = {"usd": tot_usd, "avg_price_usd": tot_usd / N, "parts": parts}
    print(f"  sell {N:>9,}: ${tot_usd:,.2f} avg ${tot_usd/N:.5f}/JUNO")

print("\n=== cost to buy 50% / 90% / 99% of every priced pool ===")
for frac in (0.5, 0.9, 0.99):
    tot_usd = 0; tot_j = 0
    for p in priced:
        n = int(frac * p["J"])
        c = buy_cost(p["J"], p["R"], n)
        tot_usd += c / 1e6 * PRICE[p["denom"]]
        tot_j += n
    agg[f"buy_{int(frac*100)}pct_priced"] = {"juno_bought": tot_j / 1e6, "usd_cost": tot_usd,
                                             "avg_price_usd": tot_usd / (tot_j / 1e6)}
    print(f"  buy {int(frac*100)}%: {tot_j/1e6:,.0f} JUNO for ${tot_usd:,.0f} (avg ${tot_usd/(tot_j/1e6):.5f}/JUNO)")

out["aggregate"] = agg
out["cl_note"] = ("CL pool 1097 holds 546,400 JUNO + 104,565 OSMO; tick-range liquidity, excluded from CP math. "
                  "Pool 3546 holds 67 JUNO / 0.60 allUSDC. Total JUNO across ALL venues (incl. CL): "
                  f"{cp_tot + cl_tot:,.2f} JUNO, far below the 15M JUNO target.")
json.dump(out, open("cost_curve.json", "w"), indent=1)
print("\nsaved cost_curve.json")

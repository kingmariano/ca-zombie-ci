#!/usr/bin/env python3
"""
Final economics with DEPLOYED semantics:
 - factory 1 pairs: COLLATERIZATION_RATE = 75% (repo version; empirically probed on fork)
 - factory 2 pairs: COLLATERIZATION_RATE = 85% (Sourcify-verified deployed source for 0x63fdafa5)
 - oracle-liveness gate: pairs whose oracle.get() reverts ("Stale Price Feed") block borrow/liquidate
Outputs ci-out/econ_summary.json
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")

d = json.load(open(os.path.join(OUT, "state_latest.json")))
pos = json.load(open(os.path.join(OUT, "positions.json")))
toks = d["tokens"]
prices = json.load(open("/tmp/opencode/cog_prices.json"))
prices['scroll:0x79379c0e09a41d7978f883a56246290ee9a8c4d3'] = 163.20437647880277
prices['scroll:0xb755039edc7910c1f1bd985d48322e55a31ac0bf'] = 0.36039696153033285

# factory membership from triage results
tri = json.load(open("/home/heisenberg/CA/l2-triage-b/ci-out/results.json"))
cog = [p for p in tri["protocols"] if p.get("slug") == "cog"][0]
factory_of = {}
for t in cog["targets"]:
    f = "f1" if "factory 1" in t["label"] else "f2"
    for pr in t["pairs"]:
        factory_of[pr["pair"]] = f
LTV = {"f1": 75_000, "f2": 85_000}          # raw constants
LTVF = {"f1": 0.75, "f2": 0.85}             # fractions

def px(t): return prices.get(('scroll:' + t).lower()) or 0.0
def b(x): return int(x, 16) if isinstance(x, str) and x.startswith('0x') else None

rows = []
for p in d["pairs"]:
    if "err" in p: continue
    pair = p["pair"]; a = p["asset"]; c = p["collateral"]
    da = toks[a]["decimals"]; dc = toks[c]["decimals"]
    Pa = px(a); Pc = px(c)
    rate = (p.get("get_exchange_rate_sim") or {}).get("rate")
    alive = bool(p.get("get_exchange_rate_sim") and p["get_exchange_rate_sim"].get("updated"))
    stored_rate = p.get("exchange_rate")
    used_rate = rate if alive else stored_rate
    ta = p.get("total_asset") or [0, 0]; tb = p.get("total_borrow") or [0, 0]
    ab = p.get("asset_bal") or 0; cb = p.get("coll_bal") or 0
    ab_usd = ab / 10**da * Pa; cb_usd = cb / 10**dc * Pc
    debt_usd = tb[0] / 10**da * Pa
    fac = factory_of.get(pair, "?")
    ltv = LTVF.get(fac, 0)
    ltv_raw = LTV.get(fac, 0)
    rate_mkt = 1e18 * (Pa / Pc) * (10**dc / 10**da) if Pa and Pc else 0
    g = (used_rate / rate_mkt) if rate_mkt else 0
    paused = (b(p["paused"]) == 1)

    # borrow-and-default
    borrow_profit = 0.0; coll_needed = 0.0; cap_ok = False
    if (not paused) and alive and ab > 0 and used_rate and Pa and ltv > 0:
        # solvency: cs*ltv >= B*1.0005*rate  =>  need = B*1.0005*rate/ltv
        need_raw = ab * 1.0005 * used_rate / (ltv * 1e18)
        coll_needed = need_raw / 10**dc * Pc
        if coll_needed < ab_usd:
            borrow_profit = ab_usd - coll_needed
            cap_ok = True

    # liquidation
    liq_profit = 0.0; liq_pay = 0.0; n_liq = 0
    base_borrow = tb[1]; el_borrow = tb[0]
    for q in pos.get(pair, {}).get("positions", []):
        bp = q.get("borrow_part") or 0
        cs = q.get("collateral_share") or 0
        if bp <= 0 or base_borrow <= 0 or not used_rate or not alive or ltv_raw == 0: continue
        elastic = bp * el_borrow // base_borrow
        if elastic <= 0: continue
        collateral_amt = cs * 10**13 * ltv_raw
        if collateral_amt >= elastic * used_rate:   # solvent
            continue
        c_out = elastic * 1.12 * used_rate / 1e18
        c_got = cs if c_out > cs else c_out
        pay = elastic / 10**da * Pa
        get = c_got / 10**dc * Pc
        profit = get - pay
        if profit > 0:
            liq_profit += profit; liq_pay += pay; n_liq += 1

    rows.append({
        "pair": pair, "factory": fac, "asset": toks[a]["symbol"], "coll": toks[c]["symbol"],
        "paused": paused, "oracle_alive": alive, "ltv": ltv, "rate": used_rate, "g": g,
        "asset_usd": round(ab_usd, 2), "coll_usd": round(cb_usd, 2), "debt_usd": round(debt_usd, 2),
        "borrow_profit": round(borrow_profit, 2), "coll_needed": round(coll_needed, 2),
        "liq_profit": round(liq_profit, 2), "liq_pay": round(liq_pay, 2), "n_liq": n_liq,
        "lp_nominal": round((ta[0] + tb[0]) / 10**da * Pa, 2),
    })

json.dump(rows, open(os.path.join(OUT, "econ_summary.json"), "w"), indent=1)

bp = sum(r["borrow_profit"] for r in rows); lq = sum(r["liq_profit"] for r in rows)
print(f"asset-held ${sum(r['asset_usd'] for r in rows):,.2f}  coll-held ${sum(r['coll_usd'] for r in rows):,.2f}  debt ${sum(r['debt_usd'] for r in rows):,.2f}")
print(f"E-U borrow-and-default: ${bp:,.2f}")
print(f"E-U liquidation       : ${lq:,.2f}")
print(f"E-U TOTAL             : ${bp+lq:,.2f}")
print()
for r in sorted(rows, key=lambda x: -x["borrow_profit"]):
    if r["borrow_profit"] > 0.5:
        print(f"  BORROW {r['pair']} {r['asset']}/{r['coll']} f={r['factory']} ltv={r['ltv']/1000:.0f}% profit ${r['borrow_profit']:,.2f} (coll ${r['coll_needed']:,.2f}, g={r['g']:.4f})")
print()
for r in sorted(rows, key=lambda x: -x["liq_profit"]):
    if r["liq_profit"] > 0.01:
        print(f"  LIQ    {r['pair']} {r['asset']}/{r['coll']} f={r['factory']} ltv={r['ltv']/1000:.0f}% profit ${r['liq_profit']:,.2f} (pay ${r['liq_pay']:,.2f}, n={r['n_liq']})")

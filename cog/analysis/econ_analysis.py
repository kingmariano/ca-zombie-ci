#!/usr/bin/env python3
"""
Final analysis: for every pair compute
 (1) borrow-and-default profit available to an unprivileged attacker (rate < market => capacity > collateral)
 (2) profitable liquidation of existing positions (rate inflation => repay cheap debt, seize collateral)
Outputs ci-out/econ_summary.json + prints a table.
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

def px(t): return prices.get(('scroll:' + t).lower()) or 0.0
def b(x): return int(x, 16) if isinstance(x, str) and x.startswith('0x') else None

rows = []
for p in d["pairs"]:
    if "err" in p:
        continue
    pair = p["pair"]; a = p["asset"]; c = p["collateral"]
    da = toks[a]["decimals"]; dc = toks[c]["decimals"]
    Pa = px(a); Pc = px(c)
    rate = (p.get("get_exchange_rate_sim") or {}).get("rate") or p.get("exchange_rate")
    ta = p.get("total_asset") or [0, 0]; tb = p.get("total_borrow") or [0, 0]
    ab = p.get("asset_bal") or 0; cb = p.get("coll_bal") or 0
    ab_usd = ab / 10**da * Pa; cb_usd = cb / 10**dc * Pc
    debt_usd = tb[0] / 10**da * Pa
    rate_mkt = 1e18 * (Pa / Pc) * (10**dc / 10**da) if Pa and Pc else 0
    g = (rate / rate_mkt) if rate_mkt else 0
    paused = (b(p["paused"]) == 1)

    # ---- borrow-and-default ----
    borrow_profit = 0.0; coll_needed = 0.0
    if (not paused) and ab > 0 and rate and Pa:
        # attacker supplies collateral worth coll_needed to borrow the entire asset balance
        # capacity = coll_raw*7.5e17/rate >= ab  =>  coll_raw >= ab*rate/7.5e17
        need_raw = ab * rate / 7.5e17
        coll_needed = need_raw / 10**dc * Pc
        borrow_profit = ab_usd - coll_needed
        if borrow_profit < 0:
            borrow_profit = 0.0

    # ---- liquidation ----
    liq_profit = 0.0; liq_pay = 0.0; liq_get = 0.0; n_liq = 0
    row_pos = pos.get(pair, {})
    base_borrow = tb[1]; el_borrow = tb[0]
    for q in row_pos.get("positions", []):
        bp = q.get("borrow_part") or 0
        cs = q.get("collateral_share") or 0
        if bp <= 0 or base_borrow <= 0 or not rate:
            continue
        elastic = bp * el_borrow // base_borrow  # to_elastic floor
        if elastic <= 0:
            continue
        # solvency check (uses elastic debt)
        solv = (cs * 7.5e17) >= (elastic * rate)
        if solv:
            continue
        c_out = elastic * 1.12 * rate / 1e18
        full = (bp == base_borrow) or True  # attacker takes the max part (min(max, available)); cap needs full part
        capped = c_out > cs
        c_got = cs if capped else c_out
        # NOTE: the cap branch also requires borrow_part == available_borrow_part;
        # attacker sets max_borrow_parts >= available -> full. If c_out > cs and not capped -> underflow revert.
        if c_out > cs and not capped:
            continue
        pay = elastic / 10**da * Pa
        get = c_got / 10**dc * Pc
        profit = get - pay
        if profit > 0:
            liq_profit += profit; liq_pay += pay; liq_get += get; n_liq += 1

    rows.append({
        "pair": pair, "asset": toks[a]["symbol"], "coll": toks[c]["symbol"],
        "paused": paused, "rate": rate, "rate_mkt": rate_mkt, "g": g,
        "asset_usd": round(ab_usd, 2), "coll_usd": round(cb_usd, 2), "debt_usd": round(debt_usd, 2),
        "borrow_profit": round(borrow_profit, 2), "coll_needed": round(coll_needed, 2),
        "liq_profit": round(liq_profit, 2), "liq_pay": round(liq_pay, 2), "n_liq": n_liq,
        "lp_nominal": round((ta[0] + tb[0]) / 10**da * Pa, 2),
        "users_live": len(row_pos.get("positions", [])),
    })

json.dump(rows, open(os.path.join(OUT, "econ_summary.json"), "w"), indent=1)

tot_ab = sum(r["asset_usd"] for r in rows); tot_cb = sum(r["coll_usd"] for r in rows)
tot_debt = sum(r["debt_usd"] for r in rows); tot_bp = sum(r["borrow_profit"] for r in rows)
tot_lp = sum(r["liq_profit"] for r in rows)
print(f"TOTAL asset-held ${tot_ab:,.2f}  coll-held ${tot_cb:,.2f}  debt ${tot_debt:,.2f}")
print(f"E-U borrow-and-default total ${tot_bp:,.2f}")
print(f"E-U liquidation-profit total ${tot_lp:,.2f}")
print()
print("== borrow-and-default opportunities ==")
for r in sorted(rows, key=lambda x: -x["borrow_profit"]):
    if r["borrow_profit"] > 0.5:
        print(f"  {r['pair']} {r['asset']}/{r['coll']} profit ${r['borrow_profit']:,.2f} (need coll ${r['coll_needed']:,.2f}, pool asset ${r['asset_usd']:,.2f}, g={r['g']:.4f})")
print()
print("== liquidation opportunities ==")
for r in sorted(rows, key=lambda x: -x["liq_profit"]):
    if r["liq_profit"] > 0.5:
        print(f"  {r['pair']} {r['asset']}/{r['coll']} profit ${r['liq_profit']:,.2f} (pay ${r['liq_pay']:,.2f}, n={r['n_liq']}, g={r['g']:.3f})")
print()
print("== top pairs by assets ==")
for r in sorted(rows, key=lambda x: -x["asset_usd"])[:12]:
    print(f"  {r['pair']} {r['asset']}/{r['coll']} asset ${r['asset_usd']:,.0f} coll ${r['coll_usd']:,.0f} debt ${r['debt_usd']:,.0f} LPnom ${r['lp_nominal']:,.0f} paused={r['paused']} g={r['g']:.3f}")

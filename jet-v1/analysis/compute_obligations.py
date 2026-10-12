#!/usr/bin/env python3
"""Task A: full Jet v1 obligation census (read-only).

Inputs : obligations_keys.json, raw_batches/*.json.gz, accounts.json (market cache)
Outputs: obligations_full.json, obligations_summary.json, obligations_summary.md

Valuation follows the deployed program math (jet-v1 programs/jet/src/state/obligation.rs):
  value = notes_amount * note_exchange_rate * price
  - collateral positions use deposit_note_exchange_rate
  - loan positions use loan_note_exchange_rate
Health (on-chain rule): unhealthy <=> loan_value > 0 AND loan_value * min_collateral_ratio > collateral_value
  (min_collateral_ratio = 1.25 for all four reserves at the market cache snapshot)

Two price sets:
  - "oracle"  : the prices frozen in the market cache (last_updated_slot 451021492)
  - "real"    : live DEX/market prices for the same token mints (fetched from Jupiter v3 / CoinGecko)

Liquidator-bonus metrics (per the source, liquidation_bonus=300bps, min_cr=1.25):
  x = C/D; cap = limit_fraction * C with limit_fraction = (min_cr/x - 1) / (min_cr*(1-bonus) - 1)
  seized(r) = min(x*r, (1+bonus)*r, cap)   (r = repaid oracle value, r <= D; $10 floor ignored here)
  exact oracle profit = max_r seized(r) - r
  real PnL of the same on-chain liquidation = seized_oracle(r*) * ratio_coll - r* * ratio_loan
     with ratio_i = real_price_i / oracle_price_i
"""
import base64, gzip, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from parse_jet_accounts import parse_market, parse_obligation  # noqa: E402

MIN_CR = 1.25
BONUS = 0.03
MIN_PARTIAL = 10.0  # MIN_PARTIAL_LIQUIDATION_VALUE


def rpc(method, params, retries=4):
    import time
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(
                "https://api.mainnet-beta.solana.com",
                data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                headers={"Content-Type": "application/json", "User-Agent": "research-readonly/1.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read())
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2 * (i + 1))
    raise RuntimeError(last)


def get_real_prices(mints):
    """Live prices: Jupiter v3 for SPL tokens, CoinGecko for SOL fallback. Returns dict mint->usd."""
    out = {}
    try:
        url = "https://lite-api.jup.ag/price/v3?ids=" + ",".join(mints)
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "research-readonly/1.0"}), timeout=30) as r:
            d = json.loads(r.read())
        for mint, v in d.items():
            if isinstance(v, dict) and v.get("usdPrice"):
                out[mint] = {"usd": float(v["usdPrice"]), "source": "jupiter-v3", "liquidity": v.get("liquidity"), "blockId": v.get("blockId")}
    except Exception as e:  # noqa: BLE001
        print("WARN jupiter:", e, file=sys.stderr)
    try:
        with urllib.request.urlopen(urllib.request.Request(
                "https://api.coingecko.com/api/v3/simple/price?ids=solana,bitcoin,ethereum&vs_currencies=usd",
                headers={"User-Agent": "research-readonly/1.0"}), timeout=30) as r:
            cg = json.loads(r.read())
        out["_coingecko"] = {"solana": cg.get("solana", {}).get("usd"), "bitcoin": cg.get("bitcoin", {}).get("usd"), "ethereum": cg.get("ethereum", {}).get("usd")}
    except Exception as e:  # noqa: BLE001
        print("WARN coingecko:", e, file=sys.stderr)
    return out


def exact_oracle_profit(D, C, min_cr=MIN_CR, bonus=BONUS):
    """Max oracle-value profit of an on-chain liquidation for one (loan,collateral) reserve pair."""
    if D <= 0 or C <= 0:
        return {"liquidatable": False, "reason": "no_debt_or_no_collateral", "x": None, "profit_oracle": 0.0}
    x = C / D
    if x >= min_cr:
        return {"liquidatable": False, "reason": "healthy_oracle", "x": x, "profit_oracle": 0.0}
    c_ratio_ltv = min_cr / x
    limit_fraction = (c_ratio_ltv - 1) / (min_cr * (1 - bonus) - 1)
    cap = limit_fraction * C
    m = min(x, 1 + bonus)
    if m <= 1:
        profit = 0.0  # underwater: seized < repaid at every r
        r_star = 0.0
    elif cap >= m * D:
        profit = (m - 1) * D
        r_star = D
        cap = min(cap, C)
    else:
        r_star = cap / m
        profit = cap * (1 - 1 / m)
    return {"liquidatable": True, "x": x, "limit_fraction": limit_fraction, "cap": cap,
            "m": m, "r_star": r_star, "profit_oracle": profit,
            "seized_oracle": min(m * r_star, cap) if r_star else 0.0}


def real_pnl(D, C, ratio_loan, ratio_coll, pair):
    """Real-terms PnL of the same liquidation honouring the on-chain oracle math.
    Full flexibility over r: profit_real = max_r [ min(m r, cap) * ratio_coll - r * ratio_loan ]."""
    if D <= 0 or C <= 0:
        return 0.0
    x = C / D
    if x >= MIN_CR:
        return 0.0
    c_ratio_ltv = MIN_CR / x
    cap = ((c_ratio_ltv - 1) / (MIN_CR * (1 - BONUS) - 1)) * C
    m = min(x, 1 + BONUS)
    # seized(r) = min(m r, cap); profit(r) = seized*rc - r*rl
    # if m*rc > rl -> increase r until cap => r*=cap/m (if cap < m*D) else r=D
    if m * ratio_coll <= ratio_loan:
        return 0.0
    if cap >= m * D:
        return min(m * D, C) * ratio_coll - D * ratio_loan
    r_star = cap / m
    return cap * ratio_coll - r_star * ratio_loan


def main():
    accts = json.load(open(os.path.join(HERE, "accounts.json")))["accounts"]
    mkt = parse_market(base64.b64decode(accts["9oiXzad28vLhT2TkFoVRRRcwYKrSF7E3XPUJpwcarCAo"]["data_b64"]))
    oracle_prices = [c["price"] for c in mkt["cache"]]
    drates = [c["deposit_note_exchange_rate"] for c in mkt["cache"]]
    lrates = [c["loan_note_exchange_rate"] for c in mkt["cache"]]
    ref_slot = mkt["cache"][0]["last_updated_slot"]

    # mint order = reserve index order of the market
    reserve_mints = {
        0: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",   # USDC
        1: "So11111111111111111111111111111111111111112",      # wrapped SOL
        2: "9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E",     # solBTC (Sollet BTC)
        3: "2FPyTwcZLUg1MDrwsyoP4D6s1tM7hAkHYRjkNb5w6Pxk",     # solETH (Sollet ETH)
    }
    live = get_real_prices(list(reserve_mints.values()))
    json.dump(live, open(os.path.join(HERE, "live_prices.json"), "w"), indent=1)
    # real USD price per reserve index (fallbacks = parent-provided approx)
    fallback = {0: 1.0, 1: 110.41, 2: 54.66, 3: 299.52}
    real_prices = []
    price_sources = {}
    for ri, mint in reserve_mints.items():
        v = live.get(mint)
        if v and v.get("usd"):
            real_prices.append(v["usd"])
            price_sources[ri] = v["source"]
        else:
            real_prices.append(fallback[ri])
            price_sources[ri] = "fallback(parent-provided approx)"
    print("oracle prices:", oracle_prices)
    print("real prices  :", real_prices, price_sources)

    # load + parse all obligations
    raw = {}
    for f in sorted(os.listdir(os.path.join(HERE, "raw_batches"))):
        if not f.endswith(".json.gz"):
            continue
        with gzip.open(os.path.join(HERE, "raw_batches", f), "rt") as fh:
            raw.update(json.load(fh)["accounts"])
    keys = json.load(open(os.path.join(HERE, "obligations_keys.json")))["pubkeys"]
    assert all(k in raw for k in keys)

    full = {}
    agg = {
        "n_total": len(keys), "n_any_position": 0, "n_collateral_only": 0, "n_loans_only": 0,
        "n_both": 0, "n_unhealthy_oracle": 0, "n_unhealthy_real": 0,
        "total_loan_value_oracle": 0.0, "total_collateral_value_oracle": 0.0,
        "total_loan_value_real": 0.0, "total_collateral_value_real": 0.0,
        "loan_value_oracle_per_reserve": [0.0] * 4, "collateral_value_oracle_per_reserve": [0.0] * 4,
        "loan_value_real_per_reserve": [0.0] * 4, "collateral_value_real_per_reserve": [0.0] * 4,
        "n_loans_only_with_debt": 0,
        "dust_debt_oracle": {"<0.10": 0, "<1": 0, "<10": 0, "<100": 0, ">=100": 0},
        "dust_debt_real": {"<0.10": 0, "<1": 0, "<10": 0, "<100": 0, ">=100": 0},
    }
    unhealthy_oracle = []
    unhealthy_real = []
    real_profit_candidates = []

    for pk in keys:
        o = parse_obligation(base64.b64decode(raw[pk]["data_b64"]))
        rec = {"pubkey": pk, "owner": o["owner"], "market": o["market"],
               "collateral": o["collateral"], "loans": o["loans"],
               "cached_collateral_value": o["cached_collateral_value"],
               "cached_loan_value": o["cached_loan_value"],
               "cache_last_updated": o["cache_last_updated"], "cache_invalidated": o["cache_invalidated"]}
        cv_o = lv_o = cv_r = lv_r = 0.0
        coll_by_res = [0.0] * 4
        loans_by_res = [0.0] * 4
        coll_by_res_r = [0.0] * 4
        loans_by_res_r = [0.0] * 4
        for p in o["collateral"]:
            ri = p["reserve_index"]
            v = p["amount"] * drates[ri] * oracle_prices[ri]
            vr = p["amount"] * drates[ri] * real_prices[ri]
            coll_by_res[ri] += v; coll_by_res_r[ri] += vr
            cv_o += v; cv_r += vr
        for p in o["loans"]:
            ri = p["reserve_index"]
            v = p["amount"] * lrates[ri] * oracle_prices[ri]
            vr = p["amount"] * lrates[ri] * real_prices[ri]
            loans_by_res[ri] += v; loans_by_res_r[ri] += vr
            lv_o += v; lv_r += vr
        rec["collateral_value_oracle"] = cv_o
        rec["loan_value_oracle"] = lv_o
        rec["collateral_value_real"] = cv_r
        rec["loan_value_real"] = lv_r
        rec["collateral_value_oracle_per_reserve"] = coll_by_res
        rec["loan_value_oracle_per_reserve"] = loans_by_res
        rec["collateral_value_real_per_reserve"] = coll_by_res_r
        rec["loan_value_real_per_reserve"] = loans_by_res_r
        has_c = bool(o["collateral"]); has_l = bool(o["loans"])
        nz_c = any(p["amount"] > 0 for p in o["collateral"])
        nz_l = any(p["amount"] > 0 for p in o["loans"])
        if nz_c or nz_l:
            agg.setdefault("n_any_nonzero_position", 0)
            agg["n_any_nonzero_position"] += 1
        if nz_c and not nz_l:
            agg.setdefault("n_collateral_only_nonzero", 0)
            agg["n_collateral_only_nonzero"] += 1
        if nz_l and not nz_c:
            agg.setdefault("n_loans_only_nonzero", 0)
            agg["n_loans_only_nonzero"] += 1
        if has_c or has_l:
            agg["n_any_position"] += 1
        if has_c and not has_l:
            agg["n_collateral_only"] += 1
        if has_l and not has_c:
            agg["n_loans_only"] += 1
            if lv_o > 0:
                agg["n_loans_only_with_debt"] += 1
        if has_c and has_l:
            agg["n_both"] += 1
        agg["total_loan_value_oracle"] += lv_o
        agg["total_collateral_value_oracle"] += cv_o
        agg["total_loan_value_real"] += lv_r
        agg["total_collateral_value_real"] += cv_r
        for i in range(4):
            agg["loan_value_oracle_per_reserve"][i] += loans_by_res[i]
            agg["collateral_value_oracle_per_reserve"][i] += coll_by_res[i]
            agg["loan_value_real_per_reserve"][i] += loans_by_res_r[i]
            agg["collateral_value_real_per_reserve"][i] += coll_by_res_r[i]
        un_o = lv_o > 0 and cv_o < lv_o * MIN_CR
        un_r = lv_r > 0 and cv_r < lv_r * MIN_CR
        rec["unhealthy_oracle"] = un_o
        rec["unhealthy_real"] = un_r
        if lv_o > 0:
            d = lv_o
            b = "<0.10" if d < 0.10 else ("<1" if d < 1 else ("<10" if d < 10 else ("<100" if d < 100 else ">=100")))
            agg["dust_debt_oracle"][b] += 1
        if lv_r > 0:
            d = lv_r
            b = "<0.10" if d < 0.10 else ("<1" if d < 1 else ("<10" if d < 10 else ("<100" if d < 100 else ">=100")))
            agg["dust_debt_real"][b] += 1
        if un_o:
            agg["n_unhealthy_oracle"] += 1
            simple_bonus = max(0.0, min(cv_o - lv_o / MIN_CR, BONUS * lv_o))
            # exact per-pair profits (single-position pairs dominate; multi handled as sum over pairs, approx)
            pairs = []
            for lp in o["loans"]:
                ri_l = lp["reserve_index"]
                D_pair = loans_by_res[ri_l]
                for cp in o["collateral"]:
                    ri_c = cp["reserve_index"]
                    C_pair = coll_by_res[ri_c]
                    if D_pair <= 0 or C_pair <= 0:
                        continue
                    pr = exact_oracle_profit(D_pair, C_pair)
                    rp = real_pnl(D_pair, C_pair, real_prices[ri_l] / oracle_prices[ri_l],
                                  real_prices[ri_c] / oracle_prices[ri_c], (ri_l, ri_c))
                    pairs.append({"loan_reserve": ri_l, "collateral_reserve": ri_c,
                                  "profit_oracle_exact": pr["profit_oracle"],
                                  "real_pnl_full_math": rp,
                                  "liquidatable": pr["liquidatable"], "x": pr["x"]})
                    if rp > 0.01:
                        real_profit_candidates.append({"obligation": pk, "owner": o["owner"],
                                                       "loan_reserve": ri_l, "collateral_reserve": ri_c,
                                                       "debt_oracle": D_pair, "collateral_oracle": C_pair,
                                                       "real_pnl_est": rp})
            unhealthy_oracle.append({
                "pubkey": pk, "owner": o["owner"], "debt_usd_oracle": lv_o, "collateral_usd_oracle": cv_o,
                "debt_usd_real": lv_r, "collateral_usd_real": cv_r,
                "bonus_simple_oracle": simple_bonus,
                "pairs": pairs,
                "cache_last_updated": o["cache_last_updated"],
            })
        if un_r:
            agg["n_unhealthy_real"] += 1
            unhealthy_real.append({"pubkey": pk, "owner": o["owner"], "debt_usd_real": lv_r,
                                   "collateral_usd_real": cv_r, "debt_usd_oracle": lv_o, "collateral_usd_oracle": cv_o})
        full[pk] = rec

    agg["oracle_prices"] = oracle_prices
    agg["real_prices"] = real_prices
    agg["real_price_sources"] = price_sources
    agg["market_cache_ref_slot"] = ref_slot
    agg["min_collateral_ratio"] = MIN_CR
    agg["liquidation_bonus_bps"] = int(BONUS * 10000)
    agg["n_real_profit_candidates"] = len(real_profit_candidates)
    agg["real_profit_candidates_total_est_usd"] = sum(c["real_pnl_est"] for c in real_profit_candidates)
    agg["total_bonus_simple_oracle"] = sum(u["bonus_simple_oracle"] for u in unhealthy_oracle)
    agg["total_bonus_exact_oracle"] = sum(p["profit_oracle_exact"] for u in unhealthy_oracle for p in u["pairs"] if p["liquidatable"])

    json.dump({"slot_market": ref_slot, "count": len(full),
               "note": "amounts are note amounts; values recomputed with market-cache exchange rates/prices; cached_* are program-stored (mostly stale)",
               "obligations": full},
              open(os.path.join(HERE, "obligations_full.json"), "w"))
    json.dump({"aggregate": agg, "unhealthy_oracle": unhealthy_oracle,
               "unhealthy_real": unhealthy_real, "real_profit_candidates": real_profit_candidates},
              open(os.path.join(HERE, "obligations_summary.json"), "w"), indent=1)

    # readable md
    lines = []
    w = lines.append
    w("# Jet v1 obligation census")
    w("")
    w(f"- obligations fetched: **{agg['n_total']}** (all accounts with discriminator a8ce8d6a584caca7, fetched at ~slot 456073460-456075034)")
    w(f"- with any position entry: **{agg['n_any_position']}** (collateral-only {agg['n_collateral_only']}, loans-only {agg['n_loans_only']}, both {agg['n_both']})")
    w(f"- with any **nonzero** position: **{agg.get('n_any_nonzero_position', 0)}** (collateral-only {agg.get('n_collateral_only_nonzero', 0)}, loans-only(nonzero debt, no nonzero collateral) {agg.get('n_loans_only_nonzero', 0)}, both {agg.get('n_any_nonzero_position', 0) - agg.get('n_collateral_only_nonzero', 0) - agg.get('n_loans_only_nonzero', 0)})")
    w(f"- obligations with loan value > 0: {sum(1 for o in full.values() if o['loan_value_oracle'] > 0)}")
    w(f"- loans-only with nonzero debt: {agg['n_loans_only_with_debt']} (non-empty-list definition) / {agg.get('n_loans_only_nonzero', 0)} (nonzero-amount definition)")
    w(f"- market cache prices used: oracle={oracle_prices} (last updated slot {ref_slot})")
    w(f"- real prices used: USDC ${real_prices[0]:.4f}, SOL ${real_prices[1]:.4f}, solBTC ${real_prices[2]:.4f}, solETH ${real_prices[3]:.4f} (per {json.dumps(price_sources)})")
    w("")
    w("## Totals (USD oracle values / real values)")
    w("")
    w("| metric | oracle | real |")
    w("|---|---|---|")
    w(f"| total loan value | {agg['total_loan_value_oracle']:,.2f} | {agg['total_loan_value_real']:,.2f} |")
    w(f"| total collateral value | {agg['total_collateral_value_oracle']:,.2f} | {agg['total_collateral_value_real']:,.2f} |")
    w(f"| unhealthy obligations | {agg['n_unhealthy_oracle']} | {agg['n_unhealthy_real']} |")
    w("")
    w("### Debt per reserve (oracle / real USD)")
    w("")
    for i, name in enumerate(["USDC (0)", "SOL (1)", "solBTC (2)", "solETH (3)"]):
        w(f"- {name}: oracle {agg['loan_value_oracle_per_reserve'][i]:,.2f} / real {agg['loan_value_real_per_reserve'][i]:,.2f}")
    w("")
    w("### Collateral per reserve (oracle / real USD)")
    w("")
    for i, name in enumerate(["USDC (0)", "SOL (1)", "solBTC (2)", "solETH (3)"]):
        w(f"- {name}: oracle {agg['collateral_value_oracle_per_reserve'][i]:,.2f} / real {agg['collateral_value_real_per_reserve'][i]:,.2f}")
    w("")
    w("## Liquidator bonus (oracle terms)")
    w("")
    w(f"- simple metric sum (min(C - D/1.25, 0.03 D)): {agg['total_bonus_simple_oracle']:,.2f} USD")
    w(f"- exact per-source-formula sum: {agg['total_bonus_exact_oracle']:,.2f} USD")
    w("")
    w("## Real-terms liquidation candidates (positive real PnL under on-chain oracle math)")
    w("")
    w(f"- pairs: {agg['n_real_profit_candidates']}, estimated total: {agg['real_profit_candidates_total_est_usd']:,.2f} USD")
    for c in sorted(real_profit_candidates, key=lambda z: -z["real_pnl_est"])[:25]:
        w(f"  - {c['obligation'][:12]}… debt(loan r{c['loan_reserve']}) {c['debt_oracle']:,.2f} oracle / coll(r{c['collateral_reserve']}) {c['collateral_oracle']:,.2f} oracle -> est real PnL {c['real_pnl_est']:,.2f}")
    w("")
    w("## Dust distribution of debt")
    w("")
    w("| band | oracle-set | real-set |")
    w("|---|---|---|")
    for band in ["<0.10", "<1", "<10", "<100", ">=100"]:
        w(f"| {band} | {agg['dust_debt_oracle'][band]} | {agg['dust_debt_real'][band]} |")
    w("")
    w("## Oracle-unhealthy obligations >= $1 (full list below; rest are dust)")
    w("")
    w("| obligation | owner | debt (oracle) | collateral (oracle) | debt (real) | collateral (real) | exact oracle bonus | best real PnL |")
    w("|---|---|---|---|---|---|---|---|")
    for u in sorted(unhealthy_oracle, key=lambda z: -z["debt_usd_oracle"]):
        if u["debt_usd_oracle"] < 1:
            continue
        best_real = max([p["real_pnl_full_math"] for p in u["pairs"]] or [0.0])
        exact = sum(p["profit_oracle_exact"] for p in u["pairs"])
        w(f"| {u['pubkey'][:16]}... | {u['owner'][:12]}... | {u['debt_usd_oracle']:.2f} | {u['collateral_usd_oracle']:.2f} | {u['debt_usd_real']:.2f} | {u['collateral_usd_real']:.2f} | {exact:.2f} | {best_real:.2f} |")
    w("")
    w("## Real-unhealthy obligations (debt real > 1.25 x collateral real) - top 20 by real debt")
    w("")
    w("| obligation | owner | debt (real) | collateral (real) | debt (oracle) | collateral (oracle) |")
    w("|---|---|---|---|---|---|")
    for u in sorted(unhealthy_real, key=lambda z: -z["debt_usd_real"])[:20]:
        w(f"| {u['pubkey'][:16]}... | {u['owner'][:12]}... | {u['debt_usd_real']:.2f} | {u['collateral_usd_real']:.2f} | {u['debt_usd_oracle']:.2f} | {u['collateral_usd_oracle']:.2f} |")
    w("")
    w("Caveats: 'real' prices are thin-market DEX prices (Jupiter v3); solBTC/solETH exit liquidity is only a few $k, so real value is indicative. ")
    w("Oracle prices come from the on-chain market cache (last refresh slot 451021492, i.e. 2026-09-27), sourced from frozen Pyth legacy feeds.")
    open(os.path.join(HERE, "obligations_summary.md"), "w").write("\n".join(lines) + "\n")
    print(json.dumps(agg, indent=1))


if __name__ == "__main__":
    main()

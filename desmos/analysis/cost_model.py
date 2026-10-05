#!/usr/bin/env python3
"""
C2-10 Desmos — governance-capture cost model + CP realizable-value model.

Inputs : a directory of raw JSON evidence (fetched by ci/run.sh or locally).
Outputs: COST-MODEL.md + cost-model.json in the output directory.

All numbers are derived from on-chain state; USD prices come from the same
snapshot (pool-implied prices are primary, CoinGecko/DefiLlama secondary).
Read-only analysis; no transactions.
"""
import json, os, sys

FEE = 0.002  # fallback swap fee

DSM_DENOM = "ibc/EA4C0A9F72E2CEDF10D0E7A9A6A22954DB3444910DB5BE980DF59B05A46DAD1C"
ATOM_DENOM = "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2"
USDC_DENOM = "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4"

def load(d, name, default=None):
    p = os.path.join(d, name)
    if not os.path.exists(p):
        return default
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return default

def fnum(x, default=0.0):
    try:
        return float(x)
    except Exception:
        return default

def asset_tuple(a):
    """Normalize gamm pool_assets ({token:{denom,amount}}) and pool_liquidity ({denom,amount})."""
    tok = a.get("token") or {}
    denom = a.get("denom") or tok.get("denom")
    amount = a.get("amount") if a.get("amount") is not None else tok.get("amount")
    return denom, fnum(amount)

def main():
    raw = sys.argv[1] if len(sys.argv) > 1 else "ci-out/raw"
    out = sys.argv[2] if len(sys.argv) > 2 else "ci-out"
    os.makedirs(out, exist_ok=True)

    gov = load(raw, "gov-params.json", {}) or {}
    pool = load(raw, "staking-pool.json", {}) or {}
    cp = load(raw, "community-pool.json", {}) or {}
    supply = load(raw, "supply.json", {}) or {}
    prices = load(raw, "prices.json", {}) or {}
    pools = load(raw, "osmosis-pools.json", []) or []
    dsm_supply_osmo = load(raw, "osmosis-dsm-supply.json", {}) or {}
    escrows = load(raw, "escrows.json", {}) or {}
    height = load(raw, "height.json", {}) or {}
    client = load(raw, "ibc-client.json", {}) or {}
    wasm_codes = load(raw, "wasm-codes.json", {}) or {}
    wasm_params = load(raw, "wasm-params.json", {}) or {}
    endpoints = load(raw, "endpoint-survey.json", []) or []
    wasm_contract_balances = load(raw, "contract-balances.json", {}) or {}
    valraw = load(raw, "validators.json", {}) or {}

    def udsm(balances):
        for b in balances or []:
            if b.get("denom") == "udsm":
                return fnum(b.get("amount")) / 1e6
        return 0.0

    bonded = fnum(pool.get("bonded_tokens")) / 1e6
    not_bonded = fnum(pool.get("not_bonded_tokens")) / 1e6
    cp_dsm = udsm(cp.get("pool")) if isinstance(cp, dict) else 0.0
    total_supply = 0.0
    for b in (supply.get("supply") or []):
        if b.get("denom") == "udsm":
            total_supply = fnum(b.get("amount")) / 1e6

    quorum = fnum(gov.get("quorum"), 0.334)
    threshold = fnum(gov.get("threshold"), 0.5)
    veto = fnum(gov.get("veto_threshold"), 0.334)
    min_deposit = udsm(gov.get("min_deposit"))
    voting_period = gov.get("voting_period", "?")
    max_deposit = gov.get("max_deposit_period", "?")

    atom_usd = fnum(prices.get("atom_usd"))
    osmo_usd = fnum(prices.get("osmo_usd"))
    dsm_usd_cg = fnum(prices.get("dsm_usd_coingecko"))

    # ---------- DSM pools ----------
    implied = []
    dsm_pools = []
    for p in pools:
        assets = [asset_tuple(a) for a in (p.get("assets") or [])]
        dsm = next((a for a in assets if a[0] == DSM_DENOM), None)
        if not dsm or dsm[1] <= 0:
            continue
        dsm_amt = dsm[1] / 1e6
        counter = [a for a in assets if a[0] != DSM_DENOM]
        c_usd, cname, c_amt = 0.0, "none", 0.0
        if counter:
            c_denom, c_amt = counter[0]
            if c_denom == "uosmo":
                c_usd, cname = c_amt / 1e6 * osmo_usd, "OSMO"
            elif c_denom == ATOM_DENOM:
                c_usd, cname = c_amt / 1e6 * atom_usd, "ATOM"
            elif c_denom == USDC_DENOM:
                c_usd, cname = c_amt / 1e6 * 1.0, "USDC"
            else:
                cname = (c_denom or "?")[:24] + "…"
        implied_price = c_usd / dsm_amt if (dsm_amt and c_usd > 0) else 0.0
        if implied_price > 0:
            implied.append(implied_price)
        dsm_pools.append({
            "id": p.get("id"), "type": p.get("type", "weighted"),
            "dsm": dsm_amt, "counter": c_amt / 1e6, "counter_name": cname,
            "counter_usd": c_usd, "implied_dsm_usd": implied_price,
            "swap_fee": fnum(p.get("swap_fee"), FEE) if p.get("swap_fee") is not None else FEE,
        })
    dsm_usd = dsm_usd_cg or (sum(implied) / len(implied) if implied else 0.0)

    # ---------- CP realizable via AMM dump (weighted pools only; CL valued separately) ----------
    cp_realizable = 0.0
    for p in dsm_pools:
        if p["type"] == "concentrated":
            continue
        D, C, f = p["dsm"], p["counter_usd"], p["swap_fee"]
        x_eff = cp_dsm * (1 - f)
        cp_realizable += C * x_eff / (D + x_eff) if (D + x_eff) > 0 else 0.0
    cl_counter_usd = sum(p["counter_usd"] for p in dsm_pools if p["type"] == "concentrated")

    # ---------- On-market accumulation ----------
    quorum_dsm = quorum * bonded
    dsm_pool_total = sum(p["dsm"] for p in dsm_pools)
    weighted = [p for p in dsm_pools if p["type"] != "concentrated"]
    dsm_weighted_total = sum(p["dsm"] for p in weighted)
    counter_total_usd = sum(p["counter_usd"] for p in dsm_pools)
    on_market_cost_quorum = None
    if quorum_dsm < dsm_weighted_total:
        cost = 0.0
        for p in weighted:
            D, C = p["dsm"], p["counter_usd"]
            x = quorum_dsm * (D / dsm_weighted_total)
            if x < D:
                cost += C * x / (D - x)
        on_market_cost_quorum = cost
    otc_cost_quorum = quorum_dsm * dsm_usd

    # ---------- validators ----------
    val_list = valraw.get("validators", []) if isinstance(valraw, dict) else []
    votes = sorted([fnum(v.get("tokens")) / 1e6 for v in val_list], reverse=True)
    top4_dsm = sum(votes[:4])
    outvote_dsm = top4_dsm
    outvote_cost_otc = outvote_dsm * dsm_usd
    # to avoid veto from top-4 NoWithVeto: A/(A+top4) <= veto  =>  A <= top4*(1-veto)/veto ; need A > that
    veto_avoid_dsm = top4_dsm * (1 - veto) / veto

    # ---------- net P&L ----------
    total_dump = quorum_dsm + cp_dsm
    dump_all = 0.0
    for p in weighted:
        D, C, f = p["dsm"], p["counter_usd"], p["swap_fee"]
        x_eff = total_dump * (1 - f)
        dump_all += C * x_eff / (D + x_eff) if (D + x_eff) > 0 else 0.0
    net_otc_spot = dump_all - otc_cost_quorum
    breakeven_price = dump_all / quorum_dsm if quorum_dsm else 0.0
    breakeven_vs_market = (breakeven_price / dsm_usd) if dsm_usd else 0.0

    # ---------- wasm / DoS ----------
    codes = (wasm_codes.get("codeInfos") or wasm_codes.get("code_infos") or []) if isinstance(wasm_codes, dict) else []
    n_codes = len(codes)
    wasm_native_total = 0.0
    n_contracts = 0
    if isinstance(wasm_contract_balances, dict):
        for c, bals in (wasm_contract_balances.get("contracts") or {}).items():
            n_contracts += 1
            wasm_native_total += udsm(bals)

    escrow_total = 0.0
    for ch, info in (escrows or {}).items():
        if isinstance(info, dict):
            escrow_total += udsm(info.get("balances"))

    result = {
        "finding": "C2-10",
        "chain": "desmos-mainnet",
        "height": height.get("height"),
        "block_time": height.get("time"),
        "gov_params": {
            "quorum": quorum, "threshold": threshold, "veto_threshold": veto,
            "min_deposit_dsm": min_deposit, "voting_period": voting_period,
            "max_deposit_period": max_deposit,
        },
        "staking": {"bonded_dsm": bonded, "not_bonded_dsm": not_bonded,
                    "bonded_usd": bonded * dsm_usd, "top4_dsm": top4_dsm,
                    "top4_share": (top4_dsm / bonded) if bonded else None},
        "community_pool": {"dsm": cp_dsm, "usd_nominal": cp_dsm * dsm_usd},
        "supply_dsm": total_supply,
        "dsm_price_usd": dsm_usd,
        "dsm_price_sources": {"coingecko": dsm_usd_cg, "pool_implied": implied},
        "osmosis": {
            "dsm_ibc_supply_dsm": fnum((dsm_supply_osmo.get("amount") or {}).get("amount")) / 1e6,
            "pools": dsm_pools,
            "pool_dsm_total": dsm_pool_total,
            "pool_counter_total_usd": counter_total_usd,
            "cl_counter_total_usd": cl_counter_usd,
        },
        "capture": {
            "quorum_dsm": quorum_dsm,
            "quorum_cost_onmarket_usd": on_market_cost_quorum,
            "quorum_cost_otc_spot_usd": otc_cost_quorum,
            "onmarket_infeasible": quorum_dsm > dsm_weighted_total,
            "outvote_top4_dsm": outvote_dsm,
            "outvote_top4_cost_otc_spot_usd": outvote_cost_otc,
            "avoid_veto_needs_dsm": veto_avoid_dsm,
            "avoid_veto_cost_otc_spot_usd": veto_avoid_dsm * dsm_usd,
            "cp_realizable_dump_usd": cp_realizable,
            "attacker_bag_dump_usd": dump_all,
            "net_if_otc_at_spot_usd": net_otc_spot,
            "breakeven_otc_price_usd": breakeven_price,
            "breakeven_vs_market_x": breakeven_vs_market,
        },
        "wasm": {
            "params": wasm_params,
            "n_codes": n_codes,
            "n_contracts": n_contracts,
            "native_dsm_in_contracts": wasm_native_total,
        },
        "ibc": {"client": client, "escrow_total_dsm": escrow_total},
        "endpoint_versions": endpoints,
    }

    with open(os.path.join(out, "cost-model.json"), "w") as f:
        json.dump(result, f, indent=2)

    def fmt(x, nd=2):
        return f"{x:,.{nd}f}" if isinstance(x, (int, float)) else str(x)

    L = []
    A = L.append
    A("# C2-10 Desmos — capture cost model (live snapshot)\n")
    A(f"- Height: **{height.get('height')}** at {height.get('time')}")
    A(f"- DSM price: **${fmt(dsm_usd, 6)}** (sources: CG {dsm_usd_cg}, pool-implied {[round(x,6) for x in implied]})")
    A(f"- Bonded: **{fmt(bonded)} DSM** (${fmt(bonded*dsm_usd)}) — top-4 validators {fmt(top4_dsm)} DSM ({fmt(100*top4_dsm/bonded if bonded else 0)}%)")
    A(f"- Community pool: **{fmt(cp_dsm)} DSM** nominal ${fmt(cp_dsm*dsm_usd)}")
    A(f"- Gov: quorum {quorum}, threshold {threshold}, veto {veto}, min deposit {fmt(min_deposit)} DSM, voting {voting_period}\n")
    A("## Market depth (Osmosis)\n")
    A("| pool | type | DSM | counter | counter USD | implied DSM USD | fee |")
    A("|---|---|---|---|---|---|---|")
    for p in dsm_pools:
        A(f"| {p['id']} | {p['type']} | {fmt(p['dsm'],3)} | {fmt(p['counter'],3)} {p['counter_name']} | {fmt(p['counter_usd'])} | ${fmt(p['implied_dsm_usd'],6)} | {p['swap_fee']} |")
    A(f"\n- Total DSM in pools: **{fmt(dsm_pool_total,3)} DSM**; counter value **${fmt(counter_total_usd)}** (CL part ${fmt(cl_counter_usd)})")
    A(f"- DSM IBC supply on Osmosis: {fmt(fnum((dsm_supply_osmo.get('amount') or {}).get('amount'))/1e6,3)} DSM")
    A("\n## Capture cost\n")
    A(f"- Quorum votes needed: **{fmt(quorum_dsm,3)} DSM** ({quorum:.1%} of bonded)")
    if on_market_cost_quorum is not None:
        A(f"- On-market buy of quorum: ${fmt(on_market_cost_quorum)}")
    else:
        A(f"- On-market buy of quorum: **INFEASIBLE** — weighted pools hold only {fmt(dsm_weighted_total,3)} DSM (< {fmt(quorum_dsm,3)} needed)")
    A(f"- OTC at spot (lower bound): **${fmt(otc_cost_quorum)}** for quorum; **${fmt(outvote_cost_otc)}** to outvote top-4; **${fmt(veto_avoid_dsm*dsm_usd)}** to avoid a top-4 veto ({fmt(veto_avoid_dsm,0)} DSM)")
    A(f"- CP immediately realizable by dumping {fmt(cp_dsm,3)} DSM into weighted pools: **${fmt(cp_realizable)}**")
    A(f"- Attacker total bag dumped (quorum+CP = {fmt(total_dump,3)} DSM): **${fmt(dump_all)}**")
    A(f"- Net if OTC bought at spot: **${fmt(net_otc_spot)}** (loss)")
    A(f"- Break-even OTC price: **${fmt(breakeven_price,6)}/DSM** = {fmt(breakeven_vs_market,3)}x market price")
    A("\n## DoS / wasm\n")
    A(f"- wasm codes: {n_codes}; contracts: {n_contracts}; native DSM held by contracts: {fmt(wasm_native_total,3)}")
    A(f"- wasm params: {json.dumps(wasm_params)}")
    A(f"- IBC escrow (all transfer channels): {fmt(escrow_total,3)} DSM")
    A("\n## Endpoint versions\n")
    A("| endpoint | app | wasmvm | ibc-go | wasmd |")
    A("|---|---|---|---|---|")
    for e in endpoints:
        A(f"| {e.get('endpoint')} | {e.get('app_version')} | {e.get('wasmvm')} | {e.get('ibc_go')} | {e.get('wasmd')} |")

    with open(os.path.join(out, "COST-MODEL.md"), "w") as f:
        f.write("\n".join(L) + "\n")

    print("\n".join(L))

if __name__ == "__main__":
    main()

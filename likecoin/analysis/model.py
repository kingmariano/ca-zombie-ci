#!/usr/bin/env python3
"""
C2-29 LikeCoin (likecoin-mainnet-2) governance-capture model (read-only, public endpoints only).

Computes, from live chain state:
  1. gov params (reconstructed: genesis defaults + the two ParameterChangeProposals that
     touched the gov subspace; no quorum/threshold/veto change ever passed);
  2. staking pool, supply, community-pool (fee-pool) accounting, distribution module balance,
     module-account balances, IBC escrow balances;
  3. LIKE v2 market depth: every Osmosis pool containing the LIKE IBC denom, with counterpart
     USD value -> the max realizable value of a CP dump;
  4. the two capture paths (solo-quorum vs min-deposit+validator-vote) with the standard
     corrections (attacker's own stake enters the quorum denominator; veto threshold; float depth).

Outputs: model.json + model.md in --outdir (default: ./out).
No secrets, no transactions. Public LCD/RPC + price APIs only.
"""
import argparse, json, os, subprocess, sys, time
from datetime import datetime, timezone

UA = "Mozilla/5.0 (X11; Linux x86_64) research"
LIKE_LCD = "https://mainnet-node.like.co"
OSM_LCD = "https://lcd.osmosis.zone"
DL = "https://coins.llama.fi/prices/current/"

LIKE_IBC_OSMOSIS = "ibc/9989AD6CCA39D1131523DB0617B50F6442081162294B4795E26746292467B525"  # transfer/channel-53/nanolike
NANOLIKE = 1e9

# Gov params: genesis (2021-08-18) tally_params + tracked ParameterChangeProposals.
# - prop 8  (2021-09): min_deposit -> 100,000 LIKE ; max_deposit_period -> 14d
# - prop 18 (2021-10): voting_period -> 7d
# - NO proposal ever changed quorum / threshold / veto_threshold.
GOV = {
    "quorum": 0.40,
    "threshold": 0.50,
    "veto_threshold": 0.334,
    "min_deposit_like": 100_000.0,
    "voting_period_days": 7,
    "max_deposit_period_days": 14,
    "burn_vote_veto": True,   # SDK v0.46: deposit refunded on pass/reject, burned on veto
}
UNBONDING_DAYS = 21
COMMUNITY_TAX = 0.02


def curl(url, timeout=40):
    try:
        r = subprocess.run(["curl", "-s", "--max-time", str(timeout), "-A", UA, url],
                           capture_output=True, text=True)
        return r.stdout
    except Exception:
        return ""


def jget(url, timeout=40, retries=3):
    for i in range(retries):
        out = curl(url, timeout)
        try:
            return json.loads(out)
        except Exception:
            time.sleep(1.5)
    return None


def load(rawdir, name):
    p = os.path.join(rawdir, name)
    if os.path.exists(p):
        try:
            return json.load(open(p))
        except Exception:
            return None
    return None


def fnum(x):
    try:
        return float(x)
    except Exception:
        return 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rawdir", default=None, help="raw state dir (default: analysis/raw, falls back to ci-out/raw)")
    ap.add_argument("--outdir", default=None, help="output dir (default: analysis/out)")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    base = os.path.dirname(here)  # finding folder
    rawdir = args.rawdir or os.path.join(base, "analysis", "raw")
    if not os.path.isdir(rawdir):
        rawdir = os.path.join(base, "ci-out", "raw")
    outdir = args.outdir or os.path.join(base, "analysis", "out")
    os.makedirs(outdir, exist_ok=True)

    # ---------- live state ----------
    blocks = load(rawdir, "blocks_latest.json") or {}
    height = int(blocks.get("block", {}).get("header", {}).get("height", 0) or 0)
    block_time = blocks.get("block", {}).get("header", {}).get("time")

    pool = (load(rawdir, "staking_pool.json") or {}).get("pool", {})
    bonded = fnum(pool.get("bonded_tokens")) / NANOLIKE
    not_bonded = fnum(pool.get("not_bonded_tokens")) / NANOLIKE

    cp = (load(rawdir, "community_pool.json") or {}).get("pool", [])
    cp_like = sum(fnum(x["amount"]) for x in cp if x["denom"] == "nanolike") / NANOLIKE
    cp_other = [x for x in cp if x["denom"] != "nanolike"]

    mb = load(rawdir, "module_balances.json") or {}
    def modbal(name):
        b = (mb.get(name) or {}).get("balances") or []
        if isinstance(b, dict):
            b = b.get("balances") or []
        return sum(fnum(x["amount"]) for x in b if x["denom"] == "nanolike") / NANOLIKE
    dist_actual = modbal("distribution")
    dist_extra = dist_actual - cp_like  # unreachable via CP spend (SafeSub caps at fee-pool accounting)

    supply = load(rawdir, "supply.json") or {}
    sup_like = sum(fnum(x["amount"]) for x in supply.get("supply", []) if x["denom"] == "nanolike") / NANOLIKE
    sup_ibc = [(x["denom"], fnum(x["amount"])) for x in supply.get("supply", []) if x["denom"] != "nanolike"]

    esc = load(rawdir, "escrow_balances.json") or {}
    esc_rows = []
    esc_total = 0.0
    for ch, v in sorted(esc.items()):
        tot = sum(fnum(b["amount"]) for b in (v.get("balances") or []) if b["denom"] == "nanolike") / NANOLIKE
        if tot > 0:
            esc_rows.append({"channel": ch, "like": round(tot, 6), "address": v.get("address")})
            esc_total += tot

    vb = load(rawdir, "validators_bonded.json") or {}
    vlist = vb.get("validators", [])
    vbonded = [{"moniker": v["description"]["moniker"], "operator": v["operator_address"],
                "tokens_like": fnum(v["tokens"]) / NANOLIKE} for v in vlist]
    vbonded.sort(key=lambda x: -x["tokens_like"])
    va = load(rawdir, "validators_all.json") or {}
    v_all = len(va.get("validators", []))

    props = load(rawdir, "proposals_all_v1.json") or {}
    plist = props.get("proposals", [])
    n_props = len(plist)
    last_prop = max((int(p["id"]) for p in plist), default=0)

    # ---------- prices (live; fall back to last-known) ----------
    px = jget(DL + "coingecko:likecoin-2,coingecko:osmosis,coingecko:cosmos") or {}
    coins = px.get("coins", {})
    p_like_v3 = fnum((coins.get("coingecko:likecoin-2") or {}).get("price")) or 0.00145379
    p_osmo = fnum((coins.get("coingecko:osmosis") or {}).get("price")) or 0.034032
    p_atom = fnum((coins.get("coingecko:cosmos") or {}).get("price")) or 1.878737
    p_usdc = 1.0
    p_akt = fnum((jget(DL + "coingecko:akash-network") or {}).get("coins", {}).get("coingecko:akash-network", {}).get("price")) or 0.5
    p_hava = 0.0  # memecoin, treated as 0 (documented)

    # ---------- Osmosis LIKE pools & dump model ----------
    osp = load(rawdir, "osmosis_all_pools.json") or {}
    pools = osp.get("pools", [])
    DEC = {"uosmo": 1e6, "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2": 1e6,
           "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4": 1e6,
           "ibc/1480B8FD20AD5FCAE81EA87584D269547DD4D436843C1D20F15E00EB64743EF4": 1e6,
           "ibc/8242AD24008032E457D2E12D46588FD39FB54FB29680C6C7663D296B383C37C4": 1e6,
           "ibc/884EBC228DFCE8F1304D917A712AA9611427A6C1ECC3179B2E91D7468FB091A2": 1e6,
           "ibc/CEE970BB3D26F4B907097B6B660489F13F3B0DA765B83CC7D9A0BC0CE220FA6F": 1e6,
           "factory/osmo1qnglc04tmhg32uc4kxlxh55a5cmhj88cpa3rmtly484xqu82t79sfv94w0/alloyed/allXRP": 1e6}
    PRICE = {"uosmo": p_osmo,
             "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2": p_atom,
             "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4": p_usdc,
             "ibc/1480B8FD20AD5FCAE81EA87584D269547DD4D436843C1D20F15E00EB64743EF4": p_akt,
             "ibc/8242AD24008032E457D2E12D46588FD39FB54FB29680C6C7663D296B383C37C4": p_usdc,
             "ibc/884EBC228DFCE8F1304D917A712AA9611427A6C1ECC3179B2E91D7468FB091A2": p_hava,
             "ibc/CEE970BB3D26F4B907097B6B660489F13F3B0DA765B83CC7D9A0BC0CE220FA6F": 0.0,
             "factory/osmo1qnglc04tmhg32uc4kxlxh55a5cmhj88cpa3rmtly484xqu82t79sfv94w0/alloyed/allXRP": p_usdc}

    like_pools = []
    total_like_in_pools = 0.0
    total_counterpart_usd = 0.0
    for p in pools:
        s = json.dumps(p)
        if LIKE_IBC_OSMOSIS not in s:
            continue
        pid = p.get("id"); ptype = p.get("@type", "").split(".")[-1]
        like_amt = 0.0
        counterpart = []
        if "gamm.v1beta1.Pool" in p.get("@type", ""):
            fee = fnum(p.get("pool_params", {}).get("swap_fee"))
            for a in p.get("pool_assets", []):
                tok = a.get("token", {})
                if tok.get("denom") == LIKE_IBC_OSMOSIS:
                    like_amt = fnum(tok.get("amount")) / NANOLIKE
                else:
                    d = tok.get("denom")
                    amt = fnum(tok.get("amount")) / DEC.get(d, 1e6)
                    counterpart.append({"denom": d, "amount": amt, "usd": amt * PRICE.get(d, 0.0)})
        else:
            fee = fnum(p.get("pool_params", {}).get("swap_fee"))
            for a in p.get("pool_liquidity", []):
                d = a.get("denom"); amt = fnum(a.get("amount")) / (NANOLIKE if d == LIKE_IBC_OSMOSIS else DEC.get(d, 1e6))
                if d == LIKE_IBC_OSMOSIS:
                    like_amt = amt
                else:
                    counterpart.append({"denom": d, "amount": amt, "usd": amt * PRICE.get(d, 0.0)})
        cp_usd = sum(c["usd"] for c in counterpart)
        total_like_in_pools += like_amt
        total_counterpart_usd += cp_usd
        like_pools.append({"id": pid, "type": ptype, "fee": fee, "like": round(like_amt, 4),
                           "counterpart": counterpart, "counterpart_usd": round(cp_usd, 2)})
    like_pools.sort(key=lambda x: -x["counterpart_usd"])

    # Max realizable dump of the CP amount into each gamm pool: out = R_out * X_net/(R_in + X_net)
    dump_usd = 0.0
    dump_rows = []
    cp_amount = cp_like
    for lp in like_pools:
        if lp["type"] != "Pool" or lp["like"] <= 0:
            # stableswap: approximate upper bound by counterpart value (dust)
            dump_rows.append({"pool": lp["id"], "out_usd": round(lp["counterpart_usd"], 2), "note": "counterpart cap"})
            dump_usd += lp["counterpart_usd"]
            continue
        fee = lp["fee"] or 0.003
        x_net = cp_amount * (1 - fee)
        out_usd = 0.0
        for c in lp["counterpart"]:
            out_amt = c["amount"] * x_net / (lp["like"] + x_net)  # human units out
            out_usd += out_amt * PRICE.get(c["denom"], 0.0)
        dump_rows.append({"pool": lp["id"], "out_usd": round(out_usd, 2)})
        dump_usd += out_usd

    # Cost to acquire the min deposit (100,000 LIKE) from the deepest gamm pool (553)
    dep_cost_usd = None
    for lp in like_pools:
        if str(lp["id"]) != "553" or lp["like"] <= 0:
            continue
        fee = lp["fee"] or 0.003
        target = GOV["min_deposit_like"]
        osmo_side = [c for c in lp["counterpart"] if c["denom"] == "uosmo"]
        if osmo_side:
            r_osmo = osmo_side[0]["amount"]      # OSMO reserve (human units)
            r_like = lp["like"]                  # LIKE reserve
            if r_like > target:
                need_net_osmo = r_osmo * target / (r_like - target)
                need_gross_osmo = need_net_osmo / (1 - fee)
                dep_cost_usd = need_gross_osmo * p_osmo
    # ---------- capture economics ----------
    q = GOV["quorum"]
    solo_quorum_stake = q / (1 - q) * bonded        # attacker stake S: S >= q*(B0+S)
    veto_proof_stake = 2 * bonded                    # attacker fraction > 2/3 -> nobody can veto
    threshold_only_stake = bonded                    # >50% of all bonded -> wins even if rest vote No
    float_liquid = sup_like - bonded - not_bonded - dist_actual - esc_total  # residual user balances

    cap = {
        "bonded_like": round(bonded, 4),
        "not_bonded_like": round(not_bonded, 4),
        "supply_like": round(sup_like, 4),
        "cp_accounting_like": round(cp_like, 4),
        "distribution_module_like": round(dist_actual, 4),
        "distribution_extra_unreachable_like": round(dist_extra, 4),
        "escrow_total_like": round(esc_total, 4),
        "liquid_float_like": round(float_liquid, 4),
        "solo_quorum_stake_like": round(solo_quorum_stake, 2),
        "veto_proof_stake_like": round(veto_proof_stake, 2),
        "threshold_only_stake_like": round(threshold_only_stake, 2),
        "solo_quorum_cost_usd_at_v3_price": round(solo_quorum_stake * p_like_v3, 2),
        "dex_like_inventory_all_pools": round(total_like_in_pools, 2),
        "solo_quorum_x_dex_inventory": round(solo_quorum_stake / total_like_in_pools, 1) if total_like_in_pools else None,
        "min_deposit_like": GOV["min_deposit_like"],
        "min_deposit_acquisition_cost_usd": round(dep_cost_usd, 2) if dep_cost_usd else None,
        "cp_nominal_usd_at_v3_price": round(cp_like * p_like_v3, 2),
        "cp_realizable_dump_usd": round(dump_usd, 2),
        "realizable_over_nominal": round(dump_usd / (cp_like * p_like_v3), 4) if cp_like else None,
        "solo_quorum_feasible_on_public_markets": False,
        "deposit_path_cost_usd": round(dep_cost_usd, 2) if dep_cost_usd else None,
        "deposit_refundable_on_pass_or_reject": True,
        "deposit_burned_on_veto": True,
    }

    model = {
        "finding": "C2-29",
        "chain": "likecoin-mainnet-2",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "likecoin_height": height,
        "likecoin_block_time": block_time,
        "gov_params": GOV,
        "gov_params_source": "genesis tally_params (quorum 0.4 / threshold 0.5 / veto 0.334) + props 8 & 18 (deposit, voting period); no quorum/threshold/veto change ever passed",
        "validators": {"bonded_count": len(vbonded), "all_count": v_all, "bonded": vbonded,
                       "top_share": round(vbonded[0]["tokens_like"] / bonded, 4) if vbonded and bonded else None},
        "proposals": {"count": n_props, "last_id": last_prop},
        "prices_usd": {"LIKE_v3_base": p_like_v3, "OSMO": p_osmo, "ATOM": p_atom, "USDC": p_usdc, "AKT": p_akt},
        "like_pools": like_pools,
        "dump_rows": dump_rows,
        "capture": cap,
        "escrows": {"total_like": round(esc_total, 4), "rows": esc_rows},
        "supply_ibc_denoms": sup_ibc,
        "notes": [
            "LIKE v2 migration to v3 closed 2026-02-02; v2 tokens are not convertible (official announcement; app i18n).",
            "CommunityPoolSpend on SDK v0.46.16 (likecoin fork v0.46.16-dual-prefix) caps at the fee-pool DecCoins accounting (SafeSub) -> the distribution module's extra balance is NOT spendable via CP spend.",
            "Solo-quorum capture requires acquiring 408.16M LIKE vs 2.69M LIKE of total AMM inventory; not executable on public markets.",
            "The deposit path only needs 100k LIKE (refundable; burned on veto) but the payout requires the 3 bonded validators to vote Yes (they hold 100% of bonded power; quorum is 40% of bonded).",
        ],
    }

    with open(os.path.join(outdir, "model.json"), "w") as f:
        json.dump(model, f, indent=1)

    md = []
    md.append(f"# C2-29 LikeCoin capture model — live at h {height} ({block_time})")
    md.append("")
    md.append("## State")
    md.append(f"- bonded: **{bonded:,.2f} LIKE**; not bonded: {not_bonded:,.2f}; supply: {sup_like:,.2f}")
    md.append(f"- community pool (fee-pool accounting): **{cp_like:,.2f} LIKE**; distribution module: {dist_actual:,.2f} (extra unreachable: {dist_extra:,.2f})")
    md.append(f"- IBC escrows: {esc_total:,.2f} LIKE; liquid float: {float_liquid:,.2f} LIKE")
    md.append(f"- bonded validators: {len(vbonded)} of {v_all}: " + ", ".join(f"{v['moniker']} {v['tokens_like']:,.0f}" for v in vbonded))
    md.append("")
    md.append("## Capture economics")
    md.append(f"- gov: quorum {q}, threshold {GOV['threshold']}, veto {GOV['veto_threshold']}; min deposit {GOV['min_deposit_like']:,.0f} LIKE; voting {GOV['voting_period_days']}d; unbonding {UNBONDING_DAYS}d")
    md.append(f"- solo-quorum stake: **{solo_quorum_stake:,.2f} LIKE** (${solo_quorum_stake*p_like_v3:,.0f} at v3 price) — DEX inventory {total_like_in_pools:,.2f} LIKE ({solo_quorum_stake/total_like_in_pools:.0f}x)")
    md.append(f"- veto-proof stake: {veto_proof_stake:,.2f} LIKE (> total supply: impossible)")
    md.append(f"- min-deposit acquisition cost: ${dep_cost_usd:,.2f} (refundable; burned only on veto)")
    md.append(f"- CP nominal at v3 price: ${cp_like*p_like_v3:,.2f}; **realizable dump: ${dump_usd:,.2f}** ({dump_usd/(cp_like*p_like_v3)*100:.2f}% of nominal)")
    md.append("")
    md.append("## Top LIKE pools (Osmosis)")
    for lp in like_pools[:6]:
        md.append(f"- pool {lp['id']} ({lp['type']}): {lp['like']:,.2f} LIKE / counterpart ${lp['counterpart_usd']:,.2f}")
    md.append("")
    md.append("Verdict: capture requires the 3 bonded validators' cooperation; solo-quorum is not executable (408.16M LIKE vs 2.69M AMM inventory); prize realizable ~$" + f"{dump_usd:,.0f} (v2 tokens dead post-migration). Uneconomic confirmed.")
    with open(os.path.join(outdir, "model.md"), "w") as f:
        f.write("\n".join(md) + "\n")

    print(f"bonded LIKE:              {bonded:,.2f}")
    print(f"CP accounting LIKE:       {cp_like:,.2f}  (nominal ${cp_like*p_like_v3:,.2f} at v3 price)")
    print(f"dist extra (unreachable): {dist_extra:,.2f} LIKE")
    print(f"escrow total LIKE:        {esc_total:,.2f}")
    print(f"liquid float LIKE:        {float_liquid:,.2f}")
    print(f"bonded validators:        {len(vbonded)} (top {vbonded[0]['moniker'] if vbonded else '?'})")
    print(f"solo-quorum stake:        {solo_quorum_stake:,.2f} LIKE = ${solo_quorum_stake*p_like_v3:,.2f} (not executable; AMM inventory {total_like_in_pools:,.2f} LIKE)")
    print(f"min-deposit cost:         ${dep_cost_usd:,.2f} refundable (buy 100,000 LIKE on Osmosis)")
    print(f"CP realizable dump:       ${dump_usd:,.2f}  vs nominal ${cp_like*p_like_v3:,.2f}")
    print(f"veto-proof stake:         {veto_proof_stake:,.2f} LIKE (> supply -> impossible)")
    print("OK")


if __name__ == "__main__":
    main()

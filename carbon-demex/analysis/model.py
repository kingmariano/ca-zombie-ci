#!/usr/bin/env python3
"""
C2-32 Carbon / Demex — governance-capture economics model (read-only).

Inputs: a frozen-state snapshot (inputs.json). Default resolution order:
  1) --inputs <file>
  2) ci-out/raw/inputs.json          (written by ci/evidence.py on the runner)
  3) analysis/inputs_snapshot.json   (curated snapshot, 2026-10-09)

Outputs: <outdir>/model.json + <outdir>/model.md

No network access here; all raw values are pulled by ci/evidence.py.
"""
import argparse, json, os, sys, datetime

Q = 0.334            # quorum (staking-explorer /parameters/carbon)
THRESH = 0.50        # threshold
VETO = 0.334         # veto threshold
UNBOND_DAYS = 30

def load_inputs(path=None):
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    cands = []
    if path:
        cands.append(path)
    cands += [
        os.path.join(root, "ci-out", "raw", "inputs.json"),
        os.path.join(here, "inputs_snapshot.json"),
    ]
    for c in cands:
        if os.path.exists(c):
            with open(c) as f:
                return json.load(f), c
    raise SystemExit("no inputs file found")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", default=None)
    ap.add_argument("--outdir", default=None)
    args = ap.parse_args()

    data, src = load_inputs(args.inputs)
    outdir = args.outdir or os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
    os.makedirs(outdir, exist_ok=True)

    B = float(data["staking"]["bonded_swth"])
    NB = float(data["staking"]["not_bonded_swth"])
    SUP = float(data["staking"]["total_supply_swth"])
    price = float(data["prices"]["swth_usd_defillama"])
    osmo = float(data["prices"]["osmo_usd_defillama"])
    halt = data["halt"]
    cp = float(data["community_pool"]["unspent_locked_swth"])
    cp_spent = float(data["community_pool"]["spent_via_proposals_swth"])
    pools = data["osmosis_swth_pools"]["pools"]
    tvl_chain = float(data["tvl"]["defillama_chain_carbon_usd"])
    tvl_demex = float(data["tvl"]["demex_usd"])
    tvl_nitron = float(data["tvl"]["nitron_usd"])
    actives = data["validators_active"]

    # ---------- capture cost (standard corrections) ----------
    # naive (corpus): q x B, ignoring that the attacker's own stake enters the denominator
    naive = Q * B
    # corrected solo-quorum: x/(B+x) >= q  =>  x >= q/(1-q) x B
    corrected = Q / (1 - Q) * B
    # majority vs full validator turnout (all others vote No): x/(x+B) > 0.5 => x > B
    majority = B * 1.0000001
    # veto-proof: x/(x+B) > 2/3 => x > 2B
    vetoproof = 2 * B * 1.0000001

    usd = lambda x: x * price
    capture = {
        "bonded_swth": B,
        "not_bonded_swth": NB,
        "supply_swth": SUP,
        "bonded_share_of_supply": B / SUP,
        "gov_quorum": Q, "gov_threshold": THRESH, "gov_veto": VETO,
        "min_deposit_swth": data["gov"]["min_deposit_swth"],
        "voting_period_days": data["gov"]["voting_period_days"],
        "unbonding_days": UNBOND_DAYS,
        "naive_quorum_swth": naive, "naive_quorum_usd": usd(naive),
        "corrected_solo_quorum_swth": corrected, "corrected_solo_quorum_usd": usd(corrected),
        "majority_full_turnout_swth": majority, "majority_full_turnout_usd": usd(majority),
        "veto_proof_swth": vetoproof, "veto_proof_usd": usd(vetoproof),
        "corpus_reconciliation": {
            "corpus_cost_usd": 30600,
            "corpus_price_used": 0.0001722,
            "naive_quorum_usd_at_corpus_price": naive * 0.0001722,
            "note": "corpus $30.6k = naive quorum x DMX price 2026-10-05; ignores own-stake denominator, liquidity and the halt"
        }
    }

    # ---------- validator bloc / veto ----------
    switcheo = actives[0]
    switcheo_share = switcheo["staked_swth"] / B
    validator_bloc = {
        "active_validators": len(actives),
        "max_validators": data["staking"]["max_validators"],
        "inactive_nodes": 45,
        "top1_moniker": switcheo["moniker"],
        "top1_staked_swth": switcheo["staked_swth"],
        "top1_share_of_bonded": switcheo_share,
        "top1_can_single_veto": switcheo_share > VETO,
        "top3_share": sum(v["staked_swth"] for v in actives[:3]) / B,
        "all_active_share": sum(v["staked_swth"] for v in actives) / B,
        "note": "All 532,905,309 bonded SWTH sits in 6 active validators; the largest (Switcheo Staking, 38.42%) alone exceeds the 33.4% veto threshold."
    }

    # ---------- liquidity / executability ----------
    p651 = [p for p in pools if int(p["id"]) == 651][0]
    S = float(p651["swth"]); O = float(p651["counter_amount"])
    total_swth_onchain = sum(float(p["swth"]) for p in pools)
    # constant-product buy cost: to buy x SWTH from pool 651 you pay c OSMO = O*x/(S-x)
    def buy_cost_osmo(x, S=S, O=O):
        return O * x / (S - x) if x < S else float("inf")
    # sell: dump x SWTH into pool 651 -> OSMO out = O*x/(S+x)
    def sell_osmo(x, S=S, O=O):
        return O * x / (S + x)
    # realistic max on-chain buy = drain 98.5% of pool 651 + other pools' SWTH
    realistic_buy_swth = 0.985 * S + sum(float(p["swth"]) for p in pools if p["id"] != 651)
    liquidity = {
        "pool_651_swth": S, "pool_651_osmo": O,
        "pool_651_swth_usd": S * price, "pool_651_osmo_usd": O * osmo,
        "total_swth_on_osmosis": total_swth_onchain,
        "total_swth_on_osmosis_usd": total_swth_onchain * price,
        "buy_depth_usd_pool651_counter_side": O * osmo,
        "realistic_max_onchain_buy_swth": realistic_buy_swth,
        "realistic_max_onchain_buy_usd_at_spot": realistic_buy_swth * price,
        "realistic_max_buy_cost_usd": buy_cost_osmo(realistic_buy_swth) * osmo,
        "realistic_buy_coverage_of_corrected_quorum": realistic_buy_swth / corrected,
        "realistic_buy_coverage_of_naive_quorum": realistic_buy_swth / naive,
        "note": "Osmosis is the only SWTH market (CoinGecko lists 1 ticker; 24h volume $2.1). Even absorbing ~98.5% of pool 651's SWTH side (~1.4% of the corrected quorum requirement) costs ~$40k in OSMO due to slippage."
    }

    # ---------- what a proposal can actually pay ----------
    cp_dump_osmo = sell_osmo(cp)
    cp_dump_usd = cp_dump_osmo * osmo
    proceeds = {
        "community_pool_nominal_swth": cp,
        "community_pool_nominal_usd": usd(cp),
        "community_pool_spent_historically_swth": cp_spent,
        "cp_spend_precedent": True,
        "cp_realizable_usd_dump_into_pool651": cp_dump_usd,
        "cp_realizable_ceiling_usd": O * osmo,
        "chain_tvl_usd": tvl_chain,
        "demex_tvl_usd": tvl_demex,
        "nitron_tvl_usd": tvl_nitron,
        "tvl_directly_gov_spendable_usd": 0.0,
        "tvl_note": "The $250,097 chain TVL (Demex $184,651 + Nitron $65,446) sits in module accounts / user pools / perp-pool NAV. No Carbon module exposes a governance message that transfers module balances (checked carbon-js-sdk v0.11.75 tx protos: only MsgUpdateParams/relayer/controller ops are authority-gated). Moving it requires a malicious software upgrade (P) or bridge-controller compromise, not a proposal.",
        "distribution_pool_swth": data["distribution_pool"]["total_swth"],
        "distribution_pool_usd": data["distribution_pool"]["total_swth"] * price
    }

    # ---------- halt ----------
    halt_block = {
        "halted": halt["halted"],
        "last_block_height": halt["last_block_height"],
        "last_block_time": halt["last_block_time"],
        "age_days_at_capture": round((datetime.datetime(2026, 10, 9, 14, 44, 41) -
             datetime.datetime(2026, 9, 25, 20, 1, 25)).total_seconds() / 86400, 2),
        "executable_today": False,
        "note": "No transaction can execute on carbon-1 since 2026-09-25T20:01:25Z; governance, staking, IBC and module calls are all frozen."
    }

    # ---------- verdict ----------
    verdict = {
        "classification": {
            "E-U": 0.0,
            "capture": 0.0,
            "P": round(tvl_chain, 2),
            "H-O": 0.0,
            "S": round(tvl_chain, 2)
        },
        "why_capture_does_not_pay": [
            "Chain is halted (block %d, 2026-09-25): no proposal can be submitted, voted or executed today." % halt["last_block_height"],
            "Direct prize is the community pool only: 55,321,211 SWTH nominal ($%.0f), but its realizable value is bounded by the single exit pool's OSMO side (~$%.0f); nominal < naive quorum cost ($%.0f) and << corrected quorum cost ($%.0f)." % (usd(cp), O * osmo, usd(naive), usd(corrected)),
            "Buying the required stake is impossible on-chain: only %.2fM SWTH exists on Osmosis vs %.1fM SWTH needed (%.2f%% coverage); no CEX market (24h volume $2.1)." % (total_swth_onchain / 1e6, corrected / 1e6, 100 * total_swth_onchain / corrected),
            "The largest active validator (Switcheo Staking, %.2f%% of bonded) can single-handedly NoWithVeto any hostile proposal." % (100 * switcheo_share),
            "The $250,097 chain TVL is not directly spendable by governance; it is reachable only through a malicious software upgrade / validator coordination (P) or bridge-controller paths."
        ],
        "latent_risk": "If the chain resumes AND an attacker somehow acquires >50%% of bonded SWTH, a CP spend could pay out the pool; with >2/3 they could push a malicious upgrade. Both are off-chain/OTC acquisition questions, not executable on-chain today.",
        "confidence": "high"
    }

    model = {
        "finding": "C2-32",
        "title": "Carbon/Demex governance capture — halted chain, uneconomic and non-executable capture",
        "generated_at_utc": datetime.datetime.utcnow().isoformat() + "Z",
        "inputs_source": src,
        "halt": halt_block,
        "capture": capture,
        "validator_bloc": validator_bloc,
        "liquidity": liquidity,
        "proceeds": proceeds,
        "verdict": verdict
    }

    with open(os.path.join(outdir, "model.json"), "w") as f:
        json.dump(model, f, indent=1)

    # ---------- markdown ----------
    md = []
    md.append("# C2-32 Carbon/Demex — capture economics (frozen state)\n")
    md.append(f"- Generated: {model['generated_at_utc']} · inputs: `{os.path.relpath(src)}`\n")
    md.append("## Halt\n")
    md.append(f"- carbon-1 halted at height **{halt_block['last_block_height']}** ({halt_block['last_block_time']}); "
              f"{halt_block['age_days_at_capture']} days old at measurement; executable today: **{halt_block['executable_today']}**\n")
    md.append("## Capture cost (SWTH, USD @ $%.8f)\n" % price)
    md.append("| gate | SWTH needed | USD |\n|---|---|---|")
    md.append(f"| naive quorum (corpus) | {naive:,.0f} | ${usd(naive):,.0f} |")
    md.append(f"| corrected solo quorum (own stake in denominator) | {corrected:,.0f} | ${usd(corrected):,.0f} |")
    md.append(f"| majority vs full turnout | {majority:,.0f} | ${usd(majority):,.0f} |")
    md.append(f"| veto-proof (>2/3) | {vetoproof:,.0f} | ${usd(vetoproof):,.0f} |\n")
    md.append("## Validator bloc\n")
    md.append(f"- Active: {validator_bloc['active_validators']} of {validator_bloc['max_validators']} slots; "
              f"all {B:,.0f} bonded SWTH in these 6; top1 {validator_bloc['top1_moniker']} "
              f"{validator_bloc['top1_share_of_bonded']*100:.2f}% (single-veto: {validator_bloc['top1_can_single_veto']}); top3 {validator_bloc['top3_share']*100:.2f}%\n")
    md.append("## Liquidity (only venue: Osmosis)\n")
    md.append(f"- pool 651: {S:,.2f} SWTH (${S*price:,.0f}) vs {O:,.2f} OSMO (${O*osmo:,.0f})")
    md.append(f"- all SWTH on Osmosis: {total_swth_onchain:,.2f} SWTH (${total_swth_onchain*price:,.0f}); coverage of corrected quorum: "
              f"{100*realistic_buy_swth/corrected:.2f}%")
    md.append(f"- realistic max on-chain buy: {realistic_buy_swth:,.0f} SWTH for ~${buy_cost_osmo(realistic_buy_swth)*osmo:,.0f}\n")
    md.append("## What a proposal can pay\n")
    md.append(f"- community pool: {cp:,.0f} SWTH nominal (${usd(cp):,.0f}); realizable dump value ~${cp_dump_usd:,.0f} (ceiling ${O*osmo:,.0f})")
    md.append(f"- chain TVL: ${tvl_chain:,.0f} (Demex ${tvl_demex:,.0f} + Nitron ${tvl_nitron:,.0f}) — **not directly gov-spendable**\n")
    md.append("## Verdict\n")
    md.append(f"- E-U: $0 · capture: $0 · P: ${tvl_chain:,.0f} · H-O: $0 · S: ${tvl_chain:,.0f} · confidence: {verdict['confidence']}")
    for w in verdict["why_capture_does_not_pay"]:
        md.append(f"  - {w}")
    with open(os.path.join(outdir, "model.md"), "w") as f:
        f.write("\n".join(md) + "\n")

    print(json.dumps({"ok": True, "outdir": outdir, "naive_usd": usd(naive),
                      "corrected_usd": usd(corrected), "cp_nominal_usd": usd(cp),
                      "cp_realizable_usd": cp_dump_usd, "tvl_usd": tvl_chain}, indent=1))

if __name__ == "__main__":
    main()

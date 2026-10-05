#!/usr/bin/env python3
"""C2-05 Stride governance capture — live-state valuation + attack cost model.

Reads the raw JSON pulls in ci-out/raw/ (produced by ci/run.sh) and writes
ci-out/report.json and ci-out/report.txt. Pure read-only computation; no secrets.
"""
import json, os, sys, glob

RAW = os.path.join(os.path.dirname(__file__), "..", "ci-out", "raw")
OUT = os.path.join(os.path.dirname(__file__), "..", "ci-out")

def load(name, default=None):
    p = os.path.join(RAW, name)
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return default

def load_jsonl(name):
    rows = []
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        return rows
    with open(p) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                pass
    return rows

# ---------------------------------------------------------------- constants
# CP / bank denom -> (label, decimals, price_key). price_key resolved from prices.json
DENOMS = {
    "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2": ("ATOM", 6, "coingecko:cosmos"),
    "ibc/4B322204B4F59D770680FE4D7A565DDC3F37BFF035474B717476C66A4F83DD72": ("EVMOS", 18, "coingecko:evmos"),
    "ibc/520D9C4509027DE66C737A1D6A6021915A3071E30DBA8F758B46532B060D7AA5": ("SAGA", 6, "coingecko:saga-2"),
    "ibc/561C70B20188A047BFDE6F9946BDDC5D8AC172B9BE04FF868DFABF819E5A9CCE": ("DYDX", 18, "coingecko:dydx-chain"),
    "ibc/A7454562FF29FE068F42F9DE4805ABEF54F599D1720B345D6518D9B5C64EA6D2": ("INJ", 18, "coingecko:injective-protocol"),
    "ibc/BF3B4F53F3694B66E13C23107C84B6485BD2B96296BB7EC680EA77BBA75B4801": ("TIA", 6, "coingecko:celestia"),
    "ibc/D24B4564BCD51D3D02D9987D92571EAC5915676A9BD6D9B0C1D0254CB8A5EA34": ("OSMO", 6, "coingecko:osmosis"),
    "ibc/E1C22332C083574F3418481359733BA8887D171E76C80AD9237422AEABB66018": ("UNKNOWN(ibc/E1C2)", 0, None),
    "staISLM": ("stISLM", 18, "coingecko:islamic-coin"),
    "stadydx": ("stDYDX", 18, "coingecko:dydx-chain"),
    "stadym": ("stDYM", 18, "coingecko:dymension"),
    "staevmos": ("stEVMOS", 18, "coingecko:evmos"),
    "stinj": ("stINJ", 18, "coingecko:injective-protocol"),
    "stuatom": ("stATOM", 6, "coingecko:stride-staked-atom"),
    "stuband": ("stBAND", 6, "coingecko:band-protocol"),
    "stucmdx": ("stCMDX", 6, "coingecko:comdex"),
    "stujuno": ("stJUNO", 6, "coingecko:juno-network"),
    "stuluna": ("stLUNA", 6, "coingecko:terra-luna-2"),
    "stuosmo": ("stOSMO", 6, "coingecko:osmosis"),
    "stusaga": ("stSAGA", 6, "coingecko:saga-2"),
    "stusomm": ("stSOMM", 6, "coingecko:sommelier"),
    "stustars": ("stSTARS", 6, "coingecko:stargaze"),
    "stutia": ("stTIA", 6, "coingecko:stride-staked-tia"),
    "stuumee": ("stUMEE", 6, "coingecko:umee"),
    "ustrd": ("STRD", 6, "coingecko:stride"),
}
# host zone chainId -> (host denom, decimals, price key, stToken denom)
HOSTZONES = {
    "cosmoshub-4": ("uatom", 6, "coingecko:cosmos", "stuatom"),
    "celestia": ("utia", 6, "coingecko:celestia", "stutia"),
    "osmosis-1": ("uosmo", 6, "coingecko:osmosis", "stuosmo"),
    "dydx-mainnet-1": ("adydx", 18, "coingecko:dydx-chain", "stadydx"),
    "injective-1": ("inj", 18, "coingecko:injective-protocol", "stinj"),
    "evmos_9001-2": ("aevmos", 18, "coingecko:evmos", "staevmos"),
    "haqq_11235-1": ("aISLM", 18, "coingecko:islamic-coin", "staISLM"),
    "juno-1": ("ujuno", 6, "coingecko:juno-network", "stujuno"),
    "laozi-mainnet": ("uband", 6, "coingecko:band-protocol", "stuband"),
    "phoenix-1": ("uluna", 6, "coingecko:terra-luna-2", "stuluna"),
    "sommelier-3": ("usomm", 6, "coingecko:sommelier", "stusomm"),
    "ssc-1": ("usaga", 6, "coingecko:saga-2", "stusaga"),
    "stargaze-1": ("ustars", 6, "coingecko:stargaze", "stustars"),
    "umee-1": ("uumee", 6, "coingecko:umee", "stuumee"),
    "comdex-1": ("ucmdx", 6, "coingecko:comdex", "stucmdx"),
}

def main():
    report = {"finding": "C2-05", "chain": "stride-1"}
    prices = (load("prices.json") or {}).get("coins", {})
    price = lambda k: prices.get(k, {}).get("price") if k else None

    # ---- height
    h = load("height.json")
    try:
        report["height"] = int(h["block"]["header"]["height"])
        report["time"] = h["block"]["header"]["time"]
    except Exception:
        report["height"] = None

    # ---- gov params (gRPC) or fallback
    gp = load("gov_params_grpc.json")
    params = gp.get("params") if gp else None
    if params:
        report["gov_params"] = {
            "min_deposit_ustrd": params["minDeposit"][0]["amount"],
            "min_deposit_strd": int(params["minDeposit"][0]["amount"]) / 1e6,
            "max_deposit_period": params["maxDepositPeriod"],
            "voting_period": params["votingPeriod"],
            "quorum": params["quorum"],
            "threshold": params["threshold"],
            "veto_threshold": params["vetoThreshold"],
            "expedited_voting_period": params.get("expeditedVotingPeriod"),
            "expedited_min_deposit": params.get("expeditedMinDeposit"),
            "burn_vote_veto": params.get("burnVoteVeto"),
        }

    # ---- staking pool / supply
    pool = (load("staking_pool.json") or {}).get("pool", {})
    bonded = int(pool.get("bonded_tokens", 0))
    not_bonded = int(pool.get("not_bonded_tokens", 0))
    st_params = (load("staking_params.json") or {}).get("params", {})
    sup = {}
    for d in ["ustrd", "stuatom", "stutia"]:
        s = load(f"supply_{d}.json")
        if s and isinstance(s.get("amount"), dict) and "amount" in s["amount"]:
            sup[d] = int(s["amount"]["amount"])
        elif s and "amount" in s:
            sup[d] = int(s["amount"])
    report["staking"] = {
        "bonded_ustrd": bonded,
        "bonded_strd": bonded / 1e6,
        "not_bonded_ustrd": not_bonded,
        "unbonding_time": st_params.get("unbonding_time"),
        "bond_denom": st_params.get("bond_denom"),
        "supply_ustrd": sup.get("ustrd"),
        "supply_strd": (sup.get("ustrd") or 0) / 1e6,
        "stuatom_supply": (sup.get("stuatom") or 0) / 1e6,
        "stutia_supply": (sup.get("stutia") or 0) / 1e6,
    }

    strd_price = price("coingecko:stride")
    report["strd_price_usd"] = strd_price
    report["bonded_usd"] = (bonded / 1e6) * (strd_price or 0)

    # ---- community pool valuation
    cp = (load("community_pool.json") or {}).get("pool", []) or []
    cp_items, cp_total = [], 0.0
    for c in cp:
        denom, amt = c["denom"], int(c["amount"].split(".")[0]) if isinstance(c["amount"], str) else int(c["amount"])
        label, dec, pk = DENOMS.get(denom, (denom[:24] + "..", 6, None))
        px = price(pk) if pk else 0.0
        if dec == 0:  # unknown decimals: skip valuation
            val = 0.0
        else:
            val = (amt / (10 ** dec)) * (px or 0)
        cp_items.append({"denom": denom, "label": label, "raw": str(amt), "usd": round(val, 4), "priced": bool(px)})
        cp_total += val
    report["community_pool"] = {"items": sorted(cp_items, key=lambda x: -x["usd"]), "total_usd": round(cp_total, 2)}

    # ---- host zone custody
    hz = (load("hostzones_grpc.json") or {}).get("hostZone", [])
    custody_items, custody_total = [], 0.0
    for z in hz:
        cid = z["chainId"]
        if cid not in HOSTZONES:
            continue
        hd, dec, pk, std = HOSTZONES[cid]
        px = price(pk) or 0.0
        tot_raw = int(z.get("totalDelegations", "0") or 0)
        rr = float(z.get("redemptionRate", "0") or 0) / 1e18
        val = (tot_raw / (10 ** dec)) * px
        custody_items.append({
            "chain": cid, "host_denom": hd, "total_delegations_raw": str(tot_raw),
            "tokens": round(tot_raw / (10 ** dec), 6), "redemption_rate": round(rr, 6),
            "st_token": std, "usd": round(val, 2),
            "delegation_ica": z.get("delegationIcaAddress"),
            "redemption_ica": z.get("redemptionIcaAddress"),
            "fee_ica": z.get("feeIcaAddress"),
        })
        custody_total += val
    custody_items.sort(key=lambda x: -x["usd"])
    report["ica_custody"] = {"items": custody_items, "total_usd": round(custody_total, 2)}

    # on-chain verified ATOM / TIA delegations (from full REST pulls)
    def sum_deleg(fn):
        d = load(fn) or {}
        try:
            return sum(int(x["balance"]["amount"]) for x in d["delegation_responses"])
        except Exception:
            return None
    hub_deleg = sum_deleg("hub_ica_delegations_full.json")
    cel_deleg = sum_deleg("cel_ica_delegations_full.json")
    report["ica_onchain_verified"] = {
        "cosmoshub_atom_uatom": hub_deleg,
        "cosmoshub_atom": (hub_deleg or 0) / 1e6,
        "cosmoshub_atom_usd": round((hub_deleg or 0) / 1e6 * (price("coingecko:cosmos") or 0), 2),
        "celestia_tia_utia": cel_deleg,
        "celestia_tia": (cel_deleg or 0) / 1e6,
        "celestia_tia_usd": round((cel_deleg or 0) / 1e6 * (price("coingecko:celestia") or 0), 2),
    }

    # ---- liquidity quotes
    rows = load_jsonl("sqs_quotes.jsonl")
    curve = {"buy_osmo": [], "sell_osmo": [], "buy_usdc": []}
    osmo_px = price("coingecko:osmosis") or 0
    for r in rows:
        side = r.get("side")
        resp = r.get("resp") or {}
        try:
            out = int(resp.get("amount_out", 0))
        except Exception:
            out = 0
        inp = r.get("in", "")
        curve.setdefault(side, []).append({"in": inp, "out_raw": out, "out": out / 1e6})
    report["liquidity_curve"] = curve
    max_buy_strd = max([x["out"] for x in curve.get("buy_osmo", [])] + [x["out"] for x in curve.get("buy_usdc", [])] + [0])
    report["market_max_strd_deliverable"] = max_buy_strd
    report["market_max_strd_usd_at_spot"] = round(max_buy_strd * (strd_price or 0), 2)
    sell = curve.get("sell_osmo", [])
    report["sell_221m_strd_osmo"] = next((x["out"] for x in sell if x["in"].startswith("2210000000000")), None)
    report["sell_221m_strd_usd"] = round((report["sell_221m_strd_osmo"] or 0) * osmo_px, 2)
    report["sell_max_position_note"] = "sell curve uses routed SQS quotes; 2.21M STRD is the no-opposition quorum requirement"

    # ---- capture cost model
    B = bonded / 1e6
    x_min = B / 3.0 + 1e-6  # quorum 25% with attacker's own stake inflating the denominator
    report["attack_model"] = {
        "bonded_strd": B,
        "quorum_only_min_stake_strd": round(x_min, 2),
        "quorum_only_min_stake_usd_spot": round(x_min * (strd_price or 0), 2),
        "market_max_deliverable_strd": round(max_buy_strd, 2),
        "market_shortfall_strd": round(x_min - max_buy_strd, 2),
        "market_shortfall_pct": round(100 * (x_min - max_buy_strd) / x_min, 2),
        "min_deposit_strd": 20000,
        "min_deposit_usd": round(20000 * (strd_price or 0), 2),
        "cp_prize_usd": round(cp_total, 2),
        "robust_case_note": "To outvote historical turnout (~4.5M STRD voting) the attacker would need >50% of all bonded (~3.3M STRD) — 4.4x the entire market's deliverable STRD.",
    }

    # ---- tallies (turnout evidence)
    tallies = {}
    for f in sorted(glob.glob(os.path.join(RAW, "tally_*.json"))):
        pid = os.path.basename(f).split("_")[1].split(".")[0]
        t = (load(os.path.basename(f)) or {}).get("tally")
        if t:
            tot = sum(int(t.get(k, 0)) for k in ["yes_count", "abstain_count", "no_count", "no_with_veto_count"])
            tallies[pid] = {"total_strd": tot / 1e6, "pct_of_current_bonded": round(100 * tot / 1e6 / B, 2), **{k: int(v) / 1e6 for k, v in t.items()}}
    report["proposal_tallies"] = tallies

    with open(os.path.join(OUT, "report.json"), "w") as f:
        json.dump(report, f, indent=2)

    # human summary
    L = []
    L.append(f"C2-05 Stride governance capture — live state @ stride-1 height {report.get('height')} ({report.get('time')})")
    if params:
        L.append(f"gov: quorum={params['quorum']} threshold={params['threshold']} veto={params['vetoThreshold']} "
                 f"voting={params['votingPeriod']} minDeposit={int(params['minDeposit'][0]['amount'])/1e6:.0f} STRD")
    L.append(f"bonded={B:,.2f} STRD (${report['bonded_usd']:,.2f}); total supply={report['staking']['supply_strd']:,.2f} STRD; "
             f"unbonding={report['staking']['unbonding_time']}")
    L.append(f"STRD price=${strd_price} | stATOM supply={report['staking']['stuatom_supply']:,.2f} | stTIA supply={report['staking']['stutia_supply']:,.2f}")
    L.append(f"community pool total = ${cp_total:,.2f}")
    for it in sorted(cp_items, key=lambda x: -x['usd'])[:8]:
        L.append(f"   CP {it['label']:<14} {it['usd']:>10,.2f}")
    L.append(f"ICA custody total (gRPC totalDelegations) = ${custody_total:,.2f}")
    L.append(f"   verified on-chain ATOM delegations: {report['ica_onchain_verified']['cosmoshub_atom']:,.2f} ATOM "
             f"(${report['ica_onchain_verified']['cosmoshub_atom_usd']:,.2f})")
    L.append(f"   verified on-chain TIA delegations: {report['ica_onchain_verified']['celestia_tia']:,.2f} TIA "
             f"(${report['ica_onchain_verified']['celestia_tia_usd']:,.2f})")
    L.append(f"market max STRD deliverable = {max_buy_strd:,.0f} STRD (spot value ${report['market_max_strd_usd_at_spot']:,.2f})")
    L.append(f"quorum-only minimum stake = {x_min:,.0f} STRD (${x_min*(strd_price or 0):,.2f}); shortfall vs market = "
             f"{report['attack_model']['market_shortfall_strd']:,.0f} STRD ({report['attack_model']['market_shortfall_pct']}%)")
    L.append(f"sell 2.21M STRD -> {report['sell_221m_strd_osmo'] or 0:,.0f} OSMO (${report['sell_221m_strd_usd']:,.2f})")
    with open(os.path.join(OUT, "report.txt"), "w") as f:
        f.write("\n".join(L) + "\n")
    print("\n".join(L))

if __name__ == "__main__":
    main()

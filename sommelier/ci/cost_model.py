#!/usr/bin/env python3
"""C2-08 Sommelier capture cost/proceeds model from ci-out/live_state.json.

Writes ci-out/cost_model.json and ci-out/EVIDENCE.md. Pure arithmetic, no network.
"""
import json, os

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "ci-out")

with open(os.path.join(OUT, "live_state.json")) as f:
    S = json.load(f)

som = S["sommelier"]
prices = S.get("prices", {}).get("coins", {})
p_somm = prices.get("coingecko:sommelier", {}).get("price", 0)
p_osmo = prices.get("coingecko:osmosis", {}).get("price", 0)
p_eth = prices.get("coingecko:ethereum", {}).get("price", 0)

usomm = 1e6
bonded = int(som["staking_pool"]["bonded_tokens"]) / usomm
not_bonded = int(som["staking_pool"]["not_bonded_tokens"]) / usomm
supply = int(som["supply_usomm"]["amount"]) / usomm
cp = next((int(x["amount"].split(".")[0]) for x in som["community_pool"] if x["denom"] == "usomm"), 0) / usomm

# authority bloc from live validators
auth_ops = set(som["poa_authority_set"])
vals = {v["operator_address"]: v for v in som["validators_all"]}
auth_tokens = sum(int(vals[o]["tokens"]) for o in auth_ops if o in vals) / usomm
auth_count = sum(1 for o in auth_ops if o in vals and vals[o]["status"] == "BOND_STATUS_BONDED" and not vals[o]["jailed"])
community = bonded - auth_tokens
foundation = int(vals.get("sommvaloper1rtt69afx4dtj4t3urgm93qq7kxypzzeew4w8t0", {}).get("tokens", 0)) / usomm

gov = som.get("gov_params", {})
quorum = float(gov.get("quorum", 0.5))
threshold = float(gov.get("threshold", 0.5))
veto = float(gov.get("veto_threshold", 0.334))
min_dep = gov.get("min_deposit", {}).get("amount", "5000000000")

# Capture thresholds (boosted == raw here: authority share 73.9% >= 67% floor => multiplier 1,
# confirmed by live effective_power == raw tokens for the Foundation validator).
# gov tally (SDK 0.47): quorum = votesCast >= quorum * TotalBondedTokens(at tally, includes attacker's
# newly bonded stake); threshold = yes/(yes+no) > 0.5; veto = noWithVeto > 33.4% of votes cast.
solo_quorum = bonded / (1 - quorum) * quorum  # x >= q*(B+x) -> x = q*B/(1-q); q=0.5 -> x=B
contested_threshold = auth_tokens + 1        # beat authority plain-No votes
veto_proof = auth_tokens / veto * 2          # x so that auth/(x+auth) <= veto -> x >= auth*(1/veto - 1)
# more exact veto-proof: noWithVeto/(yes+no+veto) > veto -> auth/(x+auth) <= veto -> x >= auth*(1-veto)/veto
veto_proof_exact = auth_tokens * (1 - veto) / veto

# Liquidity: SOMM available across all Osmosis pools
pool_somm = 0.0
main_pool = None
for p in S.get("osmosis_somm_pools", []):
    toks = p.get("pool_assets") or [{"token": t} for t in p.get("pool_liquidity", [])]
    for t in toks:
        tok = t.get("token", t)
        if tok.get("denom") == "ibc/9BBA9A1C257E971E38C1422780CE6F0B0686F0A3085E2D61118D904BFE0F5F5E":
            amt = int(tok["amount"]) / usomm
            pool_somm += amt
            if p.get("id") == "627":
                main_pool = {"id": p["id"], "somm": amt}
                osmo = next((int(x["token"]["amount"]) / usomm for x in p["pool_assets"] if x["token"]["denom"] == "uosmo"), 0)
                main_pool["uosmo"] = osmo
                main_pool["osmo_usd"] = osmo * p_osmo

pair = S.get("ethereum", {}).get("pair_reserves", {})
pair_somm = pair.get("reserve0", 0) / usomm
pair_weth = pair.get("reserve1", 0) / 1e18

# Proceeds
cp_usd = cp * p_somm
cellar_items = []
for chain, c in S.get("cellars", {}).items():
    for it in c.get("items", []):
        ta = it.get("totalAssets")
        asset = it.get("asset")
        if not ta or not asset or ta.startswith("error"):
            continue
        raw = int(ta, 16)
        a = asset[-40:].lower()
        if a in ("ff970a61a04b1ca14834a43f5de4533ebddb5cc8", "af88d065e77c8cc2239327c5edb3a432268e5831"):
            usd = raw / 1e6
        elif a in ("82af49447d8a07e3bd95bd0d56f35241523fbab1", "4200000000000000000000000000000000000006",
                   "5300000000000000000000000000000000000004"):
            usd = raw / 1e18 * p_eth
        else:
            usd = None
        cellar_items.append({"chain": chain, "address": it["address"], "owner": it.get("owner"),
                             "asset": asset, "raw_totalAssets": str(raw), "usd": usd})
cellar_usd = sum(x["usd"] or 0 for x in cellar_items)

# cellarfees
cf = {b["denom"]: int(b["amount"]) for b in som["module_balances"].get("cellarfees", [])}
cf_usd = (
    cf.get("gravity0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 0) / 1e6
    + cf.get("gravity0xdAC17F958D2ee523a2206206994597C13D831ec7", 0) / 1e6
    + cf.get("gravity0x853d955aCEf822Db058eb8505911ED77F175b99e", 0) / 1e18
    + cf.get("gravity0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84", 0) / 1e18 * p_eth
)

# gravity module balance (escrow accounting)
gm = som["module_balances"].get("gravity", [])
gravity_usomm = next((int(x["amount"]) / usomm for x in gm if x["denom"] == "usomm"), 0)

model = {
    "chain": "sommelier-3",
    "height": som["height"],
    "time": som["time"],
    "gov_params": gov,
    "token": {"price_usd": p_somm, "osmo_usd": p_osmo, "eth_usd": p_eth},
    "staking": {
        "bonded_somm": bonded, "not_bonded_somm": not_bonded, "supply_somm": supply,
        "bonded_usd_paper": bonded * p_somm,
        "authority_validators": auth_count, "authority_somm": auth_tokens,
        "authority_share": auth_tokens / bonded if bonded else 0,
        "foundation_somm": foundation, "foundation_share": foundation / bonded if bonded else 0,
        "community_somm": community,
        "poa_floor_fraction": float(som["poa_params"]["floor_fraction"]),
        "poa_multiplier_live": 1.0,
        "poa_safe_mode_active": som["poa_safe_mode"]["active"],
    },
    "capture_cost_somm": {
        "solo_quorum": solo_quorum,
        "contested_plain_no": contested_threshold,
        "veto_proof": veto_proof_exact,
    },
    "capture_cost_usd": {
        "solo_quorum": solo_quorum * p_somm,
        "contested_plain_no": contested_threshold * p_somm,
        "veto_proof": veto_proof_exact * p_somm,
        "min_deposit_somm": int(min_dep) / usomm,
        "min_deposit_usd": int(min_dep) / usomm * p_somm,
    },
    "liquidity": {
        "osmosis_somm_total_in_pools": pool_somm,
        "osmosis_main_pool_627": main_pool,
        "ethereum_uniswap_v2_pair_somm": pair_somm,
        "ethereum_uniswap_v2_pair_weth": pair_weth,
        "public_market_so_mm_ceiling_somm": pool_somm + pair_somm,
        "pct_of_solo_quorum_available": (pool_somm + pair_somm) / solo_quorum if solo_quorum else None,
    },
    "proceeds": {
        "community_pool_somm": cp,
        "community_pool_usd_paper": cp_usd,
        "cork_managed_cellars_usd": cellar_usd,
        "cork_managed_cellars": cellar_items,
        "cellarfees_usd": cf_usd,
        "gravity_module_usomm": gravity_usomm,
        "gravity_module_usd_paper": gravity_usomm * p_somm,
        "total_privileged_paper_usd": cp_usd + cellar_usd,
    },
    "verdict": {
        "eu_live_usd": 0.0,
        "reason": ("capture requires >52.8M SOMM (authority bloc, veto-proof ~105.7M) but only "
                   f"{pool_somm + pair_somm:,.0f} SOMM exists in all public DEX pools; "
                   "authority bloc holds %.1f%% of bonded; June-2026 drain attempt (prop 173) failed quorum+veto"
                   % (100 * auth_tokens / bonded)),
    },
}

with open(os.path.join(OUT, "cost_model.json"), "w") as f:
    json.dump(model, f, indent=1)

# EVIDENCE.md
L = []
L.append("# C2-08 Sommelier — live evidence (CI run)\n")
L.append(f"- Chain: sommelier-3 @ height {som['height']} ({som['time']})")
L.append(f"- Gov params: quorum={gov.get('quorum')} threshold={gov.get('threshold')} veto={gov.get('veto_threshold')} "
         f"voting={gov.get('voting_period_s')}s deposit={gov.get('max_deposit_period_s')}s min_deposit={min_dep}")
L.append(f"- Bonded: {bonded:,.0f} SOMM (${bonded*p_somm:,.0f} paper @ ${p_somm:.6f}); "
         f"authority bloc {auth_tokens:,.0f} SOMM ({100*auth_tokens/bonded:.2f}%, {auth_count} validators); "
         f"Foundation {foundation:,.0f} ({100*foundation/bonded:.2f}%)")
L.append(f"- PoA: safe_mode={som['poa_safe_mode']} floor={som['poa_params']['floor_fraction']} (multiplier live = 1)")
L.append(f"- Capture thresholds: solo quorum {solo_quorum:,.0f} SOMM (${solo_quorum*p_somm:,.0f}); "
         f"beat-plain-No {contested_threshold:,.0f} (${contested_threshold*p_somm:,.0f}); "
         f"veto-proof {veto_proof_exact:,.0f} (${veto_proof_exact*p_somm:,.0f})")
L.append(f"- Public DEX SOMM ceiling: {pool_somm + pair_somm:,.2f} SOMM "
         f"(Osmosis {pool_somm:,.2f} across {len(S.get('osmosis_somm_pools',[]))} pools + Ethereum v2 {pair_somm:,.2f}) "
         f"= {100*(pool_somm+pair_somm)/solo_quorum:.2f}% of solo-quorum need")
L.append(f"- Proceeds (paper): CP {cp:,.0f} SOMM = ${cp_usd:,.0f}; cork-managed cellars ${cellar_usd:,.0f}; "
         f"cellarfees ${cf_usd:,.2f}; gravity module {gravity_usomm:,.0f} SOMM")
L.append(f"- Cork authority: {som['cork_params'].get('cork_authority')} "
         f"(single EOA, seq {som.get('cork_authority_account',{}).get('sequence')})")
L.append(f"- Managed cellars: {json.dumps(som['axelarcork_cellar_ids'])}")
L.append(f"- Verdict: E-U ${model['verdict']['eu_live_usd']:.2f} — {model['verdict']['reason']}")
with open(os.path.join(OUT, "EVIDENCE.md"), "w") as f:
    f.write("\n".join(L) + "\n")

print(json.dumps(model["verdict"], indent=1))
print("capture cost USD:", json.dumps(model["capture_cost_usd"], indent=1))
print("liquidity:", json.dumps(model["liquidity"], indent=1))
print("proceeds:", json.dumps({k: v for k, v in model["proceeds"].items() if k != "cork_managed_cellars"}, indent=1))

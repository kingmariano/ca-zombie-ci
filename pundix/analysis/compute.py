#!/usr/bin/env python3
"""C2-33 PundiX governance-capture economics — compute from live raw snapshot.

Reads analysis/snapshot_live.json (public LCD reads at explicit height) plus
module/escrow balance files, and emits clean params.json / assets.json /
capture_economics.json. No secrets; public data only.
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
D = 10**18

def load(name):
    with open(os.path.join(HERE, name)) as f:
        return json.load(f)

snap = load('snapshot_live.json')
mods = load('module_balances.json')
esc = load('escrow_balances_v340.json')

PUNDIX = "ibc/55367B7B6572631B78A93C66EF9FDFCE87CDE372CC4ED7848DA78C1EB1DCDD78"
PURSE  = "bsc0x29a63F4B209C29B4DC47f06FFA896F32667DAD2C"

# prices (DefiLlama / CoinGecko, 2026-10-09)
PRICE = {
    "PUNDIX_DL": 0.11189131591008934,
    "PUNDIX_CG": 0.112057,
    "PURSE": 0.000002068669043896242,
    "FX": 0.071802,          # CoinGecko fx-coin (old Function X mark)
    "WETH": 2496.4015703447217,
    "USDT": 1.0,
    "OSMO_note": "dust",
}
P = PRICE["PUNDIX_DL"]

pool = snap['staking_pool']['pool']
bonded = int(pool['bonded_tokens']) / D
not_bonded = int(pool['not_bonded_tokens']) / D
supply = {x['denom']: int(x['amount']) for x in snap['supply']['supply']}
cp = {x['denom']: float(x['amount']) for x in snap['community_pool']['pool']}
dist = {x['denom']: int(x['amount']) for x in snap['distribution_module_balances']['balances']}

supply_px = supply[PUNDIX] / D
supply_purse = supply[PURSE] / D
cp_px = cp[PUNDIX] / D
cp_purse = cp[PURSE] / D
dist_px = dist.get(PUNDIX, 0) / D
dist_purse = dist.get(PURSE, 0) / D

esc0 = {x['denom']: int(x['amount']) for x in esc['transfer_escrow_ch0_v340']['balances']}
esc1 = {x['denom']: int(x['amount']) for x in esc['transfer_escrow_ch1_v340']['balances']}
esc0_purse = esc0.get(PURSE, 0) / D
esc1_purse = esc1.get(PURSE, 0) / D

free_px = supply_px - bonded - not_bonded - cp_px
free_purse = supply_purse - esc0_purse - esc1_purse - dist_purse

# other user vouchers (from supply; IBC traces in snapshot)
other = {}
for denom, raw in supply.items():
    if denom in (PUNDIX, PURSE):
        continue
    trace = snap['denom_traces'].get(denom, {})
    base = trace.get('base_denom', '?')
    other[denom] = {"raw": raw, "base_denom": base, "path": trace.get('path')}
# known decimals from traces: usdt 6, uosmo 6, FX 18, weth 18
dec = {
    "ibc/027BB5CDD412B8C3130E1D7EF27D3C90412373FDFB915D3F0B35C067A85819EA": (6, 'USDT', 1.0),
    "ibc/0471F1C4E7AFD3F07702BEF6DC365268D64570F7C1FDC98EA6098DD6DE59817B": (6, 'OSMO', 0.0),
    "ibc/0816EE31A3FE24B7B00ED64C6ABB34C3FD14410A5DCFB61CD7C126ABFE96B9ED": (6, 'USDT', 1.0),
    "ibc/37CA072246C3BCBB445AEC196645F5AAB7876C456D76BC96141D3A0D6E615D2E": (18, 'FX', PRICE['FX']),
    "ibc/41746107C9CB12ECF4402F46ECCEF66D0C30D9283E6647DCAFED8A09C9A78197": (18, 'WETH', PRICE['WETH']),
    "ibc/6259AD5A0FEBC77820378BCF9939ABFC3BB4CC8E2F2094703669F217858F1BE1": (6, 'USDT', 1.0),
}
other_usd = 0.0
for denom, (d, sym, price) in dec.items():
    amt = supply.get(denom, 0) / 10**d
    usd = amt * price
    other[denom].update({"amount": amt, "symbol": sym, "price_usd": price, "usd": round(usd, 2)})
    other_usd += usd

# gov params
def param_value(key):
    v = snap[f'gov_{key}']['param']['value']
    return json.loads(v)

vp = param_value('votingparams')
tp = param_value('tallyparams')
dp = param_value('depositparams')

Q = float(tp['quorum'])
THR = float(tp['threshold'])
VETO = float(tp['veto_threshold'])
min_dep = int(dp['min_deposit'][0]['amount']) / D
voting_days = int(vp['voting_period']) / 1e9 / 86400
dep_days = int(dp['max_deposit_period']) / 1e9 / 86400

params = {
    "height": snap['height'],
    "block_time": snap['block_time'],
    "chain_id": "PUNDIX",
    "binary": {"app": "pundix", "version": "HEAD-9be0620c49bbea1d44d864a54bb5cfadc989f1b3",
               "cosmos_sdk": "v0.45.11", "ibc_go": "v3.4.0", "wasm": None},
    "bond_denom": PUNDIX,
    "gov": {"quorum": Q, "threshold": THR, "veto_threshold": VETO,
            "voting_period_days": voting_days, "max_deposit_period_days": dep_days,
            "min_deposit_PUNDIX": min_dep, "min_deposit_usd": round(min_dep * P, 2)},
    "staking": {"unbonding_time_s": 1814400, "max_validators": 50, "bonded_validators": 20},
    "mint": {"mint_denom": PURSE, "inflation_now_pct": 27.2154, "inflation_max_pct": 40.0,
             "inflation_min_pct": 20.0, "goal_bonded": 0.51},
    "prices": PRICE,
    "sources": {"lcd": "https://px-rest.pundix.com",
                "gov_params": "/cosmos/params/v1beta1/params?subspace=gov&key=tallyparams (live)",
                "tally_semantics": "cosmos-sdk v0.45.11 x/gov/keeper/tally.go: quorum denominator = TotalBondedTokens(ctx) at tally; any account may vote"},
}

assets = {
    "height": snap['height'],
    "PUNDIX": {
        "denom": PUNDIX,
        "supply": supply_px, "supply_usd": round(supply_px * P, 2),
        "bonded": bonded, "bonded_usd": round(bonded * P, 2),
        "not_bonded_unbonding": not_bonded, "not_bonded_usd": round(not_bonded * P, 2),
        "community_pool": cp_px, "community_pool_usd": round(cp_px * P, 2),
        "free_user_float": free_px, "free_user_float_usd": round(free_px * P, 2),
    },
    "PURSE": {
        "denom": PURSE,
        "supply": supply_purse, "supply_usd_nominal": round(supply_purse * PRICE['PURSE'], 2),
        "ibc_escrow_channel0_fxcore": esc0_purse,
        "ibc_escrow_channel0_usd": round(esc0_purse * PRICE['PURSE'], 2),
        "ibc_escrow_channel1_osmosis": esc1_purse,
        "ibc_escrow_channel1_usd": round(esc1_purse * PRICE['PURSE'], 2),
        "distribution_module": dist_purse,
        "community_pool": cp_purse, "community_pool_usd": round(cp_purse * PRICE['PURSE'], 2),
        "unclaimed_staking_rewards_in_distribution": dist_purse - cp_purse,
        "unclaimed_rewards_usd": round((dist_purse - cp_purse) * PRICE['PURSE'], 2),
        "free_user_float": free_purse, "free_user_float_usd": round(free_purse * PRICE['PURSE'], 2),
    },
    "module_accounts": {k: v['balances'] for k, v in mods.items()},
    "ibc_escrows_v340": esc,
    "other_user_vouchers": other,
    "other_user_vouchers_usd": round(other_usd, 2),
}

# capture economics
naive = Q * bonded
selfinc = Q / (1 - Q) * bonded
majority = bonded          # outvote full bonded turnout (yes > 50% of non-abstain)
vetoproof = bonded * (1 - VETO) / VETO
cp_usd = cp_purse * PRICE['PURSE'] + cp_px * P

capture = {
    "height": snap['height'],
    "quorum": Q, "threshold": THR, "veto": VETO,
    "bonded_PUNDIX": bonded, "bonded_usd": round(bonded * P, 2),
    "proceeds": {"community_pool_usd": round(cp_usd, 2),
                 "community_pool_PURSE": cp_purse, "community_pool_PUNDIX": cp_px,
                 "gov_movable_beyond_cp": 0.0,
                 "note": "CP is the only asset any gov message can move immediately; escrows/pools/user balances are not gov-spendable; software upgrade is validator-adopted (P)."},
    "scenarios": {
        "naive_quorum_only_QxB": {"pundix": naive, "usd": round(naive * P, 2)},
        "precise_self_inclusive_Q_over_1mQ_xB": {"pundix": selfinc, "usd": round(selfinc * P, 2),
            "note": "v0.45 tally: attacker's own stake enters the quorum denominator; minimum when nobody else votes."},
        "majority_of_cast_votes_full_turnout_opposition": {"pundix": majority, "usd": round(majority * P, 2)},
        "veto_proof_full_turnout_opposition": {"pundix": vetoproof, "usd": round(vetoproof * P, 2)},
    },
    "acquisition": {
        "onchain_free_float_PUNDIX": free_px, "onchain_free_float_usd": round(free_px * P, 2),
        "onchain_float_vs_naive_pct": round(100 * free_px / naive, 2),
        "onchain_float_vs_precise_pct": round(100 * free_px / selfinc, 2),
        "only_route": "IBC channel-0 from fxcore (voucher origin chain); fxcore public LCD/RPC endpoints return 503 (checked 2026-10-09) - bridge-in feasibility unverified.",
        "note": "No DEX/AMM on PundiX chain (no wasm, no AMM module; 1,111 accounts total). Tokens must be bridged in via channel-0 (fxcore) or channel-1 (osmosis-1).",
    },
    "ev": {
        "naive": round(cp_usd - naive * P, 2),
        "precise": round(cp_usd - selfinc * P, 2),
        "note": "Attacker's principal is recoverable after 21-day unbonding, but exposed to price risk; the CP itself is in bridged/native vouchers needing outbound bridge to realize USD.",
    },
    "corpus_reconciliation": {
        "claimed_capture_usd": 33600,
        "implied": "0.40 x 685,703.54 x $0.1225 (Oct-4-2026 price) = $33.5k - the corpus figure used the correct live quorum but the pre-drawdown price",
        "live_price_usd": P,
        "correction": "self-inclusive denominator raises the true minimum to $51.1k; either way >= 16x the CP",
    },
    "verdict": "dead end confirmed: capture cost >= $30.7k (naive) / $51.1k (precise) vs CP $1,844.44; acquisition additionally constrained (float 217.4k < 274.3k/457.1k needed); EV <= -$28.8k",
}

for name, obj in [("params.json", params), ("assets.json", assets), ("capture_economics.json", capture)]:
    with open(os.path.join(HERE, name), 'w') as f:
        json.dump(obj, f, indent=2)
    print("wrote", name)

print(json.dumps(capture, indent=2))

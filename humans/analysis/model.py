#!/usr/bin/env python3
"""
C2-30 Humans governance capture — cost model (read-only; public data only).

Inputs: raw/*.json (live pulls saved by pull_state_slim.py / deep_checks.py / float_discovery.py / cex_books.json)
Outputs: out/model.json + out/model.md

Key corrections applied (per campaign standard):
  * attacker's own stake enters the quorum denominator (B_end = B + S)
  * threshold = yes/(votes - abstain) > 50%  (SDK v0.46.11 tally.go, verified from source)
  * veto = NWV/total votes > 33.4% (denominator = votes cast, not bonded)
  * float depth: on-chain HEART buyable vs 697M needed; exit liquidity for the captured asset
  * CP-spend cap = feePool.CommunityPool accounting (SDK v0.46.11 DistributeFromFeePool)
"""
import json, os, hashlib
from decimal import Decimal, getcontext

getcontext().prec = 50
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)

def D(x): return Decimal(str(x))
def load(n): return json.load(open(os.path.join(RAW, n)))

st = load("state.json")
deep = load("deep_checks.json")
esc = load("escrows.json")
flt = load("float.json")
books = load("cex_books.json")

# ---------------- measured inputs ----------------
B = D(st["staking_pool"]["bonded_tokens"]) / D(10**18)            # bonded HEART
NB = D(st["staking_pool"]["not_bonded_tokens"]) / D(10**18)
SUP = D(st["supply_all"][0]["amount"]) / D(10**18)
CP_AHEART = D(st["community_pool"][0]["amount"])
CP = CP_AHEART / D(10**18)                                        # community pool HEART
CP2_AHEART = D(st["community_pool_noders"][0]["amount"])         # second LCD cross-check
def modbal(name):
    bals = deep["module_accounts_full"][name]["balances"] or []
    return sum(D(b["amount"]) for b in bals if b["denom"] == "aheart") / D(10**18)
DIST = modbal("distribution")
GOVBAL = modbal("gov")
NBPOOL = modbal("not_bonded_tokens_pool")
REWARDS = D(deep["outstanding_rewards_sum_aheart"]) / D(10**18)   # all-validator outstanding rewards
try:
    REWARDS_ALL = D(load("rewards_all.json")["total_aheart"]) / D(10**18)
except Exception:
    REWARDS_ALL = REWARDS
PRICE = D("0.00034294")          # CoinGecko+DefiLlama, 2026-10-09
ETH = D("2494.7105955717993")    # DefiLlama 2026-10-09
PRICE_OCT4 = D("0.0004100524599550983")   # DefiLlama historical 2026-10-04
PRICE_OCT5 = D("0.0004147169922523474")   # DefiLlama historical 2026-10-05

# gov params (ABCI + genesis cross-checked)
QUORUM, THRESHOLD, VETO = D("0.334"), D("0.5"), D("0.334")
MIN_DEP = D("25000")   # aheart->HEART 25,000
VOTING_DAYS = 5

# validators
vals = sorted(st["validators_bonded"], key=lambda v: -int(v["tokens"]))
shares = [(v["description"]["moniker"], D(v["tokens"]) / D(10**18) / B) for v in vals]
top2 = sum(s for _, s in shares[:2]); top4 = sum(s for _, s in shares[:4])

# float
osmo_pool_heart = D("15004536351236428262957552") / D(10**18)
osmo_pool_usdc = D("3056875444") / D(10**6)
eth_heart = D("60511710052094407587870226") / D(10**18)
eth_weth = D("8373832705164386167") / D(10**18)
gate_ask = sum(D(b[0]) * D(b[1]) for b in books["gate"]["asks"]) if books["gate"].get("asks") else D(0)
gate_bid = sum(D(b[0]) * D(b[1]) for b in books["gate"]["bids"]) if books["gate"].get("bids") else D(0)
onchain_buyable_heart = osmo_pool_heart + eth_heart
exit_usd = osmo_pool_usdc + eth_weth * ETH + gate_bid

# escrows
esc_ch4 = D(esc["channel-4"]["balances"][0]["amount"]) / D(10**18) if esc["channel-4"]["balances"] else D(0)
esc_all = sum(D(b["amount"]) for ch in esc.values() for b in (ch["balances"] or [])) / D(10**18)

# ---------------- model ----------------
out = {"finding": "C2-30", "chain": "humans_1089-1", "measured": {
    "height": st["height"], "time": st["time"],
    "bonded_heart": str(B), "not_bonded_heart": str(NB), "supply_heart": str(SUP),
    "community_pool_heart": str(CP), "community_pool_heart_lcd2": str(CP2_AHEART / D(10**18)),
    "distribution_module_heart": str(DIST), "outstanding_rewards_all_vals_heart": str(REWARDS_ALL),
    "not_bonded_pool_heart": str(NBPOOL), "gov_module_heart": str(GOVBAL),
    "price_usd": str(PRICE), "eth_usd": str(ETH),
    "gov_params": {"quorum": str(QUORUM), "threshold": str(THRESHOLD), "veto": str(VETO),
                    "min_deposit_heart": str(MIN_DEP), "voting_days": VOTING_DAYS},
    "top2_share": str(top2), "top4_share": str(top4),
    "float": {"osmo_pool1493_heart": str(osmo_pool_heart), "osmo_pool1493_usdc": str(osmo_pool_usdc),
              "eth_univ2_heart": str(eth_heart), "eth_univ2_weth": str(eth_weth),
              "gate_asks_usd_50lvl": str(gate_ask), "gate_bids_usd_50lvl": str(gate_bid),
              "onchain_heart_buyable": str(onchain_buyable_heart), "exit_usd_approx": str(exit_usd)},
    "escrows_heart": {"channel0_osmosis": str(D(esc["channel-0"]["balances"][0]["amount"]) / D(10**18)) if esc["channel-0"]["balances"] else "0",
                       "channel3_osmosis": str(D(esc["channel-3"]["balances"][0]["amount"]) / D(10**18)) if esc["channel-3"]["balances"] else "0",
                       "channel4_osmosis": str(esc_ch4), "total": str(esc_all)},
}}

m = {}
# capture cost paths (HEART needed)
m["solo_quorum_stake_heart"] = str(QUORUM / (1 - QUORUM) * B)          # 0.5015 * B
m["outvote_top2_no_heart"] = str(top2 / (1 - top2) * B)
m["outvote_top4_no_heart"] = str(top4 / (1 - top4) * B)
m["veto_block_top2_heart"] = str(top2 / (1 - top2) * B)                # same form (NWV > 0.5015*Yes)
# costs in USD
for k in ("solo_quorum_stake_heart", "outvote_top2_no_heart", "outvote_top4_no_heart"):
    m[k + "_usd_spot"] = str(D(m[k]) * PRICE)
m["deposit_heart"] = str(MIN_DEP)
m["deposit_usd"] = str(MIN_DEP * PRICE)
m["gas_est_heart"] = str(D("0.05"))                                    # ~500k gas @ 100 Gwei = 0.05 HEART
m["gas_est_usd"] = str(D("0.05") * PRICE)

# proceeds
m["cp_spend_cap_heart"] = str(CP)
m["cp_spend_cap_usd"] = str(CP * PRICE)
m["gov_module_usd"] = str(GOVBAL * PRICE)
m["direct_gov_movable_usd"] = str(CP * PRICE + GOVBAL * PRICE)
m["latent_upgrade_reachable_heart"] = str(DIST + NBPOOL + esc_all)     # non-staking custody + escrow
m["latent_upgrade_reachable_usd"] = str((DIST + NBPOOL + esc_all) * PRICE)
m["latent_incl_bonded_heart"] = str(DIST + NBPOOL + esc_all + B)
m["latent_incl_bonded_usd"] = str((DIST + NBPOOL + esc_all + B) * PRICE)
m["annual_inflation_heart"] = "554263587.03"
m["annual_inflation_usd"] = str(D("554263587.03") * PRICE)

# float adequacy
m["float_cover_ratio"] = str(onchain_buyable_heart / D(m["solo_quorum_stake_heart"]))
m["exit_recovery_ratio"] = str(exit_usd / D(m["solo_quorum_stake_heart_usd_spot"]))

# corpus artifact (the $50.7k claim)
m["corpus_artifact_heart_6dec"] = str(CP_AHEART / D(10**6))            # misread as 6-decimals
m["corpus_artifact_usd_oct5"] = str(CP_AHEART / D(10**6) * PRICE_OCT5)
m["corpus_artifact_usd_oct4"] = str(CP_AHEART / D(10**6) * PRICE_OCT4)
m["corpus_artifact_usd_today"] = str(CP_AHEART / D(10**6) * PRICE)
m["true_over_corpus_ratio"] = str(CP / (CP_AHEART / D(10**6)))

# ratios
m["cost_to_proceeds_ratio_solo"] = str(D(m["solo_quorum_stake_heart_usd_spot"]) / (CP * PRICE))
m["net_ev_solo_usd"] = str(CP * PRICE - D(m["solo_quorum_stake_heart_usd_spot"]))
m["net_ev_deposit_path_usd"] = str(CP * PRICE - MIN_DEP * PRICE)

out["model"] = m

with open(os.path.join(OUT, "model.json"), "w") as f:
    json.dump(out, f, indent=1)

md = f"""# C2-30 Humans — capture cost model (humans_1089-1)

Measured at height **{st['height']}** ({st['time']}), price ${PRICE} (CG/DL 2026-10-09), ETH ${ETH:.2f}.

| Item | Value |
|---|---|
| Bonded | {B:,.2f} HEART (${B*PRICE:,.2f}) |
| Not bonded | {NB:,.2f} HEART |
| Supply | {SUP:,.2f} HEART |
| Community pool (accounting) | {CP} HEART = **${CP*PRICE:.10f}** |
| CP cross-check (2nd LCD) | {CP2_AHEART/D(10**18)} HEART |
| Distribution module balance | {DIST:,.2f} HEART (unclaimed rewards+commission all-validator sum: {REWARDS_ALL:,.2f} HEART; ratio {REWARDS_ALL/DIST:.6f}) |
| Gov module / fee_collector / mint / transfer | 0 |
| Gov params | quorum 33.4% / threshold 50% / veto 33.4% / min-deposit {MIN_DEP} HEART / {VOTING_DAYS}-day vote |
| Top-2 validator share | {top2*100:.2f}% (Alchemist {shares[0][1]*100:.2f}% + Meria {shares[1][1]*100:.2f}%) |
| Top-4 validator share | {top4*100:.2f}% |

## Capture paths (with own-stake-in-denominator correction)

| Path | HEART needed | USD at spot | Note |
|---|---:|---:|---|
| Solo quorum (all others abstain) | {D(m['solo_quorum_stake_heart']):,.2f} | ${D(m['solo_quorum_stake_heart_usd_spot']):,.2f} | S = q/(1-q)·B |
| Outvote top-2 if they vote No | {D(m['outvote_top2_no_heart']):,.2f} | ${D(m['outvote_top2_no_heart_usd_spot']):,.2f} | S > N |
| Outvote top-4 if they vote No | {D(m['outvote_top4_no_heart']):,.2f} | ${D(m['outvote_top4_no_heart_usd_spot']):,.2f} | {D(m['outvote_top4_no_heart'])/SUP*100:.1f}% of total supply |
| Deposit-only (validators auto-Yes) | {MIN_DEP:,} (refundable) | ${MIN_DEP*PRICE:.2f} | historical props: 2/2 passed near-unanimous Yes |

## Float / depth
- On-chain HEART buyable (drain both pools): **{onchain_buyable_heart:,.2f} HEART** = {onchain_buyable_heart/D(m['solo_quorum_stake_heart'])*100:.2f}% of the solo-quorum need
  (Osmosis pool 1493: {osmo_pool_heart:,.2f} HEART vs ${osmo_pool_usdc:,.2f} USDC; Ethereum UniV2: {eth_heart:,.2f} HEART vs {eth_weth:.4f} WETH)
- Exit liquidity (sell side of all venues): ≈ **${exit_usd:,.2f}** (Osmosis ${osmo_pool_usdc:,.2f} + ETH WETH ${eth_weth*ETH:,.2f} + Gate bids ${gate_bid:,.2f})
- Gate visible ask depth (50 lvls): ${gate_ask:,.2f}; KuCoin book unavailable (API), 24h vol ~$3k.

## Proceeds
- CP spend cap (SDK v0.46.11 `DistributeFromFeePool` = feePool.CommunityPool accounting): **{CP} HEART = ${CP*PRICE:.10f}**
- Gov module balance: {GOVBAL}
- Directly gov-movable total: **${CP*PRICE + GOVBAL*PRICE:.10f}**
- Latent via malicious software upgrade (P, needs validator adoption): {DIST+NBPOOL+esc_all:,.2f} HEART (${(DIST+NBPOOL+esc_all)*PRICE:,.2f}); incl. bonded pool {DIST+NBPOOL+esc_all+B:,.2f} HEART (${(DIST+NBPOOL+esc_all+B)*PRICE:,.2f})

## Corpus correction
- The campaign's "CP $50.7k" = CP misread with 6 decimals: {CP_AHEART/D(10**6):,.2f} HEART × ${PRICE_OCT5} (2026-10-05) = **${CP_AHEART/D(10**6)*PRICE_OCT5:,.2f}** — matches $50.7k.
- True CP = 10^12 × smaller: ${CP*PRICE:.10f}.

## Verdict
All capture paths are negative-EV by ~${D(m['solo_quorum_stake_heart_usd_spot']):,.0f}+ (solo) against a ${CP*PRICE:.10f} prize; on-chain float covers only {onchain_buyable_heart/D(m['solo_quorum_stake_heart'])*100:.1f}% of the minimum stake needed. **Uneconomic — confirmed, with the CP figure corrected to dust.**
"""
with open(os.path.join(OUT, "model.md"), "w") as f:
    f.write(md)
print(md)

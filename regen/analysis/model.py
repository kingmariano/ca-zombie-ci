#!/usr/bin/env python3
"""C2-27 Regen governance-capture cost model.

Inputs are live on-chain reads recorded in analysis/raw/ (block heights in
README) plus market prices at query time. Formulas follow cosmos-sdk v0.53.6
x/gov/keeper/tally.go (vendored in analysis/raw/sdk_tally.go):
  - quorum:  (yes+abstain+no+veto) / bonded_at_tally  >= 0.40
  - veto:    veto / (yes+abstain+no+veto) > 0.334  -> fail + burn deposit
  - pass:    yes / (yes+abstain+no) > 0.50
An attacker's own stake is bonded, so it inflates the quorum denominator.
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)

# ---------------- verified inputs (see analysis/raw/*, README citations) ----------------
B = 80_957_442.153681          # bonded REGEN (staking pool, 2026-10-09)
SUPPLY = 239_826_669.588209    # uregen total supply
CP = 3_672_761.593494          # protocolpool community pool REGEN
NCT = 44_331.178755            # eco.uC.NCT supply == basket backing (credits)
Q = 0.40                       # quorum
THRESH = 0.50
VETO = 0.334
VOTING_DAYS = 7
UNBONDING_DAYS = 21
MIN_DEPOSIT = 2_000.0          # REGEN
INITIAL_DEPOSIT = 200.0        # 10% of min_deposit

PRICES = {
    "regen_finding_2026_10_04": 0.0008052,   # CoinGecko daily close, finding date
    "regen_2026_10_09_cg": 0.00189101,       # CoinGecko
    "regen_2026_10_09_dl": 0.0024345,        # DefiLlama (early UTC)
    "regen_2026_10_09_cg_pm": 0.00188211,    # CoinGecko (CI snapshot)
    "nct_2026_10_09": 0.2301044095248986,    # DefiLlama
}

# validator blocs (bonded tokens, 2026-10-09)
VAL = {
    "ecoBridge.earth": 16_864_585_721_529, "Regenerator": 10_663_750_995_425,
    "polkachu.com": 9_153_912_782_612, "Earthist": 7_661_104_001_897,
    "Vitwit": 7_305_714_401_496, "KalpaTech": 7_138_625_487_634,
    "0base.vc": 6_712_442_675_296, "Chainflow": 5_988_309_006_293,
    "ECO Stake": 5_314_564_606_290, "Alex": 2_521_142_396_643,
    "MekongLabs": 1_633_290_078_566,
}
VAL = {k: v / 1e6 for k, v in VAL.items()}
TOP2 = sum(sorted(VAL.values(), reverse=True)[:2])

# float depth (public DEX pools; GeckoTerminal + Osmosis LCD, 2026-10-09)
OSMOSIS_GAMM = 1_371_941.29   # sum of REGEN in 50 gamm pools
OSMOSIS_CL = 52_535.0         # 568.11 + 51,966.86 (2 live CL pools)
BASE_REG = 2_220_000.0        # ~$4.2k side of $8.4k Base pools / $0.00188
CELO_REG = 900_000.0          # ~$1.7k side of $3.4k Celo pools / $0.00188
DEX_FLOAT = OSMOSIS_GAMM + OSMOSIS_CL + BASE_REG + CELO_REG
VOL24 = 3_359.0               # CoinGecko total 24h volume

# counterpart (non-REGEN) liquidity in those pools, USD — the sellable side
COUNTERPART = 1_900.0 + 30.0 + 4_179.58 + 1_687.28   # gamm est + CL + Base + Celo

# realization of a CP-spend payout (3.67M REGEN) dumped across the float:
# proportional split of sell orders gives out ~= C_total * f/(1+f), f = X/R_total
def dump_value(x_regen, r_total, c_total):
    f = x_regen / r_total
    return c_total * f / (1 + f)

TOUCAN_CHAINS = {"Polygon": 325_904.94, "Celo": 159_791.24, "Base": 34_735.34, "Regen": 29_363.14}
IBC_VALUE = 12_472.36 + 116.31 + 5.7 + 6.4 + 89.5 + 1.7 + 10.0 + 2.1 + 1.0 + 1.0 + 0.7  # USDC ch48+gravity, OSMO, ATOM, DAI, AKT, PHOTON, QREGEN, dust

X_self = B * Q / (1 - Q)                     # attacker must reach 40% of bonded incl. own stake
def usd(x, p): return x * p

# realization of a CP-spend payout dumped across the float
dump_single = dump_value(CP, DEX_FLOAT, COUNTERPART)

# marginal top-up if validators deliver V yes votes
def marginal(V_yes): return max(0.0, (Q * B - V_yes) / (1 - Q))
X_marg_28 = marginal(28_516_969.272713)      # prop 80/81 turnout level (quorum miss)
X_marg_35 = marginal(35_040_733.456333)      # prop 75 turnout level (pass)

veto_frac_top2 = TOP2 / (X_self + TOP2)      # if top-2 bloc vetoes the self-sufficient attacker

model = {
    "chain": "regen-1",
    "inputs": {
        "bonded_regen": B, "supply_regen": SUPPLY, "community_pool_regen": CP,
        "nct_supply": NCT, "quorum": Q, "threshold": THRESH, "veto_threshold": VETO,
        "voting_period_days": VOTING_DAYS, "unbonding_days": UNBONDING_DAYS,
        "min_deposit_regen": MIN_DEPOSIT, "initial_deposit_regen": INITIAL_DEPOSIT,
        "prices": PRICES,
    },
    "cost_self_sufficient": {
        "stake_regen": X_self,
        "usd_at_finding_price": usd(X_self, PRICES["regen_finding_2026_10_04"]),
        "usd_at_cg_price": usd(X_self, PRICES["regen_2026_10_09_cg"]),
        "usd_at_dl_price": usd(X_self, PRICES["regen_2026_10_09_dl"]),
        "finding_naive_qxb_usd": usd(B * Q, PRICES["regen_finding_2026_10_04"]),
        "correction": "finding used q*B (32.38M REGEN) instead of q/(1-q)*B (53.97M); own stake is in the quorum denominator",
    },
    "cost_marginal": {
        "topup_if_validators_28_5M_yes_regen": X_marg_28,
        "topup_usd_cg": usd(X_marg_28, PRICES["regen_2026_10_09_cg"]),
        "topup_if_validators_35M_yes_regen": X_marg_35,
        "topup_usd_cg_35M": usd(X_marg_35, PRICES["regen_2026_10_09_cg"]),
        "deposit_only_usd": usd(INITIAL_DEPOSIT, PRICES["regen_2026_10_09_cg"]),
    },
    "float_depth": {
        "osmosis_gamm_regen": OSMOSIS_GAMM, "osmosis_cl_regen": OSMOSIS_CL,
        "base_regen_est": BASE_REG, "celo_regen_est": CELO_REG,
        "total_dex_regen_est": DEX_FLOAT,
        "total_dex_usd_est": usd(DEX_FLOAT, PRICES["regen_2026_10_09_cg"]),
        "volume_24h_usd": VOL24,
        "self_sufficient_stake_as_pct_of_dex_float": 100 * X_self / DEX_FLOAT,
    },
    "veto": {
        "top2_bloc_regen": TOP2,
        "top2_share_of_bonded_pct": 100 * TOP2 / B,
        "top2_veto_share_vs_self_sufficient_attacker_pct": 100 * veto_frac_top2,
        "top2_can_veto_self_sufficient": veto_frac_top2 > VETO,
    },
    "proceeds": {
        "community_pool_regen": CP,
        "community_pool_usd_cg": usd(CP, PRICES["regen_2026_10_09_cg"]),
        "community_pool_usd_dl": usd(CP, PRICES["regen_2026_10_09_dl"]),
        "community_pool_realizable_single_shot_usd": dump_single,
        "community_pool_realization_note": "proportional-split dump of the full CP payout across all REGEN DEX pools: out = C_total*f/(1+f), f=X/R_total",
        "nct_basket_usd": usd(NCT, PRICES["nct_2026_10_09"]),
        "toucan_chain_tvls_usd": TOUCAN_CHAINS,
        "toucan_total_usd": sum(TOUCAN_CHAINS.values()),
        "ibc_on_regen_usd_est": IBC_VALUE,
        "upgrade_leg_nominal_usd": usd(SUPPLY, PRICES["regen_2026_10_09_cg"]) + usd(NCT, PRICES["nct_2026_10_09"]) + IBC_VALUE,
        "upgrade_leg_caveat": "requires 2/3+ validator adoption of a malicious binary; validators are the same bloc that can veto; realizable value bounded by ~$8.5k DEX float",
    },
    "verdict": {
        "self_sufficient_ev_usd_cg": usd(CP, PRICES["regen_2026_10_09_cg"]) - usd(X_self, PRICES["regen_2026_10_09_cg"]),
        "self_sufficient_multiple": usd(X_self, PRICES["regen_2026_10_09_cg"]) / usd(CP, PRICES["regen_2026_10_09_cg"]),
        "finding_asset_claim_usd": 547_100,
        "resolved_asset": "Toucan Protocol global TVL across Polygon/Celo/Base/Regen (~$549.8k today); Regen gov controls none of the Polygon/Celo/Base contracts",
    },
}
json.dump(model, open(os.path.join(OUT, "model.json"), "w"), indent=2)

md = f"""# C2-27 Regen capture — cost model (computed {model['chain']})

## Cost to pass alone (attacker stake counts in the quorum denominator)
- required stake = q/(1-q) * bonded = **{X_self:,.2f} REGEN**
- USD: ${usd(X_self, PRICES['regen_finding_2026_10_04']):,.0f} at finding-date price ($0.0008052) |
  ${usd(X_self, PRICES['regen_2026_10_09_cg']):,.0f} at current CG price | ${usd(X_self, PRICES['regen_2026_10_09_dl']):,.0f} at DL price
- finding's number ({usd(B*Q, PRICES['regen_finding_2026_10_04']):,.0f} USD) used q*B = {B*Q:,.0f} REGEN and the pre-pump price; corrected formula + current price => ~{usd(X_self, PRICES['regen_2026_10_09_cg'])/1000:,.0f}k

## Float depth (can the stake even be bought?)
- total public DEX REGEN ~= {DEX_FLOAT:,.0f} REGEN (~${usd(DEX_FLOAT, PRICES['regen_2026_10_09_cg']):,.0f}) across Osmosis ({OSMOSIS_GAMM+OSMOSIS_CL:,.0f}), Base (~{BASE_REG:,.0f}), Celo (~{CELO_REG:,.0f})
- required stake is **{100*X_self/DEX_FLOAT:,.0f}% of the entire public float**; 24h volume ${VOL24:,.0f}
- => self-sufficient capture is not market-fillable at any price; requires OTC accumulation from large holders

## Marginal scenarios (validator turnout)
- if validators deliver ~28.5M yes (recent reject level): attacker top-up {X_marg_28:,.2f} REGEN (${usd(X_marg_28, PRICES['regen_2026_10_09_cg']):,.0f})
- if validators deliver ~35M yes (recent pass level): top-up 0; cost is the {INITIAL_DEPOSIT:,.0f}-REGEN initial deposit (~${usd(INITIAL_DEPOSIT, PRICES['regen_2026_10_09_cg']):,.2f})
- veto: top-2 validators = {100*TOP2/B:.1f}% of bonded; vs a self-sufficient attacker their veto share = {100*veto_frac_top2:.1f}% > 33.4% -> can kill (deposit burned)

## Proceeds
- community pool (protocolpool): **{CP:,.2f} REGEN = ${usd(CP, PRICES['regen_2026_10_09_cg']):,.2f}** (CG) / ${usd(CP, PRICES['regen_2026_10_09_dl']):,.2f} (DL) — spendable via /cosmos.protocolpool.v1.MsgCommunityPoolSpend (precedent: props #63/#77/#78)
- realizable single-shot if dumped across the DEX float: **${dump_single:,.2f}** (nominal ${usd(CP, PRICES['regen_2026_10_09_cg']):,.0f})
- NCT basket: {NCT:,.2f} NCT = ${usd(NCT, PRICES['nct_2026_10_09']):,.2f} — holder-owned; no gov message moves it (MsgTake signer=owner; curator can only change fees)
- Toucan "$547.1k": = {TOUCAN_CHAINS} = **${sum(TOUCAN_CHAINS.values()):,.0f}** global TVL; Regen-side ${TOUCAN_CHAINS['Regen']:,.0f}; Polygon/Celo/Base bridge contracts are operator-EOA-controlled, NOT Regen gov
- malicious-upgrade leg: nominal ${model['proceeds']['upgrade_leg_nominal_usd']:,.0f}, validator-adoption gated; realizable << nominal

## Verdict
- self-sufficient capture EV = ${model['verdict']['self_sufficient_ev_usd_cg']:,.0f} (cost is {model['verdict']['self_sufficient_multiple']:.1f}x proceeds)
- capital-based capture: **negative EV**; finding's "$25.9k" and "$547.1k" both corrected
- live residual: zero-capital CP-spend proposal (~${usd(INITIAL_DEPOSIT, PRICES['regen_2026_10_09_cg']):,.2f} deposit) against {CP:,.0f} REGEN pool, conditional on validators voting yes (they did: #77 self-addressed spend passed 53.6M-0)
"""
open(os.path.join(OUT, "model.md"), "w").write(md)
print(md)

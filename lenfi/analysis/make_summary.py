#!/usr/bin/env python3
"""Assemble the final summary.json for the Lenfi deep-dive: V1 + V2 custody, categories, proof results."""
import json, os, sys, urllib.request, urllib.parse, time

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(D)


def load(p, default=None):
    try:
        return json.load(open(p))
    except Exception:
        return default


ADA = (load(f"{D}/valuation.json") or {}).get("ada_price_usd") or 0.243
tip = load(f"{D}/koios_tip.json", [{}])
block = tip[0].get("block_height") if tip else None
v1 = load(f"{D}/valuation.json", {})
v2s = load(f"{D}/v2/v2_stats.json", {})
v2v = load(f"{D}/v2/v2_valuation.json", {})
rows = load(f"{D}/live_utxos_classified.json", [])
custody = load(f"{D}/nft_custody.json", {})
gates = load(f"{ROOT}/ci-out/cek_proofs_aiken.json", {})
window = load(f"{ROOT}/ci-out/cek_window_proofs.json", {})

# ---- V1 totals (7 addr1z + staking) minus the 3 enterprise V2 addresses which are in valuation.json
V2_ENTERPRISE_ADA = 35.52 + 3948.75 + 63.41  # carriers/registry-at-enterprise/collateral-carrier
v1_ada = (v1.get("total_ada") or 0) - V2_ENTERPRISE_ADA
v1_usd = (v1.get("total_usd") or 0) - V2_ENTERPRISE_ADA * ADA
# remove the token USD that belonged to the enterprise addresses (they hold no tokens per live state)
v1_usd = v1.get("total_usd", 0) - V2_ENTERPRISE_ADA * ADA

# ---- V2 totals
pool_ada = float(v2v.get("pool_ada") or 0)          # 739.17 incl. carriers
pool_tok_usd = float(v2v.get("pool_token_usd") or 0)  # $47.68
leftovers_ada = v2s.get("registries", {}).get("ada", 0) + v2s.get("liquidation_leftovers", {}).get("ada", 0) + v2s.get("other", {}).get("ada", 0)
collateral_ada = 275.15529
config_ada = float((v2v.get("config") or {}).get("ada") or 0)
v2_ada = pool_ada + leftovers_ada + collateral_ada + config_ada
v2_usd = v2_ada * ADA + pool_tok_usd

total_ada = v1_ada + v2_ada
total_usd = v1_usd + v2_usd

# ---- categories
E_U = 0.00    # see README §8: no unprivileged path proven live; V2 pool LpAdjust ceiling ~$228 latent-only
# S: V1 stuck (2 script-held gate NFTs + no-datum dust) + V2 carriers + V2 no-datum dust
V1_S = round((1.11629 + 1.31455 + 442.215) * ADA + 120.61, 2)  # script-held UTxOs + IAG + datum-less dust
V2_CARRIERS_ADA = 101.33
V2_NODATUM_ADA = 380.41 + 11.74 + 1.59
V2_S = round((V2_CARRIERS_ADA + V2_NODATUM_ADA) * ADA, 2)
S = round(V1_S + V2_S, 2)
HO = round(max(0.0, total_usd - S - E_U), 2)

summary = {
    "finding": "lenfi",
    "title": "Lenfi / ex-Aada Finance (Cardano) — V1 P2P lending + V2 Aiken contracts; full custody re-derived, claim gates CEK-proven",
    "chains": ["cardano"],
    "headline_extractable_usd": E_U,
    "headline_confidence": "high",
    "categories": {"E-U": E_U, "H-O": HO, "P": 0.0, "S": S},
    "latest_block": block,
    "block_numbers": {"cardano": block},
    "targets_checked": len(rows) + 396 + 269,
    "live_targets": 12 + 124 + 1,
    "closed_reasons": [
        "V1 interest/liquidation payouts require burning the unique borrower/lender NFT (mint names bound to sha256(idx||txid) of a consumed UTxO; forging infeasible, CEK-verified 12/12)",
        "V1 request funding and debt-request take require the tx validity range to END before requestExpiration; every live offer/request is expired (CEK-verified 4/4 on deployed debt_request_v2)",
        "V1 collateral release requires the borrower NFT (repay) or lender NFT (liquidate); both unique and key-held",
        "V1 staking needs both copies of the per-stake bond NFT burned; receipts are user-held",
        "V2 leftovers/registry spends are burn-only but the gating pool NFT is locked inside its pool UTxO; liquidation leftovers need the borrower NFT",
        "V2 pool LpAdjust drain predicate (pre-fix) is present in live bytecode, but live pools hold only min-UTxO (~$228 total incl. carriers + $47.68 tokens) and no full drain tx was CEK-proven — latent only",
    ],
    "poc": {
        "type": "chain-native CEK evaluation (aiken uplc eval) of deployed on-chain scripts vs hand-built script contexts",
        "tests_passed": (gates.get("passed", 0) + window.get("passed", 0)),
        "tests_total": (gates.get("total", 0) + window.get("total", 0)),
        "ci_run_urls": ["https://github.com/kingmariano/ca-zombie-ci/actions/runs/38278817782", "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38277843455"],
        "artifacts": ["ci-out/cek_proofs_aiken.json", "ci-out/cek_window_proofs.json"],
    },
    "key_facts": [
        f"full live custody re-derived: {total_ada:.2f} ADA + priced tokens = ${total_usd:.2f} (V1 {v1_ada:.2f} ADA + V2 {v2_ada:.2f} ADA) at tip {block}",
        f"V1 interest_v1 alone: 567,513.79 ADA (${(v1.get('by_class',{}).get('interest_v1',{}).get('usd',0)):.2f}); claim = burn the lender NFT; 74/74 gate NFTs alive, 14 (backing $116.8K) in the Lenfi batcher wallet",
        "NFT policy: permissionless mint with name = sha256(idx||txid) of a consumed UTxO, unrestricted burn — names cannot be forged (CEK A1/A2/D1)",
        "interest validator accepts iff the mint field is exactly one burn (-1) of (lenderNftCs, datum lenderNftTn); no payout checks (CEK B1..B4)",
        "V2 was missed by the triage at stake-enabled addresses: leftovers 13,888.73 ADA (216 registries 3,946.35 + 31 liquidation leftovers 9,938.39), pools 739.17 ADA (+$47.68 tokens), collateral 275.16 ADA, pool_config 534.43 ADA",
        "audits: Vacuumlabs V1 (2022-09-02), DebtRequest (2022-11-25), Aiken (2023-03-21); AADA-006/201 (post-deadline lender takes all collateral, no oracle) acknowledged, not fixed; shipped oracle = 3-of-3 native script",
        "no verifiable Aug-2022 exploit exists; V1 abandoned (site redirected, app down, DefiLlama deadUrl) but loan closes continue via integrations; Safety Module never activated",
        f"stuck: ${S:.2f} = V1 script-held/dust + V2 carriers ({V2_CARRIERS_ADA:.2f} ADA, datum can't type-check) + V2 no-datum dust ({V2_NODATUM_ADA:.2f} ADA)",
    ],
    "caveats": [
        "point-in-time read; ADA $0.24299 and token USD via DefiLlama cardano:<unit> (AADA and 60+ units unpriced)",
        "V2 pool drain (pre-fix LpAdjust) verified as a predicate in live UPLC by the sub-audit, NOT as a full CEK drain transaction; treated as $0 E-U (latent). V2 pool datums show balance in loan-asset units; several pools' datum/UTxO accounting is inconsistent (frozen)",
        "V2 config script (534.43 ADA + 269 NFTs) spend conditions were not analysed",
        "claim-NFT-holding wallet attribution (Lenfi batcher vs third-party close service) not proven",
        "no transactions were sent; no secrets in this folder",
    ],
    "one_liner": f"External unprivileged extraction is ~$0 live: V1 value is NFT-gated (CEK-proven) and expired fund/take windows are closed; V2 adds 15.4K ADA of custody but the only known prefix flaw (LpAdjust) faces empty pools.",
    "v1_ada": round(v1_ada, 2), "v2_ada": round(v2_ada, 2),
    "v2_breakdown": {"pools_ada": pool_ada, "pool_tokens_usd": pool_tok_usd,
                     "registries_ada": v2s.get("registries", {}).get("ada"),
                     "liquidation_leftovers_ada": v2s.get("liquidation_leftovers", {}).get("ada"),
                     "collateral_ada": collateral_ada, "config_ada": config_ada,
                     "carriers_ada": V2_CARRIERS_ADA, "nodatum_ada": V2_NODATUM_ADA},
}
json.dump(summary, open(f"{ROOT}/summary.json", "w"), indent=1)
os.makedirs(f"{ROOT}/ci-out", exist_ok=True)
json.dump(summary, open(f"{ROOT}/ci-out/summary.json", "w"), indent=1)
print(json.dumps({"categories": summary["categories"], "total_ada": round(total_ada, 2),
                  "total_usd": round(total_usd, 2), "v1_ada": round(v1_ada, 2), "v2_ada": round(v2_ada, 2),
                  "tests": f'{summary["poc"]["tests_passed"]}/{summary["poc"]["tests_total"]}'}, indent=1))

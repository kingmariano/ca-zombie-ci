#!/usr/bin/env python3
"""Build summary.json for the L-2 triage-C deliverable."""
import json, os, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "ci-out", "results.json")))
rows = res["rows"]

STATUS = {}
for r in rows:
    STATUS[r["slug"]] = r["status"]

counts = {"live_funded": 0, "drained": 0, "unreachable": 0, "already_covered": 0}
for r in rows:
    if r["status"] == "LIVE-FUNDED":
        counts["live_funded"] += 1
    elif r["status"] == "DRAINED":
        counts["drained"] += 1
    elif r["status"] == "UNREACHABLE":
        counts["unreachable"] += 1

total = sum((r.get("live_usd") or 0) for r in rows)

# Phase-2 shortlist: funded rows, ranked by live $; reason per row (curated)
SHORTLIST = [
    ("taiga-acala", "Acala module account holds 99,381 DOT + 1,039,284 LDOT (LDOT unpriced by DefiLlama; ~$1.28M at DOT parity) — live, permissionless-read custody, unexplored control surface"),
    ("jediswap-v1", "Abandoned Cairo AMM; 1,051 pair contracts still hold live reserves; no audits; sync/burn paths unexplored"),
    ("ergodex", "285 unspent boxes at the P2S contract hold ~632K ERG + tokens; eUTxO validator logic unexplored"),
    ("armada", "Solana CLP vault program with 24 vaults + ~$352K in vault token accounts; whirlpool position layer not fully measured"),
    ("hliquity", "Liquity fork on Hedera with 2.28M HBAR in activePool; trove/liquidation logic unexplored"),
    ("lenfi", "Cardano v1+v2 Plutus scripts hold 586K ADA + tokens; UTxO script validation unexplored"),
    ("jet-v1", "Shut-down Solana lending program still holds ~$156K in 21k token accounts; withdraw/repay paths unexplored"),
    ("omm", "ICON lending pool holds ~$150K cash (USDC/USDS) with $52K borrows; 2023 exploit history"),
    ("01", "Solana perps vault still holds ~$112K (USDC); close/withdraw paths unexplored"),
    ("fountain-protocol", "Oasis Compound fork still holds ~$93K cash across 3 comptrollers; 'mint is paused' states present"),
    ("caviarnine-lsu-pool", "Radix LSU pool component holds ~$38K of LSUs (82 resources); redemption path live"),
    ("margined-protocol", "Osmosis+Neutron vaults hold ~$12K (TIA/ATOM/OSMO/stOSMO); sunset derivatives"),
    ("dojoswap-amm", "Injective factory with 900+ pairs; live reserves mostly test/CW20 tokens — verify pricing before Phase-2"),
    ("10kswap", "Starknet AMM factory with 15 pairs; live reserves present (value pending final run)"),
    ("bluemove-dex", "Sui AMM pools with live reserves (value pending final run)"),
    ("hashmix-fil", "Filecoin pool holds ~1.6K FIL (~$1.7K); residual staking claims"),
]

short = []
for slug, reason in SHORTLIST:
    r = next((x for x in rows if x["slug"] == slug), None)
    if not r:
        continue
    short.append({"slug": slug, "protocol": r["protocol"], "chain": r["chain"],
                  "live_usd": r.get("live_usd"), "status": r["status"], "reason": reason})

out = {
    "triage": "L-2 Phase-1 — Triage-C (non-EVM custody screen)",
    "generated_at_utc": res.get("generated_at_utc"),
    "ci_run_urls": [
        "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38127724782 (final, all fixes)",
        "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38125777999 (first full run, pre-fix)",
    ],
    "rows_total": len(rows),
    "counts": counts,
    "total_live_usd": round(total, 2),
    "rows": [
        {
            "slug": r["slug"], "protocol": r["protocol"], "chain": r["chain"],
            "status": r["status"], "live_usd": r.get("live_usd"), "confidence": r["confidence"],
            "custody": r.get("custody"), "notes": r.get("notes"),
            "unpriced_tokens": r.get("unpriced_tokens"),
        }
        for r in sorted(rows, key=lambda x: -(x.get("live_usd") or 0))
    ],
    "phase2_shortlist": short,
    "caveats": [
        "All reads are point-in-time at the latest block/height of the CI run (2026-10-11).",
        "USD = DefiLlama coins-API prices at scan time; native/LSD amounts scaled with on-chain decimals.",
        "LDOT (taiga-acala) and a handful of LSD/IBC tokens have no direct price feed and are valued via proxies (noted per row).",
        "Unreachable rows: protocol API/indexer and/or the chain's public RPC surface were dead at scan time; last-known values are months old and were NOT carried forward.",
        "No vulnerability analysis, no transactions, no keyed RPC URLs persisted.",
    ],
}
with open(os.path.join(ROOT, "summary.json"), "w") as f:
    json.dump(out, f, indent=2)
print(json.dumps({k: out[k] for k in ("counts", "total_live_usd")}, indent=2))
print("shortlist:", len(short))

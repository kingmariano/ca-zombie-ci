#!/usr/bin/env python3
"""Generate l2-triage-b/summary.json from analysis/final_table.json + ci-out/results.json."""
import json, os, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = json.load(open(os.path.join(ROOT, "analysis/final_table.json")))
res = json.load(open(os.path.join(ROOT, "ci-out/results.json")))
meta = json.load(open(os.path.join(ROOT, "analysis/llama_meta.json")))

funded = [r for r in rows if r["status"].startswith("LIVE")]
drained = [r for r in rows if r["status"].startswith("DRAINED")]
unreach = [r for r in rows if r["status"].startswith("UNREACHABLE")]
live_total = round(sum(r["onchain_usd"] for r in funded), 2)

blocks = {}
for r in rows:
    for ch, b in (r.get("blocks") or {}).items():
        if b:
            blocks[ch] = max(blocks.get(ch, 0), b)

summary = {
    "finding": "L-2 (Triage-B: alt-EVMs / L2s)",
    "title": "Phase-1 custody screen of 29 alt-EVM/L2 zombie rows",
    "chains": sorted({c for r in rows for c in r["chains"]}),
    "rows_total": len(rows),
    "status_counts": {
        "LIVE-FUNDED": len(funded),
        "DRAINED_$0": len(drained),
        "UNREACHABLE": len(unreach),
        "ALREADY-COVERED": 0,
    },
    "ci_runs": {
        "full_screen": "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38131461859",
        "deep_pass_all_pairs": "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38134363405",
    },
    "live_total_usd": live_total,
    "headline_confidence": "medium-high (direct on-chain reads at pinned blocks; DefiLlama prices for token USD)",
    "block_numbers": blocks,
    "phase2_shortlist": [
        {"rank": i, "protocol": r["name"], "slug": r["slug"], "chains": r["chains"],
         "live_usd": r["onchain_usd"], "status": r["status"]}
        for i, r in enumerate(funded, 1)
    ],
    "key_facts": [
        "All 29 rows screened by direct on-chain reads of the custody contracts defined by current DefiLlama registries/adapters (keyless public RPCs, read-only).",
        "Every row classified LIVE-FUNDED (>=$1k on-chain), DRAINED (<$1k), or UNREACHABLE (chain/indexer dead).",
        "DefiLlama 'current' TVL matches on-chain reads for most fresh rows; material overstatements found for rows whose adapters are frozen/carried-forward (see per-row notes).",
    ],
    "caveats": [
        "USD values use DefiLlama token prices; illiquid/obscure tokens may be unpriced or mispriced (e.g. Pala's internal oracle differs from market).",
        "Custody-screen only: no vulnerability analysis, no exploitability assessment.",
        "LP tokens are valued pro-rata at pair reserves; staking-contract LP deposits double-count liquidity that is already in pools when summed naively.",
    ],
    "one_liner": f"{len(funded)} of {len(rows)} rows remain live-funded on-chain (~${live_total:,.0f}); {len(drained)} drained; {len(unreach)} unreachable.",
}
json.dump(summary, open(os.path.join(ROOT, "summary.json"), "w"), indent=1)
print(json.dumps(summary, indent=1)[:1500])

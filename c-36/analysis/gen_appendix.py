#!/usr/bin/env python3
"""Generate the compact 295-row markdown appendix from final_table.json + parent overrides."""
import json

BASE = "/home/heisenberg/CA/c-36/analysis"
rows = json.load(open(f"{BASE}/final_table.json"))

# parent overrides (verified independently)
OVERRIDES = {
    "0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e": {
        "classification": "H-O",
        "claim_model": "Per-sub-account withdraw via operate(); bulk is holder-only. Prior deep-dive found one unprivileged path: liquidation/vaporize spread on open debt, <=$16-18.",
        "notes": "parent override: child E marked S (0 ETH on contract) but the value is WETH/USDC/DAI sub-account balances ($6.7M) - holder-only; prior E-U <=$16-18.",
    },
    "0xdd9fd6b6f8f7ea932997992bbe67eabb3e316f3c": {
        "classification": "S",
        "claim_model": "P3D-style player vaults; prior verdict: self-scoped payouts + probabilistic airdrop <=0.29 ETH negative EV.",
        "notes": "child E found no working claim path; prior treated as self-service. Either way $0 E-U. Parent keeps S per live test, notes ambiguity.",
    },
    "0xa2f987a546d4cd1c607ee8141276876c26b72bdf": {
        "classification": "H-O",
        "claim_model": "bETH redeem 1:1 for stETH; vault holds 745.47 stETH vs 1,013.43 bETH supply (73.6% coverage / 26.4% shortfall, first-mover race). Index-mapped 232.83 ETH subset is fully covered.",
        "notes": "parent reconciliation of seg-D/seg-E: no ETH-mainnet DEX market for bETH (no V2/V3 pair) -> not E-U; holder race only.",
    },
    "0x6090a6e47849629b7245dfa1ca21d94cd15878ef": {
        "classification": "S",
        "claim_model": "Old registrar: bids escrowed in per-bid Deed child contracts; registrar itself empty; deed owners release via releaseDeed (holder-only).",
        "notes": "parent: the 8,983.98 ETH-equiv mapped lives in Deed children (not enumerated); not E-U.",
    },
}
for r in rows:
    o = OVERRIDES.get(r["address"].lower())
    if o:
        r.update(o)

# counts
from collections import Counter, defaultdict
cnt = Counter(); eth = defaultdict(float)
for r in rows:
    cnt[r["classification"]] += 1
    eth[r["classification"]] += r["live_eth"] or 0
print("FINAL COUNTS:", dict(cnt))
print("LIVE ETH BY CLASS:", {k: round(v,1) for k,v in eth.items()})

# markdown appendix sorted by live_eth desc
lines = ["| # | Contract | Name | Live ETH | Mapped | Class | Reason |", "|---:|---|---|---:|---:|---|---|"]
for i, r in enumerate(sorted(rows, key=lambda x: -(x["live_eth"] or 0)), 1):
    reason = (r.get("claim_model") or r.get("notes") or "").replace("|", "/").replace("\n", " ")
    if r.get("eu_candidate"):
        reason = "E-U CANDIDATE: " + json.dumps(r["eu_candidate"])[:160]
    lines.append(f"| {i} | `{r['address']}` | {str(r.get('name') or '')[:32]} | {r['live_eth'] or 0:.4f} | {r['mapped'] or 0:.2f} | {r['classification']} | {reason[:150]} |")
open(f"{BASE}/appendix_table.md", "w").write("\n".join(lines) + "\n")
print("wrote appendix_table.md rows:", len(rows))
# unreviewed check
un = [r for r in rows if r["classification"] == "UNREVIEWED"]
print("UNREVIEWED:", len(un), [r["address"] for r in un][:10])

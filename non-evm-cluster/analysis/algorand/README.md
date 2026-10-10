# Algorand — C2-55 non-EVM cluster (child-algorand)

Read-only assessments of legacy custody on Algorand (no transactions sent, keyless endpoints only).

| Protocol | Report | Headline (round ~65.85M, 2026-10-10) |
|---|---|---|
| **Folks Finance** | `folks/REPORT.md` | E-U $0 proven (stale-oracle liquidation candidate unquantified); H-O ≈ **$558.1k** (v1 pools $45.2k + govDist14 $508.4k + v2 staking $4.5k) + live xALGO/v2; S ≈ **$65.0k** (v1 surplus $45.6k + govDist4-6 $19.5k); P = Folks reserve key unpause/admin. |
| **Pact (AMM)** | `pact/REPORT.md` | E-U $0 direct (live MEV weakness: min-out args discarded in SWAP/ADDLIQ/REMLIQ); H-O = **$924,558.95** total LP-recoverable ($495,982.49 deprecated classic + $428,576.46 v201); P = admin/manager keys; S = none found. |

Layout: `folks/{REPORT.md, raw/, scripts/}`, `pact/{REPORT.md, raw/, scripts/}`, shared `scripts/algo_lib.py`.
Raw dumps carry explicit rounds; every headline number in the reports is backed by app id + escrow address + raw amount + round.
Blockers: algod dryrun disabled on public nodes (404); heavy enumerations left as CI candidates.

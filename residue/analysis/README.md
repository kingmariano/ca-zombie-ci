# H2-03 analysis index

| Folder | Contents |
|---|---|
| `nimiq/` | Polygon Nimiq HTLC handlers: live-state dumps (`polygon_state_95284024.json`, `live_state_95284982.json`), full event logs (`logs/*.json.gz` — Open/Redeem/Refund + all Approval events to both handlers), verified contract sources (`sources/`, incl. the Feb-2023 prototype), OpenGSN RelayHub/StakeManager sources + ABIs (`opengsn/`) |
| `base-sibling/` | Base vault sibling `0x416Ec2cA…` re-verification (`findings.md`) + verified proxy source |
| `cozy/` | Cozy Finance v2 Sets (Optimism) child-subagent deliverable: `findings.md`, `evidence.json`, `sources.md`, raw state dumps |
| `bsc-trio/` | SKYDAO / FIST / MSN (BSC) child-subagent deliverable: `findings.md`, `evidence.json`, `sources.md`, `raw/` (some gzipped), `logs/` |

Top-level scripts (keyless or env-keyed only; no secrets stored):

- `scan_polygon_nimiq.py` — balances/allowances/code scan (public RPC).
- `enumerate_nimiq.py` — Open/Redeem/Refund event enumeration (Etherscan V2, key from env).
- `enumerate_approvals.py` — all Approval events granting allowance to either handler.
- `process_nimiq.py` — Multicall3 live-state processor (allowance+balance per owner, `htlcs`/`deposits`).
- `ci/run.sh` — selects an archive-capable Polygon RPC for the CI tests (redacted output).

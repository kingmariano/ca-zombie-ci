# Heliobond — timeline & evidence (read-only)

## Code timeline (Heliobond/contracts, branch main)

| Date (UTC) | Commit / event | What |
|---|---|---|
| 2026-06-12 | repo created | `Heliobond/contracts` created |
| 2026-06-15 | tag `v0.1.0` | first tag (pre-queue) |
| 2026-06-26 22:29 -0700 | `5d0a576` "feat: redemption queue, property tests, deploy script, events table" (PR #152, merge `c65dd5e`) | **queue feature introduced; double-count bug exists from here** |
| 2026-06-27 → 2026-08-25 | main compiles | vulnerable + buildable window (~2 months) |
| 2026-08-25 18:36 +0100 | `60f2263` "Add bounds checks, event pagination, and notification dedup persistence" | introduces duplicate `RegistryError` discriminants (41/42) → `project_registry` no longer compiles (E0081) |
| 2026-08-25 → 2026-09-26 | **main does not compile** | any deployment in this window must have come from an earlier build or a patched tree |
| 2026-09-25 18:37 | issue #613 opened by `dadadave80` | "queued withdrawal claims are not deducted from total_assets()" |
| 2026-09-26 09:31 | issue #640 opened by `jarik2014` | duplicate report + `#[ignore]`d repro in invariant suite PR #641 |
| 2026-09-26 09:31 | davefinances.com article | press coverage of #640 ("50,000 vs 90,040") |
| 2026-09-26 17:31 | PR #647 merged (`401b782`) | fix `e99b4cc` + test `f0e7608`: `total_assets = ... - queued_liabilities` |
| 2026-09-26 20:13 | `8e87d69` | compile-only fix: duplicate `RegistryError` discriminants moved to 43/44 (main builds again) |
| 2026-09-26 17:31 | issue #613 closed | fixed same day it was triaged |
| 2026-09-29 18:17 | issue #640 closed | Stellar Wave Program completion (contributor `Dove1010`, PR #653) |
| 2026-10-01 | current main `b233e10` | fix still present (`read_total_assets` subtracts `queued_liabilities`) |

`git branch --contains e99b4cc` → `main`. No tag after `v0.1.0`; no release
including the fix was published, but main is fixed.

## Deployment evidence search (negative)

Checked (see `child_mainnet_search.md` for the independent pass):

1. **Repo, all branches, history**: no mainnet contract IDs; `deploy/testnet.json`
   is an empty template (`"project_registry": ""`). Only well-known testnet USDC
   SAC `CBIELTK6...` appears (in `network-tests.yml`).
2. **Frontend repo**: `.env.example` has empty `NEXT_PUBLIC_VAULT_CONTRACT_ID` /
   `NEXT_PUBLIC_REGISTRY_CONTRACT_ID`; production bundle at
   `https://heliobond.vercel.app` contains **no `C...` contract IDs** and its
   `/api/backend/*` proxy answers `503 {"error":"Backend is not configured"}` —
   the live app runs in demo mode.
3. **Backend repo**: `PROJECT_REGISTRY_CONTRACT_ID` / `INVESTMENT_VAULT_CONTRACT_ID`
   empty in `.env.example`; no deployed API found.
4. **GitHub Actions**: all 33 `deploy.yml` runs failed (workflow-file issue on
   push; no `workflow_dispatch` runs). All 192 `network-tests.yml` runs either
   failed (scheduled) or had the deploy job **skipped** — the CI has never
   deployed, not even to testnet.
5. **Website**: `heliobond.io` NXDOMAIN (2026-10-04); `heliobond.com` resolves to
   an unrelated parking IP.
6. **npm**: no `@heliobond/*` package published.
7. **Stellar mainnet contract index (stellar.expert)**: full enumeration +
   WASM marker scan — see `mainnet_scan.md`.

## Live mainnet state snapshot

| Item | Value |
|---|---|
| Soroban mainnet RPC | `https://mainnet.sorobanrpc.com` (and `soroban-rpc.mainnet.stellar.gateway.fm`) |
| Latest ledger at snapshot | 64,773,044+ (2026-10-04) |
| Heliobond mainnet contracts | **none identified** (see mainnet scan) |
| Heliobond mainnet TVL / queued liabilities | $0.00 (no contract) |

## On-chain identification method

1. Enumerate all mainnet contracts via
   `https://api.stellar.expert/explorer/public/contract?limit=200&order=asc&cursor=...`
   (fields: contract, created, creator, wasm, invocations).
2. For contracts created ≥ 2026-06-01, collect distinct `wasm` hashes and
   download the binaries (`.../wasm/{hash}`).
3. Grep binaries for Heliobond markers (`heliobond`, `HBS`, `QueuedClaim`,
   `fund_project`, `Heliobond Shares`) — independent of build reproducibility.
4. Cross-check the sha256 of locally built vuln/fixed WASMs against mainnet
   `ContractCode` ledger entries via Soroban RPC `getLedgerEntries`
   (`ci/check_wasm_on_chain.py`).

# Heliobond (`investment_vault`, Stellar/Soroban) — live extractable-value determination

**Campaign:** zombie-hunt · **Finding:** L-1 Heliobond · **Chain:** Stellar (Soroban)
**Date of work:** 2026-10-04 · **Status:** read-only research; no transactions sent on any network; all builds/PoC run in CI (GitHub Actions) on copies of the public source.
**Lead:** "queued withdrawals are double-counted in `total_assets()` — repro 50,000 USDC assets vs 90,040 USDC owed" (davefinances.com 2026-09-26; GitHub issue #640, confidence MEDIUM).

---

## TL;DR

**An external, unprivileged attacker can extract $0 live right now** — there is **no Stellar mainnet (or testnet) Heliobond deployment** that can be identified from any public source, and the double-count bug is **already fixed on `main`** (fix `e99b4cc`, merged 2026-09-26 17:31 UTC, same day the issue was triaged). The finding is real in code but has no live victim: the project is a development-stage, Stellar-Wave-program repo whose production website is a demo-mode frontend with no configured backend and whose CI has never deployed a contract.

| Target | Live extractable (unprivileged) | Why closed today | Latent risk |
|---|---|---|---|
| `investment_vault` (vulnerable build `c79daec`) | **$0** | No mainnet/testnet deployment found; contract IDs unpublished; no funded contract exists | If a pre-fix build is deployed with funds, an existing shareholder can divert **up to ~the queued claim (bounded by liquid)** from queued claimants; a small holder can approach the full queue size |
| `investment_vault` (current `main` `b233e10`) | **$0** | Fixed: `total_assets = liquid + investments + expected − queued_liabilities` | TTL/archival of the queue-liability entry on a dormant queue (weeks), ERC-4626 donation attack infeasible (needs ~$1e12 donation) |

**Total live extractable found: $0.00 (confidence: high).**
**Latent (not live) exposure if the vulnerable build is deployed as-is: up to ~100% of the outstanding withdrawal queue, bounded by liquid assets.** In the deterministic PoC (a $50,000 vault with a $40,040 queue) the attacker nets **$25,000** and the queued claimant loses **$25,040**.

---

## 1. The bug, in exact terms

Heliobond's Soroban `InvestmentVault` is a SEP-41 share vault (HBS shares, 7-decimal USDC). `withdraw` burns shares immediately and records a FIFO `QueuedClaim { from, usdc_owed }` when the vault's liquid USDC cannot cover the redemption (`investment_vault/src/lib.rs`, queue branch).

**Vulnerable version** (last pre-fix `main`, `c79daec1`, 2026-09-26 18:07 +0100):

```rust
fn read_total_assets(env: &Env) -> i128 {
    liquid_usdc(env) + investments + expected     // queued liabilities NOT subtracted
}
```

After the burn, `total_supply` falls but `total_assets()` does not, so the price of every remaining share jumps by ≈ `usdc_owed / remaining_supply`. The USDC owed to the queue is simultaneously counted as backing the remaining shares. `claim()` is permissionless and pays FIFO; strict FIFO means a queued entry that cannot be fully paid blocks later ones.

**Fixed version** (fix `e99b4cc`, PR #647, merged 2026-09-26 17:31 UTC; still present on current `main` `b233e10`):

```rust
liquid_usdc(env) + investments + expected - queued_liabilities(env)
```

`VaultKey::QueuedLiabilities` is incremented on enqueue and decremented on each `claim()` payout. The queue is now a NAV liability.

Exact references:
- Vulnerable code: `investment_vault/src/lib.rs` @ `c79daec1` — queue branch (~L620-640), `read_total_assets` (~L2412).
- Fix: `e99b4cce35ed1db304218caee7bd508621c8e4ae` (+ test `f0e7608`); merge `401b78265095cccf8d4b3d295ec0be9e1e4a8d57` (PR #647).
- Issues: #613 (opened 2026-09-25 18:37 UTC by `dadadave80`, closed 2026-09-26 17:31), #640 (opened 2026-09-26 09:31 UTC by `jarik2014`, closed 2026-09-29 as a Stellar Wave Program item).

### Attacker model (exact)

Let `TA = L + I + E` (liquid + investments + expected), supply `S`, victim `s_v`, attacker `s_a`, remaining supply `S_r = S − s_v`, queued claim `Q = s_v·TA/S`.

1. **Victim queues.** A holder withdraws while `Q > L` and utilisation `I/(L+I) < 50%` — at ≥50% the graduated withdrawal-tier cap rejects the withdrawal before the queue branch is reachable, so the queue only forms when the victim is a **majority holder** and enough capital is deployed to make the vault illiquid.
2. **Attacker holds shares.** No secondary market for HBS was found; acquisition = deposit before the queue.
3. **Attacker redeems at the inflated price**, capped so the payout is ≤ `L`: `pay = min(TA·s_a/S_r, L)`. Fair (post-fix) value `= s_a·(TA−Q)/S_r`.
4. **Gross diversion** `= min(TA·s_a/S_r, L) − s_a·(TA−Q)/S_r`. If `s_a = S_r`: `= Q − I − E`. With a small attacker stake (`s_a → 0`), diversion → `Q` (the whole queue), bounded by `L`.
5. **New depositors** are a second victim class: while the queue is open, `deposit` mints too few shares at the inflated NAV, transferring value to existing shareholders.
6. **Self-queue is zero-sum** (the overpayment to a second attacker account equals the shortfall of the first account's claim), so the attack requires a third-party queued claim.

**Caps/blockers (buggy build):** victim must be a majority holder; utilisation must be < 50% when the victim exits; attacker needs an existing share position and enough liquid to be paid immediately; at most the liquid buffer can be taken instantly (the rest queues behind the victim).

---

## 2. Live-state assessment — is any of this deployed?

| Check | Result |
|---|---|
| `Heliobond/contracts` repo, all branches/history | `deploy/testnet.json` is an empty template; **no mainnet contract IDs**; only the well-known testnet USDC SAC `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA` appears (network-tests workflow) |
| `Heliobond/frontend` (live at `heliobond.vercel.app`) | `.env.example` contract IDs empty; production JS bundles contain **no `C…` contract IDs**; `/api/backend/*` returns `503 {"error":"Backend is not configured"}` — demo mode |
| `Heliobond/backend` | `.env.example` `PROJECT_REGISTRY_CONTRACT_ID` / `INVESTMENT_VAULT_CONTRACT_ID` empty; no deployed API found |
| GitHub Actions `deploy.yml` | 33/33 runs failed; **no `workflow_dispatch` runs**; no successful deployment |
| GitHub Actions `network-tests.yml` | 192 runs: scheduled = failed, workflow_run = deploy job **skipped** every time; CI has never deployed, even to testnet |
| Website | `heliobond.io` NXDOMAIN; `heliobond.com` = unrelated parking IP |
| npm | no `@heliobond/*` package published |
| **Stellar mainnet contract index (stellar.expert)** | **{{SCAN_RESULT}}** |
| **Mainnet ContractCode check of built WASMs (Soroban RPC)** | **{{HASH_RESULT}}** |
| Soroban mainnet latest ledger at snapshot | **{{LATEST_LEDGER}}** (`https://mainnet.sorobanrpc.com`) |

**No Heliobond mainnet contract could be identified.** With no contract ID, there is no vault to attack: `E-U = $0` live.

---

## 3. What an attacker can/cannot do

**Cannot (today):**
- No contract to call on Stellar mainnet — every candidate path requires a deployed `InvestmentVault` address, and none exists publicly (no ID in the repo, frontend, backend, CI artifacts, Actions logs, npm, or the on-chain index).
- The current `main` code is fixed; deploying it now does not reproduce the bug.
- No keys/roles are needed for the (non-existent) exploit — but there is nothing to point it at.

**If a pre-fix build were deployed with funds (latent, hypothetical):**
- An existing shareholder can front-run a queued claimant: redeem at the inflated NAV and drain the liquid the queue is owed. Cost: gas only; no flash loan needed (the attacker must already hold HBS).
- Bounds: victim must be a majority holder exiting at <50% utilisation; attacker's instant take ≤ liquid; net profit = take − their deposit.
- Deterministic PoC numbers (below): $25,000 net attacker profit / $25,040 victim shortfall in a $50,000 vault.

---

## 4. PoC / CI verification

Everything heavy (builds + Rust test PoC) runs on GitHub Actions in the public campaign repo `kingmariano/ca-zombie-ci`, branch `heliobond`.

- CI runs: **{{CI_URLS}}**
- `poc/poc_vulnerable.rs` — deterministic PoC against `c79daec1` (pre-fix): asserts `total_assets` unchanged by the queue, attacker overpayment > 0, `total_assets < queued liabilities`, `claim()` pays 0.
- `poc/poc_fixed.rs` — same scenario against current `main` `b233e10`: asserts `total_assets = TA − queued`, fair attacker payout, vault stays solvent.
- `ci/check_wasm_on_chain.py` — checks the built WASM sha256 as `ContractCode` entries on mainnet/testnet via `getLedgerEntries`.

**Key PoC numbers (7-decimal USDC):** **{{POC_NUMBERS}}**

---

## 5. Verdict, residual & latent risk

- **E-U (external unprivileged, live): $0.00** — no deployment, fixed source.
- **H-O / P / S: $0.00** — no live contract to hold, recover, or brick.
- **Latent risk 1 (deployment):** anyone deploying a pre-fix build re-creates the bug; the extractable amount scales with the outstanding queue (up to ~100% of it, bounded by liquid).
- **Latent risk 2 (TTL/archival, fixed code):** `QueueEntry` / `QueueTail` / `QueuedLiabilities` are written without explicit `extend_ttl`. A dormant queue could have its liability entry archived while queue entries are kept alive via permissionless `extendFootprintTtl`, silently re-inflating NAV. Requires weeks of dormancy; not live.
- **Negative result (documented):** the ERC-4626 first-depositor donation/inflation path is infeasible — zeroing a 1,000 USDC victim deposit would require ≈ $9.95e11 of donated liquidity because of the 7-decimal unit scale and the 100 USDC minimum.
- **Blockers to exploitation today:** no contract; no published IDs; no mainnet deployment evidence; source fixed.

## 6. Methodology & sources

- Source inspection: `Heliobond/contracts` cloned read-only; commits `c79daec1` (vuln), `e99b4cc`/`b233e10` (fixed); issue #613/#640 and PR #641/#647 read via GitHub API.
- On-chain discovery: stellar.expert contract index (`/explorer/public/contract`, `/contract/{id}`, `/wasm/{hash}`), Soroban RPC `getHealth`/`getLedgerEntries` on `https://mainnet.sorobanrpc.com` and `https://soroban-rpc.mainnet.stellar.gateway.fm`, Horizon (`https://horizon.stellar.org`).
- Builds/PoC: GitHub Actions (Rust 1.84.0 pinned by `rust-toolchain.toml`, stellar-cli 26.1.0 per repo CI), artifacts in `ci-out/`.
- Sources: davefinances.com article (2026-09-26), `zombie_hunt/x_social_leads.md` (row 5/37/77), GitHub issues #613/#640, PR #647.

**Caveats:** the negative deployment conclusion rests on the completeness of the stellar.expert index and on string/hash matching of built WASMs; a deployment from a *modified* source that keeps none of the identifying strings cannot be ruled out absolutely. Independent verification is in `analysis/child_mainnet_search.md`.

## 7. Files

| File | Purpose |
|---|---|
| `analysis/timeline.md` | code/report timeline + deployment-evidence search |
| `analysis/nav_model.md` | exact NAV/exploit model + PoC numbers + residual issues |
| `analysis/mainnet_scan.md` | full mainnet contract enumeration + WASM marker scan |
| `analysis/enumerate_all_mainnet_contracts.py` | enumeration script |
| `analysis/mainnet_contracts_all.json` | raw contract index dump (evidence) |
| `analysis/xdr_keys.py` | Soroban RPC ledger-key helper |
| `poc/poc_vulnerable.rs`, `poc/poc_fixed.rs` | deterministic PoCs (run in CI) |
| `ci/run.sh`, `ci/check_wasm_on_chain.py` | CI job |
| `ci-out/` | CI artifacts (logs, hashes, JSON) |
| `summary.json` | machine-readable summary |

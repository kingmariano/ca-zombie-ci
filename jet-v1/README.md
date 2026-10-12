# Jet V1 (Solana) — L2 Phase-2 deep dive: how much can an external unprivileged attacker extract?

**Date:** 2026-10-12 · **Chain:** Solana mainnet-beta · **Status:** read-only; the exploit PoC was executed **only** in an in-process LiteSVM against cloned mainnet state and the sha256-verified live program ELF; **no transactions were signed or sent to any real network**.

**Triage row** (`l2-triage-c/summary.json`): Jet V1 — LIVE-FUNDED, **$156,438.12**, custody `7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8` (21,194 token accounts). This report re-verifies live state and determines what is actually extractable by an outsider.

---

## 1. TL;DR

| Target | Live extractable (external unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|
| Jet v1 market `9oiXzad28vLhT2TkFoVRRRcwYKrSF7E3XPUJpwcarCAo` — 4 reserve vaults: USDC `63AEVgB…` **16,246.540570**; SOL `DvM98WW…` **1,274.172220813**; solBTC `5xMkyca…` 4.956563; solETH `FPwT6PEY…` 1.357014 | **≈ $0.06** (one dust liquidation; effectively zero) | The obvious drain path — buy dead-bridge solBTC/solETH cheap, post as collateral at the **frozen 2024 oracle prices**, borrow the whole vault, default — is **blocked**: the deployed program's `borrow` handler panics unconditionally (hard-disabled since the 2022-11-10 upgrade). No other instruction moves vault funds to an outsider without burning deposit notes. | **Severe latent:** any future upgrade that re-enables `borrow` (or adds a sweep) makes ≈ **$155–168K instantly drainable by anyone** for ~$200–$30K cost; the frozen oracles are still live and still accepted by `refresh_reserve`. |
| Deposit-note holders' redeemable vault cash | up to **$155,720** (Jupiter v3 prices) / $157,285 (DefiLlama) — **H-O** | `withdraw`/`withdrawTokens` work (proven on-chain 2026-09-27), but notes are per-user and first-come-first-served; note claims exceed vault cash | Withdrawal race; unclaimed/lost-key notes are not recovered |
| Upgrade authority `6Mi9fKyqpFhtBJnjy3Ym3MmQZqGZAGFQNCYvp5NPsyt` | same funds — **P** (alternate control, not additive) | program is upgradeable; the authority can deploy code that sweeps every program account | key custody unknown (team wound down Dec 2023; Jan/Feb 2024 Squads-multisig txs touch the ProgramData) |

**Total live extractable by an external unprivileged attacker today: ≈ $0.06** (confidence **high** on the mechanics; the number is cents-level and an existing third-party bot races for it).

**Value change since triage:** none. Vault raw balances are byte-identical to triage (USDC 16,246,540,570 raw; SOL 1,274,172,220,813 lamports; solBTC 4,956,563; solETH 1,357,014 at finalized slot **456,115,416**). The USD difference ($156,438 at triage prices → $155,720/$157,285 today) is price noise only.

---

## 2. What Jet v1 actually is (verified deployed reality)

* Program `JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU` (Jet Protocol v1 lending, Anchor-based; on-chain IDL v0.2.0, 24 instructions — extracted from the program's own IDL accounts `6vMStqkJ…`/`CjqQ9kx9…`; identical instruction list to the public v0.2.0 IDL snapshot).
* **Upgradeable** (BPFLoaderUpgradeable), ProgramData `45X4uzRnRvZoiG6X5ho6V8FJUU7HVxDApuyoL8mwgiP9`; internal **last-deploy slot 160,301,534 = 2022-11-10 12:43:29 UTC**; upgrade authority `6Mi9fKyqpFhtBJnjy3Ym3MmQZqGZAGFQNCYvp5NPsyt` (on-curve; that account currently holds 0 lamports). Deployed ELF sha256 `2ccc9a0e28a50d50ae85ca25ecf7a783847d0fd11891e626e7be5d90c09dc352` (hash of the account the PoC executed).
* One market `9oiXzad28vLhT2TkFoVRRRcwYKrSF7E3XPUJpwcarCAo`; **market authority = `7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8`** (off-curve PDA — the triage's "custody" account). It owns **21,194 SPL token accounts**: the 4 reserve vaults, ~21k per-user deposit/collateral PDA accounts (deposit notes), zeroed fee vaults/DEX swap accounts, plus one 300-unit dust account. None of the 21,194 accounts has a delegate or close authority; all are initialized (state=1) — no third-party token-account takeover path.
* Market flags = **0** (not halted: deposits/withdrawals/repays/liquidations enabled). Market owner `CkkWJtdPoq22CVdfWBhV5vo9MXNVaPXJAjrVmsRpYGC1` (off-curve PDA; can only set flags/owner).
* **7,289 Obligation accounts**; USDC quote; 4 reserves:

| idx | token | mint | vault | vault balance | oracle price (frozen) | real price (2026-10-12) | outstanding debt |
|---|---|---|---|---|---|---|---|
| 0 | USDC | `EPjFWdd5…` | `63AEVgBicvYeaEwoTr8tkURPnszuB2H1pMBUoNnUPjTN` | 16,246.540570 | $1.00 | $0.9997 | 42,566.56 |
| 1 | wrapped SOL | `So1111…112` | `DvM98WWqFFAeCQi1QJbFREkHetRREqiymHBfaPckdHR3` | 1,274.172220813 | $119.23378 | $108.94 | 81.50 SOL |
| 2 | **solBTC** (dead Sollet bridge token) | `9n4nbM75…` | `5xMkycaRErjMYYJYktpVvXb72EC4bpF2GTNpmsnaGgz` | 4.956563 | **$52,326.91** | **$54.62** | 0.0383 |
| 3 | **solETH** (dead Sollet bridge token) | `2FPyTwcZ…` | `FPwT6PEYNJvN2i9Pnz4rD9xS72fgStRdNGXq1kSVGeMH` | 1.357014 | **$2,304.09** | **$296.50** | 0.0461 |

Vault total: **$155,720** real (Jupiter v3 prices) / $157,285 (DefiLlama) / $430,659 at the frozen oracle prices.

---

## 3. The mechanism (what the triage row really represents)

Jet v1 is a 2021-era lending market whose deposits were never fully withdrawn after the protocol shut down (Jet Protocol Holdings LLC, Dec 2023). The four Pyth **legacy price feeds the program trusts are frozen**:

| feed | aggregate last-publish slot | date | value | real market now |
|---|---|---|---|---|
| USDC | 286,560,277 | 2024-08-29 | $1.00 | $1.00 |
| solBTC | 286,561,788 | 2024-08-29 | $52,326.91 | **$54.62** |
| solETH | 286,561,779 | 2024-08-29 | $2,304.09 | **$296.50** |
| SOL | 299,058,484 | 2024-11-02 | $119.23378 | $108.94 |

`refresh_reserve` (permissionless) checks only `price >= 0` and the confidence band vs. twap — **it never checks publish time or feed status** — so the protocol keeps "refreshing" 2024 prices (most recently by a third-party keeper bot on 2026-09-27, slot 451,021,492).

This is the classic drainable-lending-market setup: **solBTC is oracle-valued at 958× its real value and solETH at 7.8×**. If `borrow` worked, an outsider could buy ~4.02 solBTC (~$220) or ~91.2 solETH (~$30K), deposit as collateral, and borrow the entire USDC + SOL vaults (oracle debt value $168,163; required collateral $210,204 at the 1.25 min collateral ratio), then default — **net ≈ $126–155K**. That attack was built and executed in the PoC. It fails at the last step: see §4.

### 3.1 The gate that closes it: `borrow` is hard-disabled in the deployed program

* The deployed ELF has no borrow-handler body (e.g. the "Requested a debt that would exceed…" string is gone as dead code) but retains the panic `Location` `src/instructions/borrow.rs:110:5` in rodata.
* Mirror repo `judithjr/jet-v1`, branch `no-borrows`, commit `66991f4c8f14` "**disable borrows**" (2022-11-10 05:19:06 UTC) inserts `panic!("disabled");` as the **first statement of the borrow handler** (exact diff: `programs/jet/src/instructions/borrow.rs` +2 lines) — and the on-chain upgrade is dated the same day 7 hours later (ProgramData slot 160,301,534 = 2022-11-10 12:43:29 UTC).
* LiteSVM execution against the sha256-verified deployed ELF (see §6) shows **15/15 borrow variants panic** at exactly `borrow.rs:110:5`, for amount 0/1/full-vault, both reserves, with and without `refresh_reserve`, market read-only or writable. **The vaults are unchanged after every attempt.**

So the $156K is real but unreachable through `borrow` since November 2022 — before the protocol entity even shut down.

---

## 4. What an attacker can and cannot do today (path-by-path)

**Cannot (each verified):**

| Path | Gate |
|---|---|
| `borrow` the vaults against overpriced solBTC/solETH collateral | Hard-disabled — unconditional `panic!` (PoC: 15/15 blocked) |
| `withdraw`/`withdrawTokens` someone else's deposits | Requires the depositor signer; the note balance is burned from that depositor's PDA account (observed live in the 2026-09-27 bot tx) |
| `withdrawCollateral` / `close*` against other users' accounts | Owner signer + PDA seeds bind accounts to the caller |
| `updateReserveConfig`, `setMarketFlags`, `setMarketOwner`, `initReserve` | Market/owner gated (owner is an off-curve PDA; owner-signed only) |
| Upgrade the program | Only `6Mi9fKyq…` (P category) |
| `liquidate_dex` (Serum) as a novel drain | Bounded by the same repay→seize rule; needs live Serum markets (dead) and the reserves' Serum open-orders; no vault-drain leg |
| Steal via token-account delegate/close authority | None of the 21,194 custody accounts has a delegate or close authority |

**Can (the only residual E-U):** sweep the small set of obligations that are *oracle-unhealthy* with **real-value-positive** collateral:

* 26 obligations are unhealthy under the frozen oracle prices (total $7,269.66 oracle debt vs $4,233.31 oracle collateral). Their exact program-formula liquidation "bonus" universe is only **$22.61 oracle-USD** — and because the seizable collateral is mostly solBTC/solETH (oracle-overvalued ~8–958×), the real-terms PnL of executing those liquidations is **≈ +$0.06 total**.
* One candidate: obligation `7c6HkPMpv92MaMTHpHXHa9CxJnHmdXzAmnNqz4bfL2jo` (solBTC debt → USDC collateral) — estimated real PnL $0.0575.
* A Kamino-integrated keeper bot (`C3MPbLBQbREEJ56ku8SNHrHMh5q3iYKUkAYFQdvmcWP8`) has been sweeping this dust (e.g. 2026-09-27 14:17 UTC, slot 451,021,492, sig `fs5LWcW35JcxnVFcrmrTC37VJeUUKrjNRzQiPkBDcsv9czq4VGXMHE6gjd8aoXkhmArMcdvBkE4K1aNVaHqvMti`: flash-borrow from Kamino → 4× refreshReserve → liquidate → withdraw/withdrawTokens, net +$0.30 USDC). No Jet activity after 2026-09-27.

**Costs:** liquidations are net of a few 5,000-lamport tx fees; the dust candidate is worth cents, so any rational attacker nets ≈ $0 (the bot's edge is automation at scale).

---

## 5. Where the $156K actually is (category split, non-additive)

* **E-U (external unprivileged): $0.06** — dust liquidation only.
* **H-O (holder-only): $155,720** — deposit-note holders can redeem vault cash. `withdraw` burns their notes and pays from the vault (works: market flags=0, caches refreshable permissionlessly, compliance with the v0.2.0 `withdrawTokens`/`withdraw` paths observed live). Claims exceed cash (e.g. USDC notes 51.26M raw claim ≈ 58.9k USDC vs 16.25k USDC cash), so recovery is a **first-come-first-served race**; whatever is unclaimed (lost keys) stays.
* **P: $155,720 (alternate control)** — the upgrade authority can deploy a sweep instruction. Same funds as H-O; not additive.
* **S: $0** — nothing is structurally unreachable in-program: vault cash is reachable by note holders; outstanding debts are repayable by their owners (`repay` enabled).
* **Bad-debt overhang (informational):** note-holders' claims on the ~$51k (real) of outstanding loans are contingent on 2021–2022 borrowers choosing to repay; in real terms the loan book is ~23% collateralized (mostly solBTC-collateralized debt). This is the protocol's solvency hole, not attacker profit.

---

## 6. PoC / verification

**LiteSVM runner** (`poc-svm/`; Rust; GitHub Actions; public CI):

1. Loads the **deployed ELF** (`analysis/jet_program.so`, sha256 `2ccc9a0e…c352`, fetched from ProgramData `45X4uz…`) and 21 cloned mainnet accounts (`analysis/accounts.json`, dump slot **456,071,544**) into an in-process LiteSVM. No RPC at run time; nothing sent to any chain.
2. Executes the full pre-disable attack as an unprivileged fabricated attacker (`2ibkSmTR…`, funded 10 SOL, fabricated 100 solETH token account):
   * `refresh_reserve` ×3 reserves (iterative; ~15 days of accrual → 2–3 calls each), `init_obligation`, `init_deposit_account`, `deposit(91.24 solETH)`, `init_collateral_account`, `deposit_collateral(91,076,163 notes)`, `init_loan_account` ×2 — **14/14 setup steps succeed** (the attacker genuinely books ≈ $210k of oracle-priced collateral on live state).
   * `borrow(USDC/SOL)` — **15/15 variants panic** at `src/instructions/borrow.rs:110:5` → `ProgramFailedToComplete`. Vault balances after: USDC 16,246,540,570 / SOL 1,274,172,220,813 raw — **unchanged**.
3. Result: `status = blocked_borrow_disabled`. Results: `ci-out/poc_results.json`, `ci-out/poc_log.txt`.
4. CI: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38273270502** (success, 2026-10-12; artifacts uploaded). Earlier run: 38272670757 (success).
5. PDA seeds were cross-verified against live data (1,200 obligations / 2,132 positions re-derived), and account metas against the on-chain IDL v0.2.0 / published `jet-proto-v1-cpi`.

**On-chain evidence used** (all at stated slots, read-only):
* Vault balances: `getTokenAccountBalance` at finalized slot 456,115,416 (identical to triage).
* Market/Reserve parse: market `9oiXz…` (flags=0, authority `7gpj9…`), reserves & configs; oracle prices from the market cache last refreshed at slot 451,021,492.
* Pyth feeds: 4 legacy price accounts (`Gnt27xtC…`, `H6ARHf6Y…`, `GVXRSBjF…`, `JBu1AL4o…`), last-publish slots 286.56M/299.06M (2024-08/2024-11).
* ProgramData: internal last-deploy slot 160,301,534; upgrade authority `6Mi9fKyq…`; ELF sha256 match.
* IDL accounts: `3u4ha5y…`, `6HgqgVk…` (v0.0.0), `6vMStqkJ…`, `CjqQ9kx9…` (v0.2.0, zlib JSON).
* Obligation census: all 7,289 accounts (`analysis/obligations_full.json`, `obligations_summary.md`).
* Activity census: 1,000 signatures 2026-07-07…2026-09-27 (`analysis/activity_census.*`) — only keeper bots; no non-bot borrow/deposit activity.

---

## 7. Verdict, blockers, residual risk

**Verdict:** The triage's $156,438 is real and still on-chain, but **not extractable by an external unprivileged attacker** (E-U ≈ $0.06). The program's borrow path has been hard-disabled since 2022-11-10; the remaining value is deposit-note holders' collateral (H-O) with an upgrade-authority override (P). Confidence: **high** (ELF-level execution + hash match + commit archaeology + live reads agree).

**Blockers that would change the verdict:**
1. **Upgrade risk (main blocker):** the program remains upgradeable by `6Mi9fKyq…` (0-lamport key; 2024 Squads-multisig ops touched the ProgramData). A single upgrade re-enabling `borrow` — or adding any sweep/withdraw-fees instruction — turns the frozen-oracle market into an instant ~$155–168K drain for ~$200–$30K cost, reproducible with the PoC's pre-disable path (all setup steps already pass).
2. **Deposits remain open:** anyone can still deposit into the frozen-oracle reserves; new depositors' cash joins the redemption race (and would be instantly drainable if borrows return).
3. **Frozen feeds remain accepted:** `refresh_reserve` still accepts 2024 prices; any new Jet-style market using these legacy feeds inherits the flaw.
4. **Cents-level dust liquidations** remain (real PnL ≈ $0.06), raced by an active bot.

---

## 8. Methodology & sources; caveats; files

**Methodology:** public RPC only (`api.mainnet-beta.solana.com`, `solana-rpc.publicnode.com`; no keyed endpoints — the local Alchemy key was over its monthly cap and was not used). State at explicit finalized slots; deployed ELF fetched, hashed, and executed in LiteSVM; instruction semantics audited against Jet v0.2.0 sources and the on-chain IDL; obligation economics computed with both the on-chain (frozen) and real-market price sets. Read-only throughout; nothing signed or sent on-chain.

**Caveats:**
* The deployed binary (Nov 2022) post-dates the public Dec-2021 source used for layout/semantics reading; account layouts, sizes, the on-chain IDL, and the PoC execution are consistent, but some instruction bodies were only exercised where noted (deposit/collateral/borrow in LiteSVM; liquidate/withdraw/withdrawTokens observed live).
* "Real" prices for solBTC/solETH are thin-market DEX prices (Jupiter v3 liquidity: solBTC ≈ $0.5k — essentially unsellable at scale; solETH ≈ $46k) — indicative, and they *reduce* E-U, they never increase it.
* H-O recovery is first-come-first-served and assumes depositors still hold their keys; lost-key notes will stay unclaimed.
* The 2024 Squads-multisig transactions touching the ProgramData were not fully decoded (Squads v3 outer program); they did not change the deploy slot.

**Files:**
* `README.md` (this report) · `summary.json` (machine-readable)
* `analysis/`: `final_state_snapshot.json` (all final reads), `accounts.json` + `dump_accounts.py` (cloned PoC accounts, slot 456,071,544), `jet_program.so` + ELF hash, `jet_idl_v020.json` / `jet_idl_onchain_020.json` (deployed IDL), `parse_jet_accounts.py`, `enum_token_accounts.py` (21,194-account enum), `obligations_full.json` / `obligations_summary.json` / `.md` (7,289-obligation census), `activity_census.json` / `.md`, `live_prices.json`, `REPORT.md` (census narrative + correction banner)
* `poc-svm/`: Rust LiteSVM PoC (`src/main.rs`, `README.md`)
* `ci-out/`: `poc_results.json`, `poc_log.txt` (run outcome) · `ci-log.txt` + `ci-artifacts/` (CI logs/artifacts) · CI run: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38273270502

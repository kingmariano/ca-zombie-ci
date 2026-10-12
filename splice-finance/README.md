# Splice Finance (Blast + Mode) — L2 Phase-2 deep-dive

**Date:** 2026-10-12 · **Chains:** Blast (81457), Mode (34443) · **Finding:** L2 watchlist Phase-2, rank 3 (triage: $484,392.71 live, Pendle-style SY claims)
**Status:** read-only research; **no transactions were signed or sent to any live chain**; all extraction attempts were executed only as read-only `eth_call` simulations and on a local/CI fork. No secrets in this folder.

---

## 1. TL;DR

| Target | Live value (re-verified) | Extractable by unprivileged attacker (E-U) | Why closed / open | Latent risk |
|---|---|---|---|---|
| Blast — SY-hUSDB claim (Hyper USDB vault) | **$341,646.73** (341,148.65 USDB) | **$0** | Standard Pendle-V2 SY ↔ OZ ERC4626; value only redeemable by SY holders (markets' LPs, YT contract's PY claimants, user wallets) | Owner EOA can pause SY transfers (P); Blast shutdown Oct 26 |
| Blast — SY-hWETH claim (Hyper WETH vault) | **$101,954.72** (40.2146 WETH) | **$0** | same | same |
| Blast — SY-sWETH claim (Splice sWETH vault) | **$6,393.53** (2.5218 WETH) | **$0** | standard ERC4626 (unverified, selector-identical); owner EOA can only config Blast points | owner EOA (P) |
| Blast — SY-sUSDB claim (Splice sUSDB vault) | **$2,853.14** (2,848.99 USDB) | **$0** | same | owner EOA (P) |
| Blast — SY-wUSDB claim (Wasabi wUSDB vault) | $14,359.12 **book** | **$0** | Vault **drained 2026-04-30**; holds 0 USDB; redemption reverts | S / P-recovery only |
| Mode — 16 markets (ezETH, weETH, wrsETH, MODE, USDe, sUSDe) | **$24,091.29** | **$0** | SYs hold the exact underlying 1:1; redeemable only by holders | Blast-style owner powers (P) |
| **TOTAL live (re-verified)** | **$491,300.24** | **$0.00** | | |
| — of which **holder-redeemable now (H-O)** | **$457,645.45** | | verified by live `eth_call` redemption of every path | time-bounded on Blast |
| — of which **treasury-only (P)** | $19,295.68 | | accrued post-expiry interest already assigned to the factory treasury EOAs | |
| — of which **stuck (S)** | $14,359.12 | | Wasabi vault drained, recovery team-only | |

**Headline: external unprivileged extractable = $0.00 (high confidence).** The triage's $484,392.71 is confirmed live and *backed*: $457.6k redeemable by holders, $19.3k accrued to the protocol treasury, $14.4k stuck in a drained third-party vault. No permissionless path pays value to an outsider.

---

## 2. What Splice is / the mechanism (exact terms)

Splice Finance is a **1:1 fork of Pendle V2** (source: `github.com/splice-finance/contracts-public`; contract `NAME="Splice Market"`, `SYMBOL="SPLICE-LPT"` in `PendleMarketV3.sol`). Deployed May–Sep 2024 on Mode and Blast. Frontend dead; markets long expired. The live value is the residual of:

- **SY tokens** — `PendleERC4626SY` wrappers: `exchangeRate() = vault.totalAssets()/vault.totalSupply()`, and SY shares are minted/redeemed **1:1 with ERC4626 vault shares** (`_deposit`→`vault.deposit`, `_redeem`→`vault.redeem`, see `analysis/src/HyperUSDBSY/src_core_StandardizedYield_implementations_PendleERC4626SY.sol`).
- **Markets** (`PendleMarketV3`) hold SY + PT for LPs; **YT contracts** (`PendleYieldToken`) hold SY backing outstanding PT/YT.
- Post-expiry (all markets expired 2024-06-27 / 2024-08-11/21 / 2024-10-31): `mint` and swaps are `notExpired`-blocked; only `burn` (LP), `redeemPY` (PT), `redeemDueInterestAndRewards` (YT), `skim`, and treasury sweeps remain.

**The extraction question** therefore reduces to: (a) can an outsider take SY/PT/YT/LP-backed value through any remaining permissionless function, and (b) is the vault backing real and reachable.

---

## 3. Live-state assessment (addresses, calls, blocks)

Pinned blocks: **Blast 41,475,467**, **Mode 45,796,981** (state dump); vaults re-verified at **Blast 41,477,200** (`analysis/vaults.md`). Full dump: `analysis/state_dump.json`; summary: `analysis/splice_summary.json`.

### 3.1 Contracts & roles (all read on-chain)

| Item | Blast | Mode |
|---|---|---|
| Market factory 1 | `0x96A6C433…d64375` (owner/treasury `0x88653cb8…` — Hyper deployer **EOA**) | — |
| Market factory 2 | `0xf87E1891…E34bf` (owner/treasury `0x04d440CE…` — Splice deployer **EOA**) | `0x9e6d1209…4AB39` (same EOA owner/treasury) |
| Yield contract factory | `0xb55cAd69…f75C5` / `0x19f73Aba…c6f8`, `interestFeeRate=0` | `0xD0135Ddd…C4F82` |
| Markets | **9 markets** (6+3; 2 PTs have two markets each) | 16 markets |
| SYs | 7 (5 funded: hUSDB, hWETH, wUSDB, sWETH, sUSDB; + 2 empty ezETH:ETH) | 16 |
| SY pause state | all `paused=false` | all `paused=false` |
| SY self-balance | **0** for all five | **0** for all sixteen |
| PT held by YT contracts | **0** for every YT | **0** for every YT |

### 3.2 Value distribution (deduped by SY; block pinned above)

| Chain | SY | Asset | Total USD | market-held | YT-contract | user wallets |
|---|---|---|---|---|---|---|
| Blast | `0x13293Dac…` hUSDB | USDB | 341,646.73 | 4,501.59 | 111,077.29 | 226,067.85 |
| Blast | `0xB80aD10D…` hWETH | WETH | 101,954.72 | 11,044.08 | 78,566.11 | 12,344.52 |
| Blast | `0xF904fA59…` wUSDB | USDB | 14,359.12 (stuck) | 2,629.70 | 11,209.82 | 519.60 |
| Blast | `0xc28fb4cc…` sWETH | WETH | 6,393.53 | 3,456.43 | 2,925.22 | 11.88 |
| Blast | `0x0e999EB7…` sUSDB | USDB | 2,853.14 | 392.90 | 947.81 | 1,512.43 |
| Mode | 16 SYs (largest: ezETH `0x0Cd0F94b…` 17,365.09; weETH `0x356B2eBc…` 4,300.34; wrsETH `0x9bAF8D6a…` 1,789.48) | | 24,091.29 | | | |

### 3.3 Backing (vault cash == claim)

| Vault | totalAssets | actual cash | SY claim | Verdict |
|---|---|---|---|---|
| hUSDB `0x390b781B…` | 343,696.92 USDB | **equal** | 341,148.65 USDB | LIVE-REDEEMABLE |
| hWETH `0x1856C7e0…` | 40.6757 WETH | **equal** | 40.2146 WETH | LIVE-REDEEMABLE |
| wUSDB `0x4BeD2A92…` | 163,243.25 USDB (book) | **0** | 14,338.18 USDB | **DEAD-STUCK** |
| sWETH `0x8A444bF2…` | 2.5218 WETH | **equal** | 2.5218 WETH | LIVE-REDEEMABLE |
| sUSDB `0x33413CA0…` | 2,848.99 USDB | **equal** | 2,848.99 USDB | LIVE-REDEEMABLE |

wUSDB drain proof: `StrategyDeposit` of all 163,243.246 USDB to malicious strategy `0xe1e6f6d4…` at Blast block **34,362,930** (2026-04-30), UUPS-upgrade to `WasabiVaultRecoveryV1` + `StrategyDebtMigrated` to recovery strategy `0xac4eb51b…` (which holds 0 USDB). Redeem now reverts `InsufficientBalance` (simulated from the SY's actual holder). Details: `analysis/vaults.md` §3.3/§5.3.

### 3.4 Code equivalence (fork vs canonical, and unverified components)

- The two **unverified Blast SYs** (`0xc28fb4cc` sWETH, `0x0e999eb7` sUSDB) have **byte-identical dispatchers** (md5 of first 1000 runtime bytes) to the verified `SpliceWUSDBSY` `0xF904fA59…` → same `PendleERC4626SY`+supply-cap implementation.
- Vaults sWETH/sUSDB are unverified but selector-identical to OZ ERC4626 + Ownable + BlastPointsManager; no pause/sweep/upgrade selectors; `totalAssets == balanceOf(asset)` to the wei; live redeem succeeds (vault subagent, `analysis/vaults.md` §3.4/§5.4).
- **Fork-vs-canonical diff (`analysis/fork-diff.md`, child subagent, high rigour):** the fork is a **Dec-2023–Mar-2024 Pendle-V2 snapshot (package v4.2.3)** — base determined by git-blob equality over all 2,116 canonical commits: **94/109 files byte-identical**; 5 differ only cosmetically (`PendleMarketV3` NAME/SYMBOL, trailing newline, an unused import); 10 are fork-only Mode additions (L2 SYs, Mode router). Every core accounting/reward/AMM file is **byte-identical** (`SYBase`, `PYIndex`, `MarketMathCore`, `PendleYieldToken`, `InterestManagerYT`, `PendlePrincipalToken`, `RewardManager*`, factories, action facets, base libs). **Deployed Mode contracts: 17/17 byte-identical** to a local compile of the repo (both factories, weETH market/PT/YT, 5 action facets, router, PtOracle, OracleLib, 4 SYs; immutables/metadata masked), including the embedded PT-creation hash. No fork-introduced extraction surface.

---

## 4. What an attacker can / cannot do (exact call paths)

**Candidate paths tested (all read-only simulations and fork tests):**

| # | Path | Result |
|---|---|---|
| 1 | `SY.redeem(receiver, shares, tokenOut, 0, **burnFromInternalBalance=true**)` — burns from the SY's own balance | **Reverts** — every SY self-balance is 0 |
| 2 | `YT.redeemPY(attacker)` / `redeemPYMulti` — post-expiry redeems **all PT held by the YT contract** to the caller | **Pays 0** — every YT contract's PT balance is 0 (verified Blast+Mode); a bogus amount reverts on burn |
| 3 | `Market.burn(attacker, attacker, 1)` without LP | **Reverts** (burns from market's own balance; caller has 0 LP) |
| 4 | `Market.skim()` — permissionless; sends donated surplus to `market.treasury` | **Pays the protocol treasury** (EOA `0x88653cb8…`), not the caller — proven in PoC |
| 5 | `YT.redeemInterestAndRewardsPostExpiryForTreasury()` — permissionless | **Pays the factory treasury** (15,158.78 SY at test block), not the caller — proven in PoC |
| 6 | `YT.redeemDueInterestAndRewards(user, true, false)` — permissionless for any `user` | Pays **`user` only**; calling it for a victim pays the victim |
| 7 | SY `deposit`→`redeem` round-trip (incl. vault-share route) | 1:1, both rounding directions favor the vault; no gain |
| 8 | Donation to the backing vault (share-price inflation) | Strict loss `−X·(1−a)` (a = attacker's share); vaults non-empty; OZ v4.9 — no profitable inflation |
| 9 | PT/YT/LP bought cheaply then redeemed | Possible only by **paying the holder** — a purchase, not extraction; AMMs are expired so no on-protocol counterparty |
| 10 | Market `mint`/swaps (`notExpired`) | Blocked — all 25 markets expired in 2024 |

**Preconditions for any extraction:** ownership of PT/YT/LP/SY (all markets expired; `mintPY` blocked) or a bug in the audited Pendle-V2 core. None found. The only value flows remaining are **holder redemptions** (H-O) and **treasury sweeps** (P).

---

## 5. PoC / fork verification

Project: `poc/` (Foundry; forks of Blast at block **41,475,467** and Mode at block **45,796,981**; public archive RPCs — no keys). **15/15 tests pass.**

Tests (`poc/test/SpliceExtraction.t.sol` — Blast, 10 tests; `poc/test/SpliceMode.t.sol` — Mode, 5 tests):

| Test | Asserts |
|---|---|
| `test_outsider_cannot_drain_sy_internal_balance` | all 5 SY self-balances are 0; `redeem(...,burnFromInternalBalance=true)` reverts; outsider redeem reverts |
| `test_outsider_cannot_sweep_yt` | YT holds 0 PT; `redeemPY(attacker)` pays 0; `redeemPYMulti` with bogus amount reverts |
| `test_outsider_cannot_burn_market` | `burn` without LP reverts |
| `test_skim_surplus_goes_to_treasury_not_caller` | 93.07 SY + 253.42 PT surplus goes to treasury; caller gets nothing |
| `test_treasury_sweep_pays_treasury_only` | 15,158.78 SY post-expiry interest goes to treasury; caller gets nothing |
| `test_real_yt_holder_can_claim_interest` (H-O) | real holder `0x13FeFdD5…` (112,085.6 YT) claims **1,411.47 SY** |
| `test_real_lp_holder_can_burn` (H-O) | real LP holder `0x45D2E892…` (1,799.07 LP) burns → receives pro-rata SY+PT |
| `test_sy_redeem_pays_underlying` (H-O) | 1 SY → 1.117696 USDB from the live hUSDB vault |
| `test_pt_redemption_pays_redeemer` (H-O) | PT → SY at `1e18/rate` via deployed `redeemPY` |
| `test_context_state` | expiry/pause/self-balance/backing invariants |
| `test_mode_sy_self_balances_zero` / `test_mode_yt_pt_zero_and_no_sweep` / `test_mode_outsider_cannot_burn` | same negative proofs on Mode |
| `test_mode_sy_redeem_live` (H-O) | Mode SYs redeem 1:1 for ezETH/MODE (live) |
| `test_mode_market_context` | Mode market internal accounting ≥ actual balances |

**CI run:** [https://github.com/kingmariano/ca-zombie-ci/actions/runs/38189685116](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38189685116) (success; 15/15 tests). The same run re-executed the full-state dump on both chains (blast 41,478,275 / mode 45,799,418 → **$493,248.34** deduped total, within price/block drift of the local pin) and uploaded `ci-out/state_dump.json` + `ci-out/splice_summary.json` as artifacts. Full log: `ci-log.txt`.

---

## 6. Verdict and residual / latent risk

- **E-U = $0.00, confidence high.** All permissionless surfaces either revert, pay zero, pay the holder, or pay the protocol treasury. The Pendle-V2 core is battle-tested; the fork's custom parts (SY wrappers, vaults) are 1:1 or standard.
- **H-O = $457,645.45** currently redeemable by holders (verified by executing every redemption path against live state): Blast $433,673.80 + Mode $23,971.65.
- **S = $14,359.12** — SY-wUSDB claim against a vault drained 2026-04-30 (Wasabi incident). Recovery is a team/multisig process (`P`); recovery strategy holds $0 today.
- **Latent risks (not E-U):** (1) SY/vault owner **EOAs** can pause SYs / reconfigure Blast points / rug the Splice-owned vaults (P); Wasabi recovery EOA can UUPS-upgrade the drained vault (P, nothing to take today). (2) **Blast L2 wind-down** (announced 2026-10-02): interface withdrawals close **2026-10-26** — the $433.7k Blast H-O value is time-bounded; holders who miss it face bridge-only exit. (3) Price drift on USDB/WETH changes USD figures slightly. (4) Known Pendle-V2 quirk: PT transferred into a YT contract outside the atomic router flow is redeemable by **anyone** via `redeemPY` — no PT sits there today (all balances 0), but a user who donates PT by mistake would lose it; this is user-error surface, not live extractable value.
- **Dead ends (recorded so they are not re-investigated):** markets `0x89bb9e39` and `0x92523143` (ezETH:ETH SYs, Blast) and 6 Mode markets are empty (0 supply); the two `SY-ezETH:ETH` SYs hold 0; no Splice/Hyper/Wasabi infra contract holds SY/PT/YT/LP (checked 12 Blast + 6 Mode infra addresses); the market factory-1 holds only 0.1 LP of market `0x258133c3` (dust); market surplus donated tokens are swept to the treasury by `skim`.

## 7. Methodology & sources

- Read-only `eth_call`/`eth_getLogs` on public RPCs (`rpc.blast.io`, `blast.drpc.org`, `blast-rpc.publicnode.com`, `mainnet.mode.network`, `mode.drpc.org`); Etherscan V2 for sources/logs/holders; DefiLlama for prices; Foundry fork tests in CI.
- Sources: Splice `contracts-public` repo (Pendle V2 fork); verified SY/vault sources from Blastscan; Wasabi `WasabiVaultRecoveryV1`/`RecoveryStrategy` sources; Blast shutdown announcements (2026-10-02).
- **Caveats:** unverified sWETH/sUSDB vault sources (resolved by selector + behavior equivalence); `eth_call` simulations prove the path at the pinned block, not forever; the fork-diff result is in `analysis/fork-diff.md` (base version + 17/17 deployed Mode bytecode match; Blast deployed contracts were verified functionally by the PoC tests and by behavioral equivalence, not bytecode-compared).
- **Files:** `analysis/state_dump.json`, `analysis/splice_summary.json/.md`, `analysis/vaults.md`, `analysis/vaults.json`, `analysis/fork-diff.md`, `analysis/*.py` (dumps/summaries), `poc/`, `ci/`, `ci-out/`.

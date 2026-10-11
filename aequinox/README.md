# Aequinox (BSC) — L2 Phase-2 deep dive

**Date:** 2026-10-11 · **Chain:** BNB Smart Chain (BSC, chainid 56) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions**

**Target (triage):** Aequinox — Balancer-V2-style DEX fork on BSC, vault `0xEE1c8DbfBf958484c6a4571F5FB7b99B74A54AA7`, triage value **$631,352** (LIVE-FUNDED, confidence high).

---

## 1. TL;DR

| Target | Live value | External unprivileged extractable (E-U) | Why closed | Latent / other |
|---|---|---|---|---|
| Balancer V2 Vault `0xEE1c…4AA7` + 55 pools (48 weighted, 1 stable, 5 unused linear) | **$632,869.64** | **$0.00** | Swaps/joins are fair-valued; pool registration is isolated per-pool; no profitable round-trip exists (flash & free capital); admin functions authorizer-gated; reentrancy guarded | **$622,103.49 stuck (S)**: BPT staked in 10 Curve-style gauges whose controller checkpoint is permanently broken → `withdraw()` reverts. **$10,766.15 holder-recoverable (H-O)**: BPT outside gauges exits at fair value. |

**Total live extractable by an external unprivileged attacker now: $0.00 (high confidence).**
**Live value frozen/stuck (S): ~$622,103.49 (high confidence).**
**Live value recoverable by BPT holders outside gauges (H-O): ~$10,766.15.**

Key surprise vs triage: the triage counted the vault balance as "live funds". In reality **98.3% of it is trapped inside Curve-style gauge clones** whose `withdraw()` path reverts (dead `GaugeController.checkpoint_gauge`, frozen since 2022/2023). The tokens are still in the Vault, but no BPT holder can redeem the staked share, and nobody — not even the team — can move the gauge-locked BPT.

---

## 2. Live-state assessment (pinned block 127,079,392 / latest 127,091,750; re-verified in PoC fork)

* Vault `0xEE1c8DbfBf958484c6a4571F5FB7b99B74A54AA7` — 24,207 bytes, **canonical Balancer V2 Vault** selectors (`swap` 52bbbe29, `batchSwap`, `joinPool`, `exitPool`, `registerPool`, `managePoolBalance`, `flashLoan`, `setPaused`, `setAuthorizer`); **no owner/sweep/upgrade/implementation** selectors. `getPausedState()` = **not paused** (last pause window ended 2022-11-14).
* Live tokens (block 127,091,750): **USDT 306,097.108** · **USDC 218,875.490** · **BUSD 90,089.693** · WBNB 13.333 · WETH 1.646 · BTCB 0.04947 · DAI 28.05 · TUSD dust ≈ **$632.9k** at DefiLlama prices 2026-10-11.
* 55 pools registered (2022-08-15 → 2026-05-12). Value split: **one StablePool `0xb3A07a9C…` holds $606,466** (USDT/USDC/BUSD; A=2000, fee 0.2%, BPT rate 1.016716), the rest in small weighted pools (~$26.4k). `getPoolTokenInfo` on all 148 pool-token pairs: **managed = 0 everywhere** (no asset-manager withdrawals).
* **Gauges:** 10 EIP-1167 clones of Curve-style LiquidityGaugeV5 (`impl 0xdabb6553…`, `version() = v5.0.0`, all `is_killed = true`, admin `0x12fd0D8d…`) hold **$622,103.49 of the pools' BPT** (stable gauge alone: 596,884.60 of 596,890.04 BPT = $606,460.95).
* **GaugeController `0x585ECE79…`:** `time_total` = 1,692,835,200 (2023-08-24); stable gauge `period` 3907 / `period_timestamp` = 1,666,816,109 (**2022-10-26**); last gauge Deposit/Withdraw event block 22,516,874 (Oct 2022) — zero gauge activity since.
* Authorizer `0x7Bdc7b72…` gates `setPaused`/`setAuthorizer`/pool `pause()`/`setSwapFeePercentage()`/`enableRecoveryMode()` (BAL#401 from random EOA). Pool owners are EOAs; ProtocolFeesCollector `0x2b1698d2…` has protocol swap fee = **50%**, flash-loan fee = **1%**.

---

## 3. The mechanism in exact terms

### 3.1 What is closed for attackers (E-U = $0)

1. **Malicious pool registration is isolated.** `registerPool` is permissionless (verified: a random EOA receives a poolId). But `registerTokens`/`deregisterTokens` are `onlyPool` (BAL#402 from a third party), `managePoolBalance` requires caller == registered asset manager (BAL#502), and exits/swaps only decrement a pool's own **cash** (`BalanceAllocation.decreaseCash`, checked arithmetic). An attacker-controlled pool can fabricate its own `managed` balance via asset-manager UPDATE (succeeds) but WITHDRAW/exit/swap then revert on cash underflow. PoC `test_02` proves: fabricated managed = 1e24, all four extraction attempts revert, vault balances unchanged, reentrancy blocked.
2. **No fair-value arbitrage.** Stable pool swaps: 100k USDT→USDC→USDT = −0.14%; joins+exits lose the fee. PoC `test_05` (free capital, no flash fee) ends strictly below start. Flash-loan round trips (1–100k, 2 paths) and 3-hop batchSwap round trips all revert on repayment (PoC `test_04`, `test_08`).
3. **No admin path.** `setPaused`/`setAuthorizer`/`enableRecoveryMode`/`setSwapFeePercentage`/`pause` all revert for a random EOA (BAL#401); pools are not in recovery mode.

### 3.2 What is stuck (S = $622,103.49)

The Curve-style gauges route every deposit/withdraw/claim through `_checkpoint()` → `GaugeController.checkpoint_gauge(gauge)`. That call **reverts for every gauge** (PoC `test_07`, `test_08`; opcode trace: internal assert in the controller, no external calls). Root state: the controller's last checkpoint is 2023-08-24 and gauge weight entries date from Oct 2022–Feb 2023; `points_total(current week) = 0`; the checkpoint math walks the stale weekly weights and underflows (slope 0 vs a recorded `changes_weight` of 4.04e12 observed in the trace). The state is monotonic (storage is immutable, time only advances) and no public/admin function rewrites it; `add_gauge` cannot re-add (type≠0) and `change_gauge_weight`/voting would re-enter the same reverting math (veAEQ totalSupply = 0). Therefore the **BPT in all gauges is permanently unredeemable** — `withdraw`, `deposit`, `claim_rewards`, `user_checkpoint` all revert; gauge tokens are transferable but worthless claims. This has held since the last successful gauge checkpoint (stable gauge: **2022-10-26**; last gauge deposit/withdraw event Oct 2022; controller-wide: Aug 2023).

### 3.3 What holders can still recover (H-O = $10,766.15)

BPT held **outside** gauges (5.44 BPT of the stable pool; ~$10.8k across weighted pools) exits via the Vault at fair value: stable pool proportional exit (ExitKind 1) works (PoC `test_06`: 5.075 BPT → 2.584 USDT + 1.861 USDC + 0.697 BUSD, matching pro-rata within the protocol-fee charge on USDT); weighted pools' proportional exit (kind 2) reverts (fork bug) but **one-token exit (kind 0) works** (PoC `test_weighted_holder_exits`: 1e15 BPT → 0.002155 ETH).

---

## 4. Value table (exact, block 127,079,392 + DefiLlama 2026-10-11)

| Pool | Type | Pool USD | Gauge share | Stuck (S) | Holder-recoverable (H-O) |
|---|---|---|---|---|---|
| 0xb3a07a9c… (USDT/USDC/BUSD) | StablePool | 606,466.47 | 99.999% | **606,460.95** | 5.52 |
| 0x0256c70b… (ETH/BTCB/WBNB) | Weighted | 12,283.66 | 94.37% | **11,591.48** | 692.18 |
| 0x5ba2bc39… (WBNB/BUSD) | Weighted | 10,174.41 | 14.76% | **1,501.77** | 8,672.64 |
| 0x74154c70… (BUSD+token) | Weighted | 1,925.58 | 99.63% | **1,918.48** | 7.10 |
| 0x9aa86787… | Weighted | 799.85 | 46.94% | **375.43** | 424.42 |
| 0xe53896c8… | Weighted | 233.07 | 99.55% | **232.03** | 1.04 |
| 0xe263e513… | Weighted | 169.24 | 3.72% | **6.30** | 162.94 |
| 0x835ff599… | Weighted | 22.89 | 74.46% | **17.05** | 5.85 |
| 12 un-gauged small pools | Weighted | ~804 | 0% | 0 | ~804 |
| **Total** | | **632,869.64** | | **622,103.49** | **10,766.15** |

Prices used: USDT 0.99907, USDC 0.99967, BUSD 0.99884, WBNB 749.30, WETH 2520.33, BTCB 82,941.08, DAI 0.99938. Unpriced fork-launch tokens are excluded (no exit liquidity; their blue-chip legs are valued above).

---

## 5. PoC / fork verification

Foundry project `poc/` — all tests fork BSC at latest (`BSC_RPC_URL` env, public fallback) and are **read-only** (impersonation + `deal` only; no signed transactions).

| Test | Proves | Result |
|---|---|---|
| `test_01_live_state` | vault/pool/gauge live state, unpaused, $633k present | PASS |
| `test_02_malicious_pool_isolated` | permissionless registration but zero extraction: managed fabrication, withdraw/exit/swap revert, reentrancy blocked | PASS |
| `test_03_no_cross_pool_or_admin_access` | BAL#402/502/401 gates on other pools' tokens and admin fns | PASS |
| `test_04_flash_roundtrip_no_profit` | 6 zero-capital flash round trips unprofitable (1% flash fee) | PASS |
| `test_05_free_capital_no_profit` | free-capital swaps and join+exit strictly lose money | PASS |
| `test_06_holder_exit_works` | non-gauge BPT exits at fair value (H-O) | PASS |
| `test_07_gauge_frozen` | withdraw/deposit revert; `initialize`/`transferFrom` guarded; BPT stays trapped | PASS |
| `test_08_controller_freeze_gauges` | `checkpoint_gauge` reverts for all tested gauges; `time_total` frozen (2023) | PASS |
| `test_weighted_holder_exits` | weighted kind2 reverts, kind0 works → holders recover | PASS |
| `test_debug_checkpoint_gauge` | controller freeze diagnostics (11-entry gauge map) | PASS |

**11/11 tests pass.** CI: GitHub Actions `kingmariano/ca-zombie-ci` (public) — see `ci-log.txt` and `ci-artifacts/`; run URL recorded in `summary.json`.

---

## 6. Verdict and residual/latent risk

* **E-U $0 (high):** no path for an unprivileged attacker to end with more value than they started. The Vault is canonical; pools' pricing is fair; registration is isolated; admin is gated; the one broken thing (gauge withdrawals) blocks *everyone*, including attackers.
* **S $622,103.49 (high):** gauge-staked BPT is permanently frozen (controller checkpoint dead since 2022/2023, state monotonic, no repair function). The underlying tokens remain in the Vault but are only reachable via fair-value swaps — no redemption for the stakers.
* **H-O $10,766.15 (high):** non-gauge BPT can exit today (stable: proportional; weighted: one-token).
* **Latent:** (i) if the GaugeController admin (`0x12fd0D8d…`, a contract) somehow rewrites the controller state, the $622k becomes holder-recoverable (not attacker-extractable); (ii) if governance ever sets the protocol swap fee to 0, more exit paths open (still fair-value); (iii) flash-loan/swap surfaces stay fair-valued at any fee level.
* **Blockers:** none for E-U (it is a closure result, not a blocked attack). For recovery: the gauge freeze above.

## 7. Methodology & sources

Canonical Balancer V2 Vault/Pool sources (mainnet verified contracts via Etherscan V2 + balancer-v2-monorepo) used as reference; all live values read at pinned blocks via public/keyless RPCs; gauge/pool/controller identification via `eth_getCode`, selector extraction (evmole + 4byte), `ankr_getLogs`; fork PoCs in Foundry (CI GitHub Actions). Negative results recorded: kind-2 weighted exit reverts (fork bug), stable `queryExit` decode mismatch, `0x177cA62c…` uninitialized gauge clone (empty), 5 LinearPools never used (2^112−1 pre-mint, zero deposits), 11 zero-supply pools hold dust only.

**Caveats:** the deployed pools are an Aequinox fork of Balancer (unverified source); exact fork-internal line numbers for the two reverts (controller checkpoint underflow, weighted kind-2 exit) were not source-verified — behaviour was proven on-fork. USD uses DefiLlama spot prices at 2026-10-11 (stablecoins ≠ exactly $1). Fork state is "latest"; figures drift with swaps (stable pool `lastChangeBlock` 121,837,879).

## 8. Files

`analysis/` (state dumps, pool/gauge maps, final_values.json, evmole selectors), `poc/` (Foundry project, 11 tests), `ci-out/poc-results.json` (written by CI), `ci-log.txt`, `ci-artifacts/`, `summary.json`.

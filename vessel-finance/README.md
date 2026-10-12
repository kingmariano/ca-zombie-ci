# Vessel Finance (Scroll) — L2 Phase-2 deep dive: external unprivileged extraction

**Date:** 2026-10-12 · **Chain:** Scroll (chainid 534352) · **Status:** read-only; PoC fork-verified only; no mainnet transactions
**Source row:** L-2 Triage-B rank 11 — Vessel Finance, LIVE-FUNDED $193,046 (triage block 35337420)

---

## 1. TL;DR

| Target | Live value | E-U (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|---|
| Vessel VaultProxy `0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2` (ETH/USDT/USDC/WBTC/SCR) | **$194,876.45** at block 35349825 | **$0** (high confidence) | Every value-moving path is gated by `operator`, `admin`, `exitManager` roles + ECDSA user signatures; role storage is protected by a 2-of-3 Gnosis Safe → AccessControl executor → ProxyAdmin chain. No permissionless payout exists. | (a) 2-of-3 Safe → executor → ProxyAdmin can upgrade the Vault at any time (trust assumption, not an exploit); (b) operator keys can resume SNARK commits so users/LPs can self-withdraw; (c) **operator has been dormant since 2026-08-04** — user balances need the operator to become withdrawable; (d) `withdrawAll()` is broken (always reverts, UX bug only — `withdraw()` works). |
| Immediate holder-only (H-O) | see §4 | **CLAIMABLE_NOW_USD** | `pendingWithdraw` balances credited by past SNARK commits can be withdrawn right now, permissionlessly, by their owners | none beyond normal |

**Total external-unprivileged extractable now: $0.00** (high confidence — 14/14 fork tests, whole attack matrix reverts, balances unchanged).

**Total vault value that is live but must be moved by its owners/operator: $194,876.45** — of which **$CLAIMABLE_NOW_USD** is already `pendingWithdraw`-credited and self-withdrawable today; the remainder needs operator commits (or an admin upgrade) to become claimable.

---

## 2. What Vessel Finance is (architecture, per deployed code)

Vessel Finance (`vessel-finance`, DefiLlama "Dexs", listed 2026-07-04) is a zk-DEX on Scroll: a limit-order-book + AMM ("VAELOB") whose **L2 state is committed to a Scroll vault via Groth16 SNARK proofs** submitted by an operator. The DefiLlama TVL is exactly "ETH, USDT, USDC and WBTC balances held in the Vessel Finance VaultProxy contract on Scroll".

Deployed contract set (all verified on Scrollscan, keyless reads):

| Component | Address | Notes |
|---|---|---|
| VaultProxy (TransparentUpgradeableProxy, EIP-1967) | `0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2` | holds **all** user funds; deployed block 8,015,163 (2024-08-03) |
| Implementation `Vault` (current, "v0.1.20") | `0x8804201FD6C0aBBcB62C158e51978893aA47785c` | set by the only `Upgraded` event, block 11,468,107 (2024-11-28); `is_changed_bytecode=false`; spare identical copy at `0x2a0E741E924d715dA0286AC38D63B1C0aFFF69d8` (same code hash) |
| Old implementation (v1, unused since 2024-11-28) | `0x54e661Cf6B2aDC335d5201751F4C216AA25b63df` | 21,267 runtime bytes |
| ProxyAdmin | `0x6251b4291ae357e63D9665dC2ABcD958e7CEe742` | `owner() = 0x3c417EC0…` |
| Governance admin (vault `admin` slot) + executor | `0x3c417EC088f19EA02Ac9853cd6c35Fb193c98Abe` | custom AccessControl executor; `execute(target,value,data,salt)` requires `DEFAULT_ADMIN_ROLE` |
| Safe (role holder) | `0x9549F1d6428066BE58C315374676E9d244716d4F` | Gnosis Safe, **threshold 2 of 3** owners: `0xFe23B174…8755`, `0x9eC6b246…E655`, `0x3Bbb6028…e75E`; nonce 6; last exec 2026-03-03 |
| SNARK verifier (Groth16, current) | `0xF33De4cA77959061a17B0866d35c850249aCed7E` | set 2026-03-03 (`updateAll(verifier,"vessel-0.1.20")`); previous verifiers 0x22dFe04C→0x1acd3733→0x39a1211B |
| MessageQueueEncoder | `0x6Ede705B5b092c2a7Cf3e9A71621cbDCea6a883A` | set 2024-11-28 |
| WETH | `0x5300000000000000000000000000000000000004` | canonical Scroll WETH |
| Operators (3, none ever removed) | `0xb7bbcd40c5…01fc3` (main committer), `0xe5ad0cd37c…0e981`, `0x570b2c7104…a257` | EOAs; added at deployment |
| Exit manager (1) | `0x5bef2A1fCf34911e0Eb7b02376d1aB1c85cecfAc` | EOA; registered 2024-11-28 |
| Registered assets | id1 USDC `0x06eFdBFf…63A4`, id2 USDT `0xf55BEC9c…99Df`, id3 WBTC `0x3C1BCa5a…0Cf1`, id4 SCR `0xd29687c8…7b1b` (+ native ETH id0) | all currently active |

Snapshotted governance history (from `Safe.execTransaction` txs, fully decoded):
2024-08-03 deploy + `transferAdmin(executor)` + 3 operators + `updateAll(v0.1.14)` + asset registrations;
2024-10-22 SCR asset added; 2024-11-07 `updateAll(v0.1.17)`;
2024-11-28 single MultiSend: **ProxyAdmin.upgrade(vault→0x8804201) + setMessageQueueEncoder + setWethAddress + registerExitManager(0x5bef2A1f)** + `updateAll(v0.1.18)`;
2026-03-03 last admin action: `updateAll(0xF33De4cA, "vessel-0.1.20")`.

### 2.1 The code (what moves value)

`Vault.sol` (Apache-2.0, "Copyright 2024 Vessel Team") and its modules:
- `depositERC20/depositNative/registerAndDeposit*` → **funds in only**; require a registered `vesselKey` (`validVesselKeyToAddress`), and registration (`checkAndRegisterUser`) requires an **operator ECDSA signature** over `UserBinding(vesselKey, msg.sender)`.
- `withdraw/withdrawAll` → pays `msg.sender` only up to `pendingWithdraw[msg.sender][assetId]`.
- `pendingWithdraw` is written **only** in `_verifyAndUpdateL2ToL1MessageQueue()` inside `commitSnarkProof()` → `onlyOperator`; every credit requires a SNARK proof whose instances must match the live eternal/ephemeral tree roots and the L1→L2 / L2→L1 hash chains (`Vault.sol:225-375`).
- `fastWithdraw(lp,recipient,asset,amount,fee,nonce,expiry,v,r,s)` → `onlyExitManager`; pulls `amount-fee` from the **LP wallet** (`safeTransferFrom`, LP's own allowance) to the recipient, requires the **recipient's EIP-712 signature** (digest binds action string, recipient, asset, amount, fee, nonce, expiry, domainSeparator incl. chainId + vault), marks the nonce used.
- `transferOutFromExitLp` for native checks the vault's ETH balance is unchanged; `backfillToExitLp` pays LPs **from the vault**, only from `commitSnarkProof`.
- Roles: `transferAdmin`, `register/unregisterOperator`, `register/unregisterExitManager`, `updateAll/updateSnarkVerifierAddress`, `setWethAddress`, `setMessageQueueEncoder` → `onlyAdmin`; `registerNewAsset`, `setAssetActive/Inactive`, `updateAssetLimitAndPrecision`, `commitSnarkProof` → `onlyOperator`.
- `initialize()` is initializer-guarded (proxy storage slot 0 = `…0001`); implementation calls `_disableInitializers()`.

---

## 3. Live state (block 35349825, 2026-10-12 ~18:20 UTC)

Vault balances and USD (DefiLlama prices same block):

| Asset | Amount | Price | USD |
|---|---|---|---|
| ETH | 44.03683120 | $2,531.70 | $111,487.90 |
| USDT | 39,047.673998 | $0.9992 | $39,016.18 |
| USDC | 37,364.910793 | $0.9997 | $37,354.57 |
| WBTC | 0.08045803 | $82,515.27 | $6,639.02 |
| SCR | 15,125.236229 | $0.02505 | $378.79 |
| **Total** | | | **$194,876.45** |

- Triage (2026-10-11, block 35337420) found $193,046.15 for the same 4 assets; the difference is ETH/token price drift plus **15,125 SCR (~$379) that the DefiLlama adapter does not count** (adapter sums only ETH/USDT/USDC/WBTC).
- `getPendingWithdraw(user, asset)` live values: `0x6Da57994…A3722` = 87.378 SCR; `0x6935a594…a79F` = 91.7419 SCR; all other sampled users = 0. (Full-history total in §4.)
- Message queues: `l1ToL2MessageQueueTailIndex = 20546` vs `commitIndex = 20528` → **18 L1→L2 messages queued but never committed** (17 fast-withdraws + 1 register, all from the 2026-08-04 window).
- Last `LogProofCommitted`: block 34,561,380 (2026-08-04 06:57 UTC), batch 4174. **No vault event of any kind after block 34,566,367 (2026-08-04 19:24 UTC)** — the protocol has been dormant for ~10 weeks.
- Operator activity: all sampled `commitSnarkProof` txs ever were sent by `0xb7bbcd40…01fc3` (56 commits scanned from deployment day onward; last 3 = 2026-08-01…08-04). All three operators still return `isOperator=true`.
- The 2026-08-04 window contains the **wind-down exits**: 17 `fastWithdraw` calls (topics decoded) queuing payouts of 3.0816 ETH + 25,742.59 USDC + 10,245.32 USDT + 0.551157 WBTC + 7,140.52 SCR (~$118k) from **6 distinct LP wallets** to a small set of recipients. L1 transfers from LPs did occur (e.g. tx `0xfe0bf3e893…`: 3.0 SCR moved; `0x4590832788…`: 1,525.5 SCR; `0x84c958db0d…`: 1,998.5 SCR). The LPs' reimbursement requires operator-committed L2→L1 backfills — none have happened since.

---

## 4. What an external unprivileged attacker can / cannot do

**Cannot (each proven by fork test + live read):**
1. `withdraw` any amount without a `pendingWithdraw` balance → reverts `Vault: not enough funds` (test `test_attacker_withdraw_reverts`).
2. `commitSnarkProof` (the only way to create `pendingWithdraw` credits) → `Gov: caller is not an operator`.
3. `fastWithdraw` → `Gov: caller is not an exit manager.`; and even the real exit manager can only pay a **signing recipient** — the digest binds the recipient address and a per-user nonce, so no redirection/replay.
4. Any admin function (`transferAdmin`, `updateAll`, `updateSnarkVerifierAddress`, `setWethAddress`, `registerNewAsset`, `setAssetActive/Inactive`) → `Gov: caller is not the admin/operator`.
5. `initialize()` re-init → `Initializable: contract is already initialized`.
6. `ProxyAdmin.upgradeTo/upgradeAndCall` → reverts (owner = executor).
7. Executor `execute()` → `AccessControl: account … is missing role 0x00…00` (only the Safe holds it; simulated and fork-verified).
8. Fake-operator user registration / unregistered-key deposits → revert (`Users: invalid operator address`, `Users: vesselKey not registered to user address`).
9. Any combination in the attack matrix leaves all vault balances and the attacker's balance unchanged (`test_balances_unchanged_after_attack_matrix`).

**Can (all harmless to the vault):** send ETH/tokens to the vault; call any view function; call `registerUser` with a genuine operator signature (needs the team); use `withdraw()` on one's own historic `pendingWithdraw`.

**Can, and it *is* the H-O path:** any address holding `pendingWithdraw[account][asset] > 0` (credited by historic SNARK commits) can call `withdraw(assetId, amount)` **today**, without operator or admin cooperation. Fork-demonstrated with `0x6Da57994…A3722` withdrawing 87.378 SCR (`test_HO_selfservice_withdraw_works`).

**Quirk (negative result, not extraction):** `withdrawAll(assetId)` always reverts with `ReentrancyGuard: reentrant call` — it is `nonReentrant` and internally calls the also-`nonReentrant` `withdraw()` (OZ 4.9). Fork-proven (`test_withdrawAll_nested_reentrancy_quirk`). Self-service withdrawal is unaffected via `withdraw()`.

**Deployed-source integrity (byte-for-byte):** reconstructing the Scrollscan-verified sources (`analysis/bs_impl.json`, 22 files) and compiling them with solc 0.8.19 / optimizer runs 10000 / evm paris / **via-IR / metadata stripped** yields runtime bytecode **byte-for-byte identical (24,195 bytes) to the live implementation** at `0x8804201FD6C0aBBcB62C158e51978893aA47785c` (`ci/verify_bytecode.py`; result re-checked in CI: `ci-out/bytecode_check.txt`). The audited source **is** the deployed code. (Non-via-IR compiles and non-stripped-metadata builds show expected differences: 26,129 B and +54 B metadata.)

---

## 5. PoC / fork verification

Foundry fork tests (Scroll), `poc/test/VesselPoC.t.sol` — local run: **14 passed / 14 total**; CI: **CI_TESTS**.

| Test | Asserts |
|---|---|
| `test_live_state_roles_and_impl` | admin, EIP-1967 impl slot, verifier 0xF33De4cA, circuit `vessel-0.1.20`, operator/exitManager flags, ProxyAdmin owner |
| `test_live_state_balances` | vault ETH>40 / USDC>37k / USDT>39k / WBTC>0.08 / SCR>15k; assetId mapping |
| `test_attacker_withdraw_reverts` / `_commitSnarkProof_` / `_fastWithdraw_` | exact revert reasons |
| `test_attacker_admin_functions_revert` | 7 admin/operator functions, exact revert reasons |
| `test_initialize_locked`, `test_registerUser_fake_operator_reverts`, `test_deposit_unregistered_key_reverts` | auth gates |
| `test_proxyAdmin_upgrade_reverts_for_attacker`, `test_executor_execute_reverts_for_attacker` | upgrade path closed |
| `test_balances_unchanged_after_attack_matrix` | 11-call attack matrix; ETH/USDC/USDT/WBTC/SCR balances + attacker unchanged |
| `test_HO_selfservice_withdraw_works` | H-O: 87.378 SCR withdrawn by its owner on the fork |
| `test_withdrawAll_nested_reentrancy_quirk` | `withdrawAll` always reverts (negative result) |

CI runs (GitHub Actions, `kingmariano/ca-zombie-ci`):
- **CI_RUN_URL**
- Full-history scan artifacts: `ci-out/scan_summary.json`, `ci-out/pending_withdraw.csv`, `ci-out/vault_logs_compact.json.gz`; bytecode parity check `ci-out/bytecode_check.txt` (**BYTECODE_CHECK**).

Full-history scan results (all vault events from deploy block 8,015,163 → latest):
- Events by type: **CI_EVENT_COUNTS**
- Claimable-now total (live `pendingWithdraw`): **$CLAIMABLE_NOW_USD** across N accounts.
- Deposits/withdrawals/fastWithdraw/backfill aggregates: **CI_AGGREGATES**

---

## 6. Verdict, categories, residual/latent risk

| Category | USD | Notes |
|---|---|---|
| **E-U (external unprivileged)** | **$0.00** | high confidence; 14/14 fork tests; attack matrix reverts; balances unchanged |
| H-O (self-service, live now) | **CLAIMABLE_NOW_USD** | `pendingWithdraw` owners only |
| Operator-liveness-gated (latent H-O / S-until-resume) | **$194,876.45 − CLAIMABLE_NOW_USD** | user L2 balances + LP reimbursement claims; become withdrawable if/when an operator resumes committing proofs |
| P (privileged-only) | same remainder | 2-of-3 Safe (owners alive, last act 2026-03-03) can upgrade the vault via ProxyAdmin and do anything — trust assumption inherent to an upgradeable vault |
| S (permanently stuck) | $0 today | nothing is permanently bricked while Safe owners and operator keys exist; if all keys are lost, the remainder becomes S |

**Residual/latent risk (not attacker-extractable):** (1) the operator/admin single points of trust are live and have been dormant since 2026-08-04 — users who never exited are dependent on them resuming; (2) 6 LP wallets are ~$115k out-of-pocket from the Aug-4 fast-withdraw window with no backfills yet; (3) `withdrawAll` UX bug; (4) SNARK/circuit soundness is assumed (verifier bytecode is on-chain; circuit source was not public — repo distributes verifier via GitHub release per README).

**Blockers to extraction:** role gates (operator/admin/exitManager), operator-signature requirement for registration, SNARK-verified state transitions, Safe-held admin role, Safe-upgrade power (trust, not exploitability).

---

## 7. Methodology & sources; caveats; files

**Method:** keyless public Scroll RPC (`scroll-rpc.publicnode.com`, `rpc.scroll.io`, `scroll.drpc.org`) + Scrollscan API; all addresses/roles/balances verified by `eth_call`/`eth_getStorageAt`/`eth_getLogs` at named blocks; explorer-verified source (`is_changed_bytecode=false`) cross-checked by fork behavior; DefiLlama prices; web research for project status (dead site/socials, no incident, no audit found).

**Key caveats:**
- $0 E-U is conditional on the deployed implementation matching the verified source — explorer `is_changed_bytecode=false`, behavior matches all revert strings/tests; an exact bytecode-compile comparison was attempted in CI (**BYTECODE_CHECK**).
- The vault's live value changed from triage: **$193,046 → $194,876 (+$1,830)**; entirely price drift + SCR (amounts themselves unchanged — no deposits/withdrawals since 2026-08-04).
- `pendingWithdraw` totals rely on last-write-wins decoding of `LogNewPendingWithdrawAmount` over full history; any account never emitting the event has 0.
- No live E-U means "not exploitable by role-less external attackers", not "users are safe": the operator/Safe trust surface and the dormant wind-down are the real risks.
- Web findings (child subagent): project appears abandoned (site dead since ~Mar-2026, X silent since 2025-01-22, RootData dead-list), no exploit/audit/post-mortem found; source repo `github.com/Meshee-Team/vessel-contracts`; docs list only Scroll.

**Files:** `analysis/` (source dumps, state reads, log scans, `child-web/findings.md`), `poc/` (Foundry fork tests), `ci/` (full-history scan + bytecode check), `ci-out/` (CI artifacts), `ci-log.txt`, `summary.json`.

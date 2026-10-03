# H-01 — Bucket Farm (Sui) deep-dive: live-state audit & extraction analysis

- **Date:** 2026-10-03 (UTC)
- **Chain:** Sui mainnet (read-only)
- **Target:** Bucket Farm — `farm.bucketprotocol.io` (DefiLlama "Bucket Farm", `module: bucket-farm/index.js`, deadFrom 2025-09-09, last-known TVL **$37.98M**, 0 audits)
- **Status:** **read-only; all proofs are `sui_dryRunTransactionBlock` simulations; no mainnet transaction was signed or submitted.**
- **Latest checkpoint observed:** `329,860,258` (CI state dump; local runs `329,859,861`–`329,856,433`)
- **CI run:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37137479809 — **6/6 dry-run expectations met**

---

## 1. TL;DR

| Target | Live extractable (external unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| 33 live `DegenPool` farm pools (SUI, AFSUI, HASUI, CERT, STSUI, BTC, BUCK, USDC, …) | **$0** | Every value-moving path is gated by (a) the pool's hot-potato `Stake/UnstakeResponse` accounting, (b) a per-account `Profile` stake bound enforced in `point::fulfill_unstake` (`stake::sub`), (c) a `credits`-map debtor allow-list for loans, and (d) the `WrapperRule` witness policy that forces the current (v7) package | Old package versions (v1–v6) stay callable, but cross-version value mixing is rejected (`InvalidLinkage`) and the policy blocks old entry points |
| `PointCenter` DROP rewards (`claim`) | **$0** | Only the caller's own accrued points are claimable; all pool `flow_rate = 0` (emissions off), so no new accrual | If flow rates were re-enabled, reward math should be re-audited |
| `ButConvertor` DROP→BUT redemption (public, 9.30M BUT reserve ≈ $6.45K) | **$0** (requires DROP) | Redemption is public but needs `Coin<DROP>`; DROP is only obtainable from already-accrued farm points or a market. Rate is the intended 0.543 BUT/DROP | DROP market could let a buyer drain the reserve at market price; holder-only value |
| Admin-only paths (pond withdrawals, NAVI/Scallop unwinds, rules, treasury cap) | n/a — **P** | `AdminCap<DROP>` owned by `0xa7caa2a3…`; pond `AdminCap` owned by `0xbfd2e22f…` | EOA key control unverifiable |

**Total live extractable now (E-U): $0.00 — confidence: high.**
**Live value still held: ~$16,179,471** (idle balances $89,417.68 + lent credits $16,090,053.35).

---

## 2. Deployment reconstruction (verified on-chain)

### 2.1 Packages (all `Immutable`, all old versions remain callable)

| Lineage | Versions | Notes |
|---|---|---|
| **Farm** `0x0db143…` (original) | v1 `0x0db143…`; v2 `0x9b99b270…`; v3 `0xb1c78ada…`; v4 `0xa65640fb…`; v5 `0x41af5b07…`; v6 `0x6c3a57c1…`; **v7 `0xf6248808…`** (current) | v1: admin, event, min_size_rule, point, pool, profile, stake, state. v5 adds `pool_type_check`, `privilege`; v6 adds `pool_type_check_V2`; **v7 adds `wrapper`** |
| **Float** (accounting engine) `0xa90218…` | v1 `0xa90218…`; v2 `0x4fbf72ca…`; v3 `0x9f37ba0e…`; **v4 `0xd2b2de20…`** | v4 adds `double`; `sheet` hardened (debtor/creditor must pre-exist) |
| **DROP token** `0x1d627cec…` | v1 (immutable) | `Bucket Drop Token`, 9 decimals, supply 17,126,247.73 |
| **Pond** (strategies) `0xad4f4f73…` | **23 versions**; v1 `0xad4f4f73…` → v20 `0x8cf204f1…` (frontend) → v23 `0x305dff5d…` | v2 adds `CenterPond`, NAVI_UNI_POND; v2+ adds permissionless `withdraw_from_navi_v2/v3` |
| **Scallop pond** `0x7b2720e5…` | v1 `0x7b2720e5…` + upgrades | All value functions require `AdminCap` |
| **ButConvertor** `0x75c86bc3…` | v1 `0x75c86bc3…`, v2 `0xaf8a51fd…` | Public DROP→BUT redemption, reserve 9,301,105.59 BUT |
| **Bucket CDP v1** `0xce7ff77a…`, NAVI `0xd899cf7d…`, oracle `0xca441b44…` | dependencies | used by ponds |

### 2.2 Live objects

| Object | ID | Notes |
|---|---|---|
| `PointCenter<DROP>` | `0xc60fb4131a47aa52ac27fe5b6f9613ffe27832c5f52d27755511039d53908217` | shared (init ver 449801898); holds `TreasuryCap<DROP>`, buffer 402,143.28 DROP, 13,718 profiles, 33 pool states; `claimable=true`; **stake & unstake policies = `0xf6248808…::wrapper::WrapperRule`** |
| SUI `DegenPool<DROP,SUI>` | `0xab90d38384dfaf833c57ce7802d2f87efd286ffa8dddf5474323dc2f2e20f052` | 272.74 SUI idle; credits: NAVI_POND 1,328,357 SUI + NAVI_UNI_POND 38,532 SUI |
| other 32 `DegenPool`s | see `analysis/pool_states.json` / `ci-out/state.json` | assets: AFSUI, HASUI, CERT, KSUI, SPRING_SUI, MSUI, COIN×2, USDC, AUSD, FDUSD, CETUS, NAVX, ALPHA, SEND, BLUE, SCA, TYPUS, DEEP, NS, BLUB, LOFI, ETH, AF_LP×2, STSUI, KOTO, BUCK, LP_TOKEN, BTC |
| Farm `AdminCap<DROP>` | `0x8b9a436268e71d35b7613c9eba09ab4776bb065134eae8cea0451af526bc340f` | owned by `0xa7caa2a3e8d4dc1d35297ce32e46c4b05fa990968384cad74571c983ad6e598a` (deployer EOA) |
| Pond `AdminCap` | `0xd602cfa0d2a6180c1979a3587a4589730f7b2b527746c152c5bb3f9168221d08` | owned by `0xbfd2e22f32d4bcaaf6f12f218fcc26488fdf63f338481e0d4f96e95160d61ba9` |
| `CenterPond<DROP>` | `0xf7b2c10e8f71abf8133debe9076176117a9bf8eac5d673b22f5bf9d27c6cc841` | shared; holds NAVI `AccountCap`, per-asset `Position` (Bucket strap + NAVI sheet) |
| `ButConvertor` | `0xa9a29be9bd67c96dabd8c8086e3e33d98fd30e91fb7f6f58dc990ae3936612b8` | `is_public=true`, rate `543090379` (0.543090379 BUT/DROP), reserve 9,301,105.59 BUT |
| DROP `TreasuryCap` | inside `PointCenter` | borrowable only with `AdminCap` (`point::borrow_treasury_cap`) |
| `Privilege` objects | **none ever created** (0 txs for `privilege::create/new`) | `point::mint`/`levy` unreachable |

### 2.3 Live value (DefiLlama prices, 2026-10-03; raw values at checkpoint 329,860,258)

| Bucket | USD |
|---|---|
| Idle pool balances (immediately payable) | **$89,417.68** |
| Credits → `SCALLOP_POND` (AFSUI/HASUI/CERT) | $8,461,885.85 |
| Credits → `NAVI_POND` (SUI/STSUI/BTC) | $7,525,432.40 |
| Credits → `NAVI_UNI_POND` (USDC/BLUE/DEEP/NS/…) | $102,735.10 |
| **Total** | **$16,179,471.03** |

The DefiLlama "$37.98M last-known" (2025-09-09) is stale: SUI/BTC/LST prices fell and ~$0.4–1M of pool balances were withdrawn in the interim. Full per-pool tables: `analysis/pool_values.json`, `analysis/prices.json`, `ci-out/state.json`.

---

## 3. The mechanism — why nothing is extractable (path-by-path)

The farm is a two-layer system:
1. **`DegenPool<POINT, ASSET>`** (farm package): holds `Balance<ASSET>` + a float-package `Sheet` of credits/debts. User stakes are recorded in `PointCenter.user_profiles[address].stakes[pool_id]`.
2. **Ponds** (NAVI/Scallop/Bucket): receive the pooled assets as loans (sheet credits) and repay them when users unstake.

Every candidate extraction path was traced in the Move bytecode and, where decisive, simulated:

| # | Candidate path | Gate(s) found | Proof |
|---|---|---|---|
| 1 | **Over-unstake** — stake 1 SUI, withdraw 2 | `point::fulfill_unstake` → `stake::sub` aborts `err_not_enough_to_unstake` | dry-run #2 PASS (CI) |
| 2 | **Non-depositor unstake** | `point::fulfill_unstake` → `err_account_not_found` if no profile/stake | dry-run #3 PASS (CI) |
| 3 | **Reuse / double-unstake** | `UnstakeResponse` is a no-drop hot potato; only consumer is `point::fulfill_unstake` (same tx) | bytecode + all dry-runs |
| 4 | **Forged identity** | `AccountRequest` is either `ctx.sender()` or `id_to_address(Account.id)`; profiles are keyed by wallet address (frontend uses `account::request(ctx)`); object IDs cannot be chosen | `float::account` disassembly |
| 5 | **Arbitrary-debtor loan** — v1/v7 `pool::loan_by_stake_res(pool, res)` with attacker-chosen debtor | `sheet.credits` must already contain the debtor, else `err_invalid_debtor`; live debtors are only NAVI_POND / NAVI_UNI_POND / SCALLOP_POND | dry-run #5 PASS (CI) |
| 6 | **Cross-version value mixing** — v7-created `StakeResponse` fed to v1 `loan_by_stake_res` (v1 float's `record_loan` auto-adds debtors) | rejected with `InvalidLinkage` (v1's linkage points at float v1; v7 values are not mixable) | dry-run #4 PASS (CI) |
| 7 | **Old-version bypass of the WrapperRule policy** — call v1 `pool::fulfill_stake/unstake` directly | `PointCenter.stake_policy/unstake_policy = [v7::wrapper::WrapperRule]`; the witness can only be constructed inside v7 `wrapper`, and v7's internal `pool::fulfill_*` calls carry the `pool_id` check | bytecode + policy read from live object |
| 8 | **Cross-pool unstake** (request pool A, fulfil pool B) | v7 `pool::fulfill_stake/unstake` check `request.pool_id == pool.id`; v7 wrapper re-checks `asset_type`; the only same-asset pair (two SUI pools) has an empty second pool (0 balance, 0 credits) | disassembly + live pool list |
| 9 | **Hot-potato neutralisation + fake-sheet loan** — dispose the temp `Sheet` via `dynamic_field::add` + `object::delete`, receive a Loan, keep coins | works mechanically (dry-run #1 PASS), but the Loan can only be created to an allow-listed pond debtor, so funds land in a pond sheet, never in attacker custody | dry-runs #1/#5 |
| 10 | **Permissionless pond withdrawals** (`withdraw_from_navi_v2/v3`, `withdraw_from_surplus`) | Permissionless, but only consumable with a `Collector` created by `pool::dun_by_unstake_req`; amount ≤ pool's real credit; the resulting `UnstakeResponse` must pass `point::fulfill_unstake` (per-user stake bound) | bytecode (pond v20/v23) |
| 11 | **Scallop pond** | `supply/withdraw/claim` all require `AdminCap` | disassembly |
| 12 | **DROP mint / inflated points** | `point::mint/levy` need a `Privilege` (none exist); `settle_user_points` pays from the 402K DROP buffer only for accrued points; **all `flow_rate = 0`** | live state + disassembly |
| 13 | **Admin-cap paths** (`loan_by_admin`, `borrow_treasury_cap`, `end_pool`, `remove_debtor`, pond `withdraw`) | require `AdminCap` held by deployer EOAs | live owners |
| 14 | **ButConvertor** | public, but requires `Coin<DROP>`; rate is correct (0.543090379 BUT/DROP; live `ConvertEvent`s match); 9.30M BUT reserve | live state + 20+ historical conversion events |

**The only confirmed mechanical oddity found:** a `Sheet` (which has `store` but no `drop`) can be neutralised by storing it in a dynamic field of a freshly-created `UID` and then `object::delete(uid)` (dry-run #1). This is a framework-level trick, not a farm bug; the farm's accounting prevents it from yielding value (path 9).

---

## 4. Live-state assessment (checkpoint 329,860,258)

- `PointCenter` version `943596890`; `claimable=true`; buffer `402,143,276,184,737` raw DROP; profiles 13,718.
- `stake_policy = unstake_policy = [0xf6248808…::wrapper::WrapperRule]`.
- SUI pool version `937212706`: idle 272,740,435,639 MIST; credits to NAVI_POND 1,328,357,000,000,000 MIST and NAVI_UNI_POND 38,531,998,520,030 MIST.
- All pool `flow_rate` values are `0` (checked in all 33 `PoolState`s) — emissions permanently off.
- Farm AdminCap owner `0xa7caa2a3…`; pond AdminCap owner `0xbfd2e22f…`; both EOAs still exist on-chain.
- DROP: 17,126,247.73 supply; no DefiLlama price; BUT (the redemption token) = $0.000693.

---

## 5. What an attacker can / cannot do (exact call paths)

**Cannot (all proven above):** move any pool funds to themselves beyond their own recorded stake; borrow from a pool to an arbitrary debtor; claim other users' points; mint DROP; call any pond/admin function without the respective cap; exploit old package versions (policy + `InvalidLinkage`).

**Can (unprivileged, own funds only):**
- Stake/unstake their own funds via `0xf6248808…::wrapper::wrap_*` + `fulfill_*` + `point::fulfill_*`.
- If their stake is lent to a NAVI pond, self-service unstake via `pool::dun_by_unstake_req` → `0x8cf204f1…::pond::withdraw_from_navi_v3` (permissionless) → `pool::collect` → `wrapper::fulfill_unstake`; for NAVI_POND credits via `withdraw_from_surplus`.
- Claim their own accrued DROP (`point::claim`) and redeem it for BUT (`convertor::convert_to_but`, public).
- Anyone can donate (`pool::supply`), add DROP rewards, or waste gas.

**Cannot yet verified as user-recoverable:** pools credited to `SCALLOP_POND` (AFSUI/HASUI/CERT ≈ $8.46M) have **no permissionless repayment path** (Scallop pond `withdraw` is AdminCap-only) — those users can only recover from the small idle balances unless the admin acts.

---

## 6. PoC / dry-run verification

All tests are `sui_dryRunTransactionBlock` simulations from the deployer's public address (gas coin used only as a dry-run reference; **nothing signed or sent**).

| # | Test | Expected | Result |
|---|---|---|---|
| 0 | dry-run pipeline probe | success | PASS |
| 1 | dispose `Sheet` via `dynamic_field`+`object::delete` | success | PASS |
| 2 | stake 1 SUI then unstake 2 SUI | `stake::err_not_enough_to_unstake` | PASS |
| 3 | unstake with no stake | `point::err_account_not_found` | PASS |
| 4 | v7 `StakeResponse` → v1 `loan_by_stake_res` | `InvalidLinkage` | PASS |
| 5 | v7 `loan_by_stake_res` unknown debtor `bool` | `pool::err_invalid_debtor` | PASS |

- **6/6 PASS**, CI run: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37137479809**
- Artifacts: `ci-out/dryruns.txt`, `ci-out/state.json` (also in `ci-artifacts/result-bucket-farm/`).
- Scripts: `poc-node/dryruns.js`, `poc-node/statedump.js`, runner `ci/run.sh` (read-only; no secrets).

---

## 7. Verdict and residual / latent risk

- **E-U (external unprivileged): $0.00 — high confidence.**
- **H-O (self-service, bounded by each user's own stake): $89,417.68 of idle balances are immediately recoverable; a further ~$102.7K of NAVI_UNI_POND-credited funds is conditionally recoverable via the permissionless `withdraw_from_navi_v2/v3` path (subject to NAVI liquidity); ~$7.53M NAVI_POND-credited funds are recoverable permissionlessly only to the extent the CenterPond's Bucket surplus holds them.**
- **P (privileged): the remaining ~$16.09M is admin-reachable** (farm + pond AdminCaps held by two EOAs).
- **S (stuck/bricked): none proven today.** If the admin EOAs' keys are lost, the `SCALLOP_POND`-credited user stakes (~$8.46M) and the NAVI_POND credits become effectively stuck.

**Latent risk to watch:** (a) any future `add_rule`/`set_flow_rate` changes; (b) any new package upgrade re-opening a value path; (c) DROP markets (a cheap DROP could drain the $6.45K BUT reserve — small); (d) NAVI/Scallop liquidity for user withdrawals.

**Blockers / limitations:** no `sui` CLI or local validator was used; proofs are dry-run simulations plus bytecode analysis. The farm's package history (7 versions) was fully disassembled from chain, but the exact historical dates of each upgrade were not reconstructed. Admin key control is not verifiable from public data.

---

## 8. Methodology & sources

- **Live reads:** Sui JSON-RPC (`sui_getObject`, `suix_queryTransactionBlocks`, `sui_dryRunTransactionBlock`) against `sui.blockpi.network` / `sui-rpc.publicnode.com` / `sui-mainnet.nodeinfra.com`; Sui GraphQL (`graphql.mainnet.sui.io`) for `MoveModule.disassembly`, `packageVersions`, and transaction JSON.
- **Bytecode audit:** all modules of all 7 farm versions, all 4 float versions, DROP, pond v20/v23, Scallop pond, ButConvertor v1/v2 — full disassembly saved under `analysis/`.
- **Prices:** DefiLlama `coins.llama.fi/prices/current` (2026-10-03); BUT/DROP checks.
- **Corpus:** `zombie_hunt/FINDINGS.md` H-01; DefiLlama `bucket-farm` protocol JSON + archived adapter (`POINT_CENTER_ID`); `farm.bucketprotocol.io` JS bundle (object IDs + call flows).

### Caveats
1. Dry-runs simulate against latest state but do not prove that a *submitted* transaction succeeds (they do execute the same Move code; no signatures were used).
2. NAVI/Bucket/Scallop position liquidity was not exhaustively valued; H-O figures for lent funds are conditional on those protocols.
3. Some low-value assets (AF_LP×2, LP_TOKEN, KOTO, ALPHAFI_LP) have no DefiLlama price; they are excluded (small).
4. The `total_stake` figures in `ci-out/state.json` are `null` (they live in `PointCenter.pool_states`, not the pool objects); use `analysis/pool_states.json` for stakes.

### Files index
- `README.md` — this report; `summary.json` — machine-readable summary
- `analysis/` — RPC client, pool states/values, prices, all disassemblies (`disasm_*`), `all_versions.json`, `version_changes.json`
- `poc-node/` — `dryruns.js` (6 proofs), `statedump.js`; `ci/run.sh` — CI runner; `ci-out/`, `ci-artifacts/`, `ci-log.txt` — CI evidence
- CI: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37137479809

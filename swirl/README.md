# C2-45 — Swirl stIOTA (IOTA L1): cap-less `rebalance*` surface, live-extraction assessment

**Date:** 2026-10-10 · **Chain:** IOTA L1 (Rebased / Move-based; chain id `6364aad5`) ·
**Status:** read-only; devInspect dry-runs only; **no mainnet transactions, no signatures, no secrets**.
Snapshot: checkpoint **201,819,434**, epoch **522** (CI proof run); earlier local reads at checkpoint 201,817,112.

---

## 1. TL;DR

| target | live value | live extractable (unprivileged) | why closed / open | latent risk |
|---|---|---|---|---|
| Swirl `NativePool` `0x02d641d7…a8056` (stIOTA liquid staking) | **74,386,217.59 IOTA staked + 6,631,092.04 IOTA rewards ≈ $4,235,564** (H-O, holders' own redemption) | **$0.00** | cap-less `rebalance`/`rebalance_from_validator`/`rabalance_overstaked` only move funds validator → `pool.pending` → re-stake; **no caller payout**; every payout/admin path requires `OwnerCap`/`OperatorCap` | pending-exclusion ratio distortion bounded at **≈11,715 IOTA ≈ $612** — requires filling 13.6M IOTA of validator headroom + an external numerator-restore event; not practically extractable |

## 2. Total live extractable now

**E-U (external unprivileged): $0.00 — confidence: HIGH.**

- **H-O** (holder self-service redemption): **$4,235,563.74** (81,017,309.622458 IOTA at DefiLlama price $0.05227974, ts 1791597174) — stIOTA holders' own capital; redeemable via `native_pool::unstake`.
- **P** (privileged-only): $0 — fee ledger `collectable_fee` = 0; treasury receiver holds 49.99998 IOTA dust.
- **S** (stuck): $0 — `paused = false`; all functions live.

## 3. The finding in exact terms

C2-45 flagged Swirl for **cap-less `rebalance*` functions** with **cap-gated sensitive functions**.
Verified against deployed bytecode:

- Live package **v9** `0xa38a034356187b52c603282198fc831f0f710e16a61b141986697372ef16b292`
  (pool `version` field = 9; `assert_version` accepts {8,9}).
- Cap-less public entry points (v9 `native_pool`):
  - `rebalance(&mut NativePool, &mut IotaSystemState, &mut TxContext)` — unstakes `u64::MAX` from every priority-0 validator, joins the coin to `pool.pending`, then `stake_pool()` re-stakes it.
  - `rebalance_from_validator(pool, system, address, u64, ctx)` — same, caller-chosen validator and amount; **requires `address ∈ get_bad_validators()`** else `abort 112`.
  - `rabalance_overstaked(pool, system, ctx)` — unstakes only per-validator amounts above 4,000,000 IOTA (≤ half the excess), joins to pending, re-stakes. Currently a no-op (no validator > 4M).
  - `stake`/`unstake` — consume only the caller's own `Coin<IOTA>`/`Coin<CERT>`; `unstake` pays `tx_context::sender()`.
  - `publish_ratio` — emits an event only.
- All value-paying/config functions are cap-gated: `collect_fee`/`collect_fee_new` (OwnerCap, pays a chosen address), `set_pause`, `change_*`, `update_rewards*` (Operator/OwnerCap), `add_pending`, `update_validators`, `add_points`/`delete_points`, `migrate`.
- **Old versions v1–v7** are deployed and callable but every pool-touching entry point aborts via `assert_version` (pool.version 9 ∉ {N−1,N}) — see `analysis/entry_function_matrix.json`. `update_rewards_revert` (v1–v9) skips `assert_version` but is OwnerCap-only.
- **No unguarded value-moving function exists in any of the 8 deployed versions.**

## 4. Live-state assessment (all read from public RPC)

| item | value / address | source |
|---|---|---|
| `NativePool` (shared) | `0x02d641d7b021b1cd7a2c361ac35b415ae8263be0641f9475ec32af4b9d8a8056`; object version 836,154,089 (local read); `total_staked` 74,386,217.586698839 IOTA; `total_rewards` 6,631,092.035759532; `pending` 0.046442297; `collectable_fee` 0; `paused` false; `version` 9 | `iota_getObject`, checkpoint 201,817,112 / CI 201,819,434 |
| CERT metadata (shared) | `0x8c25ec843c12fbfddc7e25d66869f8639e20021758cac1a3db0f6de3c9fda2ed`; `total_supply` 69,280,534.211951268 stIOTA | `iota_getObject` |
| stIOTA coin | `0x3467…7be68c::cert::CERT`; CoinMetadata `0xc52f4441ce99aade4eb41b898dafb23ec59aa7c36a208a329034f7f18fcc22ab` (9 decimals, "Staked IOTA") | `iotax_getCoinMetadata` |
| OwnerCap | `0x024b8ee182db98e727c4ceca0c5c7202e92933dd96d2a92c38a28eaecb632f52` → owner `0x119191cd04c303b5cd872868a1898fe205c1eb9eaee9fb97c1ee87c943e40066` | `iota_getObject` |
| OperatorCap | `0xa78c4b44ea49620200994ba70712074e73675c4bb64989f35bb09dae6f178a5e` → owner `0x12e6e7b62250a5eb6bc0a8021fb9cf9635ebcbe433cdc2643fc315708f4e18d1` | `iota_getObject` |
| Mint authority | none as an object: `cert::mint` is `public(friend)` (only `native_pool::stake` can mint) | v9 bytecode |
| "bad" validator (priority 0) | `0xd7a5275f14f5297774fdd93cb5691045b38dab9f0a1870f5a1da79706b9d69e2` — 1,948,434.338 IOTA staked (marked priority 0 by the operator on 2026-10-09) | `iota_getObject` vaults + `ValidatorPriorUpdated` events |
| validators / vaults | 24 entries; 22 vaults; **15 vaults exactly at the 4,000,000 IOTA cap** (independently re-verified); re-stake headroom ≈ 13,613,730 IOTA | dynamic-field walk (`analysis/vaults_state.json`) |
| system objects | `IotaSystemState` `0x5`, `Clock` `0x6` | `iota_getObject` |
| treasury/fee receiver | `0x5b9507f5a0f840f5c203969cdf4ecc50d80930be882948fe0b06f82421f18c0c` — 49.9999804 IOTA (fees swept; lifetime `collected_rewards` 26,682.09 IOTA) | `iotax_getBalance`, `FeeCollectedEvent` |
| price used | $0.05227973819565595 (DefiLlama `coingecko:iota`, ts 1791597174) | `coins.llama.fi` |

## 5. What an attacker can / cannot do

**Can (verified by devInspect from random `0x1111…1111`, no caps, no stake — read-only simulation):**
1. Call `native_pool::rebalance` → **success**; it unstakes the bad validator's 1.95M IOTA from the system staking pool and re-stakes across the other validators. **Nothing is credited to the sender** (no IOTA balance change; no transfer in effects).
2. Call `rebalance_from_validator(bad_validator, amount)` → **success** (same internal movement).
3. Call `rabalance_overstaked` → **success**, no-op today.
4. Call `stake`/`unstake` with their own coins at the floor-rounded ratio.

**Cannot:**
1. Get any payout from `rebalance*` — funds stay in the pool (`pending` → re-stake); there is no recipient parameter.
2. Call `rebalance_from_validator` on a healthy validator → **abort 112** (devInspect-confirmed).
3. Call `collect_fee` → **abort 911** always (v9 deprecated stub; devInspect-confirmed). The live fee payout path `collect_fee_new`/`collect_fee_non_entry` transfers `Coin<IOTA>` to a chosen address but requires `&OwnerCap` (object owned by `0x119191cd…`; a foreign sender cannot supply it). Same class of gate for `set_pause`, `update_rewards`, `update_validators`, `add_pending`, `change_*`, `migrate`.
4. Profit from share math: `to_shares`/`from_shares` both floor; round-trip `from_shares(to_shares(C)) = C − 1` nano (verified for C ∈ {1, 10³, 10⁶, 10⁸ IOTA}). `min_stake = 1 IOTA` blocks the min-1-share edge.
5. Use old packages v1–v7: `assert_version` aborts (pool.version = 9).
6. Redirect rewards: rewards only enter the pool via OperatorCap `update_rewards` (≥12 h apart, ≤ +743,862 IOTA per call); there is no permissionless "claim" that pays a caller.

**Latent only (not counted as extractable):** if a large `pending` existed, `get_ratio` excludes it, so new stakers would mint at an inflated shares/IOTA ratio. Quantified upper bound: pending X = bad-validator stake 1.948M IOTA → max profit `X²/4N ≈ 11,715 IOTA ≈ $612` at C = X/2; requires filling ~13.6M IOTA of validator headroom with the attacker's own capital (≥ $700k) and an external event to restore the numerator before redeeming. Today `pending` = 0.046 IOTA dust.

## 6. PoC / verification

Non-EVM chain → no Foundry; proof is a **read-only `devInspectTransactionBlock` harness** in
`ci/dryrun.mjs`, run on GitHub Actions (and reproduced locally):

- CI run: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38015234723** (conclusion: success; artifact `result-swirl.zip`, 3 files)
- Tests: **5/5 expected outcomes** at checkpoint 201,819,434 / epoch 522:
  - `rebalance_public_no_cap` → success (random sender; no payout)
  - `rebalance_from_validator_bad` → success
  - `rebalance_from_validator_good_must_abort` → failure, Abort Code **112**
  - `rabalance_overstaked_public` → success (no-op)
  - `collect_fee_no_cap` → failure, Abort Code **911**
- Round-trip math: gain = **−1 nano** for all four sizes.
- Pending-exclusion bound: **11,714.769310375 IOTA ≈ $612.45**.
- Artifacts: `ci-out/state.json`, `ci-out/dryrun_results.json`, `ci-out/dryrun.log` (also in `ci-artifacts/result-swirl/`).
- **Independent verification** (separate child agent, read-only RPC, checkpoint 201,829,142):
  `analysis/independent-verification.md` — full-package adversarial sweep of all 5 modules found
  **no cap-less path that pays the caller or an arbitrary address**; headline $0 **CONFIRMED**
  (one secondary count corrected: 15 vaults at the 4M cap, not 16).

Static evidence: full bytecode disassembly of all 8 deployed package versions in
`analysis/disassembly*/`; per-version entry-function matrix in `analysis/entry_function_matrix.json`;
per-validator vault dump in `analysis/vaults_state.json`.

## 7. Verdict & residual risk

**Closed for external unprivileged extraction ($0).** The "cap-less `rebalance*`" surface is real
and callable by anyone, but it is economically inert: it is a public maintenance path that only
re-stakes the protocol's own funds. The funds ($4.24M) belong to stIOTA holders and are redeemable
by them (H-O). Residual risks, none currently extractable:

1. **Owner/Operator key risk** — both caps are single `AddressOwner` objects. If either key is
   compromised, the holder can `collect_fee`, change fees/validators, pause, or (Owner) migrate to
   a malicious package. That is a P-class risk, out of scope for E-U; recommend monitoring both
   addresses and verifying they are multisigs (docs claim multisig ops; not verifiable via RPC).
2. **Pending-exclusion latent accounting** — bounded ≈ $612, needs attacker to first lock ~$700k
   at fair value and an external re-stake event; monitor `pending` growth.
3. **Reward-update timing** — operator updates ~daily (Δ≈23k IOTA); no public mempool on IOTA,
   so no reliable unprivileged front-run.
4. **Operator correctness** — `update_rewards` accepts operator-reported values up to
   +743,862 IOTA per 12 h; over-reporting inflates the ratio and can impair unstaking
   (Hacken F-2025-9133 class). Operator-gated, not attacker.

## 8. Methodology & sources

- **RPC:** `https://api.mainnet.iota.cafe` (public, keyless) — `iota_getObject`,
  `iota_getNormalizedMoveModulesByPackage`, `iotax_queryEvents`, `iotax_getDynamicFields`,
  `iotax_queryTransactionBlocks`, `iotax_getBalance`, `iota_devInspectTransactionBlock`
  (via `@iota/iota-sdk` v1.16.0 in CI).
- **Bytecode audit:** package disassembly for v1–v7 + v9 (all modules: `native_pool`,
  `validator_set`, `math`, `cert`, `ownership`), read line-by-line for caps, version gates,
  rounding, and fund flow.
- **Version chain:** `native_pool::MigratedEvent` events (1→2→…→7→9; no v8).
- **Roles:** `ValidatorPriorUpdated`, `RewardsUpdated`, `StakedEvent`, `UnstakedEvent`,
  `FeeCollectedEvent` events + object owners.
- **Value:** on-chain fields + DefiLlama price API; DefiLlama TVL adapter for Swirl reads the same
  `NativePool` object (confirms it is the protocol's sole custody object).
- **Context:** Hacken audit PDF for ANKR StakeFi/Swirl (8 pages; findings F-2025-9094/9095/9098/9099/9133,
  0 critical) — corroborates that known issues are privileged/accounting, not unprivileged drains.

**Caveats / limitations**
- Cap-holder addresses (`0x119191cd…`, `0x12e6e7b6…`) are plain address owners on RPC; whether they
  are native multisigs could not be verified from public RPC.
- Full-chain object enumeration for "other Swirl custody" was not possible (no public indexer);
  coverage relies on the version chain, events, docs, and the DefiLlama adapter.
- USD values move with IOTA price; token amounts are exact at the stated checkpoints.
- devInspect simulates against latest state; it never commits (no state change, no gas, no signature).

## 9. Files index

```
swirl/
├── README.md                      # this report
├── summary.json                   # machine-readable summary
├── analysis/
│   ├── object-cap-map.md          # packages, objects, caps, roles, live accounting
│   ├── extraction-analysis.md     # vector-by-vector extraction analysis
│   ├── entry_function_matrix.json # cap/version/transfer matrix for every fn of every version
│   ├── vaults_state.json          # per-validator total_staked / epoch counters
│   ├── native_pool_object*.json   # pool object snapshots
│   ├── cert_metadata_state.json   # CERT supply
│   ├── normalized_modules*.json   # ABIs (v1, v9)
│   ├── disassembly*/              # full Move bytecode, all modules, all versions
│   ├── migrated_events.json, rebalance*_txs.json, rewards_updated_50.json, fee_collected_events.json
├── ci/                            # dryrun.mjs + run.sh (read-only devInspect proofs)
├── ci-out/                        # proof outputs (state, results, log)
├── ci-artifacts/                  # downloaded CI artifacts
└── ci-log.txt                     # full GitHub Actions log
```

# Swirl stIOTA (C2-45) — IOTA L1 object / package / capability map

Read-only reconnaissance. All data from public IOTA mainnet RPC `https://api.mainnet.iota.cafe`.
Snapshot: checkpoint **201,817,112**, epoch **522** (IOTA Rebased, Move-based L1; chain id `6364aad5`).
Original type/module address (stable across all versions): `0x346778989a9f57480ec3fee15f2cd68409c73a62112d40a3efd13987997be68c` (referred to below as `0x3467…7be68c`).

## 1. Package version chain (the "old-version" surface)

Swirl uses **publish-new-package + OwnerCap-gated migrate** versioning (IOTA style, not Sui
same-object upgrades). Every package version's entry functions call `assert_version(pool)` which
accepts `pool.version ∈ {N-1, N}` (N = that package's own version constant). The pool's `version`
field is currently **9**, so only the **v9** package executes; v1–v7 abort with code 1.

| ver | package object ID | pool.version accepted | status today |
|---|---|---|---|
| v1 | `0x346778989a9f57480ec3fee15f2cd68409c73a62112d40a3efd13987997be68c` | {0,1} | deployed, version-gated out |
| v2 | `0xa4682f62428176133307b7f3f04c468b99d33a3dc6cf46efa266d9d3ee4aa933` | {1,2} | version-gated out |
| v3 | `0xe7c1268b45053e57db0007c744138b4349597f8d36d6f0ad1296377f535dc6f4` | {2,3} | version-gated out |
| v4 | `0xb8a3dd2c4754a15e656c2dbabbeb86afef51bfafba79d6fe52310754930ba918` | {3,4} | version-gated out |
| v5 | `0x2b36d4f76396d34c509b839bffe1c4e27c48e20f3c9c3ed2187588651b613841` | {4,5} | version-gated out |
| v6 | `0x315d2c4f5b1c408d6f8e3700218c1d83ab1a422bb83a4c99097d501271ec2427` | {5,6} | version-gated out |
| v7 | `0xd282b91f8e6dc8ca5b381d22754d5423e9049851a0f6777240c3be2b3b2bb7a7` | {6,7} | version-gated out |
| v8 | — (migration jumped 7 → 9; no v8 package) | — | — |
| **v9** | **`0xa38a034356187b52c603282198fc831f0f710e16a61b141986697372ef16b292`** | **{8,9}** | **LIVE** |

Migration events (`native_pool::MigratedEvent`, `iotax_queryEvents`): 1→2, 2→3, 3→4, 4→5, 5→6, 6→7, 7→9.
Migrate txs all sent by OwnerCap holder `0x119191cd…`.

## 2. Shared objects

| object | ID | type | notes |
|---|---|---|---|
| NativePool | `0x02d641d7b021b1cd7a2c361ac35b415ae8263be0641f9475ec32af4b9d8a8056` | `0x3467…7be68c::native_pool::NativePool` | shared (initial_shared_version 19); object version 836,154,089; holds all staked funds accounting |
| CERT Metadata | `0x8c25ec843c12fbfddc7e25d66869f8639e20021758cac1a3db0f6de3c9fda2ed` | `0x3467…7be68c::cert::Metadata<…::cert::CERT>` | shared; `total_supply` = 69,280,578.756434085 stIOTA; `version` 1 |
| CERT CoinMetadata | `0xc52f4441ce99aade4eb41b898dafb23ec59aa7c36a208a329034f7f18fcc22ab` | `0x2::coin::CoinMetadata<…::cert::CERT>` | Immutable; symbol `stIOTA`, 9 decimals |
| IotaSystemState | `0x5` | `0x3::iota_system::IotaSystemState` | system staking state |
| Clock | `0x6` | `0x2::clock::Clock` | system |

The `NativePool` contains `validator_set.vaults` — a `Table<address, Vault>` (table UID
`0x6539a1c44752b7e427d747468da5fb131775fde3e8abb8b1e8e8d265153ede5b`, size 22) whose dynamic
fields are the per-validator `Vault { total_staked, stake_epoch, staked_in_epoch, stakes: ObjectTable<u64, StakedIota> }`.
Full vault dump: `analysis/vaults_state.json`.

## 3. Capabilities (who can do what)

There is **no MintCap / TreasuryCap object**: `cert::mint` and `cert::burn_*` are `public(friend)`,
callable only from `native_pool` inside the same package. Mint authority == the pool's `stake()`
logic. There is no `UpgradeCap`; upgrades happen by publishing a new package object (above) and
calling the OwnerCap-gated `migrate`.

| cap | object ID | owner | powers |
|---|---|---|---|
| OwnerCap | `0x024b8ee182db98e727c4ceca0c5c7202e92933dd96d2a92c38a28eaecb632f52` | `0x119191cd04c303b5cd872868a1898fe205c1eb9eaee9fb97c1ee87c943e40066` | `change_base_reward_fee`, `change_min_stake`, `change_max_validator_stake_per_epoch`, `update_rewards_threshold`, `update_rewards_revert`, `set_pause`, `collect_fee`/`collect_fee_new`, `migrate` (pool + cert), `transfer_owner` |
| OperatorCap | `0xa78c4b44ea49620200994ba70712074e73675c4bb64989f35bb09dae6f178a5e` | `0x12e6e7b62250a5eb6bc0a8021fb9cf9635ebcbe433cdc2643fc315708f4e18d1` | `update_validators`, `update_rewards`, `add_pending`, `add_points`, `delete_points`, `collect_fee`, `transfer_operator` |

Swirl docs state validator management/backend ops are run through multi-signature wallets; the two
cap-holding addresses are plain `AddressOwner` objects (whether they are native multisig addresses
was not determinable from RPC — noted as a limitation).

Fee/treasury receiver observed in `FeeCollectedEvent`s: `0x5b9507f5a0f840f5c203969cdf4ecc50d80930be882948fe0b06f82421f18c0c`
(current IOTA balance 49.9999804 IOTA — fees are swept out regularly; lifetime fee ledger
`collected_rewards` = 26,682.091711182 IOTA).

## 4. v9 entry-point surface (live)

Cap-less, mutating (any address can call):
- `native_pool::rebalance(&mut NativePool, &mut IotaSystemState, &mut TxContext)` — unstakes `u64::MAX` from all priority-0 ("bad") validators, joins to `pool.pending`, then `stake_pool()` re-stakes.
- `native_pool::rebalance_from_validator(&mut NativePool, &mut IotaSystemState, address, u64, &mut TxContext)` — same, but caller picks one validator (must be in `get_bad_validators()`, else abort 112) and an amount.
- `native_pool::rabalance_overstaked(&mut NativePool, &mut IotaSystemState, &mut TxContext)` — unstakes only the amount above 4,000,000 IOTA per validator (capped at half the excess), joins to pending, re-stakes. No-op while no validator exceeds 4M.
- `native_pool::stake(...)` / `native_pool::unstake(...)` — move only the caller's own `Coin<IOTA>` / `Coin<CERT>`; `unstake` transfers the redeemed IOTA to `tx_context::sender()`.
- `native_pool::publish_ratio(&NativePool, &Metadata<CERT>)` — read-only; emits `RatioUpdatedEvent`.

Cap-gated (attacker cannot call):
- `collect_fee`, `collect_fee_new`, `set_pause`, `change_*`, `update_rewards*`, `add_pending`, `update_validators`, `add_points`, `delete_points`, `migrate`, `transfer_owner/operator`.

`assert_version` (v9) accepts pool.version ∈ {8,9}; live pool version = 9 → passes.
`when_not_paused`: live `paused = false` → passes.

## 5. Live accounting snapshot (checkpoint 201,817,112, epoch 522)

| field | value (IOTA) |
|---|---|
| total_staked | 74,386,217.586698839 |
| total_rewards | 6,631,092.035759532 |
| pending | 0.046442297 (rounding dust) |
| collectable_fee | 0 |
| collected_rewards (lifetime fees) | 26,682.091711182 |
| cert total supply | 69,280,578.756434085 stIOTA |
| implied value / stIOTA | 1.168990 IOTA |
| validators | 24 (22 with vaults; 15 exactly at the 4,000,000 IOTA cap) |
| priority-0 ("bad") validator | `0xd7a5275f14f5297774fdd93cb5691045b38dab9f0a1870f5a1da79706b9d69e2` — 1,948,434.338 IOTA staked (set priority 0 by the operator on 2026-10-09) |
| re-stake headroom to 4M cap | ≈ 13,613,730 IOTA total |

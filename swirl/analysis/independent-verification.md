# C2-45 — Independent Verification (Swirl stIOTA, IOTA L1)

**Verdict on headline claim ("external unprivileged attacker can extract $0 live"): CONFIRMED.**

- Verifier: independent child subagent; read-only.
- Method: keyless public RPC `https://api.mainnet.iota.cafe` (JSON-RPC). Only read methods used: `iota_getObject` (showContent/showOwner/showType), `iotax_getDynamicFields`, `iota_getLatestCheckpointSequenceNumber`. No transaction was signed or sent; no devInspect was needed.
- Checkpoints observed: **201825516** (first) and **201829142** (last / latest).

## 1. Package, pool, metadata, caps (target facts)

| Fact | Verdict | Evidence |
|---|---|---|
| Live package `0xa38a034356187b52c603282198fc831f0f710e16a61b141986697372ef16b292` | CONFIRMED | `iota_getObject` returns `content.dataType = "package"`; modules: `cert`, `math`, `native_pool`, `ownership`, `validator_set`. Its `assert_version` constant = 9 (matches live pool version). |
| NativePool shared `0x02d641d7b021b1cd7a2c361ac35b415ae8263be0641f9475ec32af4b9d8a8056` | CONFIRMED | Type `0x3467…be68c::native_pool::NativePool`; owner `Shared {initial_shared_version: 19}`; `fields.version = "9"`. |
| CERT Metadata shared `0x8c25ec843c12fbfddc7e25d66869f8639e20021758cac1a3db0f6de3c9fda2ed` | CONFIRMED | Type `0x3467…be68c::cert::Metadata<…::cert::CERT>`; Shared (init version 19); `version = "1"`; `total_supply = 69,280,534,211,951,268`. |
| OwnerCap `0x024b8e…b632f52` owner | CONFIRMED | `ownership::OwnerCap`, `AddressOwner 0x119191cd04c303b5cd872868a1898fe205c1eb9eaee9fb97c1ee87c943e40066`. |
| OperatorCap `0xa78c4b…178a5e` owner | CONFIRMED | `ownership::OperatorCap`, `AddressOwner 0x12e6e7b62250a5eb6bc0a8021fb9cf9635ebcbe433cdc2643fc315708f4e18d1`. |
| Bad (priority 0) validator `0xd7a5275f14f5297774fdd93cb5691045b38dab9f0a1870f5a1da79706b9d69e2` | CONFIRMED | `validator_set.validators` is `VecMap<address,u64>` of 24 entries; exactly one entry has value `0` — `0xd7a5275f…b9d69e2`. `validator_set::get_bad_validators` returns addresses whose priority `== 0`. (Minor anomaly, irrelevant to extraction: priority `18` appears twice and `17` is absent.) |

## 2. Claim 1 — entry-function inventory and value flow

### native_pool entry functions (18)

| Entry | Cap parameter | Calls `assert_version` | Value out |
|---|---|---|---|
| `change_max_validator_stake_per_epoch` | `&OwnerCap` | no | none |
| `change_min_stake` | `&OwnerCap` | yes | none |
| `change_base_reward_fee` | `&OwnerCap` | yes | none |
| `update_validators` | `&OperatorCap` | yes | none |
| `update_rewards_threshold` | `&OwnerCap` | yes | none |
| `update_rewards_revert` | `&OwnerCap` | no | none |
| `update_rewards` | `&OperatorCap` | yes | none |
| `publish_ratio` | **none** | no | event only (`RatioUpdatedEvent`); no mutation, no coin |
| `stake` | **none** | via `stake_non_entry` | `Coin<CERT>` → `public_transfer` to `tx_context::sender` (user pays `Coin<IOTA>` in) |
| `add_pending` | `&OperatorCap` | no | joins `Coin<IOTA>` into `pending` |
| `unstake` | **none** | via `unstake_non_entry` | `Coin<IOTA>` → `public_transfer` to `tx_context::sender` (user pays `Coin<CERT>` in) |
| `rebalance` | **none** | yes | see below — into `pending`, re-staked |
| `rebalance_from_validator` | **none** | yes | see below — into `pending`, re-staked |
| `rabalance_overstaked` | **none** | yes | see below — into `pending`, re-staked |
| `collect_fee_new` | `&OwnerCap` | yes | `public_transfer<Coin<IOTA>>` to arbitrary `Arg2: address` — **cap-gated** |
| `collect_fee` | `&OwnerCap` | no | body is `LdU64(911); Abort` — always aborts |
| `set_pause` | `&OwnerCap` | no | none |
| `migrate` | `&OwnerCap` | no | sets version to 9 (aborts if version < 9) |

Other modules' entries: `cert::migrate(&mut Metadata<CERT>, &OwnerCap)` (cap-gated, sets metadata version 1); `ownership::transfer_owner/transfer_operator` (cap taken by value, requires new owner ≠ sender, no funds); `math` has no entry; `validator_set` has no entry (mutators are `public(friend)`: `create`, `update_validators`, `add_stake`, `remove_stakes`).

### rebalance family — trace of `Coin<IOTA>` (CONFIRMED)

- `rebalance` (bytecode 0:–27:): `assert_version`, `when_not_paused`, `get_bad_validators`, then `unstake_amount_from_validators(pool, sys, 18446744073709551615, bad_validators, ctx): Coin<IOTA>` → `coin::into_balance` → `balance::join` into `NativePool.pending` (offset 18–21) → `stake_pool(...)`. **No `public_transfer`, no `tx_context::sender` anywhere in this function.**
- `rebalance_from_validator` (offsets 0–43): requires `Arg2 ∈ get_bad_validators` else `abort 112`; same path into `pending` → `stake_pool`. Caller-supplied `u64` amount cannot redirect funds; it only sizes the unstake.
- `rabalance_overstaked` (offsets 0–86): iterates validators, excess over `4e15` (capped at `4e15/2`), `validator_set::remove_stakes` → `Balance<IOTA>` → `balance::join` into `pending` → `stake_pool`.
- `unstake_amount_from_validators` (150 lines): splits/joins balances, `validator_set::remove_stakes`, updates `total_staked`, returns `Coin<IOTA>` to its **caller function only**; no transfer/sender. `stake_pool` (183 lines) splits `pending`, `iota_system::request_add_stake_non_entry` to a validator address taken from pool state, `validator_set::add_stake`. **Full-module scan found zero `public_transfer`/`tx_context::sender` in `stake_pool` or `unstake_amount_from_validators`.**

## 3. Claim 2 — `assert_version` constants

- v9 `native_pool::assert_version`: `version == (9-1) || version == 9` → accepts **{8, 9}**. CONFIRMED (bytecode: `LdConst[0]=9; LdU64(1); Sub; Eq` then `version == 9`; abort code 1 otherwise). Live `pool.version = 9`, so v1–v7 packages (different constants) abort.
- Spot-check v1 package `0x346778989a9f57480ec3fee15f2cd68409c73a62112d40a3efd13987997be68c`: `assert_version` accepts **{0, 1}**. CONFIRMED.
- `cert::assert_version` requires `Metadata.version == 1`; live metadata version = 1 (so mint/burn work; both are `public(friend)`, not externally callable).

## 4. Claim 3 — cap ownership

CONFIRMED; see table above. Both caps are `AddressOwner` objects held by the claimed addresses; no unprivileged reference to either cap exists in the package.

## 5. Claim 4 — validators and vaults

- Priorities: 24 validators, one per priority 0–23 except duplicate 18 / missing 17; **exactly one priority-0 validator** `0xd7a5275f…b9d69e2`. CONFIRMED.
- Vaults table `0x6539a1c44752b7e427d747468da5fb131775fde3e8abb8b1e8e8d265153ede5b` (child of pool): `size = 22`; walked all 22 dynamic fields and read each `Vault.total_staked`:
  - **15 vaults at exactly `4,000,000,000,000,000`** (not 16 as claimed);
  - 1 vault at `0` (`0xd4e16657…f6326a`);
  - 6 partial: `3,742,522,772,648,945`; `3,552,979,895,806,307`; `3,057,470,030,858,707`; `1,948,382,264,372,249` (the priority-0 validator); `1,737,575,093,223,820`; `347,287,529,788,811`.
  - Sum of vaults = `74,386,217,586,698,839` = `pool.total_staked` **exactly** (internal consistency).
- **Contradiction found (secondary claim):** "16 vaults at exactly 4e15" is not what the live object shows at checkpoint 201825516 — it is 15 of 22 (the claim may stem from a different observation time; this does not affect the $0 extraction verdict).

## 6. Claim 5 — adversarial sweep (cap-less payout hunt)

Full-package scan for `public_transfer` / `transfer::` / `tx_context::sender` / `share_object` / `freeze_object` across **all** functions of **all** five modules:

- `native_pool`: the only hits are (a) `init` `share_object<NativePool>`; (b) `stake` entry → `public_transfer<Coin<CERT>>` to **sender**; (c) `stake_non_entry` sender used only for the `StakedEvent` field; (d) `unstake` entry → `public_transfer<Coin<IOTA>>` to **sender**; (e) `unstake_non_entry` sender only for `UnstakedEvent`; (f) `collect_fee_new` → `public_transfer<Coin<IOTA>>` to an **arbitrary address** but requires `&OwnerCap` (owner-only, by design).
- `validator_set`: **zero** transfer/sender/share/freeze instructions.
- `cert`, `ownership`, `math`: no unprivileged fund payouts (`cert::migrate` cap-gated; `ownership` transfers take the cap by value and move no funds; `math` is pure arithmetic).
- `collect_fee` always aborts (911); `collect_fee_non_entry` (public, returns `Coin<IOTA>` from `collectable_fee` + validator unstake) requires `&OwnerCap`.
- `add_points`/`delete_points` are cap-gated (`&OperatorCap`) and only forward to the external `0x12fc…::point` module.
- `publish_ratio` takes no cap but only emits an event; `stake`/`unstake` transfer only to `tx_context::sender` and require the user to supply the input coin (fair exchange, no recipient parameter).

**Conclusion: no cap-less entry function can send IOTA or CERT to the caller or an arbitrary address.** The rebalance family is permissionless but routes value into `NativePool.pending` where `stake_pool` re-stakes it to pool-selected validators; only the OwnerCap holder can collect fees (`collect_fee_new`).

## 7. Residual uncertainties

1. The "16 vaults at 4e15" supporting claim is off by one (15 observed); possibly a stale observation. Irrelevant to the $0 headline.
2. The external `0x12fc…::point` module (used by cap-gated `add_points`/`delete_points`) and IOTA system package `0x3` were not audited; both are behind caps / trusted system code.
3. `iotax_getDynamicFields` pagination: table `size` (22) matched returned entries (22), so the walk is complete.
4. Package "v9" is inferred from its `assert_version` constant 9 + live pool version 9; the RPC package content did not expose a numeric package version field.

## 8. Final verdict

**CONFIRMED — an external unprivileged attacker can extract $0 live:** every value-out path is either cap-gated (`OwnerCap`/`OperatorCap`) or a user-funded fair exchange (`stake`/`unstake` to `tx_context::sender`), and the permissionless rebalance paths recycle funds into `NativePool.pending` and re-stake them.

*Latest checkpoint observed: 201829142.*

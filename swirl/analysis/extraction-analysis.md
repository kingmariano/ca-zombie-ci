# Swirl stIOTA (C2-45) — unprivileged extraction analysis

Question: **how much can an external, unprivileged attacker extract live, right now?**
Method: full Move-bytecode audit of all 8 deployed package versions (`analysis/disassembly_v*/`),
live state enumeration, and read-only `devInspect` simulations from a random address
(`0x1111…1111`) — see `ci-out/dryrun_results.json` and `ci-out/dryrun.log`.

## Verdict

**E-U = $0 (high confidence).** The cap-less `rebalance*` family is callable by anyone but
transfers nothing to the caller: every path moves pool funds from validators → `pool.pending` →
re-stakes them via `stake_pool()`. All functions that can pay an arbitrary address
(`collect_fee`, `collect_fee_new`) or change configuration (`set_pause`, `change_*`,
`update_rewards*`, `update_validators`, `add_pending`, `migrate`) require `OwnerCap`/`OperatorCap`
objects owned by Swirl's admin/operator addresses. `stake`/`unstake` only move the caller's own
coins, and the share math rounds in the pool's favour. No unguarded old-version entry point exists
(all v1–v7 entry points abort via `assert_version` on the v9 pool).

## Vector-by-vector

### V1. `rebalance` / `rebalance_from_validator` / `rabalance_overstaked` — cap-less, no payout
Bytecode (v9 `native_pool.mv.txt` lines 1249–1444):
- `rebalance`: `assert_version` → `when_not_paused` → `get_bad_validators` → `unstake_amount_from_validators(…, u64::MAX, bad)` → `balance::join(pool.pending, …)` → `stake_pool()`. No transfer to sender.
- `rebalance_from_validator(addr, amount)`: requires `addr ∈ get_bad_validators()` (else **abort 112**), then the same pending+re-stake flow. No transfer to sender.
- `rabalance_overstaked`: only unstakes per-validator amounts above 4,000,000 IOTA (max half the excess) → pending → re-stake. No transfer to sender.

`devInspect` from `0x1111…1111` (no caps, no stake):
- `rebalance` → **success**; events = `UnstakingRequestEvent`s from the bad validator's system pool + `StakingRequestEvent`s to other pools; **no balance change credited to the sender**.
- `rebalance_from_validator(bad, 1 IOTA)` → success.
- `rebalance_from_validator(good validator, 1 IOTA)` → **abort 112** (gate enforced).
- `rabalance_overstaked` → success, no-op (no validator > 4M).

So the cap-less surface is real but economically inert for an attacker. It is a public
maintenance path (the operator has used it; all historical calls found were from operator
`0x12e6e7b6…`).

### V2. `stake` / `unstake` share math — no rounding or pricing leak
`get_ratio = supply·1e18/(total_staked+total_rewards)`; `to_shares` and `from_shares` both **floor**
(`math.mv.txt`). Static round-trip from live state: `from_shares(to_shares(C)) = C − 1` nano for
C ∈ {1e9, 1e12, 1e15, 1e17} — the pool always wins. The `to_shares` "min 1 share" rule cannot be
triggered: `min_stake = 1 IOTA` and the live ratio is ≈ 0.855 shares/IOTA, so 1 IOTA always mints
≈ 855,132,496 shares, never 0.

### V3. Pending-exclusion ratio distortion (bounded, not practically extractable)
`get_ratio` deliberately excludes `pool.pending`. If a large pending balance existed, new stakers
would mint shares at an artificially high shares/IOTA ratio and could later redeem at the restored
ratio, diluting existing holders. Quantified:

- Max pending an attacker can force today = the bad validator's stake = **1,948,434 IOTA** (one-shot;
  calling `rebalance` also removes that validator from the set permanently).
- For that pending to *persist*, `stake_pool()` must fail to re-stake it, which requires exhausting
  every validator's headroom to the 4,000,000 IOTA cap: **≈ 13,613,730 IOTA** of attacker capital
  (15/22 vaults are already at the cap; the rest have ≤ 4M headroom each).
- If pending X persists, attacker stakes C < X at the depressed ratio and redeems after restoration:
  profit = `C·(X−C)/(N′+C)`, maximum at C = X/2 → `X²/(4N) ≈ 11,714 IOTA ≈ $604` (N ≈ 81.0M IOTA).
- Restoration requires an external headroom-creating event (operator adds validators / raises caps,
  or users unstake more than pending) — the attacker cannot trigger it at will, and any same-PTB
  sequence loses money (the attacker bears their pro-rata share of the moved pending).
- Today `pending = 0.046442297 IOTA` (rounding dust only; the historical 1-IOTA enforcement
  `remove_stakes` issue, Hacken F-2025-9094, re-stakes excess into pending in dust amounts).

Conclusion: upper bound ≈ $604 under a fragile multi-condition scenario with ≥ $700k capital and
an external trigger; **not a live extraction path**.

### V4. Reward-update timing (operator-gated, no public mempool)
`update_rewards` (OperatorCap) requires: new value > current; ≥ 12 h since last update
(`REWARD_UPDATE_DELAY` = 43,200,000 ms); new value ≤ current + `total_staked·rewards_threshold/10000`
= +743,862 IOTA. Live cadence: ~once/day, Δ ≈ 22,600–23,900 IOTA. A hypothetical sniper staking
right before the update and unstaking right after would capture `f·Δ` (≈ 14% of Δ at max feasible
size ≈ 3.3k IOTA ≈ $170/day) — but IOTA's Mysticeti has no public mempool, so the operator tx
cannot be observed/front-run by an unprivileged attacker; holding continuously earns rewards
fairly. Not counted as extractable.

### V5. Cap gates verified
`collect_fee(pool, to, &OwnerCap, ctx)` devInspect from `0x1111…1111` (passing the real OwnerCap
object as input) → **abort 911** (`ENotOwner`-class: object not owned by sender). All other
sensitive functions take `&OwnerCap`/`&OperatorCap` by reference and are unreachable without the
owned cap object.

### V6. Old package versions (v1–v7) — version-gated
Every entry function of every old version that can touch the pool calls `assert_version` and aborts
(code 1) because pool.version = 9 ∉ {N−1,N}. Checked per version in
`analysis/entry_function_matrix.json`. Exceptions: `update_rewards_revert` (OwnerCap only, no
version check — admin-only) and `collect_fee`/`set_pause`/`add_pending`/`change_max_…` (cap-only,
no version check — admin-only). No cap-less unguarded mutator exists in any version.

### V7. Other custody surfaces
The `NativePool` is the only Swirl custody object (DefiLlama TVL adapter reads exactly this
object). `Coin<CERT>`/`Coin<IOTA>` objects owned by the protocol are only the treasury receiver
(dust, 49.99998 IOTA) and `collectable_fee` (0). No other Swirl package holding value was found in
the version chain or app references.

## Categories
- **E-U**: $0.00 (headline)
- **H-O**: $4,180,633 (stIOTA holders' self-service redemption value = total_staked+total_rewards ≈ 81,017,309.6 IOTA at $0.05160167/IOTA; this is holders' own capital, not attacker-extractable)
- **P**: $0 (no privileged-only value; fee ledger empty, treasury dust)
- **S**: $0 (nothing bricked; pause = false, all functions live)

# StarkDeFi code review (C2-48) — deployed vs. repository

Source: `github.com/Starkdefi/StarkDefi` (Cairo 1, last push 2025-06-11), cloned 2026-10-10.
Deployed classes were fingerprinted by ABI/entry points and behavior (`starknet_getClass`, `starknet_call`).

## Commit history relevant to security

| Commit | Date | Note |
|---|---|---|
| `56185c5` cairo1-upgrade merge | 2023-10-22 | Cairo-1 rewrite deployed era |
| `57b5506` add fee tier | 2023-10-22 | fee_tier u8 added |
| `6a68300` "bug: fix balance1 in skim" | **2024-08-08** | fixes `balance1 = balance_of(token0)` → `balance_of(token1)` |
| `9c08834` PR #18 "fix/zellic-bug-report" | **2025-06-07** | merge of the skim fix into `main` (Zellic audit) |
| `8c5418c`…`32b67bf` scarb/docker updates | 2025-06-11 | last repo activity |

**Deployed classes:** 4 pair classes exist on mainnet. Behavioral probe (309 quiet pairs) shows the
pre-fix behavior only on class `0xaef408ec…` (96 pairs, creation indices 216–311 = newest batch, and the
factory's *current* `class_hash_for_pair_contract`). Classes `0x30ca5759…` (192), `0x4a56a2e3…` (22),
`0x63c46cdc…` (2) behave as the fixed version. The two newest fixed classes also expose
`recover_orphaned_fees()` and a handler-gated `_6bdf53(u64)` (probe → `not allowed`).

## Pair (`Pair.cairo`, `starkDefi::dex::v1::pair`)

- **`skim`**: pre-fix bug as documented (see README §2). Deployed buggy class proven by revert reasons
  (`u256_sub Overflow`, `ERC20: insufficient balance`) and by a full simulateTransaction trace showing
  two `balanceOf` calls on token0.
- **`swap`**: `_lock` reentrancy guard; `assert_not_paused`; requires `amountOut < reserve`;
  `to != token0/token1`; computes `amountIn` from balance deltas; fee `= amountIn * get_fee / 10000`
  moved to the vault; `k(balance) >= k(reserve)` enforced after fees. Volatile `k = x*y`; stable
  `k = x*y*(x²+y²)` on decimal-normalized reserves (Solidly). No unguarded extraction found.
- **`mint`**: Uniswap-V2-style; first mint mints `MINIMUM_LIQUIDITY=1000` to `'deAd'`; stable first-mint
  requires equal normalized amounts and `k > 1e10`. `_update_user_fee` before mint (fee-index hygiene).
- **`burn(to)`**: no pause check (asymmetric with `swap`/`mint`/`skim`), but it only burns the LP balance
  **held by the pair contract itself** (`balance_of(this)`) and pays `to`. All 312 pairs hold 0 self-LP,
  so no sweep exists. It also calls `_claim_fees(to)` first (fees for `to`).
- **`sync`/`skim`**: `skim` pays excess above stored reserves (fixed classes) — legitimate cleanup.
- **`claim_fees`/`_claim_fees`/`_update_user_fee`**: per-LP fee index (`global_fees` scaled by 1e18;
  `claimable += balance*Δ/1e18`), floored — no inflation path; `balance==0` resets claimable. Claims are
  paid by the vault after setting local claimable to 0; vault call does not reenter the pair (lock held).
- **`recover_orphaned_fees`** (classes 0x4a56/0x63c4): `assert_only_handler` → factory.fee_handler.
- **`upgrade`**: `assert_only_handler` (factory.fee_handler). Live `fee_handler` is a funded ArgentX
  account → privileged, not E-U.
- **`get_amount_out`**: fee-adjusted, view; used for feasibility modeling only.

## Factory (`factory.cairo`)

- `create_pair(tokenA,tokenB,stable,fee)` is permissionless; `fee ≤ 100` (1%). Salt = pedersen of
  token0 (+fee) and token1 (+stable). Creating pairs is harmless (new empty pairs, buggy class today).
- All sensitive functions (`set_fee_to`, `set_fee`, `set_custom_pair_fee`, `set_fee_handler`,
  `set_pair_contract_class`, `set_vault_contract_class`, `pause`, `unpause`, `toggle_protocol_fee`,
  `upgrade`) assert `caller == fee_handler`. `fee_handler` set at construction; non-zero.
- `get_fee(pair)` asserts `valid_pairs[pair].is_valid`; custom fee overrides global (stable 4 / volatile
  30 bps).
- Live: 312 pairs, `protocol_fee_on = true`, not paused, pair class = buggy `0xaef408ec…`.

## Fee vault (`pairFeesVault.cairo`) — one deployed class for all 312 vaults

- `claim_lp_fees(user,amount0,amount1)`: `assert(caller == pair)`. The pair passes its own computed
  per-user claimable; then the vault internally calls `claim_protocol_fees`.
- `update_protocol_fees`: `assert(caller == pair)`.
- `claim_protocol_fees`: `assert(caller == fee_handler || caller == pair)`; pays tracked protocol fees to
  `factory.fee_to()`.
- No getter for protocol accumulator; vault balances read directly (291/312 non-zero, $14,730.64).
- No unprivileged path to vault funds found.

## Router (`router.cairo`)

- Functions: `add_liquidity`, `remove_liquidity`, swaps (`exact_tokens_for_tokens[_supporting_fees]`),
  quotes/views. **No `multicall`/arbitrary-call entry point** — every token move is
  `transferFrom(caller → pair)` or `pair.burn(to)` for the caller's own LP. No approval-confusion path.
- `set_factory`/`upgrade` are fee_handler-gated (`assert_only_handler` reads factory.fee_handler()).
- `remove_liquidity` transfers the caller's LP to the pair then `burn(to)`; `to` is caller-chosen but the
  LP is the caller's — no third-party exposure.

## Utils

- `upgradable.cairo`: `replace_class_syscall` with non-zero check; gating is at the call sites
  (fee_handler).
- `callFallback.cairo`: try-selector fallback (`transferFrom`/`transfer_from`, `balanceOf`/`balance_of`)
  for token compatibility; no privilege implication.
- `multicall.cairo` (repo) is not deployed as an open multicall on the factory/router addresses checked.

## Negative results (do not re-investigate)

- Fixed classes (`0x30ca`, `0x4a56`, `0x63c4`): `skim` transfers 0 on quiet pairs (no theft); `upgrade`,
  fees, pause, class changes all handler-gated; `recover_orphaned_fees` handler-gated.
- No pair holds self-LP (0/312) → `burn(to)` sweep unavailable.
- Vaults: pair/handler-gated; `claim_protocol_fees` can only pay `fee_to`.
- Router: no arbitrary call; approvals to it are not abusable.
- `_6bdf53(u64)`: `not allowed` for non-handler.
- Factory `create_pair` with `fee=0` is allowed but harmless.

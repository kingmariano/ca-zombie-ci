# C2-46 — SithSwap pair: Cairo-0 bytecode audit (read-only)

**Method.** The pair source is not verified on any explorer (Voyager/Starkscan APIs are keyed; the
project's own domain is now squatted). The deployed code was therefore audited from the Cairo-0
program returned by `starknet_getClassAt` (pair class hash
`0x07eb597ad7d9ba28ea1db162cdb99e265fe22bcb00e9b690e188c2203de9e005`), using:
- the class ABI + `entry_points_by_type` (exact external surface),
- the program `identifiers` table (module/function names, argument layouts, PCs),
- the `attributes` table (all `error_message` assert strings),
- a custom Cairo-0 disassembler (`analysis/disasm.py`, v0.10.3 encoding).

**Key finding: the pair is a faithful Cairo-0 port of Velodrome v2's audited `Pool.sol`** (Solidly v2
lineage), with Solidly-v1-style ownership layered on. Every value-bearing function decoded from the
bytecode matches the Velodrome v2 semantics; the identified deviations are listed at the end and none
open an unprivileged extraction path.

## Contract set (live, Starknet mainnet)

| Contract | Address / class | Notes |
|---|---|---|
| Factory | `0xeaf728d8e09bfbe5f11881f848ca647ba41593502347ed2ec5881e46b57a32` (class `0x6703fd47…`) | `allPairsLength = 203` (index 0 zero; 202 real pools), `createPair`, `pairFor`, ownership |
| Pair class | `0x07eb597ad7d9ba28ea1db162cdb99e265fe22bcb00e9b690e188c2203de9e005` | 57 external functions = exactly the ABI (no hidden entry points) |
| Pair-fees class | `0x06f6b4f1d8c8baeeb0b009108fc44c7988d82aa0801e6bb3fc6b64ab29478668` | 1 external function: `claimFeesFor` (constructor-only init) |
| Router | `0x028c858a586fa12123a1ccb337a0a3b369281f91ea00544d0c086524b759f627` (class `0xcabe1e6e…`) | peripheral helper; pair is callable directly |

Modules visible in the compiled program (debug identifiers):
`sithswap.amm.pair.library.SithSwapV1Pair`, `sithswap.amm.math.L03.library.SithSwapV1Library`,
`sithswap.amm.fees.library.SithSwapV1PairFees`, `sithswap.libraries.{SithMath,SafeUint256,SafeERC20,SafeOwnable,Initializable,Reentrancyguard,ERC20Library}`.

## Function map (selected, from identifiers + disassembly)

| Function | PC | Behaviour (decoded) |
|---|---|---|
| `initialize` | 5311 | `Initializable.initialize` (revert `Initializable: contract already initialized`), `SafeOwnable.initializer(caller)` → owner = first caller, `factory = caller`, writes fees/tokens/stable/fee0=fee1=fee, `decimals0=10^dec0`, `decimals1=10^dec1` (`too many decimals` if >38), observations[0] |
| `swap` | 6800 | reentrancy guard; `amount0Out==0 && amount1Out==0` → `insufficient output amount`; `amountOut >= reserve` → `insufficient liquidity`; `to != token0/token1` → `invalid destination`; optimistic transfers; hook; re-read balances; `amountIn = bal - (reserve - out)`; `insufficient input amount`; **fee transfer + index accrual**; re-read balances; `_k(new) >= _k(old)` → `swap: K` (assert at pc 7022) |
| `_k` | 7491 | reads `stable`, `decimals0/1`; `SithSwapV1Library.k` |
| library `k` | 1506 | stable: `x·y·(x²+y²)/1e18³` on 1e18-normalised reserves (`x3y+y3x`); volatile: `x·y` |
| library `get_amount_out` | 1437 | stable → `_get_amount_out_stable` (Newton `get_y`/`f`/`d`, same as Velodrome `_f`/`_d`/`_get_y`); volatile → `y·x_in/(x+x_in)` |
| `amount_out` (view) | 5724 | `getAmountOut = curve(amount_in − get_trade_fee(amount_in))` |
| `get_trade_fee` | 5766 | `amount_in * fee0 (or fee1) / 1e6` — fee scale is **1e6** (1500 = 0.15 %) |
| `_update0/_update1` | 7293/7317 | **transfer the fee to the per-pair Fees contract**, then `index += fee·1e18/totalSupply` |
| `_update_for` | 7341 | Solidly/Velodrome fee-index accounting; zero-balance accounts get `supply_index = index` (no history claim) |
| `claim_fees` | 6376 | `_update_for(caller)`; `claimed0/1 = claimable0/1[caller]`; zero them; `fees.claimFeesFor(caller, …)`; emit `Claim` — **pays only the caller's own accrued share** |
| Fees `claim_fees_for` | fees 209 | `caller == pair` else `caller not pair`; conditional ERC20 transfers from the Fees contract to the recipient |
| `_mint` | 7711 | `_update_for(account)` **before** minting → no fee-sniping on mint |
| `transfer` / `transfer_from` | 7177/7201 | `_update_for(from)` + `_update_for(to)` before transfer → no fee-sniping on LP purchase |
| `_burn` | 7723 | `_update_for(account)` before burn |
| `mint_liquidity` | 6477 | `totalSupply==0`: `sqrt(a0·a1) − 1000`, lock 1000 wei to factory; else `min(a0·S/r0, a1·S/r1)`; `insufficient liquidity minted` |
| `burn_amounts` | 6627 | burns the pair's own LP balance pro-rata on **balances**, sends to `to`; `insufficient liquidity burned` |
| `skim` / `sync` | 7057/7127 | permissionless; skim sends only `balance − reserve` excess; sync refreshes reserves |
| `set_trade_fee` | 6252 | `fee <= 10000` (**max 1 %**), caller must be pair owner **or** factory owner (`caller not owner`), per-direction 7-day (604800 s) cooldown (`fee is frozen`) |
| `clawback_ownership` | 7224 | caller must be `factory.owner()` (`caller not factory owner`) → re-initialises SafeOwnable |
| `renounce/transfer/claim_ownership` | — | standard SafeOwnable gating (`caller not owner` / `caller not pending owner`) |

## Live gate proofs (read-only simulations, `starknet_simulateTransactions` + `SKIP_VALIDATE,SKIP_FEE_CHARGE`)

| Case (sender = unprivileged account) | Result |
|---|---|
| `setTradeFee(1,0)` on pools 1 & 2 | REVERT `SithSwapV1Pair::set_trade_fee: caller not owner` |
| `initialize(...)` on live pool | REVERT `Initializable: contract already initialized` |
| `claimFees()` from non-LP | **OK, returns (0,0)** |
| `burn` with no LP | REVERT `burn_amounts: insufficient liquidity burned` |
| `transferOwnership` / `renounceOwnership` / `claimOwnership` / `clawbackOwnership` | REVERT (owner/pending-owner/factory-owner asserts) |
| `sync()` / `skim(attacker)` | OK (permissionless, moves 0 excess) |
| `swap(0,0)` | REVERT (insufficient output amount) |
| **swap 0.0001 ETH → quoted 230147702450943403 DAI (pool 1)** | **OK (executes)** |
| same swap with out+1 wei | REVERT **`SithSwapV1Pair::swap: K`** at pc 0:7022 |

The last two rows are the decisive invariant proof: the K check binds exactly at the `getAmountOut`
quote, so no output beyond the fair, fee-charged amount is extractable.

## Independent math verification

`ci/math_check.py` reimplements the curve from the decoded formulas (Velodrome-v2 `_k`, `_f`, `_d`,
`_get_y`) and compares it with the live `getAmountOut` on the top pools by TVL, plus checks that
`k(reserve_in + net, reserve_out − out) >= k(reserve)` and that `out+1` breaks it.
Results: `ci-out/math_check.json` (see CI log).

## Cairo-0 quirks checked

- All value math uses `Uint256` + range checks (`SafeUint256`, `SithMath` overflow asserts:
  `sith_add: overflow`, `sith_mul_1e18: overflow`, …). No felt-wrap path found in value-bearing code.
- `decimals0/decimals1` are stored as `10^decimals` (felts) at init; the invariant normalises by them.
- Reentrancy guard (`ReentrancyGuard: reentrant call`) on `swap`, `mint`, `burn`, `skim`, `sync`.
  `claim_fees` is not guarded, but it zeroes `claimable` before the external call and can only pay the
  caller's own share — no double-claim or cross-account claim.
- Pair LP token is the pair itself; `transfer`/`transfer_from` sync both parties' fee indexes.

## Deviations from Velodrome v2 (risk assessment)

1. **Fee scale** `/1e6` and **directional `fee0`/`fee1`** with 7-day freeze — no extraction (fee is
   physically moved to the Fees contract before the K check).
2. **`set_trade_fee` callable by owner or factory owner** (max 1 %) — privileged (P).
3. **`clawback_ownership`** — factory-owner only (P).
4. **First mint of a new pool** omits Velodrome's stable equal-deposit and `MINIMUM_K` checks — affects
   only the creator of a brand-new pool; no existing-pool funds at risk.
5. **No pause** mechanism — cannot be used to trap or extract funds.
6. Minimum liquidity (1000 wei LP/pool) locked to the **factory** instead of `address(1)` — dust (S).

## Negative results (dead ends, with evidence)

- No hidden/undocumented external entry point: the 57 entry-point selectors map 1:1 to the ABI.
- Fees contract cannot be re-initialised (no external `initialize`; constructor only).
- No unguarded setter (`set_trade_fee`, ownership functions, `clawback`) — all gated (simulated).
- No fee-sniping: `_update_for` is called before `_mint`, before LP transfers, and before `_burn`.
- No path for a non-LP to claim fees (live simulation returns (0,0)).
- No swap path beyond the invariant: `getAmountOut+1` reverts `swap: K` (live simulation).

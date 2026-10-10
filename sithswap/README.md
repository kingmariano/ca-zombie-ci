# C2-46 — SithSwap (Starknet): live extractable-value determination

**Campaign:** zombie-hunt II · **Chain:** Starknet mainnet · **Date of work:** 2026-10-10
**Status:** read-only research; all proofs are on-chain **simulations** (`starknet_simulateTransactions`,
`SKIP_VALIDATE|SKIP_FEE_CHARGE`) and view calls. **No transactions were signed or sent.**
**Target:** SithSwap AMM (Cairo-0 Solidly/Velodrome fork), finding C2-46 — reported $178.7k in 75/202 pools.

## TL;DR

| Target | Live extractable (unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|
| SithSwap factory + 202 pairs + 202 per-pair Fees contracts | **$0 (high confidence)** | Pair is a faithful Cairo-0 port of Velodrome v2 `Pool.sol`; every privileged path reverts for strangers; swap invariant binds exactly at the quote (out+1 → `swap: K`); fee claims are caller-share-only; init/ownership guarded | None found for E-U. All value is holder/privileged: $48.7k unclaimed fees (LP holders) + $173.9k LP principal (LP holders). Privileged paths: fee ≤1 % + 7-day freeze (owner/factory-owner), clawback (factory-owner). Dead protocol, no pause; secondary risk only via key compromise of the owner contracts |

**Total live extractable by an external unprivileged attacker: ≈ $0** (high confidence).
**Holder-recoverable (H-O): $48,739.35** unclaimed swap fees in the per-pair Fees contracts (claimable
only by each LP holder for their own LP share) **+ $173,924.76** LP principal redeemable via `burn`
by whoever holds the LP tokens. **Privileged (P):** fee changes (≤1 %, 7-day cooldown), ownership
clawback — owner and factory-owner are contract accounts (`0x38b44c5c…`, `0x1428178d…`).
**Stuck (S):** minimum-liquidity dust (1000 wei LP per pool locked to the factory) + any fees of LP
that is permanently lost.

## 1. What the finding claimed vs. what is live

C2-46: *"$178.7k in 75/202 pools; immutable Cairo-0 Solidly fork; ownership/init guarded; swap/fee
bytecode unaudited."* Re-verified at **block 16,152,604** (2026-10-10):

- Factory `0xeaf728d8e09bfbe5f11881f848ca647ba41593502347ed2ec5881e46b57a32` has `allPairsLength = 203`
  (slot 0 empty → **202 pairs**, all with non-zero reserves; **75 pools hold ≥ $1**; 127 dust pools <$1).
- **Total TVL = $173,924.76** (DefiLlama prices at the same time: ~$174.2k — matches).
- **Per-pair Fees contracts hold $48,739.35 of unclaimed swap fees** (28 % of TVL).
- 19 stable pools ($69,225.11) / 183 volatile ($104,699.65). 198 pools at 0.15 % fee, 2 stable pools at 0.01 %.

Pool table (top 45 + aggregates): `analysis/POOL-TABLE.md`. Raw state: `analysis/pairs_raw.json`,
`analysis/pairs_priced.json`, `analysis/tokens_meta.json`, `analysis/prices.json`.

## 2. The mechanism, in exact terms (deployed code)

The pair class (`0x07eb597ad7d9ba28ea1db162cdb99e265fe22bcb00e9b690e188c2203de9e005`) was disassembled
from the on-chain Cairo-0 program (source is not verified anywhere; `sithswap.com` is now a squatted
domain). Full write-up: **`analysis/CODE-REVIEW.md`**. Key decoded paths:

- `swap` (pc 6800): standard Solidly/Velodrome flow — optimistic transfers, `to != token0/1`, input
  measured from balances, **fee moved to the per-pair Fees contract**, then
  `_k(balances) >= _k(reserves)` else `SithSwapV1Pair::swap: K` (assert at pc 7022).
- `_k` = `x·y` (volatile) or `x·y·(x²+y²)/1e18³` on 1e18-normalised reserves (stable) — byte-for-byte
  the Velodrome v2 invariant (`x3y+y3x`).
- Stable curve (`get_y`, `f`, `d`) matches Velodrome v2's audited `_get_y`/`_f`/`_d` Newton iteration.
- Fee flow: `_update0/1` (pc 7293/7317) transfer the fee out **and** accrue
  `index += fee·1e18/totalSupply`; `claim_fees` (pc 6376) pays **only the caller's own
  `claimable[caller]`** through the Fees contract; the Fees contract's `claimFeesFor` (fees pc 209)
  is gated `caller == pair`.
- Anti-sniping: `_update_for` is invoked before `_mint` (pc 7711), before LP `transfer`/`transfer_from`
  (pc 7177/7201) and before `_burn` (pc 7723); zero-balance accounts are synced to the current index.
- Guards: `initialize` is `Initializable`-gated; `set_trade_fee` requires owner **or** factory owner,
  caps the fee at 1 % and enforces a per-direction 7-day freeze; `clawback_ownership` requires the
  factory owner; all SafeOwnable functions are owner/pending-owner gated.

**Deviations from Velodrome v2** (all assessed in `analysis/CODE-REVIEW.md`): directional fee0/fee1
with `/1e6` scale and 7-day freeze; owner-or-factory-owner fee control; `clawback_ownership`; missing
stable equal-deposit / `MINIMUM_K` checks on the **first mint of a brand-new pool only**; no pause.
None of these open an unprivileged path.

## 3. Live-state assessment (explicit citations)

| Check | Result |
|---|---|
| Factory `allPairsLength` | 203 (202 real pairs) @ block 16,152,604 |
| Pairs with reserves > 0 | 202/202 |
| Pairs with `totalSupply == 0` (stuck) | 0 |
| Pairs with `owner == 0` (renounced) | 0 |
| Pair owners | `0x38b44c5c…` ×197, `0x1428178d…` ×3 — both **contract accounts** (class `0x4d07e40e…` / `0x36078334…`) |
| Factory owner / pendingOwner | `0x38b44c5c…` (class `0x4d07e40e…`) / `0x1428178d…` (class `0x36078334…`) |
| Fees contracts | every pair's `getFees()` address is the pair-fees class `0x06f6b4f1…`; live code; only `claimFeesFor` external |
| Fee configs | 198×0.15 %, 2×0.01 % (max settable 1 %, 7-day cooldown) |
| Pool 1 (DAI/ETH) example | reserves 6,693.03 DAI + 2.9037 ETH; fees contract 2,087.29 DAI + 1.1485 ETH; owner `0x1428178d…` |

## 4. What an attacker can / cannot do (exact call paths)

**Cannot** (each proven live, block 16,168,054+, see `ci-out/sim_results.json`):

| Attempt (unprivileged sender) | Live result |
|---|---|
| `setTradeFee(1,0)` (pools 1 & 2) | REVERT `SithSwapV1Pair::set_trade_fee: caller not owner` |
| `initialize(pid,tokens,stable,fee,fees)` on live pool | REVERT `Initializable: contract already initialized` |
| `claimFees()` from an address with no LP | **OK, returns (0,0)** — nothing claimable |
| `burn(to)` with no LP | REVERT `burn_amounts: insufficient liquidity burned` |
| `transferOwnership` / `renounceOwnership` / `claimOwnership` / `clawbackOwnership` | REVERT (owner / pending-owner / factory-owner asserts) |
| `swap` taking more than the quote | REVERT **`SithSwapV1Pair::swap: K`** (out+1 wei breaks the invariant) |

**Can** (permissionless, value-neutral): `sync()` and `skim(to)` — skim moves only `balance − reserve`
excess (0 today for the sampled pools); `claim_fees()` — claims only the caller's own accrued share;
`mint`/`burn`/`swap` — fair, invariant-guarded.

**Positive swap proof** (the decisive test): unprivileged account
`0x17dd33c2dcbdac44429ded27be81638e77fe729e243630106790c516020cc07` — transfer 0.0001 ETH into pool 1,
`swap(230147702450943403,0,…)` (exactly `getAmountOut`) → **executes OK**; the same swap with **+1 wei**
→ **REVERT `SithSwapV1Pair::swap: K`** at pc 0:7022. The invariant binds at 1-wei precision, so no
output beyond the fair fee-charged amount is extractable.

## 5. PoC / verification (read-only; no mainnet transactions)

| Artifact | What it proves |
|---|---|
| `ci-out/sim_results.json` + `ci-out/sim_proofs.log` | 15 simulation cases: every privileged path reverts for a stranger; `claimFees` non-LP → (0,0); fair swap OK; out+1 → `swap: K` |
| `ci-out/math_check.json` + log | Independent reimplementation of the curve vs. live `getAmountOut` on the top 40 pools (~99 % of TVL, block 16,169,041): **all 29 volatile pools match exactly and their K check binds at +1 wei (gap = 0)**; stable pools quote 1 wei more conservatively than the K limit (max observed K-gap = 2,881,587 wei of an 18-decimal token ≈ $10⁻¹¹; the largest stable pool, $60k USDC/USDT, has a 1-wei gap) → dust-level, gas-negative |
| `analysis/CODE-REVIEW.md`, `analysis/disasm.py`, `analysis/pair_program.json` | Full bytecode audit trail (function map, assert strings, decoded logic) |
| `analysis/POOL-TABLE.md`, `analysis/pairs_raw.json`, `analysis/pairs_priced.json` | Full 202-pool state + USD valuation at a pinned block |
| `ci-out/skim_excess.json` | Permissionless `skim(to)` can move only `balance − reserve` excess: **0 excess on the top 12 pools** (~$170k of $173.9k TVL) → $0 |
| CI run | `ci-run.sh sithswap` → GitHub Actions `poc.yml` on branch `sithswap` (URL in `ci-log.txt` / §8) |

## 6. Verdict and residual/latent risk

- **E-U = $0 (high confidence).** No unprivileged drain: gates verified live, invariant verified
  live (fair pass / +1 fail), fee accounting verified in bytecode + live state, all deviations from
  the audited upstream assessed as non-extractable. The only imperfection found is a rounding-level
  gap on stable pools: the on-chain quote is 1 wei conservative vs. the K limit (largest observed gap
  2,881,587 wei of an 18-decimal token ≈ $10⁻¹¹; 1 wei for the biggest stable pool) — gas-negative and
  not economically extractable.
- **H-O = $48,739.35** unclaimed fees (per-pair Fees contracts; each LP holder claims only their own
  pro-rata share via `claim_fees`) **+ $173,924.76** LP principal (`burn`). Caveat: the LP-holder
  distribution was not exhaustively enumerated (no keyless event indexer; the protocol is inactive —
  no LP transfers in the last 200k blocks). Any LP held by lost keys is effectively **S**, not H-O.
- **P:** `set_trade_fee` (≤1 %, 7-day cooldown) and `clawback_ownership` are callable by the owner
  contract `0x38b44c5c…` or factory owner; both are smart-contract accounts — key compromise of those
  accounts would expose fee-setting/ownership, but even then the code caps fees at 1 % and cannot
  move LP principal.
- **S:** 1000 wei LP per pool locked to the factory at first mint; unclaimed fees of permanently lost
  LP; any dust pairs.
- **Latent:** none identified for unprivileged extraction. If the protocol were ever revived, the
  standard Solidly/Velodrome surfaces (invariant-guarded swaps, holder-only claims) still apply.

## 7. Methodology & sources; caveats

- Enumerated from the factory (`allPairsLength`/`allPairs`), not from lists; all 202 pairs read at a
  pinned block; token metadata on-chain; prices from DefiLlama `coins.llama.fi` at the same time.
- Code audit from the on-chain Cairo-0 program (identifiers/attributes/disassembly); upstream
  comparison against Velodrome v2 `Pool.sol`/`PoolFees.sol` (public repo).
- Proofs via `starknet_simulateTransactions` with `SKIP_VALIDATE|SKIP_FEE_CHARGE` (read-only, no
  signatures, no state changes) and view calls. Keyless public RPCs only; no secrets in this folder.
- Caveats: (1) LP holder set not enumerated → H-O/S split is a bound, not a per-holder ledger;
  (2) `getAmountOut`/invariant checks were run on the top 40 pools by TVL (covers ~99 % of value) and
  the swap proof on pool 1; (3) source was reconstructed from bytecode, so a semantic mismatch in an
  unexercised path cannot be fully excluded — however the invariant guard bounds any swap to the
  K-preserving amount regardless of quote errors.

## 8. Files index

```
sithswap/
├── README.md                  # this file
├── summary.json               # machine-readable summary
├── analysis/
│   ├── CODE-REVIEW.md         # bytecode audit (function map, decoded logic, deviations)
│   ├── POOL-TABLE.md          # top-45 pool table
│   ├── pairs_raw.json         # 202 pairs: tokens/reserves/supply/stable/fees/owner/index @ block
│   ├── pairs_priced.json      # + USD values and Fees-contract balances
│   ├── tokens_meta.json, prices.json, aggregates.json
│   ├── pair_abi.json, pair_class.json, pair_program.json, fees_abi.json, fees_program.json, factory_class.json
│   ├── sn.py, disasm.py, enumerate.py, price_pools.py, sim_proofs.py
│   └── dis_*.txt              # raw disassembly excerpts of key functions
├── ci/run.sh                  # CI job: sim proofs + math check + skim check
├── ci/math_check.py           # independent curve verification
├── ci/skim_top.py             # skim-able excess check
├── ci-out/                    # sim_results.json, math_check.json, skim_excess.json, logs (CI artifacts)
├── ci-log.txt                 # CI run log (fetched by ci-run.sh)
└── ci-artifacts/              # CI artifacts
```

Note: no Foundry project is provided because SithSwap is a Starknet/Cairo-0 system (Foundry does not
fork Starknet). The equivalent PoC is the set of **read-only on-chain simulations** in
`analysis/sim_proofs.py` (+ `ci/math_check.py`), runnable via `ci/run.sh` and reproduced in CI.

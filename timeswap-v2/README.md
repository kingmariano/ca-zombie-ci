# Timeswap V2 (L2-Triage-A) — zombie-hunt II Phase-2 deep dive

**Date:** 2026-10-12 · **Chains:** Arbitrum, Ethereum, Base, Hyperliquid L1 (HyperEVM), Optimism, Polygon zkEVM, Mantle, X Layer (+ Polygon / inEVM via DefiLlama)
**Status:** read-only research; PoC verified on local/CI mainnet forks only. **No mainnet transactions signed or sent.**

## 1. TL;DR

| Target | Live value (on-chain, this run) | Extractable by external unprivileged attacker | Why closed | Latent risk |
|---|---|---|---|---|
| Timeswap V2 core (option/pool/token, all deployed generations v2.0–v2.5) | **$360,695 measured across 9 chains** (DefiLlama live $333,666) | **$0** | Every pool on every chain is **matured**; all remaining value sits in *short* positions whose only redemption (`TimeswapV2Option.collect`) is strictly `msg.sender`-keyed; every other path (mint/burn/swap/leverage/deleverage/rebalance/transferLiquidity/initialize) reverts post-maturity; all admin paths (`collectProtocolFees`, factory ownership) are owner-gated; deployed code is byte-identical to the audited public repo (Sourcify exact-match + source diff) | Value is claimable only by the ~hundreds of ERC1155 position/LP holders (H-O); protocol fees ($2.6k) only by factory owners (P); dust stuck ($9.5) (S) |

**Total live extractable by an external unprivileged attacker now: $0. Confidence: high.**
The $360.7k of live value is **holder-only recoverable (H-O ≈ $358.1k)**, **privileged-only protocol fees (P ≈ $2.6k)**, and **stuck dust (S ≈ $9.5)**.

## 2. What the target is

Timeswap V2 is a fixed-maturity, oracle-less lending/options AMM. The L2 triage flagged it LIVE-FUNDED ($332,066) with medium confidence because only the factory contracts had been checked (they hold $0) and the per-pair pools had not been enumerated. This pass enumerates **every option pair and every (strike, maturity) pool** on every chain with a public RPC, prices the balances, and audits the deployed code.

**Architecture (custody):** each `(token0, token1)` pair has one `TimeswapV2Option` contract holding **all** deposited ERC20s; claims are stored in the option (`long0/long1/short` mappings) and/or wrapped as ERC1155 by `TimeswapV2Token`; LPs hold ERC1155 liquidity in `TimeswapV2LiquidityToken` backed by pool-level positions. AMM state (liquidity, fee growth, shortReturned growth) lives in the per-pair `TimeswapV2Pool`. Factories deploy pairs/pools; **there is no proxy/upgradeability** (all direct CREATE2 deployments).

**Post-maturity semantics (critical for this assessment):** after maturity, only `short` positions redeem (`TimeswapV2Option.collect`), pro-rata against remaining longs; `long` positions become permanently unwithdrawable (`burn`/`swap` are pre-maturity-only); LP principal is represented by `shortReturnedGrowth` claims collected via `TimeswapV2Pool.collectTransactionFeesAndShortReturned`. This is by design (code comments: *"after the maturity of the pool, the long0 and long1 tokens are zero. And the short tokens are added into the transaction fees"*).

## 3. Live-state assessment (all reads keyless public RPC; blocks recorded)

| Chain | Block | Option pairs | (strike,maturity) pools | All matured? | Value measured | DefiLlama (2026-10-12) |
|---|---|---|---|---|---|---|
| Arbitrum | 513,981,428 | 96 | 348 | yes (348/348) | **$72,377.83** | $72,313 |
| Ethereum | 26,173,179 | 19 | 28 | yes (28/28) | **$51,665.59** | $51,471 |
| Base | 52,490,083 | 15 | 41 | yes (41/41) | **$62,563.62** | $62,562 |
| Hyperliquid L1 | 48,304,759 | 28 | 110 | yes (110/110) | **$112,996.07** | $82,873¹ |
| Optimism | 158,085,375 | 6 | 18 | yes (18/18) | **$25,439.90** | $25,443 |
| Mantle | 101,819,610 | 10 | 8 | yes (8/8) | **$3,527.64** | $6,906¹ |
| Polygon zkEVM | 33,391,890 | 3 | 8 | yes (8/8) | **$31.83** | $0 |
| X Layer | 73,000,532 | 2 | 3 | yes (3/3) | **$0.03** | $0.03 |
| Polygon | 95,379,468 | 24 | 62 | yes (62/62) | **$32,092.19** | $32,097 |
| inEVM | — (RPC dead; DL $0) | — | — | — | — | $0 |
| **Total measured (9 chains)** | | **203** | **626** | **626/626 matured** | **$360,694.70** | $333,666 |

¹ Hyperliquid measured higher than DL (price timing / token coverage on BUDDY, SWAP-LP, PiP); Mantle lower (DL prices tokens we could not). Both are within expected price-source variance; the custody addresses agree.

**Key contracts (same deterministic addresses on most chains):**

| Contract | Address | Notes |
|---|---|---|
| Option factory v2.5 | `0x17385e95cb74A20150E4fA092Aa72D57330896C4` | 37 pairs (Arb) |
| Pool factory v2.5 | `0x97509c65Ff29C268F0D283A41201Be6b4090354c` | **owner = 0x70fea7b1… (Arb, helper contract), 0x1c65868b… (ETH), 0xbf90d2d8… (Base), 0x51b42077… (HL/zkEVM/Mantle/OP-old)** |
| Option factories older | `0xcf0aca5c…` (v2.0/2.1), `0x406d3Dfc…` (v2.1–2.4), `0xf8F5e4B7…` (Mantle v2.0), `0xcAB2E5Ba…` (Polygon v2.0) | verified live code |
| Pool factories older | `0x8E3fcda0…` (ETH v2.0), `0x97660755…` (Arb v2.0), `0x9660c75A…`, `0x47ffFCc1…`, `0x1EE933d5…` | owners: 3d740798…, 9454c2b5…, 0705faa3…, 90fe2365…, e93cc3ae… |
| TimeswapV2Token / LiquidityToken v2.5 | `0x4aA2Bc42…` / `0xF2A0624D…` | ERC1155 wrappers (hold wrapped positions) |
| TimeswapV2Token v2.0 / LiquidityToken v2.0 | `0x1f741e2b…` / `0x368F3Fa7…` | older wrappers, same audited code |

**Deployed-code verification:** Sourcify-verified sources were fetched for 15 deployed contracts: a live v2.5 pool (`0xcEa329e9…`), option pair (`0x30138774…`), factory, tokens, NoDex peripheries (all `exact_match` except the pool/factory which are `match` — runtime bytecode identical, metadata hash differs), plus a v2.0 pool/option/token/LiquidityToken and a v2.0 UniswapV3 periphery. **Source diff vs `Timeswap-Labs/Timeswap-V2-Contracts` @ main: every v2.5 Timeswap file is identical (zero diff); the v2.0 Option is identical; the v2.0 Token differs only in its constructor URI string; the v2.0 Pool/LiquidityToken are the older 2.0-era design (reviewed: same post-maturity gating, no permissionless claim path).** The audited code (PeckShield 2022-409 + Trust Security; critical `swap()` balance-check fix present) is what is deployed.

**Roles/privileged paths:** `collectProtocolFees` requires `msg.sender == poolFactory.owner()` (`Ownership.checkIfOwner`). No other admin powers exist (no pause, no upgrade, no mint, no sweep). Factory ownership is two-step (`setPendingOwner`/`acceptOwner`) and current owners are plain EOAs/contracts per chain (listed above). **Protocol fees are the only P-category value** — and note the *long-denominated* portion is dead post-maturity (proven by fork test).

## 4. What an attacker can and cannot do (exact call paths)

All paths were exercised on forks (Arbitrum + Ethereum). Results:

| Attempt (unprivileged) | Result |
|---|---|
| `TimeswapV2Option.collect(GivenShort)` with no short balance | **reverts** (checked underflow) — no tokens leave the option |
| `TimeswapV2Option.burn` / `swap` / `mint` (any params) | **reverts** `alreadyMatured` |
| `TimeswapV2Pool.mint/burn/deleverage/leverage/rebalance` | **reverts** `alreadyMatured` |
| `TimeswapV2Pool.initialize(strike, maturity, rate)` (re-init an emptied/drained pool) | **reverts** `alreadyMatured` (and `alreadyHaveLiquidity` for live ones pre-maturity) |
| `TimeswapV2Pool.collectProtocolFees` (redirect protocol fees) | **reverts** `NotTheOwner` |
| `TimeswapV2Pool.collectTransactionFeesAndShortReturned` with attacker-chosen `*To` | succeeds but pays **0** (caller has no liquidity position); cannot touch others' |
| `TimeswapV2LiquidityToken.collect(from=victim)` | **reverts** `NotApprovedToTransferFees` |
| `TimeswapV2Token.burn` without the ERC1155 | **reverts** (ERC1155 `_burn` balance check) |
| `TimeswapV2Option.transferPosition` to move someone else's positions | **reverts** (msg.sender-keyed, underflow) |
| NoDex periphery `refundNatives()` / `unwrapWrappedNatives()` sweep | available but **peripheries hold $0** (tested: 6 Arbitrum v2.5 + 7 Ethereum v2.0 peripheries, native+WETH = 0) |
| UniswapV3 periphery `uniswapV3SwapCallback` forged data | **reverts** — `Verify.uniswapV3Pool` requires `msg.sender` = canonical Uniswap pool; `pay()` payer is always the outer caller |
| **Position-owner path (H-O, live)** | `option.collect` by the v2.2/v2.5 LiquidityToken (real holder of LP aggregate shorts) pays out pro-rata — value is live and claimable, not stuck |
| **Owner path (P, live)** | `collectProtocolFees` by the real factory owner succeeds on the top short-fee pool; protocol counters zero afterwards |

**Costs:** no capital, no flash loans, no gas beyond a reverting call. There is nothing to extract.

## 5. Value classification (how the $360.7k splits)

| Category | USD | Basis |
|---|---|---|
| **E-U** (external unprivileged) | **$0** | all 626 pools matured; all claim paths ownership-keyed; no re-init/redeem/redirect path exists |
| **H-O** (holder-only recoverable) | **≈$358,061** | short holders (lenders/LPs) via `collect`; verified live by fork test (real position owner collects) |
| **P** (privileged — factory owner protocol fees, *short-denominated only*) | **≈$2,624** | ETH $1.84 + Arb $336.43 + Base $15.62 + OP $28.03 + HL $2,215.46 + Polygon $26.62 + zkEVM $0.03 (owner-gated; verified on fork). The much larger *long-denominated* fee counters (≈$50k+ nominal) are **dead post-maturity** — proven by `test_eth_long_protocol_fee_is_dead` |
| **S** (stuck) | **≈$9.5** | pairs where all shorts were already collected (Hyperliquid); plus rounding dust in emptied pools |

Note on DefiLlama's number: DL sums the *token balances of option pairs* — exactly what this pass measured (agreement within 0.5–2% on ETH/Arb/Base/OP/Polygon). Those balances are **claims**, and post-maturity they belong to short holders; DL's "TVL" is therefore not extractable value for a third party.

## 6. PoC / fork verification

Foundry project `poc/` (vendored forge-std). **19 tests, 19 PASS** on GitHub Actions forks (Ubuntu runner) — CI run URLs:

- Run 1 (18 tests): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38197913354
- Run 2 (19 tests, adds Ethereum periphery sweep check): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38198133864 — **19/19 PASS**

| Test file | Tests | What it proves |
|---|---|---|
| `poc/test/TimeswapV2Arbitrum.t.sol` | 13 | sampled pools from all 5 factory generations all matured; outsider cannot collect shorts / protocol fees / LP claims; every pre-maturity entry point reverts; `initialize` blocked; token burn without balance reverts; transferPosition underflow reverts; peripheries hold no funds; real LP-aggregate short holder can still collect (value live) |
| `poc/test/TimeswapV2Ethereum.t.sol` | 6 | apxETH/WETH ($51.3k): 99.9%+ of shorts are wrapped user ERC1155 (H-O); outsider cannot collect; long-denominated protocol fee is owner-collectible but unconvertible post-maturity (dead); v2.0 pool owner gate; periphery sweep checks |

Key numbers from the tests (fork blocks at run time): wstETH/WETH option holds 0.015083 wstETH + 10.956 WETH; FIN/USDC option holds 76,256 FIN + 14,607 USDC; apxETH/WETH option holds 20.162 WETH; PENDLE/mPendle pool short protocol fees 8,645,264,991,233,267,916 units — owner-only; collect by the LP-aggregate holder paid out > 0 (claim live).

**Independent CI live-state re-verification** (`ci/run.sh` → `ci-out/`): re-enumerated Arbitrum/Ethereum/Base/Hyperliquid in CI, re-ran the maturity audit (**510/510 matured** at CI blocks 513,996,454 / 26,173,553 / 52,492,319 / 48,309,273 — the CI Base walk found 24 pairs vs 41 locally, an RPC-timeout partial pass; still every found pool matured) and the owner checks — see `ci-out/maturity-audit.txt`, `ci-out/pool-factory-owners.txt`, `ci-out/pools-*.json`, `ci-out/live-*.json`.

## 7. Verdict, residual risk, blockers

- **Verdict: E-U $0. Confidence high.** The protocol is fully post-maturity and its residual value is claims, not assets a third party can take. An honest "$0 with proof" is the outcome.
- **Residual/latent risk (not attacker-extractable):**
  1. **Holder claims are first-come, pro-rata**: post-maturity the option's `totalLong0/totalLong1` shrink as shorts collect, while individual stale long balances persist. Short holders (and the LP/token contracts holding aggregate shorts) are paid pro-rata; later collectors could be diluted if claim units exceed the remaining backing (the option's own balance is the hard cap). No over-extraction is possible; late holders risk shortfall.
  2. **Protocol fees**: owner-gated ($2.6k short-denominated; long-denominated counters are dead). If owners lose keys, those fees are stuck, not stealable.
  3. **Stale pools with `liquidity == 0`** cannot be re-initialized post-maturity (tested) — no revival surface.
  4. **Approval residue**: users may still have ERC20 approvals to periphery contracts; the peripheries hold $0 and their callbacks are verified against canonical pools/tokens, so residue is not exploitable through these contracts. (A future redeployment at the same address is not possible; CREATE2 salts are fixed.)
- **Blockers/limits:** inEVM could not be enumerated (dead RPC; DefiLlama reports $0 there). Hyperliquid pricing differs from DL; USD figures carry price-timing variance.

## 8. Methodology & sources

- **Enumeration by contract, not lists:** `getByIndex`/`numberOfPairs` walk of every option factory (v2.0, v2.1, v2.2, v2.2.1, v2.3, v2.4, v2.5) per chain → 203 option pairs; every pool factory `get(optionPair)` → 626 (strike,maturity) pools; direct `balanceOf` reads of both option tokens per pair; DefiLlama `coins.llama.fi` pricing (address-level).
- **Deployed-reality verification:** Sourcify-verified sources (`exact_match`/`match`) for 15 deployed contracts across v2.0/v2.4/v2.5 + source diff vs `Timeswap-Labs/Timeswap-V2-Contracts` @ main (v2.5 identical; v2.0 option identical, token URI-only delta, older pool/LP-token design reviewed); factory owner/immutable reads; EIP-1967 slots not needed (no proxies — CREATE2 direct deployments).
- **PoC:** Foundry forks on CI (GitHub Actions, public repo `kingmariano/ca-zombie-ci`), 19 tests.
- **Sources:** Timeswap-Labs/Timeswap-V2-Contracts (public repo); DefiLlama protocol API; Sourcify; public RPCs; PeckShield audit 2022-409; Trust Security audit; deployment address map (public).
- **Corpus cross-check:** `zombie_hunt/FINDINGS.md` (Timeswap row, no exploit history), `l2-triage-a/summary.json` (Phase-1 row: factories hold $0 — confirmed), no Timeswap incident/exploit reports found in open sources.

## 9. Files index

| Path | Content |
|---|---|
| `analysis/enumerate.py` | option-pair enumeration + balances (public RPCs) |
| `analysis/pools.py` | pool-level state (maturities, liquidity, protocol fees, factory owners) |
| `analysis/price.py`, `analysis/fees.py`, `analysis/claims.py` | pricing, P/S attribution, claim decomposition |
| `analysis/live-*.json`, `analysis/pools-*.json`, `analysis/live-priced-*.json`, `analysis/claims-*.json`, `analysis/fees-*.json` | raw state dumps (blocks recorded in each) |
| `analysis/sources/` | Sourcify exact-match deployed sources (v2.0/v2.4/v2.5 + peripheries) |
| `poc/test/TimeswapV2Arbitrum.t.sol`, `poc/test/TimeswapV2Ethereum.t.sol`, `poc/test/TimeswapV2Interfaces.sol` | fork PoC (19 tests) |
| `ci/run.sh` | CI heavy job (live-state re-verification → `ci-out/`) |
| `ci-out/`, `ci-log.txt`, `ci-artifacts/` | CI evidence |
| `summary.json` | machine-readable summary |

**Caveats:** USD values use DefiLlama prices at query time; Hyperliquid/Mantle differ from DL as noted. inEVM not enumerable (dead RPC; DL $0). The P/S split uses a pro-rata attribution of pair value by short-fee share — the order of magnitude is robust; the exact split between P and H-O on Hyperliquid carries pricing variance. This is informational research; re-verify on-chain before acting.

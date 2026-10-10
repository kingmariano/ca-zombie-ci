# Minswap V1 (Cardano) — C2-55 dossier

**Date:** 2026-10-10 · **Chain:** Cardano mainnet · **Status:** read-only; no transactions; PoC is a
local/CI CEK-machine evaluation of the deployed validator (no chain writes).

## TL;DR

| Metric | Value | Evidence |
|---|---|---|
| Deployed pool script | `e1317b152faac13426e6a83e06ff88a4d62cce3c1634ab0a5ec13309` (PlutusV1) | Koios `script_info`; creation tx `2a12ef3a…`, block **7,039,882** (2022-03-25) |
| Pool address | `addr1z8snz7c4974vzdpxu65ruphl3zjdvtxw8strf2c2tmqnxz2j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq0xmsha` (pool script + fixed stake key `52563c54…`) | tx `2a12ef3a…` output 3 |
| V1 TVL (Minswap indexer, `currency=usd`, latest) | **$2.89M nominal / $1.33M both-verified / $1.79M ≥1-verified** across 7,000 top pools | `api-mainnet-prod.minswap.org/v1/pools/metrics` census (`raw/minswap_v1_all_pools_usd.json`) |
| Fake-pair pools | ~$1.0M nominal of the $2.89M is in 3 pools with both assets unverified memecoins, **$0 real** | same census |
| Live activity | 24 pools with 24h volume ($49.8k/day USD), **8,140 pending orders** in 1,433 pools | same census |
| On-chain cross-check | pool address holds **≥2,717,373.13 ADA** (Koios `address_info`; UTxO set truncated at 6,998 entries — census ADA-side total 3,467,115 ADA) + tokens; top pools match the census to the lamport | `raw/pool_addr_info.json` |
| V1 order contract | `addr1zxn9efv2f6w82hagxqtn62ju4m293tqvw0uhmdl64ch8uw…6s3z70` = **72,960.12 ADA + tokens**, 5,785 UTxOs | Koios `address_info` (epoch 660) |
| **E-U (external unprivileged)** | **$0.00** | audit of deployed code + CEK proof (below) |
| H-O (holders) | all LP value (withdraw orders; batchers live) | see classification |
| P (privileged) | pool profit-share LP (owner token) | `hasOwner` gate |
| S (stuck) | orders with script senders (cannot cancel) | README warning of Minswap repo |

## 1. Mechanism / audit history

Minswap V1 (batcher-based AMM, deployed 2022-03-24/25) was audited by Tweag in **Jan 2022**
(`MinSwap-Jan31.pdf`, vendored in `raw/`). That audit found **three CRITICAL issues**:

1. **Unauthorized redeeming of open orders** — `ApplyOrder` could be used by anyone who also redeemed a
   profit-sharing pool with `WithdrawLiquidity`; order funds could be stolen.
2. **LP tokens can be duplicated** — the LP minting policy was too loose (any tx with one output holding a
   pool NFT could mint that pool's LP), then the pool emptied via a Withdraw order.
3. **Unauthorized hijacking of pool funds (datum-hijacking)** — the pool validator selected its continuing
   output by *pool-NFT presence* (`ownOutput = case [o | o <- txOutputs, hasPoolNFT …] of [o] -> o`), not by
   address, so the pool UTxO could be re-created at an attacker's "stealer" script with an isomorphic datum,
   handing the attacker the whole pool.

The open-sourced fixed code (`dex/src/…`, vendored here from the public mirror `myway7/contracts`,
commit `162c455` "Open-source Minswap DEX contracts", 2022-03-18) contains the fixes:
`ownOutput = case [o | o <- txOutputs, ownAddress == txOutAddress o]` and an **owner-token gate**
(`hasOwner`) on `WithdrawLiquidityShare`. The March-3-2022 Tweag follow-up report records all attack tests
("datum-hijacking on WithdrawLiquidity", "order-stealing on WithdrawLiquidity", "mint LP tokens on …") as **OK**
on that code.

## 2. Is the *deployed* script the fixed code? (verification)

The deployed script (hash `e1317b15…`) is a **different compilation** than the open-sourced `.plutus`
(hash `57c8e718…`): different derived policy IDs (NFT `0be55d26…` vs `5178cc70…`, LP `e4214b7c…` vs
`e0baa1f0…`, factory `13aa2acc…` vs `3f609264…`) — i.e. a different toolchain build. The **same license
symbol `2f2e0404…` and owner token name `OWNER`** are embedded in both.

I verified equivalence of logic (not just intent) by decompiling both scripts to UPLC
(`uplc`/`aiken`, see `scripts/`) and comparing the complete ordered streams of builtins + constants:

| Script pair | Builtin stream | Constants | Verdict |
|---|---|---|---|
| pool A (repo 57c8e718) vs **B (deployed e1317b15)** | 515 vs 515, identical counts for all 23 builtins; 97.5% identical sequence (only commutative reorderings) | 6 vs 6; only NFT/LP/factory policy IDs differ | **same logic** |
| order A (`0ca50950…`) vs **B (deployed `a65ca58a…`)** | 28 vs 28; 96.4% | only embedded pool-script hash differs | **same logic** |
| LP policy A vs B | 88 vs 88; 95.5% | only NFT symbol differs | **same logic** |
| NFT policy A vs B | 122 vs 118 | none | same logic (optimizer reordering) |
| factory A vs B | 229 vs 253 | **B adds license policy + `"CREATOR"` token name** | B = A + pool-creation license gate (not on the extraction path) |

Minswap's own indexer (`dcSpark/carp`, `minswap_v1.rs`) lists **both** hashes
`e1317b15…` (V1) and `57c8e718…` (V1, second build) as Minswap V1 pools, confirming both were real deployments.

**Timeline:** version A (repo build, `57c8e718…`) first appeared in tx `03814bb2…`, block **6,954,641**
(2022-03-04) — i.e. *after* the March-3-2022 Tweag follow-up where all attack tests pass. Version B
(`e1317b15…`) was deployed 2022-03-25. Both are therefore the post-audit fixed code; B adds only the
`CREATOR` pool-creation licence gate in the factory. A's legacy pools still exist at
`addr1z9tu3eccc…` (198 UTxOs, 2,197.8 ADA + tokens — dust).

## 3. Behavioural proof (CEK machine, deployed script)

The deployed pool script was evaluated with the aiken UPLC interpreter on three hand-built Plutus V1
`ScriptContext`s (`ci/cek_cases.py`, run locally and in CI; logs in `out_cek/` and `ci-out/`):

| Case | Context | Result |
|---|---|---|
| `LEGIT_owner_withdraw` | `WithdrawLiquidityShare(ownerIdx,feeToIdx)`, owner input holds `(2f2e0404…, "OWNER")`, pool output at the pool's own address | **ACCEPT** (rc=0; cpu 454,122,385) |
| `ATTACK_no_owner_token` | identical except the owner input does **not** hold the `OWNER` token | **REJECT** (validator error; cpu 170,519,323) |
| `ATTACK_datum_hijack_redirect` | identical except the continuing pool output is redirected to a foreign script address (stealer) | **REJECT** (validator error; cpu 452,051,074) |

The two attack cases differ from the accepted case in exactly one variable, so the rejections are attributable
to (a) the owner-token gate and (b) the continuing-output address check. Both criticals from the Jan-2022 audit
are closed in the deployed code.

## 4. Remaining surfaces reviewed (why E-U = $0)

- **AMM math** (`ConstantProductPool/Utils.hs`): Uniswap 997/1000 swap fee, ceil-sqrt initial liquidity,
  `getAmountIn` round-up, Uniswap-2.4-style profit-sharing LP mint, Alpha Finance one-sided-deposit formula.
  Line-by-line review found no value leak; roundings favour the pool. (Tweag explicitly did not audit pricing;
  this review is the residual uncertainty — see caveats.)
- **Order contract**: `ApplyOrder` requires exactly one input whose payment credential is the pool script
  (singular match), so orders cannot be applied without a pool spend; `CancelOrder` requires the order
  sender's signature. Order funds cannot be taken by third parties.
- **LP minting**: the LP policy only binds token names; the amount is bounded by the pool validator's
  `assetClassValueOf mintValue lpCoin == totalDeltaLiquidity` on `ApplyPool`, and both other redeemers require
  `txInfoMint == mempty`. Arbitrary LP minting is not reachable.
- **Pool creation**: the deployed factory (B) additionally requires a `(2f2e0404…, "CREATOR")` license input;
  fake pools cannot process orders anyway because every pool UTxO must hold exactly one factory token
  (`factoryCoinIn == 1`) and factory tokens are only minted under that gate.
- **Batcher licences**: `ApplyPool` requires a batcher licence NFT (policy `2f2e0404…`, token name = deadline)
  plus the batcher's signature, and `after deadline range` correctly requires the tx to be valid *before* the
  deadline (Plutus `after h (Interval _ t) = upperBound h > t`). Expired licences are unusable; licences are
  issued by Minswap, not mintable by outsiders. Even with a licence, a batcher can only execute orders with
  the user's own `minimumReceive` slippage bound — no third-party value is extractable.

## 5. Classification

- **E-U: $0.00 (high confidence)** — no unprivileged path to any V1 pool, order, or policy value.
- **H-O: LP value (≈ $1.33M both-verified / $2.89M nominal) + order funds (72,960.12 ADA ≈ $18.5k + ~492k MIN ≈ $1.9k + spam tokens)** — recoverable
  by holders: LP withdrawals and order cancels go through live batchers (23 pools trading daily, 8,124 pending
  orders processed historically).
- **P: pool profit-share LP balances** (owner token `OWNER`; e.g. the ADA/EcTOSI pool datum with
  `feeSharing = Just`) — withdrawable only by Minswap via `WithdrawLiquidityShare`/`UpdateFeeTo`.
- **S: orders whose `sender` is a script address** (cannot sign `CancelOrder`; Minswap's own README warns of
  this) — dust amounts, stuck by construction.

## 6. Caveats / blockers

- The Minswap market-data API defaults to a non-USD denomination; all TVL figures here were re-pulled with
  `"currency":"usd"` (the earlier ADA-denominated run is kept for reference as `raw/minswap_v1_all_pools.json`).
- The census covered the top 7,000 V1 pools by liquidity (the tail is dust); the on-chain pool address holds a
  large junk/dust UTxO set and Koios truncates `address_info` at 6,998 entries, so the on-chain ADA figure is a
  lower bound (top pools match the census exactly, which is why the census is used for TVL).
- The AMM math review is manual, not machine-verified; a subtle arithmetic bug remains the only residual path
  (would still require a batcher licence to execute).
- The CEK proof uses synthetic contexts consistent with the deployed script's constants; it demonstrates
  validator behaviour, not a specific live pool transaction.

## 7. Files

- `raw/`: deployed script CBORs (`minswap_v1_*_script.cbor`), Tweag audit PDFs + text, Minswap census JSON.
- `scripts/`: `poc_cek_eval.py` (uplc AST builder + evaluator), `run_cek_aiken.py`, `make_cek_args.py`,
  `uplc/` decompiled scripts (A/B), `pool_A.uplc`, `pool_B.uplc`, builtin streams.
- `out_cek/`: aiken CEK results + full logs (`cek_legit.log`, `cek_attack.log`).
- `ci/cek_cases.py`, `ci/run.sh`: standalone CI reproduction; `ci-out/minswap-v1-cek.json`.
- CI run (success): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38026892333 (artifact
  `result-non-evm-cluster`, `ci-out/minswap-v1-cek.json` — LEGIT ACCEPT, both ATTACKs REJECT).
- Cross-checks: `analysis/cardano/minswap-v1/scripts/` (uplc comparison), `myway-contracts` mirror (not vendored
  to keep the repo light — see `raw/SOURCES.md`).

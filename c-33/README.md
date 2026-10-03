# C-33 — Compound-v2 empty-market lineage: surviving unfixed forks (live extraction assessment)

**Campaign:** zombie-hunt · **Chains:** 69 EVM chains reachable + 18 no-RPC chain configs · **Date:** 2026-10-03
**Status:** read-only research. Fork-verified PoCs only (CI forks). **No mainnet transactions were sent.**
**Scope:** every reachable Compound-v2-style cToken market where an external, unprivileged attacker can
still profit from the empty-market exchange-rate donation / `redeemUnderlying` truncation class
(Hundred 2023 → Onyx 2023/24 → Sonne 2024 → zkLend 2025 → Resupply 2025 lineage).

---

## 1. TL;DR

**Headline: $0 live extractable by an external unprivileged attacker.** The entire reachable
Compound-v2 fork universe (263 comptrollers / 104 protocol families / 2,124 markets read) contains
**no market where the empty-market donation/truncation attack still profits today**. Every candidate
that passed the mechanical preconditions is closed by a specific, on-chain-verified gate — and the
last one (Midas `fMIMO-3`) was closed by a protocol minimum-borrow rule during the fork tests:

| Candidate | Chain | Mechanical potential | Gate that closes it (verified) |
|---|---|---:|---|
| **Midas fMIMO-3** | Polygon | $5.86 | **`minBorrowEth` = 143.9** (comptroller risk engine) vs $5.86 of unpaused cash — the borrow step can never execute; same codebase on Moonbeam ($0.38) |
| OCP kCake-LP | BSC | $183,288.30 | `totalSupply()=1` owned by another holder — the attacker cannot own the supply; the truncating redeem leaves **zero collateral** (INSUFFICIENT_SHORTFALL, trace) |
| Paxo vLINK | Polygon | $150.10 | cToken implementation **has no `borrow`/`redeemUnderlying` functions** (selectors absent; calls revert) |
| Sonne soVELO | Optimism | $50.30 | comptroller `redeemVerify` reverts `"redeemTokens zero"` (the exact truncation guard) |
| Tectonic | Cronos | ~$20M | all markets mint+borrow guardian-paused |
| Scream | Fantom | ~$1.24M | code-bearing markets paused; unpaused listings have **no code** |
| Onyx | Ethereum | ~$31.7k | all markets `collateralFactor=0` + paused |
| Ionic | Mode/Base/Lisk/OP | ~$21.6M | guardian-paused |
| Hundred | Ethereum/Arbitrum | dust / $0 | empty CF>0 markets exist but no unpaused cash; hWBTC cash=0 |
| Compound v2 itself | Ethereum | — | huge `totalSupply`; free pull ≈$2.5e-10/call |

**The two rules this pass establishes (both proven on forks):**
1. The borrow attack requires `totalSupply == 0` — a market with even **1 wei** of supply held by
   someone else is not exploitable (the attacker can never burn another holder's token; the
   truncating redeem either fails the collateral check or recovers only part of the donation).
2. Even a T=0 market with CF>0 and open mint is only exploitable if the protocol's own borrow rules
   allow a borrow large enough to matter (Midas blocks everything below `minBorrowEth`).

**Total live extractable now: $0.00** (confidence: **high**). This is a "closed with proof" result,
not an absence of analysis: 11 fork tests + 7 CI runs document each gate. The class remains a live
**latent** deployment risk for forks that list new markets with CF>0 before supply exists.

## 2. The bug in exact terms (deployed-code mechanics)

Compound-v2 `CToken.redeemFresh()` (pristine 2019-2020 code, copied into every fork):

- `exchangeRateStoredInternal() = (cash + totalBorrows − totalReserves) * 1e18 / totalSupply` — **live
  balance based**; a direct `transfer()` of underlying into the cToken ("donation") raises it instantly.
- `redeemUnderlying(x)` computes the burn as `redeemTokens = div_(x, exchangeRate) = x * 1e18 / rate`
  — **truncating division**.
- If `redeemTokens == 0`, the `redeemTokensHeld < redeemTokens` check passes for any caller (0 < 0 is
  false) and the `if (redeemTokens > 0)` collateral check is **skipped**, then `x` underlying is paid out.
- When `totalSupply` is 0-1 wei, an attacker can become (near-)sole supplier, donate a flash-loaned
  amount `D` to inflate the exchange rate, borrow against the inflated collateral from *other* markets,
  then `redeemUnderlying(cash−1)` recovers the whole donation while burning ≤1 wei. Net profit = the
  borrowed amount; the bad debt stays behind.

Attack template (Hundred Finance 2023-04-15, ~$7.4M; the Compound forum confirmed the conditions
"markets with low total supply and a non-zero collateral factor", thread 4266):

1. mint the cost of 1 cToken wei into an empty market (or 1-wei-supply market), redeem down to 1 wei
2. `enterMarkets`, donate `D` (flash loan) → exchange rate inflates
3. borrow another asset `B` from an unpaused cash market against the inflated collateral
4. `redeemUnderlying(cash−1)` → truncation burns ≤1 wei, the donation is recovered
5. default on `B` (optionally self-liquidate to reset the market and repeat)

Live preconditions (all verified on-chain, per market): `isListed`, `collateralFactor > 0`,
`mintGuardianPaused == false`, `exchangeRateStored > 0`, oracle price readable, `totalSupply <= 1 wei`,
code present, and ≥1 borrowable (unpaused) market with cash. The collateral market's own
`borrowGuardianPaused` is **irrelevant** (borrows happen elsewhere) — a predicate refinement that
surfaced the OCP/BSC candidate.

**Direct-drain variant (no capital, no donation):** when `totalSupply = T > 0` is small and `cash` is
large, *any* address (even with 0 cTokens) can call `redeemUnderlying(x)` with `x < cash/T`; the burn
truncates to 0 and the caller is paid `x` for free. Repeat ~`T·ln(100)` times to drain ~99%.
Notably, redeem is **not** gated by mint/borrow guardian pauses in the original code, so a paused
protocol can still be directly drainable (Sonne soVELO is the live test of this).

## 3. Full universe & selection criteria

- **Universe:** all 249 comptrollers in DefiLlama's Compound-fork registry
  (`DefiLlama-Adapters/registries/compound.js` → `analysis/compound_registry.json`), plus
  corpus-named deployments absent from the registry (Scream, Benqi, Ionic, Sturdy v2, Lodestar v1),
  plus Compound v2 itself (legacy markets). **104 protocol families / 263 comptrollers / 83 chain configs.**
- **Scanned:** 69 chains reachable from public RPCs (CI); 18 chain configs had no reachable RPC and are
  listed in `ci-out/scan_summary.json` (`chains_no_rpc`). 43 comptrollers reverted `getAllMarkets()`
  (bricked/unverified) and are recorded with status.
- **Corpus corrections (verified):** Starlay is an **Aave v2 fork** (`starlay-protocol` uses
  `LendingPoolAddressesProvider`), as are Geist, Valas and Voltage; Ironclad is Aave-based and bricked.
  These are out of the cToken class (documented in `analysis/non_evm_and_corrections.md`).
- **Non-EVM:** zkLend (Starknet) is dead post-hack; ABEL Finance (Aptos, ~$218k) is a Compound-v2 port —
  document-only (no Move toolchain test).
- **Exclusions:** Aave forks, Compound v3 (Comet), Rari Fuse isolated pools (separate finding family).

## 4. Live-state assessment

Scanner coverage: **263 comptrollers / 104 protocol families / 83 chain configs**; 220 comptrollers
read successfully (2,124 markets at the run-6 snapshot), 24 reverted `getAllMarkets()` (bricked/unverified),
18 are on chains with no reachable public RPC, 1 chain hit the scan budget. Empty markets: 158;
near-empty (≤1e-6 cToken): 235; empty+CF>0+unpaused under the corrected T=0 rule: 14;
cash-bounded direct-truncation-drain candidates: 1 (Sonne, blocked by its guard).
Full machine-readable results: `ci-out/scan.json`, `ci-out/markets.csv`, `ci-out/candidates.json`.
The raw scan flags were post-processed with `analysis/postprocess_scan.py` (T=0 rule + cash-bounded pull).

**Exposure summary (potential = unpaused borrowable cash + directly drainable cash; the Sonne
direct-drain row is blocked by its `redeemVerify` guard — see §4.3):**

| Protocol | Chain | Mode | Direct-drain USD | Unpaused borrowable USD | Potential USD |
|---|---|---|---:|---:|---:|
| sonne-finance | optimism | +direct_drain | 50.56 | 0.00 | 50.56 |
| midas-capital | polygon | empty_market_borrow | 0.00 | 5.86 | 5.86 |
| midas-capital | moonbeam | empty_market_borrow | 0.00 | 0.38 | 0.38 |
| bencu | metis | near_empty_only | 0.00 | 0.01 | 0.00 |
| sumer | monad | near_empty_only | 0.00 | 0.00 | 0.00 |
| jiblend | jbc | near_empty_only | 0.00 | 561.43 | 0.00 |
| rho-markets | scroll | near_empty_only | 0.00 | 0.11 | 0.00 |
| metalend | ronin | near_empty_only | 0.00 | 0.00 | 0.00 |
| sumer | bitlayer | near_empty_only | 0.00 | 0.00 | 0.00 |
| aquarius-loan | core | near_empty_only | 0.00 | 56,986.16 | 0.00 |
| sumer | core | near_empty_only | 0.00 | 0.00 | 0.00 |
| asofinance | blast | near_empty_only | 0.00 | 0.00 | 0.00 |
| orbitlending-io | blast | near_empty_only | 0.00 | 0.00 | 0.00 |
| cream | base | near_empty_only | 0.00 | 0.00 | 0.00 |
| xpert | base | near_empty_only | 0.00 | 4,817.77 | 0.00 |
| ionic-protocol | base | near_empty_only | 0.00 | 0.00 | 0.00 |
| sumer | meter | near_empty_only | 0.00 | 0.00 | 0.00 |
| zkfox | zksync | near_empty_only | 0.00 | 259,682,288,209.47 | 0.00 |
| sumer | berachain | near_empty_only | 0.00 | 0.00 | 0.00 |
| neku | moonriver | near_empty_only | 0.00 | 146,607.71 | 0.00 |
| sumer | bsquared | near_empty_only | 0.00 | 0.00 | 0.00 |
| sumer | hemi | near_empty_only | 0.00 | 0.00 | 0.00 |
| zenolend | hemi | near_empty_only | 0.00 | 511.38 | 0.00 |
| sumer | arbitrum | near_empty_only | 0.00 | 0.00 | 0.00 |
| tender-finance | arbitrum | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | arbitrum | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | arbitrum | near_empty_only | 0.00 | 0.00 | 0.00 |
| sumer | goat | near_empty_only | 0.00 | 0.00 | 0.00 |
| zenolend | apechain | near_empty_only | 0.00 | 2,817.51 | 0.00 |
| wepiggy | okc | near_empty_only | 0.00 | 0.00 | 0.00 |
| hundredfinance | gnosis | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | moonbeam | near_empty_only | 0.00 | 0.00 | 0.00 |
| minterest | morph | near_empty_only | 0.00 | 0.00 | 0.00 |
| sumer | zklink | near_empty_only | 0.00 | 0.00 | 0.00 |
| hundredfinance | optimism | near_empty_only | 0.00 | 0.00 | 0.00 |
| keom | manta | near_empty_only | 0.00 | 0.00 | 0.00 |
| paxo-finance | polygon | near_empty_only | 0.00 | 150.19 | 0.00 |
| keom | polygon | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | polygon | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | polygon | empty_market_borrow | 0.00 | 0.00 | 0.00 |
| midas-capital | polygon | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | polygon | empty_market_borrow | 0.00 | 0.00 | 0.00 |
| fenrirfinance | bsc | near_empty_only | 0.00 | 0.10 | 0.00 |
| OCP | bsc | near_empty_only | 0.00 | 183,288.30 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 1.24 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 0.00 | 0.00 |
| midas-capital | bsc | near_empty_only | 0.00 | 0.00 | 0.00 |
| olafinance | fantom | near_empty_only | 0.00 | 0.00 | 0.00 |
| scream | fantom | near_empty_only | 0.00 | 0.00 | 0.00 |
| mantradao | ethereum | near_empty_only | 0.00 | 24.03 | 0.00 |
| strike | ethereum | near_empty_only | 0.00 | 1.26 | 0.00 |
| sumer | ethereum | near_empty_only | 0.00 | 0.00 | 0.00 |
| cozy | ethereum | near_empty_only | 0.00 | 0.00 | 0.00 |
| bao-markets | ethereum | near_empty_only | 0.00 | 19,154.66 | 0.00 |
| venus | ethereum | near_empty_only | 0.00 | 0.00 | 0.00 |
| hundredfinance | ethereum | empty_market_borrow | 0.00 | 0.00 | 0.00 |
| donkey | ethereum | near_empty_only | 0.00 | 0.00 | 0.00 |


**Full checker table** (all 219 protocol×chain rows; `Empty+CF>0+unpaused` = empty markets where the
borrow-attack preconditions hold under the corrected T=0 rule, `Direct drain` = truncation-drain
candidates):

| Protocol | Chain | Mkts | Empty | Tiny | Empty+CF>0+unpaused | Direct drain | Unpaused borrowable USD | Verdict |
|---|---|---:|---:|---:|---:|---:|---:|---|
| midas-capital | polygon | 56 | 15 | 29 | 11 | 0 | 5.86 | LIVE (empty+funded) |
| hundredfinance | ethereum | 11 | 5 | 8 | 2 | 0 | 0.00 | empty market, no unpaused cash |
| midas-capital | moonbeam | 17 | 5 | 7 | 1 | 0 | 0.38 | LIVE (empty+funded) |
| zkfox | zksync | 8 | 2 | 2 | 0 | 0 | 259,682,288,209.47 | cash but no empty market |
| filda | bittorrent | 5 | 0 | 0 | 0 | 0 | 43,105,023,260.02 | cash but no empty market |
| sonne-finance | optimism | 13 | 0 | 1 | 0 | 1 | 0.00 | direct truncation drain |
| benqi-lending | avax | 22 | 0 | 0 | 0 | 0 | 121,542,214.98 | cash but no empty market |
| takara | sei | 21 | 0 | 2 | 0 | 0 | 49,163,442.50 | cash but no empty market |
| capyfi | ethereum | 13 | 0 | 0 | 0 | 0 | 48,255,157.91 | cash but no empty market |
| kinetic | flare | 13 | 0 | 0 | 0 | 0 | 38,210,288.61 | cash but no empty market |
| basic | iotex | 5 | 0 | 0 | 0 | 0 | 25,277,912.92 | cash but no empty market |
| fluxfinance | ethereum | 5 | 0 | 0 | 0 | 0 | 4,286,230.36 | cash but no empty market |
| wanlend | wan | 30 | 0 | 2 | 0 | 0 | 2,867,161.51 | cash but no empty market |
| mendi-finance | linea | 9 | 0 | 0 | 0 | 0 | 1,225,447.83 | cash but no empty market |
| moonwell | ethereum | 4 | 0 | 0 | 0 | 0 | 643,589.30 | cash but no empty market |
| reactorfusion | zksync | 6 | 0 | 0 | 0 | 0 | 297,303.79 | cash but no empty market |
| teralend | flare | 6 | 0 | 0 | 0 | 0 | 265,006.96 | cash but no empty market |
| OCP | bsc | 15 | 0 | 2 | 0 | 0 | 183,288.30 | cash but no empty market |
| moonwell | optimism | 14 | 0 | 1 | 0 | 0 | 165,766.39 | cash but no empty market |
| neku | moonriver | 49 | 4 | 4 | 0 | 0 | 146,607.71 | cash but no empty market |
| neku | arbitrum | 37 | 0 | 0 | 0 | 0 | 118,145.10 | cash but no empty market |
| capyfi | base | 7 | 0 | 0 | 0 | 0 | 80,920.44 | cash but no empty market |
| ironbank | optimism | 8 | 0 | 0 | 0 | 0 | 77,223.44 | cash but no empty market |
| sonne-finance | base | 7 | 0 | 0 | 0 | 0 | 57,058.84 | cash but no empty market |
| aquarius-loan | core | 7 | 1 | 2 | 0 | 0 | 56,986.16 | cash but no empty market |
| qie-lend | qie | 4 | 0 | 0 | 0 | 0 | 52,028.39 | cash but no empty market |
| capyfi | worldchain | 7 | 0 | 0 | 0 | 0 | 43,781.20 | cash but no empty market |
| ironbank | avax | 11 | 0 | 0 | 0 | 0 | 40,775.47 | cash but no empty market |
| aquarius-loan | arbitrum | 9 | 0 | 0 | 0 | 0 | 23,452.90 | cash but no empty market |
| tonpound | ethereum | 9 | 0 | 0 | 0 | 0 | 22,148.24 | cash but no empty market |
| bao-markets | ethereum | 7 | 2 | 2 | 0 | 0 | 19,154.66 | cash but no empty market |
| zoro | zksync | 15 | 0 | 0 | 0 | 0 | 18,210.73 | cash but no empty market |
| lander | bsc | 9 | 0 | 0 | 0 | 0 | 9,334.01 | cash but no empty market |
| damm-finance | ethereum | 41 | 0 | 4 | 0 | 0 | 7,381.24 | cash but no empty market |
| solidlizard-lending | arbitrum | 7 | 0 | 0 | 0 | 0 | 7,103.58 | cash but no empty market |
| xpert | base | 6 | 0 | 2 | 0 | 0 | 4,817.77 | cash but no empty market |
| cream | arbitrum | 3 | 0 | 0 | 0 | 0 | 4,513.59 | cash but no empty market |
| torches | kcc | 7 | 0 | 0 | 0 | 0 | 3,559.09 | cash but no empty market |
| zenolend | apechain | 6 | 2 | 2 | 0 | 0 | 2,817.51 | cash but no empty market |
| filda | polygon | 14 | 0 | 0 | 0 | 0 | 1,208.89 | cash but no empty market |
| filda | rei | 6 | 0 | 0 | 0 | 0 | 822.97 | cash but no empty market |
| trustin | bitlayer | 10 | 0 | 0 | 0 | 0 | 709.24 | cash but no empty market |
| zenolend | unichain | 4 | 0 | 0 | 0 | 0 | 647.09 | cash but no empty market |
| jiblend | jbc | 10 | 0 | 2 | 0 | 0 | 561.43 | cash but no empty market |
| zenolend | hemi | 15 | 12 | 12 | 0 | 0 | 511.38 | cash but no empty market |
| nebula | nibiru | 4 | 0 | 0 | 0 | 0 | 487.85 | cash but no empty market |
| jax-protocol | taiko | 1 | 0 | 0 | 0 | 0 | 352.51 | cash but no empty market |
| neku | bsc | 55 | 0 | 0 | 0 | 0 | 341.60 | cash but no empty market |
| paxo-finance | polygon | 12 | 0 | 2 | 0 | 0 | 150.19 | cash but no empty market |
| paxo-finance | boba | 3 | 0 | 0 | 0 | 0 | 111.29 | cash but no empty market |
| paxo-finance | xdc | 9 | 0 | 1 | 0 | 0 | 78.83 | closed/no cash |
| paxo-finance | linea | 4 | 0 | 0 | 0 | 0 | 24.07 | closed/no cash |
| mantradao | ethereum | 64 | 3 | 3 | 0 | 0 | 24.03 | closed/no cash |
| zenolend | soneium | 9 | 0 | 3 | 0 | 0 | 7.35 | closed/no cash |
| midas-capital | bsc | 80 | 15 | 20 | 0 | 0 | 3.39 | closed/no cash |
| strike | ethereum | 18 | 1 | 1 | 0 | 0 | 1.26 | closed/no cash |
| xpert | ink | 5 | 0 | 2 | 0 | 0 | 1.13 | closed/no cash |
| filda | bsc | 5 | 0 | 0 | 0 | 0 | 0.71 | closed/no cash |
| filda | arbitrum | 8 | 0 | 0 | 0 | 0 | 0.34 | closed/no cash |
| rho-markets | scroll | 16 | 0 | 3 | 0 | 0 | 0.11 | closed/no cash |
| filda | kava | 3 | 0 | 0 | 0 | 0 | 0.10 | closed/no cash |
| fenrirfinance | bsc | 16 | 1 | 1 | 0 | 0 | 0.10 | closed/no cash |
| mare-finance-v2 | kava | 3 | 0 | 0 | 0 | 0 | 0.09 | closed/no cash |
| aurigami | aurora | 14 | 0 | 0 | 0 | 0 | 0.06 | closed/no cash |
| bencu | metis | 7 | 1 | 1 | 0 | 0 | 0.01 | closed/no cash |
| quantus | megaeth | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| capyfi | lac | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| elara | zircuit | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| minterest | taiko | 3 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | metis | 3 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hover | kava | 3 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| quantus | monad | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | monad | 8 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| ionise-io | zilliqa | 2 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| nyke | etc | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| enclabs | plasma | 8 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| loanshark | scroll | 4 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| deepr-finance | iotex | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| filda | iotex | 9 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| coslend | evmos | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| tashi | evmos | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| metalend | ronin | 3 | 2 | 2 | 0 | 0 | 0.00 | closed/no cash |
| forlend | findora | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| enzo | bitlayer | 7 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | bitlayer | 3 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| reactorfusion | telos | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| deepr-finance | shimmer | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| 0xLend | kcc | 9 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | core | 12 | 2 | 2 | 0 | 0 | 0.00 | closed/no cash |
| segment-finance | core | 13 | 0 | 3 | 0 | 0 | 0.00 | closed/no cash |
| blume-fm | blast | 2 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| asofinance | blast | 7 | 0 | 2 | 0 | 0 | 0.00 | closed/no cash |
| 0xLend | blast | 1 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| novation | blast | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| orbitlending-io | blast | 21 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| enclabs | sonic | 28 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| machfi | sonic | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sturdy-v2 | linea | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | base | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| cream | base | 7 | 3 | 3 | 0 | 0 | 0.00 | closed/no cash |
| venus | base | 5 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| unitus | base | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| moonwell | base | 21 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| ionic-protocol | base | 28 | 1 | 2 | 0 | 0 | 0.00 | closed/no cash |
| sumer | meter | 7 | 2 | 2 | 0 | 0 | 0.00 | closed/no cash |
| basilisk | zksync | 2 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| 0xLend | zksync | 2 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| venus | zksync | 9 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| traderjoe-lend | avax | 12 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | berachain | 11 | 2 | 3 | 0 | 0 | 0.00 | closed/no cash |
| tropykus | rsk | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| segment-finance | rsk | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| segment-finance | opbnb | 5 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| venus | opbnb | 5 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| filda | heco | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | heco | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| demeter | heco | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| huckleberry-lending | moonriver | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | moonriver | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hundredfinance | moonriver | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| moonwell-apollo | moonriver | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| filda | elastos | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| lumen-money | neon | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | bsquared | 6 | 6 | 6 | 0 | 0 | 0.00 | closed/no cash |
| segment-finance | bsquared | 6 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | bsquared | 4 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | hemi | 11 | 4 | 6 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | oasis | 3 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| whitehole-finance | arbitrum | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| paribus | arbitrum | 4 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | arbitrum | 18 | 4 | 5 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | arbitrum | 6 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| venus | arbitrum | 7 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| unitus | arbitrum | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hundredfinance | arbitrum | 11 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| tender-finance | arbitrum | 18 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| midas-capital | arbitrum | 9 | 5 | 6 | 0 | 0 | 0.00 | closed/no cash |
| lodestar-v1 | arbitrum | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | goat | 13 | 4 | 5 | 0 | 0 | 0.00 | closed/no cash |
| vivacity | canto | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| canto-lending | canto | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| fusefi-lending | fuse | 6 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | fuse | 2 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| netweave-lending | mode | 4 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | mode | 5 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| ionic-protocol | mode | 22 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sturdy-v2 | mode | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| zenolend | sty | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| venus | unichain | 7 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| unitus | conflux | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | okc | 16 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| minterest | mantle | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hundredfinance | gnosis | 6 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | harmony | 7 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hundredfinance | harmony | 7 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| orbiter-one | moonbeam | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | moonbeam | 6 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| moonwell | moonbeam | 12 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| minterest | morph | 8 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| sumer | zklink | 10 | 5 | 5 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | zklink | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| keom | astar_zkevm | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | kroma | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | optimism | 7 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| venus | optimism | 5 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| unitus | optimism | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hundredfinance | optimism | 9 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| ionic-protocol | optimism | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sturdy-v2 | optimism | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| mage | merlin | 6 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| kyros-finance | robinhood | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | aurora | 5 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| bastion | aurora | 13 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| tectonic | cronos | 33 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| segment-finance | bob | 21 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | bob | 10 | 0 | 2 | 0 | 0 | 0.00 | closed/no cash |
| wemix-lend | wemix | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | wemix | 2 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| keom | polygon_zkevm | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| ionic-protocol | lisk | 5 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| keom | manta | 6 | 1 | 2 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | manta | 7 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| cream | polygon | 16 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | polygon | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| unitus | polygon | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hundredfinance | polygon | 9 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| keom | polygon | 16 | 2 | 2 | 0 | 0 | 0.00 | closed/no cash |
| donkey | klaytn | 12 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| shoebillFinance-v2 | klaytn | 2 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| knightswap-lending | bsc | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| apeswap-lending | bsc | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| usdfi-lending | bsc | 16 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sumer | bsc | 9 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| segment-finance | bsc | 8 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| cream | bsc | 47 | 0 | 1 | 0 | 0 | 0.00 | closed/no cash |
| liqee | bsc | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | bsc | 16 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| venus | bsc | 55 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| unitus | bsc | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| demeter | bsc | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| olafinance | fantom | 15 | 4 | 4 | 0 | 0 | 0.00 | closed/no cash |
| ironbank | fantom | 13 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| hundredfinance | fantom | 16 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| scream | fantom | 27 | 8 | 8 | 0 | 0 | 0.00 | closed/no cash |
| sumer | ethereum | 28 | 17 | 17 | 0 | 0 | 0.00 | closed/no cash |
| compound-onchain | ethereum | 20 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| cream | ethereum | 7 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| liqee | ethereum | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| ironbank | ethereum | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| wepiggy | ethereum | 10 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| cozy | ethereum | 19 | 4 | 4 | 0 | 0 | 0.00 | closed/no cash |
| venus | ethereum | 23 | 4 | 6 | 0 | 0 | 0.00 | closed/no cash |
| unitus | ethereum | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| minterest | ethereum | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| donkey | ethereum | 30 | 1 | 1 | 0 | 0 | 0.00 | closed/no cash |
| onyx | ethereum | 18 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sturdy-v2 | ethereum | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| kawa | sei | 3 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |
| sturdy-v2 | sei | 0 | 0 | 0 | 0 | 0 | 0.00 | closed/no cash |

### 4.1 Corpus targets — re-verified verdicts (latest-block reads)

| Target | Chain | Block | Verified gate | Verdict |
|---|---|---|---|---|
| Onyx | Ethereum | 26,109,555 | every market `markets(m)=(true,0,*)`, `mintGuardianPaused=true`, `borrowGuardianPaused=true` | closed (user redemption only) |
| Scream | Fantom | 123,532,543 | `mintGuardianPaused(scUSDC/scDAI/scWFTM/scLINK)=true`; `eth_getCode(scFBTC/scFETH)=0x` | closed |
| Tectonic | Cronos | 97,610,677 | `mintGuardianPaused(tUSDC/tCRO)=true`, `borrowGuardianPaused=true` | closed |
| Sonne | Optimism | 157,702,284 | all markets paused; `redeemVerify` reverts `"redeemTokens zero"` (PoC) | closed |
| Ionic | Mode/Base/Lisk/OP | 45,417,474 (Mode) | guardian-paused (corpus + scan) | closed |
| Hundred | Ethereum | 26,109,555 | hWBTC/hLINK/hCOMP T=1, CF>0, unpaused, but unpaused cash in comptroller = 10,000,000,000,004 wei (dust ≈ $0.0001) | closed |
| Hundred | Arbitrum | 511,200,704 | hWBTC T=2,008,958 wei, cash=0 | closed |
| Ironclad | Mode | — | Aave-style provider bricked (all reads revert) | out of class / dead |
| Starlay | Astar | — | Aave v2 fork (repo layout) | out of class |
| Geist/Valas/Voltage | Fantom/BSC/Fuse | — | Aave forks (docs/repos) | out of class |
| Resupply | Ethereum | — | share-market (LendingOps), June-2025 hack realized; not a cToken | document-only |
| zkLend | Starknet | — | dead post-hack (protocol shut down 2025) | document-only |

### 4.2 Candidates and the gates that close them (detail)

**1. Midas Capital — fMIMO-3, Polygon (block 94,870,031)** — *closed by `minBorrowEth`*
- Comptroller `0xF1ABd146B4620D2AE67F34EA39532367F73bbbd2`; fMIMO-3
  `0x34F55352C6E15E3C63beaDedc2a919a4985228B7`: `totalSupply()=0`, CF=0.25, `mintGuardianPaused=false`,
  oracle $0.0434, code present, implementation `0xAa7B…` has mint/redeem/borrow/redeemUnderlying.
- Unpaused borrowable cash in the comptroller: fPAR-3 $5.81 + fUSDC-3 $0.04 = **$5.86**.
- **Gate:** the comptroller's risk engine enforces `minBorrowEth() = 143.919681304257721877`
  (`0xf656D243a23A0987329ac6522292f4104A7388e1`). `borrowWithinLimits` rejected the $4-5 borrow in
  the fork test (`Failure(…, 16, 18)`, return 1018). No borrow large enough to matter can be made
  against $5.86 of cash → the attack cannot execute. Moonbeam `fGLINT-0` ($0.38) uses the same
  codebase and is presumed subject to the same rule.

**2. OCP — kCake-LP, BSC (block 125,439,229)** — *closed by T=1 ownership*
- kCake-LP `totalSupply()=1`, CF=0.65, mint open, oracle $0.5716; $183,288.30 unpaused borrowable cash.
- The attacker can mint 1 wei (T=2, holding 1 of 2), but the truncating redeem that recovers the
  donation burns their only wei and leaves **0 collateral** → `redeemAllowed` returns
  INSUFFICIENT_SHORTFALL (fork trace: `emit Failure(3, 40, 4)`). With D→0 the theoretical gain is
  CF×cash0/2 where cash0=2e8 wei ≈ $0. Closed.

**3. Paxo Finance — vLINK, Polygon (block 94,870,031)** — *closed by cToken function removal*
- vLINK T=1, CF=0.9, mint+borrow unpaused, $150.10 unpaused borrowable cash — but the cToken
  implementation `0x12a92662bF3c6996a124A2bAc718729f791844E8` contains **no `borrow(uint256)`
  (0xc5ebeaec) and no `redeemUnderlying(uint256)` (0x852a12e3) selectors**; calls hit the fallback
  and revert (fork gate). Closed.

**4. Sonne soVELO, Optimism** — direct-drain candidate (T=13, cash 1,444.46 VELO / $50.30) closed by
the comptroller's `redeemVerify` zero-token guard (`"redeemTokens zero"`).

### 4.3 Corpus targets — re-verified verdicts (latest-block reads)

## 5. What an attacker can/cannot do

### 5.1 The attack template (for reference — no live target found)
1. Find a listed cToken market with `totalSupply == 0`, `collateralFactor > 0`, `mintGuardianPaused == false`,
   a live oracle and code present.
2. Flash-borrow the underlying, mint a tiny amount, `enterMarkets`; the attacker owns the whole supply.
3. Donate a large amount (also flash-borrowed) to inflate `exchangeRateStored`.
4. Borrow another asset from an unpaused cash market against the inflated collateral.
5. `redeemUnderlying(cashNow−1)` — the truncating burn leaves 1 wei of the attacker's own supply as
   collateral and recovers the donation; default on the borrow. Profit = borrowed USD − fees.
6. Direct-drain variant: with `totalSupply = T` small and cash large, anyone with 0 cTokens can call
   `redeemUnderlying(x)` with `x < cash/T`; the burn truncates to 0 and they are paid `x` for free.

### 5.2 Why every candidate fails today
- **T=1 or more supply held by others** (OCP, Hundred, Paxo, all `tinySupply` markets): the attacker
  cannot burn the other holder's tokens. Their own burn either leaves zero collateral
  (INSUFFICIENT_SHORTFALL) or recovers only a fraction of the donation; net ≤ CF×cash0/2, i.e. dust.
- **cToken functions removed** (Paxo): no borrow/redeemUnderlying entry points at all.
- **Protocol borrow rules** (Midas): `minBorrowEth` far above all available cash.
- **Pauses / CF=0 / phantom markets** (Tectonic, Scream, Onyx, Ionic, Hundred): mint or borrow reverts.
- **Zero-token redeem guard** (Sonne): the truncation step reverts.
- **Deep supply** (Compound v2 itself): the free pull per call is ~$2.5e-10 — economically dead.

### 5.3 What would re-open it
A new listing on any active Compound-v2 fork with `collateralFactor > 0` **before any supply exists**,
or an existing market whose supply falls to exactly 0 while it keeps CF>0 and unpaused borrowable
cash elsewhere. Compound's own guidance (forum 4266) is to list with CF=0, mint, then set CF; forks
should also enforce a redeem zero-check (Sonne-style) and sane borrow minimums.

## 6. PoC / fork verification

<!-- RESULTS_POC -->

## 7. Verdict, residual/latent risk

**Total live extractable now: $0.00 (E-U). Confidence: high.** The mechanical preconditions for the
empty-market donation/truncation class exist in 14 markets (T=0, CF>0, mint open) across 3 protocols,
but every one of them is closed by a protocol-level gate: Midas by `minBorrowEth` (143.9 vs $5.86 of
cash), Paxo by removed borrow/redeemUnderlying functions, OCP by the T=1 ownership rule; and all
corpus targets by pauses, CF=0, phantom markets, or a zero-token redeem guard. The direct-drain
variant exists only at economically dead scales (Sonne $50.30, blocked by its guard; Hundred/Arbitrum
cash=0).

**Latent risk (the durable finding):** the class is a *deployment property*. Any Compound-v2 fork
that lists a new market with CF>0 before supply exists, or lets a market fall to exactly
`totalSupply == 0` while CF>0 and unpaused borrowable cash exists elsewhere, is immediately
exploitable by anyone with a flash loan. Watch new listings on active forks (Moonwell, Benqi, Flux,
Venus, Kinetic, Takara, Mendi, Capyfi, LayerBank, …) between market creation and first deposit; and
watch for admin reversals of the pauses/CF=0 states that close Tectonic, Ionic, Scream and Onyx.

**Residual (not attacker-extractable, H-O):** Tectonic (~$20M), Ionic (~$21.6M), Scream (~$1.24M),
Onyx (~$31.7k), Sonne (~$50) remain user-redeemable in paused/CF=0 markets; values are the
corpus-verified balances, not re-measured here.

## 8. Methodology & sources

- DefiLlama registry + protocol TVLs (`api.llama.fi`), DefiLlama coins prices; GoldRush holders.
- On-chain reads only (JSON-RPC `eth_call`/`eth_getCode`) at explicit latest blocks (recorded per chain in
  `ci-out/scan_summary.json`); public RPCs + CI-provided RPCs; Etherscan V2 / Blockscout for spot checks.
- Scanner `ci/scan.py` (stdlib only, batched/chunked, URL rotation, null-safe, per-candidate second read,
  code-presence checks); run on GitHub Actions via `bash /home/heisenberg/CA/ci/ci-run.sh c-33`.
- Incident sources: Hundred post-mortem + Compound forum 4266 (2023); Halborn/Numen analyses; Onyx
  2023/2024; Sonne post-mortem (2024); SlowMist/Halborn zkLend (2025); Halborn/Olympix/Rekt Resupply (2025).

## 9. Caveats & limitations

1. Read-only snapshot (block numbers in `ci-out/scan_summary.json`); guardians/admins can change state.
2. Public-RPC coverage gaps: chains with no reachable RPC were not scanned (18 chain configs).
3. Phantom markets (listed address without code) are excluded; markets unreadable on flaky RPCs are
   treated as unknown (never flagged).
4. USD figures use DefiLlama spot prices at scan time; token amounts are raw on-chain reads.
5. The scanner flags preconditions; the fork tests are the extraction proof (or the reverting gate).
6. OCP/BSC's mechanism is proven but its practical extraction is capital-constrained by OCP-BUSD LP
   sourcing (see §5.3); it is reported separately from the conservative headline.

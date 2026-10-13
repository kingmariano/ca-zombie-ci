# Geist Finance (Fantom) — zombie deep-dive (L2 Phase 2)

**Date:** 2026-10-13 · **Chain:** Fantom Opera (chainId 250) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions**

Geist Finance is an Aave V2 fork on Fantom (deployed Aug 2021). It was put into
repay/withdraw-only mode in July 2023 after the Multichain bridge collapse (its reserve assets are
Multichain-bridged tokens), and formally wound down (`deadFrom 2023-10-18`). The pool is still live:
all 9 reserves are **frozen** (deposit/borrow blocked; withdraw/repay/liquidate open), the pool is
**not paused**, and the price oracle is **frozen** (Chainlink feeds dead, Band feeds stale since
2024-12-03) so every interaction is priced at the stored `lastGoodPrice` values from ~2024.

The aToken contracts still custody the reserves' cash (the original depositors' money), which the
Phase-1 triage counted at ~$124k using only LINK/CRV/MIM at canonical prices. On-chain, the whole
cash stack is ~$18.0M at the *frozen oracle* prices, but the reserve assets are **unbacked
Multichain tokens** whose live local DEX prices are 1.5–150× below the oracle: the same cash is
worth ≈ **$100–146k** when actually sold into the live Fantom DEX pools (SpookySwap + SpiritSwap,
measured on a fork).

---

## 1. TL;DR

| Surface | Live value | Extractable by fresh unprivileged attacker? | Why |
|---|---|---|---|
| LendingPool `0x9FAD24f5…d068` — aToken cash (all 9 reserves) | ≈ $100–146k realisable (DEX) / $18.0M at frozen oracle | **Only via liquidation of underwater debtors (E-U) — see §6/§7** | cash belongs to aToken holders; no permissionless function moves it to a non-holder |
| Treasury aToken fees held by staking/treasury contracts | aLINK 228.56, aCRV 105.75M(nom), aMIM 1.175M(nom), aDAI 269.1k, aETH 31.2, aWFTM 8.25B(nom) | No (H-O: stakers claim pro-rata; P: owner `recoverERC20`) | reward streams are effectively finished; a fresh staker earns ≈ 0 (PoC) |
| WFTM market (aWFTM 8.25B nominal) | **$0** | No — **S (stuck)**: cash = 0, withdrawal reverts | the market was drained; aWFTM is unbacked |
| GEIST staking (`0x49c93a95…`) | ~$4.6k of WFTM in GEIST/WFTM pair + 397.6M GEIST | No (H-O) | stakers' own deposits; `withdraw`/`exit` are self-service |
| Admin surfaces (freeze/pause/oracle/configurator) | — | No (P) | `LendingPoolConfigurator` is owned by pool admin `0xC03253FF…` |

**Total live extractable now (E-U):** pending liquidation scan — bounded above by the realisable
cash of the seizable collateral reserves (≈ **$100–146k**); the attacker must pay the debt tokens'
market price, so net E-U is lower (see §6–§8 for the exact per-position numbers).
**H-O:** ≈ $100–146k to aToken holders (first-come-first-served; several markets under-backed).
**S:** the WFTM market (8.25B nominal aWFTM with zero cash) and the unbacked part of aCRV/aMIM/aUSDC claims.

---

## 2. The protocol today, in exact terms

* **LendingPool proxy** `0x9FAD24f572045c7869117160A571B2e50b10d068` (impl `0x3104ad2aadb6fe9df166948a5e3a547004862f90`,
  EIP-1967 impl slot verified; admin slot = 0 → immutable). Source = stock Aave V2 (master) with one
  change: `_executeBorrow` prices with `IPriceOracleGetter.updateAssetPrice()` instead of
  `getAssetPrice()` (Geist's pull oracle). All user functions carry `whenNotPaused`; `paused() == false`.
* **LendingPoolAddressesProvider** `0x6c793c628Fe2b480c5e6FB7957dDa4b9291F9c9b`
  (getLendingPool / getPriceOracle / getPoolAdmin / getEmergencyAdmin / getLendingPoolConfigurator
  all read live). Pool admin = emergency admin = `0xC03253FFc57bC863c6F593bDCe394B533DF6a182`
  (contract, 170 bytes). Owner = `0x7FB9a7cBc6689C1C79e37BF8f852adA44b10EfFC` (contract, 5,922 bytes).
* **PriceOracle (AaveOracle)** `0xC466e3FeE82C6bdc2E17f2eaF2c6F1E91AD10FD3` → per-asset
  `PriceFeed` (Liquity-style Chainlink-primary/Band-fallback). **Every feed returns
  `fetchPrice() == lastGoodPrice()` and `status() == 1` (usingBandChainlinkUntrusted)**: the
  Chainlink aggregators revert on `latestRoundData()` and the Band `StdReference` base updates are
  frozen at 2024-12-03. `updatePrice()` is permissionless but a **no-op** (PoC-verified for all 9
  assets). Effective prices are therefore the stored ~2024 values below.
* **All 9 reserves are frozen** (`isFrozen=1`, `isActive=1`) → no deposits, no borrows;
  withdraw / repay / liquidationCall remain open. This is the "repay & withdraw only" wind-down state.

### Reserve state (block 123,677,183; direct RPC, public Fantom endpoint)

| # | sym | underlying | aToken | cash (underlying) | aToken supply (nominal) | variable debt (nominal) | oracle $ | live DEX $ |
|---|-----|-----------|--------|------------------|------------------------|------------------------|----------|-----------|
| 0 | DAI | 0x8D11eC38…bf3E | 0x07E6332d…DCFB | 632,692.86 | 914,308.12 | 281,688.80 | 0.99990 | 0.0129 |
| 1 | ETH | 0x74b23882…C76d | 0x25C130B2…A22f | 488.3336 | 497.3236 | 9.0088 | 2,519.05 | 26.3 |
| 2 | WFTM | 0x21be370D…4C83 | 0x39B3bd37…430a | **0** | 8,317,308,997.58 | 13,562,361,534.03 | 0.10746 | 0.0684 |
| 3 | BTC | 0x321162Cd…5b11 | 0x38aCa548…10A3 | 113.4801 | 113.8367 | 0.3566 | 68,615.04 | 1,066 |
| 4 | fUSDT | 0x049d6802…3C7A | 0x940F41f0…F6B5 | 7,634,561.11 | 7,951,693.08 | 317,136.43 | 0.99950 | 0.0567 |
| 5 | USDC | 0x04068DA6…5B75 | 0xe578C856…0b26 | 469,779.98 | 1,509,165.47 | 1,039,528.95 | 0.99992 | 0.117 |
| 6 | CRV | 0x1E4F97b9…C68b | 0x690754A1…8A98 | 107,517.02 | 107,867,898.39 | 128,719,113.57 | 0.35400 | 0.00427 |
| 7 | MIM | 0x82f0B8B4…829c1 | 0xc664Fc7b…3bBe | 173,780.29 | 1,493,215.95 | 1,562,951.79 | 0.99866 | 0.0426 |
| 8 | LINK | 0xb3654dc3…FBdC8 | 0xBeCF2926…F73B | 6,119.6206 | 6,616.1620 | 496.7385 | 8.72233 | 0.215 |

* Cash is held by the **aToken contracts** (Aave V2 design) — verified with direct
  `underlying.balanceOf(aToken)` reads for all nine.
* `liquidityIndex` (LI) vs `variableBorrowIndex` (VBI) show three years of unpayable debt:
  WFTM LI 30.88 / VBI 6,708.19, CRV LI 47.34 / VBI 7,565.65, MIM LI 3.29 / VBI 14.55 (all others ~1.02–1.2).
  The WFTM and CRV books are ~$0-realisable bad debt; the aToken claims there are 0–0.1% backed.

### Why the oracle price ≠ market price

The reserve assets are the **Multichain (Anyswap)-bridged tokens** (that is what killed the protocol:
"oracles misreporting Multichain token values", July 2023). Chainlink/Band feeds died with the
protocol, so the frozen `lastGoodPrice` still values them at ~2024 levels. Live local DEX prices
(SpookySwap **and** SpiritSwap show identical ratios → genuinely arbitraged market):

| asset | oracle $ | live DEX $ | oracle/market |
|---|---|---|---|
| DAI | 0.99990 | 0.0129 | 77× |
| ETH | 2,519.05 | 26.3 | 96× |
| WFTM | 0.10746 | 0.0684 | 1.6× |
| BTC | 68,615 | 1,066 | 64× |
| fUSDT | 0.99950 | 0.0567 | 18× |
| USDC | 0.99992 | 0.117 | 8.5× |
| CRV | 0.35400 | 0.00427 | 83× |
| MIM | 0.99866 | 0.0426 | 23× |
| LINK | 8.72233 | 0.215 | 41× |

DefiLlama's `fantom:LINK` price ($12.88) is an exact copy of `ethereum:LINK` (ratio 1.0000 for 90
days) — a bridged-token parity assumption, not a Fantom market price. The Fantom pools price
anyLINK at $0.215 (Spooky) / $0.215 (Spirit). The **backed** USDC on Fantom (native
`0x28a92dde…`) trades at $1.00 in its WFTM pool, while the Multichain USDC in Geist's reserve
(`0x04068DA6…`) trades at $0.117 — confirming the discount is asset-specific, not a chain-wide artifact.

### Realisable value of the cash (fork-measured)

Selling the entire aToken cash of each reserve through the live UniswapV2 routers (SpookySwap and
SpiritSwap, real pools) yields:

| asset | WFTM out (Spooky) | WFTM out (Spirit) |
|---|---|---|
| DAI | 61,197 | 519 |
| ETH | 110,669 | 22,874 |
| BTC | 293,657 | 25,802 |
| fUSDT | 392,637 | 34,132 |
| USDC | 552,652 | 462,295 |
| CRV | 5,036 | 21,694 |
| MIM | 43,948 | 88,348 |
| LINK | 14,817 | 13,244 |
| **total** | **1,474,613** | **688,908** |

≈ 2.16M WFTM ≈ **$148k** at FTM $0.0684 (CoinGecko). Selling everything is an upper bound (it
consumes the pools' WFTM sides); a realistic single-pass extraction is ≈ $100–120k. If any bridge
or off-ramp still honoured these tokens at canonical prices, the value would be far higher — none
was found (the Multichain bridge is dead; native-asset bridges do not accept these tokens).

---

## 3. Live-state assessment (roles, gates, custody)

* `paused() == false`; every reserve `isActive=1, isFrozen=1` (repay/withdraw/liquidate-only).
* Pool admin = emergency admin = `0xC03253FFc57bC863c6F593bDCe394B533DF6a182` (contract).
  `setPause(bool)` is `onlyLendingPoolConfigurator` → configurator proxy `0xb7C10e50…6AA8`.
* Oracle owner = `0x7FB9a7cBc6689C1C79e37BF8f852adA44b10EfFC` (contract). `setAssetSources` is `onlyOwner`.
* Treasury addresses (`RESERVE_TREASURY_ADDRESS()` on each aToken):
  * DAI/ETH/CRV/MIM/LINK → **the GEIST staking contract** `0x49c93a95dbcc9A6A4D8f77E59c038ce5020e82f8`
  * WFTM → `0x0F595677AfC5F4A99Cfa1dDB4a00B8f54Cfda506`
  * BTC/fUSDT/USDC → `0xfB6485AE36b3027eF109f271aD4C3ECFD651cF30`
* Treasury aToken balances (protocol fees already minted inline by `ReserveLogic._mintToTreasury` on
  every state update — there is no pending `mintToTreasury` queue):
  staking contract holds aLINK 228.5575, aCRV 105,754,391.19(nom), aMIM 1,175,144.41(nom),
  aDAI 269,124.64, aETH 31.19986; the WFTM treasury holds aWFTM 8,246,777,537.35(nom); the
  stablecoin treasury holds aBTC 0.00159310, afUSDT 4,319.10, aUSDC 85,566.46.
* **Staking rewards = those aTokens.** `MultiFeeDistribution.rewardTokens` = [GEIST, aDAI, aETH,
  aWFTM, aBTC, afUSDT, aUSDC, aCRV, aMIM, aLINK]; rewards are streamed pro-rata to all stakers
  (`totalSupply` = 386.56M GEIST staked, `lockedSupply` = 245.88M). Every reward token's stream is
  already fully accounted (`rewardData.balance` == the contract's actual balance) and the live
  `rewardRate` only streams the aToken interest accruing on the residual balances (dust).
  A fresh staker therefore earns ≈ 0 — PoC-verified (`test_fresh_staker_rewards_are_dust`).
* No aToken allowances to third parties were found that matter; aTokens are not transferable claims
  on others' cash without owning them.

---

## 4. What an attacker can / cannot do

**Cannot (all PoC-verified on a fork):**
1. Withdraw or redeem aToken cash without holding aTokens (`test_fresh_attacker_cannot_withdraw`,
   `test_fresh_attacker_cannot_redeem_aTokens` → revert).
2. Move the oracle: `updatePrice()` is permissionless but returns `lastGoodPrice` for every feed
   (Chainlink dead, Band frozen) → prices are immutable (`test_oracle_cannot_be_refreshed_by_attacker`).
3. Use admin paths: `setPause`, `setReserveFreeze`, `setAssetSources`, `recoverERC20` are all
   owner/configurator-gated (P).
4. Redeem unbacked markets: the WFTM market has zero cash → any aWFTM withdrawal reverts
   (`test_wftm_market_is_unbacked`).
5. Farm the staking contract: rewards are pro-rata and effectively finished.

**Can (E-U, subject to the liquidation scan):**
* Call `liquidationCall(collateral, debt, user, debtToCover, false)` for any user whose health factor
  at the *frozen* prices is < 1. Because the oracle overvalues every debt asset by 1.6–96× versus
  its live market price while the seizable collateral is capped by the *cash actually present in the
  collateral aToken*, an attacker who buys the debt asset cheaply on the local DEX can seize
  collateral aTokens (redeemable 1:1 up to cash) and resell them. Profit = collateral realisable
  value − debt market cost, capped by the collateral reserve's cash.
* Any aToken holder (incl. an attacker who acquires aTokens) can `redeem`/`withdraw` 1:1 up to cash
  (H-O) — demonstrated with the staking contract's aLINK (`test_holder_can_withdraw_its_aTokens`).

---

## 5. PoC / fork verification

Foundry project in `poc/` (vendored forge-std). All tests run against a live Fantom fork; nothing is
sent to mainnet.

| Test | Result | What it proves |
|---|---|---|
| `test_live_state` | PASS | 9 reserves, all frozen, cash/supply/debt per reserve |
| `test_oracle_is_frozen` | PASS | `fetchPrice()==lastGoodPrice()` for all 9 feeds, `status=1` |
| `test_oracle_cannot_be_refreshed_by_attacker` | PASS | permissionless `updatePrice()` cannot move any price |
| `test_fresh_attacker_cannot_withdraw` / `..._redeem_aTokens` | PASS | no free withdrawal path |
| `test_holder_can_withdraw_its_aTokens` | PASS | H-O: staking contract redeems 228.5575 aLINK → 228.5575 LINK |
| `test_wftm_market_is_unbacked` | PASS | S: aWFTM cash 0 → withdraw reverts |
| `test_realizable_cash_via_spooky` | PASS | cash → WFTM via live pools = 1,474,613 WFTM |
| `test_fresh_staker_rewards_are_dust` | PASS | staking-reward path yields dust for a new staker |
| `test_liquidate_worst_borrowers` | see CI run | liquidation P&L for the worst live borrowers (from the scan) |

CI run URLs: <!-- filled after runs -->

---

## 6. Verdict, residual/latent risk

<!-- filled after the liquidation scan -->

---

## 7. Methodology, caveats, files

* Live state read directly from a public Fantom RPC (`https://rpcapi.fantom.network`, keyless) with
  raw JSON-RPC (`analysis/read_state.py`, `analysis/scan_borrowers.py`); the CI `FANTOM_RPC_URL`
  secret was non-functional, so the scan used the public endpoint (redacted-key discipline kept:
  no keys/URLs are written anywhere in this folder).
* Prices: DefiLlama coins API (canonical vs chain-specific) + CoinGecko FTM + direct on-chain pool
  ratios on SpookySwap (factory `0x152eE697…`) and SpiritSwap (factory `0xEF45d134…`).
* Caveats: (1) local DEX prices are the only realisable market for these unbacked tokens; if a
  recovery/bridge ever re-backs them, values rise (upside risk, not claimed). (2) `liquidationCall`
  profitability depends on live borrowers (scan in progress). (3) Gas costs on Fantom are trivial
  and ignored. (4) The pool's `updateAssetPrice` path means a *live* Chainlink/Band feed would
  unfreeze prices — currently impossible.

Files: `analysis/read_state.py` (reserve/oracle state), `analysis/scan_borrowers.py` (borrower scan),
`analysis/live-state.json` (raw dump), `poc/` (Foundry), `ci-out/` (CI artifacts), `ci-log.txt`.

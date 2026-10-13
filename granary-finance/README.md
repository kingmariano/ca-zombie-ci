# Granary Finance — L2 Phase-2 deep dive (zombie-hunt II)

**Date:** 2026-10-13 · **Chains:** Optimism, Metis, Arbitrum, Fantom, Avalanche, BSC, Ethereum, Base
**Status:** read-only; PoC fork-verified only; no mainnet transactions. No secrets in this folder.

Granary Finance is a **verbatim Aave V2 fork** (commit `e558db406f4efdd0d076d72a7174c6d49ef21da3` lineage, compiler 0.6.12,
`LENDINGPOOL_REVISION = 0x2`) deployed by The Granary (Fantom, Mar 2022), later on 8 chains. The team announced
full wind-down in early 2025 (users migrated to Cod3x/CDX). No direct contract hack is documented; the corpus and
web record only third-party bridge exposure (Harmony/Multichain). The oracle is the stock Aave V2 `AaveOracle`
(Chainlink `latestAnswer()` sources, USD base currency, 8-dec answers).

## 1. TL;DR — live extractable by an external unprivileged attacker

| # | Chain | Live "supply" (aToken claims) | Pool cash (withdrawable) | Outstanding debt | E-U (permissionless extraction) | Why closed/open |
|---|-------|------------------------------|--------------------------|------------------|--------------------------------|-----------------|
| 1 | Optimism | $127,573 | **$102,816** | $24,940 | **$0** (best seizable plan: $0.01) | pool live, oracles fresh; 1,260 live debtors, 208 liquidatable; best nominal collateral $0.78 = retired sUSD (unseizable); rest is dust/bad debt |
| 2 | Metis | $76,629 | $55,945 | $20,759 | **$0** (max single plan ≈ $1.1, dust) | 83 liquidatable positions, all ≤ $23 collateral |
| 3 | Ethereum | $93,287 | **$1.39** | $110,849 | **$0** | 36 liquidatable (incl. $55.6k whale) but every collateral reserve has 0 cash → seize-to-underlying reverts; seize-to-aToken yields worthless claims (fork-proven) |
| 4 | Base | $264,524 | $0.26 | $418,978 | **$0** | pool **paused** — all user paths revert ('64') |
| 5 | Arbitrum | $14,440 | $7,508 | $6,951 | **$0** | all reserves frozen; 11 liquidatable but dust (≤$3.65) |
| 6 | Fantom | $3,537 | $2,515 | $3,661 | **$0** | all Chainlink feeds dead → every price-dependent call reverts |
| 7 | Avalanche | $3,216 | $2,811 | $423 | **$0** | 23 liquidatable, all zero-collateral bad debt |
| 8 | BSC | $3,317 | $2,693 | $854 | **$0** | 10 liquidatable, dust (≤$2.30) |
| | **Total** | **$586,524** | **$174,289** | **$587,414** | **$0.00** | |

**Total live extractable now: $0.00.** Confidence: **high** (all 8 chains enumerated; 2,750+ candidate debtors → 1,900+ live debtors
scanned; 370+ liquidatable positions; every one either dust, zero-collateral, or unseizable; oracles fresh; no borrow-extraction path).
The triage row's $180,076 was based on DefiLlama's `aToken` sums; direct reads show the real picture (see §4). The
"supply" column is nominal aToken claims, much of it inflated by runaway liquidity-index accrual and not backed by cash.

> Key insight: **Granary's residual value is ~$174k of withdrawable pool cash (H-O, suppliers) plus nominal claims
> that are largely S (stuck)**. There is no unprivileged borrow-extraction path: oracles are fresh and match market
> (≤0.3%), LTVs are normal, and every liquidatable position is either dust or unseizable.

## 2. The mechanism in exact terms (why extraction is closed)

- **Fork lineage.** `LendingPool` (impl `0x72fad09e…` on OP; `0xc01a7ad7…` on ETH/AVAX/Base) is stock Aave V2 rev 2:
  `whenNotPaused` on deposit/withdraw/borrow/repay/liquidationCall; close factor **50%** (`LIQUIDATION_CLOSE_FACTOR_PERCENT = 5000`);
  flash-loan premium 9 bps. `UserConfiguration` bitmap = stock V2 (collateral bit `2i+1`, borrow bit `2i`).
  `LendingPoolCollateralManager` (`0xF6d1CABe…`) is stock V2 and gates `receiveAToken=false` liquidations on
  `collateralAsset.balanceOf(aToken) >= maxCollateralToLiquidate` → error `'45'` when the reserve has no cash.
- **Oracle.** Stock `AaveOracle` reading Chainlink `latestAnswer()`. Cross-checked every feed against DefiLlama market
  prices: **all live-market feeds are fresh and within 0.3%** (OP/Metis/AVAX/BSC/ETH/ARB). Dead feeds exist only in
  already-closed markets (Fantom all, ARB wstETH/rETH, Base cbETH, OP BAL). The one −60% "divergence" (OP sUSD,
  oracle $0.3987) is a **retired token** (`Synth sUSD (retired)`, totalSupply 0) — nobody can acquire it.
- **No manipulable spot oracle, no mispriced LTV, no unprotected init/upgrade.** Pool/atoken proxies are owned by the
  `LendingPoolAddressesProvider`; provider owner + poolAdmin/emergencyAdmin are contracts (P-only). Granary removed
  `getUserReserveData` from its LendingPool (fork detail), but `getUserAccountData`/config bitmaps work normally.
- **Liquidation math (stock V2).** HF<0.95 → close factor 50% of the chosen debt asset; seize = repay×bonus/price;
  capped by the borrower's aToken balance; `receiveAToken=false` additionally requires the collateral reserve to hold
  enough **cash**. On chains where collateral reserves are drained (Ethereum) this makes liquidations either revert
  ('45') or deliver aTokens backed by ~nothing.
- **Index-inflation artifact.** Several reserves show aToken claims ≫ cash+debt (e.g. ETH WBTC: claims 0.681 WBTC,
  cash 0, debt 15 wei). This is the stock V2 `liquidityIndex` compounding at max utilization (dust debt pins U≈100%,
  borrow rate 307%, liquidity rate ~101% APR; WBTC index 9.9e30 → 3.69e31 since Sept 2025). It inflates *nominal*
  collateral but is not itself extractable (pump premiums are value-neutral; and no cash remains to borrow).

## 3. Live-state assessment (latest blocks, 2026-10-13)

Registry → provider → pool per chain (all verified live, `eth_getCode` non-empty):

| Chain | Registry | Provider | Pool | Oracle | Pool paused? | Block |
|---|---|---|---|---|---|---|
| Optimism | 0x872b9e8aea5d65fbf29b8b05bfa4aa3fe94cc11f | 0xdDE5dC81e40799750B92079723Da2acAF9e1C6D6 | 0x8fd4af47e4e63d1d2d45582c3286b4bd9bb95dfe | 0x9aeefef549323511e027d70562f0c7edcdeb294c | no | 158,138,066 |
| Metis | 0x37133a8dca96400c249102e59b11e25b0f663ee0 | 0xE2dfcb86C99599DAFC12028F67b8456f99c9de4c | 0x65dec665ea1e96ee5203db321b5cd413b81b2bd2 | 0xc4ae6cea0f15f5a44e0f8eea1d516af2eccb9709 | no | 23,271,882 |
| Arbitrum | 0x512f582ffccf3c14bd872152eeae60866dcb2a1e | 0x642cc899652B068D1bED786c4B060Ec1027D1563 | 0x102442a3ba1e441043154bc0b8a2e2fb5e0f94a7 | 0xe12e084fc4550387cb2b252b5f289ba38b755354 | no (all reserves frozen) | 514,357,517 |
| Fantom | 0x773e0277667f0c38d3ca2cf771b416bfd065da83 | 0x4808f2e044D3820bDBBDbdAB5eBC144179A1F6e8 | 0x65fa36fe0a7c0d346dd02b7217fdd6e6c5aaa269 | 0x59dea1331503c8fb92f5f68df2a7f97a801a4ea9 | no (feeds dead) | 123,667,741 |
| Avalanche | 0xc043ba54f34c9fb3a0b45d22e2ef1f171272bc9d | 0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC | 0xb702ce183b4e1faa574834715e5d4a6378d0eed3 | 0x5a3423210536d930150080f699248edebc65e2b4 | no | 97,425,362 |
| BSC | 0x7c8e7536c5044e1b3693eb564c6de3a3ce58bbda | 0x12c26138b666360AB2B7A1B149dF9Cf6642CDfBf | 0x7171054f8d148fe1097948923c91a6596fc29032 | 0x417ca1091fa4c329cee19452851dff46902440a5 | no | 127,359,770 |
| Ethereum | 0x5c93b799d31d3d6a7c977f75fdb88d069565a55b | 0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC | 0xb702ce183b4e1faa574834715e5d4a6378d0eed3 | 0x9546f673ef71ff666ae66d01fd6e7c6dae5a9995 | no | 26,181,961 |
| Base | 0x5c93b799d31d3d6a7c977f75fdb88d069565a55b | 0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC | 0xb702ce183b4e1faa574834715e5d4a6378d0eed3 | 0x5a3423210536d930150080f699248edebc65e2b4 | **YES** | 52,542,913 |

Per-reserve state (cash/supply/debt at oracle prices) is in `analysis/live-value.json`; raw reads in `analysis/state-*.json`;
holder/debtor scans in `analysis/borrowers-*.json`; liquidation plans in `analysis/liq-detail-*.json`.
CI re-verification at later blocks (independent keyed RPCs, `ci-artifacts/…/ci-out/`): totals **supply $583,368 / cash $171,493 /
debt $584,479** — matching the local numbers within 0.6% (Fantom's ~$3.5k is market-priced; its on-chain oracle is dead).

Notable per-chain facts:
- **Ethereum** — cash: DAI $1.39, USDC $0, USDT $0, WBTC $0, WETH $0. Debt: $110.8k (USDC 12.4k, WETH 97.5k, DAI 397, USDT 471).
  36 liquidatable accounts; largest is `0x50e4832c…` (HF 0.557, WBTC collateral $55.6k vs $85.0k debt). The pool was
  drained of all lendable cash by Sept-2025 (attacker-style automated activity: flash-loan loops, WETHGateway borrows,
  CoW Swap sells — custom unverified contracts `0x524128bfd7…`, `0x6e1a87e5…`, `0x7ba04257…`). What remains is bad debt.
- **Optimism** — the only meaningful cash pool ($102.8k), pool not paused, all feeds fresh. Full debtor scan (CI, keyed RPC):
  1,260 live debtors → **208 liquidatable**; the largest nominal collateral among them is **$0.78 of retired sUSD** (`0xab75c93b…`,
  unseizable — reserve cash 0), and the best genuinely seizable position is `0xc9eaf0d4…` ($0.14 OP collateral; realized
  profit $0.01). Everything else is zero-collateral bad debt (largest: `0xa98e339f…`, 2,999 SNX ≈ $737 debt). No extractable position exists. Cash is withdrawable by suppliers (H-O).
- **Metis** — 83 liquidatable, all ≤ $23 collateral (largest: `0x2f374d4c…` HF 0.021, $22.92 collateral vs $930.61 debt;
  profit-if-seizable ≈ $1.1). Cash $55.9k withdrawable by suppliers.
- **Base** — paused since before audit; every user path (deposit/withdraw/borrow/repay/liquidate) reverts `'64'`.
  $264.5k of nominal claims sit behind the pause; $0.26 cash. Only poolAdmin/emergencyAdmin (P) can unpause.
- **Fantom** — all six Chainlink feeds revert (`latestRoundData` dead) → `getAssetPrice` reverts → withdraw/liquidate/
  borrow all revert. $2.5k cash is unreachable (S) absent admin oracle fix (P).
- **Arbitrum** — every reserve frozen (deposits/borrows blocked), pool not paused. 11 liquidatable, all dust (≤$3.65);
  wstETH/rETH feeds dead (their positions can't even be valued). $7.5k cash withdrawable (H-O).

## 4. What an attacker can / cannot do (exact paths)

**Closed paths (all verified by live reads; ETH paths fork-proven in PoC):**
1. **Liquidate the ETH whale to underlying** → reverts `'45'` (`LPCM_NOT_ENOUGH_LIQUIDITY_TO_LIQUIDATE`): `WBTC.balanceOf(aWBTC) = 0`
   while seize would be 0.0317 WBTC for 1 WETH. Same for every ETH collateral reserve (cash ≈ 0).
2. **Liquidate the ETH whale with `receiveAToken=true`** → succeeds but yields aWBTC whose backing `(cash+debt)/totalSupply ≈ 15 wei/0.681 WBTC ≈ 0`;
   redeeming reverts; borrowing USDC against it reverts (USDC cash 0). Net profit ≈ −gas. [PoC]
3. **Borrow against inflated collateral** (ETH WBTC index artifact): no cash left in any borrowable reserve → borrow reverts.
4. **Oracle manipulation** — Chainlink sources, fresh, matching market; no spot/LP oracle anywhere. The dead feeds are in
   closed markets. OP sUSD feed reads a retired token (totalSupply 0 — cannot deposit/repay with it).
5. **Base/Fantom user paths** — paused / dead-oracle; admin-gated only.
6. **Admin/init/upgrade** — pool admin, emergency admin, oracle owner, provider owner are contracts (multisig/timelock);
   `initReserve`/`setPause`/`setConfiguration` are `onlyLendingPoolConfigurator`; oracle `setAssetSources` is `onlyOwner`. P-only.
7. **Flash-loan index pumping** — value-neutral (premium paid = claim gained; borrowing against self-funded collateral
   loses ≥ LTV−1); no free cash.

**Open paths (residual, non-attacker):**
- **H-O**: suppliers can withdraw their pro-rata share of pool cash on OP/Metis/ARB/AVAX/BSC (~$171.5k total, CI block).
- **S**: ETH claims ($93.4k) sit against ~$0 cash (bad debt of $110.9k held by underwater accounts); Base ($264.5k claims)
  and Fantom ($3.5k) are hard-blocked until admin action (P).

## 5. PoC / fork verification

Foundry project `poc/` (forge-std vendored). Tests fork mainnet in CI (`FORK_RPC_URL` / per-chain RPC env):

| Test | Chain | Proves | Result |
|---|---|---|---|
| `test_eth_pool_live_and_whale_liquidatable` | Ethereum | pool live, whale HF<1 | PASS |
| `test_eth_liquidation_to_underlying_reverts_no_cash` | Ethereum | revert `'45'`, no cash | PASS |
| `test_eth_liquidation_to_atoken_is_worthless` | Ethereum | aWBTC backing≈0, redeem/borrow revert | PASS |
| `test_eth_all_reserve_cash_is_dust` | Ethereum | all ETH cash ≈ 0 | PASS |
| `test_base_pool_paused_blocks_everything` | Base | paused, deposit reverts `'64'` | PASS |
| `test_fantom_oracle_dead_blocks_all_price_dependent_ops` | Fantom | getAssetPrice reverts | PASS |
| `test_op_susd_is_retired_token_nobody_can_acquire` | Optimism | sUSD supply 0, feed live | PASS |
| `test_op_pool_live_oracles_fresh` | Optimism | pool live, prices > 0 | PASS |
| `test_op_liquidatable_positions_are_all_dust` | Optimism | zero-collateral bad debt; best nominal = retired sUSD ($0.78, supply 0); best seizable ≤ $0.15 | PASS |
| `test_op_retired_susd_collateral_cannot_be_seized` | Optimism | liquidation of retired-sUSD collateral reverts `'45'` | PASS |
| `test_op_best_liquidation_profit_is_one_cent` | Optimism | executed liquidation; profit < $0.10 | PASS |

CI runs: [CI-URLS]

## 6. Verdict

**External unprivileged extraction from Granary Finance today: $0.00 (high confidence).** Every candidate vector is closed:
oracles are fresh Chainlink feeds matching market; liquidatable positions are dust (OP best $0.01, Metis best ~$1.1) or
unseizable (Ethereum: $3.55k of nominal liquidation bonus blocked because every collateral reserve holds $0 cash — fork-proven);
Base is paused; Fantom's oracle is dead. The protocol's residual value is **$171.5k of supplier-withdrawable cash (H-O)**
on OP/Metis/Arbitrum/Avalanche/BSC and **~$415.4k of stuck claims (S)** on Ethereum/Base/Fantom and the receivable gap on
live chains. Latent risks (not currently extractable): (a) if an admin unpauses Base, the ETH-style dynamic could recur there
($264.5k claims vs $0.26 cash — still no cash to seize); (b) if the OP cbETH feed stays dead while cbETH moves, that $10 reserve
could be gamed; (c) OP SNX/BAL dead-feed positions can't be liquidated (revert), trapping those claims.

## 7. Methodology & sources

- Enumerated registries/providers/pools from the triage row; validated every reserve→aToken mapping via
  `UNDERLYING_ASSET_ADDRESS()` (40/40 OK); verified pool/oracle/configurator source from Etherscan V2 (chainid 1/10/56/42161/43114/8453).
- Debtor enumeration: GoldRush `token_holders` (v2 + v1 fallback) for current holders of each variable-debt token,
  unioned, then `balanceOf` + `getUserAccountData` on-chain. Metis via Blockscout `getTokenHolders`.
  Live debtors after on-chain filtering: OP **1,260** (CI keyed RPC; local public-RPC run found 477 — CI is authoritative),
  ETH 63, Metis 317, ARB 11, AVAX 109, BSC 53.
- Price cross-check: DefiLlama `coins.llama.fi` vs on-chain oracle for all 40 reserves.
- Web: Granary docs/retrospective, DefiLlama protocol page, Certik due-diligence summary, API3 OEV liquidator repo,
  avoid.net investigation. No incident report of a direct Granary contract hack was found.

## 8. Caveats & limitations

- Public keyless RPCs used locally; blocks cited per chain. Metis/AVAX holders lists may miss dust debtors (indexer limits).
- The ETH whale's history (Sept-2025 drain) was partially reconstructed; the exact operator intent is not provable from
  public data. It does not change current extractability.
- USD values at on-chain oracle prices (== market within 0.3%) on 2026-10-13.
- `getUserReserveData` is absent from Granary's LendingPool (fork removal); per-user data was reconstructed from
  `getUserConfiguration` + token `balanceOf`.

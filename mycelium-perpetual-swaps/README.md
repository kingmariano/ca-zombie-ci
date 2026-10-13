# Mycelium Perpetual Swaps (Arbitrum) — live extractability deep-dive

**Date:** 2026-10-13 · **Chain:** Arbitrum One (42161) · **Status:** read-only; PoC fork-verified only; no mainnet transactions
**Source row:** `l2-triage-a` → `mycelium-perpetual-swaps` (LIVE-FUNDED, triage $134,810, high confidence)
**Snapshot block:** 514,494,093 – 514,523,261 (recorded per call below)

---

## 1. TL;DR

| Target | Live value (unprivileged view) | Why closed / open | Latent risk |
|---|---|---|---|
| Vault `0xDfbA8AD5…` — MLP pool | **~$115.3k** | **S (stuck)**: MLP redemption is handler-gated *and* bricked (`MlpManager.getAum()` reverts on dead MIM/BAL/FXS price feeds) | Governance could fix feeds → becomes H-O for MLP holders |
| Vault — fee reserves | ~$2.27k | **P**: `withdrawFees` only via Timelock→gov | — |
| Vault — 15 live positions | $293.33 collateral | **H-O**: position owners can `decreasePosition` (msg.sender == account) | — |
| `feeMlpTracker` WETH pot | 19.4175 WETH = **$48.7k** | **H-O**: claimable by MLP stakers (≥282.3 WETH distributed lifetime, ≥262.9 claimed) | First-come-first-served; stakers only |
| `sMYC` tracker (2023) WETH pot | 6.6624 WETH = **$16.7k** | **H-O**: claimable by sMYC stakers (≥15.9 WETH distributed lifetime); a fresh staker captures **0** past rewards | Nominal claims may exceed pot (race) |
| `RewardDistributor 0xdb8cc5be` | 7.4679 WETH = **$18.7k** | **S**: deployed-but-uninitialised, `gov()==0`, no reachable function moves the WETH | — |
| OrderBook pending orders | ~$698 (0.00134 WBTC, 500 USDC, 29.6 USDT, 0.0227 WETH) | **H-O** (owner `cancel*`); **all `execute*` revert** — execution fees uncollectible | — |
| PositionRouter(1/2) pending | ~$94 | **H-O** (owner cancel); execution `onlyPositionKeeper` | — |
| Vesters / StakingRewards / MerkleTokenSale | ~$1.3k + illiquid MYC | **H-O / P / S** (vesting claims, owner recover, merkle) | — |
| **Any permissionless extraction** | **$0.00** | all swap outputs buffer-locked or dust; liquidations private; leverage off; MLP bricked; trackers no-capture | — |

## 2. Total live extractable now: **$0.00** (E-U), confidence **high**

The single residual permissionless path — the vault's `swap()` — can only output tokens whose
pool exceeds their configured buffer. Every material asset is buffer-locked; the only unblocked
pools are dust (UNI 0.0000101, FRAX 0.000325, CRV 0.000847). Even the strict-stable mispricing
(FRAX valued $1.00 by the vault vs $0.9905 market) monetises to **<$0.000001** because there is
no meaningful unblocked output. Fork proof: `test_16_frax_mispricing_not_extractable`.

The triage headline ($134,810) **undercounts** live value: it missed the `feeMlpTracker` WETH pot
($48.7k) and the stuck `RewardDistributor` ($18.7k). Full live value ≈ **$203k**, of which
≈$67.8k is H-O (holders), ≈$134k is S (stuck), ≈$2.3k is P.

---

## 3. The protocol and the bug/mechanism in exact terms

Mycelium Perpetual Swaps is a **GMX v1 fork** deployed on Arbitrum (deployer
`0xcc97eb5651e05d5a0ae8bcd2813b9dfdad6f92a5`, block ~20,209,000, Aug-2022; a 2023 batch added a
second RewardTracker generation). Verified sources (Arbiscan):

| Contract | Address | Notes |
|---|---|---|
| Vault | `0xDfbA8AD57d2c62F61F0a60B2C508bCdeb182f855` | solc 0.6.12, holds WBTC/WETH/USDC/LINK/… |
| Router | `0x3cd2F02B9e39ccC781d0C07fc0286F654e53A76D` | GMX v1 Router |
| VaultPriceFeed | `0xDffe2f49234001380119d89E9C965BEd4bf123f0` | Chainlink primary + FastPriceFeed secondary |
| FastPriceFeed | `0x2cA1DF570CcA0421cd4fd4798417a2B36C73e845` | **stale since 1696291869 (Oct-2023)**, priceDuration 300 s → falls back to Chainlink |
| VaultUtils | `0x875B5f3908E37367533b7D6c92535F9AB579B072` | fees/spreads |
| Timelock (Vault gov) | `0x25D390B53b06Ae32DAB3BDcB1C0D4fa44D2907D7` | admin = Safe `0x3E2d8447…` (threshold 2) |
| MlpManager | `0x2DE28AB4827112Cd3F89E5353Ca5A8D80dB7018f` | MLP mint/burn; `inPrivateMode=true` |
| MLP token | `0x752b746426b6D0c3188bb530660374f92FD9cf7c` | supply 38,874.21; 99.95% held by feeMlpTracker |
| USDG | `0xe61a61B9Ce1Bd12e17a53AeeeE1005Ef6C1b2E80` | 2.347M supply, 100% held by MlpManager |
| RewardRouterV2 | `0xd98d8e458F7aD22DD3C1d7A8B35C74005eb52b0b` | the only MlpManager handler |
| sMYC tracker (2023) | `0xF9B003Ee160dA9677115Ad3c5bd6BB6dADcB2F93` | RewardTracker proxy; 6.66 WETH + 23.43M MYC |
| feeMlpTracker / stakedMlpTracker | `0xF0BFB95087E611897096982c33B6934C8aBfA083` / `0xF7Bd2ed13BEf9C27a2188f541Dc5ED85C5325306` | 19.42 WETH / 232,253 esMYC |
| OrderBook | `0x2eeef7852a306a580acf94f7c18c3ff124a59d4f` | **permissionless `execute*`** |
| PositionManager | `0x3892b8cf646b17709c91e653319ba5504a5feafe` | the Vault's only liquidator |
| PositionRouter (×2) | `0xbB214233C570b8e9b732212974E7baeFFE63F0de` / `0xe510571cac76279dadf6c4b6eace5370f86e3dc2` | keeper-gated execution |
| MerkleTokenSale | `0xbc61d76cbd784bb3ede8c855f37deb465c5b43a9` | 196.57M MYC (2024) |
| RewardDistributor (stuck) | `0xdb8cc5be809ebe47d2a96da599647162c51e4` | uninitialised, holds 7.4679 WETH |

### 3.1 Why the vault cannot be drained permissionlessly

* `swap(tokenIn, tokenOut, receiver)` is **permissionless** (only `isSwapEnabled` + whitelist). But
  `_validateBufferAmount(_tokenOut)` reverts when `poolAmounts[out] < bufferAmounts[out]`, and every
  material asset is configured with `buffer > pool` (WBTC 33 > 1.2168; WETH 740 > 1.6012; USDC
  1.378M > 1.437k; LINK 13,778 > 676.9; USDT 414,309 > 0.30; DAI 642,700 > 0.675). The only
  unblocked pools are dust (UNI 1.0078e13 = 0.0000101 UNI; FRAX 0.000325; CRV 0.000847; BAL/FXS
  feeds dead). `_decreasePoolAmount` additionally enforces `reserved ≤ pool`.
* Prices come from **live Chainlink** aggregators (all 12 feeds read at the snapshot; WBTC
  $83,134.41 vs market $83,072.83; WETH $2,503.90 vs $2,506.51; LINK/UNI/CRV within 0.25%). The
  FastPriceFeed has been stale since Oct-2023, so the oracle is Chainlink-only — not manipulable.
* **FRAX strict-stable quirk**: `strictStableTokens[FRAX]=true`, `maxStrictPriceDeviation=5%`, so
  the vault prices FRAX at exactly $1.00 while the market is $0.9905 (0.95% edge). Not monetisable
  — the only unblocked output pools are dust (proved in `test_16`; max extractable $0.0000006).
* `liquidatePosition` is gated by `inPrivateLiquidationMode=true` + `isLiquidator[msg.sender]`;
  only the PositionManager is a liquidator, and its own liquidator set is 2 EOAs
  (`0x87b674f4…`, `0x4a9cf80d…`, both still active). No liquidations ever occurred (0 events).
* `increasePosition` requires `isLeverageEnabled`, which is `false`; the toggles on the Timelock are
  `onlyAdminOrHandler` (PositionRouter only).
* `decreasePosition` is `_validateRouter(_account)`: caller must be the account, the Router, or an
  account-approved plugin → position owners only (H-O).

### 3.2 Why MLP redemption is bricked (S)

`MlpManager` (verified source): `inPrivateMode=true` blocks the direct `addLiquidity/removeLiquidity`;
`addLiquidityForAccount/removeLiquidityForAccount` require `isHandler[msg.sender]` (only the
RewardRouter). But `_removeLiquidity` first calls `getAumInUsdg(false)` → `getAum(false)`, which
iterates **all** whitelisted tokens and calls `vault.getMinPrice(token)` — including MIM, BAL and
FXS, whose Chainlink aggregators are dead and revert. Result: `getAum` reverts with **empty data**
(no `require` string), so both mint and burn revert even through the legitimate handler.
Proof: `test_11_mlp_redemption_bricked_getAum_reverts` (direct `getAum` revert + handler-path revert).

Consequence: the MLP-backed pool (~$115.3k) is unreachable without governance action (P). The
USDG supply (2.347M) is entirely inside the MlpManager and cannot be redeemed either.

### 3.3 OrderBook: permissionless execution, zero collectible

`executeSwapOrder` / `executeIncreaseOrder` / `executeDecreaseOrder` are `external nonReentrant`
with **no access control**, and pay `order.executionFee` to the caller-chosen `_feeReceiver`.
10 orders are pending (1 swap, 6 increase, 5 decrease; total fees 0.0127 ETH). Every one reverts:

* swap order (0.00134518 WBTC→WETH): `Vault: reserve exceeds pool` (WETH pool − amountOut < 1.597 WETH reserve);
* increase orders: `Vault: reserve exceeds pool` / dead BAL feed / OrderBook not approved as Router plugin;
* decrease orders: `Router: invalid plugin` (accounts never approved the OrderBook) and/or no live position.

Order owners can still `cancel*` and recover their funds (H-O, ~$698 incl. fees).

### 3.4 Reward trackers: no fresh-attacker capture

`stake()` is open (`inPrivateStakingMode=false`, depositCap not hit) and `claim()` is open
(`inPrivateClaimingMode=false`) — but `_stake` calls `_updateRewards(account)` **before** increasing
`stakedAmounts`, so a new staker's `previousCumulatedRewardPerToken` = current cumulative → past
rewards are not capturable. Fork-proved: a fresh account claims 0 (`test_12`), and
stake-100k-MYC-then-claim returns 0 (`test_13`). `claimForAccount` / `stakeForAccount` /
`unstakeForAccount` are `_validateHandler`-gated; the handlers are the RewardRouter/vesters, whose
own entry points always use `msg.sender` (no victim-account parameter). The RewardRouter's
`signalTransfer/acceptTransfer` handover requires the *sender* to signal the receiver first.

### 3.5 The stuck distributor (S)

`0xdb8cc5be809ebe47d2a96da599647162c51e4` (RewardDistributor) holds **7.4679 WETH** but is
`isInitialized=true` with `gov()==0`, `rewardTracker()==0`, `tokensPerInterval==0`,
`pendingRewards()==0`. `distribute()` reverts (no tracker), and every `onlyGov` function is
unreachable (gov is the zero address). The WETH is stuck.

---

## 4. Live-state assessment (addresses, code checks, balances, roles, block numbers)

All reads against public Arbitrum RPC at blocks 514,494,093 / 514,500,782 / 514,523,261
(`analysis/family-balances.json`, `analysis/trackers-state.json`, `analysis/live-positions-full.json`).

**Vault flags** (block 514,494,093): `isSwapEnabled=true`, `isLeverageEnabled=false`,
`includeAmmPrice=true`, `inManagerMode=true`, `inPrivateLiquidationMode=true`,
`isInitialized=true`, `liquidationFeeUsd=5e30 ($5)`, `maxGasPrice=0`, 12 whitelisted tokens,
`hasDynamicFees=true`, `gov=0x25D390B5…`.

**Vault balances** (block 514,500,782; USD at 2026-10-13 market prices):
WBTC 1.23417190 ($102,556) · WETH 1.722166590661866233 ($4,317) · USDC.e 2,997.947146 ($2,998) ·
LINK 681.522524556557239877 ($8,789) · USDT 18.270969 · DAI 133.83462840991191018 · FRAX 0.000325 ·
UNI 0.000122104 · CRV 0.000847 · BAL 0.000473 · FXS 0.002817 · MIM 0 → **≈ $118,810**.
Pool (MLP NAV basis) ≈ $115,274; feeReserves ≈ $2,272; live positions collateral $293.33.

**Staking pots**: feeMlpTracker 19.417548813040933241 WETH ($48,676) + 38,855.766 MLP;
sMYC tracker 6.662358833018414643 WETH ($16,701) + 23,430,368.25 MYC + 71,302.50 esMYC;
stakedMlpTracker 232,253.77 esMYC; distributors of both trackers hold **0 WETH** (no further streaming).

**Roles**: Vault gov → Timelock `0x25D390B5…` (admin = Safe `0x3E2d8447…`, threshold 2, buffer 3600 s);
Timelock handlers: PositionRouter only; `isManager` = MlpManager only; `isLiquidator` =
PositionManager only; MlpManager `isHandler` = RewardRouter only; VaultPriceFeed gov =
`0x3E2d8447…` (Safe); PositionManager admin = Timelock; PositionRouter admin = Safe.

**Positions** (block ~514,520,000; 1,526 unique candidates from ~5,000 `IncreasePosition` events):
15 live, total collateral **$293.33**, total size $1,396.82 (largest: USDC/UNI short, $141.66).

**Token liquidity caveat**: MYC (23.4M in the tracker + 196.6M in the MerkleTokenSale) has only
~$70k–1k pools on Arbitrum with ~zero 24 h volume → not realisable.

---

## 5. What an attacker can/cannot do — exact call paths

| # | Call | Preconditions | Result |
|---|---|---|---|
| 1 | `Vault.swap(X, WBTC/USDC/LINK/USDT/DAI/WETH, …)` | transfer X to vault first | **revert** `Vault: poolAmount < buffer` |
| 2 | `Vault.swap(FRAX, UNI, …)` (FRAX mispriced +0.95%) | 76,293 FRAX in | succeeds, returns 0.0000101 UNI = **$0.00008** |
| 3 | `OrderBook.executeSwapOrder(0x3d38f210…, 1, attacker)` | none | **revert** `Vault: reserve exceeds pool` |
| 4 | `OrderBook.executeIncreaseOrder(0xd1dE8093…, 10, attacker)` | none | **revert** `Vault: reserve exceeds pool` |
| 5 | `OrderBook.executeDecreaseOrder(0xacFF176F…, 0, attacker)` | none | **revert** `Router: invalid plugin` |
| 6 | `Vault.liquidatePosition(any, …)` | `isLiquidator[attacker]` | **revert** `Vault: invalid liquidator` |
| 7 | `Vault.decreasePosition(victim, …)` | msg.sender ∈ {victim, Router, approved} | **revert** `Vault: invalid msg.sender` |
| 8 | `Vault.increasePosition(attacker, …)` | `isLeverageEnabled` | **revert** `Vault: leverage not enabled` |
| 9 | `MlpManager.removeLiquidity(…)` | `inPrivateMode=false` | **revert** `MlpManager: action not enabled` |
| 10 | `MlpManager.removeLiquidityForAccount(victim, …)` | `isHandler[attacker]` | **revert** `MlpManager: forbidden` |
| 11 | `MlpManager.removeLiquidityForAccount(staker, …)` via RewardRouter | handler ✓ | **revert** empty (`getAum` → dead feed) |
| 12 | `sMYC.claim(attacker)` | stakedAmounts>0 | returns **0** |
| 13 | `sMYC.stake(MYC, 100k)` then `claim()` | MYC funded | returns **0** (no past capture) |
| 14 | `sMYC.claimForAccount(victim, attacker)` | `isHandler[attacker]` | **revert** `RewardTracker: forbidden` |
| 15 | `Timelock.enableLeverage(vault)` / `setIsLeverageEnabled` | `onlyAdminOrHandler` | **revert** unless PositionRouter/keeper |
| 16 | `Vault.directPoolDeposit(token)` | — | succeeds — **donation** (no mint, no payout) |
| 17 | `Vault.updateCumulativeFundingRate(a,b)` | — | succeeds — state update only, no payout |
| 18 | H-O: `sMYC.claim(sMYC_staker)` / `feeMlpTracker.claim(mlp_staker)` | real staker | pays 0.008367 / 0.000166 WETH (fork-proved) |

---

## 6. PoC / fork-verification

* Project: `poc/` (Foundry, solc 0.8.24, `lib/forge-std` vendored), tests `poc/test/Mycelium.t.sol`.
* Fork: `vm.createSelectFork(vm.envOr("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc"))` — Arbitrum latest.
* **Local: 17/17 PASS** (`forge test -vv`); CI run: see §8.
* Key fork numbers: sMYC staker claim 8,367,309,953,026,861 wei WETH (H-O); MLP staker claim
  166,518,273,757,038 wei WETH (H-O); FRAX→UNI max extraction 614,234,948,431 wei USD ($6.1e-7).
* CI job also dumps live state to `ci-out/live-state.json` (`ci/dump-state.py`).

## 7. Verdict and residual/latent risk

* **E-U = $0.00 (high confidence).** No permissionless path pays an external attacker anything.
* **H-O ≈ $67.8k**: MLP-staker WETH claims ($48.7k), sMYC-staker WETH claims ($16.7k),
  position owners ($293), pending-order owners (~$790), vesting claims (~$1.2k), StakingRewards (~$77).
* **P ≈ $2.3k + all vault tokens**: the Timelock (admin = 2-of-N Safe) can `withdrawFees`, and
  `upgradeVault` can move every vault token; `setTokenConfig`/`setPriceFeed` could fix the dead
  feeds (turning the stuck pool into H-O for MLP holders).
* **S ≈ $134.0k**: MLP pool $115.3k (bricked getAum) + stuck RewardDistributor $18.7k.
* Latent risks worth monitoring: (a) if governance repairs the MIM/BAL/FXS feeds or re-enables
  `inPrivateMode`, the whole pool becomes redeemable by MLP holders; (b) the sMYC tracker's pot
  may be under-collateralised vs nominal claims (first-come-first-served); (c) the
  `RewardDistributor` WETH is recoverable only if the Safe deploys new code (it cannot, gov=0).
* Blockers found: `inPrivateLiquidationMode`, `isLeverageEnabled=false`, `inPrivateMode`,
  buffer-locked outputs, dead MIM/BAL/FXS feeds (they brick getAum but also make those tokens
  unswappable), zero-liquidity MYC.

## 8. Methodology & sources; caveats; files

**Method**: full contract-family enumeration from the deployer's creation list
(`0xcc97eb56…`, 643 txs); verified-source review (Vault, MlpManager, VaultPriceFeed, FastPriceFeed,
RewardTracker, RewardRouterV2, OrderBook, PositionManager, PositionRouter, Timelock, MycTimelock,
TokenManager, RewardManager, Vesters, MintableBaseToken, MerkleTokenSale); live state at explicit
blocks; Chainlink feed freshness vs DefiLlama/CoinGecko market prices; log-diff for pending orders
and positions; read-only `eth_call` simulations of every candidate path; Foundry fork PoC on CI.

**Caveats**: (1) USD values use 2026-10-13 market prices (FRAX $0.9909, UNI $7.5771, WETH $2,506.51,
WBTC $83,072.83); (2) the MLP NAV cannot be read on-chain (getAum reverts) so the pool value is
computed from poolAmounts × market prices; (3) tracker claimables are sampled (200 stakers each),
not enumerated; (4) MYC is treated as ~$0 due to absent liquidity; (5) all tests are fork-only —
no mainnet state was modified.

**Files**: `analysis/` (sources, state dumps, scripts, logs), `poc/` (Foundry project),
`ci/` (state-dump job), `ci-out/`, `ci-log.txt`, `summary.json`.

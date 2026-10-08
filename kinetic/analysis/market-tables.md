# Kinetic (Flare) — market state & oracle evidence (C2-12)

All values read-only. **Block 71,637,545** for the C1/C2 USD table (thirdweb/public RPC, oracle prices at the
same block); **block 71,640,541** for the independent snapshot in `../ci-out/live-state-snapshot.txt`
(re-run at 71,639,731 by childA — zero diffs). No transactions were signed or sent.

## 1. Comptrollers (4 found; the finding named 2)

| # | Unitroller | Kind | Markets | Oracle | Admin (proxy admin / unitroller admin) |
|---|---|---|---|---|---|
| C1 | `0x15F69897E6aEBE0463401345543C26d1Fd994abB` | ISO FXRP pool (ComptrollerV2 impl `0x35aFf5…8866`) | 3 | `0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b` | `0x37C6C7c719DB93085678cE72981CDd96219C9B72` |
| C2 | `0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8` | main pool (ComptrollerV2 impl `0x2E7C09…734a`) | 7 | `0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c` | `0x81274d9250C8a36c62d3F45F18BD34D44D433b45` |
| C3 | `0xDcce91d46Ecb209645A26B5885500127819BeAdd` | ISO JOULE pool (impl `0x7c772A…cf9F`) | 3 | `0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D` | `0x37C6C7c719DB93085678cE72981CDd96219C9B72` |
| C4 | `0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f` | legacy/"t" pool (impl `0xA43B4b…410C`, unverified-named `Comptroller`) | 6 | `0x4d309754eB1ae09e94bfC2b5cb3178a317E76273` (unverified) | `0x1e7D53bacF8Be70A8dB3f5CD968048d6C76b770D` |

C1/C2 markets are **CErc20Delegator proxies** all delegating to impl `0xF114620FFf7cAe11Be8A352E6DEe25386547A333`
(CErc20Delegate, verified, source matches Compound v2.8 + Kinetic patches); the C2 native FLR market is
`CNativeDelegator 0xb84F77…9407` → impl `0x31e7fa682312807D27d94C91563F284Bf6281F02`. All delegator admins:
`0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7`.

## 2. Market table — C1 + C2 (the live, unpaused venues), block 71,637,545

USD = underlying base units × oracle price / 1e36 (Compound price scaling). CF = `markets(address)` word 2.

| Pool | Market | Underlying | Cash USD | Borrows USD | Reserves USD | CF | mintPaused | borrowPaused | borrowCap |
|---|---|---|---|---|---|---|---|---|---|
| C1 | isoFXRP | FXRP `0xAd55…C5bE` | **$25,135,329.71** | $1,926,817.17 | $761.93 | 70% | false | false | 3,000,000 |
| C1 | isoUSDT0 | USD₮0 `0xe7cd…fC82D` | $481,411.60 | $4,922,337.73 | $5,880.37 | 80% | false | false | 5,000,000 |
| C1 | isoSTXRP | stXRP `0x4C18…1B2b3` | $35,263.19 | $0 | $0 | 0% | **true** | **true** | 1 |
| C2 | kSFLR | sFLR `0x12e6…1c2BB` | $4,861,385.43 | $219,765.91 | $19.04 | 70.82% | false | false | 200,000,000 |
| C2 | kFLRETH | flrETH `0x26A1…B16A5` | $2,290,247.17 | $8,855.59 | $1.24 | 62.5% | false | false | 953 |
| C2 | kFLR | FLR (native) | $1,192,195.08 | $373,065.12 | $147.63 | 70.27% | false | false | 70,000,000 |
| C2 | kUSDT0 | USD₮0 | $523,517.31 | $2,140,636.56 | $2,922.57 | 80% | false | false | 2,400,000 |
| C2 | kWETH | WETH `0x1502…75d3D` | $487,713.02 | $1,400,635.30 | $912.57 | 62.5% | false | false | 2,142 |
| C2 | kUSDC.E | USDC.e `0xFbDa…7d3b6` | $147,818.37 | $639,107.96 | $620.26 | 80% | false | false | 2,750,000 |
| C2 | kUSDT | USDT `0x0B38…35396` | $2,564.47 | $3,675.73 | $2.68 | 80% | false | false | **1 (frozen)** |
| | **TOTAL C1+C2** | | **$35,157,445.34** | $11,634,897.07 | $11,268.29 | | | | |

C3 (all 3 markets **mint+borrow paused**): isoUSDC cash ≈ $2,354.62; isoFLR cash ≈ $28,939.26;
isoJOULE cash ≈ $10.94 (price is an owner override — see §4). C4 (all but one market paused): tflrETH cash
99 units ≈ $243,150 at C4's (unverified) oracle; every other C4 market cash = 0. C4's `tFLR`/`tsFLR`/… cash=0,
fully lent.

Smallest `totalSupply` across all 19 markets: **24,354,210,705 raw** (C4 tUSDC.e, 243.5 cTokens) — ten orders
of magnitude above the Sonne precondition (2 wei). No market has `totalSupply == 0` with cash > 0 anywhere.

## 3. Exchange-rate legs (oracle `exchangeAsset`)

`tokenConfigs(underlying)` on C1/C2/C3 returns `(asset, bytes21 feedId, uint64 maxStalePeriod, address exchangeAsset)`:

| Asset | feedId | maxStale | exchangeAsset | rate now |
|---|---|---|---|---|
| USDT0 | `0x01USDT/USD…` | 420s | `0x0` | — |
| FXRP | `0x01XRP/USD…` | 420s | `0x0` | — |
| stXRP | `0x01XRP/USD…` | 420s | `0x0` | — |
| USDC.e | `0x01USDC/USD…` | 420s | `0x0` | — |
| USDT | `0x01USDT/USD…` | 420s | `0x0` | — |
| WETH | `0x01ETH/USD…` | 420s | `0x0` | — |
| **sFLR** | `0x01FLR/USD…` | 420s | **`0x7E0182…65Cc`** (sNative wrapper) | `getExchangeRate()` = 1.889606…e18 |
| **flrETH** | `0x01ETH/USD…` | 420s | **`0x134719…2D94`** (sETH wrapper) | `getExchangeRate()` = 1.070476…e18 |

- `sNative.getExchangeRate()` = `StakedFlr.getPooledFlrByShares(1e18)` = `totalPooledFlr × 1e18 / totalShares`
  (2.139719e27 / 1.132362e27 = 1.889606e18). **`totalPooledFlr` is a storage variable, only mutated by
  role-gated `accrueRewardsExt` and by user `submit`/`redeem` at fair pro-rata value; a plain FLR transfer
  hits `receive()` which auto-`submit()`s (mints shares) — it does not move the rate** (fork test
  `test_9`).
- `sETH.getExchangeRate()` = `WrappedLiquidStakedToken.LSTPerToken()` = `lst.convertToAssets(1e18, true)`
  (Redacted `WrappedLiquidStakedToken`, impl `0x0bd0465c…ca32`) — also share-accounting based.
- Oracle price recomposition is exact (fork test `test_8`): sFLR price = FLR/USD × 1.889606 = 12,749,645,570,252,760;
  flrETH price = ETH/USD × 1.070476 = 2,623,602,547,573,510,249,735.

## 4. FTSO path & overrides

- C1 oracle uses Flare registry `FtsoV2` `0x7BDE3Df0624114eDB3A67dFe6753e62f4e7c1d20` (170-byte registry proxy);
  C2/C3 use `0xB18d3A5e5A85C65cE47f977D7F486B79F99D3d32`. Both return identical feed values (verified).
- Feeds are **live per block** (FLR/USD ts 1,791,487,346 vs block ts 1,791,487,4xx at snapshot; measured
  age 0–3 s), 100-provider FTSO v2 median — not flash-manipulable.
- Staleness is **fail-closed**: `getFTSOPrice` reverts `"stale price"` when `block.timestamp − feedTs > maxStalePeriod`
  (420 s). Fork test `test_4b` warps +421 s and confirms the revert.
- **Owner price overrides (`assetPrices`) are 0 for every C1/C2 underlying** (no pushed prices).
  Exception found by the independent verifier: **C3's isoJOULE has a live owner override
  `assetPrices(JOULE) = 1e13`** ($0.00001; no JOULE/USD feed exists). C3 markets are mint+borrow paused →
  P-category only, no E-U.
- Oracle owner: C1/C3 `0x37C6C7c7…` (same as unitroller admin), C2 `0x58B1b315…` (oracle-setter timelock per
  docs). `setPrice`/`setUnderlyingPrice`/`setTokenConfig`/`setFTSOV2` are all `onlyOwner`.

## 5. Gates that close the known drain classes

| Class | Gate observed (live) |
|---|---|
| Sonne/Compound empty-market donation + `redeemUnderlying` truncation | no market is empty or microscopic (min supply 2.44e10 raw vs attack precondition ~2 wei); per-call truncation gain ≤ one raw share ≈ **< $1e-11** (fork test `test_3`); end-to-end Sonne sequence on kSFLR nets **−$134.75** (fork test `test_2`) |
| Over-borrow against manipulated collateral | FTSO v2 + storage-based LST rates; no spot DEX leg; `assetPrices` overrides 0 on C1/C2 |
| Oracle staleness/lag | `maxStalePeriod = 420 s` enforced; feeds update per block; stale ⇒ revert (fail-closed) |
| Permissionless liquidations | `liquidateBorrowAllowed` → `AllowList.allowed(liquidator)`; random addresses `false`; returns `UNAUTHORIZED(1)` on C1/C2/C3 (fork test `test_5`); C4 has no whitelist but only dust/illiquid positions |
| cToken `approve` abuse | `CErc20Delegate.approve` requires `approvalAllowList.allowed(spender)` for non-zero amounts (`SNA` revert; fork test `test_6`) |
| `redeemTokens == 0` free redemption | `Comptroller.redeemVerify` **reverts `"RV"`** when `redeemTokens == 0 && redeemAmount > 0` (hardened vs vanilla Compound) |
| Direct donations (cToken / LST) | pro-rata to all shareholders; attacker gain ≤ (share fraction × donation) − donation < 0; LST rates are storage-accounted |
| New market listing race (Sonne's true root cause) | `_supportMarket` / `_setCollateralFactor` are admin-only (not permissionless timelock calls); latent only |

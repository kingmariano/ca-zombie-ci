# Oracle evidence — YeiLend (Sei), block 236,462,331 (2026-10-08)

## Architecture (verified from deployed sources)

- `AaveOracle` `0xA1ce28cEbaB91d8dF346D19970E4Ee69A6989734` (pool1) and `0xBDecf329328CD5A8b0035697163b61d7268887AE` (pool2),
  standard Aave v3 `AaveOracle` (source verified on SeiScan, compiler 0.8.10). Owner = `ACLAdmin` of the pool
  provider = `0x02135EA9bc6481f7296852c9C3c24e8f9Ef10bE7` (**YeiTimeLockController**, an OpenZeppelin
  `TimelockController`). `setAssetSources` / `setFallbackOracle` are `onlyAssetListingOrPoolAdmins`.
- `getAssetPrice(asset)` = `assetsSources[asset].latestAnswer()`; if source is 0 or price ≤ 0, falls back to
  `_fallbackOracle` — **fallback oracle is `0x0`** in both pools.
- Price sources are **not naive owner pushes** (corpus correction): 13 of 15 sources are the custom
  `Oracle` contract (`src/Oracle.sol`, verified) that reads **Pyth (getPriceUnsafe), Redstone, API3** in a
  configured order with per-source heartbeat + 60 s buffer staleness checks, reverting `NoAvailablePrice()`
  only if all sources are stale. `latestTimestamp()` returns the winning source's publish time.
- All sources are owned by the same `YeiTimeLockController`.

## Per-reserve price source mapping (pool1 unless noted)

| reserve | oracle $ (1e8) | source | source type | live? |
|---|---|---|---|---|
| USDC.n / USDC | 99,972,910 | `0x9657cfbcff1636131de4927bda6fe563ce3d61b6` | Oracle "USDC" | fresh |
| USDT / USD₮0 | 99,945,787 | `0xf56e2a3e177256eef2d713115f79ef23f513f855` | Oracle "USDT" | fresh |
| WSEI | 6,466,517 | `0x241b320946caa015324c9b614d077b4619a4d3d3` | Oracle "SEI" | fresh (ts 1791483897) |
| WETH / frxETH | 242,202,000,000 | `0xc0c85b1117b103d4be97ec5dafe24ef0430e26f5` | Oracle "ETH" | fresh |
| iSEI | 6,985,309 | `0xf708db0c6352d012aa093d71d407cec1250a4cb3` | Oracle "ISEI" | fresh |
| frxUSD | 98,941,400 | `0xaf53096c0cf0d2132cd35c02c572cfc958420557` | Oracle "FRAX" | fresh |
| sfrxUSD | 114,849,167 | `0x306b10fb33665d27e8183e363bb615988f6cdcb3` | Oracle "sFRAX" | fresh |
| sfrxETH | 283,675,162,782 | `0x36f472dc45503f1d2487cf18e52a6d03f36dcfa4` | Oracle "sfrxETH" | fresh |
| **fastUSD / sfastUSD** | **1 (=$1e-8)** | `0x824f04f2cd6d57071bf33a86bbfc5b266fd44b72` | **`CustomOracle` "temporaryOracle"** | static, owner-set |
| WBTC | 8,076,592,742,400 | `0x25c85f34f0f44e9f0ef8f4e86bb22a423ffcb6dc` | Oracle "WBTC" | fresh |
| SolvBTC / xSolvBTC (both pools) | 8,086,014,854,733 | `0x49973fa847fd57d879f48e4b8fd5f968dafd5774` | TransparentUpgradeableProxy (impl `0xe47b9d77…`) | fresh |
| wstETH | 301,214,235,543 | `0xe21ebba5cbc0261fcfe7b062361984809c97f39d` | Oracle | fresh |
| CLO | 6,018,000 | `0xe738397386e2bfea3618bde3462b2f206f5b5dfe` | Oracle | fresh |
| USDY | 113,969,117 | `0xd03fee5e2240c9446832c9219cafc44c6887e243` | `USDyOracle` = USDC oracle × `multiplierBps` (max 1.20) | fresh |

## Oracle vs market (DefiLlama, same day)

| asset | oracle | market (DL) | ratio | note |
|---|---|---|---|---|
| WSEI | 0.06467 | 0.06441–0.06595 | 0.98–1.00 | fine |
| WETH | 2422.02 | 2409.94 | 1.005 | fine |
| frxUSD | 0.98941 | 0.99923–0.99937 | 0.990 | fine (frxUSD oracle lags slightly) |
| frxETH | 2422.02 | 2407.97 | 1.006 | fine |
| sfrxUSD | 1.14849 | 1.21418 | 0.946 | oracle **below** market (collateral undervalued) |
| WBTC | 80,765.93 | ~80,600–81,600 | ≈1.00 | fine |
| SolvBTC | 80,860.15 | 80,639.98 | 1.003 | fine |
| xSolvBTC | 80,860.15 | 80,902.72 | 0.9995 | fine |
| wstETH | 3012.14 | 3005.61–3064.50 | 0.98–1.00 | fine |
| CLO | 0.06018 | 0.06078 | 0.99 | fine |
| USDY | 1.13969 | 1.14872 | 0.992 | fine |
| **USDT.kava (`0xB75D…`)** | **0.99946** | **0.18929–0.19494** | **≈5.2×** | **feed stale/wrong; reserve frozen+LTV0+forced** |
| **fastUSD / sfastUSD** | **1e-8** | no market price (dead) | — | **`temporaryOracle` static 1; reserves frozen+LTV0** |

Sources: `analysis/reserves_raw.json`, `analysis/oracle_feeds_raw.json`, `analysis/reserve_table.md`;
DefiLlama `coins.llama.fi/prices/current|historical`.

## Why no oracle-exploit path today (pool1)

1. **Overvalued assets are all un-borrowable/un-suppliable**:
   - `USDT.kava` (5.2× over oracle): `frozen=1`, `LTV=0`, `borrowingEnabled=1`, `forcedLiquidation=1`. It cannot be
     supplied as new collateral or borrowed; third-party liquidations of positions with USDT debt require the
     forced-liquidation whitelist (reverts `'128'` otherwise).
   - `iSEI`: `frozen=1`, `LTV=0` (only usable inside eMode 2 by pre-existing suppliers; not suppliable now).
   - `fastUSD/sfastUSD` (priced ≈0): `frozen=1`, `LTV=0`; borrow/supply revert `'28'`.
2. **All collateral-eligible (LTV>0, not frozen) reserves are priced within ~1% of market**: WSEI, WETH, WBTC,
   SolvBTC, xSolvBTC, USD₮0, USDC. No >LTV⁻¹ overvaluation exists, so no borrow-and-default profit.
3. Feed freshness: all `Oracle` sources returned `latestTimestamp` within minutes of the read block.

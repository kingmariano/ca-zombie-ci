# On-chain evidence index — Mycelium Perpetual Swaps (Arbitrum)

All calls via public Arbitrum RPC (`https://arb1.arbitrum.io/rpc`), read-only `eth_call`.
Blocks: 514,494,093 (flags), 514,500,782 (balances), 514,505,610 (orders), 514,520,000 (positions),
514,523,261 (final). Sources in `analysis/src-*.json` (Arbiscan, chainid=42161).

## Headline citations

| Claim | Call | Result |
|---|---|---|
| Vault flags | `Vault.isSwapEnabled()` / `isLeverageEnabled()` / `inPrivateLiquidationMode()` / `inManagerMode()` @514494093 | true / false / true / true |
| Vault gov | `Vault.gov()` @514494093 | 0x25D390B53b06Ae32DAB3BDcB1C0D4fa44D2907D7 (Timelock) |
| Timelock admin | `Timelock.admin()` | 0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac (Safe, `getThreshold()`=2) |
| WBTC swap-out blocked | `Vault.bufferAmounts(WBTC)`=3.3e9 > `poolAmounts(WBTC)`=1.2168e8 | swap reverts `Vault: poolAmount < buffer` (fork test_01) |
| WETH swap-out blocked | `bufferAmounts(WETH)`=740e18 > `poolAmounts(WETH)`=1.6012e18 | fork test_02 |
| USDC/LINK/USDT/DAI blocked | buffers 1.378e12 / 1.3778e22 / 4.143e11 / 6.427e23 vs pools 1.437e9 / 6.769e20 / 3.04e5 / 6.75e17 | fork test_02 |
| Only unblocked pools are dust | `poolAmounts(UNI)`=1.0078e13 (0.0000101 UNI), FRAX=3.2e14, CRV=6.6e14 | fork test_02 |
| Chainlink feeds live | `latestRoundData()` on 12 aggregators; WBTC $83,134.41 vs market $83,072.83, WETH $2,503.90 vs $2,506.51 | no mispricing |
| FastPriceFeed stale | `lastUpdatedAt()`=1696291869, `priceDuration()`=300 | falls back to Chainlink |
| FRAX strict-stable | `VaultPriceFeed.strictStableTokens(FRAX)`=true, `maxStrictPriceDeviation()`=5e28, `getPrice(FRAX,*,true,true)`=1e30 | vault FRAX=$1.00 vs market $0.9905 |
| FRAX edge not monetisable | fork test_16: swap 76,292,886,502,438 FRAX → 10,058,213,994,118 wei UNI | gross edge $0.0000006 |
| Liquidation gated | `inPrivateLiquidationMode()`=true, `isLiquidator(attacker)`=false, `isLiquidator(PositionManager)`=true | fork test_06 revert `Vault: invalid liquidator` |
| PositionManager liquidators | `PositionManager.isLiquidator(0x87b674f4… / 0x4a9cf80d…)`=true | 2 EOAs |
| No liquidations ever | `LiquidatePosition` logs on Vault = 0 | — |
| Positions owner-only | `Vault.getPosition(0x9baaa9b5…, USDC, UNI, false)` size=1.1056e33; attacker `decreasePosition` reverts `Vault: invalid msg.sender` | fork test_07 |
| Leverage off | `isLeverageEnabled()`=false; Timelock `enableLeverage` is `onlyAdminOrHandler` | fork test_08 |
| MLP private mode | `MlpManager.inPrivateMode()`=true; direct remove reverts `MlpManager: action not enabled` | fork test_09 |
| MLP handler gate | `isHandler(RewardRouter)`=true, `isHandler(attacker)`=false; attacker ForAccount reverts `MlpManager: forbidden` | fork test_10 |
| MLP bricked | `MlpManager.getAum(false)` / `getAumInUsdg(false)` revert with EMPTY data; RewardRouter handler path also reverts (empty) | fork test_11 |
| OrderBook swap order reverts | `executeSwapOrder(0x3d38f210…, 1, attacker)` → `Vault: reserve exceeds pool` | fork test_03 |
| OrderBook increase order reverts | `executeIncreaseOrder(0xd1dE8093…, 10, attacker)` → `Vault: reserve exceeds pool` | fork test_04 |
| OrderBook decrease order reverts | `executeDecreaseOrder(0xacFF176F…, 0, attacker)` → `Router: invalid plugin` | fork test_05 |
| Pending orders | `getSwapOrder/getIncreaseOrder/getDecreaseOrder` scan of 69 create events → 10 pending, total fees 0.0127 ETH | `orderbook-pending.json` |
| Trackers: no fresh capture | fresh `claim()`=0; stake 100k MYC then `claim()`=0 | fork tests 12/13 |
| Trackers: stakers can claim | sMYC staker `claim()` = 8,367,309,953,026,861 wei WETH; MLP staker = 166,518,273,757,038 wei | fork tests 14/15 |
| Distributors empty | WETH.balanceOf(0xd5c7bba9)=0, (0x0f5976e0)=0 | fork test_17 |
| Stuck distributor | `RewardDistributor(0xdb8cc5be).isInitialized()`=true, `gov()`=0, `rewardTracker()`=0, holds 7.4679 WETH | stuck |
| MYC illiquid | GeckoTerminal: MYC/WETH pools reserve $989 / ~$X, 24h volume 0 | not realisable |

## Value inventory (block 514,500,782, market prices 2026-10-13)

Vault: WBTC 1.23417190 ($102,556) · WETH 1.722166590661866233 ($4,317) · USDC.e 2,997.947146 ·
LINK 681.522524556557239877 ($8,789) · USDT 18.270969 · DAI 133.83462840991191018 · dust → $118,810.
feeMlpTracker: 19.417548813040933241 WETH ($48,676). sMYC tracker: 6.662358833018414643 WETH ($16,701).
Stuck distributor: 7.467861571 WETH ($18,719). OrderBook: $698. PositionRouters: $94.
mlpVester: 0.4954 WETH + 1.81M MYC + 1.43M esMYC. MerkleTokenSale: 196.57M MYC.

## Scripts

* `rpc.py` — batch JSON-RPC helper (public endpoints only)
* `scan-family.py` — balances of 56 family contracts × 17 tokens
* `scan-orderbook.py` — pending-order detection + fee extraction
* `scan-positions.py` — live-position enumeration (1,526 candidates → 15 live)
* `read-trackers.py` — tracker state (flags, handlers, balances)

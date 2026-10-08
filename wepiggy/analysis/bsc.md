# WePiggy — BNB Smart Chain (chainid 56) deployment enumeration

**Block:** 126,492,407 (latest at scan time, 2026-10-08)
**Comptroller:** `0x8c925623708A94c7DE98a8e83e8200259fF716E0`
**Oracle:** `0x4c78015679fabe22f6e02ce8102afbf7d93794ea` (WePiggy WP_PRICE_PROVIDER_V1)
**Owner:** `0x8998f77fc48e674852da89286263fa753927c42e` · **pauseGuardian:** `0x2e74d372eacd55062c115037e4d38df8726dfad1`
**Markets:** 16 (all listed) · **Close factor:** 0.5 · **Liquidation incentive:** 1.08 · **reserveFactor: 100% on all markets**

## How the comptroller was found

- `github.com/WePiggy/contract_addresses` README, **BSC section**: COMPTROLLER `0x8c925623708A94c7DE98a8e83e8200259fF716E0` (also lists the 16 pTokens and WP_PRICE_PROVIDER_V1).
- On-chain cross-check: `getAllMarkets()` on that address returns exactly the 16 pTokens from the README, and `oracle()` returns the README's WP_PRICE_PROVIDER_V1. The Ethereum comptroller `0x0C8c…0f0b` is not deployed on BSC (same address appears on Polygon/OEC as a pToken/IRM, reused-deployer noise).
- The comptroller is a **direct (non-proxy) deployment**: storage slot 0 = oracle; no `admin()`/`comptrollerImplementation()` getters. WePiggy's `markets()` getter returns 3 words `(isListed, collateralFactorMantissa, isMinted)` (ComptrollerStorage.Market has no pause fields in the struct — per-market pauses live in `pTokenMintGuardianPaused` / `pTokenBorrowGuardianPaused`).

## Market state (human units; prices from coins.llama.fi, bsc)

| sym | cToken | underlying | CF | mint | borrow | pTokens | cash | borrows | reserves | supply | rate/pToken | oraclePrice | cash USD |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| pBNB | 0x33a3…22a7 | native BNB | 0 | paused | paused | 1,382.447739 | 31.711972 | 0.069539 | 0 | 31.781511 | 0.022989 | 679.25 | $23,018.54 |
| pETH | 0x849c…6293 | 0x2170…f933f8 | 0 | paused | paused | 78.940966 | 1.603414 | 0.002865 | 0 | 1.606280 | 0.020348 | 2255.00 | $3,908.23 |
| pBTCB | 0x311a…2554 | 0x7130…3ead9c | 0 | paused | paused | 2.826803 | 0.056766 | 0.000039 | 0 | 0.056805 | 0.020095 | 73699.59 | $4,574.58 |
| pDAI | 0x12d8…7c8b | 0x1af3…1dbc3 | 0 | paused | paused | 4,446.906532 | 102.068255 | 25.371138 | 0 | 127.439393 | 0.028658 | 1.00 | $102.02 |
| pUSDT | 0x2a8c…0d7f | 0x55d3…97955 | 0 | paused | paused | 451,956.182263 | 11,366.117688 | 68.360866 | 0 | 11,434.478555 | 0.025300 | 1.00 | $11,358.80 |
| pUSDC | 0x2b7f…6b3f | 0x8ac7…d580d | 0 | paused | paused | 4,308.805150 | 60.166259 | 42.575794 | 0 | 102.742053 | 0.023845 | 1.00 | $60.15 |
| pBUSD | 0x2dd8…e3be | 0xe9e7…87d56 | 0 | paused | paused | 175,708.568457 | 3,819.381080 | 12.667338 | 0 | 3,832.048418 | 0.021809 | 1.00 | $3,811.36 |
| pDOT | 0x811c…aec2 | 0x7083…73402 | 0 | paused | paused | 881.386404 | 17.073596 | 1.224841 | 0 | 18.298437 | 0.020761 | 1.60 | $17.46 |
| pUNI | 0x1793…3159 | 0xbf51…ce9b1 | 0 | **open** | paused | 2,552.723951 | 50.462076 | 0.828286 | 0 | 51.290362 | 0.020092 | 4.09 | $362.64 |
| pCAKE | 0x417f…2c1d | 0x0e09…1ce82 | 0 | paused | paused | 31,745.947475 | 850.798120 | 74.646947 | 0 | 925.445067 | 0.029152 | 1.51 | $1,798.11 |
| pLTC | 0x6a05…471c | 0x4338…0db94 | 0 | paused | paused | 854.705703 | 18.340801 | 0.068173 | 0 | 18.408975 | 0.021538 | 57.57 | $1,132.35 |
| pLINK | 0x00ff…561a | 0xf8a0…a51bd | 0 | paused | paused | 4,475.375022 | 89.926462 | 0.909544 | 0 | 90.836007 | 0.020297 | 9.70 | $1,115.70 |
| pADA | 0xbc52…ad0d | 0x3ee2…35d47 | 0 | paused | paused | 578,132.431088 | 11,694.428922 | 13.309178 | 0 | 11,707.738099 | 0.020251 | 0.29 | $2,651.19 |
| pFIL | 0xdf21…7f32 | 0x0d8c…e153 | 0 | paused | paused | 96.027294 | 0.953112 | 9.728293 | 8.735305 | 1.946100 | 0.020266 | 1.00 | $0.95 |
| pNULS | 0x23cf…6c85 | 0x8cd6…f89313b (8 dec) | 0 | paused | paused | 239,776.844662 | 4,791.641881 | 11.236664 | 0 | 4,802.878545 | 0.020031 | 52.56* | ~$0 |
| pMASK | 0x33d2…294e | 0x2ed9…568a3 | 0 | paused | paused | 2.784319 | 1.549395 | 1.057190 | 0 | 2.606584 | **0.936166** | 0.47 | $0.67 |

\* pNULS oracle price is stale/implausible (DefiLlama returned no price). All others ~= market price.

**Totals:** cash ≈ **$53,913**; supply ≈ **$54,307**. `mintAllowed` reverts "mint is paused" for 15/16 markets (pUNI returns 0 = allowed); `borrowAllowed` reverts "borrow is paused" for all 16; `redeemAllowed` = allowed everywhere.

## Donation-candidate analysis (Hundred-Finance empty-market class)

- **Markets with CF > 0: NONE.** All 16 markets have `collateralFactorMantissa = 0`, `borrowCap = 0` (unlimited), and borrowing is paused everywhere. The empty-market donation → inflate exchange rate → borrow class is **not exploitable at the comptroller level**: an inflated market cannot be entered as collateral and no borrow can be initiated.
- **Truly empty markets (totalSupply = 0): NONE.** Smallest supply values:
  1. **pMASK** — supply 2.606584 MASK ($1.13) vs cash 1.549395 MASK ($0.67); rate 0.936166/pToken.
  2. **pFIL** — supply 1.946100 FIL ($1.95) vs cash 0.953112 FIL ($0.95).
  3. **pBTCB** — supply 0.056805 BTCB ($4,577.70) vs cash 0.056766 BTCB ($4,574.58).
  (All CF=0 / paused; donation would yield no borrowing power.)
- **pMASK anomaly (worth flagging):** exchangeRateStored 0.9362 = **46.8× the ~0.02 initial rate** of every other market, while `borrowIndex` is only 2.05× and `reserveFactor = 100%` with `reserves = 0` — supplier interest cannot explain it. This is the fingerprint of a **direct underlying donation (exchange-rate inflation remnant)**. Last market interaction: a liquidation bot at block 125,778,698 (`0xa7950f…4e961`): repaid 1.010382562847877569 MASK for borrower `0x03f90d07649e6b7717bd3c2f35f3eafa8e425c7b`, seized 3.251525 pBNB, redeemed → 0.000747 BNB, swapped on Pancake. Current pMASK state is the post-liquidation state.
- Other observation: at block 95,688,762 a Uniswap v4 PoolManager init tx created v4 pools with all 16 pTokens as currencies (hook `0x3fae6472c16393e4f82bae559fa6d377b932c088`) — unrelated to WePiggy core, noted for completeness.

## Dead ends / notes

- Ethereum comptroller `0x0C8c…0f0b` not on BSC; no WePiggy BSC comptroller in DefiLlama-Adapters surfaced before the GitHub README hit.
- Etherscan V2 API (free) rejects chainid 56 ("upgrade plan"); Alchemy BNB endpoints 429/403 with the available keys; public dataseed caps batch sizes (~290-call batch fails, 20–25-call chunks OK) and rejects wide `eth_getLogs` ranges; GoldRush `transfers_v2` 500s (only `transactions_v3` worked). Archive state (pre-liquidation history) not retrievable with available public endpoints.

## Files

- `bsc-markets.json` — enriched raw dump (all fields + decimals + human/derived values + notes)
- `bsc-values.json`, `bsc-decimals.json`, `bsc-guards.json` — computed values, decimals/pauses, guard matrix

# Jet v1 obligation census

- obligations fetched: **7289** (all accounts with discriminator a8ce8d6a584caca7, fetched at ~slot 456073460-456075034)
- with any position entry: **7287** (collateral-only 3478, loans-only 0, both 3809)
- with any **nonzero** position: **2853** (collateral-only 2379, loans-only(nonzero debt, no nonzero collateral) 4, both 470)
- obligations with loan value > 0: 474
- loans-only with nonzero debt: 0 (non-empty-list definition) / 4 (nonzero-amount definition)
- market cache prices used: oracle=[1.0, 119.23378, 52326.9113705, 2304.08750074] (last updated slot 451021492)
- real prices used: USDC $0.9997, SOL $108.9377, solBTC $54.6161, solETH $296.5034 (per {"0": "jupiter-v3", "1": "jupiter-v3", "2": "jupiter-v3", "3": "jupiter-v3"})

## Totals (USD oracle values / real values)

| metric | oracle | real |
|---|---|---|
| total loan value | 54,393.61 | 51,448.38 |
| total collateral value | 485,041.69 | 207,158.59 |
| unhealthy obligations | 26 | 60 |

### Debt per reserve (oracle / real USD)

- USDC (0): oracle 42,566.56 / real 42,553.91
- SOL (1): oracle 9,717.87 / real 8,878.71
- solBTC (2): oracle 2,002.94 / real 2.09
- solETH (3): oracle 106.25 / real 13.67

### Collateral per reserve (oracle / real USD)

- USDC (0): oracle 58,817.27 / real 58,799.79
- SOL (1): oracle 161,626.79 / real 147,669.97
- solBTC (2): oracle 261,364.71 / real 272.80
- solETH (3): oracle 3,232.93 / real 416.03

## Liquidator bonus (oracle terms)

- simple metric sum (min(C - D/1.25, 0.03 D)): 36.44 USD
- exact per-source-formula sum: 22.61 USD

## Real-terms liquidation candidates (positive real PnL under on-chain oracle math)

- pairs: 1, estimated total: 0.06 USD
  - 7c6HkPMpv92M… debt(loan r2) 0.08 oracle / coll(r0) 0.06 oracle -> est real PnL 0.06

## Dust distribution of debt

| band | oracle-set | real-set |
|---|---|---|
| <0.10 | 133 | 159 |
| <1 | 104 | 103 |
| <10 | 162 | 148 |
| <100 | 44 | 36 |
| >=100 | 31 | 28 |

## Oracle-unhealthy obligations >= $1 (full list below; rest are dust)

| obligation | owner | debt (oracle) | collateral (oracle) | debt (real) | collateral (real) | exact oracle bonus | best real PnL |
|---|---|---|---|---|---|---|---|
| 2xFbaXMJ4Q3tFKqN... | GBpe8E33cNkF... | 5144.91 | 2660.95 | 4700.63 | 2.78 | 0.00 | 0.00 |
| B8FENB5WyL9iimPL... | 5DdnXL9eYGS4... | 1207.11 | 1344.13 | 1206.75 | 1.40 | 22.58 | 0.00 |
| 8aAhuyRVPuDuZ5zN... | 6eMxDsNHDRyg... | 806.61 | 161.75 | 736.96 | 161.71 | 0.00 | 0.00 |
| FkPRkmC5fvxvVdao... | 8dVHCoEtJBRn... | 100.99 | 56.23 | 92.27 | 56.21 | 0.00 | 0.00 |
| xogaY3VRafJC7Jsc... | HmjxCroPGbPM... | 1.68 | 2.04 | 1.68 | 2.03 | 0.01 | 0.01 |
| 27WL5iHj9JeSL7on... | 8QkMS9m5tKKh... | 1.28 | 1.55 | 1.28 | 1.55 | 0.01 | 0.01 |
| E8T1yyia64rVhWK6... | BVQjwmmCc9uk... | 1.23 | 0.96 | 1.12 | 0.96 | 0.00 | 0.00 |
| 93FfB2bVfG5u2nEw... | 8F2bKxNXZ3xR... | 1.04 | 1.30 | 0.95 | 1.19 | 0.00 | 0.00 |

## Real-unhealthy obligations (debt real > 1.25 x collateral real) - top 20 by real debt

| obligation | owner | debt (real) | collateral (real) | debt (oracle) | collateral (oracle) |
|---|---|---|---|---|---|
| 7hiohKNj97RUBhGP... | HcdvpFHKNBtz... | 11554.52 | 50.02 | 11557.95 | 47925.28 |
| 3s6yrtiNsJPjRStu... | 4pk84fPV9WCz... | 9310.79 | 31.79 | 9313.56 | 30456.61 |
| 5a5TTeCZVuWGj1HF... | Fz29i6xkNgpo... | 5988.24 | 24.78 | 5990.02 | 23741.95 |
| AkoY6BAZ4AjqWu7X... | 59aHxK4GjKXN... | 4985.02 | 18.74 | 4986.50 | 17953.80 |
| 2xFbaXMJ4Q3tFKqN... | GBpe8E33cNkF... | 4700.63 | 2.78 | 5144.91 | 2660.95 |
| DGU6YXLqCfuokFna... | EdgLSiYEfsjm... | 3146.80 | 14.21 | 3147.73 | 13612.95 |
| AL7LGVQ43d9ZGEbF... | BdStWKvWhK9r... | 1376.04 | 15.78 | 1376.45 | 15118.12 |
| B8FENB5WyL9iimPL... | 5DdnXL9eYGS4... | 1206.75 | 1.40 | 1207.11 | 1344.13 |
| 9BtKwKDcCfTgDFi5... | GDvfwuytQuzK... | 1010.02 | 3.69 | 1010.32 | 3535.25 |
| FZQBgSEFL5oN9HH9... | 2ZcYhxGkKir9... | 1003.95 | 1.54 | 1004.25 | 1472.90 |
| 4QztvotMREKpZJj4... | 59vKgH1RX2gY... | 961.55 | 5.09 | 961.83 | 4872.57 |
| 8aAhuyRVPuDuZ5zN... | 6eMxDsNHDRyg... | 736.96 | 161.71 | 806.61 | 161.75 |
| BitxCyMRTwJvUK5V... | AoVFaxrGXt3C... | 463.27 | 147.97 | 507.06 | 1149.83 |
| 6x9fMyQKBVYMceWK... | F7n8tsbZTc6K... | 338.47 | 1.24 | 338.57 | 1185.66 |
| 91J73YdwPufdJ1Mx... | HE7EuxXajySt... | 275.08 | 92.86 | 275.16 | 721.62 |
| EdgNhtAJ8rutgBJZ... | FbyzmYrzMK43... | 185.30 | 1.63 | 202.81 | 1566.02 |
| Ci7VoYk6cinPG3nr... | C8n84un3bqTb... | 122.10 | 1.33 | 122.14 | 1272.10 |
| FkPRkmC5fvxvVdao... | 8dVHCoEtJBRn... | 92.27 | 56.21 | 100.99 | 56.23 |
| 3PvFhKuk8r1m2PWE... | 3Xv2DSebn2DG... | 40.17 | 0.15 | 40.18 | 144.05 |
| EKgxxMYNrTCYkCVq... | 8C8Ad1xrWhfN... | 33.73 | 11.84 | 33.74 | 92.01 |

Caveats: 'real' prices are thin-market DEX prices (Jupiter v3); solBTC/solETH exit liquidity is only a few $k, so real value is indicative. 
Oracle prices come from the on-chain market cache (last refresh slot 451021492, i.e. 2026-09-27), sourced from frozen Pyth legacy feeds.

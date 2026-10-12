# Mobius pools — DefiLlama-priced vs realizability-adjusted value

- **DL-priced total (fresh balances, correct token ids): $412,887.37**
- **Realizability-adjusted total: $262,966.47** (junk-side & BTC-token sides haircut to 0; see FACT table in script)
- Of the DL total, **$118,821.37** is the two BTC pools' d629/baab sides (no on-chain liquidation venue; paper only).

| pool | paused | DL USD | realizable USD | detail |
|---|---|---|---|---|
| `0xa5037661989789d0310ac2b796fa78f1b01f195d` | False | 86,363.82 | 86,363.82 | USDm 24432.3 ($24,467.63); USDC 61914.4 ($61,896.19) |
| `0xf3f65dfe0c8c8f2986da0fec159abe6fd4e700b4` | False | 84,608.25 | 84,608.25 | USDm 32760.3 ($32,807.64); DAI 51795.7 ($51,800.61) |
| `0x19260b9b573569ddb105780176547875fe9feda3` | False | 79,913.93 | 0.00 | BTC 0.965833 ($79,913.93 x0.0) BTC18 TokenSoft - no liquidation venue; cross-rate mark ~$44.5k is thin/stale |
| `0xaefc4e8cf655a182e8346b24c8abce45616ee0d2` | False | 38,907.44 | 0.00 | BTC 0.444971 ($36,817.33 x0.0) BTC18 TokenSoft - no liquidation venue; cross-rate mark ~$44.5k is thin/stale; WBTC 0.0252984 ($2,090.11 x0.0) WBTC2 (Optics) - no liquidation venue |
| `0x63c1914bf00a9b395a2bf89aada55a5615a3656e` | False | 35,121.74 | 13,413.91 | USDm 13394.6 ($13,413.91); asUSDC 21714.2 ($21,707.83 x0.0) asUSDC (Allbridge - paused; no mkt) |
| `0x0ff04189ef135b6541e56f7c638489de92e9c778` | False | 25,488.70 | 25,488.71 | USDm 5119.57 ($5,126.97); cUSDC 20367.7 ($20,361.74) |
| `0x74ef28d635c6c5800dd3cd62d4c4f8752daacb09` | False | 21,755.23 | 15,859.87 | cETH 12.5485 ($19,651.23 x0.7) cETH (Optics 'Wrapped Ethereum') - thin mkt; WETH 0.832993 ($2,104.01) |
| `0xdbf27fd2a702cc02ac7acf0aea376db780d53247` | False | 21,353.05 | 21,353.04 | USDm 12970.5 ($12,989.26); cUSDT 8370.68 ($8,363.78) |
| `0xe0f2cc70e52f05edb383313393d88df2937da55a` | False | 11,455.74 | 8,290.05 | cETH 6.73826 ($10,552.30 x0.7) cETH (Optics 'Wrapped Ethereum') - thin mkt; WETH 0.357597 ($903.44) |
| `0xcce0d62ce14fb3e4363eb92db37ff3630836c252` | False | 3,746.49 | 3,746.49 | USDm 3741.08 ($3,746.49) |
| `0x9906589ea8fd27504974b7e8201df5bbde986b03` | False | 2,777.81 | 2,777.81 | USDm 2773.8 ($2,777.81) |
| `0x0986b42f5f9c42feeef66fc23eba9ea1164c916d` | False | 534.30 | 280.56 | USDm 280.151 ($280.56); aaUSDC 253.822 ($253.75 x0.0) aaUSDC (Allbridge - paused; no mkt) |
| `0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c` | False | 330.88 | 330.88 | USDm 330.407 ($330.88) |
| `0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a` | False | 130.44 | 130.44 | CELO 1368.14 ($130.44) |
| `0x2080aaa167e2225e1fc9923250ba60e19a180fb2` | False | 124.02 | 124.02 | USDm 123.838 ($124.02) |
| `0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae` | False | 116.40 | 39.48 | USDm 39.4196 ($39.48); atUST 14513.8 ($76.92 x0.0) atUST (dead Terra claim; mkt $0.06 depth) |
| `0xc0ba93d4aaf90d39924402162ee4a213300d1d60` | False | 96.85 | 96.86 | USDm 55.855 ($55.94); USDC 40.9274 ($40.92) |
| `0x382ed834c6b7dbd10e4798b08889eaed1455e820` | False | 30.02 | 30.02 | EURm 26.7785 ($30.02) |
| `0xebf0536356256f8ff2a5eb6c65800839801d8b95` | False | 11.91 | 11.91 | CELO 124.955 ($11.91) |
| `0x23c95678862a229fac088bd9705622d78130bc3e` | False | 11.58 | 11.58 | EURm 10.3275 ($11.58) |
| `0x413ffcc28e6cdde7e93625ef4742810fe9738578` | False | 6.99 | 6.99 | CELO 73.3617 ($6.99) |
| `0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735` | False | 1.58 | 1.58 | USDm 1.57545 ($1.58) |
| `0xfa3df877f98ac5ecd87456a7accaa948462412f0` | False | 0.20 | 0.20 | USDm 0.0170615 ($0.02); USDC 0.184474 ($0.18) |
| `0x81b6a3d9f725ab5d706d9e552b128bc5bb0b58a1` | True | 0.00 | 0.00 |  |

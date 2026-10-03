# C-32 Moonwell market/oracle table

Generated 2026-10-03 03:51 UTC from `analysis/out/*.json` (on-chain reads; external refs as noted). All values USD per whole token.

## base (chain id 8453, block-head scan 2026-10-03 02:46 UTC)

Comptroller `0xfBb21d0380beE3312B33c4353c8936a0F13EF26C`, oracle `0xec942be8a8114bfd0396a5052c36027f2ca6a9d0` (matches docs: True), close factor 0.5, liquidation incentive 1.1, pauseGuardian `0xb9d4acf113a423bc4a64110b8738a52e51c2ab38`

| market | underlying | oracle $ | external $ (source) | div % | CF | borrow cap | mint/borrow paused | oracle src | feed age | feed |
|---|---|---|---|---|---|---|---|---|---|---|
| mUSDC | USDbC | 0.99991498 | 0.9999598615389947 (defillama) | -0.004 | 0.63 | 1 | False/False | chainlink_feed | 14.0h | `0xb7967d184907737a955f39a8067bc1a0cc313292` |
| mWETH | WETH | 2679.71119369 | 2680.1 (CoinGecko) | -0.015 | 0.84 | 1 | False/False | chainlink_feed | 0.2h | `0x57da741ad933869cc9ebfb9668288053a0738f3c` |
| mcbETH | cbETH | 3057.04607105799 | 3056.1776860942605 (defillama) | 0.028 | 0.81 | 1 | False/False | chainlink_feed | 0.0h | `0xb0ba0c5d7da4ec400c1c3e5ef2485134f89918c5` |
| mDAI | DAI | 0.99998065 | 0.9998615105636262 (defillama) | 0.012 | 0.5 | 1 | False/False | chainlink_feed | 12.4h | `0x0eab3b9ae08b43077ad1aeb9820462faf99bcec8` |
| mUSDC | USDC | 0.99991498 | 1.0 (stable) | -0.009 | 0.88 | 1 | False/False | chainlink_feed | 14.0h | `0xb7967d184907737a955f39a8067bc1a0cc313292` |
| mwstETH | wstETH | 3335.6673064771358 | 3335.4062027101263 (defillama) | 0.008 | 0.81 | 1 | False/False | chainlink_feed | 0.0h | `0xa5a5892bcfca4642c6bd789ca75f27774309dcb7` |
| mrETH | rETH | 3143.1931974479135 | 3135.4668056859814 (defillama) | 0.246 | 0.78 | 1 | False/False | chainlink_feed | 0.0h | `0x98819cc6c48ee912508454b0f1f4e68bd35ca313` |
| mAERO | AERO | 0.79498705 | 0.7924515426368779 (defillama) | 0.320 | 0.6 | 1 | False/False | chainlink_feed | 0.1h | `0x3623c921bfd9d7e9d88e5cbb436b68be2c2bc0b7` |
| mweETH | weETH | 2959.390300116455 | 2959.157685484799 (defillama) | 0.008 | 0.78 | 1 | False/False | chainlink_feed | 0.0h | `0xe44b816fe6bc5047c22b9fa5e4d4c5c9747476b3` |
| mcbBTC | cbBTC | 84646.15570567 | 84649.66837691132 (defillama) | -0.004 | 0.85 | 1 | False/False | chainlink_feed | 0.2h | `0xfea70a74d94a6b6f9764db9c4867bbe4678a5da6` |
| mEURC | EURC | 1.12552984 | 1.1247829309515243 (defillama) | 0.066 | 0.88 | 1 | False/False | chainlink_feed | 22.4h | `0x945ab3891d7963214833b4d51f54f068c8e6b55e` |
| mwrsETH | wrsETH | 2897.3770053190415 | 2943.68 (GeckoTerminal DEX (Base)) | -1.573 | 0.46 | 1 | True/True | chainlink_feed | 0.0h | `0xccc994a46c0d81c934fd6c82d89f626aee336ade` |
| mWELL | WELL | 0.00226411 | 0.002239293065837657 (defillama) | 1.108 | 0.55 | 1 | False/False | chainlink_feed | 4.5h | `0x605f14438a6b44a78975fa6bec37f041687a8bae` |
| mUSDS | USDS | 1.00003013 | 0.9999092534979965 (defillama) | 0.012 | 0.8 | 1 | False/False | chainlink_feed | 12.4h | `0xf655eedede0cd9f7a3de5e8018909c429dcfbf9b` |
| mtBTC | tBTC | 84584.11234357 | 84648.48139628227 (defillama) | -0.076 | 0.64 | 1 | False/False | chainlink_feed | 1.9h | `0xd46e01f8517319784c58dfe2004440999a75ea66` |
| mLBTC | LBTC | 85017.80904214221 | 84888.75629205731 (defillama) | 0.152 | 0.8 | 1 | False/False | chainlink_feed | 0.0h | `0xb9059d6ace87b699e67ec750fe4399d29797d232` |
| mVIRTUAL | VIRTUAL | 0.7709206 | 0.7716882641365381 (defillama) | -0.099 | 0.65 | 1 | False/False | chainlink_feed | 0.5h | `0xc19b9ff59e445e267283ca6618ea647268f200b0` |
| mMORPHO | MORPHO | 2.5727442 | 2.577177667318552 (defillama) | -0.172 | 0.6 | 1 | False/False | chainlink_feed | 1.0h | `0x769e8d347c75502878c1844eafacea3547d9a225` |
| mcbXRP | cbXRP | 1.49198406 | 1.4897858155182417 (defillama) | 0.148 | 0.74 | 1 | False/False | chainlink_feed | 1.5h | `0xe5c91119dff7e04cd6834a9c9d0a66380edb4af5` |
| mMAMO | MAMO | 0.00752407 | 0.0075599 (GeckoTerminal DEX (Base)) | -0.474 | 0.5 | 1 | False/False | chainlink_feed | 0.2h | `0xdbd37c274a70a8a3f92a227c843a6a8d3203afe6` |
| mVVV | VVV | 27.84461110689612 | 27.878805819594696 (defillama) | -0.123 | 0.5 | 1 | False/False | chainlink_feed | 0.2h | `0x0208810d9d0d639d6e212ad1b42cfb22ab3e51a2` |

## optimism (chain id 10, block-head scan 2026-10-03 02:47 UTC)

Comptroller `0xCa889f40aae37FFf165BccF69aeF1E82b5C511B9`, oracle `0x2f1490bd6ad10c9ce42a2829afa13eac0b746dcf` (matches docs: True), close factor 0.5, liquidation incentive 1.1, pauseGuardian `0x355f7b5edbfbfb5ccc7a3c67dab2f99a72fdda09`

| market | underlying | oracle $ | external $ (source) | div % | CF | borrow cap | mint/borrow paused | oracle src | feed age | feed |
|---|---|---|---|---|---|---|---|---|---|---|
| mUSDC | USDC | 1.00000007 | 1.0 (stable) | 0.000 | 0.88 | 34000000000000 | False/False | chainlink_feed | 7.2h | `0xd05b7d0d156798a85335ecd283d20c7ae07142e4` |
| mUSDT | USDT | 0.999805 | 1.0 (stable) | -0.019 | 0.88 | 18400000000000 | False/False | chainlink_feed | 7.2h | `0x9427a800f5618deb7162a4cdd74b613f30a1554a` |
| mDAI | DAI | 0.99979657 | 0.9998615105636262 (defillama) | -0.006 | 0.83 | 1 | False/False | chainlink_feed | 9.7h | `0xfa1eb770dd37870a4eb0bfe8e70e809852cd0a06` |
| mWBTC | WBTC | 84564.25981587 | 84629.24 (CoinGecko) | -0.077 | 0.001 | 10000 | False/False | chainlink_feed | 0.1h | `0x452f29e1942a29fabdef3620f9e989c294234c71` |
| mWETH | WETH | 2679.17131543 | 2680.1 (CoinGecko) | -0.035 | 0.83 | 30000000000000000000000 | False/False | chainlink_feed | 0.1h | `0x6fb1e8b41fcdd1fafa75d5281fbbe7dbb87434d2` |
| mwstETH | wstETH | 3335.36731467992 | 3335.4062027101263 (defillama) | -0.001 | 0.81 | 10000000000000000 | False/False | chainlink_feed | 0.0h | `0xe770bd40b6976efbbb095174395dd2cb794c938a` |
| mcbETH | cbETH | 3056.4881249364526 | 3056.1776860942605 (defillama) | 0.010 | 0.01 | 100000000000000000 | False/False | chainlink_feed | 0.0h | `0x6250e204ba6f722c7d498f659f8d3c5550ec811e` |
| mrETH | rETH | 3142.5599420141643 | 3135.4668056859814 (defillama) | 0.226 | 0.79 | 1 | False/False | chainlink_feed | 0.0h | `0x48ce24c1d1da86158da2dd8aee23f906161e3433` |
| mVELO | VELO | 0.03482894 | 0.034372293927997774 (defillama) | 1.329 | 0.0 | 1 | True/True | chainlink_feed | 0.0h | `0xa061ed814bbd1b03e8df0b7abebc40f4a6feb895` |
| mOP | OP | 0.1307 | 0.13081568160877588 (defillama) | -0.088 | 0.65 | 1 | False/False | chainlink_feed | 0.0h | `0xf613dc4cc612d19dff308e77d65d34db27c46303` |
| mweETH | weETH | 2958.896547253997 | 2959.157685484799 (defillama) | -0.009 | 0.77 | 1 | False/False | chainlink_feed | 0.0h | `0xecd80fbc47b1689445a1adfc278bcb41eb9bc766` |
| mVELO | VELO | 0.03482894 | 0.034372293927997774 (defillama) | 1.329 | 0.6 | 1 | False/False | chainlink_feed | 0.0h | `0xa061ed814bbd1b03e8df0b7abebc40f4a6feb895` |
| mwrsETH | wrsETH | 2896.793274184179 | 2872.79 (GeckoTerminal DEX (OP)) | 0.836 | 0.37 | 100000000000000000 | True/True | chainlink_feed | 0.0h | `0x5fddda4866db63685018faa1bfc9bfce7072014c` |
| mUSDT0 | USD₮0 | 0.999805 | 1.0 (stable) | -0.019 | 0.83 | 8000000000000 | False/False | chainlink_feed | 7.2h | `0x9427a800f5618deb7162a4cdd74b613f30a1554a` |

## ethereum (chain id 1, block-head scan 2026-10-03 02:48 UTC)

Comptroller `0xdec80bB934397575594E91970b37baf65f5b21bE`, oracle `0x599a01297fc181558bdfa1737cafee513694b654` (matches docs: True), close factor 0.5, liquidation incentive 1.1, pauseGuardian `0x5b710010586c1b728b047c3e42473c700eea4026`

| market | underlying | oracle $ | external $ (source) | div % | CF | borrow cap | mint/borrow paused | oracle src | feed age | feed |
|---|---|---|---|---|---|---|---|---|---|---|
| mWETH | WETH | 2678.6094 | 2680.1 (CoinGecko) | -0.056 | 0.8 | 20000000000000000000000 | False/False | chainlink_feed | 0.8h | `0xe28454de12d1bad21cace063f4f095da7e4350d2` |
| mUSDC | USDC | 0.99998993 | 1.0 (stable) | -0.001 | 0.85 | 180000000000000 | False/False | chainlink_feed | 5.2h | `0x019b18f787abc756520ddc48bf92b0222c85bcbe` |
| mUSDT | USDT | 0.99983258 | 1.0 (stable) | -0.017 | 0.85 | 180000000000000 | False/False | chainlink_feed | 12.2h | `0x4d46d74ccfe86ed3aa0c9c2487fcd977967c5ae7` |
| mcbBTC | cbBTC | 84974.43756243 | 84654.49312846265 (defillama) | 0.378 | 0.8 | 60000000000 | False/False | chainlink_feed | 9.6h | `0x86a1f72ffeafd397ead099a5a359fe81749351b5` |

## moonbeam (chain id 1284, block-head scan 2026-10-03 02:45 UTC)

Comptroller `0x8E00D5e02E65A19337Cdba98bbA9F84d4186a180`, oracle `0xed301cd3eb27217bdb05c4e9b820a8a3c8b665f9` (matches docs: True), close factor 0.5, liquidation incentive 1.1, pauseGuardian `0x82aa6030973b61aced7c978ee0e73a83136b02a9`

| market | underlying | oracle $ | external $ (source) | div % | CF | borrow cap | mint/borrow paused | oracle src | feed age | feed |
|---|---|---|---|---|---|---|---|---|---|---|
| mGLMR | GLMR | 0.007638024166329579 | 0.008481 (DefiLlama) | -9.940 | 0.37 | 100000000000000000 | True/True | chainlink_feed | 1514.8h | `0x80308dce5bd550209fdb22871ce411869014ee8e` |
| mDOT | xcDOT | 0.7594352399285714 | 1.1655 (CoinGecko DOT) | -34.840 | 0.55 | 1000000000 | True/True | chainlink_feed | 1515.9h | `0xccdf06f6c0f53b0e753e816e226bfd349e397736` |
| mETH | WETH | 1865.865384615385 | 2680.1 (CoinGecko) | -30.381 | 0.0 | 0 | True/True | chainlink_feed | 1520.1h | `0x1ae6fcc292417245f2db747317fbaa1e3914fa0d` |
| mWBTC | WBTC | 62827.69631394642 | 84629.24 (CoinGecko) | -25.761 | 0.0 | 0 | True/True | chainlink_feed | 1517.7h | `0x9f61b8e136f3cbe9a678bbae652819c13531fd29` |
| mUSDC | USDC | 0.99986725 | 1.0 (stable) | -0.013 | 0.0 | 0 | True/True | chainlink_feed | 1523.8h | `0x4fa8b7153d770e2ead9bf293244aaa9064032a94` |
| mFRAX | FRAX | 0.9901863223327848 | 0.9923 (DefiLlama) | -0.213 | 0.21 | 100000000000000000 | True/True | chainlink_feed | 1523.8h | `0xedf5858b2eb814f1748272dbe2b13b8ca161dde6` |
| mETH.wh | WETH | 1865.865384615385 | 2680.1 (CoinGecko) | -30.381 | 0.24 | 100000000000000000 | True/True | chainlink_feed | 1520.1h | `0x1ae6fcc292417245f2db747317fbaa1e3914fa0d` |
| mWBTC.wh | WBTC | 62827.69631394642 | 84629.24 (CoinGecko) | -25.761 | 0.06 | 10000000 | True/True | chainlink_feed | 1517.7h | `0x9f61b8e136f3cbe9a678bbae652819c13531fd29` |
| mUSDC.wh | USDC | 0.99986725 | 1.0 (stable) | -0.013 | 0.09 | 100000 | True/True | chainlink_feed | 1523.8h | `0x4fa8b7153d770e2ead9bf293244aaa9064032a94` |
| mBUSD.wh | BUSD | 1.0 | 1.0 (stable) | 0.000 | 0.0 | 100000000000000000 | True/True | override | 497498.8h | `0x2330fd83662bba3fc62bc48cc935ca58847a8957` |
| mxcUSDT | xcUSDT | 0.9986883069823309 | 1.0 (stable) | -0.131 | 0.25 | 100000 | True/True | chainlink_feed | 1523.8h | `0x5c4916479faae9e248ccf8d981ec18d6ef709057` |
| mxcUSDC | xcUSDC | 0.99986725 | 1.0 (stable) | -0.013 | 0.25 | 100000 | True/True | chainlink_feed | 1523.8h | `0x4fa8b7153d770e2ead9bf293244aaa9064032a94` |

## moonriver (chain id 1285, block-head scan 2026-10-03 02:48 UTC)

Comptroller `0x0b7a0EAA884849c6Af7a129e899536dDDcA4905E`, oracle `0x892be716dcf0a6199677f355f45ba8cc123baf60` (matches docs: True), close factor 0.5, liquidation incentive 1.1, pauseGuardian `0xf4643e5653a07c9aacb031dd99e304175affb6af`

| market | underlying | oracle $ | external $ (source) | div % | CF | borrow cap | mint/borrow paused | oracle src | feed age | feed |
|---|---|---|---|---|---|---|---|---|---|---|
| mMOVR | MOVR | 1.25 | 1.8826 (DefiLlama) | -33.602 | 0.0 | 100000000000000000 | True/True | chainlink_feed | 1290.3h | `0x90791e2f723bd683828fc35904748f9c61ab3c2e` |
| mWBTC | WBTC | 69145.0 | 84629.24 (CoinGecko) | -18.297 | 0.0 | 10000000 | True/True | override | 497498.8h | `0x1b5c6cf9df1cbf30387c24cc7db1787ccf65c797` |
| mETH | ETH | 2050.0 | 2680.1 (CoinGecko) | -23.510 | 0.0 | 100000000000000000 | True/True | override | 497498.8h | `0xc3cf399566220dc5ed6c8cfbf8247214af103c72` |
| mUSDC | USDC | 1.0 | 1.0 (stable) | 0.000 | 0.0 | 100000 | True/True | override | 497498.8h | `0x12870664a77dd55bbdcde32f91eb3244f511ef2e` |
| mUSDT | USDT | 1.0 | 1.0 (stable) | 0.000 | 0.0 | 100000 | True/True | override | 497498.8h | `0xf80dad54af79257d41c30014160349896ca5370a` |
| mFRAX | FRAX | 1.0 | 0.9923 (DefiLlama) | 0.776 | 0.0 | 100000000000000000 | True/True | override | 497498.8h | `0xd080d4760318710e795b0a59f181f6c1512ffb15` |
| mxcKSM | xcKSM | 4.8 | 5.1 (CoinGecko KSM) | -5.882 | 0.0 | 100000000000 | True/True | override | 497498.8h | `0x6e0513145fce707cd743528db7c1cab537de9d1b` |


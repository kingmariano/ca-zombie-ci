# L-2 Phase-1 triage — Triage-B (alt-EVMs / L2s)

**Date:** 2026-10-11 · **Scope:** 29 watchlist rows (alt-EVM / L2 zombie candidates) · **Status:** read-only custody screen; no transactions, no vulnerability analysis; all balances read via keyless public RPCs at the blocks below.

**CI runs (heavy enumeration):** full screen — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38131461859 · deep pass (all-pair scans) — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38134363405

## 1. What this is

Phase-1 of the L-2 sweep: for each of the 29 rows in `ci/L2-SPLIT-B.json` (whose `funds` column is months old), determine **what is live on-chain today**. For every row we resolved the protocol's core custody contracts from the *current* DefiLlama registry/adapter definitions (`registries/uniswapV2.js`, `uniswapV3.js`, `compound.js`, `sumTokens.js`, `liquity.js`, and `projects/*`), then read live balances directly (`eth_call` / `eth_getLogs` / `eth_getBalance`) at the latest block of each chain. Token amounts are valued with DefiLlama `coins.llama.fi` prices (same price source DefiLlama uses for TVL).

Method per contract class:

- **AMM V2 factories** — `allPairsLength()` + `allPairs(i)` + `token0/token1/balanceOf` of every pair (full pair list; capped at 800 + last 200 with a note if a factory is bigger).
- **CL (UniV3/Algebra) factories** — pool-created events via chunked `eth_getLogs` (Etherscan V2 logs as fallback where a public RPC caps ranges), then `balanceOf(token0/1)` per pool.
- **Compound forks** — `getAllMarkets()` + per-market `underlying()`/`balanceOf`/`totalBorrows`.
- **Vaults / pools / staking** — explicit `balanceOf(token, owner)` sets from the registry definitions; LP tokens resolved pro-rata against pair reserves.
- **Pendle-style (Splice)** — market-creation logs, then per SY: `assetInfo()`, direct uAsset balance, and the claim value `totalSupply × exchangeRate`.

## 2. TL;DR — live vs watchlist

- **25 of 29 rows are LIVE-FUNDED** on-chain today: **$5,554,029** of verified, directly-read custody value (excluding rows where DefiLlama overstates; see notes).
- **3 rows are DRAINED / effectively $0** (contracts exist but hold < $1k).
- **1 row UNREACHABLE** — Kleva Farm (adapter data source dead, custody addresses not re-derivable); two chain-level targets (Canto for LeetSwap, SatoshiVM for savmSwap) are dead and excluded from those rows' totals.
- **0 rows ALREADY-COVERED** — no prior report in the corpus covers these 29.
- DefiLlama's *current* TVL is fresh (updated today) for 27/29 rows, but for several rows the number is **not reproducible on-chain** (carried-forward from failing adapters): most notably **LuigiSwap** (DL $337k vs live ~$0.6k) and **Pala** (DL $401k vs market-priced live ~$42k; DL uses the protocol's own internal oracle, which prices Orbit-bridge assets far above market).

## 3. Per-row results (sorted by live $ desc)

| # | Protocol | Chain(s) | Status | Conf | Live $ (on-chain) | DefiLlama today | Watchlist (stale) | Key custody contracts (chain: address) | Blocks |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Ra Exchange | fraxtal | **LIVE-FUNDED** | high | $837,929 | $839,491 | $0.872M | fraxtal: `0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42`; fraxtal: `0xaaa16c016bf556fcd620328f0759252e29b1ab57`; Ra CL factory (UniV3) (112 pools); Ra stable AMM factory (crAMM) (63 pairs) | fraxtal:42451737 |
| 2 | Powercity Flex Protocol | pulse | **LIVE-FUNDED** | high | $730,044 | $728,119 | $0.832M | pulse: `0xC2D0720721d48cE85e20Dc9E01B8449D7eDd14CE`; pulse: `0xCeC2c718ceFdb3A515D3CC22e430b46933922CE4`; Flex TroveManager (HEX collateral); Flex staking (FLEX); Flex staking LPs | pulse:27769393 |
| 3 | Splice Finance | blast,mode | **LIVE-FUNDED** | high | $484,393 | $485,445 | $0.502M | mode: `0x9e6d12097339ddd5402FDD39fc0Ef86Eec54AB39`; blast: `0x96A6C433078059577F0CEB707d596A5F81d64375`; Splice factory (Mode) (16 mkts); Splice factory 1 (Blast) (4 mkts); Splice factory 2 (Blast) (3 mkts) | blast:41452198, mode:45773340 |
| 4 | Swapr V3 | xdai | **LIVE-FUNDED** | high | $375,439 | $376,102 | $0.488M | xdai: `0xa0864cca6e114013ab0e27cbd5b6f4c8947da766`; Swapr V3 Algebra factory (Gnosis) (2865 pools) | xdai:48699991 |
| 5 | Nile Legacy | linea | **LIVE-FUNDED** | high | $355,124 | $418,312 | $0.390M | linea: `0xAAA16c016BF556fcD620328f0759252E29b1AB57`; linea: `0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F`; Nile V2 factory (cAMM) (133 pairs); Nile staking (NILE) | linea:32290939 |
| 6 | Mobius Money | celo | **LIVE-FUNDED** | high | $234,206 | $350,422 | $0.366M | celo: `0xc0ba93d4aaf90d39924402162ee4a213300d1d60`; Mobius stableswap pools (registry tokensAndOwners) | celo:79814420 |
| 7 | savmSwap | prom,svm | **LIVE-FUNDED (partial)** | medium | $233,736 | $315,424 | $0.367M | prom: `0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9`; svm: `0x1842c9bD09bCba88b58776c7995A9A9bD220A925`; savmSwap factory (Prom) (90 pairs) | prom:10059509 |
| 8 | FlareBank | flare | **LIVE-FUNDED** | high | $222,024 | $222,612 | $0.221M | flare: `0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059`; FlareBank owners (WFLR) | flare:71847935 |
| 9 | AbstraDEX | blast,cronos_zkevm,morph,xlayer,zeta,zkfair | **LIVE-FUNDED** | medium | $214,201 | $432,930 | $0.414M | xlayer: `0xa7afb6163c331ddb0845843889d6f9544328846f`; zkfair: `0x174c4C03DfeA09682728A5959A253bf1F7C7766F`; AbstraDEX factory (X Layer) (517 pairs); AbstraDEX factory (ZKFair) (3 pairs); AbstraDEX factory (Zeta | blast:41452198, cronos_zkevm:2671971, morph:28121408, xlayer:72945851, zeta:1941 |
| 10 | Cog | scroll | **LIVE-FUNDED** | high | $193,324 | $236,207 | $0.205M | scroll: `0xbabd55549c266c6755b99173fe7604238d04117d`; scroll: `0xCd44fecb08bb28405992358131Fd5081A0F550D0`; Cog factory 1 (93 pairs); Cog factory 2 (16 pairs) | scroll:35337420 |
| 11 | Vessel Finance | scroll | **LIVE-FUNDED** | high | $193,046 | $193,398 | $0.200M | scroll: `0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2`; Vessel VaultProxy (ETH/USDT/USDC/WBTC) | scroll:35337420 |
| 12 | Capybara Dexs | kaia | **LIVE-FUNDED** | high | $167,342 | $165,807 | $0.114M | kaia: `0x3CA30C862769b5de7987D2E2db4c1A72800A1Da1`; Capybara MasterWombat (24 pools) | kaia:229512567 |
| 13 | AuroraSwap | aurora | **LIVE-FUNDED** | high | $160,077 | $164,406 | $0.158M | aurora: `0xC5E1DaeC2ad401eBEBdd3E32516d90Ab251A3aA3`; aurora: `0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE`; AuroraSwap factory (125 pairs); AuroraSwap staking (AURORA) | aurora:219514157 |
| 14 | Nile CL | linea | **LIVE-FUNDED** | medium | $144,257 | $351,152 | $0.155M | linea: `0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42`; Nile CL factory (UniV3) (391 pools) | linea:32290939 |
| 15 | LFGSwap EthereumPoW | ethpow | **LIVE-FUNDED** | medium | $120,091 | $311,068 | $0.259M | ethpow: `0xf66cef53c518659bFA0A9a4Aa07445AF08bf9B3a`; LFGSwap factory (EthereumPoW) (1581 pairs) | ethpow:25236781 |
| 16 | Rose | aurora | **LIVE-FUNDED** | high | $118,808 | $118,820 | $0.120M | aurora: `0xc90dB0d8713414d78523436dC347419164544A3f`; aurora: `0xe23d2289FBca7De725DC21a13fC096787A85e16F`; Rose pools + VASE garden; Rose staking (stROSE) | aurora:219514157 |
| 17 | Nuri CL | scroll | **LIVE-FUNDED** | high | $116,431 | $116,675 | $0.125M | scroll: `0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42`; Nuri CL factory (UniV3) (95 pools) | scroll:35337420 |
| 18 | MonoSwap V3 | blast | **LIVE-FUNDED** | high | $112,556 | $112,688 | $0.119M | blast: `0x48d0F09710794313f33619c95147F34458BF7C3b`; MonoSwap V3 factory (Blast) (61 pools) | blast:41452198 |
| 19 | MinMax Finance | iotex | **LIVE-FUNDED** | high | $111,352 | $111,026 | $0.112M | iotex: `0x89963FCD25Cd3b369A2e0642521BCA7Cf0B9d547`; MinMax pools (registry) | iotex:53270907 |
| 20 | Orbit Protocol | blast | **LIVE-FUNDED** | medium | $93,706 | $612,818 | $0.658M | blast: `0x1E18C3cb491D908241D0db14b081B51be7B6e652`; blast: `0x273683CA19D9CF827628EE216E4a9604EfB077A3`; Orbit comptroller 1 (6 mkts); Orbit comptroller 2 (3 mkts); Orbit comptroller 3 (9 mkts) | blast:41452198 |
| 21 | EddyFinance AMM | zeta | **LIVE-FUNDED** | high | $85,707 | $91,733 | $0.102M | zeta: `0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c`; EddyFinance AMM factory (ZetaChain) (42 pairs) | zeta:19415749 |
| 22 | Eklipse Finance | kaia | **LIVE-FUNDED** | high | $80,359 | $49,457 | $0.338M | kaia: `0x4F5d9F3b17988aA047e6F1Bc511fEc0BF25691f4`; kaia: `0xD067C3b871ee9E07BA4205A8F96c182baBBA6c58`; Eklipse vaults; Eklipse staking (EKL); Eklipse pool2 LPs | kaia:229512567 |
| 23 | ReactorFusion | era,telos | **LIVE-FUNDED** | medium | $78,785 | $404,202 | $0.299M | telos: `0x19646a04BfDcf3553Adc8fAAf8B16D76EC41E494`; era: `0x23848c28Af1C3AA7B999fA57e6b6E8599C17F3f2`; ReactorFusion comptroller (Telos) (4 mkts); ReactorFusion comptroller (zkSync Era) (6 mkts) | era:72430519, telos:493385565 |
| 24 | LeetSwap | base,canto,linea,manta,op_bnb,polygon_zkevm,scroll,shibarium | **LIVE-FUNDED (partial)** | medium | $49,441 | $177,405 | $0.187M | polygon_zkevm: `0xcE87E0960f4e2702f4bFFE277655E993Ae720e84`; canto: `0x116e8a41E8B0A5A87058AF110C0Ddd55a0ed82B7`; LeetSwap factory (Polygon zkEVM) (9 pairs); LeetSwap factory (Linea) (98 pairs); LeetSwap factor | base:52463761, linea:32291245, manta:9749290, op_bnb:194399685, polygon_zkevm:33 |
| 25 | Pala | kaia | **LIVE-FUNDED** | medium | $41,651 | $400,740 | $0.346M | kaia: `0x2B16648ddD1559fc86e0c0617213Ab5dd2Ea01B9`; Pala viewer (poolInfos) (89 pools) | kaia:229512567 |
| 26 | LuigiSwap | op_bnb,scroll | **DRAINED** | medium | $571 | $336,872 | $0.346M | op_bnb: `0x0dAe6d22182c20AB9150a4DCB3160591Dc41027a`; scroll: `0x0dAe6d22182c20AB9150a4DCB3160591Dc41027a`; LuigiSwap factory (opBNB) (48 pairs); LuigiSwap factory (Scroll) (21 pairs) | op_bnb:194388039, scroll:35337420 |
| 27 | SatoshiCoreSwap | core | **DRAINED** | medium | $0 | $348,782 ⚠stale | $0.349M | core: `0x8f5c03a1c86bf79ae0baC0D72E75aee662083e26`; SatoshiCoreSwap factory (CORE) (19 pairs) | core:39468359 |
| 28 | Prism DEX | megaeth | **DRAINED** | medium | $0 | $119,928 ⚠stale | $0.120M | megaeth: `0x1adb8f973373505bb206e0e5d87af8fb1f5514ef`; Prism factory (MegaETH) | megaeth:32005524 |
| 29 | Kleva Farm | kaia | **UNREACHABLE (addresses unresolved)** | low | $0 | $783,812 ⚠stale | $0.784M | kaia: `0xa691c5891d8a98109663d07bcf3ed8d3edef820a`; Kleva klayPool vault (probe) | kaia:229512567 |

Notes on classification:

- `LIVE-FUNDED` = on-chain custody ≥ $1k today (all listed contracts read at the recorded blocks).
- `DRAINED` = contracts exist but hold < $1k of priced assets (or only junk/airdrop tokens).
- `UNREACHABLE` = no working public RPC / indexer for the chain, or no custody contract could be resolved.
- `(partial)` = some chains/targets failed and were skipped (e.g. dead chain in a multi-chain protocol); the live $ covers the reachable part.

## 4. Rows where DefiLlama and on-chain disagree (important)

| Protocol | DefiLlama today | Live on-chain | Explanation |
|---|---|---|---|
| AbstraDEX | $432,930 | $214,201 | DL WOKB (3,421) is ~2x the directly-read on-chain balance (1,706); same ~2x pattern as LeetSwap opBNB/Manta (DL adapter artefact). |
| Nile CL | $351,152 | $144,257 | DL includes $206k of the **RUSTY memecoin** (996M tokens) at DL's internal price; our priced-token total excludes it (amounts recorded). |
| LFGSwap EthereumPoW | $311,068 | $120,091 | All 1,581 pairs scanned: VVXEN 23.7T tokens ($115k) + USDT/WETHW; DL shows 58.4T VVXEN ($290k) — stale. |
| Orbit Protocol | $612,818 | $93,706 | DL counts deposits (cash + borrows); on-chain **cash** is $93.7k with $519k borrows outstanding. Markets are flagged `isInsolvent` in DL's own registry. Custody = cash. |
| ReactorFusion | $404,202 | $78,785 | Same metric gap: DL counts deposits; on-chain cash is $78.8k (zkSync Era) + $0.4k (Telos), with $114k borrowed. Custody = cash. |
| LeetSwap | $177,405 | $49,441 | Full pair scans (incl. all 4,498 Base pairs) give $49k; DL per-chain values are ~2x the directly-read balances on opBNB/Manta and not reproducible on Base ($232 live vs DL $76.8k). DL likely stale/double-counting. |
| Pala | $400,740 | $41,651 | DL values the pools with the protocol's **internal viewer oracle** (prices at/above par); the market prices of Orbit-bridge assets are far below (oUSDT $0.11, oUSDC $0.30). Market-priced custody = $41.7k; token amounts are recorded in results.json. |
| LuigiSwap | $336,872 | $571 | Pools hold 0.6 WBNB live (verified with `cast` on the top pair); DL $285k (opBNB) not reproducible — carried-forward from a failing adapter. |
| SatoshiCoreSwap | $348,782 | $0 | DL timestamp frozen at 2023-10-12; all 19 pairs hold ~$0 (only junk tokens). |
| Prism DEX | $119,928 | $0 | Shut down 2026-09-09 (DL hallmark); pools empty on-chain. |
| Kleva Farm | $783,812 | $0 | DL frozen since 2025-03-28; adapter source (`kleva.io/static/data.json`) dead; custody addresses not re-derivable (probe of the one known vault = $0). |

Also note: **Kleva Farm** (DL $784k) and **SatoshiCoreSwap** (DL $349k) have *frozen* DefiLlama timestamps (2025-03-28 and 2023-10-12) — the watchlist's own `stale` column flags them; on-chain results above supersede them. Kleva's adapter data source (`kleva.io/static/data.json`) is dead, so its vault addresses could not be re-derived (marked UNREACHABLE/unknown in the table).

## 5. Phase-2 shortlist (funded, not covered)

| Rank | Protocol | Chain(s) | Live $ | One-line reason |
|---|---|---|---|---|
| 1 | Ra Exchange | fraxtal | $837,929 | largest live CL+stableswap DEX on Fraxtal; all pools still funded |
| 2 | Powercity Flex Protocol | pulse | $730,044 | Liquity fork with HEX collateral + FLEX farms live on Pulse; custody verified (TroveManager/ActivePool) |
| 3 | Splice Finance | blast,mode | $484,393 | Pendle-style PT/SY markets live on Mode+Blast; SY claims verified (supply × exchangeRate) |
| 4 | Swapr V3 | xdai | $375,439 | live custody verified on-chain at recorded blocks |
| 5 | Nile Legacy | linea | $355,124 | Linea V2 AMM + staking still funded; cAMM stable pools included |
| 6 | Mobius Money | celo | $234,206 | live custody verified on-chain at recorded blocks |
| 7 | savmSwap | prom,svm | $233,736 | live custody verified on-chain at recorded blocks |
| 8 | FlareBank | flare | $222,024 | live custody verified on-chain at recorded blocks |
| 9 | AbstraDEX | blast,cronos_zkevm,morph,xlayer,zeta,zkfair | $214,201 | UniV2 fork with live pools on X Layer (dominant) + Morph/Cronos zkEVM/Zeta |
| 10 | Cog | scroll | $193,324 | live custody verified on-chain at recorded blocks |
| 11 | Vessel Finance | scroll | $193,046 | live custody verified on-chain at recorded blocks |
| 12 | Capybara Dexs | kaia | $167,342 | live custody verified on-chain at recorded blocks |
| 13 | AuroraSwap | aurora | $160,077 | live custody verified on-chain at recorded blocks |
| 14 | Nile CL | linea | $144,257 | live custody verified on-chain at recorded blocks |
| 15 | LFGSwap EthereumPoW | ethpow | $120,091 | live custody verified on-chain at recorded blocks |
| 16 | Rose | aurora | $118,808 | live custody verified on-chain at recorded blocks |
| 17 | Nuri CL | scroll | $116,431 | live custody verified on-chain at recorded blocks |
| 18 | MonoSwap V3 | blast | $112,556 | live custody verified on-chain at recorded blocks |
| 19 | MinMax Finance | iotex | $111,352 | live custody verified on-chain at recorded blocks |
| 20 | Orbit Protocol | blast | $93,706 | Compound fork on Blast flagged insolvent by DefiLlama; cash vs borrows measured |
| 21 | EddyFinance AMM | zeta | $85,707 | live custody verified on-chain at recorded blocks |
| 22 | Eklipse Finance | kaia | $80,359 | live custody verified on-chain at recorded blocks |
| 23 | ReactorFusion | era,telos | $78,785 | Compound fork on zkSync Era + Telos; cash verified, large borrows outstanding |
| 24 | LeetSwap | base,canto,linea,manta,op_bnb,polygon_zkevm,scroll,shibarium | $49,441 | live custody verified on-chain at recorded blocks |
| 25 | Pala | kaia | $41,651 | live custody verified on-chain at recorded blocks |

## 5b. Evidence detail for the top-10 funded rows

**Ra Exchange** — live $837,929 at blocks fraxtal #42451737:
  - Ra CL factory (UniV3) [fraxtal], 112 pools: `0xfc00000000`… 125.7 = $313,688; `0xfc00000000`… 2.107e+05 = $208,854; `0xfc00000000`… 44.05 = $109,930; `0xeb466342c4`… 1.004e+05 = $100,325
  - Ra stable AMM factory (crAMM) [fraxtal], 63 pairs: `0xfc00000000`… 0.4433 = $1,106; `0xfc00000000`… 1,106 = $1,096; `0xfc00000000`… 2,294 = $769; `0xfc00000000`… 0.3079 = $768

**Powercity Flex Protocol** — live $730,044 at blocks pulse #27769393:
  - Flex TroveManager (HEX collateral) [pulse]: `0x2b591e99af`… 2.659e+08 = $645,732
  - Flex staking (FLEX) [pulse]: `0x9c6fa17d92`… 8.018e+07 = $60,674
  - Flex staking LPs [pulse]: 

**Splice Finance** — live $484,393 at blocks blast #41452198, mode #45773340:
  - Splice factory (Mode) [mode], 16 markets: `0x2416092f14`… 6.317 = $17,106; `0x2416092f14`… 6.202 = $16,795; `0x04c0599ae5`… 1.535 = $4,238; `0x04c0599ae5`… 1.421 = $3,923
  - Splice factory 1 (Blast) [blast], 4 markets: `0x4300000000`… 3.412e+05 = $336,882; `0x4300000000`… 40.21 = $100,438; `0x4300000000`… 0.001066 = $3
  - Splice factory 2 (Blast) [blast], 3 markets: `0x4300000000`… 1.434e+04 = $14,158; `0x4300000000`… 2.522 = $6,298; `0x4300000000`… 2,849 = $2,813

**Swapr V3** — live $375,439 at blocks xdai #48699991:
  - Swapr V3 Algebra factory (Gnosis) [xdai], 2865 pools: `0x6a023ccd1f`… 85.62 = $213,911; `0x6c76971f98`… 13.11 = $40,801; `0xe91d153e0b`… 1.772e+04 = $17,717; `0x8ccd277cc6`… 1.706e+07 = $17,036

**Nile Legacy** — live $355,124 at blocks linea #32290939:
  - Nile V2 factory (cAMM) [linea], 133 pairs: `0xe5d7c2a44f`… 90.28 = $225,476; `0x2416092f14`… 44.19 = $119,652; `0xe5d7c2a44f`… 1.965 = $4,909; `0xe5d7c2a44f`… 0.7119 = $1,778
  - Nile staking (NILE) [linea]: 

**Mobius Money** — live $234,206 at blocks celo #79814420:
  - Mobius stableswap pools (registry tokensAndOwners) [celo]: `0x90ca507a5d`… 5.18e+04 = $51,789; `0x765de81684`… 3.276e+04 = $32,730; `0x765de81684`… 2.444e+04 = $24,413; `0xcd7d7ff647`… 2.171e+04 = $21,706

**savmSwap** — live $233,736 at blocks prom #10059509:
  - savmSwap factory (Prom) [prom], 90 pairs: `0x7e942605b5`… 7.638e+04 = $76,313; `0x04a21a38d5`… 1.458e+04 = $76,093; `0x04a21a38d5`… 8,674 = $45,259; `0x04a21a38d5`… 3,276 = $17,095

**FlareBank** — live $222,024 at blocks flare #71847935:
  - FlareBank owners (WFLR) [flare]: `0x1d80c49bbb`… 1.842e+07 = $127,549; `0x1d80c49bbb`… 1.364e+07 = $94,475

**AbstraDEX** — live $214,201 at blocks blast #41452198, cronos_zkevm #2671971, morph #28121408, xlayer #72945851, zeta #19415749, zkfair #29987090:
  - AbstraDEX factory (X Layer) [xlayer], 517 pairs: `0xe538905cf8`… 812.9 = $100,064; `0xe538905cf8`… 652.3 = $80,297; `0xe538905cf8`… 103.1 = $12,693; `0xe538905cf8`… 37.91 = $4,666
  - AbstraDEX factory (ZKFair) [zkfair], 3 pairs: `0xd33db7ec50`… 0.9482 = $1
  - AbstraDEX factory (ZetaChain) [zeta], 17 pairs: `0x91d4f0d540`… 51.05 = $51; `0xd97b1de361`… 0.01434 = $25; `0x5f0b1a8274`… 66.14 = $3; `0x48f80608b6`… 0.005049 = $3

**Cog** — live $193,324 at blocks scroll #35337420:
  - Cog factory 1 [scroll], 93 pairs: `0x5300000000`… 56.12 = $140,199; `0x06efdbff2a`… 2,470 = $2,469; `0x06efdbff2a`… 2,354 = $2,354; `0xf610a9dfb7`… 0.4295 = $1,338
  - Cog factory 2 [scroll], 16 pairs: `0x06efdbff2a`… 2.931e+04 = $29,299; `0xf55bec9caf`… 5,036 = $5,031; `0xf610a9dfb7`… 1.584 = $4,935; `0x5300000000`… 0.3964 = $990

## 6. Unreachable / dead

- **Kleva Farm** (kaia): custody addresses could not be re-derived: the adapter's data source (kleva.io/static/data.json) is dead and the protocol has no public registry entry; the single probe address held $0. DefiLlama's $784k is frozen since 2025-03-28.

Chain-level failures inside otherwise-live rows (excluded from their totals):
- savmSwap · svm: svm blockNumber failed: svm rpc failed: eth_blockNumber: <urlopen error [Errno -2] Name or service not known>
- LeetSwap · canto: canto blockNumber failed: canto rpc failed: eth_blockNumber: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify fa

## 7. Methodology, caveats, limitations

- **Read-only.** No transactions were signed or sent. All data comes from `eth_call`, `eth_getLogs`, `eth_getBalance`, `eth_getCode` on keyless public RPCs and DefiLlama's public price API.
- **Blocks.** Every chain's latest block at read time is recorded per row in the table and in `ci-out/results.json` (per-contract detail incl. token amounts and the exact contract address each balance was read from).
- **Pricing.** USD values use DefiLlama token prices. Obscure tokens without a price contribute $0 (amounts still recorded). Stablecoin depegs are reflected at market (e.g. Orbit-bridge oUSDT/oUSDC on Kaia).
- **Double counting.** For protocols with staking/farm contracts, LP-token deposits are valued pro-rata at pair reserves; the per-row total adds staking on top of pool reserves only where the registry reports them as separate categories (matching DefiLlama's split). Pool reserves themselves are counted once.
- **Coverage.** Custody contracts come from the *current* public adapter/registry definitions. If a team deployed unlisted contracts (or migrated without updating DefiLlama), those are not counted; Phase-2 should re-derive from events where material.
- **Not a security assessment.** No exploitability, admin-key or governance analysis was performed here.

## 8. Files

- `ci/plan.json` — the exact target set: 29 protocols, 59 targets, per-chain keyless RPCs.
- `ci/enumerate.py` — the enumeration engine (run on GitHub Actions).
- `ci/run.sh` — CI entrypoint; run URL above.
- `ci-out/results.json` — full per-target evidence (contracts, counts, token amounts, USD, blocks, errors).
- `ci-out/summary.csv` — flat per-target CSV.
- `analysis/llama_meta.json` — DefiLlama protocol metadata/current TVL/freshness at screen time.
- `analysis/final_table.json` — classified per-row results used for this README.
- `analysis/report.py`, `analysis/build_readme.py`, `analysis/make_summary.py` — classification/table generators.
- `analysis/merge_deep.py`, `analysis/lfgswap_missing_pairs.json` — deep-pass merge + local top-up of the last 203 LFGSwap pairs.
- `ci-log-full.txt`, `ci-log-deep.txt` — downloaded GitHub Actions logs for both runs.
- `summary.json` — machine-readable summary for the orchestrator.

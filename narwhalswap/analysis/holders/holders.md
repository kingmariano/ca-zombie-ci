# Narwhalswap (BSC) — Holder Distribution Report

- Block: **127220307** (BSC), generated 2026-10-12 13:39:08 UTC
- Chain: BSC (chainId 56); all balances are direct `balanceOf` reads at the block above, unless noted.
- Full machine-readable data: `holders.json`; raw sources in `raw_goldrush/`; verification scripts in this folder.

## Method & caveats
- GoldRush `token_holders` lists exclude some address classes (burn pools, protocol contracts and some flagged wallets) — they were only used as candidate sources; all final balances are direct on-chain balanceOf reads.
- GoldRush `events/address` API can drop the zero-address topic and occasionally whole logs; event reconstruction is used only to discover candidate holders, never for final balances.
- NAR accounting: balances() sum = totalSupply + `_totalBurnToken` because the contract keeps burned amounts credited at the 0x7777 burn pool balance while reducing totalSupply.

## Key findings (hand-written summary)

1. **NAR is a taxed token whose "burn" is a sink EOA.** Every NAR transfer takes 2.5% `_burnRate` burn + 2.5% `_rewardRate` reward. Burned NAR is credited to `_burnPool = 0x7777…7777` while `totalSupply` is reduced — so cumulative burned amounts (6,852,210.07 NAR) still show as a balance at 0x7777. That address is an **EOA (no code)** and has **never sent NAR, rNLP5 or rNLP6 out** (0 outgoing Transfer events across the complete event histories). 0x7777 currently sits on **11,098,868.48 NAR (80.06% of totalSupply)**, **437,408.15 rNLP5 (99.49%)** and **2,807,031.59 rNLP6 (99.9996%)**. If the key to 0x7777 ever existed and was retained, those balances are spendable — nothing on-chain proves key destruction.
2. **The NAR/WBNB liquidity is mostly locked in a project locker — but the locker has an owner-callable `withdraw()`.** Pair 0xb6b0ba4e holds 5,444,067.42 NAR + 181.45 WBNB (LP supply 25,004.55 NLP). **20,099.44 NLP (80.4%) is held by contract 0x07f1b50d…, a project locker whose bytecode exposes `withdraw()` (0x3ccfd60b), `unlockTime()` = 1605109215 = 2020-11-11 (long passed) and `owner()` = governance EOA.** The unlock date is years in the past and the LP was never withdrawn; the governance EOA can withdraw at any time. The NAR/WBNB farm (gen 5, `0x1D227F7e…`) currently holds 2,243.79 NLP staked by users.
3. **rNLP "burn" is also a sink, not a burn.** Farms (NarwhalRewardV2, 14 generations) mint rNLP 1:1 on stake and, on withdraw, **transfer** the rNLP to `burnPool` 0x7777 (no `_burn`), so rNLP supply never decreases. Result: ~99.5%/99.9996% of rNLP5/rNLP6 dumped at the EOA sink. 61 rNLP5 holders and 16 rNLP6 holders remain (all listed with farm `balanceOf`, `userInfo` and share% in this report; rNLP5 and rNLP6 reconcile to totalSupply **exactly** via direct on-chain reads).
4. **THUGS destroyed most of itself into vanity addresses.** 0x…dEaD holds **440,583.52 THUGS (67.7% of supply)** (manual burns by holders/team; dead has never sent anything out), and the original **BscSwap launch pair 0x71c1b630… still holds 185,305.67 THUGS + 3,688.28 WBNB (28.5% of supply; its 21,778 LP tokens are widely held and were never pulled)** — the lauch liquidity was never recovered. The old Pancake v1 THUGS/WBNB pair holds another 3,821.09 THUGS + 50.40 WBNB. Sell-side burn mechanics (dynamic 5–50%, with 49% of the burn routed via a timelock vault to `0xfd98d6de…`) cut supply to 650,510.47.
5. **A NAR "operation / wash" cluster exists.** Contract **0xf7a36c87… holds 1,333,817.14 NAR (9.62%)**, is extremely high-throughput (lifetime inflows ≈ 31.1M NAR, outflows ≈ 29.6M; 5.8k in / 39.7k out transfer events), and was seeded from `_rewardPool` (6.48M NAR) and governance (3.3M NAR). Co-moving cluster members (0x63c6d16d…, 0x72ac0dac…, 0x58638c8d…, 0xb187a027…, 0x30f315a4…, …) all net to **zero** today — consistent with volume/wash farming around the taxed NAR token. Its getters resemble a mine/farm (`_periodFinish()` ≈ 2026-10-14, `_rewardRate()` ≈ 0.00072 NAR/s), so part of its NAR may be an active reward reserve.
6. **Fees & team**: `_rewardPool` EOA (0xa02f5f32…) accumulated 6,852,210.07 NAR of reward fees and forwarded 6.48M to the cluster contract above; it holds 2,530.35 NAR now. Team wallet `0x507bdd06…` holds 87,117.03 NAR (0.63%). The original `_teamWallet` (0x00470220…) is empty. Governance 0xb104ae8b… (EOA) owns all rNLPs, farms and the locker.
7. **Old LP positions never unwound**: (a) WBNB/THUGS LP — 93% (254.40/273.57) is held by a vintage 2020 BSC farming EOA (0x4d710603…); (b) WBNB/BUSD LP — 81.1% is held by the dead gen-1 farm 0xbb38f755 (231.53/285.47); (c) NLP — the ~80% locker above.
8. **EIP-7702 delegation EOAs** appear among holders: 0x6bc76d22… (rNLP5), 0xbde4d38e… (rNLP6), 0x36de6d01… and 0x09dc113b… (NAR), 0x9e51bb68… and 0x990c3679… (THUGS). These are EOAs whose code field is a 23-byte `0xef0100…` delegation designator.
9. **Reconciliation** (direct on-chain reads vs canonical supply):
   - rNLP5, rNLP6, LP_WBNBBUSD, LP_WBNBTHUGS: **exact to the wei** (LP tokens only miss the pair-locked 1000-wei MINIMUM_LIQUIDITY at 0x0).
   - NLP: −14.888875 (0.06%) unresolved.
   - THUGS: −794.15 (0.12%) unresolved.
   - NAR: −66,427.69 (0.32% of the 20,715,167.96 "minted" total). NAR balances sum = `totalSupply + _totalBurnToken` because burned amounts remain credited at 0x7777. Residuals are attributed to indexer gaps (dropped event logs / address exclusions) for dust and inactive addresses — all material holders are directly verified; spot checks of every unverified ≥1,000-NAR candidate returned zero on-chain.

## NAR (NAR) — `0xa1303e6199b319a891b79685f0537d289af1fc83`

totalSupply: **13,862,957.8896** | holders found: 4065 | holders sum: **20,648,740.2673** | expected sum: 20,715,167.9555 | reconciliation delta: -66,427.688186

> Note: for NAR the balances sum is compared against `totalSupply + _totalBurnToken` (20,715,167.96), because burned amounts remain credited to the 0x7777 burn pool while `totalSupply` is reduced.

| # | holder | balance | % supply | type | note |
|---|--------|--------:|---------:|------|------|
| 1 | `0x7777777777777777777777777777777777777777` | 11,098,868.480901 | 80.0613% | EOA | burn pool — NAR `_burnPool` (hardcoded in token) and rNLP destruction sink (withdrawn rNLP sent here). EOA (no code). |
| 2 | `0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2` | 5,444,067.418572 | 39.2706% | contract | NAR/WBNB pair on NarwhalswapFactory (this address is also the NLP LP token). |
| 3 | `0xf7a36c87c3a8909949638120f23cd721bf572032` | 1,333,817.135951 | 9.6214% | contract | Large NAR-holding contract (23,244 bytes) — identity TBD (possibly a presale/ILO or vesting contract). |
| 4 | `0x6bb2a9c00f293cd4ec94d5e78db7f71aa9182e45` | 605,115.196793 | 4.3650% | EOA |  |
| 5 | `0x0da8ebc508b294236ea0e8af36e530354a19e98c` | 542,552.510724 | 3.9137% | EOA |  |
| 6 | `0x0f5667ec8eb4ea84e8ccf8777a7019def9541e05` | 218,385.063369 | 1.5753% | EOA |  |
| 7 | `0x1d227f7e283d653a60f94d2350cab7a49bb85c6f` | 204,706.947406 | 1.4766% | contract | Farm gen 5 (NarwhalRewardV2) — LP=NAR/WBNB, shares=rNLP5. `nar_balance` = unclaimed NAR rewards. |
| 8 | `0x6658cd8591285775fd31d525fc2b0f3b1dde9b47` | 128,605.661938 | 0.9277% | contract | NAR/BTCB pair on NarwhalswapFactory (NAR reserve). |
| 9 | `0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9` | 87,117.031251 | 0.6284% | EOA | Team wallet used as `teamWallet` in farms (EOA). |
| 10 | `0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107` | 73,665.161429 | 0.5314% | contract | Farm (NarwhalRewardV2) — LP=NAR/BTCB. |
| 11 | `0x956bcf131b69fb0c5ae38fca14af7aa0ecf07f65` | 62,720.550736 | 0.4524% | EOA |  |
| 12 | `0x6da9ee0c0571b63e38950d1e12e835d5343f601b` | 46,039.761308 | 0.3321% | contract | Farm gen 6 (NarwhalRewardV2) — LP=WBNB/BUSD, shares=rNLP6. |
| 13 | `0xd9116827b463ab5886262a6b705c858dcb75a32a` | 40,000.000000 | 0.2885% | EOA |  |
| 14 | `0x86354ff70c25b09fef4e5d1d4fd63a12739653b0` | 29,597.545593 | 0.2135% | EOA |  |
| 15 | `0xd2c4541b73cc7189ddda45e93d113bc59cac0e27` | 26,730.795321 | 0.1928% | EOA |  |
| 16 | `0xb6c9b20253a4bdc65d1fdc6f4ae04f57f6523915` | 26,420.145835 | 0.1906% | contract | Farm (NarwhalRewardV2) — LP=BUSD/WBNB pair 0x8e68f1ad… |
| 17 | `0xcf889a0902859662c17dc895abb7af49ee28a013` | 26,369.195632 | 0.1902% | contract | Farm (NarwhalRewardV2) — LP=USDT/WBNB pair 0xb35513a1… |
| 18 | `0x48465562007aa0e2953852ccdc98c24624e6f6a4` | 22,827.944717 | 0.1647% | EOA |  |
| 19 | `0x09dc113b466285e37f37a8ad467246c04addab8d` | 20,983.503235 | 0.1514% | contract |  |
| 20 | `0xfb4bcdddc17ae3e60aee0dd09754c98882e992b0` | 20,687.526409 | 0.1492% | EOA |  |
| 21 | `0xbe85812237741d75f81aebf1d9af52d544542168` | 19,693.970708 | 0.1421% | contract | Farm (NarwhalRewardV2) — LP=NAR/WBNB (rNLP=40572a…). |
| 22 | `0x8f68b10eafdad01f6676d66c1aede8aa1beacc42` | 19,598.632673 | 0.1414% | EOA |  |
| 23 | `0xd0226f497f9b8a8fac0c3b41a46c7c133e12b4a2` | 17,332.406641 | 0.1250% | EOA |  |
| 24 | `0x36de6d01ab563d3e0fd7661c75dce8202aa82649` | 16,358.391260 | 0.1180% | contract | EOA with EIP-7702 delegation holding NAR. |
| 25 | `0x8dc7111eeef182d76291d0598d0b450b444218fc` | 14,128.098170 | 0.1019% | EOA |  |
| 26 | `0x80337667ebef6a7a9e32b8f4b2bccebf0f91b55f` | 13,447.419184 | 0.0970% | ? |  |
| 27 | `0xc88e95f2dffefd365ebcd35043003da3b5f77621` | 13,268.788922 | 0.0957% | ? |  |
| 28 | `0xcedae2a1a9772dddc301f3778bfa603584b97a99` | 11,261.492500 | 0.0812% | ? |  |
| 29 | `0x7cd953064436b2f7c4c6774c607f9931553ed1e4` | 11,016.897328 | 0.0795% | ? |  |
| 30 | `0x22abfddcf3119f6396ab2f8dd1b05b34433a726e` | 11,001.621992 | 0.0794% | EOA |  |
| 31 | `0x3dfb186e8ce513f321232098dd551e22886c1051` | 8,113.726205 | 0.0585% | contract | Farm (NarwhalRewardV2) — LP=NAR/BTCB. |
| 32 | `0x12b0c00fe6f076c7cad0ea31799278dd9a26b513` | 7,822.303147 | 0.0564% | EOA |  |
| 33 | `0xc87cc3c0f62e21eaf5d52b5b34fb76810a384e50` | 7,483.026644 | 0.0540% | ? |  |
| 34 | `0x3e1ec33e4194b7eae6eab106941517ee3c46ab82` | 7,152.737612 | 0.0516% | EOA |  |
| 35 | `0x654716efe3b14a3b7fe0eb1bcf289ef2d6ff1c67` | 7,022.091317 | 0.0507% | ? |  |
| 36 | `0xa2471539829dcf78c87c8ae2b1f0206bb5fa03f7` | 6,858.497783 | 0.0495% | ? |  |
| 37 | `0xfe97962599c472661e30c742877f3f8e8016ee4c` | 6,306.794680 | 0.0455% | ? |  |
| 38 | `0xa4287cfcff810f9941cb7a200b72241a9b9824f6` | 6,140.716671 | 0.0443% | ? |  |
| 39 | `0x19397b71d1c62ac162c6717e2be72b819e08357f` | 6,062.646501 | 0.0437% | EOA |  |
| 40 | `0xcc94b67a88f5fc35ed7311b3a82ed6a51cbf6221` | 5,776.570000 | 0.0417% | ? |  |
| … | *4025 more holders* | | | | full list in holders.json |

## NLP (NLP_NARWBNB) — `0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2`

totalSupply: **25,004.5519** | holders found: 241 | holders sum: **24,989.6630** | expected sum: 25,004.5519 | reconciliation delta: -14.888875

| # | holder | balance | % supply | type | note |
|---|--------|--------:|---------:|------|------|
| 1 | `0x07f1b50d5ae24ec41aa7269d65a5e23e8401542a` | 20,099.440291 | 80.3831% | contract | NLP liquidity-locker contract (own `unlockTime()` = 1605109215 = 2020-11-11, owner = governance). Still holds LP long af |
| 2 | `0x1d227f7e283d653a60f94d2350cab7a49bb85c6f` | 2,243.792235 | 8.9735% | contract | Farm gen 5 (NarwhalRewardV2) — LP=NAR/WBNB, shares=rNLP5. `nar_balance` = unclaimed NAR rewards. |
| 3 | `0xbe85812237741d75f81aebf1d9af52d544542168` | 1,291.976394 | 5.1670% | contract | Farm (NarwhalRewardV2) — LP=NAR/WBNB (rNLP=40572a…). |
| 4 | `0x242fb607f7047d0d9df5df592d2ab8318c222e94` | 560.895821 | 2.2432% | EOA | NLP holder (EOA, ~2.2% of NLP). |
| 5 | `0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835` | 297.156674 | 1.1884% | contract | Farm (NarwhalRewardV2) — LP=NAR/WBNB (rNLP=e412c9…). |
| 6 | `0x72b863f45e85f305fc7bbd7519fba6df42b54a5f` | 81.920271 | 0.3276% | EOA |  |
| 7 | `0x7e86f91d7e853201ccbd0c107935a32266d95306` | 73.035102 | 0.2921% | EOA |  |
| 8 | `0xec15fdb80f7edf1fc969b3d8193ed2f64a73b339` | 66.473657 | 0.2658% | EOA |  |
| 9 | `0xcc2753c56f83427f9a4a7ea671b561e8553e9a53` | 60.798000 | 0.2431% | EOA |  |
| 10 | `0x64fef41e09e1daaf78b4ab36aa98cc543f1c0532` | 36.169337 | 0.1447% | EOA |  |
| 11 | `0xc13151cfb55eda985382e9310915d2cd86a7047d` | 30.790887 | 0.1231% | EOA |  |
| 12 | `0x8850f19fd6482538c00c45f7d2489a1f788475c8` | 21.452698 | 0.0858% | EOA |  |
| 13 | `0x00c2cdfd0ccf699632d87bac5802e9136f9989e2` | 21.097238 | 0.0844% | contract |  |
| 14 | `0x42063b302c3c3f9be87dd132ef4d0bac6ddacd8c` | 12.818604 | 0.0513% | EOA |  |
| 15 | `0x40f94ed436de8b5df7dd660b7821500a0d16591f` | 12.220245 | 0.0489% | EOA |  |
| 16 | `0x9ea8ac048af331c9eae42e64a7bfe660e0e5df03` | 10.249968 | 0.0410% | EOA |  |
| 17 | `0x4b13718fa2d0bb25a994db5818fc234ddcc8d3ef` | 9.209263 | 0.0368% | EOA | Largest GoldRush-listed NLP EOA (9.21 NLP). |
| 18 | `0x124f2f2515040f4a5fcee7d815b79af372708adc` | 8.469611 | 0.0339% | EOA |  |
| 19 | `0x52bbcf3efc10c5ed1ff3e1e373b3ebe9f3a861e1` | 3.588148 | 0.0143% | EOA |  |
| 20 | `0xc9319672d58a0bada08d8393c0506e3c0966af2b` | 3.545753 | 0.0142% | EOA |  |
| 21 | `0x7327a9f41d734a62be857c30b10907e8aff518c5` | 3.462747 | 0.0138% | EOA |  |
| 22 | `0x2dd21220ecbdf350d77833f33c64200d0a4aace8` | 2.646715 | 0.0106% | EOA |  |
| 23 | `0x30367d25b10cc778bea25a2a6c68ab8a56ab4ff5` | 2.076739 | 0.0083% | EOA |  |
| 24 | `0x9816a66bfda289a2b37ccf8e6f985bb543739504` | 1.992955 | 0.0080% | EOA |  |
| 25 | `0x283b7fabfe6f8d41dca3a2b63255261998ba4d13` | 1.788786 | 0.0072% | EOA |  |
| 26 | `0xb62ba2f81e88aeb67f42a2391e579e977c898c38` | 1.663446 | 0.0067% | EOA |  |
| 27 | `0x12f99265d529e0453d502124e29573d40e8c07b5` | 1.620360 | 0.0065% | EOA |  |
| 28 | `0xb4321dc14c28d67ca61ae6355462329f2c1f4404` | 1.612604 | 0.0064% | EOA |  |
| 29 | `0x43a0251c87fd9ef1ae65b5472bf98c7cdc3bb867` | 1.523845 | 0.0061% | EOA |  |
| 30 | `0x497e1520e2a4d17a0f3ef8475cfb886ecdb7df60` | 1.319810 | 0.0053% | EOA |  |
| … | *211 more holders* | | | | full list in holders.json |

## NLP (LP_WBNBTHUGS) — `0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957`

totalSupply: **273.5682** | holders found: 10 | holders sum: **273.5682** | expected sum: 273.5682 | reconciliation delta: -0.000000

| # | holder | balance | % supply | type | note |
|---|--------|--------:|---------:|------|------|
| 1 | `0x4d710603238427ae805b980bab8261624f5260c7` | 254.403209 | 92.9944% | EOA | Largest WBNB/THUGS LP holder (EOA) — ~93% of that LP supply. |
| 2 | `0xe99140fc04e458ac58d47c29c0649bcc3914dc0a` | 18.101030 | 6.6166% | EOA |  |
| 3 | `0xb752f0cb591ecfb1c5058a93e1332f066bf38473` | 1.058699 | 0.3870% | contract | WBNB/THUGS LP holder — contract (8,450 bytes, likely a staking/mine contract). |
| 4 | `0x7f9d39de53a3036463146e91e921cc9fbfcb2de4` | 0.004997 | 0.0018% | EOA |  |
| 5 | `0x740d618e92484b6f142e49b3644b26cc370232be` | 0.000161 | 0.0001% | contract |  |
| 6 | `0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9` | 0.000114 | 0.0000% | contract | NarwhalCollecter contract (factory `feeTo`). |
| 7 | `0x7b8056527faf16ff0bf2742a79fe3b1c9a27fd7e` | 0.000004 | 0.0000% | contract |  |
| 8 | `0x8b1bbfaf50551d8427bc24beecd3406cdcef48b8` | 0.000001 | 0.0000% | contract |  |
| 9 | `0xd777329cff7012a4d6f07aff72057cd44d405d73` | 0.000000 | 0.0000% | EOA |  |
| 10 | `0xcda85d0b4579ae31c1c2100141a6a59caca0b2d0` | 0.000000 | 0.0000% | contract | WBNB/THUGS LP holder — contract (19,222 bytes). |

## NLP (LP_WBNBBUSD) — `0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3`

totalSupply: **285.4709** | holders found: 109 | holders sum: **285.4709** | expected sum: 285.4709 | reconciliation delta: -0.000000

| # | holder | balance | % supply | type | note |
|---|--------|--------:|---------:|------|------|
| 1 | `0xbb38f7551025a433f36590be85271110212655de` | 231.532210 | 81.1054% | contract | Farm (NarwhalRewardV2) — LP=WBNB/BUSD (rNLP=ee2b4f…). |
| 2 | `0xa9d5f138ba6b6ce6ed0ed2e335e76b7d2a237621` | 33.684638 | 11.7997% | EOA |  |
| 3 | `0x6da9ee0c0571b63e38950d1e12e835d5343f601b` | 11.943791 | 4.1839% | contract | Farm gen 6 (NarwhalRewardV2) — LP=WBNB/BUSD, shares=rNLP6. |
| 4 | `0x77c10a04b7d3adebe4f235d69b5c1f20cbfd2e57` | 1.493411 | 0.5231% | contract |  |
| 5 | `0xc60f8257749d0b2fb8213ef0a9ff241d2f538a5c` | 0.769902 | 0.2697% | EOA |  |
| 6 | `0x251f28593872578a5ead1574eef61154c344b0a2` | 0.607152 | 0.2127% | EOA |  |
| 7 | `0xbf99b97042a147227525309e4ec0aaf46aa16e73` | 0.527630 | 0.1848% | EOA |  |
| 8 | `0x0865bdf122c39f179db282c7e215cac94393edd2` | 0.511789 | 0.1793% | EOA |  |
| 9 | `0x112c3aa574261bd19562cf6f77d3674f139f516a` | 0.381181 | 0.1335% | EOA |  |
| 10 | `0x03df7ef2a58335004b8acf929f02d63b201d3761` | 0.289790 | 0.1015% | EOA |  |
| 11 | `0x05ecf1a4d4d09613423e148237a869e68111943a` | 0.278338 | 0.0975% | EOA |  |
| 12 | `0x97017b3f627716b1b2a62afe853b696f582b6013` | 0.274504 | 0.0962% | EOA |  |
| 13 | `0x1e183d80b2f89cc8d5bc402c1c898e2abe8e9417` | 0.231673 | 0.0812% | EOA |  |
| 14 | `0x020be4338b750b85c73e598bf468e505a8eb76ea` | 0.194411 | 0.0681% | EOA |  |
| 15 | `0x2eeacc1875243afd432c3e081d5f7fb46b3b9179` | 0.184255 | 0.0645% | EOA |  |
| 16 | `0xa3321753b3978828ed5b62a93fa415062251e56a` | 0.178113 | 0.0624% | EOA |  |
| 17 | `0x187cd087369b76d9e095895fce43861cacc4ff7e` | 0.168282 | 0.0589% | EOA |  |
| 18 | `0x186184d90ff19e5271bc570e920541ec685c9b25` | 0.131347 | 0.0460% | EOA |  |
| 19 | `0x3bcc6667afa9e0fa7b2111ee689c605f0d8320ec` | 0.125759 | 0.0441% | EOA |  |
| 20 | `0x055169b2570b9f3e1f98449630c70c7dc61f8069` | 0.104930 | 0.0368% | EOA |  |
| 21 | `0x0e5dcf6978414a3274ac77ab7cab040fad8e62a4` | 0.100996 | 0.0354% | EOA |  |
| 22 | `0xfdddfef0f1ed3c405a16750adbb4dd9bbd4ed6dc` | 0.085173 | 0.0298% | EOA |  |
| 23 | `0x7e8a215465fdf6d5748576ff475a8c13457d87c2` | 0.083294 | 0.0292% | EOA |  |
| 24 | `0xad286cf287b91719ee85d3ba5cf3da483d631dba` | 0.082735 | 0.0290% | EOA |  |
| 25 | `0x5875d55ff1c9367b46feb5af1006dabfde6943ec` | 0.082046 | 0.0287% | EOA |  |
| 26 | `0xb62ba2f81e88aeb67f42a2391e579e977c898c38` | 0.079831 | 0.0280% | EOA |  |
| 27 | `0x0a49889803c7b38fa63ba40e189cd0780263c6a8` | 0.078803 | 0.0276% | EOA |  |
| 28 | `0x017bb577836308f4632ba1ce2047516115866cba` | 0.069769 | 0.0244% | EOA |  |
| 29 | `0x0162c3d039a31849fd4409feb711540ca36f7728` | 0.066441 | 0.0233% | EOA |  |
| 30 | `0x613a4f4a7d8b9287532586c4487e18050ae692ad` | 0.060823 | 0.0213% | EOA |  |
| 31 | `0xb3eb833853b3d7b4bdad7defb1e869372a2c6767` | 0.060799 | 0.0213% | contract |  |
| 32 | `0x4f166ff2f96c529c086ba3ef79e4adc0ceca6323` | 0.059760 | 0.0209% | EOA |  |
| … | *77 more holders* | | | | full list in holders.json |

## rNLP (rNLP5) — `0x6451571cb5bee9fd575ad98506e96f3d09c66f91`

totalSupply: **439,651.9398** | holders found: 61 | holders sum: **439,651.9398** | expected sum: 439,651.9398 | reconciliation delta: 0.000000

| # | holder | balance | % supply | type | note |
|---|--------|--------:|---------:|------|------|
| 1 | `0x7777777777777777777777777777777777777777` | 437,408.147555 | 99.4896% | EOA | burn pool — NAR `_burnPool` (hardcoded in token) and rNLP destruction sink (withdrawn rNLP sent here). EOA (no code). |
| 2 | `0x0567b7665d5633903c558ceec8fe7023743333a4` | 1,240.374383 | 0.2821% | EOA |  |
| 3 | `0x6bc76d2224e6fbd45e8e910aecad1b4b15bdfb70` | 234.819042 | 0.0534% | contract | EOA with EIP-7702 delegation (code = 0xef0100…delegate). |
| 4 | `0x2aefce802c8db8c25216140cb672ef8f5b806186` | 233.893828 | 0.0532% | EOA |  |
| 5 | `0xfee9d17162d5b0cd8f2db9a8a7e5da4bacf21e72` | 131.440965 | 0.0299% | EOA |  |
| 6 | `0x25461088f2f674918a60948c96dca9dc34658739` | 99.393840 | 0.0226% | EOA |  |
| 7 | `0x8875791187aec618f1ba655872e03fea049c2ee1` | 69.420889 | 0.0158% | EOA |  |
| 8 | `0x8b19468e2d8206983585b074a9c93d28a84e4aed` | 69.182818 | 0.0157% | EOA |  |
| 9 | `0x840e20dfb9f8f3dc076865223d6ce7e84ddc8c67` | 63.441599 | 0.0144% | EOA |  |
| 10 | `0xb64790ab8d4a83fea1bc943092c7a184f95bd2ba` | 45.379659 | 0.0103% | EOA |  |
| 11 | `0xda9cb21f6b662eb972ecc8fd358a1fdab0811977` | 24.244981 | 0.0055% | EOA |  |
| 12 | `0x9ae6a213a8d6bd61274622c31ac776ab7c7c936a` | 5.160330 | 0.0012% | EOA |  |
| 13 | `0xaf2835ea331414a99bfa7cc9192e54a9f5b88b1f` | 4.949471 | 0.0011% | EOA |  |
| 14 | `0x3abf26382c10eb04f496b5e800e20ab98fbbd536` | 4.076026 | 0.0009% | EOA |  |
| 15 | `0x5381dd87f1440ba838471512bfd3954cf2a0f030` | 3.521937 | 0.0008% | EOA |  |
| … | *46 more holders* | | | | full list in holders.json |

## rNLP (rNLP6) — `0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a`

totalSupply: **2,807,043.5319** | holders found: 16 | holders sum: **2,807,043.5319** | expected sum: 2,807,043.5319 | reconciliation delta: 0.000000

| # | holder | balance | % supply | type | note |
|---|--------|--------:|---------:|------|------|
| 1 | `0x7777777777777777777777777777777777777777` | 2,807,031.588108 | 99.9996% | EOA | burn pool — NAR `_burnPool` (hardcoded in token) and rNLP destruction sink (withdrawn rNLP sent here). EOA (no code). |
| 2 | `0x871437aec1b915c75dff5d7290122668a4919c3d` | 9.000000 | 0.0003% | EOA |  |
| 3 | `0x22e57e6c7b04847d2a4f30d646abad5fbb9951f6` | 1.000000 | 0.0000% | EOA |  |
| 4 | `0xfa55e92e056fb2a1ecf059a67bb71b01cdcbc6d7` | 0.956902 | 0.0000% | EOA |  |
| 5 | `0x30d74a14b4414d4c55ce935b3c00b3ba0826be20` | 0.289165 | 0.0000% | EOA |  |
| 6 | `0xbde4d38ec4426f1c9f4859d38928a02987e9dba7` | 0.184548 | 0.0000% | contract | EOA with EIP-7702 delegation (code = 0xef0100…delegate). |
| 7 | `0xda44d84f8de69febda4c4e0b89ff24077413f4b0` | 0.182039 | 0.0000% | EOA |  |
| 8 | `0x1061f91aa7665f623123588e4161694bb90a0400` | 0.056247 | 0.0000% | EOA |  |
| 9 | `0x13fa5163f6644500a3f603de82bd1bc65a1b7852` | 0.056247 | 0.0000% | EOA |  |
| 10 | `0x946a96b92012b52b19650e40766f3585a4df6cbf` | 0.056247 | 0.0000% | EOA |  |
| 11 | `0x5875d55ff1c9367b46feb5af1006dabfde6943ec` | 0.056213 | 0.0000% | EOA |  |
| 12 | `0x97017b3f627716b1b2a62afe853b696f582b6013` | 0.056192 | 0.0000% | EOA |  |
| 13 | `0xa5751bccc1bc1cae9bebb6dddb447a42180ac170` | 0.031193 | 0.0000% | EOA |  |
| 14 | `0x366c902380b1927044c075bc0d1934ae6076fcd6` | 0.007790 | 0.0000% | EOA |  |
| 15 | `0x09071158c1a7130058704d98f47d03446f1981be` | 0.005546 | 0.0000% | EOA |  |
| 16 | `0x3e99fe36c05e337617d3c7a09465798b446b384f` | 0.005462 | 0.0000% | EOA |  |

## THUGS (THUGS) — `0xe10e9822a5de22f8761919310dda35cd997d63c0`

totalSupply: **650,510.4736** | holders found: 325 | holders sum: **649,716.3253** | expected sum: 650,510.4736 | reconciliation delta: -794.148283

| # | holder | balance | % supply | type | note |
|---|--------|--------:|---------:|------|------|
| 1 | `0x000000000000000000000000000000000000dead` | 440,583.524949 | 67.7289% | EOA | `0x…dEaD` dead address. EOA (keys unknown; standard burn vanity). |
| 2 | `0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7` | 185,305.672686 | 28.4862% | contract | THUGS `bscSwapPair` (original BscSwap launch pair) — holds the unrecovered launch liquidity (~28.5% of THUGS supply). |
| 3 | `0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957` | 4,302.494982 | 0.6614% | contract | WBNB/THUGS pair on NarwhalswapFactory (also the LP token itself). |
| 4 | `0x40257481f09db2211a3274b34554bbb00b0a7fb1` | 3,821.093079 | 0.5874% | contract | Old PancakeSwap v1 THUGS/WBNB pair (residual reserves). |
| 5 | `0x9354cab0f1083135439b23aa6c364329e578f39a` | 1,728.556381 | 0.2657% | contract |  |
| 6 | `0x9e51bb6841fe9d6fbc7bcc9bafb67d65767ceb32` | 1,713.466347 | 0.2634% | contract |  |
| 7 | `0x571d0b55fe30eb1f6e68e8799f181c46de6b0059` | 1,294.149872 | 0.1989% | contract |  |
| 8 | `0x3a8a2f2bcae88da860c291831f4a38b63d2d17b2` | 731.716165 | 0.1125% | EOA |  |
| 9 | `0x269a27c1d9f08d71b33a9c2889240b17dba71bd9` | 342.725321 | 0.0527% | EOA |  |
| 10 | `0x4bdcf6a051ac3aa48f606da3d64b65ec5b06f45c` | 285.266503 | 0.0439% | contract |  |
| 11 | `0x0c925f9ab07f7beb696a7c3f4efbb36baef16a7c` | 247.391343 | 0.0380% | EOA |  |
| 12 | `0xd54dc3bb8252d50658193a4485e32f21cb6d0d94` | 148.703782 | 0.0229% | EOA |  |
| 13 | `0x0fce9273490a5e93bb6b3823adb179ec27f0d1a3` | 136.163764 | 0.0209% | EOA |  |
| 14 | `0x96444b5219183241a81397a72c5a2c22b8f076bd` | 133.151710 | 0.0205% | EOA |  |
| 15 | `0x990c3679173311c7db77bbf088d0e9c8fd49f69a` | 130.091823 | 0.0200% | contract |  |
| 16 | `0xe4292e1d4aa075ac989cd5c1e8433185cafbf1cd` | 125.210104 | 0.0192% | EOA |  |
| 17 | `0xe364712b859bb650eed692ac199f0c3b6c320552` | 115.754649 | 0.0178% | EOA |  |
| 18 | `0xd202825a51cdae003ba219288153bd1a72afba1f` | 110.768109 | 0.0170% | EOA |  |
| 19 | `0x95f5366ec7a3e03181553adad8b288a5692e5cc1` | 106.326771 | 0.0163% | EOA |  |
| 20 | `0x245f698621c5f7d4b92d7680b78360afcb9df9af` | 106.000000 | 0.0163% | contract |  |
| 21 | `0x288b57a76e11f1e2350c0358cd4ac002f678d1a9` | 106.000000 | 0.0163% | EOA |  |
| 22 | `0x5013603f39d18c2dfaa731964152c689d0c72247` | 106.000000 | 0.0163% | EOA |  |
| 23 | `0x9b190e1c13f1ffa1dee70817a867520716229bca` | 106.000000 | 0.0163% | EOA |  |
| 24 | `0xce2b62681b09c075d65f24bd9ef16a6edde09561` | 106.000000 | 0.0163% | EOA |  |
| 25 | `0xf05f923bec5e192d8a76ae52adf6e4727aeb5312` | 106.000000 | 0.0163% | EOA |  |
| 26 | `0xd32e03876f8dbc4da9ae04886641da44caf990c7` | 101.816624 | 0.0157% | EOA |  |
| 27 | `0x12b915f75ab486a3db1e6fb137963801e36da7d7` | 100.267539 | 0.0154% | EOA |  |
| 28 | `0xe75d3b39d017985caf20fac7134ed55b8b47cc26` | 100.000000 | 0.0154% | EOA |  |
| 29 | `0xe10e9822a5de22f8761919310dda35cd997d63c0` | 98.794145 | 0.0152% | contract | THUGS token contract itself. |
| 30 | `0xc9849e6fdb743d08faee3e34dd2d1bc69ea11a51` | 90.898813 | 0.0140% | contract |  |
| 31 | `0xa184088a740c695e156f91f5cc086a06bb78b827` | 90.609653 | 0.0139% | contract |  |
| 32 | `0x2b54ed7ce65d35e970d371347084400c458bc4df` | 90.345140 | 0.0139% | EOA |  |
| 33 | `0x6991b1b4a340f2a25f48f50f12e481eacd172452` | 85.492071 | 0.0131% | EOA |  |
| 34 | `0x17e3597f156a309b0fd31fbec6760d8400b518b5` | 80.727534 | 0.0124% | EOA |  |
| 35 | `0x2182b832e1a425bf6175022371f0f037bf7d687f` | 76.708135 | 0.0118% | EOA |  |
| 36 | `0x682a95baf52ffaa699b6a644222ad5073c3bbd05` | 72.533729 | 0.0112% | EOA |  |
| 37 | `0x35ae978ae79040ce3b75a4f8b42904d93e96a1ba` | 71.828931 | 0.0110% | EOA |  |
| 38 | `0xc26c62cb6298971daf9a51b1272ce3e4a782ead2` | 71.053946 | 0.0109% | EOA |  |
| 39 | `0x81636546d45aaddceea47fcebccc76de4e18321d` | 70.479045 | 0.0108% | EOA |  |
| 40 | `0x232406f087c05a82ef4b0a8887c2a02e83401518` | 57.701777 | 0.0089% | EOA |  |
| … | *285 more holders* | | | | full list in holders.json |

## Burn / locked addresses (direct reads)

| address | NAR | NLP_NARWBNB | LP_WBNBTHUGS | LP_WBNBBUSD | rNLP5 | rNLP6 | THUGS |
|---|---|---|---|---|---|---|---|
| `0x0000000000000000000000000000000000000000` | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 |
| `0x000000000000000000000000000000000000dead` | 25.440530 | 0.055185 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 440,583.524949 |
| `0x7777777777777777777777777777777777777777` | 11,098,868.480901 | 0.000000 | 0.000000 | 0.000000 | 437,408.147555 | 2,807,031.588108 | 0.000000 |

## rNLP farm reads
### rNLP5 — farm `0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f` (block 127196737)

| # | holder | rNLP bal | share % | staked LP (farm.balanceOf) | userInfo (userRewardPerTokenPaid, rewards, buffrate, power, timeStamp) | contract |
|---|--------|---------:|--------:|---------------------------:|----------------------------------------------------------------------|----------|
| 1 | `0x7777777777777777777777777777777777777777` | 437,408.147555 | 99.4896% | 0.000000 | 0.000000, 0.000000, 0, 0, 0 | no — burn pool — NAR `_burnPool` (hardcoded in token) and rNLP de |
| 2 | `0x0567b7665d5633903c558ceec8fe7023743333a4` | 1,240.374383 | 0.2821% | 1,240.374383 | 8.037264, 22,265.407613, 15000, 18605615739236335393770000, 1604341145 | no |
| 3 | `0x6bc76d2224e6fbd45e8e910aecad1b4b15bdfb70` | 234.819042 | 0.0534% | 234.819042 | 13.932255, 23.307965, 1500, 352228562739247158441000, 1608698637 | yes — EOA with EIP-7702 delegation (code = 0xef0100…delegate). |
| 4 | `0x2aefce802c8db8c25216140cb672ef8f5b806186` | 233.893828 | 0.0532% | 233.893828 | 12.161575, 0.000000, 1000, 233893828325870698884000, 1607166076 | no |
| 5 | `0xfee9d17162d5b0cd8f2db9a8a7e5da4bacf21e72` | 131.440965 | 0.0299% | 131.440965 | 9.933400, 0.000000, 1000, 131440965484936530633000, 1605278232 | no |
| 6 | `0x25461088f2f674918a60948c96dca9dc34658739` | 99.393840 | 0.0226% | 99.393840 | 3.790082, 1,604.248373, 9000, 894544557115873156389000, 1603560522 | no |
| 7 | `0x8875791187aec618f1ba655872e03fea049c2ee1` | 69.420889 | 0.0158% | 69.420889 | 3.503161, 1,049.085332, 9000, 624787997260501303551000, 1603548738 | no |
| 8 | `0x8b19468e2d8206983585b074a9c93d28a84e4aed` | 69.182818 | 0.0157% | 69.182818 | 4.631605, 587.916828, 7593, 525305140002669572199093, 1603679902 | no |
| 9 | `0x840e20dfb9f8f3dc076865223d6ce7e84ddc8c67` | 63.441599 | 0.0144% | 63.441599 | 4.065825, 495.871920, 7593, 481712059126660196115552, 1603640094 | no |
| 10 | `0xb64790ab8d4a83fea1bc943092c7a184f95bd2ba` | 45.379659 | 0.0103% | 45.379659 | 3.745111, 775.025729, 9000, 408416929993415346489000, 1603554666 | no |
| 11 | `0xda9cb21f6b662eb972ecc8fd358a1fdab0811977` | 24.244981 | 0.0055% | 24.244981 | 12.160623, 0.000000, 1000, 24244980855689137869000, 1607165311 | no |
| 12 | `0x9ae6a213a8d6bd61274622c31ac776ab7c7c936a` | 5.160330 | 0.0012% | 5.160330 | 0.359083, 0.000000, 1500, 7740494736274035000000, 1603140996 | no |
| 13 | `0xaf2835ea331414a99bfa7cc9192e54a9f5b88b1f` | 4.949471 | 0.0011% | 4.949471 | 15.541751, 0.000000, 1000, 4949471254949336084000, 1616599614 | no |
| 14 | `0x3abf26382c10eb04f496b5e800e20ab98fbbd536` | 4.076026 | 0.0009% | 0.000000 | 0.000000, 0.000000, 0, 0, 0 | no |
| 15 | `0x5381dd87f1440ba838471512bfd3954cf2a0f030` | 3.521937 | 0.0008% | 3.521937 | 4.553374, 8.184276, 2023, 7124879164111927375577, 1603727695 | no |
| 16 | `0xb26d140952d12c3e83c4d0ea7866cfade75d69c3` | 2.630989 | 0.0006% | 2.630989 | 14.230221, 0.000000, 1000, 2630989424873556388000, 1608964657 | no |
| 17 | `0xf765f66d6a14799329f4320f780657b0c503732b` | 1.416987 | 0.0003% | 1.416987 | 15.541744, 7.827094, 9000, 12752883881902777320000, 1615374448 | no |
| 18 | `0x6d0399cd37a4b056e3d5229e56ad677d47505fbe` | 1.215879 | 0.0003% | 1.215879 | 7.433540, 0.000000, 1000, 1215879000000000000000, 1604225278 | no |
| 19 | `0xc2db3ad63af0d995187b54818a3b1b9a83b2357f` | 1.116923 | 0.0003% | 0.000000 | 0.000000, 0.000000, 0, 0, 0 | no |
| 20 | `0x339c2c1ab253cfaa91b716391827fddb38be3e97` | 1.028556 | 0.0002% | 1.028556 | 15.541754, 0.000000, 1000, 1028556238948804879000, 1619072222 | yes |
| 21 | `0xbd14965cb3c299f5b5510e838c5164142748f3fc` | 0.992677 | 0.0002% | 0.992677 | 6.425866, 0.000000, 1000, 992676625678873720000, 1604054013 | no |
| 22 | `0xb0c0ee8f6d0ff124fed3e2a4c823ab4e7cd38da4` | 0.709892 | 0.0002% | 0.709892 | 9.473932, 0.000000, 1000, 709892156742419077000, 1604917752 | no |
| 23 | `0x650151c8de2e51243fe2c55b052eba51303a2e4a` | 0.492739 | 0.0001% | 0.492739 | 1.004612, 0.558395, 1819, 896292915465084863169, 1603201092 | no |
| 24 | `0x7cd8431c6cf37b392944b47f0bff0eb2abb6df82` | 0.438053 | 0.0001% | 0.438053 | 2.061003, 0.000000, 1000, 438053226804527575000, 1603345217 | no |
| 25 | `0x434170dc667873ae0c60a1ec83a80cc7e5961a74` | 0.412835 | 0.0001% | 0.000000 | 0.000000, 0.000000, 0, 0, 0 | no |
| 26 | `0xd232ba18643ae9a84af0eba92a9f62ad89065410` | 0.349594 | 0.0001% | 0.349594 | 1.715010, 0.000000, 1000, 349593896344892358000, 1603296550 | no |
| 27 | `0x0e9615fd9e4ad93e308c84cb517c03d86c7cd24a` | 0.345549 | 0.0001% | 0.345549 | 2.277167, 0.000000, 1000, 345549393850312143000, 1603377416 | no |
| 28 | `0xad2fb1e796be491bcdd2437fb36a33017f5f3615` | 0.334073 | 0.0001% | 0.334073 | 1.660545, 0.653576, 2250, 751664954247092300250, 1603227147 | no |
| 29 | `0x0500badf75cc314ea65d8b4e5590ed85e824ad95` | 0.330761 | 0.0001% | 0.330761 | 9.872265, 1.294410, 9000, 2976845115886480845000, 1605188510 | no |
| 30 | `0xdede6dd683b73e931cceea452fc88fdeeaf5f4db` | 0.328632 | 0.0001% | 0.328632 | 0.486627, 0.000000, 1500, 492947779379315527500, 1603152267 | no |
| 31 | `0x929648fa0dfc3637d55226ce5e3f75cae1566fce` | 0.235961 | 0.0001% | 0.235961 | 10.072753, 0.000000, 1000, 235960887198287904000, 1605398539 | no |
| 32 | `0x5d516addd718ec07a5bc6999040703ec2c9b441b` | 0.234074 | 0.0001% | 0.234074 | 2.278571, 0.000000, 1000, 234073990491630109000, 1603377638 | no |
| 33 | `0x58a17e995e0d3b9546ab1533d1ed97e2b8eea03c` | 0.230274 | 0.0001% | 0.230274 | 3.952040, 0.637263, 3375, 777174114877556580000, 1603625396 | no |
| 34 | `0xa5895b170fbbdfca3f086e38f692c386108e5967` | 0.230273 | 0.0001% | 0.230273 | 3.952096, 0.637250, 3375, 777172200273445522500, 1603625408 | no |
| 35 | `0xc736fb6c9e7748ce0ed09c63117d394b64645d84` | 0.230273 | 0.0001% | 0.230273 | 3.952170, 0.637239, 3375, 777170374378994894625, 1603625420 | no |
| 36 | `0x7c388b94456df48717f95bf7aad6e5c8e8d655ce` | 0.153516 | 0.0000% | 0.153516 | 3.951910, 0.425159, 3375, 518117115305449291500, 1603625063 | no |
| 37 | `0x0832e2d1f6b6598f6f782eb8b4759104a6099b7a` | 0.148345 | 0.0000% | 0.148345 | 6.504767, 0.000000, 1000, 148345271470640026000, 1604068497 | no |
| 38 | `0x43f01a8002698f8c6223e905d473e150ac01282c` | 0.127447 | 0.0000% | 0.127447 | 4.076986, 0.000000, 1000, 127447351312132012000, 1603645949 | no |
| 39 | `0x1c997556e0eadbc6180de7c1f5e45a4be9ac06ef` | 0.124924 | 0.0000% | 0.124924 | 11.859952, 0.000000, 1000, 124924209049305049000, 1606927534 | no |
| 40 | `0xde1fecaf3a7f38ffa21745d874054c575bdc6a0c` | 0.108433 | 0.0000% | 0.108433 | 12.802124, 0.507975, 9000, 975897000000000000000, 1607672140 | no |
| 41 | `0x5ad80ea091948c524af5161cef8efb7e20091900` | 0.098579 | 0.0000% | 0.098579 | 3.458115, 1.493458, 9000, 887214600083180808000, 1603549533 | no |
| 42 | `0x1cf3c45394d0f10656b67c37c9fe1c38a66a19ad` | 0.093194 | 0.0000% | 0.093194 | 5.072064, 0.000000, 1000, 93193638150394790000, 1603826035 | no |
| 43 | `0xd80f4d518074001c6cc997418516d85785ebeeb6` | 0.076746 | 0.0000% | 0.000000 | 4.588145, 0.000000, 1000, 0, 1603739020 | no |
| 44 | `0xaaa77711c7b70e20d32ec50b21df89e742607b9b` | 0.054020 | 0.0000% | 0.054020 | 10.339607, 0.000000, 1000, 54020000000000000000, 1605711756 | no |
| 45 | `0x366c902380b1927044c075bc0d1934ae6076fcd6` | 0.046549 | 0.0000% | 0.046549 | 8.433171, 0.000000, 1000, 46549000000000000000, 1604488388 | no |
| 46 | `0x6f6b9a91a78c2e23ea086e45a53111ffa61195ad` | 0.036953 | 0.0000% | 0.036953 | 6.632506, 0.000000, 1000, 36952600514807898000, 1604089503 | no |
| 47 | `0xed617243e7e366229e08a1357436f80904ff44e2` | 0.036244 | 0.0000% | 0.036244 | 2.116477, 0.000000, 1000, 36244000000000000000, 1603353251 | no |
| 48 | `0xa879683e1bb65c26a54d74f3908d132a986ce90d` | 0.028252 | 0.0000% | 0.028252 | 6.990663, 0.000000, 1000, 28252000000000000000, 1604147796 | no |
| 49 | `0xfa55e92e056fb2a1ecf059a67bb71b01cdcbc6d7` | 0.016865 | 0.0000% | 0.016865 | 4.241449, 0.000000, 1000, 16865401409866300000, 1603672172 | no |
| 50 | `0xfe57b687f49ccce153bfc96c0f53df07877e0be5` | 0.013850 | 0.0000% | 0.013850 | 9.775334, 0.056158, 9000, 124650000000000000000, 1605146169 | no |
| 51 | `0x2b426dee450479f5909eba62aae9f48fb6376939` | 0.013150 | 0.0000% | 0.013150 | 6.991422, 0.000000, 1000, 13150000000000000000, 1604147922 | no |
| 52 | `0x8a745886c46a4f9f9ca262bc4ae427fc6e7c880e` | 0.004354 | 0.0000% | 0.004354 | 1.958669, 0.000000, 1000, 4354008875879761000, 1603330654 | yes |
| 53 | `0xc9879d3cfc7d71a90d39230e058d287c438c81c9` | 0.002864 | 0.0000% | 0.002864 | 6.326495, 0.000000, 1000, 2864000000000000000, 1604036055 | no |
| 54 | `0x828b3b3cb2fa9eb8c631d40db9de6b0809fcaacc` | 0.002032 | 0.0000% | 0.002032 | 3.824934, 0.000000, 1000, 2032000000000000000, 1603605708 | no |
| 55 | `0xd96cca2e774e323bf22692865350aeb1af4200db` | 0.000788 | 0.0000% | 0.000788 | 10.595319, 0.000000, 1000, 788403929301240000, 1606017579 | no |
| 56 | `0x77f7a4113d65df6ad0e9eeb5bfe7820dc64167b7` | 0.000295 | 0.0000% | 0.000000 | 3.062175, 0.000000, 1000, 410574645595000, 1603496722 | no |
| 57 | `0x44245b25b5e7d41c75703438e514ea4a60ad4161` | 0.000036 | 0.0000% | 0.000036 | 15.541744, 0.000000, 5062, 183959676655504802, 1610240784 | no |
| 58 | `0x0ccf5b43857ca33df612a4f1cb671d67383bf31e` | 0.000026 | 0.0000% | 0.000026 | 14.448518, 0.000000, 1000, 26122367592125000, 1609161595 | no |
| 59 | `0xf1f431babeb314831d925abb1ee9b9fa4a3d10e6` | 0.000007 | 0.0000% | 0.000007 | 15.541744, 0.000000, 1000, 7096672801914000, 1612402324 | no |
| 60 | `0x5e0ed7fce25a45787efc887dd8ca62be4153713e` | 0.000002 | 0.0000% | 0.000002 | 15.541754, 0.000000, 1000, 2122137248396000, 1619213181 | no |
| 61 | `0xd11f8de1b9bc2c9a18405577213c06b3149668ed` | 0.000000 | 0.0000% | 0.000000 | 4.538682, 0.000000, 1000, 140000000000, 1603722958 | no |

### rNLP6 — farm `0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B` (block 127196745)

| # | holder | rNLP bal | share % | staked LP (farm.balanceOf) | userInfo (userRewardPerTokenPaid, rewards, buffrate, power, timeStamp) | contract |
|---|--------|---------:|--------:|---------------------------:|----------------------------------------------------------------------|----------|
| 1 | `0x7777777777777777777777777777777777777777` | 2,807,031.588108 | 99.9996% | 0.000000 | 0.000000, 0.000000, 0, 0, 0 | no — burn pool — NAR `_burnPool` (hardcoded in token) and rNLP de |
| 2 | `0x871437aec1b915c75dff5d7290122668a4919c3d` | 9.000000 | 0.0003% | 9.000000 | 0.324086, 0.000000, 1000, 9000000000000000000000, 1603497847 | no |
| 3 | `0x22e57e6c7b04847d2a4f30d646abad5fbb9951f6` | 1.000000 | 0.0000% | 1.000000 | 1.864189, 0.129970, 2250, 2250000498002629223250, 1604845191 | no |
| 4 | `0xfa55e92e056fb2a1ecf059a67bb71b01cdcbc6d7` | 0.956902 | 0.0000% | 0.956902 | 0.495017, 0.000000, 1000, 956901997556617117000, 1603672076 | no |
| 5 | `0x30d74a14b4414d4c55ce935b3c00b3ba0826be20` | 0.289165 | 0.0000% | 0.289165 | 0.108708, 0.000000, 1000, 289165289347084456000, 1603237621 | no |
| 6 | `0xbde4d38ec4426f1c9f4859d38928a02987e9dba7` | 0.184548 | 0.0000% | 0.184548 | 3.701491, 0.000000, 1000, 184548230344725760000, 1789604161 | yes — EOA with EIP-7702 delegation (code = 0xef0100…delegate). |
| 7 | `0xda44d84f8de69febda4c4e0b89ff24077413f4b0` | 0.182039 | 0.0000% | 0.182039 | 0.053234, 0.000000, 1500, 273058425757477096500, 1603163106 | no |
| 8 | `0x1061f91aa7665f623123588e4161694bb90a0400` | 0.056247 | 0.0000% | 0.056247 | 0.031929, 0.000000, 1500, 84369790514802619500, 1603137510 | no |
| 9 | `0x13fa5163f6644500a3f603de82bd1bc65a1b7852` | 0.056247 | 0.0000% | 0.056247 | 0.031659, 0.000000, 1500, 84369790514802619500, 1603137180 | no |
| 10 | `0x946a96b92012b52b19650e40766f3585a4df6cbf` | 0.056247 | 0.0000% | 0.056247 | 0.032168, 0.000000, 1500, 84369790514802619500, 1603137801 | no |
| 11 | `0x5875d55ff1c9367b46feb5af1006dabfde6943ec` | 0.056213 | 0.0000% | 0.056213 | 0.486533, 0.038384, 9000, 505920121414683354000, 1603655160 | no |
| 12 | `0x97017b3f627716b1b2a62afe853b696f582b6013` | 0.056192 | 0.0000% | 0.056192 | 0.031193, 0.000000, 1500, 84288132953203189500, 1603136616 | no |
| 13 | `0xa5751bccc1bc1cae9bebb6dddb447a42180ac170` | 0.031193 | 0.0000% | 0.031193 | 0.243740, 0.000000, 1000, 31193000000000000000, 1603410317 | no |
| 14 | `0x366c902380b1927044c075bc0d1934ae6076fcd6` | 0.007790 | 0.0000% | 0.007790 | 1.601930, 0.000000, 1000, 7790000000000000000, 1604487536 | no |
| 15 | `0x09071158c1a7130058704d98f47d03446f1981be` | 0.005546 | 0.0000% | 0.005546 | 0.037083, 0.000000, 1500, 8319159844157712000, 1603143705 | no |
| 16 | `0x3e99fe36c05e337617d3c7a09465798b446b384f` | 0.005462 | 0.0000% | 0.005462 | 0.423303, 0.011093, 9000, 49157434141600860000, 1603564116 | no |

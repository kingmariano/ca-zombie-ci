# C-36 seg-B deep dive — gambling / PoWH3D / Fomo3D family (76 contracts)

**Measurement:** block 26111142 (2026-10-03), read-only RPC. Live balances re-measured for all 76 and match `worklist.json` (no movement since block 26,111,001).

**Headline: 0 E-U candidates in seg-B — all 76 contracts are H-O (holder/self-service) or contain only privileged paths.** The two extraction classes in the brief both fail:

1. **Buy-and-exit / market race:** there is **no live market** for any family token. DEX sweep (Uniswap V1 `0xc0a47dFe..`, V2 `0x5C69bEe7..`, SushiSwap `0xC0AEe478..`, V3 `0x1F98431c..`; `getPair`/`getPool(token,WETH,3000/10000)` for all 49 P3D-shape tokens) found only 3 venues: P3D V1 exchange `0x4a8c8e62fefb504b1f44e4a8f68b4569f513aa74` = **0 ETH / 0 P3D**, HourglassX V2 pair `0x8af11191dd8c6dd5f1de6021dbabca2b37edc7ca` = **15,266 wei P3X / 66 wei WETH** (dust), HourglassX V1 exchange = 0/0. All other tokens have no pair at all. Contract `buy()` is the only permissionless acquisition path and always costs more than `sellPrice` (measured buy/sell 1.15–2.33x) → a round-trip loses 13–57% before gas.
2. **Permissionless airdrop / potSwap / endRound:** F3D-family `airDropTracker_` is **0 in every clone**; even at tracker=1 a ≥0.1 ETH buy wins ≤25–75% of a ≤0.23 ETH pot at ≤1/1000 odds. `endRound()` is permissionlessly triggerable via any `withdraw()` after expiry, but pays the recorded last-buyer winner. `potSwap()` only accepts ETH.

## Summary table

| address | name | live ETH | mapped | class | one-line reason |
|---|---|---:|---:|---|---|
| `0xA62142888ABa8370742bE823c1782D17A0389Da1` | Fomo3D Long | 1099.4525 | 1098.66 | H-O | PRIOR $0; 1099.45 ETH in player/winner vaults, non-player withdraw reverts |
| `0x4e8ecf79ade5e2c49b9e30d795517a81e0bf00b8` | Fomo3D Quick | 84.1401 | 76.03 | H-O | PRIOR $0; F3D clone, vault/pot only |
| `0x52083b1a21a5abc422b1b0bce5c43ca86ef74cd1` | Fomo3D Short | 76.2527 | 38.30 | H-O | PRIOR $0; F3D clone, vault/pot only |
| `0x0ad3227eb47597b566ec138b3afd78cfea752de5` | FoMo3Dshort v2 | 136.6356 | 22.83 | H-O | F3D clone; index under-claims; vault/pot only |
| `0xe336d0c8b24d8e20b6f714522f590abadb601493` | FoMo3Dlong v2 | 20.7771 | 32.36 | H-O | F3D clone + founder fee; over-claim is index artifact |
| `0xcb47c89cb17c10b719fc5ed9665bae157cac2cb1` | FoMoJP | 72.9125 | 72.78 | H-O | PRIOR $0; F3D clone + Ownable (no fund mover) |
| `0x0f90ef4e2526e3d1791862574f9fb26a0f39ec86` | F3DPLUS | 35.1095 | 35.02 | H-O | F3D clone; airdrop dead (tracker 0) |
| `0xda8d7ff0d043848a689125e2c7ab87b16a0cbe81` | SnowStorm | 34.7567 | 33.35 | H-O | F3D clone; airdrop dead |
| `0xb2b30d39074c52a60283a26f238abff31fcb4217` | SnowStorm B | 24.6683 | 23.54 | H-O | F3D clone (same bytecode as SnowStorm) |
| `0xaff69c67f5dbbdd088ccbc6d47cb9e0ea547e132` | Fomo | 15.2926 | 15.29 | H-O | F3D clone, no potSwap; airdrop pot 0 |
| `0x47663541167ece0b96d9e5c60f9e470b2a20f598` | LD3D Official | 86.5429 | 86.49 | H-O | unverified LD3D; players-only; round timer = year 2118 |
| `0x05aa2fdf9f58b426b49900834cce0565d88e52eb` | Bingo4Beast Long Official | 120.1965 | 119.97 | H-O | PRIOR $0; Bingo4Beast F3D-like, vault only |
| `0x4fb7d68e0116f35ade131b6535b2db1027bf7650` | Bingo4Beast Long Official (deploy 2) | 84.4831 | 55.94 | H-O | PRIOR $0; Bingo stone game; withdraw fail for non-player |
| `0xab83d96de35bad6f234178fbb6507203488e9626` | FoMo3D Ultra | 466.1162 | 130.90 | H-O | PRIOR $0 (airdrop); 466 ETH in unverified F3D vault accounting; non-holder withdraw reverts |
| `0x86ab844a067094ec2c5a4bade21fcf2aeee32122` | GameFair | 13.1250 | 14.00 | H-O | Ponzi; redeem/withdrawProfit pay own claim only |
| `0xc5aafe85775fe97bee49d16cc4f38aaf8dbf20c5` | IBC Lottery | 12.7129 | 12.36 | H-O | ticket lottery; refundTicket pays the player in IBC tokens, not caller |
| `0x6db943251e4126f913e9733821031791e75df713` | ReadyPlayerONE | 24.5391 | 6.82 | H-O | PRIOR $0; F3D core |
| `0x24da016c06941ec2c92be28e0a2b2e679f0d1dc7` | FoMo3D Lightning | 7.3517 | 4.72 | H-O | F3D clone; airdrop dead |
| `0x167cB3F2446F829eb327344b66E271D1a7eFeC9A` | GandhiJi | 658.8806 | 761.15 | H-O | P3D clone, over-claimed 115.5%; no market; buy->sell loses 18% |
| `0xd48b633045af65ff636f3c6edd744748351e020d` | Zethr | 276.7442 | 139.75 | H-O | PRIOR $0; Zethr withdraw(address) pays own dividends only |
| `0xb9ab8eed48852de901c13543042204c6c569b811` | Zethr Casino | 111.6839 | 73.53 | H-O | PRIOR $0; Zethr Casino, same code |
| `0x2fa0ac498d01632f959d3c18e38f4390b005e200` | EthPyramid | 27.7591 | 20.03 | H-O | EPY curve; own tokens/divs only; no admin mover |
| `0x86D179c28cCeb120Cd3f64930Cf1820a88B77D60` | FoMoGame | 13.5775 | 13.49 | H-O | F3D clone; vault/pot only |
| `0xB3775fB83F7D12A36E0475aBdD1FCA35c091efBe` | PoWH3D | 2041.0182 | 2452.80 | H-O | PRIOR $0; V1 exchange empty; holder withdraw()/exit() only |
| `0xa146240bf2c04005a743032dc0d241ec0bb2ba2b` | POWM | 25.3383 | 23.54 | H-O | P3D clone; holder only |
| `0x4c29d75cc423e8adaa3839892feb66977e295829` | POOH | 15.7667 | 20.14 | H-O | P3D clone, over-claimed 127.7%; holder only |
| `0x702392282255f8c0993dbbbb148d80d2ef6795b1` | PoWTF | 4.6124 | 3.35 | H-O | P3D clone subset; holder only |
| `0xe1c9a03cf690256ff7738cbd508c88cf5238a535` | Hourglass Clone A | 3.1489 | 2.29 | H-O | P3D clone; holder only |
| `0x34ba9c7402e1df11709c7983008b5a49d59e963f` | Hourglass Clone B | 2.8343 | 0.23 | H-O | P3D clone; holder only |
| `0xdb4837c9d84315abcde80a865f15178f86db3966` | LOCKEDiN | 2.6910 | 1.44 | H-O | P3D clone + dev early phase (self-disabled); holder only |
| `0x7e7e645e9121dddaf87d0434feb9f113d1dbbb41` | StrongHold | 2.3386 | 1.10 | H-O | P3D clone; holder only |
| `0x7b6c511a94d35b9cf9979b727335c9798edb5c64` | Hourglass Clone C | 2.0716 | 0.51 | H-O | P3D clone; holder only |
| `0xf5aa54d121dfe0d5eeb37c83aed42238f4f2c5c6` | Hourglass Clone D | 2.0467 | 0.64 | H-O | P3D clone; holder only |
| `0x5bedf488d29407bc08e77cd9ee292c2041a61c8c` | UnKoin | 1.9240 | 0.26 | H-O | P3D clone; holder only |
| `0xe65f525ec48c7e95654b9824ecc358454ea9185e` | AceDapp | 92.7314 | 27.17 | H-O | DivsAddon() is a donation to all holders; IDD() owner-only |
| `0x0a97094c19295e320d5121d72139a150021a2702` | CryptoMinerToken | 79.3062 | 45.60 | H-O | PRIOR $0; P3D subset; holder only |
| `0xabefec93451a2cd5d864ff7b0b1604dfc60e9688` | BlueChip | 52.0576 | 34.37 | H-O | P3D clone; holder only |
| `0x05215fce25902366480696f38c3093e31dbce69a` | REV1 | 30.2789 | 26.56 | H-O | P3D clone + whitelist (self-disabled); holder only |
| `0xc28e860c9132d55a184f9af53fc85e90aa3a0153` | POTJ | 9.5957 | 10.56 | H-O | P3D clone, over-claimed 110%; holder only |
| `0xecfae6f958f7ab15bdf171eeefa568e41eabf641` | LYNIA | 8.3135 | 8.59 | H-O | P3D clone + hardcoded charity forwarder; holder only |
| `0xf72b0b36723f60402cccad7f4358acf2ad474c17` | BlackGoldEthereum | 6.0215 | 8.24 | H-O | P3D clone; holder only |
| `0xea61319f55b6543962fe1d7bd990ef74849fc54f` | ProofOfCraigGrant | 6.1756 | 5.39 | H-O | P3D clone; holder only |
| `0x37304b0ab297f13f5520c523102797121182fb5b` | SportCrypt | 21.5636 | 15.76 | H-O | sports escrow; withdraw pays own balance; claim own position |
| `0xd2bfceeab8ffa24cdf94faa2683df63df4bcbdc8` | DailyDivs | 109.6839 | 102.56 | H-O | PRIOR $0; payFund() forwards to constant charity addr |
| `0x1739e311ddbf1efdfbc39b74526fd8b600755ada` | ProofOfCommunity | 6.5978 | 3.68 | H-O | P3D clone; holder only |
| `0xfcd3a0f5f416e407647a7518b90354946d316059` | BitConnect Token | 14.6368 | 19.09 | H-O | P3D clone, over-claimed 130%; holder only |
| `0xc6e5e9c6f4f3d1667df6086e91637cc7c64a13eb` | Eightherbank | 14.1128 | 12.99 | H-O | P3D clone + fixed fee addrs; owner-gated setters |
| `0xffd31e68bf7af89df862435a138615bd60abf574` | Nexgen | 11.9950 | 25.60 | H-O | over-claimed 213%; withdraw zeroes own balance (80% payout); creator-side drain is P |
| `0x84cc06eddb26575a7f0afd7ec2e3e98d31321397` | DiamondDividend | 8.1698 | 9.14 | H-O | P3D clone, over-claimed 112%; holder only |
| `0xc3ad35d351b33783f27777e2ee1a4b6f96e4ee34` | E25 Booster | 6.9073 | 4.22 | H-O | P3D clone + charity forwarder; holder only |
| `0x568a693e1094b1e51e8053b2fc642da7161603f5` | BitConnect v2 | 5.4843 | 3.76 | H-O | P3D clone; holder only |
| `0x510f9a9642ac14ded91629a1aad552be4b24b5f0` | ETHPlatinum | 20.2175 | 28.15 | H-O | over-claimed 139%; owner-gated launchtime only |
| `0x26e6c899b5a5dc1d4874d828fda515a7eb7baf00` | DivsNetwork | 4.6405 | 4.69 | H-O | over-claimed 101%; payFund to constant addr |
| `0xcd2de0bd5347f617f832442ebcc1c23a4d618847` | RedChip | 10.8973 | 9.05 | H-O | P3D clone; holder only |
| `0xa4dce3845cb88a6fca0291d4eca9e5a96e75e2b4` | CxxMain | 9.5642 | 5.57 | H-O | dailyCheckin no-op; dev-only roi/hello; holder only |
| `0xbedde30d3532165843f07b1b0e3e90fddbb75918` | FamilyOnlyToken | 7.5532 | 5.84 | H-O | P3D clone; holder only |
| `0x586f3d9e3524eb02448691b158fdcf5ffc2c57b0` | SPW | 7.1981 | 5.69 | H-O | P3D clone + charity forwarder; holder only |
| `0xca1cc76be1f5e5ee492859d8463653cb231991bc` | ETHDIAMOND | 6.1425 | 3.63 | H-O | dailyCheckin no-op; withdrawDevFee dev-only; holder only |
| `0x2c984ec9bb20b33deb84fbeedf20effda481fdc4` | Ethershares | 4.6666 | 3.07 | H-O | P3D clone; holder only |
| `0x8f6015289a64c48ccf258c21a999809fc553c3c4` | TwelveHourToken | 3.1098 | 4.38 | H-O | P3D clone, over-claimed 141%; holder only |
| `0x897d6c6772b85bf25b46c6f6da454133478ea6ab` | Neutrino81 | 3.9688 | 1.34 | H-O | passInterest/passRepay admin & payable-in; getRepay own balance |
| `0x058a144951e062fc14f310057d2fd9ef0cf5095b` | HourglassX | 4.0836 | 4.71 | H-O | over-claimed 115%; arbitrary-call blocked for handler/hourglass |
| `0xde2b11b71ad892ac3e47ce99d107788d65fe764e` | FairExchange | 4.0615 | 1.48 | H-O | P3D-style + registration; admin-gated setters |
| `0x0be5e8f107279cc2d9c3a537ed4ea669b45e443d` | POMDA | 3.7522 | 2.89 | H-O | P3D clone subset; holder only |
| `0x7d2d58d7add0b2d6e06fa85590b60da7741c18c9` | DecentEther | 3.7474 | 2.54 | H-O | P3D clone; holder only |
| `0x38e219ee67a5e1536c5a89fec2da0d69c254cac4` | BitConnect v3 | 3.5382 | 0.90 | H-O | P3D clone; holder only |
| `0xb0c4382d4355cdfe94a132fadf92a509b1e25939` | Furious | 3.1158 | 1.63 | H-O | dailyCheckin no-op; withdrawDevFee dev-only; holder only |
| `0x4af078e47490c0e761a3de260952d9eb4a6ad693` | EtherDiamond | 2.9983 | 2.63 | H-O | P3D clone subset; holder only |
| `0x11e165dd03c63771004f929d58b75e4aaf2d1a23` | CryptoSurge | 2.9613 | 0.04 | H-O | P3D clone + charity forwarder; holder only |
| `0x77b541f90ecfa09f854209eefeca24c295050e2e` | Hourglass Clone F | 2.8087 | 1.52 | H-O | P3D clone + admin fee (admin-gated changeAdmin); holder only |
| `0x5044ac8da9601edf970dcc91a10c5f41c5c548c0` | UPower | 2.3499 | 2.25 | H-O | P3D clone; holder only |
| `0xaa4ec8484e89bed69570825688789589d38eea5e` | Hourglass Clone G | 2.2820 | 2.14 | H-O | P3D clone; holder only |
| `0xae384c6e68f5d697d65ed43fd53ef5ea3288f536` | RedChip v2 | 2.1723 | 2.29 | H-O | P3D clone; holder only |
| `0x433e631ac0c03e49ca034dbf5543964c80c6b391` | OmniDex | 2.1804 | 1.77 | H-O | P3D clone + bankroll forwarder; holder only |
| `0xd446a13f9b9f8bcbc3ded73764d08735561b1638` | SPW v2 | 2.0793 | 0.13 | H-O | P3D clone + charity forwarder; holder only |
| `0x5eee354e36ac51e9d3f7283005cab0c55f423b23` | ArbitrageETHStaking | 216.3037 | 216.30 | H-O | staking pool; withdrawAll pays own balance; owner renounced; math sound |

PRIOR-covered entries (one-line confirmations, no re-litigation): PoWH3D `0xb3775fb`, Fomo3D Long `0xa621428`, FoMo3D Ultra `0xab83d96`, FoMo3Dshort `0x52083b1`, Quick `0x4e8ecf7`, FoMoJP `0xcb47c89`, AceDapp `0xe65f525`, CryptoMinerToken `0x0a97094`, Bingo4Beast `0x05aa2fd`/`0x4fb7d68`, Zethr `0xd48b633` / Zethr Casino `0xb9ab8ee`, DailyDivs `0xd2bfcee`, ReadyPlayerONE `0x6db9432` — live balances and selector sets unchanged.

## 1. Over-claimed contracts — exact price-vs-redeemable math (no E-U)

For every P3D fork the claim formula is `sell(tokens) = tokensToEthereum_(tokens) - 10% dividendFee` (supply-based bond curve), credited to `payoutsTo_` and paid by `withdraw()` from the contract balance; `buy()` prices on the same curve plus the fee. Measured at block 26111142:

| contract | live ETH | index mapped | buyPrice (ETH/token) | sellPrice (ETH/token) | buy/sell | verdict |
|---|---:|---:|---:|---:|---:|---|
| GandhiJi `0x167cB3F` | 658.881 | 761.15 (115.5%) | 0.002002297 | 0.001638243 | 1.22 | acquire costs 22% over redeem value; no market → H-O race only |
| PoWH3D `0xB3775fB` (PRIOR) | 2041.018 | 2452.80 (120.1%) | 0.003846898 | 0.003147462 | 1.22 | same; V1 exchange empty |
| POOH `0x4c29d75` | 15.767 | 20.14 (127.7%) | 0.000434379 | 0.000355401 | 1.22 | H-O race only |
| Nexgen `0xffd31e6` | 11.995 | 25.60 (213.4%) | 0.001799000 | 0.001529150 | 1.18 | stored credits > balance; H-O race; creator drain is P |
| ETHPlatinum `0x510f9a9` | 20.218 | 28.15 (139.2%) | 0.000510455 | 0.000417645 | 1.22 | H-O race only |
| BitConnect `0xfcd3a0f` | 14.637 | 19.09 (130.4%) | 0.000568414 | 0.000465066 | 1.22 | H-O race only |
| POTJ `0xc28e860` | 9.596 | 10.56 (110.1%) | 0.000107518 | 0.000067198 | 1.60 | H-O race only |
| DiamondDividend `0x84cc06e` | 8.170 | 9.14 (111.9%) | 0.000224220 | 0.000149480 | 1.50 | H-O race only |
| HourglassX `0x058a144` | 4.084 | 4.71 (115.3%) | n/a (P3X) | n/a | — | no market; handler arbitrary-call blocked |
| TwelveHourToken `0x8f60152` | 3.110 | 4.38 (140.8%) | 0.000066696 | 0.000028584 | 2.33 | H-O race only |
| DivsNetwork `0x26e6c89` | 4.641 | 4.69 (101.0%) | 0.000010138 | 0.000006082 | 1.67 | H-O race only |

`calculateEthereumReceived(totalSupply)` for PoWH3D is only **550.4 ETH** vs its 2041 ETH balance: the curve cannot pay the balance out through `sell()`; the remainder is accumulated unclaimed dividends that holders withdraw directly. An attacker cannot obtain tokens below `sellPrice`: no DEX, and `buy()` charges ≥ `sellPrice` (1.15–2.33x). **Conclusion: the over-claim is a holder first-mover race (H-O), not E-U.**

F3D-family "over-claims" (FoMo3Dshort v2 `0x0ad3227` live 136.6 vs mapped 22.8; FoMo3Dlong v2 `0xe336d0c` live 20.8 vs mapped 32.4) are index artifacts: F3D has **no sell function** — keys only earn gen dividends and the round pot, so the index key-value estimate is not a redeem path.

## 2. Permissionless airdrop EV (all F3D clones) — negative

`airdrop()` fires only when `_eth >= 0.1 ETH`; prize = 25% / 50% / 75% of `airDropPot_` for 0.1 / 1 / 10 ETH buys; odds = `airDropTracker_/1000`. Measured (block 26111142):

| clone | airDropPot_ (ETH) | tracker | first-buy EV (0.1 ETH buy) |
|---|---:|---:|---:|
| Fomo3D Long | 0.145247 | 0 | -0.09996 |
| Fomo3D Quick | 0.208717 | 0 | -0.09995 |
| Fomo3D Short | 0.152610 | 0 | -0.09996 |
| FoMo3Dshort v2 | 0.116099 | 0 | -0.09997 |
| FoMo3Dlong v2 | 0.900939 | 0 | -0.09977 |
| FoMoJP | 0.136112 | 0 | -0.09997 |
| F3DPLUS | 0.091481 | 0 | -0.09998 |
| SnowStorm | 0.145497 | 0 | -0.09996 |
| SnowStorm B | 0.150643 | 0 | -0.09996 |
| Fomo | 0.000000 | 0 | n/a |
| ReadyPlayerONE | 0.090669 | 0 | -0.09998 |
| FoMo3D Lightning | 0.100569 | 0 | -0.09997 |
| FoMoGame | 0.088748 | 0 | -0.09998 |
| FoMo3D Ultra | 0.208443 | 0 | -0.09995 |
| Bingo1 | 0.228010 | 0 | -0.09994 |

With tracker=0 the airdrop is currently **unwinnable**; even at tracker=1 the best case is 25% × 0.23 = 0.057 ETH against a 0.1 ETH buy. The prior finding (≤0.23 ETH share, negative EV) holds for every clone.

## 3. E-U candidates for parent fork-testing

**None.** No function + call path was found that lets an unprivileged non-holder extract value in seg-B. Near-misses and why they fail:

- **AceDapp `DivsAddon()` (0xe65f525, 92.7 ETH):** public payable → `DividendsDistribution(msg.value,0)`. `_amountOfTokens = ethereumToTokens_(0) = 0` and the `tokenSupply_>0` branch collapses `_fee` to `_amountOfTokens·(…)` = 0, so the caller gets **no personal credit**; only `profitPerShare_` rises (caller recovers only their pro-rata share `f·V`, losing `(1-f)·V`). `IDD()` is `require(msg.sender==owner)`.
- **Nexgen `withdraw()` (0xffd31e6, 12.0 ETH):** sets `payoutsTo_=0` after paying **80%** of the stored balance → no repeat-claim loop. Separately `sell()` credits sold tokens to `tokenBalanceLedger_[creator]` (deployer, pre-minted 35M NEXG) allowing a re-sell drain — **P**, not reachable by an attacker.
- **HourglassX `transfer(to,value,data,func)` (0x058a144, 4.1 ETH):** user-controlled `func` call, but `actualTransfer()` requires `to != refHandler` and `to != hourglass`; the handler's `sendETH` is `onlyParent`, so the vector is blocked. `takeShitcoin()` moves only non-P3X ERC20s (handler holds none; its fallback rejects tokens).
- **Neutrino81 `passInterest`/`passRepay`/`fund` (0x897d6c6, 4.0 ETH):** admin/boss-gated and **payable-in** (add `msg.value` to a customer credit). `fund()` is a public donation to all holders (caller recovers only their pro-rata share).
- **IBC Lottery `refundTicket(pID)` (0xc5aafe8, 12.7 ETH):** permissionless but transfers 25% of the player's paid-in **IBC tokens** to `plyr_[_pID].addr` — the player, not the caller; no ETH.
- **P3D-family `payFund()/payCharity()/payBankroll()`** (DailyDivs, LYNIA, SPW, E25, DivsNetwork, OmniDex, CryptoSurge, SPW v2): permissionless but forward to **`address constant`** hardcoded charity/bankroll addresses — cannot be redirected.
- **EthPyramid `withdrawOld(to)` (0x2fa0ac4, 27.8 ETH):** sends `dividends(msg.sender)` to a caller-chosen `to` — still the caller's own dividends; non-holder `dividends()==0`.

## 4. Notable H-O races / stuck-fund notes

- **PoWH3D `0xb3775fb` — 2041 ETH, 349,710 tokens.** `sellPrice` 0.003147, `buyPrice` 0.003847. Curve sell value of the whole supply = 550.4 ETH; the rest is unclaimed dividends claimable by holders via `withdraw()`. First-mover race among holders; the only historical market (V1 exchange) is empty. No attacker entry.
- **GandhiJi `0x167cB3F` — 658.9 ETH, 182,020 tokens**, index over-claims by 102 ETH; same mechanics (`buyPrice` 0.002002 vs `sellPrice` 0.001638).
- **ArbitrageETHStaking `0x5eee354` — 216.30 ETH, mapped 216.30 (100%).** `withdrawAll()`/`withdraw(n)` pay `ethBalanceOf(msg.sender) = balanceLedger·personalFactor·globalFactor/constantFactor`; fresh address = 0. Owner slot = 0 (renounced). `globalFactor` (slot 5) = `0x2cd4e87122a16ae58e5` < `constantFactor` 1e44 (no brick). The 2% fee inflates `globalFactor` proportionally, preserving backing; a large deposit into a small balance cannot inflate the attacker's own claim beyond their stake (net = `p·(A/B−1)` ≤ 0). H-O.
- **FoMo3D Ultra `0xab83d96` — 466.1 ETH (largest single holding).** Unverified modified F3D. `rID_=11`; `round_(11)` empty (pot 0, plyr 0, ended=false); rounds 9–10 winners (pID 311 `0xfce240fe5b1667773731c899729498287ad199b4`) already withdrew (win/gen=0); `airDropPot_` 0.208, tracker 0. Non-player `withdraw()` reverts. The 466 ETH sits in this variant's player-vault accounting; no non-holder path found. Keep as H-O/S; fork-test only if the parent wants to reverse the unverified vault layout.
- **LD3D `0x4766354` — 86.5 ETH (unverified).** `round_(1)`: plyr=1112, keys=124,506e18, pot only 0.056 ETH, `getTimeLeft()`=2,898,814,852 s (~92 y) → the 48% winner pot can never be distributed. `withdraw()` reverts for non-players; `getPlayerVaults(non-player)=0`. H-O for key holders.
- **Bingo4Beast ×2 (`0x05aa2fd` 120.2 ETH, `0x4fb7d68` 84.5 ETH, unverified).** F3D-like/stone games; non-player `withdraw()` reverts (`withdraw fail` on deploy 2). Prior $0 confirmed. H-O.
- **GameFair `0x86ab844` — 13.1 ETH.** `gameStart()=true`; `withdrawProfit()`/`redeem()` pay the caller's own accrued claim capped at `address(this).balance` (a whale whose claim ≥ balance can take the whole balance — H-O race).
- **Zethr `0xd48b633` (276.7 ETH) / Zethr Casino `0xb9ab8ee` (111.7 ETH)** — prior $0, unchanged; `withdraw(address)` is `dividendHolder`-gated, pays own dividends.
- **SportCrypt `0x37304b0` — 21.6 ETH.** Escrow; `withdraw(amount)` pays `min(balances[msg.sender],amount)`; `claim()` pays the caller's match position; `recoverFunds()` only finalizes. No non-holder path.

## 5. Family-deviation audit (extra selectors resolved & source-read)

- **P3D family:** `AceDapp` (`DivsAddon`, `IDD`, `exitFee`, owner — see above); `Nexgen` (`payout(address)` admin-only; `sellingWithdraw()` own balance; `soldTokens`); `CxxMain`/`ETHDIAMOND`/`Furious` (`dailyCheckin()` = counter increment; `distributedRoi()`/`helloCXX()`/`helloDiamond()`/`withdrawDevFee()`/`checkDevPool()` dev-only); `LYNIA`/`DailyDivs`/`E25`/`SPW`/`DivsNetwork`/`OmniDex`/`CryptoSurge`/`SPW v2` (constant-address charity/bankroll forwarders + ERC223 `transferAndCall`); `LOCKEDiN` (`onlyDevs` self-disabling early phase); `REV1` (ambassador whitelist, self-disabling); `Hourglass Clone F` (`changeAdmin` admin-only; `sell` pays 0.3% admin fee before payouts update); `UnKoin`/`ProofOfCraigGrant`/`RedChip`/`UPower`/`RedChip v2`/`ProofOfCommunity`/`DecentEther`/`Ethershares`/`Neutrino81`/`Eightherbank` (administrator/owner setters — all gated; `buyFor` is a normal buy-for).
- **F3D family:** `Fomo3D Quick` (ICO-phase view calculators only); `FoMo3Dlong v2` (`myFounder_`/`ourTEAM`/`setOtherFounder` — founder fee routing); `FoMoJP` (Ownable added, no owner fund mover); `Fomo` (missing `potSwap`). Unknown selectors `0112a880`, `e37b346d`, `75661f4c`, `dcb6af48`, `20b8decb`, `76bc67a5`, `636f6e74`, `6865636b` are **not functions**: calling them falls through to the payable fallback, which reverts with the `isWithinLimits` guard `"pocket lint: not a valid currency"` (requires msg.value ≥ 1 gwei) — i.e. they are bytecode constants/false-positive selector extractions.
- **Unverified four (Ultra/LD3D/Bingo1/Bingo2):** selector-probed function-by-function; `withdraw()` reverts for non-players in all four.

## 6. Method / artifacts

- Live balances re-measured at block 26111142 (all 76) → `raw/live_now.json`; selector maps → `raw/selector_map.json`, `raw/selector_annotations.txt`; sources → `raw/sources/`; DEX sweep → `raw/dex_pairs_found.json`.
- All calls were read-only (`cast call`, `cast storage`, `eth_call`, `eth_getBalance`). No transactions signed or sent.

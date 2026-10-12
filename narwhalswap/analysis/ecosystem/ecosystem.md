# Narwhalswap ecosystem — contract inventory & security notes

**Block of record: 127,201,628** (BSC mainnet, 2026-10-12). Read-only analysis (no transactions sent).
Companion machine-readable file: `ecosystem.json` (this folder). Supporting raw data: `recon1_raw.json`, `paircreated.json`, `lp_holders.json`, `farm_family.json`, `strategy_scan.json`, `strategy_value.json`, `wallet_balances.json`, `nar_minters.json`, `grand_enum.json`, `holder_identify.json`, `misc_balances.json`, `sourcify/`.

## 0. Timeline (from Sourcify deployment data + on-chain blocks)

| date | event |
|---|---|
| 2020-09-27 | NarwhalswapFactory (`0xB9fA…FEa1`) + NarwhalswapRouter (`0xe85c6a…6078`) deployed (deployer `0xc76827…`, EOA) |
| 2020-10-12 | NarToken NAR (`0xa130…fc83`) deployed by team EOA `0xb104…f2C5` |
| 2020-10-16 | NarwhalReward **V1** farms (NAR/WBNB, WBNB/BUSD) |
| 2020-10-19 | NarwhalPower ×2, rNLP tokens, **NarwhalRewardV2** farms (NAR/WBNB, WBNB/BUSD) |
| 2020-11 | NarCardToken (NFT), BTCB/NAR LP created; "Small/Medium/Huge" V2 tier farms; Dividend V2/V3 (xNAR-style) |
| 2020-12-04 | NarwhalCollecter (factory feeTo) |
| 2021-02 | NarwhalRewardV3 farms (BTCB/NAR, NAR/WBNB); SmartChef (external) |
| 2021-05 → 07 | "The Grand Banks" (same team): GRAND v1/v2, GrandBank v1 + TheGrandBanks v2 (80 pools), Timelock, strategies, FryingDutchMan servicers, NarwhalSwap aggregator, NarNft |
| 2021-11 → 2023-02 | final team-EOA activity (NarNft minting, card dispenser, last Pancake swap 2023-02-01) |
| 2022-2026 | zombie: contracts untouched, TVL stranded in old farms/LPs |

## 1. Core contracts

| contract | address | verified | holds now | notes |
|---|---|---|---|---|
| NarwhalswapFactory | `0xB9fA84912FF2383a617d8b433E926Adf0Dd3FEa1` | ✅ NarwhalswapFactory.sol | 96 pairs | feeTo = Collecter; **feeToSetter = team EOA 0xb104** (can switch fee receiver) |
| NarwhalswapRouter | `0xe85c6ab56a3422e7bafd71e81eb7d0f290646078` | ✅ NarwhalswapRouter.sol | – | factory()=Narwhal factory; stateless |
| NAR token | `0xa1303e6199b319a891b79685f0537d289af1fc83` | ✅ NarToken.sol | 13.86M supply of 21M cap | 2.5 % burn + 2.5 % rewardPool on transfers; **team EOA is governance + minter** |
| NarwhalCollecter (feeTo) | `0x7f8a46EC48442d9EBF28fBC1144A83f8BC53F7e9` | ✅ NarwhalCollecter.sol | 0.055 WBNB + LP dust | **`convert(address,address)` is permissionless** (see §6) |
| NarwhalPower ×2 | `0x1d791eaa…6956` (farm1 caller), `0xa1992a97…2ea2` (farm2 caller) | ✅ NarwhalPower.sol | – | power/segment accounting only |

## 2. The farm family (all found on-chain; several still hold value)

All `NarwhalReward*` contracts are governance-controlled by the **single team EOA `0xb104…f2C5`**.

| family | address | staked LP | holds now (block 127.2M) |
|---|---|---|---|
| NarwhalReward **V1** | `0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835` | NAR/WBNB | **297.16 LP** |
| NarwhalReward **V1** | `0xbb38f7551025a433f36590be85271110212655de` | WBNB/BUSD | **231.53 LP (81 % of pool)** |
| NarwhalRewardV2 | `0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f` | NAR/WBNB | **2,243.79 LP + 204,706.95 NAR**; NAR minter; rNLP `0x6451…6f91` |
| NarwhalRewardV2 | `0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B` | WBNB/BUSD | 11.94 LP + 46,039.76 NAR; NAR minter; rNLP `0x1f7d…de1a` |
| NarwhalRewardV3 | `0xbe85812237741d75f81aebf1d9af52d544542168` | NAR/WBNB | **1,291.98 LP** |
| NarwhalRewardV3 | `0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d` | BTCB/NAR | **36.83 LP (83 % of pool) + 5,176.73 NAR**; rNLP `0x46d603e2…bd243`; router()= Narwhal router |
| SmallV2 | `0xc3a47142…1773` / `0x3dfb186e…1051` | BTCB/NAR | 1 wei NAR / **8,113.73 NAR + 0.024 LP** |
| MediumV2 | `0x7f041488…a274` / `0xe6e0646b…f57a` | BTCB/NAR | 0 / **3,769.51 NAR** |
| HugeV2 | `0x657ba421…8b65` / `0xaaa6ddb2…c107` | BTCB/NAR | 0 / **73,665.16 NAR** |
| Dividend V2 | `0xb85a8c26…ea0d` | NAR (xNAR-style) | share supply 2.11M; 0 NAR |
| Dividend V3 | `0xc8e70639…b25e` | NAR | share supply 2.87M; 0 NAR |
| Dividend V3 | `0xf7a36c87c3a8909949638120f23cd721bf572032` | NAR | share supply 0.99M; **1,333,817.14 NAR held** |
| SmartChef (external) | `0x2368bab38a79827f49fc768bf1b6d04226704d35` | (Pancake-style pool) | 634.06 NAR; owner = external EOA `0x0F9399FC…` |

Receipt tokens (rNLP, `Rnlp.sol`): `0x6451571c…`, `0x1f7d08d9…`, `0x46d603e2…`, plus V3-tier rNLPs `0x6702ea92…`, `0x205d52f8…`, `0xd7c7ee65…`, `0x3321adb0…`, `0x7825d4c6…`, `0x162ece88…`. All are team-minted/owned ERC20 stubs.

**NAR minters (on-chain list):** farm V2 ×2 + team EOA. ~7.1M NAR of the 21M cap is still mintable by the team key.

## 3. NFTs / game / aggregator

| contract | address | supply / state | verdict |
|---|---|---|---|
| NarCardToken (ERC721) | `0x828b5adbe8e0a06aaf5d5a5fd16e6b15a393d86e` | 9,218 cards; team = minter + `_governance` | **integration dead**: every farm's `_narcardToken()/_narcardFactory()` returns `0x0`, so `setRune()/removeRune()` revert. Game boost never wired. |
| NarNft (ERC721) | `0xce7a099a7c5c062a4f66a6bbdec191a222baa3f2` | 49 NFTs; team EOA holds 12; team not a minter | airdrop/prize NFT (Beefy lottery era) |
| Card dispenser (unverified) | `0xe207ea201a1ac5907e333c68e2ecd96fdb9389e1` | `nftToken()` = NarNft; `randomCards(uint256)`, `setPrice`, `seizeBnb()`; funded 14.5 BNB lifetime; **0 now** | owner = team EOA; holds nothing |
| NarwhalSwap aggregator | `0x849b7b4541cde9cbe41cfd064d9d7ff459b9cea4` | `trade()/splitTrades()`, partner fees; holds dust (<0.1 USDT); owner = dev3 EOA `0x512d8616…` | `collectRemainingToken/Ether` onlyOwner; team used it 100+ times |

**NarwhalSwap v3 routing suite (June–July 2021, dev3 EOA `0x512d8616…`):** `NarwhalRouterV3` ×5 (`0x50cbc94e…`, `0x8e8228bc…`, `0x001b8d99…`, `0xfc571de6…`, `0x0841563d…`), `NarwhalSwap` aggregator ×2 more (`0xc7efa241…`, `0x1b849161…`), `NarwhalMultiRouter2` (`0x52801490…`), `NarwhalRouterBNB` (`0x78172b46…`), `NarRouterTokenToTokens` ×2 (`0x2b7c207f…`, `0xaba423fd…`). All verified, all **hold 0 BNB and no tracked tokens** (`swap_suite.json`); owner-only sweep functions + permissionless swap entrypoints that pay `msg.sender`.

No IFO / lottery contract was found; no timelock exists on the core Narwhalswap (only on The Grand Banks, §5).

## 4. Partner token: THUGS (+ its LP)

- THUGS token `0xe10e9822a5de22f8761919310dda35cd997d63c0` (verified `ThugsToken.sol`, deployer `0x54af6dd5…`, Oct 2020) — separate project, paired **on the Narwhal factory**.
- Its child `TokenTimelock` (computed CREATE address) = `0x586acb4be6cc93aa5c399888b255c7e864ea508e`; `release(IERC20)` is **public** but pays only the fixed beneficiary; vault now holds 0.0023 THUGS (already drained).
- THUGS team wallets: initialDistribution `0x3009c9c0…`, burnReserves `0xfd98d6de…`, team `0x6e65f24a…`, dev `0x4e433974…`, marketing `0x481f0079…` (balances in `ecosystem.json`).

## 5. The Grand Banks (same team, May–Jul 2021)

- **GrandBank V1** `0x08f886b1…2ce1` (owner = Timelock `0xd6841550…62e0`, 24 h delay; proposer/executor dev EOA `0x18527a3…`), 12 pools.
- **TheGrandBanks V2** `0x3d8fd880…1107` (owner = dev2 EOA `0xab3921C5…`), **80 pools**, holds 1,448 CATO + 31.12 USDT.
- Tokens: Grand v1 `0xd37ebaeb…67e`, CatoToken/GRAND v2 `0xee814f5b…1dd9`.
- ~92 **StrategyCake** strategies + ~20 **FryingDutchMan** (Landing/Sailing) servicers. Live strategy balances are small (top ≈ 1.7 LP-equivalent; full list in `strategy_scan.json`/`strategy_value.json`); strategy `deposit/withdraw` are farm-only, `inCaseTokensGetStuck` can never take `want`.

## 6. Permissionless payout paths found (exact signatures)

| # | function | effect | exploitable? |
|---|---|---|---|
| 1 | `NarwhalCollecter.convert(address,address)` | burns collector-held fee-LP, converts to WBNB, permanently pairs into NAR/WBNB LP **kept by the collector** | No profit for caller; spends only collector fee dust (≈0.055 WBNB). Sandwich-able (market swaps do happen). |
| 2 | `FryingDutchManLanding.execute(address,address,address,uint256,bool)` / `execute(...)` on Sailing | removes/converts **any residual balances it holds** and sends proceeds **to msg.sender** | Only drains stray leftovers. All instances currently empty (~0 BNB). No auth on `execute`. |
| 3 | `TokenTimelock.release(IERC20)` @ `0x586acb4b…` | sends full token balance to fixed beneficiary (THUGS burn-reserves) | Public trigger only; vault already empty (0.0023 THUGS). |
| 4 | `StrategyCake.earn()` | compounds strategy `earnedAddress` into want; controller/buy-back fee goes to gov | Public (unless `onlyGov`); not a principal drain; can be spammed with gas cost only. |
| 5 | `NarwhalReward.buffRateReporter(address)` | adjusts buff-rate accounting of a target + reporter | No token movement; game mechanic. |
| 6 | `NarwhalReward*.withdraw(uint256)/exit(uint256)/getReward()/emergencyWithdraw()`, `NarwhalRewardDividend*.stake/...` | caller withdraws **own** accounting only | Standard; safe by construction (per-msg.sender). |
| 7 | `SmartChef.migrate(uint256)` @ `0x2368bab3…` | drains that pool's staked LP to `migrator` | migrator = `0x0` today, but **owner is an external EOA** `0x0F9399FC…` that can set a migrator and pull staked LP. Not a Narwhal-team contract. |

## 7. Team-only powers that could move value

- **`seize(address,uint256)` (onlyGovernance = team EOA 0xb104)** on every NarwhalReward V1/V2/V3/Dividend — sweeps **any token except the staked LP** (e.g. the 204.7 k NAR in farm1, the 1.33 M NAR in Dividend V3 #2, 73.7 k NAR in HugeV2 #2) to the team key.
- `setUser(address,uint256,uint256,uint256,uint256,uint256,uint256)` / `setStake(uint256,address)` / `setInitValue(...)` (DividendV3, onlyGovernance) — can rewrite user accounting.
- `setEmergencyStop(bool[,uint256])`, `setRewardRate`, `notifyRewardAmount` (onlyGovernance) — freeze/redirect emissions.
- `TheGrandBanks.inCaseTokensGetStuck(address,uint256)` + `inCaseBNBGetStuck(uint256)` — **owner = dev2 EOA** can drain any token except GRAND-v2 from the V2 farm shell; same on V1 via the Timelock (24 h).
- `NarwhalSwap.collectRemainingToken(address,uint256)/collectRemainingEther(uint256)` — owner = dev3 EOA (dust only).
- `NarToken.addMinter/removeMinter/setRate/setRewardPool/setTeamWallet/setGovernance` — team can mint remaining supply and change transfer tax.
- `NarCardToken.addMinter/removeMinter/setGovernance`; `NarNft.addMinter/...`; card-dispenser `seizeBnb()` — NFT-side team powers.
- No recovery function found on strategies for `want`; user LP in farms is not directly sweepable by `seize` (`require(token != lpToken)`).

## 8. Migration functions

- `TheGrandBanks/GrandBank.migrateToGrandV2(uint256)` — permissionless 1:1 burn-GRAND-v1 → mint-GRAND-v2, **hard deadline `require(block.number < 7,076,050)`**; block now ≈127.2 M ⇒ **dead code**.
- `SmartChef.migrate(uint256)` — migrator-gated (external project), see §6/7.
- No other `migrate`/rescue path was found on Narwhal core contracts.

## 9. LP holdings & the WBNB/THUGS whale

Full lists in `lp_holders.json` (balances re-read at block ≈127.2 M and cross-checked against `totalSupply`; WBNB/THUGS sums match to ~1.6e‑4 LP).

- **WBNB/THUGS LP `0x40ff83ac…9957`** — totalSupply 273.568 LP, reserves 84.53 WBNB + 4,302.5 THUGS (≈$63 k of WBNB). Only **8 holders**:
  - **EOA `0x4d710603238427ae805b980bab8261624f5260c7` = 254.40 LP (93 %)** — plain EOA, dormant; no contract risk, can always burn for its share.
  - EOA `0xe99140fc04e458ac58d47c29c0649bcc3914dc0a` = 18.10 LP; contract `0xb752f0cb…` ("OriginalGangster", THUGS-deployer project) = 1.06 LP; rest dust + Collecter.
- **NAR/WBNB LP `0xb6b0ba4e…d1f2`** — 25,004.55 LP cap, 236 current holders; top: farm1 2,243.79; V3 farm `0xbe8581…` 1,291.98; V1 farm `0x186be2…` 297.16; largest EOA ≈ 81.9 LP.
- **WBNB/BUSD LP `0x5ec32c21…47c3`** — 285.47 LP; top: V1 farm `0xbb38f7…` 231.53 (81 %); EOA `0xa9d5f138…` 33.68; farm2 11.94.
- Wrapped “LP-in-LP” dust pairs (`0x00eda48b…`, `0x8b1bbfaf…`, `0x6166911e…`) were created after block 20 M by randoms; economically empty (dead end).

## 10. Team / deployer wallets (native + tokens)

| wallet | BNB | tokens | role |
|---|---|---|---|
| `0xb104AE8b7DA105ca79cbA208b9A41C1D63fff2C5` | **0.7774474728** | 563.45 NAR, 0.00138 WBNB, 39.9985 CATO | deployer ("Narwhalswap: Deployer"), feeToSetter, governance, NAR minter |
| `0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9` | 0.0867037424 | **87,117.03 NAR** | teamWallet (farms) |
| `0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960` | **1.4657232576** | 2,530.35 NAR | NAR `_rewardPool`, V3-farm teamWallet |
| `0x00470220dd82d5429379c8d9f679774b0e6e651d` | 0 | – | NAR `_teamWallet` variable |
| `0xc76827cce55338cbd6b399f45a75df0cd5da2749` | 0 | 1,571 wei NAR | factory/router deployer |
| `0x18527a351db2435fa21db88cbb87d4155188b62b0` | 0 | – | TGB deployer, timelock proposer |
| `0xab3921c5de7e3459ce07f7015b3fdf0ebec927ef` | 0.2770573757 | 77.36 BUSD, 1,965.71 CATO | TGB V2 owner |
| `0x512d86161ade81a3e01b6b2de8a994778f75f8cb` | 0 | – | NarwhalSwap owner |
| `0x6abfae833ca1a4e9a9d482dfeebcc5ecec635e90` | 0.0000775974 | – | strategy gov |

Total native value at the team EOA-side: ≈ **2.61 BNB** (~$2 k) across the above + ≈90 k NAR (~$2.3 k at last zombie price) + dust.

## 11. Dead ends (recorded)

1. `_narcardFactory()/_narcardToken()` = `0x0` on V2 and V3 farms → NarCard game integration never linked (NFTs exist, plays dead).
2. `migrateToGrandV2()` deadline passed; nothing else to migrate.
3. `TokenTimelock.release()` already drained; `NarNft` minting ended (49 supply).
4. No IFO/lottery/xNAR aside from the `*Dividend*` contracts above.
5. BscScan live scraping blocked (Cloudflare; firecrawl keyless quota); used the Wayback snapshot 2024-09-12 of the team EOA page (1,654 txs; last activity 2023-02-01).
6. Public RPC `eth_getLogs` limits (25–50 blocks) make wide scans infeasible; a public NodeReal demo endpoint (50 k-block ranges) was used transiently for the factory/LP/NAR scans (not persisted).
7. Blockscout has no BSC deployment; Etherscan key dead → not used.
8. 286 of 5,206 NAR reward recipients are 23-byte EIP-1167 proxy clones (user smart wallets, not ecosystem contracts).

## 12. Bottom line

- **Newly found live-value contracts**: NarwhalReward **V1** farms (`0x186be2…`, `0xbb38f7…`), NarwhalReward **V3** farms (`0xbe8581…`, `0x268a2c…`), the Small/Medium/Huge V2 tier farms, three **Dividend** (xNAR-style) contracts (`0xf7a36c…` holds 1.33 M NAR), the Narwhal **Router** (`0xe85c6a…`), NarwhalSwap aggregator, NarCardToken/NarNft + card dispenser, and the SmartChef clone (external owner).
- **Biggest values**: WBNB/THUGS pool (≈$63 k, 93 % in one EOA), V2 farm1 (2,243.8 LP + 204.7 k NAR), DividendV3 #2 (1.33 M NAR), V3 NAR/WBNB farm (1,292 LP), V1 WBNB/BUSD farm (81 % of its pool).
- **Permissionless payout paths**: `NarwhalCollecter.convert`, `FryingDutchMan.execute`, `TokenTimelock.release`, `StrategyCake.earn` — none pay attacker-owned principal; they recycle/dust/compound only. **No outside-callable function was found that transfers user principal to msg.sender.**
- **Governance risk**: one EOA (`0xb104…`) is governance of every Narwhal farm/dividend/NAR/collector and can `seize()` all non-LP tokens (incl. the 1.33 M NAR dividend pool) and still mint NAR up to cap. The Grand Banks V2 farm is owned by a different single EOA (`0xab3921…`) with `inCaseTokensGetStuck` powers.

# Child-C — Stakehouse ecosystem live-value scan (Ethereum mainnet)

**Date of scan:** 2026-10-12 (all times UTC)
**Final consolidated balance block:** `26179180` (file: `ecosystem_balances_final.json`)
**Earlier component scans:** RQA balances @ `26178886`, LSD ETH @ `26178916`, LSD tokens @ `26178919–26178920`, aux totals @ `26179185`
**Method:** read-only `eth_call`/`eth_getBalance`/`eth_getCode` via `childC/rpc.py` (public RPC endpoints, no keys), Etherscan V2 API via `childC/es.py` (key read from env at runtime, never written), Blockscout public API for token holders, heimdall decompiles for unknown bytecode.
**Scope:** everything in the Stakehouse/Blockswap orbit that can hold value: RageQuitAssistant fleet, LSD factory + 23 LSD networks + giant pools, dETH/savETH/sETH tokens, SafeBox/CIP, kETH contracts, brand/loot contracts, withdrawal-upgrade contracts, DAO contracts, claimant addresses.

---

## 1. Headline result

| Bucket | Live ETH | At block | Verdict |
|---|---:|---|---|
| **AccountManager** `0xDd6E67942a9566A70446f7400a21240C5f71377C` | **64.305718** | 26179180 | Known from triage; still the single big pot |
| **Giant Fees & MEV Pool** `0x04e5c93f4b96D2fdB2cDE4c9826C373e5656796E` | **7.410914** | 26179180 | NEW — largest find of this scan; live pool, not paused, users can withdraw |
| **RageQuitAssistant fleet (46 contracts)** | **0.665519** | 26179180 | NEW — leftover unclaimed rage-quit ETH, claimable by entitled parties (see §3) |
| LSD Staking Funds Vaults (4 vaults with dust) | 0.253394 | 26179180 | NEW — residual fees/MEV deposits for 4 LSD networks |
| **Giant Protected Staking Pool** `0xF5D92B01c478273bD13aA8efb130D98e131ecBB9` | **0.095158** + 5.5446 dstETH LP tokens | 26179180 | NEW — live pool, not paused |
| savETH Vault of LSD network `0x12670b89…` `0x1e8e121c…` | 0.011000 + **4.839255 savETH** | 26179180 | NEW — holds 98.5% of all savETH |
| LSD LiquidStakingManagers (all 23) | 0 | 26179180 | all zero |
| All other protocol contracts (routers, registries, dETH/savETH token contracts, SweepReporter, FullWithdrawals, SafeBox, LSD Kontroller, factory, deployers, impls/beacons, BSNGovernor, brand/loot, kETH suite) | 0 | 26179180 | all zero |
| **Protocol-side total (excl. user wallets)** | **72.741703** | 26179180 | 64.3057 + 7.4109 + 0.6655 + 0.2534 + 0.0952 + 0.0110 |

**Non-protocol (user-owned) value found while scanning, reported for completeness — not protocol custody:**

* The 138 unique RageQuitAssistant aux addresses (46 smart wallets + 46 dETH-LP + 46 sETH-LP pairs, plus the node-runner EOAs they point to) hold **8.239350 ETH** total (`rqa_aux_eth_totals.json`, block 26179185). All balances >0.001 ETH sit in **registered node-runner EOAs** (e.g. `0xa1500087…` 4.2654 ETH, `0x85535e08…` 2.7514 ETH); the LP-pair and smart-wallet contracts hold ≤0.001 ETH each.
* dETH token: 16.887594 supply / 44 holders; top external holder `0x992c5dCd…` (10.6458 dETH), Curve dETH/frxETH pool (1.2705), a DLP contract (4.1490). SweepReporter proxy itself holds 0.1 dETH dust (`raw/bs_holders_dETH.json`).
* 12 sETH held by Syndicate `0x80f759C2e0dF676f7d3D205dF3EBbf88dbf979EA` (created by the SyndicateFactory) — the only sETH in existence (§5).

---

## 2. Method + negative results up front

* **QueueFlushETHClaim — NOT FOUND on mainnet.** No contract with its function selectors (`claim(bytes)=0xc63ff8dd`, `flushClaimDelay()=0xa3bf004a`, `lastClaim(address,bytes)=0xda37edfc`, `totalClaimed(address,bytes)=0x0061cd1b`, `universe()=0x554c1b1f`) exists among the 97 contracts ever created by the protocol deployer `0x64522Bf668846761D5b8DA8DE1053F474c0b7b4D`, the 2 created by `0x0e8989c6…`, or the 7 created by `0xec9aed08…` (selector scan of runtime bytecode; `protocol_creates_selectors.json`). The `QueueFlushClaim(address,bytes)` event (topic `0x9a263ee7…`) has **zero occurrences in the entire chain history** (`raw/queueflush_claim_events_global.json`: "No records found"). Conclusion: the contract was never deployed on mainnet (or was deployed outside these deployers and never used); in any case it holds no ETH and has never paid anything out. Its ABI in `refs/queue_flush_claim.json` likely came from a testnet deployment.
* **ExitedUnknownSweeps — NOT FOUND.** Not in the deployment docs (`stakehouse-dev/contract-deployments` README lists every other protocol address), not identified among the 97 protocol-deployer creates (no candidate exposes DAO-reclaim functions), no events attributable to it. The RuntimeVerification withdrawals audit describes it as a *future* DAO tool ("could also be used…"), suggesting it was never deployed to mainnet. Negative result documented; risk of missed value here is low because it is a pass-through claimer (it would forward ETH, not hold it).
* The two unidentified Sept-2023 creates `0x6560832b1d44b0bbc07d14678cb97d029ae5c8c7` (2,959 bytes, only library-like internal functions per heimdall, 0 ETH) and `0x0fc9f568b84761d4fca150c671183c3dcfbdf9a3` (beacon-like, 0 ETH) are **not** QueueFlush/ExitedUnknownSweeps by selector evidence; both hold 0 ETH.
* **All kETH contracts hold 0 ETH** — kETH is a separate product but shares the Stakehouse stack; checked anyway (§6).

---

## 3. RageQuitAssistant fleet (46 instances) — NEW VALUE: 0.665519 ETH

**Enumeration.** `RageQuitAssistantDeployer` `0xba459271cb1d821f8505abe809c20a4c2bba44b8` emits `NewDeployment(address indexed instance)` (topic `0xfda5a29d…`). Etherscan getLogs yields exactly **46 deployments** between blocks 18,288,663 (2023-10-06) and 20,195,447 (2024-06-29) — i.e. the entire fleet was deployed during the post-withdrawal-upgrade rage-quit wave. Full list: `rqa_assistants.json`; raw logs `raw/rqa_deployer_newdeployment.json`.

**ETH balances at block 26179180** (`ecosystem_balances_final.json`; earlier identical scan at 26178886 in `rqa_balances_block.json`):

| Assistant | ETH | Assistant | ETH |
|---|---:|---|---:|
| `0xcc3f8b14d697fa6ac6c96f7b8a92654983fcc413` | 0.176763 | `0x24db0cc140807533b16a7557c401887fd4637a60` | 0.035496 |
| `0x982366277afcff5f526d578de913b4b8cacc33e1` | 0.145349 | `0x22f789e00acf3ee898ff31d5f33808486c3f5b39` | 0.005480 |
| `0xa374cba6a5f57595472eba15e6db94e4c3c889d6` | 0.119165 | `0x5900b11b400241244142e02c9ca5304817b31dc8` | 0.000474 |
| `0x6aceb6b4915d4d295ed4814207a30fc8c9f24172` | 0.113554 | 20 others | exactly 1 wei each |
| `0xa10a74a9972a9d7cb2cfb8f41ffdef392e5922a8` | 0.069239 | 18 others | 0 |
| | | **Total** | **0.6655193598619644 ETH** |

**Token balances:** none. balanceOf(dETH/savETH/all 7 sETH tokens) = 0 for all 46 at block 26178920 (`rqa_token_balances_block.json`; history in `rqa_tokentx_summary.json` — all tokens were moved out/burned in 2023).

**Live state of the four largest assistants** (`rqa_live_state.json`, block 26179033):

| | `0xcc3f8b14…` | `0x98236627…` | `0xa374cba6…` | `0x6aceb6b4…` |
|---|---|---|---|---|
| registeredNodeRunner | 0xf6195300… | 0x552262a0… | 0x827ce7b3… | 0x754f8c5d… |
| smartWalletOfKnot | 0xf48be8c9… | 0x1ca4bd64… | 0xc92265b6… | 0x5de454d0… |
| claimablePerETH | 1e24 | 1e24 | 1e24 | 1e24 |
| totalClaimed | 32.020216 | 31.992881 | 32.283979 | 31.938926 |
| lastSeenETH | 32.196979 | 32.138231 | 32.403144 | 32.052481 |
| totalETHReceivedFromRageQuit | 32.196979 | 32.138231 | 32.403144 | 32.052481 |
| isFullWithdrawalExecuted | true | true | true | true |
| collateralisedBalancesAtRageQuitLength | 1 | 1 | 1 | 1 |
| dETHRequiredForIsolation | 24.0156 | 24.0534 | 24.0000 | 24.0789 |
| sETHTokenForLSDHouse | 0xa96d93fb… | 0xa96d93fb… | 0xa96d93fb… | 0x99c5cabb… |

The residual balance is `lastSeenETH − totalClaimed` (e.g. cc3f: 32.196979 − 32.020216 = 0.176763 ETH — exactly the current balance). All 46 assistants are beacon proxies (beacon `0xd6d62803ad87a0d0e54a4e61e2f1f8790dd124c0` → impl `0x8900cfa096ca9480176f06de6436b782ad91bf8c`).

**Who can claim, and how (from the published interface `IRageQuitAssistant.sol`, npm `@blockswaplab/stakehouse-contract-interfaces@1.0.20`, extracted to `web_evidence` context; semantics verified against call history):**

* `executeFullWithdrawal(...)` — already done for all 46 (see §4). Anyone may call it, but it requires an EIP-712 signature from the designated verifier `0x9785f8e50229ebd2b3788452abc31d1942394e0c` (verified on-chain: `isDesignatedVerifier(0x9785f8e5…) = true` on both FullWithdrawals and SweepReporter). **Dormant: this signature can no longer be produced while the reporter is dead (§ web_research), which is why the 64.3 ETH in AccountManager is stuck for knots not yet fully withdrawn.**
* `distributeETH()` — permissionless accounting update (updates `claimablePerETH` from newly arrived ETH).
* `dETHClaim(uint256)` / `sETHClaim(uint256)` — LP holders burn their `rdETH`/`rsETH` RageQuit LP tokens and receive ETH pro-rata; permissionless to call, funds go to the LP token holder.
* `nodeOperatorClaim()` — "LSD node operator or ZEC council" receives the node-runner share; callable by anyone, pays `registeredNodeRunner`.
* `collateralisedSlotOwnerClaim(uint256)` — slot owners who topped up the slot receive their share.
* `dETHWithdrawal(uint256)` / `sETHWithdrawal(uint256)` — LP exit for deposits made before the rage quit.
* `prepareRageQuit()` — restricted: only the LSD LiquidStakingManager or the TransactionRouter can call (interface comment + decompiled guard `Not authorised`).

**Proof that the leftover is still claimable by a known party:** for assistant `0xcc3f8b14…`, its `dETHRageQuitLP()` is `0x0b5e52c0187b7bd71680073b68a302181afca1fa` ("rdETH"), total supply **0.175437**, 100% held by `0x1E8E121c97Be5a590f44d0bDe9942c107B0be951` — which is the **savETH Vault of LSD network `0x12670b896176c37913e62297e059ec5a00d5a171`** (the vault that also holds 4.839 savETH). The 0.176763 ETH residual ≈ the outstanding rdETH claim, so it is recoverable via `dETHClaim` by that vault's beneficiaries, not lost (`ragequit_lp_supplies.json`, `raw/bs_holders_*`).

**Aux-address sweep (138 unique addresses = smart wallets + LP pairs + node-runner EOAs):** total 8.239350 ETH (`rqa_aux_eth_totals.json`). Token balances: only 2 dust entries (0.001 dETH at `0x634c594d…`, 5.3e-6 dETH at `0x85535e08…`; `rqa_aux_token_balances.json`). Top ETH holders are all EOAs = node runners' own wallets (user funds, likely node-operator payouts; out of scope for protocol custody but noted).

---

## 4. Withdrawal-upgrade contracts + FullWithdrawalExecuted claimants

* `SweepReporter` proxy `0x64f4fCFb…` = 0 ETH; impl `0xdf39face…` = 0 ETH; `FullWithdrawals` proxy `0x8F6839b0…` = 0 ETH; impl `0xb4d61d73…` = 0 ETH.
* `FullWithdrawalExecuted(address claimant, uint256 amount)`: **48 events, 1,557.451161 ETH total, blocks 18,336,428 → 20,234,472 (2023-10-12 → 2024-07-04)** (`fullwithdrawal_executed_events.json`).
* Claimants: 46 are RageQuitAssistant instances (matching §3 list). The 2 non-assistant claimants:
  * `0xa514605e50f9e3a5fc4ad3eafdb6edfcce264e59` — GnosisSafeProxy (created by Safe factory), claimed 33.569872 ETH at block 19,034,546; **balance now 0** (holds 1 wei SHNFT).
  * `0x4553e3bc6327006a63c5aa4cdac887f66b6a433e` — EOA, claimed 32.065710 ETH at block 19,626,256 (2024-04-10) via `reportFinalSweepAndWithdraw`; **balance now 0.000137 ETH**.
* No Stakehouse contract appears in the claimant list.

---

## 5. LSD ecosystem (23 networks, factory, giant pools)

**Enumeration.** `LSDNFactory` `0x6EDd4DDa4F879541A67366bca844b2D78cC3850A` (impl `0x0fc94b5a…`) emitted `LSDNDeployed(address indexed LiquidStakingManager)` (topic `0x185c3f05…`) **23 times**, blocks 16,722,031 (2023-02-27) → 21,415,081 (2024-12-16 — the last network was deployed *after* the handover). Per-manager `savETHVault()` and `stakingFundsVault()` were read on-chain and balances checked (`lsd_networks.json`, `raw/lsd_factory_lsdn_deployed.json`, `lsd_networks_state.json`, `lsd_eth_balances.json`, `ecosystem_balances_final.json`).

**ETH findings (block 26178916 / 26179180 — identical to the wei):**

| Contract | Network (LSM) | ETH |
|---|---|---:|
| Giant Fees & MEV Pool `0x04e5c93f…` | (factory-level) | **7.410914** |
| StakingFundsVault `0x941208d2…` | LSM `0x12670b89…` | 0.141908 |
| Giant Protected Staking Pool `0xf5d92b01…` | (factory-level) | 0.095158 |
| StakingFundsVault `0x868afedd…` | LSM `0x8a7a6d99…` | 0.087352 |
| StakingFundsVault `0xdde8f21f…` | LSM `0x61449ee4…` | 0.012327 |
| StakingFundsVault `0xdff2a262…` | LSM `0xf8bfe8fa…` | 0.011803 |
| savETHVault `0x44cd01d4…` | LSM `0x8a7a6d99…` | 0.011000 |
| StakingFundsVault `0x37a54f45…` | LSM `0xb0c5ed6e…` | 0.000004 |
| all 23 LSMs, all other 22 savETH vaults, all other SFVs | — | 0 |

**Token findings (block 26178919, `lsd_token_balances.json`):** dETH/WETH/sETH balances are zero everywhere in the LSD system. The only meaningful token positions are:
* savETHVault `0x1e8e121c97be5a590f44d0bde9942c107b0be951` (LSM `0x12670b89…`) holds **4.839255 savETH** (98.5% of savETH supply).
* Giant Protected Staking Pool holds 4 savETH-vault LP tokens ("dstETH"): 5.25 + 0.114585 + 0.1 + 0.08 = **5.5446 dstETH** (100% of each token's supply; `raw/bs_addr_tokens_giantSavETHPool.json`).
* Giant Fees & MEV Pool holds WETH dust (1e-7) and a set of unsolicited memecoins (PCHS 102.85, MALLY 2326.1, KONG 102.9, yRise, FAM, DIXT, QCORE) — airdrop/spam, no ETH value.

**Pool status:** both giant pools are **not paused** (`paused()=false`), owner = `LSDKontroller` `0x7F79A6Ea8094e63B49b508a60A7b333b51d043cd` (0 ETH). The Kontroller's `DAO()` = `0x8869a94df9200c75116a285e12e85c24179129e1` = **BSNGovernor** (on-chain Blockswap DAO governor; 0 ETH). GiantLP supplies: GiantSavETHPool 5.628596, GiantFeesAndMev 5.957 — i.e. the 7.41 ETH pool backs 5.957 withdrawable GiantLP (≈1.24 ETH/LP including accrued rewards). Users retain withdrawal functions (`withdrawETH`, `withdrawLP`, `claimRewards`; not paused).

**sETH tokens (7 deployed, from SlotRegistry.stakeHouseShareTokens):** only `0x43ed0df8339a81e174f56e516c5c4c3f91985877` has any supply — **12.0 sETH**, 1 holder: Syndicate `0x80f759C2e0dF676f7d3D205dF3EBbf88dbf979EA` (creator = SyndicateFactory `0xe01e2065…`). The other 6 sETH tokens (0x761214c9, 0x99c5cabb, 0x747ab18b, 0xa96d93fb, 0x794895cf, 0xed963b7c) have **0 supply**. The 16 LSD networks whose `stakeHouseShareTokens()` returned `0x0` never had sETH minted (no knot ever registered or stakehouse never created).

---

## 6. dETH / savETH token supplies and top holders (Blockscout + RPC)

| Token | Address | totalSupply | Holders | Top holders |
|---|---|---:|---:|---|
| dETH | `0x3d1E5Cf16077F349e999d6b21A4f646e83Cd90c5` | 16.887594206 | 44 | `0x992c5dCd…` 10.645816; `0x8c814DF5…` (DLP) 4.149012; Curve dETH/frxETH pool `0x7C0d189E…` 1.270519; `0x969271dB…` 0.172835; Curve fee receiver 0.169538; GPv2Settlement 0.138525; **SweepReporter 0.1**; CowSwapBurner 0.094462; … |
| savETH | `0x00ee7ea7ca2b5cc47908f0cad1f296efbde1402e` | 4.910564466 | 5 | savETHVault `0x1E8E121c…` 4.839255; kETH Strategy `0xa060a5F8…` 0.070881; kETH dETH Vault `0x4c7aF9Bd…` 0.000428; dust 4e-18/1e-18 |
| sETH (only live one) | `0x43ed0df8…` | 12.0 | 1 | Syndicate `0x80f759C2…` 12.0 |

Raw: `raw/bs_token_*.json`, `raw/bs_holders_*.json`.

**kETH ecosystem (adjacent product):** dETH Vault `0x4c7aF9Bd…`, kETH Vault `0xE0C28A5A…`, kETH Strategy `0xa060a5F8…`, BSN `0x534D1F5E…`, BSN Farming `0x5CeCfAf8…`, kETH Kontroller `0xD7bEFfCD…` — **all 0 ETH** (`keth_ecosystem_balances.json`). Brand NFT `0x53975f26…`, Community Central `0xcf74685c…`, Loot Factory `0x1eb10469…`, Loot NFT `0x2a86d26e…` — **all 0 ETH**. (kETH Strategy does hold 0.0709 savETH — token value, listed above.)

---

## 7. Contracts explicitly checked and found at 0 ETH (negative results, block 26179180)

StakeHouseUniverse `0xC6306C52…`; TransactionRouter `0x03F4310b…`; SLOTRegistry `0xC01DC3c7…`; savETHRegistry `0x88E6c707…`; savETHTransactionRouter `0x9CbC2Bf7…`; savETHBatchRouter `0x1D1f35aA…`; dETH `0x3d1E5Cf1…`; savETH `0x00ee7ea7…`; SweepReporter `0x64f4fCFb…`; FullWithdrawals `0x8F6839b0…`; LSD Kontroller `0x7F79A6Ea…`; SafeBox `0x8035a7Ab…`; BSNGovernor `0x8869A94d…`; LSD factory + all impls/beacons/deployers (`lsmBeacon 0x84addecf`, `lsmImpl 0x20fd48b1`, `savETHVaultDeployer 0xfe467852`, `stakingFundsVaultDeployer 0x4773ce9c`, `syndicateFactory 0xe01e2065`, `smartWalletFactory 0xe543dfab`, `lsdFactoryImpl 0x0fc94b5a`, `0x6560832b`, `0x0fc9f568`, `0xe2500991`); RQA deployer `0xba459271…`, RQA impls `0x8900cfa0`/`0xdc23daba`, RQA beacon `0xd6d62803`, RQLP beacon `0x5142fc49`/impl `0x1203100a`; protocol deployer EOA `0x64522Bf6…` (0 ETH); DepositRouter signer `0x9785f8e5…` (0 ETH, 0 txs ever). Full per-address list: `ecosystem_balances_final.json` (154 rows) and the generated table below.

---

## 8. Full address table (all addresses checked, block 26179180)

<!-- TABLE_START -->
| Address | What | ETH at block 26179180 | Notes |
|---|---|---:|---|
| `0xdd6e67942a9566a70446f7400a21240c5f71377c` | AccountManager | 64.305717944 | known triage pot |
| `0x8869a94df9200c75116a285e12e85c24179129e1` | BSNGovernor | 0 |  |
| `0x8f6839b0acd8d7c7d2f01c1c7ecca982ca354333` | FullWithdrawals | 0 |  |
| `0x7f79a6ea8094e63b49b508a60a7b333b51d043cd` | LSDKontroller | 0 |  |
| `0xc01dc3c7f83b12cfdf6c0aaa09c880eb45c48569` | SLOTRegistry | 0 |  |
| `0x8035a7ab484d57a5a82469e0d6a38b2c942afbef` | SafeBox | 0 |  |
| `0xc6306c52ea0405d3630249f202751ae3043056bd` | StakeHouseUniverse | 0 |  |
| `0x64f4fcfb8377deaabf334ed42ac113e6813a55d0` | SweepReporter | 0 |  |
| `0x03f4310bfe3968934bc11dfa17b8df809d7dea80` | TransactionRouter | 0 |  |
| `0x3d1e5cf16077f349e999d6b21a4f646e83cd90c5` | dETH | 0 |  |
| `0x00ee7ea7ca2b5cc47908f0cad1f296efbde1402e` | savETH | 0 |  |
| `0x1d1f35aa28ac454da4b11b89971f5f8e6b207d37` | savETHBatchRouter | 0 |  |
| `0x88e6c7072b867f9546a232548a5d3271986b3c0c` | savETHRegistry | 0 |  |
| `0x9cbc2bf747510731ee3a38bf209a299261038369` | savETHTransactionRouter | 0 |  |
| `0xd6d62803ad87a0d0e54a4e61e2f1f8790dd124c0` | RQA_beacon | 0 | assistant beacon |
| `0x8900cfa096ca9480176f06de6436b782ad91bf8c` | RQA_impl_v2 | 0 |  |
| `0xba459271cb1d821f8505abe809c20a4c2bba44b8` | RageQuitAssistantDeployer | 0 | deployer of the 46 assistants |
| `0xc72bc66d463c2001ec3635a8869f15edb7ad5d29` | RageQuitAssistant[0] | 0 |  |
| `0x2201386e37f64faf53d23f0af40e0a3574f87e31` | RageQuitAssistant[1] | 0 |  |
| `0x5900b11b400241244142e02c9ca5304817b31dc8` | RageQuitAssistant[2] | 0.000473525 |  |
| `0x6aceb6b4915d4d295ed4814207a30fc8c9f24172` | RageQuitAssistant[3] | 0.113554203 |  |
| `0xcd6f46adcb445cd16630029c87e0c684f0a113e5` | RageQuitAssistant[4] | 1 wei |  |
| `0x2eaffcf691c9e04105ead5463103124f697981ab` | RageQuitAssistant[5] | 1 wei |  |
| `0xa10a74a9972a9d7cb2cfb8f41ffdef392e5922a8` | RageQuitAssistant[6] | 0.069239299 |  |
| `0xa374cba6a5f57595472eba15e6db94e4c3c889d6` | RageQuitAssistant[7] | 0.119164689 |  |
| `0x3e6b43aa0fe4f41e2744635085d13c32064a19e6` | RageQuitAssistant[8] | 1 wei |  |
| `0xad49d643624bec199e1b4a2d8c68e7baf4b86583` | RageQuitAssistant[9] | 1 wei |  |
| `0xedc5d5da4c587441540fc4074d7fd358c450014c` | RageQuitAssistant[10] | 0 |  |
| `0x6b5ca95dc94a6ebaf603ff06339ea88c3c1ce600` | RageQuitAssistant[11] | 0 |  |
| `0xb69c9a96f5008da2ff2d0536c03e2ee68c1a5912` | RageQuitAssistant[12] | 1 wei |  |
| `0x24db0cc140807533b16a7557c401887fd4637a60` | RageQuitAssistant[13] | 0.035495883 |  |
| `0x351c3b06d1dcc01c5b45ba7c7da51f9ce748f6b1` | RageQuitAssistant[14] | 0 |  |
| `0xf36b4cfe8c6f250836c114ab8fac49d5e4dc2b85` | RageQuitAssistant[15] | 1 wei |  |
| `0xcc3f8b14d697fa6ac6c96f7b8a92654983fcc413` | RageQuitAssistant[16] | 0.176762519 |  |
| `0x982366277afcff5f526d578de913b4b8cacc33e1` | RageQuitAssistant[17] | 0.145349497 |  |
| `0x22f789e00acf3ee898ff31d5f33808486c3f5b39` | RageQuitAssistant[18] | 0.005479745 |  |
| `0xd7edecfac7f8d045089d2a3d38859f610e02c3ce` | RageQuitAssistant[19] | 0 |  |
| `0xfeb8a2aa91d0d974543990fc034459b648380766` | RageQuitAssistant[20] | 0 |  |
| `0x4963c72b1cc89a64a9f2daaa482fc6c8091f0506` | RageQuitAssistant[21] | 1 wei |  |
| `0xc7ea685b7bf0b9a404020ee5d1d0607ed59afbd1` | RageQuitAssistant[22] | 1 wei |  |
| `0x2055926bd2e7f8cc189f2b7c96f18ecfcaae5104` | RageQuitAssistant[23] | 0 |  |
| `0xb9eb6307e29c75b33245d4999d15514aa64ad27e` | RageQuitAssistant[24] | 1 wei |  |
| `0x0a1e5d5de531070934c10cac709704d38a913753` | RageQuitAssistant[25] | 1 wei |  |
| `0x75ff81ae9ba2590dba8e1694f34f005f6cc5051b` | RageQuitAssistant[26] | 0 |  |
| `0x63a34c0b7e8950b832ae211e7a956213fa2a0f79` | RageQuitAssistant[27] | 1 wei |  |
| `0xa0b712d0818625b17e15abee334426c4802156f2` | RageQuitAssistant[28] | 0 |  |
| `0xb9380b3d6e6784047ab10ba4fc38dbb602023f55` | RageQuitAssistant[29] | 0 |  |
| `0x96241c8e4b237adf5fa0d9b1d873d1a5ddefa781` | RageQuitAssistant[30] | 0 |  |
| `0x19fcfcac310043d1418b27825decd40c57eec83b` | RageQuitAssistant[31] | 0 |  |
| `0x03103aacb3d5a6c5de4ac2407e746682b8b22432` | RageQuitAssistant[32] | 1 wei |  |
| `0xe2e1737bab608b9f68e57bb13019a20d415271cb` | RageQuitAssistant[33] | 1 wei |  |
| `0x3a480c52382dabdebf1c3f3887f6802e2bda03e6` | RageQuitAssistant[34] | 0 |  |
| `0xf1b35777dedd9212c11db067ff0da951a04c2178` | RageQuitAssistant[35] | 1 wei |  |
| `0x34823172769a5c2b3bde2b8ae2cf3f3dfb8cae2f` | RageQuitAssistant[36] | 0 |  |
| `0xa45c30514405d92f076c14514e9fe71be68b1a99` | RageQuitAssistant[37] | 0 |  |
| `0x0ad08a233ea3a9826575b160052927f26fa6f4d3` | RageQuitAssistant[38] | 1 wei |  |
| `0xffdd0dbc054fe50827be0b4a9429e92ec9259d2f` | RageQuitAssistant[39] | 0 |  |
| `0xa566cb1dc23109ae6878f44183614942046342c2` | RageQuitAssistant[40] | 1 wei |  |
| `0x520457ed9f68907d82347ccf67acb2b4a0ca38a9` | RageQuitAssistant[41] | 1 wei |  |
| `0xd95564f53ebd8309fa75d91b4ccff757da3a6dd1` | RageQuitAssistant[42] | 1 wei |  |
| `0x73592905e6df226b2847053ac7024aac64902529` | RageQuitAssistant[43] | 0 |  |
| `0x28e3f486f341f8e826baf265e48123d926dc29ef` | RageQuitAssistant[44] | 1 wei |  |
| `0xc9129b1ad311c0e5fd17d4ed6ce75046997d1b51` | RageQuitAssistant[45] | 1 wei |  |
| `0x6edd4dda4f879541a67366bca844b2d78cc3850a` | LSD_Factory | 0 |  |
| `0x04e5c93f4b96d2fdb2cde4c9826c373e5656796e` | lsdFactory_giantFeesAndMev | 7.410914188 | NEW; not paused; backs 5.957 GiantLP; +WETH dust + memecoins |
| `0xf5d92b01c478273bd13aa8efb130d98e131ecbb9` | lsdFactory_giantSavETHPool | 0.095157682 | NEW; not paused; +5.5446 dstETH LP tokens |
| `0x84addecf4ef9c3a832d540945baf32e0633f8c6b` | lsdFactory_lsmBeacon | 0 |  |
| `0x20fd48b12e3e5a1f07832a271eeae13d16bad221` | lsdFactory_lsmImpl | 0 |  |
| `0xfe46785236029f286cc0419e10e8aed07455d81a` | lsdFactory_savETHVaultDeployer | 0 |  |
| `0xe543dfababee1142e319f01295c1aa2a2884fe51` | lsdFactory_smartWalletFactory | 0 |  |
| `0x4773ce9c3962b9e1f734f9316efe5d0dcb3b06e9` | lsdFactory_stakingFundsVaultDeployer | 0 |  |
| `0xe01e2065f6468004c9abda7c4832a8138cf4b854` | lsdFactory_syndicateFactory | 0 |  |
| `0x02c1531f29d5e49b079d088c8187d599087c7dd5` | LSM[0] | 0 |  |
| `0x8a7a6d99ec388684d9afdf69c12c9c829fa6b285` | LSM[1] | 0 |  |
| `0xd317c97545be1ad598af0ca60412d6bf05dacd43` | LSM[2] | 0 |  |
| `0xb0c5ed6e891b2c6718c5fbef8ccdb59ad87b51d4` | LSM[3] | 0 |  |
| `0x12670b896176c37913e62297e059ec5a00d5a171` | LSM[4] | 0 |  |
| `0x59a14b92d7c32a59beaab2dad96809d20bac244a` | LSM[5] | 0 |  |
| `0xb511d65c23101493dbecc6d93ec3a8677ebbdcf4` | LSM[6] | 0 |  |
| `0x4c171a2e863b68b74150a662dd8cc7e5987d8808` | LSM[7] | 0 |  |
| `0xf616ee0001843f89d8e1294796e3ab3c403c6a1f` | LSM[8] | 0 |  |
| `0x1963bf8bcaccb26a0c431a8297e709322e51a63d` | LSM[9] | 0 |  |
| `0x831138ee43b1f230c0769a23e341e570eeac9452` | LSM[10] | 0 |  |
| `0x429d8801649e0cbe266f7bf887deda80d263604d` | LSM[11] | 0 |  |
| `0x61449ee4b556724e7a5bb8419af9dff142818139` | LSM[12] | 0 |  |
| `0x2435f3ce0738564bdc9262039a587fb3b03392cf` | LSM[13] | 0 |  |
| `0x41392d54060f27406de7c049735ce96d3cc6fb15` | LSM[14] | 0 |  |
| `0x62ee45b26f4deb7128d486167f7ade65d5157bf8` | LSM[15] | 0 |  |
| `0x8930410e9bcd7df01af74ca7945deda35b39f06c` | LSM[16] | 0 |  |
| `0x9f62d0caf106d793561e99db3153817856ec2127` | LSM[17] | 0 |  |
| `0xf8bfe8faecdf6327609a6d3c4f1a5177450dd447` | LSM[18] | 0 |  |
| `0xe2cf44c37b5b1dee88a3836037a4e18853c71d2a` | LSM[19] | 0 |  |
| `0xad15db52b38f0f866465ce7a347b623d62cc8b2a` | LSM[20] | 0 |  |
| `0xb688a6fbe27f6183b5da27a8300a5d10615f308e` | LSM[21] | 0 |  |
| `0x33d90d998678a41e0d2e49b1ccfa500e2f91c3f3` | LSM[22] | 0 |  |
| `0x952444255822fa4f3e9a8bed42655dadecfe8c6a` | savETHVault[0] | 0 |  |
| `0x44cd01d41c49e49f9df6e6812c2c8131c3491e96` | savETHVault[1] | 0.011 | savETHVault of network 0x8a7a6d99 |
| `0x9396a2481be1fa8dedea7840ac8631845122e142` | savETHVault[2] | 0 |  |
| `0x06fe7b73bdcd9b5fcc08d7d214bf60719688e509` | savETHVault[3] | 0 |  |
| `0x1e8e121c97be5a590f44d0bde9942c107b0be951` | savETHVault[4] | 1 wei | savETHVault[4]; 4.839255 savETH + 0.175437 rdETH LP (claim on assistant cc3f) |
| `0xd23fca8b3e6908e0bacfc88fb444cad36efbbf8b` | savETHVault[5] | 0 |  |
| `0x502b7203b4468f05869caa051a8212483f9b581d` | savETHVault[6] | 0 |  |
| `0xb351501d0fe260a19d73fcaf12964beef96e9df3` | savETHVault[7] | 0 |  |
| `0x85951dc118754581b5da565d9da06013e432cd45` | savETHVault[8] | 0 |  |
| `0x694173481efb2c8e1f0b368870ccd195087918e5` | savETHVault[9] | 0 |  |
| `0x8534721413a1818a46ab77d6bb0dcc7ef0504fad` | savETHVault[10] | 0 |  |
| `0xe8395c43ca9becd858ef22ba4c89efeabd212e15` | savETHVault[11] | 0 |  |
| `0x3265c2afbcbd9942aac2e50527348555af4e5010` | savETHVault[12] | 1 wei |  |
| `0x25b4e494c61612601f627cd58439fb8320f395a8` | savETHVault[13] | 0 |  |
| `0xca729ba11d236778f19b2421e5b2a58e420ab781` | savETHVault[14] | 0 |  |
| `0x2171c317dc646daf6f90f34ad81141d049d7f1f7` | savETHVault[15] | 0 |  |
| `0xafab724a78ef718df93212d27411a745f30dc65d` | savETHVault[16] | 0 |  |
| `0x988eba932675427c0056efdb2ca25c2418471c1d` | savETHVault[17] | 0 |  |
| `0xc4b56f18b4e20fe90b6ae3eb5c660ade86d64b18` | savETHVault[18] | 0 |  |
| `0x417109ad94ecaf7c49cca3fdbce0a7a976647994` | savETHVault[19] | 0 |  |
| `0x566ab3747f0d1ad48e94bee15d1fc6550ff59fb0` | savETHVault[20] | 0 |  |
| `0x46fa28df2dc11cfcce7766d17dfc07c56e973dad` | savETHVault[21] | 0 |  |
| `0x25969c87b1a289ec7ef60f693a194f5228510617` | savETHVault[22] | 0 |  |
| `0xcdc1e2a99ac904d40fb9bb9ead88d0ad52d57b7f` | StakingFundsVault[0] | 0 |  |
| `0x868afeddd1f5919e906bf396d115f19c17a0ba3d` | StakingFundsVault[1] | 0.087352019 |  |
| `0x74db3802eb56f80ed30619a3f94fbc5c0cb78d84` | StakingFundsVault[2] | 0 |  |
| `0x37a54f4599cbf827cd90f599234c148e9a8e3d71` | StakingFundsVault[3] | 0.000003861 |  |
| `0x941208d2a5c02142dbd66e02b84e2c75204a2732` | StakingFundsVault[4] | 0.141907787 | SFV of network 0x12670b89 |
| `0xc310dcc3dc7e16fd98cacdd20db5b73a623434e8` | StakingFundsVault[5] | 0 |  |
| `0x8073499728686bba3299361b294ecad19243511a` | StakingFundsVault[6] | 0 |  |
| `0xbda8e821282754b6986c3c1aa8fe74c928c1f459` | StakingFundsVault[7] | 0 |  |
| `0xa1e5313aec09b341ed666e93472f0f31873b10d6` | StakingFundsVault[8] | 0 |  |
| `0xeb220ab5cbe95ddc7a8dd8c71b619004605e9637` | StakingFundsVault[9] | 0 |  |
| `0x9e8eea674a1c73648d97eb2ce22b9a023b4bdadf` | StakingFundsVault[10] | 0 |  |
| `0xa93b6494b76ecb7589dd297d1afbf9aa761fe0a6` | StakingFundsVault[11] | 0 |  |
| `0xdde8f21f73cd65feb2e6b08938701fd6d5814d09` | StakingFundsVault[12] | 0.012326862 |  |
| `0x3bdc2e1f71061349e8c78c27bd9c81ce79df1f62` | StakingFundsVault[13] | 0 |  |
| `0x1056c151f43266a78e3b2f76e06069ad37546dbd` | StakingFundsVault[14] | 0 |  |
| `0x23181ad2c1e0f8923dec746e7eae5d3839d453bb` | StakingFundsVault[15] | 0 |  |
| `0xb4fc02ce723b8bce1429b32eff8f9d45509d1a9c` | StakingFundsVault[16] | 0 |  |
| `0xa2d0c88b5873d23638cb97f2cbf45e9bcb01b4ff` | StakingFundsVault[17] | 0 |  |
| `0xdff2a2628457d10c120a0693bc1b358d577a090b` | StakingFundsVault[18] | 0.011803486 |  |
| `0xdc8dd5703dcd4bee21b717b497198154ff9c8037` | StakingFundsVault[19] | 0 |  |
| `0x37386945682d9f69e70bdcc9d84b79a36a5d5fd6` | StakingFundsVault[20] | 0 |  |
| `0xeeb23ffab3b26e96b29138867ad16a882ee22308` | StakingFundsVault[21] | 0 |  |
| `0xf196b2eab47344f223670045498633b9930f2613` | StakingFundsVault[22] | 0 |  |
| `0x534d1f5e617e0f72a6b06a04aa599839af776a5e` | BSN | 0 |  |
| `0x5cecfaf8f8c2983a3336adbe836af39192a72895` | BSN_Farming | 0 |  |
| `0x53975f264a02eb415602a780af632bc132a20ca7` | BrandNFT | 0 |  |
| `0xcf74685c9865e959329b846a7785c2e126b67f03` | CommunityCentral | 0 |  |
| `0x4553e3bc6327006a63c5aa4cdac887f66b6a433e` | EOA_claimant_4553 | 0.000137246 |  |
| `0xa514605e50f9e3a5fc4ad3eafdb6edfcce264e59` | GnosisSafe_withdrawal | 0 |  |
| `0x1eb1046949e7e1235495dfd672ab3bb71091984d` | LootFactory | 0 |  |
| `0x2a86d26ea4779c3046023eb76b4ae2c9e07abfff` | LootNFT | 0 |  |
| `0x80f759c2e0df676f7d3d205df3ebbf88dbf979ea` | Syndicate_12sETH | 1 wei | Syndicate; holds all 12 sETH |
| `0xd7beffcd21d22b11269cc78240717a136f0341e7` | kETH_Kontroller | 0 |  |
| `0xa060a5f83db8bf08b45cf56db370c9383b7b895c` | kETH_Strategy | 0 |  |
| `0xe0c28a5a2da3920946e8bf821f61f7bea311048b` | kETH_Vault | 0 |  |
| `0x4c7af9bddac5bd3bee9cd2aa2feeeee7610f5a6b` | kETH_dETHVault | 3 wei |  |
<!-- TABLE_END -->

*(The remaining ~65 rows of the table — all 23 LSM/savETHVault/SFV triples with their addresses — are in `ecosystem_balances_final.json`, which is the canonical machine-readable version of this table. Every address in it was individually checked with `eth_getBalance` at block 26179180.)*

---

## 9. Caveats / honesty notes

* **Blocks differ slightly between component scans** (26178886–26179185). All are within ~1 hour on 2026-10-12; nothing moved between them except unobservable-at-this-scale dust. The consolidated table (§8) is single-block (26179180).
* The 64.3 ETH AccountManager balance is **as of the scan**; it is a proxy whose balance changes only when someone triggers `withdrawETH`/top-up flows — no direct EOA transactions to it were found ever (Etherscan: "No transactions found").
* `claimablePerETH = 1e24` in all assistants I read is the post-claim sentinel; it does not mean "1M ETH claimable" (claim math uses it against `totalClaimed`/`lastSeenETH` deltas). Do not read it as a live value.
* Whether the 0.6655 ETH is *practically* recoverable depends on gas vs claim size (per-assistant residue for most is 1 wei; the meaningful ones are the 8 listed). The largest (0.1768 ETH, cc3f) is claimable via `dETHClaim` by savETHVault `0x1e8e121c…`, which is itself a protocol contract whose beneficiaries are that LSD network's depositors.
* The giant-pool 7.41 ETH + 0.0952 ETH are **user-facing pool liquidity** (GiantLP holders), not DAO-owned; they are "live value" in the sense that contracts custody them, but they are owed to depositors.
* USD values intentionally omitted (ETH-denominated only) — avoid price assumptions.
* No Stakehouse contract was found holding value outside the list above. Negative results (QueueFlush, ExitedUnknownSweeps) are based on full-history event scans + full selector scans of every contract the protocol deployer ever created; there is a small residual chance a contract was deployed by an unknown deployer, but no evidence of one exists.

## 10. Evidence index

| File | Contents |
|---|---|
| `ecosystem_balances_final.json` | 154-row consolidated balance table, block 26179180 |
| `rqa_assistants.json` / `raw/rqa_deployer_newdeployment.json` | 46 deployments + raw logs |
| `rqa_balances_block.json` | RQA balances, block 26178886 |
| `rqa_live_state.json` | 4 assistants × 28 getters, block 26179033 |
| `rqa_tokentx_summary.json` / `raw/tokentx_*.json` | token history of all 46 assistants |
| `rqa_aux_addresses.json`, `rqa_aux_eth_totals.json`, `rqa_aux_token_balances.json`, `rqa_aux_top_eth.json` | aux address inventory (138) + balances |
| `ragequit_lp_supplies.json` | rdETH/rsETH LP supplies for assistant cc3f |
| `lsd_networks.json`, `raw/lsd_factory_lsdn_deployed.json` | 23 LSD networks |
| `lsd_networks_state.json` | per-network LSM/savETHVault/SFV/sETH + factory cfg |
| `lsd_eth_balances.json`, `lsd_token_balances.json` | LSD ETH + token balances |
| `keth_ecosystem_balances.json`, `extra_stakehouse_balances.json` | kETH + misc balances |
| `fullwithdrawal_executed_events.json` | 48 FullWithdrawalExecuted events |
| `sweepreported_all.json`, `sweepreported_monthly.json` | 1,931 SweepReported events + monthly histogram |
| `reporter_activity.json`, `reporter_profiles.json` | SweepReporter txs, reporter senders, DepositRouter signer |
| `protocol_deployer_creates.json`, `protocol_creates_selectors.json`, `sept2023_upgrade_contracts.json`, `other_deployers_creates.json` | deployment/selector census (QueueFlush/ExitedUnknown negatives) |
| `raw/queueflush_claim_events_global.json` | zero QueueFlushClaim events chain-wide |
| `raw/bs_token_*.json`, `raw/bs_holders_*.json`, `raw/bs_addr_tokens_*.json` | Blockscout token/holder snapshots |
| `web_evidence/` | DefiLlama JSON + archived forum RSS evidence (see web_research.md) |

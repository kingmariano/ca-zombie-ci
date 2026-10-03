# IntentX / SYMMIO diamond core — unprivileged extraction audit

**Campaign:** read-only adversarial audit of the live IntentX SYMMIO diamond deployments (dead protocol per DefiLlama 2026‑01‑08).
**Question:** can an external, unprivileged attacker extract value TODAY via the deployed diamond code?
**Constraints honored:** no transactions signed/sent, no private keys, RPC reads + web reads only. All writes under `/home/heisenberg/CA/intentx/analysis/core/`.
**Bottom line:** **No unprivileged extraction path was found in the deployed code that is open today.** The residual risks are (a) two unverified PartyB facets whose source is only available upstream (live probes show partyB gating), (b) the Muon TSS/gateway key trust root (key compromise/oracle signing is out of scope for a code audit), and (c) one **privileged** (partyB-only) mispricing primitive (`adlClose`) worth noting for completeness.

---

## 0. Snapshot blocks (all reads pinned to these)

| Read | Base (8453) | Arbitrum (42161) | Mantle (5000) | Blast (81457) |
|---|---|---|---|---|
| `facets()` / code | 52,124,388 | 511,328,523 | 101,453,907 | 41,114,163 |
| live state / balances | 52,125,754 | 511,338,661 | 101,455,297 | 41,115,565 |
| guard probes / `eth_call` | 52,126,682 / 52,127,069 / 52,127,291 / 52,127,357 | — | — | — |

RPCs: Base `https://rpc.ankr.com/base/<key>` (archive eth_getLogs), Arb `https://arb1.arbitrum.io/rpc`, Mantle `https://rpc.mantle.xyz`, Blast `https://blast-rpc.publicnode.com`. Sources via Etherscan V2 `getsourcecode` (chainids 8453/42161/5000/81457).

Live diamond collateral balances (block above):
- Base: **1,018,722.777883 USDC** (`1018722777883`)
- Arb: **591,107.969626 USDC** (`591107969626`)
- Mantle: **61,658.902999059175503421 USDe** (`61658902999059175503421`, 18 dec)
- Blast: **40.5175384338934146 USDB** (`40517538433893414600`, 18 dec)

Pause state (`pauseState()`, block above): Base/Arb/Mantle **all flags = 0 (fully unpaused)**; Blast **`accountingPaused = true`**, all other flags 0.

Ownership: Base owner = `TimelockController 0x92e89bb3ce2cea34df6168010bbefce2997b014d` (contract, created by tx `0xf5efad…`); Arb owner = `0x0cbf07176e67671c99222bebdb166efc58dacd95`; Mantle owner = `0xd02f2cc0c2bc1799ff0674b64620a351f986ebde`; Blast (old build) has no `owner()`.

---

## 1. Facet inventory

### 1.1 Base / Arbitrum / Mantle — 29 facets, 382 selectors each

All three chains run the **same code generation** (IntentX fork of SYMMIO v0.8.5). Bytecode comparison (`cast code` at snapshot block, metadata stripped) shows facet logic is **identical** across the three chains except embedded per-chain addresses of **externally linked libraries** (LibQuoteFunding, LibQuoteClose, LibSettlement, LibForceActions) and Solidity PUSH-size shifts caused by those addresses (e.g. `PUSH20`→`PUSH19`). Verified by diffing runtime code byte-by-byte: every run of differing bytes is a 20-byte address constant (or its push-opcode shift); see `facets/identity_final.json`, `facets/code_hashes.json`.

27/29 facets are verified on Etherscan; **2 are UNVERIFIED** (the PartyB action facets, §3.1).

| # | Facet | Base address | Arb address | Mantle address | Verified |
|---|---|---|---|---|---|
| 00 | DiamondCutFacet | `0x74aa0c998F83e6C164C6D2444b1C3cbc233EF2BC` | `0xF39352ec34A007B2726e2c4610A13F7aEA86684E` | `0x464873026877c9D947E2778a1B4cB4A3CbC688F0` | yes |
| 01 | AccountFacet | `0x61139ecEa179682C494ed9e0b10d7E967440FEe6` | `0x4Bf068778f51C1c470D6d228ef4003d36e0e326B` | `0x695284f22929BDcC0644b4F1E5507101420adBeA` | yes |
| 02 | PartyBAccountFacet | `0x0774aC76179eB5bFac5DD76801a495Bc0Db33233` | `0x4aD00Ade12949e7E791fb256645Faa95D0B743D0` | `0xDbc5EbFb4E7cF72C15A4E35780d789b04eA52978` | yes |
| 03 | PauseControlFacet | `0xD6d97b701b07df7f1567a6834D9a6A139a127b4a` | `0x101Dc298A91D463eB5F772f4D78B0A156E9C1627` | `0x99641E06d38F327166b3a48f86Ca2cbB3B4fB7EB` | yes |
| 04 | SymbolControlFacet | `0x9A71fd5D452c72B07d317477Ce965671d50dE272` | `0x293DD013FAb4c340c14366234Fb0D2606924fBed` | `0x1d821059D7EF2B12244866BB29d840B75DE27cFF` | yes |
| 05 | ControlFacet | `0x30b05c5FDa94c45d4EB2b61854a6cBDAdf62c117` | `0xcF53496BB00D13C05E25446a40457e10fA3647c9` | `0x6aA554A167864027A02051D3F5C553244439B7Fd` | yes |
| 06 | ForceActionsFacet | `0x61c1726B5517e3449ffeb6F50273F0F1aB3181f1` | `0xb5C6e47Efa0715E10767A7D8E0a46D3ED6777b39` | `0xb4627e881A476fa6036C14B6b9Fd26FdAC3F286D` | yes |
| 07 | DiamondLoupeFacet | `0xc83377cF995907121D7F52c44485cdA151dd0F0b` | `0x812e98F31A4EfFC09dD82e6e87ff7456151a0dFB` | `0x07A274cb35c67b941E5d1D254b30E50518347DC3` | yes |
| 08 | PartyALiquidationFacet | `0xA10A8E3dCB69788564362f77b4fa2deB8DF29239` | `0x941655533F19fF686E05ffd842a3E11f94E72983` | `0x626E834b1297b7481E42a0DF2b05ff6F812Bc7E4` | yes |
| 09 | PartyBLiquidationFacet | `0xd84D3af12A1aE5e86505ecCe61Cbd527B4D9E4bD` | `0x2a63626CD2162446a403EAA61A45d0810b0FD649` | `0x1E909012D7e4B07f310449964F02801DFd70117f` | yes |
| 10 | PartyAFacet | `0x617f9f1750d0b1eeAF473B99E7D5bA98869f4D33` | `0x08124f008F38f41e69e9664abaF51953AdCF7Ab4` | `0xa8b175204Db46Fb3cF5db4530724e28DF00b7CF3` | yes |
| 11 | SettlementFacet | `0x775Fa3b63154f7c4a9030C15B132C7a4d127C77b` | `0x3A81e001Fc4fc73146EB36D4c327CC6176F94137` | `0xFC324022f2880087bd4a6D8f13e796Ea2AAF3750` | yes |
| 12 | **UNVERIFIED PartyB positions** | `0x68D482AE815B262C2fBC7227c438a4Ca9cB91DF4` | `0x42b5612870671795Eff958eB761A9BEf1684664D` | `0xb970936fAA0d919DA11A9d0020875F3450b4b7FE` | **no** |
| 13 | PartyBQuoteActionsFacet | `0x3ef4037849a7C4151D90430c399A67A18290088b` | `0x1a58B46A7857AC0F3f2421FCEB8c1bcACaa905B0` | `0xc749da7b75F06f1f2b2fcAE0dE7a5A3bbc501F3E` | yes |
| 14 | PartyBEmergencyActionsFacet | `0x319B5379c45658EFCD2eBB3EFf43A1dA3497df09` | `0xfa91dB12200F784b6e6382F99f7187Ce8ecd4035` | `0x152ca4A0F9246387B184a60065DdA488e4Bd2E7b` | yes |
| 15 | ViewFacet | `0x7538bA7dC3e8698Ee10d73C0Bd8AE88a2eA1CF19` | `0x80707FDF1B3A5e0DD5Da295E428736bB1f728486` | `0x9eF1866E5B275D2f7c4e9780d7b6f719927329CB` | yes |
| 16 | ViewFacetQuote | `0x50A6f5268Be4BeADdd770951EAc1DBDabbAE235c` | `0x87f0c18972e9B2a08290407516A88B92472cb9AA` | `0xcb2c1b28b13f074A57bC8E628Bd0d9F054C2C5C9` | yes |
| 17 | ViewFacetSymbol | `0x626f770e7341a69b12455e1966a3f6Db07f0f2B2` | `0x7404AcB6eB0097bd0111c37bd18AB4828A04BAD9` | `0x53Ec53afbD56dD6538a4dAcdD3c47B718E699556` | yes |
| 18 | FundingRateFacet | `0xe31eCaBb603C658f28cB9C0c3Eff645aC6648ab5` | `0xDe09455699e82f3997c7f41986Ee81638F5116a0` | `0xCB3F2E1f218A94dff5a9fEb3209d09CC9748Eb82` | yes |
| 19 | BridgeFacet | `0x83A854c0661C0E13F581436Cb8921C7c4A17620f` | `0x4fac9812cB2B95d8cF616f7cB471cEee97265734` | `0x68e321BBdc62d69346fAa093Be837912198635a1` | yes |
| 20 | ExternalTransferFacet | `0x4D9bc750Da579770b5caDdE4fa25398bDAD85540` | `0x74415ec35d1279f56beEed99bD46292D9a471935` | `0x8E08e2A9Eb40Bd47AEEe5b8B35F2F2ca314fE7C6` | yes |
| 21 | BindingFacet | `0x34f95010CcDa517e407999C5D2Fc156a4cC3c171` | `0xbf40BECa9Fb74FB67dF4a5C9C99eBAD35e616fFd` | `0xfE03689496ff33fF2a2c45E0C1A1817E4466c055` | yes |
| 22 | PledgeFacet | `0xEC4f0532A37EC385ffEBe542C0cD8cD041283Ad5` | `0xa8383d0C180f4FeA7590571848A58b717e57c4F9` | `0x91312F334a5988aEa2ddA3B9fc26Fc24Ec3A11AF` | yes |
| 23 | MigrationFacet | `0x84dA2dA28eF37e07A2683Ed5850ab88C220dE020` | `0x50c53C109572B77577d76aFf11601c3Ee47242A2` | `0x5D8057A2ae47895A7Ab39A06cBD2F24438298355` | yes |
| 24 | ViewFacetAggregate | `0x356eA4E3A4E7eFbb077ac6AB14bD8D5Dd3713092` | `0x7ee1c2788107A27E7795137892d6C6cf06144897` | `0x9bc1396224Cc602D6B0C92a64C4607cBd261984F` | yes |
| 25 | ForceCloseStepsFacet | `0x9DE224F678Bfa05366b4ab3fF358789b734b3DD2` | `0xa805FE5baA301D4e72C789694F3967452c77D6fD` | `0x63b844A36eB1060C4a11191EE3e94Bd717f652ac` | yes |
| 26 | ClearingHouseFacet | `0x77aa4c9aBAfE2f3b58eF4FD16EB4c8121acc3B52` | `0xf62a670cda28FfAE65eE2a42D6cf6CF05EC5E775` | `0x45CC5665d3E4eC960D0cb74535a478dbDE1F5159` | yes |
| 27 | **UNVERIFIED PartyB batch** | `0xEE572C02099A0BE4E194C5590604958423599B0B` | `0x932f55Ad809feD0Ff417fDFEe7121480bD15f5C7` | `0x65f1D2482B54F9c1b87391CEfc489665D01Ef96e` | **no** |
| 28 | WithdrawFacet | `0x37c64DB434cE941C14145D867c1396223E96c4C9` | `0x43B61088E7f1de1b83edCb55B377752f1DFDe346` | `0xeF30891f4869d96D306397E88Ee3974eDC124073` | yes |

`facets()` map per chain: `facets/base_map.txt`, `facets/arb_map.txt`, `facets/mantle_map.txt` (383 selectors incl. 0x1f931c1c `diamondCut`).

**Externally linked libraries** (embedded as 20-byte constants in facet runtime code; executed via DELEGATECALL):

| Library | Base | Arb | Mantle | Verified |
|---|---|---|---|---|
| LibQuoteFunding | `0x9f094939fdbfbe8081cffbbce61730ac2eda2cdc` | `0xf3e0fc10e5ba38dad1ec9176cbe27fa16d8195bf` | `0xffb625b05f635d149d9a99eb6cff085baa927b2b` | yes |
| LibQuoteClose | `0xf1a2f5fa36ba647c658210f2d41ce8b5e5f6756e` | `0x4aa182a375ac41ab5555c23e624d844a3c615390` | `0x18ecbfab4f8772842bee44b22fa035adbf4c4c4e` | yes |
| LibSettlement | `0x3a429ec4d5c50a7152730e8436bac883093496a3` | `0x2a615938d9e37d8d057bf10d50f5de4cb8d15ee6` | `0x8d9d3be426247c25ca43ff6077b615916130…` | yes |
| LibForceActions | `0x818fae27361bfd48329cd7bd8c8036a487653e91` | `0xd94adf2c3e180b221a66cbefb29296c6a09f…` | `0xd7ea3d948cb112daae0cbdda34ea2d511bbef845` | **no** (source is inside every verified facet closure: `libraries/LibForceActions.sol`) |

Library addresses are baked into immutable runtime code and cannot be redirected. Direct calls to a library execute against the library's own (empty) storage, so they cannot touch diamond state. No `SELFDESTRUCT`; delegatecall sites in the two unverified facets point only at the known libraries above (checked via `cast disassemble`).

### 1.2 Blast — 15 facets, 177 selectors (different, older generation)

Blast is a **distinct, older SYMMIO build** (multi-account era, `MultiAccount`/`SymmioPartyA/B` lineage; facet sizes differ materially from the other chains). All 15 facets are verified. `accountingPaused = true` live (block 41,115,565), which blocks deposits/withdrawals/allocations/bridge/external-transfer/pledge operations.

| Facet | Address | selectors |
|---|---|---|
| DiamondCutFacet | `0x7e6DC84041E33e20Ac4529a84C8e8201Db785237` | 1 |
| AccountFacet | `0x4d5BE5E9B8E0cd46BB34F79045Eeb9941FFD8be2` | 11 |
| ControlFacet | `0xd1559baB2423644ac489Ef52c76AB92B0F05fC01` | 52 |
| ControlFacet (2nd impl) | `0xEF03B00Cb1D9df2a5b3f354d641e7140D4f31950` | 1 |
| DiamondLoupeFacet | `0xb74629900981F2977cd7a8E37052fee0D7a4C395` | 5 |
| LiquidationFacet | `0x9f8f9D8B8bfCcF3D782564e6D9cC09371792c2cb` | 10 |
| PartyAFacet | `0xDEA50824a9e50bd1E9943155938f3b82854b2Eec` | 9 |
| PartyAFacet (2nd impl) | `0x6AE14800C45aE9383db2C3f2eE6019Ebe1E32403` | 1 |
| PartyBFacet | `0x50154e11eDf5D7d528cBc7Ec0D507dDB70B8B1c6` | 8 |
| ViewFacet | `0x8F00a481C046e98FDEe4ea673dF2984376946953` | 64 |
| FundingRateFacet | `0xa46E5D77a18b93803fa0d3641d868DC9bdd381B4` | 1 |
| BlastConfigFacet | `0x4D8e97f44cD90504E790827137334d9a42bbec55` | 6 |
| BlastConfigFacet | `0xbeFd548F4038cb122745FA061bDD976958EB3e21` | 2 |
| BlastConfigFacet | `0xcCCDA5C17dbdb6F786F432239887d6d51B4B9aD8` | 1 |
| BridgeFacet | `0x0e35FA030fd3Bbed41993BC288B7378cC43F39Ac` | 5 |

Blast `LiquidationFacet` access control mirrors the new build: `liquidatePartyA/setSymbolsPrice/deferred*/liquidatePositionsPartyA/liquidatePartyB/liquidatePositionsPartyB` = `onlyRole(LIQUIDATOR_ROLE)`; `settlePartyALiquidation` unguarded; `resolveLiquidationDispute` = DISPUTE_ROLE (`sources/blast/LiquidationFacet_0x9f8f9D8B/...`).

---

## 2. Security-relevant selector → function → facet (all new-build chains)

Base addresses; Arb/Mantle share the same selectors per facet. Full list: `facets/base_map.txt`, `facets/selector_to_sig.json`.

| function | selector | facet | caller |
|---|---|---|---|
| `deposit(uint256)` | `0xb6b55f25` | AccountFacet | signer (msg.sender) |
| `depositFor(address,uint256)` | `0x2f4f21e2` | AccountFacet | signer; credits arbitrary user |
| `withdraw(uint256)` | `0x2e1a7d4d` | AccountFacet | signer + cooldown |
| `withdrawTo(address,uint256)` | `0x205c2878` | AccountFacet | signer + cooldown; sends to arbitrary user |
| `allocate(uint256)` | `0x90ca796b` | AccountFacet | signer |
| `deallocate(uint256,SingleUpnlSig)` | `0xea002a7b` | AccountFacet | signer + Muon |
| `safeDeallocate(uint256,SingleUpnlWithPendingBalanceSig)` | `0xeb5e538e` | AccountFacet | signer + Muon |
| `zeroUpnlDeallocate(uint256)` | `0x1738ca93` | AccountFacet | BALANCE_SETTLER_ROLE (proxy-allowed) |
| `internalTransfer(address,uint256)` | `0x3e7ba166` | AccountFacet | signer → arbitrary user (debit self) |
| `internalTransferToBalance(address,uint256)` | `0xfad846e3` | AccountFacet | BALANCE_SETTLER_ROLE (proxy-allowed) |
| `withdrawSuspendedUserFunds(address,address,uint256)` | `0x1b91c54b` | AccountFacet | SUSPENDED_FUNDS_WITHDRAWER_ROLE |
| `deallocateSuspendedUserFunds(address,uint256)` | `0x9b171f57` | AccountFacet | SUSPENDED_FUNDS_WITHDRAWER_ROLE |
| `virtualDepositFor(address,uint256)` | `0xe0fc7eeb` | AccountFacet | registered virtual provider |
| `depositVirtualFunds(uint256)` | `0xb13f81c4` | AccountFacet | registered virtual provider |
| `virtualDepositAndAllocateFor(address,uint256)` | `0x47034661` | AccountFacet | registered virtual provider |
| `allocateForPartyB(uint256,address)` | `0xcd0bac16` | PartyBAccountFacet | signer must be partyB |
| `deallocateForPartyB(uint256,address,SingleUpnlSig)` | `0xa3b298c9` | PartyBAccountFacet | signer partyB + Muon |
| `transferAllocation(uint256,address,address,SingleUpnlSig)` | `0xdd6801f2` | PartyBAccountFacet | signer partyB + Muon (self origin only) |
| `depositToReserveVault(uint256,address)` | `0x527628b5` | PartyBAccountFacet | signer (any); donates own balance |
| `withdrawFromReserveVault(uint256)` | `0xb074c08d` | PartyBAccountFacet | signer (own vault) |
| `activateCrossPartyB()` | `0x490b64b4` | PartyBAccountFacet | signer partyB; global cross mode currently off |
| `liquidatePartyA(address,LiquidationSig)` | `0x3f65c7f4` | PartyALiquidationFacet | LIQUIDATOR_ROLE |
| `setSymbolsPrice(address,LiquidationSig)` | `0x5e843f74` | PartyALiquidationFacet | LIQUIDATOR_ROLE |
| `liquidatePendingPositionsPartyA(address)` | `0xc81ead74` | PartyALiquidationFacet | LIQUIDATOR_ROLE |
| `liquidatePositionsPartyA(address,uint256[])` | `0x7d50901c` | PartyALiquidationFacet | LIQUIDATOR_ROLE |
| `settlePartyALiquidation(address,address[])` | `0x03f9af79` | PartyALiquidationFacet | **anyone** (precondition-locked, §3.2) |
| `resolveLiquidationDispute(address,address[],int256[],bool)` | `0xb680c57d` | PartyALiquidationFacet | DISPUTE_ROLE |
| `liquidatePartyB(address,address,SingleUpnlSig)` | `0x7e65a279` | PartyBLiquidationFacet | PARTYB_LIQUIDATOR_ROLE |
| `liquidatePositionsPartyB(address,address,QuotePriceSig)` | `0x97b75d61` | PartyBLiquidationFacet | PARTYB_LIQUIDATOR_ROLE |
| `openPosition(uint256,uint256,uint256,PairUpnlAndPriceSig)` | `0xfa59fbe8` | **UNVERIFIED** 0x68D4 | partyB-of-quote + Muon (probe) |
| `fillCloseRequest(uint256,uint256,uint256,PairUpnlAndPriceSig)` | `0xe0020899` | **UNVERIFIED** 0x68D4 | partyB-of-quote + Muon (probe) |
| `fillCloseRequestToLiquidation(uint256,uint256,PairUpnlAndPriceSig)` | `0xb052244f` | **UNVERIFIED** 0x68D4 | partyB-of-quote (probe) |
| `acceptCancelCloseRequest(uint256)` | `0x89b90cd3` | **UNVERIFIED** 0x68D4 | partyB-of-quote (probe) |
| `openPositions(uint256[],uint256[],uint256[],PairUpnlAndPricesSig)` | `0xcb32cdbc` | **UNVERIFIED** 0xEE57 | Muon first, then per-quote partyB (upstream) |
| `fillCloseRequests(uint256[],uint256[],uint256[],PairUpnlAndPricesSig)` | `0xb98ff519` | **UNVERIFIED** 0xEE57 | Muon first, then per-quote partyB (upstream) |
| `emergencyClosePosition(uint256,PairUpnlAndPriceSig)` | `0xa3039431` | PartyBEmergencyActionsFacet | partyB-of-quote + Muon; needs emergency/delisted |
| `adlClose(uint256,uint256,uint256)` | `0x25869929` | PartyBEmergencyActionsFacet | partyB-of-quote + `adlEnabled`; **price arbitrary, no Muon** |
| `sendQuote(…)` family | `0x983af15…` etc. | PartyAFacet | signer |
| `expireQuote(uint256[])` | `0xf2445cd7` | PartyAFacet | **anyone** (expired quotes cleanup) |
| `requestToCancelQuote(uint256)` | `0xa8ffc7ab` | PartyAFacet | partyA-of-quote |
| `requestToClosePosition(...)` | `0x501e891f` | PartyAFacet | partyA-of-quote |
| `requestToCancelCloseRequest(uint256)` | `0xa63b9363` | PartyAFacet | partyA-of-quote |
| `forceCancelQuote(uint256)` | `0x5e1313e7` | ForceActionsFacet | **anyone** after cooldown (CANCEL_PENDING only) |
| `forceCancelCloseRequest(uint256)` | `0xf03e45b9` | ForceActionsFacet | **anyone** after cooldown (CANCEL_CLOSE_PENDING only) |
| `forceClosePosition(uint256,HighLowPriceSig)` | `0x56129889` | ForceActionsFacet | anyone + Muon high/low sig |
| `initializeForceClose / settleUpnlForForceClose / finalizeForceClose / forceCloseAndSettlePositionsUnified` | `0xe66dd4f1…` | ForceCloseStepsFacet | anyone + Muon sig |
| `settleUpnl(SettlementSig,uint256[],address)` | `0x3d6627f7` | SettlementFacet | `onlyPartyB` + Muon; must hold position with partyA |
| `settleUpnlUnified(UnifiedSettlementSig,uint256[])` | `0x615172cc` | SettlementFacet | `onlyPartyB` + Muon |
| `settlePartyBUpnlForLiquidation(...)` | `0x4eb1c6bc` | SettlementFacet | LIQUIDATOR_ROLE |
| `chargeFundingRate / updateAccumulatedFundingFee / chargeAccumulatedFundingFee` | `0xa4d4eadf…` | FundingRateFacet | anyone + Muon `Funding` sig |
| `initiateWithdraw(WithdrawReceiverPart[],bool,bytes)` | `0xb48c2317` | WithdrawFacet | signer, debits immediately |
| `acceptWithdrawRequest(address,uint256)` | `0x90c1ed37` | WithdrawFacet | request's provider contract |
| `rejectWithdrawRequest(address,uint256)` | `0xd8ee6cec` | WithdrawFacet | request's provider contract |
| `finalizeWithdrawRequest(address,uint256)` | `0x1531b3c8` | WithdrawFacet | **anyone** after cooldown (targets fixed at initiate) |
| `requestCancelWithdraw(uint256)` | `0xe8262b31` | WithdrawFacet | signer (request owner) |
| `acceptWithdrawCancelRequest(address,uint256)` | `0x448332f7` | WithdrawFacet | request's provider contract |
| `forceCancelWithdraw(address,uint256)` | `0xed839fc8` | WithdrawFacet | WITHDRAW_FORCE_CANCEL_ROLE |
| `suspendWithdrawRequest(address,uint256)` | `0x339fc599` | WithdrawFacet | SUSPENDER_ROLE |
| `acceptSpeedUpRequest(address,uint256,uint256)` | `0x8fe62f6e` | WithdrawFacet | WITHDRAW_SPEED_UP_ROLE |
| `transferToBridge(uint256,address)` | `0x4760bc29` | BridgeFacet | signer; registered bridge only |
| `withdrawReceivedBridgeValue(uint256)` | `0x6c132520` | BridgeFacet | the transaction's registered bridge + cooldown |
| `externalTransfer(address,uint256,address)` | `0x5d6d370b` | ExternalTransferFacet | signer → whitelisted target relayer |
| `virtualExternalTransfer(address,uint256,address,address)` | `0xd45c30de` | ExternalTransferFacet | signer; registered virtual provider |
| `acceptVirtualExternalTransfer(uint256)` | `0xaf27c2d3` | ExternalTransferFacet | assigned provider |
| `depositPledge(address,uint256)` | `0xa3550344` | PledgeFacet | signer (any token) |
| `requestPledgeWithdraw(address,uint256,address)` | `0xfd1d5733` | PledgeFacet | signer (own pledge) |
| `acceptPledgeWithdraw(address,uint256,address)` | `0x81f01e1f` | PledgeFacet | PARTY_B_MANAGER_ROLE |
| `slashPledge(address,address,uint256,address)` | `0x136b7f6e` | PledgeFacet | PARTY_B_MANAGER_ROLE |
| `migrateQuotes(uint256[])` | `0x4cb4d82c` | MigrationFacet | MIGRATION_ROLE |
| `migrateCrossLockedValues(address,address[])` | `0x4612c2e7` | MigrationFacet | MIGRATION_ROLE |
| `takeoverPartyALiquidation + all CH functions` | `0x…` | ClearingHouseFacet | CLEARING_HOUSE_ROLE / SOFT_LIQUIDATOR_ROLE |
| `grantRole(address,bytes32)` | `0xab2742dc` | ControlFacet | role-admin / DEFAULT_ADMIN |
| `setCollateral(address)` | `0x886abef5` | ControlFacet | DEFAULT_ADMIN |
| `setSignatureVerifierAddress(address)` | `0xc2b8c9b5` | ControlFacet | DEFAULT_ADMIN |
| `setSigner(address)` | `0x6c19e783` | ControlFacet | SIGNER_ADMIN_ROLE (proxy-allowed) |
| `setMuonConfig(uint256,uint256)` / `setMuonIds(uint256)` | `0x0be41b62` / `0x799137c4` | ControlFacet | MUON_SETTER_ROLE |
| `pause*/unpause*` | `0x…` | PauseControlFacet | PAUSER/UNPAUSER/EMERGENCY_ADMIN |
| `hasRole(address,bytes32)` | `0x1f45baef` | ViewFacet | anyone (view) |
| `getMuonConfig() / getSignatureVerifier() / pauseState()` | `0x464a8f22` / `0x904fa60d` / `0x9c2c5bb5` | ViewFacet | anyone (view) |

---

## 3. Candidate unprivileged extraction paths (ranked)

### 3.1 Two unverified PartyB facets (`0x68D4…`, `0xEE57…`) — CLOSED, residual source risk
- These are the only on-chain contracts with no verified source. Function sets recovered via 4byte/openchain and selector analysis:
  - `0x68D4` = PartyB position actions: `openPosition`, `fillCloseRequest`, `fillCloseRequestToLiquidation`, `acceptCancelCloseRequest` (selector map §2).
  - `0xEE57` = PartyB batch actions: `openPositions`, `fillCloseRequests`.
- **Live probe evidence (Base, block 52,126,682, caller `0x…dEaD`, read-only `eth_call`):**
  ```
  openPosition(1,0,0,zerosig)               -> revert "Accessibility: Should be partyB of quote"
  fillCloseRequest(1,0,0,zerosig)           -> revert "Accessibility: Should be partyB of quote"
  fillCloseRequestToLiquidation(1,0,zerosig)-> revert "Accessibility: Should be partyB of quote"
  acceptCancelCloseRequest(1)               -> revert "Accessibility: Should be partyB of quote"
  openPositions([1],[0],[0],zerosig)        -> revert "LibMuon: Expired signature" (Muon checked before loop)
  fillCloseRequests([1],[0],[0],zerosig)    -> revert "LibMuon: Expired signature"
  ```
- Upstream `SYMM-IO/protocol-core@0.8.5` `PartyBPositionActionsFacet`/`PartyBBatchActionsFacet` show the same ordering: single functions gate on `onlyPartyBOfQuote` (msg.sender == quote.partyB); batch functions verify a Muon `PairUpnlAndPricesSig` bound to the quote/party/nonce data and then require `quote.partyB == msg.sender` per quote (`upstream/0.8.5/contracts/facets/PartyBBatchActions/PartyBBatchActionsFacetImpl.sol:44`).
- Disassembly of both unverified facets shows their only DELEGATECALL targets are the known linked libraries (`0x9f09…` LibQuoteFunding, `0xf1a2…` LibQuoteClose), consistent with the same IntentX build.
- `fillCloseRequestToLiquidation` does **not** exist in upstream 0.8.5 — it is IntentX-specific. Its selector is gated by the same `onlyPartyBOfQuote` (probe above), but its full body cannot be verified from source. **Residual risk: LOW; cannot be fully excluded without bytecode decompilation.**
- A registered partyB (16 addresses on Base, all `isPartyB()==true` at block 52,127,069) is privileged by design; see §3.6 for the one mispricing primitive we found for that role.

### 3.2 `settlePartyALiquidation(partyA, partyBs)` — unguarded but CLOSED
- No modifier and no internal role check (`PartyALiquidationFacet.sol:113`; impl `PartyALiquidationFacetImpl.sol:330`), so anyone can call it.
- Preconditions: `liquidationStatus[partyA] == true`, `partyAPositionsCount == 0`, `partyAPendingQuotes == 0`, `!disputed`, `settlementStates[partyA][partyB].pending`. `liquidationStatus` can only be set by `liquidatePartyA`, which is `LIQUIDATOR_ROLE`.
- Live probe at block 52,126,682: `settlePartyALiquidation(0xdEaD,[0x…01])` reverts `LiquidationFacet: PartyA is solvent`.
- Even if a liquidation were pending, settle pays the pre-recorded settlement amounts (no caller-chosen inputs) and pays the liquidation fee to the recorded `liquidators` array; the caller gains nothing. Note (privileged/liveness, not extraction): if only one liquidator was recorded, `allocatedBalances[liquidators[partyA][1]]` is address(0) — half the fee is burned; `resolveLiquidationDispute` is DISPUTE_ROLE.
- Verdict: **not exploitable by an unprivileged attacker** (entry state unreachable without the role).

### 3.3 `finalizeWithdrawRequest(address,uint256)` — permissionless, value-safe; id=0 quirk
- Callable by anyone, transfers collateral only to receivers fixed at `initiateWithdraw` time, requires `block.timestamp >= request.cooldownEndTime` and the request status (`WithdrawFacetImpl.sol:165-225`). It cannot redirect funds, double-pay, or skip the cooldown.
- Edge case found: `_getWithdrawRequest` uses `require(requestId <= lastWithdrawRequestId[user])` (`WithdrawFacetImpl.sol:380`). For any user who never withdrew, `requestId = 0` resolves to an empty request (status enum 0 = PENDING, provider 0) and `finalizeWithdrawRequest(user,0)` **succeeds as a no-op** (empty `parts`, `totalAmount = 0`) — verified live: `finalizeWithdrawRequest(0xdEaD,0) → success 0x` at block 52,126,682. No balance or lock movement (`withdrawLockedBalance -= 0`; no transfers). Not exploitable.
- Provider paths check `msg.sender == withdrawRequest.provider` (`acceptWithdrawRequest`, `rejectWithdrawRequest`, `acceptWithdrawCancelRequest`); express/virtual providers must be registered or whitelisted at initiation. Not exploitable.

### 3.4 Permissionless cleanup functions — CLOSED (no value redirect)
- `expireQuote(uint256[])` (`PartyAFacet.sol:262`, `LibQuoteClose.sol:177`): only for quotes past `deadline`; refunds the open trading fee to the quote's partyA, unlocks pending locked balances, marks EXPIRED (or reverts CLOSE_PENDING quotes to OPENED). All refund targets are derived from the quote, not the caller. Live probe reverted `LibQuote: Invalid state` for a stub id.
- `forceCancelQuote` / `forceCancelCloseRequest` (`ForceActionsFacetImpl.sol:26-66`): anyone after `forceCancelCooldown`/`forceCancelCloseCooldown` (live Base 43200 s / 150 s), but only transition `CANCEL_PENDING → CANCELED` (refunds fee to partyA, releases partyB pending locks) or `CANCEL_CLOSE_PENDING → OPENED`. Executes the request owner's own intent; caller gains nothing.

### 3.5 Muon signature pipeline — CLOSED to forgery; trust root is the TSS/gateway key set
- All balances/prices/UPNL values that drive liquidation, settlement, force-close, funding, and account management are passed through `MuonSignatureVerifier` (`sources/verifier/.../SymmioSignatureVerifier.sol`):
  - TSS verification via `LibMuonV04ClientBase.muonVerify` against registered public keys, **plus per-`MuonFunction` authorization** (`publicKeyPermissions[keyId][func]`).
  - Gateway ECDSA over `hash.toEthSignedMessageHash()` against registered gateway signers, also per-function authorized.
  - Setters (`addPublicKey`, `addGatewaySigner`, `set*Permissions`) are `onlyRole(SETTER_ROLE)`; live SETTER_ROLE and DEFAULT_ADMIN = Gnosis Safe `0x5146C35725d9b8F11A84ebD4a3abe9845698Ada9` (counts = 1 each, verified on-chain at block 52,127,357). No unprivileged setter exists.
- Hash binding (deployed sources, each includes `muonAppId`, `address(this)`, method string, nonces, values, timestamp and `block.chainid`; all verified against upstream 0.8.5 — no weakening found):
  - `LibMuonLiquidation.verifyLiquidationSig` (`LibMuonLiquidation.sol:22-38`): `muonAppId, reqId, liquidationId, address(this), "verifyLiquidationSig", partyA, partyANonces[partyA], upnl, totalUnrealizedLoss, symbolIds[], prices[], timestamp, chainid`.
  - `LibMuonAccount.verifyPartyAUpnl` (`LibMuonAccount.sol:17-29`): `muonAppId, reqId, address(this), partyA, partyANonces[partyA], upnl, timestamp, chainid`; expiration `timestamp + upnlValidTime` (live 60 s on Base/Arb/Mantle).
  - `LibMuonSettlement.verifySettlement` (`LibMuonSettlement.sol:12-52`): `muonAppId, reqId, address(this), "verifySettlement", nonces[] (per-quote partyB), partyANonces[partyA], packed(quoteId,currentPrice,partyBUpnlIndex) per quote, upnlPartyBs[], upnlPartyA, timestamp, chainid`.
  - Settlement `updatedPrices[]` are caller-supplied but must satisfy `_validatePriceInRange(openedPrice, signedCurrentPrice, updatedPrice)` (price must lie between opened price and the Muon-signed current price; `LibSettlement.sol:282-288`), and the caller must be `partyB` with a position or the partyB itself (`SettlementFacet.sol:26` `onlyPartyB`; `LibSettlement.sol:39-42`).
  - PartyB UPNL (`LibMuon.verifyPartyBUpnl`, `LibMuon.sol:56-74`): appId, reqId, `address(this)`, partyB, partyA, partyB nonce (cross-aware), upnl, timestamp, chainid.
  - `MuonFunction` domain separation is enforced in the 4-arg verifier; `verifyQuotePrices` (partyB liquidation) binds quoteIds+prices+chainid and is time-bounded in `PartyBLiquidationFacetImpl.sol:43-48` by `partyBLiquidationTimestamp ± liquidationTimeout` (live 1800 s).
- Live verifiers: Base `0x0Ae899A702b9a7E6fbAd661117F0b1B002eD18F1`, Arb `0x1423D1bB78fbeA2B0980611F6319844fa7063cAf`, Mantle `0x1D6102C4fd0e18aE6C751aC2215e10D534B72689` (identical 8,334-byte code). Base registry: 1 TSS key (x=28816647750548585451357630311330111079635661660584752231799347508659086631222, parity 0), 1 gateway signer `0xF621f85f20BBe733699306D336230184621dBe60`. Main diamond `getSigner()` = 0 on Base/Arb/Mantle (no residual meta-tx signer).
- Verdict: **forging/replaying/oracle-choosing values is not possible from on-chain state alone.** Key compromise of the TSS share/gateway key (off-chain) is the only remaining trust assumption and is out of scope.

### 3.6 `adlClose(uint256,uint256,uint256)` — partyB-only (privileged mispricing primitive, NOT unprivileged)
- Facet modifier only `whenNotPartyBActionsPaused` (`PartyBEmergencyActionsFacet.sol:44`), but impl requires `quote.partyB == signer` and `adlEnabled[signer]` (`PartyBEmergencyActionsFacetImpl.sol:62-63`), plus solvency/liquidation guards. Live probe from random caller reverts `PartyBFacet: Sender isn't partyB of quote` (block 52,126,682). `isADLEnabled` for one sampled registered partyB = false at block 52,127,291.
- Because it settles at a **caller-supplied price with no Muon signature**, a malicious/compromised PartyB with `adlEnabled=true` could self-deal against its PartyAs. This is a privileged-role risk, not an unprivileged extraction path; recorded for completeness.

### 3.7 Meta-tx `signer` / AccountLayer integration — CLOSED
- IntentX patched every user-scoped path to `LibSigner.getSigner()` (= `GlobalAppStorage.signer` if set, else `msg.sender`). The only setter is `ControlFacet.setSigner`, `onlyRoleAllowProxy(SIGNER_ADMIN_ROLE)` (`ControlFacet.sol:624`). Live signer = 0 on all three new-build chains.
- The SIGNER_ADMIN + BALANCE_SETTLER role holder on Base is AccountLayer diamond `0x56caf00c6c5cb5478570bb23807b9d1d697863dc` (verified facets: CoreFacet, MarginFacet, SymmioHookFacet, ControlFacet, ViewFacet, AffiliateFacet). Its execution entry points are gated:
  - `_call(account, callDatas)` — `onlyAccountOwner(account)` via `resolveAccountOwner`; blocks the two proxy-only selectors (`CoreFacet.sol:308-365`).
  - `executeForAccount(callData)` — requires an active hook context and `msg.sender == ctx.activeHook`, selector whitelisted per affiliate (`CoreFacet.sol:372-396`).
  - `setSigner` on the AccountLayer — `onlyRole(SIGNER_SETTER_ROLE)`; live AccountLayer `globalSigner = 0`, `paused = false`.
  - Hooks are called with `globalSigner` cleared; signer is reset to 0 immediately after every delegated call (`LibAccountLayerUtils.sol:29-42, 145-169`).
- Arb/Mantle equivalents exist (`BALANCE_SETTLER_ROLE` holders `0xa60ac54e…`, `0xba3d3982…`). No unprivileged entry was found in the wrapper's verified source.
- Note: AccountLayer `_call` forbids only `internalTransferToBalance` and `zeroUpnlDeallocate`; an account owner can still invoke any other diamond function as their own signer (by design).

### 3.8 Linked-library delegatecalls — CLOSED
- The 4 linked libraries are fixed in facet runtime code; three are verified and LibForceActions' source is present in every verified facet closure. No upgrade path. Direct calls execute in the library's own context (no diamond storage/funds).

---

## 4. Negative results (gated / no value movement) with evidence

| Path | Why closed | Evidence |
|---|---|---|
| `AccountFacet.withdraw / withdrawTo` | only signer's own balance; cooldown `deallocateTimestamp[signer] + withdrawCooldownPeriod` (live Base 43200 s); balance ≥ amount checked; no redirect to attacker | `AccountFacetImpl.sol:44-61`; `AccountFacet.sol:80-94` |
| `depositFor / depositAndAllocateFor / virtualDeposit*` | debit is caller's token/balance; credits arbitrary `user` (gift only); virtual paths require `virtualProviders[msg.sender]` | `AccountFacetImpl.sol:22-41`; `AccountFacet.sol:26-75` |
| `internalTransfer(user,amount)` | debits signer only; user ≠ partyB; `notLiquidatedPartyA(user)` | `AccountFacetImpl.sol:143-154`; `AccountFacet.sol:196-206` |
| `zeroUpnlDeallocate` / `internalTransferToBalance` | BALANCE_SETTLER_ROLE only; live holder is the verified AccountLayer | `AccountFacet.sol:184,215` |
| `PartyBAccount.*` | every path is `signer`-scoped and (for Muon paths) signature-verified; `transferAllocation` cannot choose another partyB as origin | `PartyBAccountFacetImpl.sol:19-123` |
| `PartyBQuoteActions.lockQuote/unlockQuote/acceptCancelRequest` | `onlyPartyB` / `onlyPartyBOfQuote` + Muon sig on lock | `PartyBQuoteActionsFacet.sol:21-40` |
| `FundingRateFacet.chargeFundingRate*` | permissionless relay but Muon `Funding` sig binds parties, rates, nonces, timestamp, chainid | `LibMuonFundingRate.sol:18-32` |
| `ForceCloseSteps.*` / `ForceActions.forceClosePosition` | permissionless relay, but Muon HighLowPriceSig binds quote, parties, prices/window, nonces, chainid; solvency enforced; cross-mode blocked | `ForceActionsFacetImpl.sol:69-94`; `LibMuonForceActions.sol:19-40` |
| `BridgeFacet.transferToBridge` | `bridgeLayout.bridges[bridge]` must be registered; debit is signer's balance; `bridge != user` | `BridgeFacetImpl.sol:19-57` |
| `BridgeFacet.withdrawReceivedBridgeValue(s)` | `msg.sender == bridgeTransaction.bridge` + cooldown | `BridgeFacetImpl.sol:60-110` |
| `ExternalTransfer.*` | target must have a registered relayer; debit is signer's balance; accept/cancel are provider/sender-gated | `ExternalTransferFacetImpl.sol:21-115` |
| `Pledge.*` | accept/slash = PARTY_B_MANAGER_ROLE; deposit/request/cancel are signer-scoped and per-token accounting | `PledgeFacet.sol`; `PledgeFacetImpl.sol:13-81` |
| `MigrationFacet.*` | MIGRATION_ROLE | `MigrationFacet.sol:24-38` |
| `ClearingHouseFacet.*` | all 10 mutating functions CLEARING_HOUSE_ROLE (soft liquidation: SOFT_LIQUIDATOR_ROLE) | `ClearingHouseFacet.sol:25-171` |
| `ControlFacet` setters (`grantRole`, `setCollateral`, `setSignatureVerifierAddress`, `setMuonConfig/Ids`, `setLiquidatorShare`, …) | role-gated; owner = Timelock/multisig; no unprivileged setter | `ControlFacet.sol`; live role table §5.3 |
| `PauseControlFacet` | PAUSER/UNPAUSER/EMERGENCY_ADMIN roles | `PauseControlFacet.sol` |
| Blast accounting/trading state | `accountingPaused = true` blocks deposit/withdraw/allocate/bridge/external-transfer/pledge; trading/liquidation facets are the old generation with the same role gating | `live/blast_state.txt` (block 41,115,565); `sources/blast/...` |

### 4.1 Live role holders (grant − revoke from event logs; verified by `hasRole` spot-checks)

Base (block 52,125,754; logs full-range via Ankr):
- DEFAULT_ADMIN / PARTY_B_MANAGER / FEE_ADMIN / DISPUTE / PROTOCOL_CONFIG / COOLDOWN / MUON_SETTER / SUSPENDED_FUNDS_WITHDRAWER / UNPAUSER / EMERGENCY_ADMIN / MIGRATION: GnosisSafe `0x5146c35725d9b8f11a84ebd4a3abe9845698ada9`
- BALANCE_SETTLER + SIGNER_ADMIN: AccountLayer `0x56caf00c6c5cb5478570bb23807b9d1d697863dc`
- LIQUIDATOR (8): `0x153a3c4e…`, `0x1fdc2223…`, `0x31e4e68b…`, `0x6f2f120b…`, `0x75c221d2…`, `0x9bc9ca7e…`, `0xb2679343…`, `0xcf8739af…`, `0xd130f10c…` (sampled ones are EOAs, code size 0)
- PARTYB_LIQUIDATOR: `0x18ad5aa8…`, `0x5653910e…`, `0xc587c76a…`
- PAUSER/SUSPENDER: ops EOAs incl. deployer `0x9bc9ca7e…`
- Symbols: SymbolManager contracts `0x02267ece…`, `0x39e5d7c1…`
- InstantLayer contract `0x0825435285ac0e5c02c7a7c443f631f3e07fe375` (INSTANT_LAYER_ROLE)

Arb (block 511,338,661): DEFAULT_ADMIN + most roles `0xdf4188959bc1711e5b999fc527901daae1630c78`; BALANCE_SETTLER + SIGNER_ADMIN `0xa60ac54e18739f1c4681409383dcf881de3efabe`; LIQUIDATOR `0x18ad5aa8…`, `0x593a40f4…`, `0x5df743f2…`, `0x7ecbeb26…`, `0xc587c76a…`, `0xe7f10000…`; PARTYB_LIQUIDATOR `0x18ad5aa8…`, `0x5653910e…`, `0xc587c76a…`; INSTANT_LAYER `0x4a6a866e…`; UNSUSPENDER `0xdf4188…`.
Mantle (block 101,455,297): admin `0x0c83ff10e8255df41e71006ee6523a23024aafc4`; BALANCE_SETTLER + SIGNER_ADMIN `0xba3d3982dc12acd61fe11ff08ba2164cd1c12c78`; 9 LIQUIDATOR EOAs; INSTANT_LAYER `0xbf40beca9fb74fb67df4a5c9c99ebad35e616ffd`.
Blast (block 41,115,565): admin `0x629bcef8659a11f576ec0aad0a8fb35a8356ffcf`; 4 LIQUIDATOR EOAs; PAUSER/SUSPENDER `0x9bc9ca7e…`.
Raw logs: `live/<chainid>_{role,rev,partyB}_logs.json`.

### 4.2 Live PartyB set (Base, block 52,127,069)
All 16 registered PartyBs remain active (`isPartyB == true`): `0x9206d9d8…`, `0x12de0352…`, `0x94d2c488…`, `0x5f3525db…`, `0x1ecabf0e…`, `0xfc4ac3af…`, `0xb6e3b449…`, `0xf49d0089…`, `0x15c544d6…`, `0x939ca7b7…`, `0xb49cae38…`, `0x9f20bad7…`, `0x81631953…`, `0x6015e7e0…`, `0xecd1d9dc…`, `0xed85c23e…`. A registered PartyB is required for every quote action; an outsider cannot register (`registerPartyB` = PARTY_B_MANAGER_ROLE, holder = Gnosis Safe).

Note: Base registered PartyB `0x9206d9d8…` has `isADLEnabled == false` (block 52,127,291; not all 16 sampled).

---

## 5. Raw evidence index (all under `/home/heisenberg/CA/intentx/analysis/core/`)

| Path | Contents |
|---|---|
| `REPORT.md` | this report |
| `facets/base_map.txt`, `arb_map.txt`, `mantle_map.txt`, `blast_map.txt` | parsed `facets()` output (facet → selectors → resolved signature) |
| `facets/all_facets.json` | machine-readable facet→selector map, all 4 chains |
| `facets/selector_to_sig.json` | selector → canonical signature (built from verified ABIs) |
| `facets/still_unknown.json`, `facets/unknown_selectors.json` | selector resolution worklist |
| `facets/code_hashes.json`, `facets/identity_final.json` | keccak of runtime code per facet; base/arb/mantle identity analysis |
| `facets/accountlayer_facets_raw.txt` | `facets()` of the AccountLayer diamond `0x56caf00c…` |
| `sources/base/`, `sources/arb/`, `sources/mantle/`, `sources/blast/` | extracted verified Solidity per facet (+ `_index.json` with names/compilers) |
| `sources/base_raw/`, `sources/accountlayer_raw/` | raw Etherscan V2 JSON (incl. ABIs) |
| `sources/accountlayer/` | verified AccountLayer facets/sources |
| `sources/verifier/` | `MuonSignatureVerifier` source |
| `upstream/0.8.5/` | upstream `SYMM-IO/protocol-core@0.8.5` sources used for diffs |
| `live/base_state.txt`, `arb_state.txt`, `mantle_state.txt`, `blast_state.txt` | live state snapshots + block numbers |
| `live/<chainid>_role_logs.json`, `_rev_logs.json`, `_partyB_logs.json` | role/partyB event logs |
| `live/8453_role_logs_bs.json`, `8453_partyB_logs.json` | Base logs (Blockscout/Ankr) |
| `code/` | raw runtime bytecode samples (`base_accountfacet.hex`, unverified facets, etc.) |
| `parse_facets.py`, `extract_source_selectors.py`, `fetch_sources.py`, `verify_identity.py`, `live_reads.sh` | tooling used (read-only) |

### Reproduce the key probes
```bash
# facet map (any chain)
cast call 0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43 "facets()((address,bytes4[])[])" --rpc-url https://base-rpc.publicnode.com
# unprivileged guard probes (read-only eth_call)
cast call 0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43 "acceptCancelCloseRequest(uint256)" 1 \
  --from 0x000000000000000000000000000000000000dEaD --rpc-url <rpc>   # reverts: Should be partyB of quote
cast call 0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43 "liquidatorShare()(uint256)" --rpc-url <rpc>
```

---

## 6. Conclusions

1. **Base / Arbitrum / Mantle** are fully unpaused and hold **1,018,722 + 591,108 USDC and 61,659 USDe**; the operator multisig/Timelock, role holders, and Muon signer set appear intact. Every value-moving entry point in the 29 verified facets is either (a) restricted to the caller's own account, (b) role-gated to a non-zero team address, or (c) value-loaded from a Muon signature that is strongly bound to parties, nonces, method, app id, timestamp and chain id. Live probes confirm the gates fire.
2. **Blast** runs an older build with `accountingPaused = true`; its (verified) liquidation/gating structure matches the new build's pattern, and value-moving accounting is paused. 40.5 USDB remains.
3. The only on-chain code without a verified source is the two PartyB action facets (`0x68D4…`, `0xEE57…`). Live `eth_call` probes show the single-quote functions enforce `partyB == signer` and the batch functions enforce a Muon signature first (then per-quote partyB per upstream). They delegate only to the known libraries. Residual risk is **low** but not zero for `fillCloseRequestToLiquidation`, an IntentX-specific function with no upstream equivalent.
4. Notable **privileged** (not unprivileged) observations: partyB-only `adlClose` prices at an arbitrary caller-supplied value without a Muon signature when `adlEnabled`; `settlePartyALiquidation` is permissionless (no value to caller, half the fee can go to address(0) if only one liquidator is recorded); `finalizeWithdrawRequest(user, 0)` succeeds as a value-less no-op for users who never withdrew.

**Honest result:** no unprivileged extraction path was found in the deployed code that is open today.

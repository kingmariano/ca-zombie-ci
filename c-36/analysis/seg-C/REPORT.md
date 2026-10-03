# seg-C deep-dive report — DEX tail + NFT/marketplaces + prediction + "other"

Campaign: C-36 zombie-hunt (forgotten-eth recovery index). Scope: 65 addresses (~50,692 ETH live-equivalent incl. WETH/stables at entry).
Read-only. Balances re-measured at **block 26,111,158** (ETH) and **26,111,283** (WETH/USDC/DAI); worklist snapshot was block 26,111,001.
RPC: `https://ethereum-rpc.publicnode.com`. Sources: Blockscout `api/v2/smart-contracts`, Sourcify (404 for all unverified here), 4byte/openchain selector resolution, `cast call` simulations. No fork tests run (flagged for parent where useful).

## Headline

**No E-U candidate found in seg-C.** Every value-moving path found is either (a) holder/self-service against the caller's own recorded position, (b) privileged, or (c) stuck. The three large "gap" contracts the brief flagged (Augur +332, X2Y2 Fee, Kyber) are **not** shortfalls:

| contract | live | mapped | explanation |
|---|---|---|---|
| Augur v1 Cash | 762.064744 ETH | 429.80 | `totalSupply() == balance` exactly (762064744189809847510 wei). Index simply did not enumerate all holders. Fully backed, `withdrawEther()` self-only. |
| X2Y2 Fee Sharing | 520.2324 WETH | 315.84 | surplus, not shortfall; standard MasterChef accumulator; `harvest`/`withdraw` self-only; TokenDistributor still works. |
| Kyber FeeHandler | 51.6012 ETH | 24.94 | `totalPayoutBalance() == balance` exactly (51601161897003249125 wei); claims permissionless but pay the recorded staker/rebate/platform wallets. |
| Foundation FETH | 271.7935 ETH | 271.84 | `totalSupply() == balance` exactly (271793540543240936706 wei); `withdrawAvailableBalance()` self-only. |
| ENS Old Registrar | 0 | 8,983.98 | index counted ETH that never sat in the registrar — bids were escrowed in per-bid **Deed** child contracts; registrar balance is genuinely 0. |

## Segment table

| address | name | live ETH | class | one-line reason |
|---|---|---|---|---|
| 0x2a0c0DBE…50c208 | IDEX v1 | 15,729.77 | H-O | PRIOR $0; per-user balances, self `withdraw`. |
| 0x8d12A197…CC6819 | EtherDelta v2 | 15,168.57 | H-O | PRIOR $0; self withdraw; admin only sets fees. |
| 0x1ce7ae55…ee33d8 | Token.Store | 632.62 | H-O | PRIOR $0. |
| 0x373c55c2…754666 | EtherDelta v1 | 122.27 | H-O | PRIOR; selectors match ED family; self withdraw. |
| 0x9a2d163a…566f80 | SingularX (exchange) | 854.996 | H-O | PRIOR $0. |
| 0x4d55f76c…c9091b | Unknown DEX 0x4d55 (EnclavesDEX old) | 2,479.09 | H-O | PRIOR $0. |
| 0xbf296858…cc3b05 | Decentrex | 33.09 | H-O | ED clone; self withdraw; admin can only change fees. |
| 0x04f06280…9c2342 | Joyso | 83.25 | H-O | lockMe→wait→`withdraw` self-only; admin withdraw needs user sig. |
| 0xf4c27b8b…c5c4e8d | ETHEN | 43.52 | H-O | `withdrawEther` subtracts `balances[msg.sender]`. |
| 0x3c020e01…c8e51f | Bitcratic | 30.00 | H-O | ED clone; self withdraw. |
| 0xd8d48e52…1ac4d3 | EtherC | 4.81 | H-O | ED clone; trade verifies ecrecover==maker. |
| 0xbf45f428…15e82b7 | EnclavesDex (proxy) | 7.096 | H-O | **insolvent** (mapped 17.93); self withdraw; admin upgrade = P. |
| 0x6090A6e4…15878Ef | ENS Old Registrar | 0.00 | S | ETH lived in per-bid Deeds; registrar empty; `cancelBid` 0.5% penalty only. |
| 0x22a97c80…f4ef91d | Confideal | 45.72 | H-O | failed campaign (stage=3); `withdrawRefund` self-only. |
| 0x068696a3…109d02 | DADA Collectible | 11.21 | H-O | punks-style; self withdraw/bid-withdraw. |
| 0x60cd862c…4fc54ab6 | MoonCatRescue | 233.29 | H-O | adoption escrow; `withdraw`/`cancelAdoptionRequest` self-only. |
| 0xd6c037be…5d2971e7 | CryptoPhunks Marketplace | 86.21 | H-O | bids + pending withdrawals; self-only. |
| 0x19c320b4…08e01dc | CryptoCats Marketplace | 45.49 | H-O | ~34.88 ETH is owner's `pendingWithdrawals` (P); rest self-only. |
| 0x95080082…69ef540 | CryptoCats v0/v1 | 43.685 | H-O | PRIOR $0. |
| 0x4aea7cf5…e8cf65 | EtherDelta v0 | 220.89 | H-O | PRIOR; selectors match ED v0; no admin selector. |
| 0xc3c12a9e…b81ae1b | SwitchDex | 101.11 | H-O | ED v2 fork + AccountLevels; admin fns revert for randoms. |
| 0x2f23228b…667c93b | Coinchangex | 17.35 | H-O | ED clone + special fees; self withdraw. |
| 0xbeeb6558…c66a9be | SwissCryptoExchange | 7.83 | H-O | ED clone + whitelists; self withdraw. |
| 0x3da70c70…603c4c | LSCX | 6.45 | H-O | ED + on-chain tiker book; admin fns guarded (simulated). |
| 0x232ba9f3…60e5fe | Bitcratic v1 | 3.06 | H-O | ED clone. |
| 0x2f13fa06…2e648b | MarketPlace | 2.46 | H-O | escrow exchange; self withdraw. |
| 0xb5adb233…a97d21 | Bitox | 2.25 | H-O | ED clone + feeAccount2. |
| 0xc5138d4b…33af97 | ED Fork (0xc513) | 6.92 | H-O | selector set == ED v2 exactly; self withdraw. |
| 0x49919731…900e49 | Ethernext | 1.32 | H-O | ED v2 clone. |
| 0xd4cc0cda…61f712 | SeedDex v2 | 1.27 | H-O | self withdraw; `migrateFunds` caller's own balance. |
| 0xcf25ebd5…5a5debf | SeedDex v3 | 1.18 | H-O | self withdraw; `migrateFunds` caller's own balance. |
| 0x25066b77…150e9b | PolarisDEX | 1.21 | H-O | ED v2 clone. |
| 0x2b44d685…3dbc932 | Ethmall | 1.04 | H-O | ED v2 clone. |
| 0x97c9e0ec…a2ee0f | ExToke | 0.91 | H-O | ED clone; self withdraw. |
| 0x4bc78f66…32aba3 | AlgoDEX | 0.87 | H-O | ED v2 clone. |
| 0x51a2b1a3…c23c22 | nDEx | 0.64 | H-O | ED v2 clone. |
| 0x4fbcfa90…904b02 | EDex | 0.54 | H-O | ED v2 clone. |
| 0xc6b330df…073ce2 | Etheropt Old | 16.84 | H-O | ED v0 family; no admin surface. |
| 0x2af47a65…2d2400 | Bounties Network | 83.25 | H-O | StandardBounties; release only issuer/arbiter; contribute open. |
| 0xc59b0e4d…407e0c | Omen / ConditionalTokens | 0 (76.98 WETH + $233k) | H-O | canonical Gnosis CTF; `redeemPositions` self-only. |
| 0x19c10FFF…5Cd20ba | Age of Dinos (AuctionMinter) | 24.99 | H-O | `claimAndRefund` self-only; `sendPayment` pays fixed recipient. |
| 0xDe5D4949…C7a6db | PersonaBid (RaffleAuctionMinter) | 15.04 | H-O | raffle; claim/refund self-only. |
| 0x0c7060bf…3f4613 | Fractional DEAD Vault | 44.70 | H-O | ended vault; `cash()` self-only pro-rata. |
| 0xfe2a5b94…47cc62 | Fractional SWEEP Vault | 19.75 | H-O | same. |
| 0xdb846f1c…5505f4 | Fractional ZCAT Vault | 10.48 | H-O | same. |
| 0xd3d2b564…1114fe | Kyber FeeHandler | 51.60 | H-O | permissionless claim triggers pay recorded wallets; fully allocated. |
| 0xd5524179…76B96b | Augur v1 (Cash) | 762.06 | H-O | 1:1 ETH token; `withdrawEther` self-only; fully backed. |
| 0xaA7427D8…be1011 | Ethfinex Trustless | 929.51 | H-O | PRIOR $0. |
| 0x50cb61af…0d1cff | Ethfinex Trustless v2 | 71.90 | H-O | PRIOR $0. |
| 0xc7c9b856…f78302 | R1Exchange | 149.04 | H-O | apply→wait→withdraw self-only; adminWithdraw needs user sig. |
| 0x7ee7ca6e…6b22d0 | Switcheo BrokerV2 | 406.89 | H-O | PRIOR $0. |
| 0x5995ca61…accf6d | Unknown DEX (0x5995) | 75.98 | H-O | PRIOR $0. |
| 0xe31763aa…e5e737 | Avastars | 28.85 | H-O | `withdrawDepositorBalance` self-only; owner only takes franchise surplus. |
| 0x6f400810…aa841f | Mesa / Gnosis Protocol v1 | 0 (144.69 WETH + $244k) | H-O | `withdraw(user,token)` pays recorded user; request must come from user. |
| 0xc8c3cc5b…a1b85 | X2Y2 Fee Sharing | 0 (520.23 WETH) | H-O | MasterChef; harvest/withdraw self-only. |
| 0xc2f44bc5…070be1 | X2Y2 Presale | 0 (145.77 WETH) | H-O | 1000 presale participants; broken `tokensLeft` accounting → race; owner Safe can take surplus. |
| 0x1ecb59ae…75d40f | Metadrop: Webaverse | 103.35 | H-O | merkle refund bound to msg.sender + bid-capped; owner can rug (P). |
| 0xe14ab3ee…f22585 | TweetMarket | 85.54 | H-O | cancel after 1-day lockup self-only; withdraw self-only. |
| 0x1d90d50d…be7982 | Meme Limited Collections | 48.81 | H-O | artist/controller pending fees; `withdrawFee` self-only. |
| 0x49128CF8…D50443 | Foundation FETH | 271.79 | H-O | fully backed; `withdrawAvailableBalance` self-only; market-gated calls. |
| 0xa46ed708…b1b074 | Futurists Auction Splitter | 13.00 | H-O | PaymentSplitter `release` pays registered payees. |
| 0x3a56ab63…270ca0 | Collective Canvas | 57.77 | H-O | per-token fee escrow; `withdraw(tokenId)` needs NFT ownership; exact solvency. |
| 0x9abb7bdd…f59be1b | POW NFT | 77.30 | H-O | `withdraw(tokenId)` needs token ownership; designed mining redistribution. |
| 0x0286f920…9a243e | SingularX Fund | 385.42 | H-O | `withdrawReward` self-only; broken accumulator race; no live SNGX market. |
| 0x0a14b696…f9d2a0 | zkSync Lite | 10,779.07 | H-O | PRIOR root verified; bridge live, withdrawals ongoing (−147 ETH since snapshot). |

Class counts: **H-O 64, S 1, E-U 0, P 0** (P-risk paths noted per contract).

### Augur v1 — detail (top unexamined pot, 762.06 ETH)
- The address is a **Delegator** proxy: `getController()=0xb3337164E91B9F05C87C7662C7AC684E8e0ff3E7`, `controllerLookupName()=bytes32("CashTarget")`, `lookup("CashTarget")=0x9B4Af4a3295cF476a2b00736f7332f35BbEE960E` (verified `Cash`).
- `Cash` is Augur's 1:1 ETH token (name "Cash", symbol "CASH", 18 dp). State-changing functions: `depositEther()`, `depositEtherFor(address)`, `withdrawEther(uint)`, `withdrawEtherTo(address,uint)`, `withdrawEtherToIfPossible(address,uint)`, `transfer`, `transferFrom`, `approve`, `increaseApproval`, `decreaseApproval`, `setController` (onlyControllerCaller). All value-moving paths are keyed to `balances[msg.sender]` (or allowance for `transferFrom`); `withdrawEtherTo` lets the caller choose a destination but still burns only the caller's balance.
- `totalSupply()` = `762064744189809847510` = contract balance exactly → **fully backed**. The 332 ETH gap vs the index is un-enumerated holder balances, not a shortfall.
- Augur `Market`/`Universe`/`ReputationToken` are sibling Delegators resolving their own targets via the same Controller; they escrow **CASH balances** (held inside this same Cash contract), not separate ETH. Market-level paths (`claimTradingProceeds`, `refund`, `finalize`, fork/migrate) pay per the caller's own share-token/reporting position; none can move another account's Cash balance. Controller `registerContract` is `onlyOwnerCaller` (owner = Augur governance), so the Cash target cannot be re-pointed permissionlessly. → **H-O, high confidence**.

## E-U candidates

None. The closest shapes and why they fail the E-U test:

1. **Augur v1 Cash `withdrawEtherTo(address,uint256)`** (0xd5524179…). Looks like "pay an arbitrary address" but `withdrawEtherInternal(_from=msg.sender,_to,_amount)` burns **the caller's** balance. No ownership check is missing because the caller's own balance is the only source. `depositEtherFor(to)` only credits `to`. Backing exact. → H-O.
2. **Metadrop `claimRefund(uint256,bytes32[])`** (0x1ecb59ae…). Merkle leaf = `keccak256(abi.encodePacked(refundAmount, msg.sender))`, root fixed at `0x580d90a1…`, single claim per address, and `refundAmount <= Σ msg.sender's own bid totals`. Call from random reverts `Refund proof invalid`. No leaf/domain confusion (52-byte packed leaf, 32-byte internal nodes). → H-O.
3. **Kyber `claimStakerReward(address,uint256)` / `claimReserveRebate(address)` / `claimPlatformFee(address)`** (0xd3d2b564…). Permissionless triggers, but every transfer goes to the address recorded in `rewardsPerEpoch`/`rebatePerWallet`/`feePerPlatformWallet`, never the caller. `totalPayoutBalance == balance`. → H-O.
4. **Age of Dinos / PersonaBid `sendPayment()`** (0x19c10FFF…, 0xDe5D4949…). Permissionless after auction end, but pays the immutable `paymentRecipient`; callers get nothing. → H-O.
5. **SingularX `softWithdrawRewardFor(address)`** (0x0286f920…). Permissionless settlement for any address, but credits `owed[forAddress]` — only that address can `withdrawReward()` it. → H-O.
6. **ENS `cancelBid(address,bytes32)`** (0x6090A6e4…). Genuinely permissionless and pays the caller **0.5%** of an abandoned sealed bid (99.5% burned to the ENS burn address). Requires the `seal` from a historic `newBid` tx and a bid older than ~3 weeks. The registrar itself holds 0 ETH — the ETH sits in per-bid Deed children, so this is a Deed-level surface, not this address. Parent may want to scan Deeds separately.

## Notable H-O races / solvency shortfalls (flag for parent fork testing)

### 1. EnclavesDex proxy — insolvent (7.096 ETH vs 17.93 mapped)
- Address `0xbf45f4280cfbe7c2d2515a7d984b8c71c15e82b7`, impl `0xed06d46FFB309128C4458A270C99c824dc127f5D`, admin `0x0B2dF89a0f816144c50400Cac69f25DeD20e774F`.
- `withdraw()` → `withdrawUser(amount, msg.sender)`; if local balance < amount it calls `rebalanceEnclaves` pulling from the dead EtherDelta `etherDelta` address (probably 0 there now).
- ~10.8 ETH of user balances cannot be paid → **first-mover race**: earliest withdrawers win, later ones revert.
- Fork test idea: enumerate `tokens[0][user]` from `Deposit`/`Withdraw` logs and compare Σ balances vs 7.096 ETH; simulate sequential withdrawals.

### 2. SingularX Fund — broken dividend accumulator (385.42 ETH)
- `calcReward(forAddress) = balanceOf(forAddress) * (totalReward - rewardAtTimeOfWithdraw[forAddress]) / totalSupply()` — settlement state travels with the **address**, not the tokens. If SNGX tokens change hands after a claim, the buyer's `rewardAtTimeOfWithdraw` is 0 and can claim rewards the seller already took → outstanding claims can exceed the balance; first-come-first-served.
- No live market: Uniswap v1 exchange `0x6E04C36EA43567FdcA1624Dc510404ee8c0320bB` is empty (0 ETH / 0 SNGX / 0 pool tokens); no Uni v2/v3/Sushi pairs. So not E-U today.
- `totalReward()=684.198 ETH`, balance `385.424 ETH`, SNGX supply `1e25`, `withdrawReward()` from random returns 0.
- Fork test idea: enumerate SNGX holders (10,098) + `rewardAtTimeOfWithdraw`/`owed` and compute Σ pending vs 385.42 ETH. Watch for any new liquidity venue.

### 3. X2Y2 Presale — broken `tokensLeft` accounting (145.77 WETH)
- `_pendingReward(user) = ((totalReward/totalShareSold) - rewardDebt) * (TOKENS_PER_SHARE - tokensClaimed) / TOKENS_PER_SHARE`; withdrawing X2Y2 tokens forfeits rewards, so the theoretical pool `T = tokenRewardTreasuryWithdrawn + totalRewardDistributed + balance = 449.26 ETH` can exceed the 145.77 WETH actually held if many of the 1000 participants have stale `rewardDebt`.
- Only the 1000 whitelisted `hasShare` addresses can harvest (`harvest()` from random reverts `Harvest: User not eligible`; sale phase closed, signatures can no longer be used).
- Owner `0x5D7CcA9Fb832BBD99C8bD720EbdA39B028648301` (Gnosis Safe) can call `treasuryWithdraw()` **now** (block 26.1M > stakingEnd 16,553,224 + 195,000 buffer) and take up to the full WETH balance; `_totalReward` stays constant, so participants' claims would then revert. P-risk, never exercised (`tokenRewardTreasuryWithdrawn=0`).
- Fork test idea: enumerate the 1000 participants' `(tokensClaimed, rewardDebt)` and compute Σ pending vs 145.77 WETH to size the race.

### 4. Other P-drain risks (privileged, not E-U)
- **Metadrop** `withdrawContractBalance()`/`withdrawETH()` onlyOwner (Safe `0xbf9f7E70…`), no timelock — could take all 103.35 ETH including refunds.
- **Foundation FETH** EIP-1967 admin `0x72de36c8ebeacb6100c36249552e35feff0ee099` (ProxyAdmin) can upgrade the impl and drain 271.79 ETH.
- **R1Exchange** owner can `enableWithdraw(true)` (no-limit self-withdraws) and `refund(user,…)` only to the user; cannot redirect.
- **CryptoCats Marketplace** owner `0xd7148578…` has 34.88 ETH of `pendingWithdrawals` (mint proceeds) — legitimately theirs.
- **TweetMarket** `close()` onlyDelegates can pay an arbitrary `seller`; **Fractional** `claimFees()` mints curator/gov tokens (dilution, not ETH).

## Minor mapped-vs-live discrepancies (not material)
- **Bounties Network** 83.25 live vs 84.75 mapped (−1.5 ETH): StandardBounties tracks per-bounty `balance` and releases only via issuer/arbiter; if any bounty were under-collateralised the affected slice would be a last-claimer race. Index estimate is likely slightly stale (contract has been dormant). Low priority.
- **Collective Canvas** 57.77 live vs 58.92 mapped (−1.16 ETH): provably solvent — Σ `balanceOfToken(tokenId)` over all tokens telescopes to exactly `totalFunded − withdrawn`, and the contract holds `totalFunded − withdrawn`. Index overestimate.
- **PersonaBid** −0.52, **Metadrop** −0.50, **Age of Dinos** −0.11: index rounding on active-bid contracts; claims are self-only and capped by own bids.

## PRIOR addresses re-checked (one line each)
IDEX v1 15,729.77 ETH; EtherDelta v2 15,168.57; Token.Store 632.62; EtherDelta v1 122.27; SingularX 854.996; Unknown DEX 0x4d55 2,479.09; Ethfinex 929.51; Ethfinex v2 71.90; Switcheo 406.89; zkSync Lite 10,779.07 (root verified; withdrawals active, −147 ETH since 26,111,001); CryptoCats v0/v1 43.685; EtherDelta v0 220.89; Unknown DEX 0x5995 75.98 — all at block 26,111,158, prior $0, no new surface.

## Method / reproducibility
- `seg-C/raw/live_balances.json` — ETH balances, block 26,111,158.
- `seg-C/raw/src/` — Blockscout smart-contract JSON for all verified addresses + impls (Augur Cash/Controller, FETH, EnclavesDEX, TokenVault).
- `seg-C/raw/seg_C_worklist.json`, `worklist_compact.txt` — segment worklist snapshot.
- `seg-C/raw/build_results.py` — generates `results.json`.
- Key `cast call` outputs quoted in `results.json` evidence fields.

# DeFIL (ETH) — contract-by-contract audit notes

Read-only. All reads at Ethereum block 26,169,800 (pinned) / 26,169,907 (latest during recon), 2026-10-11.
Sources: Etherscan V2 verified source, Blockscout, direct eth_call, eth_getLogs.

## 1. Token layer

| Token | Address | Supply | Mint authority | Owner | Notes |
|---|---|---|---|---|---|
| FILST | 0x7346aD4c…4Ca2 | 1,959,936 | `mint/burn` onlyPoster; poster = FILSTManage | EOA 0x557EdaaF (no code) | owner can `setPoster` — privileged risk only |
| DFL | 0x09ce2B74…5AB | 125,814,138.56 | `mint` onlyOwner | Unitroller (Comptroller proxy) | DFL distributed as lending/staking rewards |
| EFIL | 0x2a2cB9bA…b628 | 87,105.55 | MINTER_ROLE (AccessControl) | EOA 0x557EdaaF | transfer-role gated (`setupTransferRole`) |
| mFIL | 0x3C392C3F…7b0C | 1,242,378.62 | MINTER_ROLE | EOA 0x557EdaaF | no market/pairs → ~$0 realizable |
| eFIL-old | 0x22B475f3…6C2c | 50,154,369,105 (50.15B) | (owner EOA 0x557EdaaF) | EOA 0x557EdaaF | used in FILST/eFIL-old pair 0x2290a4cc |

## 2. FILST mint system (the only place new FILST can be created)

- `FILSTManage` 0xcd429F23 (verified): `mint(recipient, tokenId, nftAmount)`:
  1. `require(miningNFT.balanceOf(msg.sender, tokenId) >= nftAmount)` — caller must hold mNFT units.
  2. `mintFee = 5% of (nftAmount × 1024 FILST)` converted to DFL via `PriceConverter` (live pair reserves).
  3. `dfl.safeTransferFrom(msg.sender, this, mintFee)`; `miningNFT.safeTransferFrom(msg.sender, this, …)` (requires operator approval).
  4. `filst.mint(recipient, nftAmount × 1024e18)`.
- `PriceConverter` 0x7F5f88F7 (verified): `convertFromFilstToDFLAmount` reads **spot reserves** of FILST/USDT and DFL/USDT — manipulable, but the path is NFT-gated (see below), so moot.
- **Gate: all 1,914 mNFT units (IDs 100001–100011) are escrowed in FILSTManage.** `balanceOf(FILSTManage, id)` sums to 1,914 = `totalStakedMiningNftAmount`. FILSTManage has **no function that transfers ERC-1155s out** (only a `transfer` for DFL, onlyOwner).
- New mNFT minting: `MiningNFTManage.mint` requires `MinerManage.whiteList(msg.sender)` (owner-managed) → outsider reverts `"sender not in whitelist"`.
- Therefore: **no outsider can mint FILST**. Verified by simulation: `FILSTManage.mint(attacker, 100001, 1)` → `"exceed mining NFT balance"`.

## 3. Staking layer (custody of the live value)

All six ETH staking instances share runtime code hash `0xd3b8281179950f98149eefdb158d0e1acb56f56e8e343aa9fefafa7e36959561`
(= verified `Staking` source, solc 0.5.17). Key properties:

- `deposit(amount)`: pulls property tokens, credits shares 1:1 with the amount received.
- `withdraw(amount)`: `require(state.share >= amount)` — **only the caller's own shares**; then transfers property out.
- `claim(receiver, amount)`: `require(amount <= state.accruedAmount)` — only the caller's accrued reward; forwards to the superior distributor.
- `transfer(to, amount)`: moves the caller's **accrued reward** (not shares).
- No owner, no admin, no sweep, no pause, no upgrade hook. No reentrancy guard, but property tokens (UNI-V2 LP, FILST, DFL) have no transfer hooks, so no reentrancy vector.
- Reward accounting (Compound-style `globalAccruedIndex`): rounding truncates in the contract's favour; `accrue()` is public but only advances the index from the superior's actual accrued amount.

Verified gates (simulations):
- outsider `withdraw` on all staking instances → `"withdraw: insufficient value"`.
- outsider `claim` on all staking instances → `"claim: insufficient value"`.
- top LP staker 0xf2ba8f66 (EOA, 99.88% of staked LP) `withdraw(978272219496394154)` → **succeeds** (H-O proof).

## 4. Reward/distributor layer

- LP-staking superior: `PrivilegedRedistributor` 0xe67Ae15C (asset DFL). Member list = [0xB02F1180]; LP staking has 930,674.76 DFL accrued (claimable only through staker claims).
- FILST-staking superior: `RewardPoolDelegator` 0x5E6468b3 (proxy; impl RewardPool 0x4d3cf9f1; admin EOA 0x557EdaaF; asset EFIL; holds 377 EFIL).
- DFL-staking superior: `PrivilegedRedistributor` 0x3CCd0160 (asset EFIL).
- Root DFL distributor: Unitroller 0x6B4F20B2 holds 43.75M DFL. `claim` requires `amount <= accruedStored(msg.sender)`.
- All outsider claims revert (`"claim: insufficient value"` / `"Insufficient value"` / `"insufficent value"`).
- Reward values are small: DFL $0.000112; EFIL ~$0.0005 (pool-implied) — even a hypothetical reward exploit caps at the Unitroller's $4.9K DFL.

## 5. Compound-fork lending markets (Unitroller 0x6B4F20B2)

| Market | Underlying | Cash | Claims (supply×rate) | Status |
|---|---|---|---|---|
| ceFIL 0x036cF382 | EFIL | 38,527.8 EFIL | 192,493 EFIL | legacy bad debt (borrows 14.37M vs reserves 14.21M); cash-backed part only |
| cmFIL 0xbE8fB7dB | mFIL | 182,288.5 mFIL | 182,288.5 mFIL | fully backed; mFIL has no market |
| cFILST 0x71dd9CD4 | FILST | 3,102.08 FILST | 3,102.08 cFILST | **auto-staked into FilstPool 0x01aabbad**; market holds matching pool shares; sole holder 0x9a26f4d0 can redeem (verified) |

- The cFILST market's `getCash()` returns a stored `cash` variable (slot 15) because deposits are re-staked into the FilstPool (`doTransferIn` → `FilstPool.deposit`; `doTransferOut` → `FilstPool.withdraw`). Pool `accountState(cFILST market)` = 3,102.08 FILST shares — fully backed.
- Oracle 0x8A1e3e58 (SimplePriceOracle, owner = deployer EOA) returns **stale 2021 prices** (FILST $0.006124, EFIL $1.00, mFIL $1.25). Stale oracle can only matter for borrowing; no outsider borrow path to profit: borrowable cash is tiny and markets' collateral factors/caps prevent meaningful extraction; no Borrow events on cFILST ever.
- ceFIL/cmFIL/cFILST `collateralFactor` 0 / 0.8 / 0.8; `borrowCaps` = 0 (uncapped but cash-limited).

## 6. Other contracts (deployer sweep, 62 contracts)

- `FoundationWallet` 0x7fe1c0a5: 906,725 DFL.
- `ReferrerRewardsDistribution` 0x9a9e42bc: 36,598 DFL (owner 0x1c7f772e).
- 0x9b1322c4 (unverified, owner=deployer): 1.75M DFL.
- `Timelock` 0x8a6023e7: admin = deployer EOA, delay 2 days (no queued txs relevant).
- `RewardPool` 0x4aa5f09d: uninitialized (asset/staking/admin = 0) — dead.
- Interest-rate models, calculators, strategies: no token balances.
- `FilstMarketCErc20Delegate` 0xe5dbb86e (verified) is the cToken delegate class (auto-stake variant).
- `MiningNFTMintingLimitation` 0x0b72c88a; `FilChainStatOracle` 0xca106916; `MiningNFTMintingLimitationData` 0x097eb202 — role-limited.

## 7. Cross-chain / bridge

- Research (see `analysis/research/notes.md`): no public bridge contract; DeFIL's own bridge was team-operated (multi-sig), no public path; ETH vs BSC FILST prices ($0.5117 vs $0.1335) have not converged in years with zero cross-pool flow.
- Therefore the 3.8× price gap is **not** an unprivileged arbitrage (no bridge to move FILST).

## 8. Negative results (dead ends)

- No E-U path found on ETH: mint gated, withdrawals share-gated, claims accrued-gated, markets tiny and holder-gated, no bridge.
- PriceConverter spot manipulation irrelevant (mint gated).
- `PrivilegedRedistributor._setMembers/_setPercentages` onlyOwner; Unitroller `_set*` onlyAdmin (EOA) — privileged, not E-U.
- cFILST `getCash` anomaly resolved: auto-staking market design, fully backed.
- FILST/eFIL-old pair dust; DFL/WETH pair dust.

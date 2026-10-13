# DeFIL QC-1 — raw evidence notes (2026-10-13)

## Bytecode identity (ETH ↔ BSC), runtime code keccak

| Contract | ETH | BSC | Result |
|---|---|---|---|
| FILSTManage | `0x276faac1963aba826a639046048be916b6169dd8753b3799314d4e795675efdf` | same | IDENTICAL |
| MiningNFT | `0x96fbd2927a3d6683be467a438a492bd1168a60213c9babb6c99bd4fcab68b6f3` | same | IDENTICAL |
| MiningNFTManage | `0xdceaac356e6a97200888c6cfd6b289dd4f1d50fec8c20a269dd0366a2326be3e` | same | IDENTICAL |
| MinerManage | `0x7328d66798829f8afcb297c14a80add17453c20ec92f602f83b1c28b58257980` | same | IDENTICAL |
| RewardPool impl | `0x0de2d1717c7ed5b9e7bcee98ffacb4c438fa317f287bb22ba59daf5f599518be` (0x4D3CF9f1) | `0xbb51f46a4fd0bec0e55c9a1296edbb6fdfe8b9b65b580b38a88eeece354c1be4` (0xDE86b0Fb) | DIFFERENT (same selector surface; BSC delegator holds 0 tokens) |

## Unverified Comptroller implementation `0x622e6177…` (ETH) — extracted selectors (notable)

```
0x6bbcac92 accruedStored(address)          0xaad3ec96 claim(address,uint256)
0xea0ecf53 claimDFL()                      0xf8ba4cff accrue()
0xaf0a619c dflAccrued(address)             0xbb5260e4 dflAddress()
0x9577fbd5 _setDflKeeper(address)          0xf66d0ca5 _setDflKeeperFactor(uint256)
0x8ebf6364 _setTransferPaused(bool)        0x5f5af1aa _setPauseGuardian(address)
0x9bd660f8 dflCurrentSpeed() / dflMarketPercentages / dflSupplyIndex / dflSupplierIndex
0xc1e80334 _acceptImplementation()         0xbb82aa5e comptrollerImplementation()
```
Fork-proven: `_setPendingImplementation`, `_setDflKeeper`, `_setDflKeeperFactor`, `_setPauseGuardian`, `_setCollateralFactor`, `_supportMarket` → return `1` (UNAUTHORIZED); `_setTransferPaused` → revert; `_setMarketBorrowCaps` → revert.

## Reward-chain wiring (ETH)

```
ceFIL market 0x036cF382  --superior-->  PR 0x3CCd0160 (asset EFIL)  --superior-->  S_DFL staking 0xb685bfda
ceFIL.accruedStored(PR)            = 14,212,709.69 EFIL  (== totalReserves)
PR.accruedStored(S_DFL)            =  7,106,736.09 EFIL
PR EFIL balance                    = 0
ceFIL cash                         = 38,527.81 EFIL   (payout bound)
S_DFL.superiorAccruedAmount        =  7,106,736.09 EFIL
```
Claim chain is `msg.sender`-accrued-gated at every hop; EFIL has no ETH venue → realized $0.

BSC chain equivalent: SUP3 `0xe0F23BeE` (asset EFIL) superior = ceFIL market `0x0c6D278a`;
`ceFIL.accruedStored(SUP3)` = 0.375 EFIL; `SUP3.accruedStored(S_DFL)` = 0.208 EFIL (dust).

## Reserve-keeper mechanism (custom fork)

`FilstMarketCErc20Delegate` / `CErc20Delegate`:
```solidity
function _reduceReserves(address receiver, uint reduceAmount) external nonReentrant {
    ... address keeper = msg.sender;
    if (reduceAmount > historicalReserveKeeperAccrued[keeper]) return fail(BAD_INPUT, ...);
    historicalReserveKeeperAccrued[keeper] -= reduceAmount;   // pays `receiver`
}
```
- ceFIL reserveKeeper = PR `0x3CCd0160` (contract, accrued 14.2M EFIL; **no function calls the market**)
- cmFIL/cFILST reserveKeeper = EOA `0x3f0FE6cc` (accrued 0)
- outsider `_reduceReserves(ATTACKER,1)` → error code, cash untouched (fork-proven)

## EFIL venue check (ETH, `0x2a2cB9bA…`)

- Uni V2 factory: no pairs vs WETH/USDT/USDC/DFL/mFIL
- Sushi V2 factory: no pairs vs WETH/USDT
- Uni V3 factory: no pools vs WETH (500/3000/10000)
- Only pair: FILST/EFIL `0x7393aa9d` = 982.27 EFIL + 0.99 FILST (dust)
- Holders: ceFIL market 38,527.8; RewardPoolDelegator 377.4; EOAs/small contracts — no market

## LP float precision (ETH `0xa2f6a219…`)

- totalSupply 979,559,559,549,437,324; staking 979,475,547,106,670,098 → float 84,012,442,767,226 (8.4e-5 LP ≈ $122.6)
- float holders (Transfer-log netting): EOA `0xf82a7842…` 83,331,079,216,900 ($121.6) + smart wallet `0xb3ac829a…` (impl SmartWalletEntry `0xe40ccB2D…`) 681,363,550,326 ($1.0)
- Blockscout's holder index omitted the EOA (stale index) — on-chain netting used instead

## Old→new DFL migration (`0x9b1322c4…`)

- owner EOA `0x3f0FE6cc`; tokenA = old DFL `0x6ded0F2c` (100M supply; contract holds 85.48M), tokenB = new DFL (contract holds 1,746,989.6)
- `convert(x)` permissionless, 1:1 (fork-proven with a real holder: 1,000 old → 1,000 new)
- old DFL venue: Uni pair `0x160AC8b0` with 2,256.5 old DFL + 0.0145 WETH (~$50) → implied ~$0.022/oldDFL, above new DFL → conversion destroys value

## Fork-test log summary

- Local: `forge test` → **25/25 pass** (18 ETH + 7 BSC); two transient publicnode RPC "block not found" errors re-ran green.
- BSC test requires `BSC_RPC_URL` (CI secret) or public fallback.

## Fresh live numbers (2026-10-13)

ETH block 26,182,388 / BSC block 127,371,202 (see `ci-out/qc-evidence.json` after the CI run).

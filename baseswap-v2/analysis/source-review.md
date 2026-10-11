# BaseSwap V2 — deployed-code audit notes

All sources fetched 2026-10-11 from `base.blockscout.com` (verified contracts; UA-gated API).
No keyed endpoints in this file.

## Contracts and verification status

| Contract | Address | Name | Compiler | Verified |
|---|---|---|---|---|
| V2 Factory | 0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB | PancakeFactory | v0.5.16 | yes (2023-08-01) |
| Pair (impl used by all 8,290 pairs) | 0xf4B96d5162ADEE867b6361e9f1848D701c4286C7 (pair #0) | PancakePair | v0.5.16 | yes (2023-08-01) |
| BSWAP token | 0x78a087d713Be963Bf307b18F2Ff8122EF9A63ae9 | BswapToken (BEP20 + votes) | v0.6.12 | yes |
| MasterChefV2 (BSWAP owner) | 0x2B0A43DCcBD7d42c18F6A83F86D1a19fA58d541A | MasterChefV2 | v0.6.12 | yes |
| feeTo (protocol fee receiver) | 0x463112327576814f80DA8D3632f7bad23c853A29 | ERC1967Proxy → FactoryManager (UUPS) | v0.8.24 | yes |
| feeToSetter | 0xAF1823bACd8EDDA3b815180a61F8741fA4aBc6Dd | GnosisSafeProxy v1.4.1, 2-of-4 | v0.7.6 | yes |
| V2 Router | 0x327Df1E6de05895d2ab08513aaDD9313Fe505d86 | (FactoryManager.routerV2) | — | — |
| BSWAP staking (SmartChef) | 0x86DBd5bAAE91AC576E8e5197EB2497603d0056EA | SmartChefInitializable | — | yes |

## Pair = canonical PancakeSwap V2 pair (no backdoors)

Function-by-function diff against public PancakePair v0.5.16 (mirror nhancv/pancake-swap-testnet @707bd40):
- identical (modulo quote style): constructor, getReserves, initialize, _update, mint, burn, swap, skim, sync.
- `_mintFee` uses the *current* PancakeSwap protocol-fee formula (comment: "8/25 of the growth in sqrt(k)"):
  `numerator = totalSupply*(rootK-rootKLast)*8; denominator = rootK*17 + rootKLast*8` — matches the public
  updated PancakePair, not a BaseSwap invention.
- swap fee = 25/10000 (0.25%); K check `balance0Adjusted*balance1Adjusted >= reserve0*reserve1*10000^2`.
- `skim(to)` is **permissionless**: transfers `balanceOf(this) - reserve` for both tokens to any `to`.
- `sync()` permissionless. `mint(to)` permissionless (LP to caller).

## Factory = canonical PancakeFactory

- Functionally identical to public PancakeFactory (only quote-style diff): `createPair`, `setFeeTo`,
  `setFeeToSetter`, `allPairs`, `getPair`, `allPairsLength`.
- Admin gates live: `setFeeTo`/`setFeeToSetter` require `msg.sender == feeToSetter` (the 2-of-4 Safe).
- `feeTo` = 0x463112327576814f80DA8D3632f7bad23c853A29 (FactoryManager proxy). `feeToSetter` = Safe.
- No migrator. No owner. No pause. No upgradeable factory.

## feeTo = FactoryManager (UUPS proxy, OZ ERC1967)

- owner = feeToSetter Safe 0xAF1823…; operator = 0x479013825281fA8B03135aCEf2174f346C46Ddd3 (EOA);
  treasury = 0xE32B416d320FDB9bC793447FE2Eefe11663d19AB (Safe owner).
- All value-moving functions are `onlyOwner` or `onlyOwnerOrOperator`:
  `transferTokenToTreasury`, `batchTransferTokensToTreasury`, `collectProtocolFeeV2`, `collectProtocolFeesV2`,
  `collectProtocolFeeV3`, `approveToken`, `swap`, `setTreasury`, `setOperator`, `setFactoryV2FeeTo`, …
- `_authorizeUpgrade` is `onlyOwner`. `authorizeUpgrade(address)` is public but reverts for non-owner.
- => protocol-fee LP held by this proxy is **privileged-only (P)**, not attacker-extractable.

## BSWAP token

- Standard BEP20 `_transfer` (no fee/hook/blacklist); `mint(address,uint256) onlyOwner`; owner = MasterChefV2.
- MAX_SUPPLY 10,000,000e18; totalSupply 9,998,487.117e18 (cap nearly reached).
- Delegation (Compound-style votes) only; no value-transfer powers.

## MasterChefV2 (custom variant of Sushi MasterChef)

- owner = feeToSetter Safe; treasury = Safe; `bswapPerSec = 0` (emissions stopped); `BONUS_MULTIPLIER=1`;
  `teamRewardPercent=1000` (10% of emissions to treasury); 17 pools.
- `updatePool` public, mints `reward` to itself + 10% to treasury (bswap.mint onlyOwner = this contract).
  With bswapPerSec = 0, mints 0 — no inflation today.
- `deposit`/`withdraw` follow the standard acc-per-share pattern; `emergencyWithdraw` returns `user.amount`
  without touching `totalDeposit` (reward-accounting staleness only; no LP loss).
- `safeRewardTransfer` caps at contract BSWAP balance.
- No reentrancy guards, but the only external calls are to BSWAP (standard token) and the pair LP token
  (standard ERC20) — no callback hooks. State is updated around transfers in the standard order.
- => staked LP is withdrawable by its depositors (H-O); no permissionless theft path found.

## SmartChefInitializable (BSWAP staking, "syrup pool")

- stakedToken = BSWAP; rewardToken = WETH; depositFee = 100 bps (1% to treasury); owner = Safe.
- Contract WETH balance = 0 (rewards exhausted); users can still `withdraw`/`emergencyWithdraw` their BSWAP.
- Admin functions (recoverWrongTokens, emergencyRewardWithdraw, stopReward, …) are onlyOwner.

## Known latent / privileged (not E-U)

- Safe (2-of-4) can: set factory feeTo/feeToSetter, upgrade FactoryManager (UUPS), mint remaining ~1,512.88
  BSWAP via MasterChef emissions, re-enable emissions (`updateRewardPerSecond`), move FactoryManager tokens
  to treasury, collect protocol-fee LP. All P.
- If Safe re-enables emissions and the supply cap is hit, `bswap.mint` reverts → `updatePool` reverts →
  `deposit`/`withdraw` revert (users keep `emergencyWithdraw`). Liveness risk, P-triggered.

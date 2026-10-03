# C-39 — Dormant / secondary PulseChain DEXes: live extractability check

Block range used: 27,701,912 – 27,702,157 (PulseChain, chainid 369, 2026-10-03).
Method: GeckoTerminal pool lists per venue → on-chain `getReserves()`/`balanceOf(pair)`/`getScalingFactors()`;
verified sources from `api.scan.pulsechain.com`; all read-only.

## Result: no external-unprivileged extraction path found on any secondary venue (E-U ≈ $0)

| Venue | Live TVL (GT top-40 sum) | Key contracts | What was checked | Verdict |
|---|---|---|---|---|
| 9mm V3 | ~$1.82M | factory `0xe50DbDC88E87a2C92984d794bcF3D1d76f619C68`, owner `0xca50938949A3CcF3960537A01BDA9973D6C8DEE0` (EOA) | Uniswap-V3 fork; top pools live (USDL/DAI 0x c2e1…, HEX/WPLS, PLSX/WPLS); positions are NFTs, pool balances == pool accounting; no permissionless drain fn in factory/pool (owner-gated fee setters) | $0 E-U (P-only admin) |
| Phux | ~$1.10M | Vault `0x7F51AC3df6A034273FB09BB29e383FCF655e473c`, authorizer `0x3a68EE6D3849C4776130f13Cd86F0BcC0738F4C3` | **Balancer V2 fork**. Checked the Nov-2025 Balancer rounding-exploit precondition (`_upscale` × non-unitary `_scalingFactors`): all **60/60** pools return `getScalingFactors()` divisible by 1e18 (rate providers are all `0x0`; stable pool sfs = [1e30,1e30,1e18,1e18]) ⇒ `mulDown` is exact, exploit N/A | $0 E-U |
| 9inch | ~$273k | factory `0x5b9F077A77db37F3Be0A5b5d31BAeff4bc5C0bD7` (9,881 pairs), feeTo `0x3fefd0…`, MasterChefV2 `0x444775Ae2C82560337c86f6D62909a63381De4fd` | Uniswap-V2 fork; MasterChefV2 owner `0xC3dddAAaEb5257D46b241e7A43b26fBf2121D94B` (EOA); `withdraw` requires `user.amount >= _amount`; `emergencyWithdraw` only caller's own stake; admin fns `onlyOwner`; pool balances == reserves | $0 E-U (users can exit = H-O) |
| Finvesta | ~$91k | V3 positions NFT `0xEdab52594aF0763502A9D5b4975854BBbd5e9e08` | Uniswap-V3 style pools; no farm/staking contract found holding residual value; pools small | $0 E-U found |
| Liberty Swap | apparent $28.8B (fake) | V3 factory `0x796fcbDC956b85797EFe21145Aa97599B7FB36a6` | BXUSD pools: GT reserve is fake ($1-priced BXUSD). On-chain: BXUSD/DAI holds **37.8 DAI**, USDC/BXUSD holds 96.6 USDC, USDT/BXUSD holds 274.5 USDT. Real stable side ≈ **$410 total**; BXUSD is a third-party token (owner EOA) | $0 E-U from DEX contracts; ~$410 token-honeypot surface, not a DEX bug |
| SparkSwap | ~$11k | pools incl. SPARK/WPLS | V2-style pools; no excess; dust | $0 |
| EazySwap | ~$1.1k | LP `0x3525f612…`, `EasySwapDistributor 0x1430E243005a0d3934d592713b55f40da162B483` | Distributor: `withdraw` requires `user.amount >= _amount`; admin `onlyOwner`; pools dust | $0 |
| Dextop | ~$6.8k | V2 pools | dust pools, balances == reserves | $0 |
| Function Island | ~$361 | V2 pools | dust | $0 |
| Velocimeter | ~$465 | V2 pools | dust | $0 |
| WizardSwap / PulseGun | 0 pools | — | no live pools returned by GeckoTerminal | n/a |
| pDex.vision | ~$4.1k | V3 pools ("DAI/DAI") | dust | $0 |

## Evidence details

### Phux (Balancer V2 fork) — why the $128M Balancer bug does not apply
- Vault source: Balancer V2 `Vault is VaultAuthorization, FlashLoans, Swaps` (verified at `0x7F51AC…`).
- The Nov-2025 exploit required `ComposableStablePool._scalingFactors()` returning **non-unitary** factors
  (exchange-rate × decimals), where `_upscale = FixedPoint.mulDown` truncates.
- All 60 Phux pools (GT pages 1–3) responded to `getScalingFactors()`; every factor `% 1e18 == 0`
  (unitary rates; `getRateProviders()` on the stable pool = all zero). Truncation is therefore exact ⇒ no exploit.
- Stable pool `0xf96d60e9444f19fe5126888bd53bde80e58c2851`: sfs `[1e30,1e30,1e18,1e18]`, `version=ComposableStablePool v2 (20221122)`.
- Latent risk: if Phux governance ever attaches a non-unitary rate provider to a ComposableStablePool, the
  inherited rounding path becomes exploitable; that is a governance action (P), not E-U.

### 9inch MasterChefV2 (verified source `MasterChefV2`)
- `withdraw(pid, amt)`: `require(user.amount >= _amount)` then `user.amount -= amt` before transfer.
- `emergencyWithdraw(pid)`: operates only on `userInfo[pid][msg.sender]`.
- All value-moving admin functions (`add/set/updateBBCRate/burnBBC/updateBurnAdmin/updateWhiteList/transferOwnershipOfBBC`) are `onlyOwner`.
- Owner `0xC3dddAAaEb5257D46b241e7A43b26fBf2121D94B` is an EOA (code size 0) ⇒ P/S class.

### 9mm V3
- Factory owner is an EOA (code size 0); `protocolFeeController()` not present/reverts on this fork build.
- No permissionless function was found that moves pool funds to an arbitrary caller; positions are owned per NFT.

### Pool-level scan (all secondary venues, 220 resolvable pools)
- Only 2 pools showed excess (WPLS/GYRE 0.14 GYRE dust; 9inch WBTC/DAI re-checked at a pinned block:
  balances == reserves — the earlier "deficit" was a cross-block read artifact).
- Script: `venue_pool_scan.py`, raw: `venue_pool_excess.json`.

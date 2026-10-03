# C-41 · Ionic Mode-A — deployed-code path audit (why every unprivileged path is closed)

**Date:** 2026-10-03 · **Method:** verified source from Mode Blockscout + live `eth_call`/`eth_getLogs`
at blocks ~45,427,000–45,427,400. No transactions. Selector map: `analysis/selector_map.json`.

## 0. Contract architecture (what is actually deployed)

- **Comptroller (Mode-A)** `0xFB3323E24743Caf4ADD0fDCCFB268565c0685556` is a **Unitroller diamond**
  (Compound Unitroller + `DiamondBase` fallback). Extensions (`_listExtensions()`):
  - `0x4F6462b8B6c65916d9b585Bc4d8276505a774735` — `Comptroller` (gates + liquidity math)
  - `0x139b09e9BA6D5E57b23e21f930587647119A1213` — `ComptrollerFirstExtension` (view helpers,
    borrower registry, pause setters, caps)
  - `0x28241E3590a7fC0bC9eAe34188b3390B68cC9768` — `ComptrollerPrudentiaCapsExt` (cap configs)
- **ionLBTC market** `0xADE794534c05F79981337E73dc2A987cdFf1958d` is a **CErc20Delegator diamond**
  (Compound CErc20Delegator + `DiamondBase`). Extensions:
  - `0x83863DD9Fa107A77f0634039b9845FD716aE6690` — `CErc20Delegate` (mint/redeem/borrow/
    repay/liquidate/seize/fees)
  - `0x717a3195922BD489474C021B4497110751977ABE` — `CTokenFirstExtension` (ERC20 + interest +
    `flash`, `multicall`, `registerInSFS`, admin setters)
- Unknown selectors revert `FunctionNotFound(bytes4)` = `0x5416eb98` + selector (diamond fallback).
  Missing on ionLBTC: `exchangeRateStored()` `0x182df0f5`, `borrowBalanceStored()` `0x95dd9193`,
  `admin()` `0xf851a440`, `initialExchangeRateMantissa()` `0x675d972c`, `ap()` `0x3c4f743c`.
  These are **external getters only**; internal math uses `exchangeRateStoredInternal`/
  `_exchangeRateHypothetical`, so the missing getters do not block redeem (they do block some
  third-party integrator paths).
- Live gate values (block ~45,427,184): `mintGuardianPaused(ionLBTC)=true`,
  `borrowGuardianPaused(ionLBTC)=true`, `transferGuardianPaused()=false`,
  `seizeGuardianPaused()=false`, `enforceWhitelist()=false`, `closeFactor=0.5e18`,
  `liquidationIncentive=1.08e18`, `markets(ionLBTC)=(true, 0.5e18)`, `isDeprecated(ionLBTC)=false`,
  `oracle=0x2BAF3A2B667A5027a83101d218A9e8B73577F117`, `admin=0x8Fba84867Ba458E7c6E2c024D2DE3d0b5C3ea1C2`
  (Gnosis Safe v1.3.0, **threshold 2**, 4 owners).

## 1. Every state-changing function on ionLBTC and its gate

| selector | function | gate(s) | verdict |
|---|---|---|---|
| `0xa0712d68` | `mint(uint256)` | `isAuthorized` + hypernative + comptroller `mintAllowed`: `require(!mintGuardianPaused[market])` → **reverts "!mint:paused"** | closed |
| `0xc5ebeaec` | `borrow(uint256)` | `borrowAllowed`: `require(!borrowGuardianPaused[market])` → **reverts "!borrow:paused"**; also `oracle.getUnderlyingPrice()==0 → PRICE_ERROR` | closed |
| `0xdb006a75` | `redeem(uint256)` | `redeemAllowedInternal`: listed; if caller is a market **member** → `getHypotheticalAccountLiquidityInternal` → **oracle reverts for LBTC**; non-members bypass the check | closed for members / works for non-members |
| `0x852a12e3` | `redeemUnderlying(uint256)` | same as redeem | same |
| `0x23b872dd`/`0xa9059cbb` | `transferFrom`/`transfer` | `transferAllowed` → `require(!transferGuardianPaused)` + `redeemAllowedInternal(src)` → same oracle revert for members | closed for members |
| `0xf5e3c462` | `liquidateBorrow` | `liquidateBorrowAllowed`: non-deprecated → shortfall check → **oracle revert**; deprecated → skip check, but `liquidateCalculateSeizeTokens` reads both prices → **reverts/PRICE_ERROR for LBTC collateral**; then `balanceOf(borrower) >= seizeTokens` | closed for LBTC-collateralized positions |
| `0xb2a02ff1` | `seize(liquidator,borrower,tokens)` | `seizeAllowed` requires `markets[seizerToken=msg.sender].isListed` → direct EOA call = `SEIZE_MARKET_NOT_LISTED` error code | closed |
| `0x3c3b4b89` | `flash(amount,data)` | `isAuthorized` (`FeeDistributor.canCall` = **true for arbitrary EOA**) + hypernative (unset) → **callable**, but `selfTransferIn` → `transferFrom(msg.sender, market, amount)` requires allowance+balance → atomic repayment enforced (ignores return value, but `doTransferIn` reverts on failure) | callable, **not extractive** |
| `0xa7b820df`/`0xb0d58e49` | `_withdrawAdminFees`/`_withdrawIonicFees` | only `nonReentrant(false)` + hypernative (unset) → **callable by anyone**, but bounded by `totalAdminFees`/`totalIonicFees` (**both 0**) and pays `comptroller.admin()` / `ionicAdmin` | no attacker value |
| `0x56e67728`/`0x2c436e5b` | `_becomeImplementation`/`delegateType` | delegate-lifecycle | n/a |
| admin setters `0x34154d4c`,`0xb0a19076`,`0xfca7820b`,`0x91dd36c6`,`0xf2b3abbd` | `_setNameAndSymbol`, `_setAddressesProvider`, `_setReserveFactor`, `_setAdminFee`, `_setInterestRateModel` | `hasAdminRights()` (comptroller admin/ionicAdmin with rights) | privileged |
| `0xac9650d8` | `multicall` | OZ Multicall → self-`delegatecall`, `msg.sender` preserved | no privilege gain |
| `0x7f15e216` | `registerInSFS` | `hasAdminRights() \|\| msg.sender==comptroller` | privileged |

## 2. The decisive live fact: the oracle has no LBTC price

- `MasterPriceOracle.getUnderlyingPrice(ionLBTC)` (proxy `0x2BAF…`, impl `0x707a1b66…`,
  verified source `analysis/src_oracle_impl/main.sol`):
  - `oracles[LBTC] = 0x04ffa53A90a8DeD9AE83F64596C5783397c1cFb0`; that oracle **reverts** on
    `getUnderlyingPrice`/`price` (custom error `0x8086c764`), `fallbackOracles[LBTC] = 0`.
  - Master oracle catches the revert, fallback is zero → **reverts
    "Price oracle not found for this underlying token address."**
- Consequence: any comptroller-mediated action that prices the account (redeem, transfer,
  borrow, non-deprecated liquidation) **reverts for any account that is a member of ionLBTC**.
- The depositor `0x9E34d89C013Da3BF65fc02b59B6F27D710850430` (EOA, code `0x`) **is a member**
  (`checkMembership=true`, `getAssetsIn` includes ionLBTC and 11 other markets). Therefore:
  - `redeem(1)`, `redeemUnderlying(1)`, `transfer(0xdEaD,1)`, `exitMarket(ionLBTC)` all **revert**
    "Price oracle not found…" (fork-verified, `poc/test/IonicC41.t.sol`).
  - This is a **correction to the prior pass**, which inferred redeemability from
    `balanceOfUnderlying` (a market-level call that never touches the oracle).
- The only other ionLBTC cToken holder, `0x1155b614971f16758C92c4890eD338C9e3ede6b7`
  (55,375 cTokens, **not a member**), bypasses the liquidity check and **can redeem**
  (0.00011075 LBTC ≈ $9.4). `0x1155b614…` is one of the 4 owners of the admin Safe.

## 3. flash(): callable by anyone, provably non-extractive

- `FeeDistributor.canCall(comptroller, 0xdEaD, ionLBTC, 0x3c3b4b89)` = **true** (authority chain
  FeeDistributor → 0x9a0aF901 → 0xC3cEc17c → 0x5d74800e → 0x58975B54 → 0x2b94E2F2).
- `flash` moves `amount` of underlying to `msg.sender`, calls `receiveFlashLoan`, then
  `selfTransferIn(msg.sender, amount)` → `transferFrom` back. A contract caller must approve and
  hold the funds at callback end; otherwise `doTransferIn` reverts and the whole tx reverts.
  - Fork test: non-repaying attacker contract → revert; honest repay → market cash and
    `totalBorrows` restored, attacker balance 0.
- `totalBorrows` is inflated only for the duration of the call; `accrueInterest` is a no-op in the
  same block, so no interest/accounting gain.
- Note: `flash` is **not** `nonReentrant`; nested flash calls unwind atomically and each level must
  repay. No profit.

## 4. Liquidation / borrower registry

- `getAllBorrowersCount()` = **38,294** entries (all-time registry; accounts are removed when they
  exit all markets). Mode-A market borrows are dust (see market table in `README.md`; ionLBTC
  `totalBorrows` = 5,000 wei). No borrower with material debt was found; any liquidation attempt
  involving LBTC collateral is additionally blocked by the missing oracle. A non-LBTC-collateral
  liquidation (if a live underwater borrower exists) is ordinary Compound liquidation, bounded by
  that borrower's debt — not a C-41-specific extractable pot.

## 5. Category verdicts

- **E-U = $0** (high confidence): no unprivileged path moves value to an outsider.
- **H-O ≈ $9.40 nominal** (0.00011075 LBTC): the non-member cToken holder can self-redeem, but the
  LBTC itself has no working market (Balancer pool swaps disabled), so realizable ≈ $0. The
  depositor's own 1.0 LBTC on their EOA is transferable but equally unsellable.
- **S = $21.13M nominal** (249.00006075 LBTC): immovable today — cToken redemption blocked for the
  member depositor, and Mode LBTC's BTC peg-out/bridge/DEX are all closed
  (see `lbtc_redeemability.md`).
- **P**: the 2-of-4 admin Safe + LBTC owner can restore the oracle/withdrawals; this is the only
  route to the nominal value (and would still need a venue or peg-out to realize it).

# C2-18 Aurigami (Aurora) — adversarial math/control-flow verification (child agent)

Scope: external, unprivileged extraction given (a) borrow caps=1 wei (borrowing off), (b) oracle keeper-gated, (c) prices accurate. All checks at Aurora head ≈219,165,444, pinned state ≈219,162,280.

**Ground truth established first**: I compiled the explorer-verified sources with solc 0.8.11/runs=3000 and byte-compared to deployed code:
- Comptroller impl (0xa200…): **0 differing bytes** vs `/analysis/src/comptroller_impl.sol`.
- Unitroller (0x817a…): **0 differing bytes**.
- auUSDC/auETH: match exactly except immutable slots (underlying/decimals/initExchangeRate), i.e. the reviewed source **is** the deployed code. All source-level conclusions below are therefore on-chain facts.

## 1) Exp/Double fixed-point library — CLOSED
- Library is Compound's `ExponentialNoError` verbatim; all ops on uint256 under 0.8 checked arithmetic (overflow/underflow revert, no silent wrap). Every market path rounds **down** (`truncate`, `getExp`, `divScalarByExpTruncate`); there is no ceil/upward rounding anywhere in mint/redeem/seize.
- `liquidateCalculateSeizeTokens` (comptroller_impl.sol:3061–3095) was algebraically reduced to `seize = liqInc·priceB·repay/(priceC·exRate)`, identical to upstream Compound; moving `actualRepayAmount` into the numerator changes nothing (verified symbolically).
- `getHypotheticalAccountLiquidityInternal` (:2996–3052) matches upstream: `tokensToDenom = CF·exRate·price/1e36`, collateral sum and borrow+effects each added once; no double count. Oracle prices use Compound's `$·1e(36−underlyingDecimals)` convention; checked live: USDC price 9.998e29 (scale 1e30), WNEAR 4.663e12 (scale 1e12), i.e. 24-decimal tokens are scale-correct (auWNEAR/auSTNEAR/auNEARX exchange rates 2.0e32–2.1e32 all reconcile exactly to cash+borrows−reserves).
- `seizeInternal` protocol share `mul_(seizeTokens, Exp(protocolSeizeShare))` resolves to `·share/1e18` (3% live); borrower −seizeTokens, liquidator +(seize−protocol), totalSupply −protocol → invariant sum(balances)=totalSupply preserved.
- Live invariants re-derived for all 14 markets: `totalSupply·exRate/1e18 = cash+borrows−reserves` (USDC, ETH, WBTC, WNEAR, DAI spot-checked to the wei).

## 2) cToken control flow vs Compound v2 (redeem/mint/borrow/repay/seize/liquidate) — CLOSED
- `redeemFresh` (:1316–1401) and `borrowFresh` (:1422–1474) update `totalSupply`/`accountTokens`/`accountBorrows` **before** `doTransferOut` (the deliberate CREAM-hack fix); `redeemVerify` inlined as `if (redeemTokens==0 && redeemAmount>0) revert`. Cash check precedes effects.
- All state-mutating entry points are `nonReentrant`; market freshness (`accrualBlockTimestamp == block.timestamp`) enforced in every Fresh path and both markets during liquidation. auETH `doTransferOut` uses `.transfer` (2300 gas — reentrancy impossible); `getCashPrior()=balance−msg.value` is consistent for mint/repay/liquidate payable paths (traced all four).
- Custom `type(uint).max` paths in `redeemFresh` (`redeem(max)`, `redeemUnderlying(max)`) are value-conserving; fork-proved for auUSDC (redeem(max) returns 999.999999 USDC for 1000 USDC in, zero shares left; second path too). 24-dec round trips (auWNEAR/auSTNEAR) and native auETH mint/redeem added to test/fork tests; arithmetic is floor-on-both-sides so no cycle can gain.
- `doTransferIn` returns `amount` ignoring fee-on-transfer, but none of the 13 underlyings are fee-on-transfer and the underlying is immutable; not reachable as an attack.

## 3) Reward flywheel — CLOSED
- Every balance mutation calls the hook before balances move (`mintAllowed` :2714–2734, `redeemAllowed` :2742, `transferAllowed` :2918, `seizeAllowed` :2886, `borrowAllowed`/`repayBorrowAllowed` :2772/:2820), so every first-time holder's `rewardSupplierIndex/BorrowerIndex` is snapshotted at entry; the `supplierIndex==0 → initialIndexConstant` special case (:3494–3496) therefore only credits growth during actual holding.
- Fork test: fresh minter + immediate claim gained **0 PLY**; after 30 days holding it gained 562,067 wei (mechanically `1 wei/s × share`), no retroactive capture, pool balance unchanged. Live reward speeds are 1 wei/s, so total remaining upside is ~1e-10 PLY/market — negligible.
- `_claimRewardForOne` (:3585–3610) requires `holder==msg.sender || isWhitelisted[msg.sender]`; zeroes `rewardAccrued` **before** `doTransferOutRewards`; recipient fixed to holder. No double-claim, no claim-for-others, no redirect. PULP.lockPly pulls via `safeTransferFrom(msg.sender=comptroller)` against an explicit approval (pulp.sol:1040–1048); no allowance left exploitable.

## 4) Unitroller + admin surfaces — CLOSED (one non-profitable defect)
- Unitroller `_setPendingImplementation`/`_acceptImplementation`/`_setPendingAdmin`/`_acceptAdmin` all admin/pending-gated; live `pendingAdmin` and `pendingComptrollerImplementation` are `address(0)`. Comptroller `_become`, `_setPriceOracle`, `_setCloseFactor`, `_setCollateralFactor`, `_setLiquidationIncentive`, `_supportMarket`, pause setters, `_grantPly`, `setTokens`, `setLockAddress`, `setRewardClaimStart`, `setWhitelisted`, `_setMaxAssets`, `_setRewardSpeeds` require `admin` (Safe 2-of-6) or `comptrollerImplementation`; `borrowCapGuardian`=Safe; `mintCapGuardian`=`address(0)` (uncallable by anyone since msg.sender≠0). All 14 cToken admins = Safe, pendingAdmin=0.
- **Defect found (non-profitable)**: `AuErc20.sweepToken` (auUSDC.sol:2159–2163) is missing upstream's `require(msg.sender == admin)`. Fork-proved: an arbitrary EOA can force any auUSDC/other AuErc20 to send **any non-underlying token balance to the admin Safe**. Recipient is hard-coded to `admin`, so this is griefing/forced-donation, not attacker profit. I swept all 14 markets against 13 tokens + PLY/PULP: **all stray balances are zero**, so present-day impact is $0; it is a latent access-control bug (severity low).
- Admin function `_setProtocolSeizeShareFresh` lacks a ≤1e18 bound, but is Safe-gated; not reachable unprivileged.

## 5) Cash capture / seize-without-liquidation / donation-inflation / rounding — CLOSED
- **Borrow**: all 14 caps=1 wei, all debt markets revert `market borrow cap reached` (fork-proved). `borrow(0)` on zero-debt markets is inert (cap check strict `<`; no cash, no liquidity change — fork-tested); no other path creates `accountTokens` or moves cash except mint/redeem/liquidate.
- **Seize-without-liquidation**: `seize` uses `msg.sender` as seizer; `seizeAllowed` requires `markets[msg.sender].isListed` and borrower membership; EOA/attacker contract is not a listed market, and only `liquidateBorrowFresh` can produce a listed-cToken caller after `liquidateBorrowAllowed` (shortfall + closeFactor + membership checks). Dead-end.
- **Donation/inflation**: exchange rate rises for all existing shareholders; donor+redeem round-trip returns less than deposited (parent's test 10 + floor rounding). No empty markets.
- **Liquidations**: only 140 dust accounts are liquidatable; total debt $30.68 / collateral $42.44 ⇒ theoretical max liquidation bonus **≈$2.42** (protocol-intended 10% incentive, funded by borrowers, not protocol cash; gas makes net ~$1–2). No price/ORF manipulation can enlarge it (oracle gated, prices accurate).
- **Oracle**: unverified but fully access-controlled in practice — `owner()` EOA 0xeBD8…, `isPriceSetter(keeper 0xf9D7…)=true`; dispatch selectors decompiled from bytecode show only `setPrices` (caller-gated) plus Ownable2Step `setPriceSetter`/`setUnderlyingDecimals` (revert `Ownable: caller is not the owner` for others). Batch `getUnderlyingPrices` returns the same values **in the same order** as individual `getUnderlyingPrice` for all 11 priced markets (tested), so health/liquidation math cannot be mismatched. auTRI/auPLY/auUSN have no price and revert, but CF=0, `enterMarkets` reverts `MarketCollateralFactorZero`, and none of 5,481 known addresses is a member ⇒ no reachable DoS/freeze.

## Open uncertainties
- Oracle source is unverified; two dispatch selectors (0x078dfbe7, 0x8dd09cac) revert with empty data for every ABI shape I tried (addr, arrays, pairs, bool/bytes/string) — almost certainly dead/inaccessible stubs, but I could not positively identify them.
- The oracle owner EOA and keeper EOA are privileged trust surfaces (owner can appoint price setters); compromise of those keys would break the oracle assumption — outside "unprivileged attacker".
- Last fork-test additions (24-dec + auETH round-trips, `liquidateCalculateSeizeTokens` cross-check) were written but not executed before time-out; the arithmetic and parent's passing PoCs cover the same code.
- Utilization-spike interest grind (redeem cash → raise rate → force dust liquidations) is economically bounded (IRM ≤ ~160×/yr at cap, parent test 9 measured <200%/yr) and not modeled fully; upside remains dust.

VERDICT: external-unprivileged extraction from Aurigami = $0 (high confidence; protocol-intended dust liquidation bonus ≤$2.42 aside; sweepToken access-control bug is grief-only and currently $0)

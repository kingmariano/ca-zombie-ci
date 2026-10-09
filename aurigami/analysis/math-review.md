# C2-18 Aurigami — custom math & path review

Author: C2-18 deep-dive agent. Date: 2026-10-09. Chain: Aurora (1313161554).
Read-only review of verified deployed sources + live `eth_call` probes. No mainnet transactions.

Sources (verified, downloaded from explorer.aurora.dev):
- `analysis/src/unitroller.sol` — Unitroller proxy + storage (`0x817af6cf…`).
- `analysis/src/comptroller_impl.sol` — Comptroller implementation `0xa200b567579a577f582d292f7a1b5c4ecce195f8`.
- `analysis/src/auUSDC.sol` — `AuErc20` cToken (all ERC20 markets), `analysis/src/auETH.sol` — `AuETH`.
- `analysis/src/irm.sol` — `JumpRateModel` (per-timestamp).
- Oracle `0x5A7B8E3CDc6ee2E0E6Ad0d4fab8dCD70990157EE` is **unverified** (4474 bytes); behaviour probed live.

## 1. Fixed-point library (custom `Exp` / `Double`)
`ExponentialNoError` (comptroller_impl.sol lines ~546-680) defines:
- `expScale = 1e18`, `doubleScale = 1e36` (two int256 "types" `Exp`, `Double`).
- `getExp(num,denom) = num*1e18/denom` (used for exchange rates).
- `mul_(Exp,Exp)`, `div_(Exp,Exp)`, `mulScalarTruncate`, `divScalarByExpTruncate`,
  `mul_(uint,Double) = a*b/1e36`, `fraction(a,b) = a*1e36/b`.

These are the standard Compound-style semantics with Solidity 0.8 checked arithmetic (every
overflow/underflow reverts). No unchecked blocks, no assembly. `safe224()` guards the reward index.

## 2. Exchange rate / mint / redeem (AuErc20.sol)
- `exchangeRateStoredInternal()` = `(cash + totalBorrows - totalReserves) * 1e18 / totalSupply`;
  when `totalSupply == 0` it returns the initial rate (never live today: all 14 markets have supply > 0).
- `mintFresh`: `mintTokens = actualMintAmount * 1e18 / exchangeRate` (floor). **No minimum-share check**
  (a dust deposit can mint 0 shares and donate value — lossy for the minter only).
- `redeemFresh`: `redeemAmount = exchangeRate * redeemTokens / 1e18` (floor, protocol-favouring);
  `redeemUnderlying` floors `redeemTokens`. `redeemTokens==0 && redeemAmount>0` reverts.
- **Cash check before transfer**: `getCashPrior() < redeemAmount → revert`, so cumulative withdrawals
  can never exceed the market's cash. `doTransferOut` is the last statement (CREAM-fix ordering), and
  all user entry points are `nonReentrant`.
- Numeric consistency check (block 219,162,280): auUSDC `(80,846.479291e6 + 29,011.557022e6 − 37,830.927197e6) / 312,477,184,543,299 × 1e18
  = 2.30503578113298e14` — exactly `exchangeRateStored()`. Same identity holds for all 14 markets.

## 3. Liquidity / borrow / liquidation math (Comptroller)
- `getHypotheticalAccountLiquidityInternal`:
  `tokensToDenom = CF ⊗ exchangeRate ⊗ oraclePrice` (two `mul_` with /1e18 each),
  `sumCollateral += tokensToDenom × auTokens / 1e18`,
  `sumBorrow += oraclePrice × borrowBalance / 1e18`.
  Verified against hand-computed values for 6-dec (auUSDC), 18-dec (auETH), 24-dec (auSTNEAR):
  e.g. auSTNEAR 330,567,083 units, CF 0.40, rate 2.000218e32, price 6.75e12 →
  collateral = $0.178 = 0.40 × (330,567,083 × 2.000218e32/1e36 × 6.75) exactly. **No decimal-scaling bug**
  for 24-dec tokens (the audit suspicion in C2-18).
- `liquidateCalculateSeizeTokens`: `seizeTokens = liqIncentive × priceBorrowed × repayAmount / (priceCollateral × exchangeRate)`
  with a single truncation at the end (protocol-favouring). Numeric check: repay 100 USDC against
  auETH collateral ⇒ 2.139…e8 cToken units = 0.04445 ETH = $110 (110% of repay) exactly as intended.
- `borrowAllowed` is dead in practice: **every market has `borrowCaps == 1` wei**, and the code
  `require(nextTotalBorrows < borrowCap)` therefore reverts "market borrow cap reached" for any borrow.
  This is the master blocker for the whole Tectonic/donation→borrow class.
- `liquidateBorrowAllowed` requires `shortfall > 0`, `repayAmount ≤ 50% × borrowBalanceStored`, and
  the borrower entered the collateral market.
- `seizeAllowed` requires `markets[auTokenCollateral].isListed && markets[auTokenBorrowed].isListed`
  where `auTokenBorrowed == msg.sender` — i.e. the caller must be a listed auToken. A direct
  `auUSDC.seize(victim…)` from an EOA reverts `MarketNotListed` (fork-proven, test_04).

## 4. Reward flywheel (PLY / AURORA)
- `mintAllowed` (comptroller_impl.sol ~2714) calls `updateAndDistributeSupplierRewardsForTokenForOne(auToken, minter)`
  **before** the cToken credits shares — a first-time minter snapshots the index with a zero balance
  (`supplierDelta = 0`), so there is **no retroactive index capture** despite the index having grown
  to 9.30e46 (auUSDC) since genesis. Fork-proven: a fresh minter + `claimReward(0,…)` received
  **0 wei PLY** (test_06). `redeemAllowed` / `transferAllowed` / `seizeAllowed` update the flywheel
  for both parties with pre-action balances.
- Rewards are claimable only by the holder or whitelisted claimers
  (`isAllowedToClaimReward(user, claimer) = user==claimer || isWhitelisted[claimer]`; admin Safe false,
  random false). Reward speeds are 1 wei/timestamp on every market (emissions ≈ 0).
- Pool balances: Unitroller holds **167,372,294.98 PLY** (~$6.2k) — backs already-accrued user rewards;
  Pulp holds **672.1M PLY** (~$24.8k) — user-locked, redeemable 1:1 after week 76 (now week ~231).
  Neither is reachable by an unprivileged attacker without a genuine reward accrual.

## 5. Interest / accrual
- `accrueInterest` uses per-timestamp rates; param sets: base 2%/yr (auUSDC) / 1%/yr (auETH,auWBTC),
  slope 10%/5%, jump 109%/yr after kink 0.8/0.75. `borrowRateMaxMantissa = 5e12` is never approached.
- Even with cash drained to 1 wei (max utilisation) the auETH rate is 1.2525e10/timestamp
  ≈ **39.5%/yr** (fork-confirmed in test_09). With the longest stale accrual window (~7 days) that is
  < 1% of outstanding debt — far too small to force borrowers into liquidation. No interest-spike weapon.
- Latent griefing edge: the IRM computes `cash + borrows − reserves` in checked arithmetic. If a redeemer
  pushes `cash` below `reserves − borrows` (possible in auUSDC today only below ≈$8.8k cash, i.e. after
  ~$72k of redemptions), every `accrueInterest()` call reverts (panic 0x11) and the market bricks for
  everyone else. No attacker profit (the redeemer simply extracts their own share); any third party can
  un-brick by transferring underlying directly to the cToken (raising cash). Documented as residual risk.

## 6. Oracle
- Live `getUnderlyingPrice` values match CoinGecko/DefiLlama within ~0.5% (ETH $2,474.40 vs $2,474.6;
  BTC $81,705 vs $81,727; AURORA $0.05874 vs $0.05885; stNEAR $6.750 vs $6.730; WNEAR $4.4722 vs $4.522;
  stablecoins $0.999-1.000). Keeper EOA `0xf9D72FED…` pushes 11 prices via selector `0xec3115f9`
  every ~30-90 minutes (fresh).
- The push selector reverts `"not price setter"` for any other caller (fork-proven, test_03);
  `setPriceSetter` is `Ownable` (owner EOA `0xeBD8251539A66d25202263D59a573A9DD3425f45`).
  No unprivileged price manipulation.
- auTRI/auPLY/auUSN have no oracle price ("underlyingDecimal not set"); they are also non-collateral
  (CF=0) and non-borrowable, so the revert only affects accounts that *entered* those markets
  (members' liquidity checks revert → their funds are S-stuck unless they have no enter-markets state).

## 7. Admin surface
- Unitroller admin = Gnosis Safe **2-of-6** `0x2D05FfFE70CE64c5954710D4C308dB31C8dBd8dE` (v1.3.0);
  `pendingAdmin=0`, `pendingComptrollerImplementation=0` (no in-flight upgrade).
- All Comptroller setters require `adminOrInitializing()` (`msg.sender==admin || msg.sender==comptrollerImplementation`);
  cToken admin functions (`_reduceReserves`, `_setReserveFactor`, `_setInterestRateModel`,
  `_setProtocolSeizeShare`, `_setPendingAdmin`) require `admin` or pending-admin acceptance.
  `sweepToken` is public but always forwards balances to `admin`, and cannot touch the underlying.
  `_addReserves` is public and only adds cash (no payout).
- Reserves (≈$117.9k) are admin-withdrawable only (P).

## 8. Verdict for the audit question
No custom-math or control-flow bug found that would let an unprivileged attacker take value:
borrowing is disabled (caps=1), the oracle cannot be pushed by outsiders and is accurate, liquidation
surface is $11.18 of shortfall across 140 dust accounts, reward indices cannot be captured retroactively,
and all admin paths are gated (Safe 2-of-6 + single-EOA oracle owner). The dominant value (~$1.12M
supplier claims) is holder-owned (H-O), not attacker-extractable.

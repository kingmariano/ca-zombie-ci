# Nile CL (Linea) — adversarial review: Ramses-specific boost / period / reward code

**Date:** 2026-10-13 · **Chain:** Linea (59144) · **Mode:** read-only, no transactions, keyless RPC only.
**Scope:** deployed sources in `analysis/src_files/` — `ClPool` (`0xeD48f13B…8e33f`), `Position`/`LiquidityMath`/`Oracle`/`Tick`/`States`/`ProtocolActions`,
`GaugeV2` (`0xEB4AA37c…74b1`), `FeeDistributor` (`0xc2b256f2…7B7C`), `FeeCollector` (`0x2b70fac9…1594`), plus the callers that drive them (`Voter`, `NonfungiblePositionManager`).
**Adversary model:** external, unprivileged (no keys/roles/whitelist), may use own capital/flash liquidity and arbitrary contracts.

**Live anchors (keyless reads, 2026-10-13):** pool period **2962**; factory `feeProtocol()` = 100 (all swap fee → protocol); FeeCollector `treasury()` = `0xF7a8b377…ea9b` (BribeHolder), `treasuryFees()` = 10000 (100%), `voter()` = Voter; factory `feeCollector()` = `0xAAA2A499…4A2f` (FeeCollector proxy); Voter `nfpManager()` = `0xAAA78E8C…946A`, `_ve()` = `0xAAAEa1fB…Ce6F`.
**Header result: no path found for an unprivileged attacker to move pool/gauge/distributor tokens to themselves beyond their own pro-rata claim. Two genuine bookkeeping bugs exist in the boost code; both are reward-share/accounting corruptions, bounded by the per-period `tokenTotalSupplyByPeriod` cap, and are economically moot for live claims (period > 2830 pays no boost at all, see §Q3).**

---

## Q1 — Boost attach/detach/switchAttachment (`Position._switchAttached`, NFP mint/switch/batch)

**Verdict: NOT EXPLOITABLE for token extraction. One real unchecked underflow + two bookkeeping de-syncs found; impact limited to boosted-reward share (zero for periods > 2830).**

Mechanics (refs): `ClPool.mint(…veNftTokenId…)` (ClPool.sol:676-734) and `ClPool.burn(…veNftTokenId)` (823-862) run `Position._modifyPosition` → `_updatePosition` (Position.sol:373-719). Attach/detach is `_switchAttached` (727-816). NFP path pre-checks veNFT approval in `mint` (NFP:156-164) and `switchAttachment`/`batchSwitchAttachment` (NFP:363-405); pool-level check `isApprovedOrOwner(msg.sender, veNftTokenId)` at Position.sol:737-742 (NFP exempted only because it already checked).

Attack attempts:

1. **Attach someone else's veNFT — blocked.** Position.sol:737-742 and NFP:156-164/367-375 require owner/approved of the veNFT; `votingEscrow` is fixed per pool (`ClPool.initialize`), so no fake escrow. `mint` with `veNftTokenId != max` additionally forces `recipient == msg.sender` (ClPool:692-694).
2. **Same veNFT reused across many positions — allowed by design.** `timesAttached` counts positions; `totalVeNftAmount` counts the veNFT once (795-803). For `veNftRatio >= 2.5%` the midpoint cap and the per-veNFT 100% usage cap are deliberately skipped (`Position.sol:503-505`, `569-574`), so each attached position gets full `1.5×` boost (`LiquidityMath.sol:47` hardcodes `boostRatio = 1.5e18`; the `Math.min(veNftRatio*10, …)` line is commented out at :46). Note this "uncap" is trivially reachable even legitimately: a **first/solo attached veNFT** yields `ratio = amount×1.5e18/amount = 1.5e18 ≥ threshold`. Effect is only share-of-boost, never principal, and for `period > 2830` boosted seconds pay 0 (§Q3).
3. **`timesAttached` underflow (real bug, Position.sol:757-766).** Trigger: period P position attached to veNFT `V`; in period P+1 nobody touches it (current-period `boostInfos[P+1].veNftInfos[V].timesAttached == 0`); owner calls `NFP.decreaseLiquidity(all)` → `PositionManagerAux` calls `pool.burn(…, veNftTokenId = V)` (PositionManagerAux.sol:44-50) → `_updatePosition` sees `newLiquidity == 0` and first detaches (Position.sol:388-392) → detach path computes `timesAttached = 0` then stores `0 - 1 = type(uint128).max` (unchecked in solc 0.7.6). Consequences: later attaches of `V` skip the `veNftAmountDelta +=` add (798-800), so `totalVeNftAmount` can be **0 while a veNFT is attached** → `LiquidityMath.calculateBoostedLiquidity` uses denominator 1 (`LiquidityMath.sol:41`) → ratio trivially ≥ threshold → full uncapped boost and bypass of the per-veNFT usage cap. A subsequent attach wraps `max + 1 → 0` (803), re-arming the counter. **Impact: reward-share corruption only.** It cannot move tokens out of the pool; gauge payout is still bounded by `tokenTotalSupplyByPeriod` and the ≤1-week per-position seconds clamp (Position.sol:967-974; GaugeV2:446-465).
4. **`veNftAmount` drift (Position.sol:791-792 vs 761-766, 809-815).** `totalVeNftAmount` adds `balanceOfNFT` at first attach but subtracts the *last detacher's* stored amount; since `balanceOfNFT` changes with lock decay/increases, the residual can be non-zero (clamped at 0 at 811-813). Direction that helps an attacker (denominator understated) requires the clamp to fire; the reverse direction only under-pays boost. Again share-only.
5. **Debt overflow — no practical path.** `secondsDebtDeltaX96 = ceil(|ΔL|·c/Q32)` with `c` bounded by `Δt·2^128/max(1,L_pool)` and per-tick max liquidity ~`2^128/numTicks`; worst-case product is far below int256 bounds; int128 cast at :591 cannot wrap for real `boostAmount` magnitudes (≤1.5×maxLiquidityPerTick ≪ 2^127).
6. **`veNftBoostUsedRatio` can be desynced** by the same wrap/clamp paths (`Position.sol:576-588`, `774-776`; the `used > positionUsed ? used − positionUsed : 0` clamp at 491-494 can understate the sum, and a later exact subtraction underflows to `uint128.max`, pinning `availableRatio` to 0). Effect: denies boost to later non-threshold positions (griefing / relative share), never extraction.

**Missing checks (recommendations):** `require(timesAttached > 0)` (or reset `timesAttached` at period rollover) at Position.sol:757; store the exact amount added per position instead of re-reading `balanceOfNFT`; add a `used >= positionUsed` require before :774.

---

## Q2 — `positionPeriodSecondsInRange` / `periodCumulativesInside` / `_advancePeriod` freezing or inflation

**Verdict: NOT EXPLOITABLE. The period second-accumulators are not inflatable from outside; `_advancePeriod`-before-state-change ordering is sound because every liquidity/boost mutation writes the oracle first with pre-change values.**

Key blocking invariant (verified in code):

* `Oracle.write` is called **before** `states.liquidity`/`states.boostedLiquidity` are changed in `_modifyPosition` (Position.sol:283-292, `liquidityBefore`/`boostedLiquidityBefore` used), and swap-end writes use start-of-swap values (ClPool.sol:1158-1170 with `cache.liquidityStart`/`boostedLiquidityStart`). Therefore every `observeSingle`/`newPeriod` extrapolation covers only intervals where the dividing liquidity was constant. `secondsPerLiquidity` increments are exact per interval, and `Σ_i L_i(interval) = states.liquidity(interval)` for in-range positions, so for any period `Σ_i secondsInside_i ≤ elapsed` and each position's claim is its true `∫ L_pos/L_pool dt`.
* `_advancePeriod` runs before the tx's state change (`ClPool.sol:84-87`, `90-132`): the boundary snapshot (`Oracle.newPeriod`, Oracle.sol:363-398) extends from the last observation to the boundary at the pre-tx state — which is the state that actually held over that stretch. An attacker can only move the tick/price in an earlier block, and that move itself wrote an observation; last-block swaps can bias `tickCumulative` (TWAP, Oracle.sol:392) but **not** the seconds accounting, which depends only on `delta` and liquidity.
* Multi-week idle gap: the whole gap is attributed to `states.lastPeriod` and the intermediate periods stay zeroed (ClPool.sol:96-131). Claims for `_lastPeriod` exceed 1 week → forced to **0** by the sanity cap (`Position.sol:967-974`); intermediate periods have no data → 0. Direction is under-payment/DoS, never over-payment.
* `positionPeriodSecondsInRange` is a view; `FTR` requires `period <= states.lastPeriod` (:886-889); checkpoint liquidity uses only periods already written (:899-921); the `int160` wraparound at :926-933 is caught by the ≤1-week sanity check.
* `periodCumulativesInside` mixes absolute/relative per-period outside values across tick crosses (`Tick.cross` Oracle.sol/Tick.sol:242-272), which can mis-value claims when a tick is crossed between attach and claim. Observed directions: with matched tick states the checkpoint offsets cancel exactly (genuine seconds); with mismatched states the absolute-magnitude offset is huge → `>1 week → 0`. No claim can *land* in the (0, 1 week] window at an inflated value this way.

**Residual:** the tick-cross/outside-value handling is under-tested and can silently zero legitimate claims for periods that straddle crossings (liveness/under-pay risk), and permissionless `notifyRewardAmount` → `pool._advancePeriod()` (GaugeV2:268) merely finalizes the current period early at the correct boundary.

---

## Q3 — GaugeV2 claim path (`cachePeriodEarned`/`getReward*`/`periodClaimedAmount`)

**Verdict: NOT EXPLOITABLE. Same period cannot be paid twice; aggregate payout per period is bounded by `tokenTotalSupplyByPeriod` × (1-week-capped seconds); for all live periods boost pays nothing.**

* Repeat-claim blocked: `periodClaimedAmount[period][positionHash][token]` is added before transfer and subtracted on every recompute (`GaugeV2:467-472`, `690-693`); `getPeriodReward` (:478-555) and `getReward`/`getRewardForOwner`/`getReward(owner,index)` paths (:557-626, `_getAllRewards` :628-667) all route through `_getReward` and are subject to the same accumulator; `lastClaimByToken` bookkeeping (re-set to `currentPeriod-1` at :665) keeps the in-progress period incremental, not reset.
* Finalized-period values are frozen once written (`periodAmountsWritten`, :385-414), so later pool-state changes cannot re-inflate them.
* Over-supply blocked: payout = `baseRewards × secondsInside/(WEEK<<96)` (+ boosted part only for `period <= 2830`, :416-465). Per-position seconds ≤ 1 week (Position.sol:968-974) and **Σ over positions ≤ elapsed** (Q2 invariant) → aggregate ≤ `tokenTotalSupplyByPeriod[period][token]`. For all live periods (>2830) the boosted term is not even used (:447-465), so the boost bugs in Q1 have no live payout effect.
* Access: `getReward(tokenId,…)` requires NFP owner/approved (:568-589); `getRewardForOwner` only Voter/NFP (:591-614); the owner-indexed overload requires `msg.sender == owner` (:616-626). `Voter.claimClGaugeRewards` (:725-749) takes user-supplied `_gauges[i]`, but the ownership check is on the NFP whose id is used, the real gauge pays `nfpManager.ownerOf(tokenId)`, and a fake contract merely receives a call from Voter — it gains no allowance/state access (no path to `FeeDistributor._deposit`, which requires `msg.sender == voter` from the *Voter contract itself*, not from a callee).
* `retrieveLeftovers` is permissionless but pays `feeCollector.treasury()` only and `require(period <= 2830)` (:698-739) — reverts for the current period (live period 2962), so it is bricked, not exploitable.

---

## Q4 — FeeDistributor `_deposit/_withdraw` + `_getReward` + `getRewardForOwner`

**Verdict: NOT EXPLOITABLE. Non-veNFT holders cannot extract; veNFT holders cannot exceed pro-rata.**

* Claim math: `_reward = rewardSupply[P][token] × userVotes[P][id] / votes[P] − userClaimed[P][id][token]` (FeeDistributor.sol:105-124), with `userClaimed` accumulators (also in `earned`, :192). Repeat/period re-claim is impossible; `getPeriodReward` requires approved/owner of the veNFT (:149-156) and `period <= getPeriod()` (:111) which excludes the not-yet-distributing next period.
* `_deposit`/`_withdraw` are `require(msg.sender == voter)` (:203, :215). Both write only `getPeriod()+WEEK`, adding/removing `amount` symmetrically to `votes` and `userVotes`, so `Σ_id userVotes[P][id] == votes[P]` for every frozen period. `_withdraw`'s `if (userVotes[period][tokenId] > 0)` guard (:220-223) can only skip a decrement when the id has no weight in that period — it cannot create weight; an over-withdraw would simply revert (0.8 checked arithmetic / DoS at worst). No external caller can mint votes.
* `getRewardForOwner` is voter-only (:164-171) and always pays `IVotingEscrow(_ve).ownerOf(tokenId)`. The id "confusion" in `Voter.claimClGaugeRewards` (user passes NFP ids; NFP ownership is the gate while the payout goes to the *veNFT* of the same numeric id) is a griefing/UX quirk only: a caller can never redirect the payout, and a non-veNFT-holder can never receive.
* Splits/merges: nothing in Voter/FeeDistributor copies or rebalances `userVotes` for new ids; only Voter can write them. An escrow-side split therefore cannot create double weight; if it leaves the old id's votes untouched, rewards for it merely sit unclaimed (denominator unchanged).
* `notifyRewardAmount` is `msg.sender == pairFees` only (:229); `incentivize` is permissionless but only donates to next-period supply (:252-267). No caller-directed transfer exists in the contract.

---

## Q5 — FeeCollector `collectProtocolFees` reentrancy / parameter tricks

**Verdict: NOT EXPLOITABLE. The caller cannot make the FeeCollector send tokens anywhere except `treasury` or the voter-registered distributor.**

Flow (FeeCollector.sol:62-136): the pool argument and its `token0()/token1()` are caller-supplied, but:

1. **No live gauge path (:78-87):** only calls `pool.collectProtocol(treasury, max, max)`. For a real pool this is gated by `onlyFeeCollector` (ClPool:76-81, :1352-1370) and pays the state variable `treasury`; a malicious fake "pool" is simply a contract the FeeCollector calls — the FeeCollector transfers nothing, so the caller gains nothing.
2. **Live gauge path (:95-127):** requires a gauge registered in the real Voter (`_voter.gauges(pool)` / `customGaugeForPool`, checked `isAlive`). Gauges can only be registered by `createGauge` (pair factory `isPair`), `createCLGauge` (real CL factory pool + whitelist/governor) or `createCustomGauge` (governor) — an attacker cannot register a gauge for a fake pool, so the `feeDist` always comes from `voter.feeDistributors(gauge)` (never caller input) and the pool must be a real pool whose `factory.feeCollector()` is this FeeCollector. Destination is `treasury` (100% today) and the real distributor via `notifyRewardAmount` (pairFees = FeeCollector). No reentrancy is useful: there is no state the caller can flip, and reentering `collectProtocolFees` just repeats the same treasury-bound flow.
3. **Quirk, not extraction:** the split uses `token.balanceOf(address(this))` (a full-balance sweep, :102-103) rather than the collected amounts. Any stray/donated WETH/USDC resting in the FeeCollector would be swept to whichever eligible pool is collected first (treasury and/or that gauge's distributor). The destination is never the caller; today the contract holds $0 (parent CI scan), so this is inert.

---

## Summary & confidence

| # | Topic | Verdict | Blocking mechanism | Confidence |
|---|---|---|---|---|
| 1 | Boost attach/detach/switch | **Not exploitable** (2 real accounting bugs, share-only) | token custody only via position liquidity; boost affects only ≤2830 reward share, bounded by gauge supply | High on no extraction; med-high on full wrap-sequence enumeration |
| 2 | Period / seconds-in-range | **Not exploitable** | observation-before-mutation invariant; per-position ≤1 week clamp; Σ ≤ elapsed | High |
| 3 | Gauge claim path | **Not exploitable** | `periodClaimedAmount`; frozen finalized data; payout ≤ `tokenTotalSupplyByPeriod` × seconds share | High |
| 4 | FeeDistributor | **Not exploitable** | voter-only deposits/withdrawals; `isApprovedOrOwner`; `userClaimed` caps; payout always to veNFT owner | High (VotingEscrow internals not reviewed; it cannot write vote state, only Voter can) |
| 5 | FeeCollector | **Not exploitable** | destination is `treasury` / Voter-mapped distributor only; gauge registration gated | High |

No exploit PoC was warranted: no path was found that ends with an attacker-controlled address receiving tokens beyond its own claim, and the two boost bugs found (unchecked `timesAttached - 1`; `veNftAmount`/`totalVeNftAmount` drift) corrupt only reward *share* inside the gauge's per-period supply cap — worth fixing in any redeployment, but not extractable against the live zombie system (and moot for periods > 2830, which pay base seconds only). This review is code-inspection only (no fork tests executed here); line references are to `analysis/src_files/`.

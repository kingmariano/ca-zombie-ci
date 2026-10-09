# Solend v1 (Save/ex-Solend) — money-path gates memo

Program: `So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo` (`token-lending/sdk/src/lib.rs:15-18`).

Deployed source verified:
- Clone: `/tmp/opencode/solana-program-library`, branch `mainnet`, `git log -1` = `d04ce00bbf4356c4fd32b3be38eb9760b696bb3e` (Wed Jul 2 03:42:51 2025 -0700, "update max price offset (#220)"), working tree clean.
- Paths below are relative to that clone. `processor.rs` = `token-lending/program/src/processor.rs`; SDK state files = `token-lending/sdk/src/state/*`; oracles = `token-lending/oracles/src/*`.

Note on account lists: the inline doc comments in `token-lending/sdk/src/instruction.rs` still mention a "Clock sysvar (optional)" account. The processor does NOT read a clock account anywhere (it calls `Clock::get()?`, e.g. `processor.rs:1644`); the SDK instruction builders (which match the processor's `next_account_info` order) do not include it. Treat the processor + builders as authoritative; the doc comments are stale.

---

## 1. BORROW — `process_borrow_obligation_liquidity` (`processor.rs:1625-1909`)

### 1.1 Account order (processor.rs:1636-1645; builder `instruction.rs:1511-1551`)
0. source liquidity (must equal borrow reserve `liquidity.supply_pubkey`, `1666-1669`)
1. destination liquidity (`1670-1675`)
2. borrow reserve (writable; must be non-stale in this slot, `1680-1683`)
3. borrow reserve liquidity fee receiver (must equal `reserve.config.fee_receiver`, `1676-1679`)
4. obligation (`1694-1722`)
5. lending market
6. lending market authority PDA (`1724-1735`)
7. obligation owner (must be signer, `1707-1710`)
8. token program (must equal `lending_market.token_program_id`, `1652-1655`)
9.. `accounts[9..]`: one deposit-reserve account per `obligation.deposits`, in order (consumed by `update_borrow_attribution_values`, `1855`, and skipped by the iterator at `1864-1867`). Keys are sanity-checked against `collateral.deposit_reserve` (`1178-1181`); extras are not rejected here.
Optional after the deposit reserves: host fee receiver (`1872-1887`). If absent or `host_fee == 0`, no host fee is paid; the owner fee goes entirely to account 3.

### 1.2 Refresh requirements
- Borrow itself performs NO oracle refresh and NO interest refresh. It only checks `borrow_reserve.last_update.is_stale(clock.slot)` (`1680-1683` → `ReserveStale`).
- The obligation must already be fresh: `obligation.last_update.is_stale(...)` (`1711-1714` → `ObligationStale`). `RefreshObligation` in turn requires every collateral/borrow reserve to be non-stale (`973-1068`), and a reserve only becomes non-stale when some code path calls `_refresh_reserve_interest` in the current slot (`update_slot`, `616-617`), i.e. `RefreshReserve` (`600`) or an action that refreshes interest internally (`645, 788, 1238, 1368, 1383, 1941, 2273, 2358, 2614, 3256`). Staleness = flag set or `slot - last_slot >= 1` (`last_update.rs:6`, `43-45`).
- Practical required instruction sequence in the same tx: `RefreshReserve` for the borrow reserve and for every reserve in the obligation, then `RefreshObligation`, then `Borrow`, all in the same slot.
- `_refresh_reserve` itself is invoked only from `process_refresh_reserve` (`processor.rs:524`); `_refresh_reserve_interest` is invoked at `645, 788, 1238, 1368, 1383, 1941, 2273, 2358, 2614, 3256` (and inside `_refresh_reserve` at `600`). Borrow is not among them.
- A failed refresh returns Err (`InvalidAccountInput`/`InvalidOracleConfig`/`InvalidAccountOwner`, `543-558`, `570-590`, `3293-3311`) and aborts the whole transaction (Solana instruction atomicity — the borrow never executes); conversely, if no successful refresh exists, borrow fails `ReserveStale`/`ObligationStale`.

### 1.3 Health inequality gating the borrow
- `remaining_borrow_value = allowed_borrow_value - borrowed_value_upper_bound` (`obligation.rs:172-175`), clamped to zero with `BorrowTooLarge` if non-positive (`processor.rs:1764-1770`).
- For a normal (non-`u64::MAX`) borrow, requested `receive_amount = liquidity_amount`, fee is added (`borrow_amount = liquidity_amount + borrow_fee`), and the gate is:
  `market_value_upper_bound(borrow_amount) * borrow_weight <= allowed_borrow_value - borrowed_value_upper_bound` (`reserve.rs:326-341`, `265-269`; violation → `BorrowTooLarge` at `reserve.rs:338-341`).
- Price bounds used (all computed in `RefreshObligation`, `processor.rs:992-1109`):
  - `allowed_borrow_value` = Σ deposits `market_value_lower_bound * loan_to_value_ratio` (`1023-1035`), then `min(..., 65_000_000)` (`1122-1125`).
  - `borrowed_value_upper_bound` = Σ borrows `market_value_upper_bound * borrow_weight` (`1099-1107`).
  - `market_value_upper_bound` = `max(market_price, smoothed_market_price, extra_market_price)` × amount (`reserve.rs:112-123, 169-180`); `market_value_lower_bound` = min of the same three (`126-137, 184-195`).
  - `market_price`/`smoothed_market_price` are stored multiplied by `price_scale()` (scaled_price_offset_bps clamped to [-2000, +5000] bps) at refresh (`processor.rs:560-568`; `reserve.rs:86-104, 39-42`); `extra_market_price` is stored unscaled (`processor.rs:570-590`; config doc `reserve.rs:981-990`).
  - `borrow_weight = 1 + added_borrow_weight_bps/10000` (`reserve.rs:85-90`).
- `u64::MAX` borrow: size = `remaining_borrow_value * 10^decimals / price_upper_bound / borrow_weight`, then `.min(remaining_reserve_capacity).min(max_outflow_tokens).min(available_amount)`; fees are inclusive and `receive = floor(size) - fee` (`reserve.rs:304-325`; caps wired in `processor.rs:1772-1800`). `BorrowTooSmall` if receive == 0 (`1802-1805`).

### 1.4 Isolated collateral / borrows
- `ReserveType::Isolated` on the borrow reserve: obligation may have 0 other borrows, or exactly 1 borrow that is this reserve; otherwise `IsolatedTierAssetViolation` (`processor.rs:1737-1753`).
- If any existing borrow reserve was Isolated, the refreshed flag `obligation.borrowing_isolated_asset == true` blocks new `Regular` borrows (`1754-1761`; flag set in `RefreshObligation`, `1070-1072, 1120`).
- Isolated as collateral: `validate_reserve_config` forces `loan_to_value_ratio == 0 && liquidation_threshold == 0` for isolated reserves (`reserve.rs:1071-1076`), so isolated deposits add nothing to `allowed_borrow_value` (and nothing to `unhealthy_borrow_value`; `max_liquidation_threshold` is not constrained).

### 1.5 Attributed-borrow limits
- After the borrow, `update_borrow_attribution_values` recomputes each deposit reserve's `attributed_borrow_value` (deposits split pro-rata by collateral market value / deposited value, `processor.rs:1183-1198`) and compares against the reserve config limits:
  - above `attributed_borrow_limit_open` → `open_exceeded` (`1200-1204`);
  - above `attributed_borrow_limit_close` → `close_exceeded` (`1205-1209`).
- Borrow reverts with `BorrowAttributionLimitExceeded` if `open_exceeded` (`1855-1862`). The close limit is not enforced on borrow; it feeds closeability (see §2).
- `validate_reserve_config` requires `open <= close` (`reserve.rs:1089-1092`).

### 1.6 `borrow_limit`
- Field doc: "Borrows disabled" (`reserve.rs:968-969`). Pre-check: unless `liquidity_amount == u64::MAX`, `liquidity_amount + floor(borrowed_amount_wads) > borrow_limit` → `InvalidAmount` (`processor.rs:1684-1692`). Note this compares the requested receive amount, not `borrow_amount` including fee.
- Capacity: `remaining_reserve_capacity = max(borrow_limit - borrowed, 0)` (`1772-1774`), fed into `calculate_borrow`.
- `borrow_limit = 0` therefore disables positive borrows: normal borrows fail the pre-check; a `u64::MAX` borrow is sized to 0 → `BorrowTooSmall` (`1802-1805`). Only the market owner can raise it; the risk authority can only lower `borrow_limit` (`2493-2495`).

### 1.7 Rate limiter
- Max-outflow pre-computation: `min(reserve.usd_to_liquidity_amount_lower_bound(min(market_remaining_usd, remaining_borrow_value)), reserve_remaining_tokens)` (`1776-1789`). `usd_to_liquidity_amount_lower_bound` divides by `price_upper_bound` (`reserve.rs:141-153`, conservative).
- Hard checks (done after `calculate_borrow`, before state mutation):
  - `lending_market.rate_limiter.update(slot, market_value_upper_bound(borrow_amount))` → message "Market outflow limit exceeded! Please try again later." (`1810-1820`);
  - `borrow_reserve.rate_limiter.update(slot, borrow_amount)` → "Reserve outflow limit exceeded! Please try again later" (`1822-1828`).
  - Error variant: `OutflowRateLimitExceeded` (`rate_limiter.rs:135-136`; `error.rs:197`). A window of 0 disables the limiter (`rate_limiter.rs:109-111, 126-130`; default config window=1, max=u64::MAX, `144-154`).

### 1.8 Fees
- `borrow_fee_wad` charged exclusively on top of the requested amount: `fee = round(amount * borrow_fee_wad/WAD)` with a floor of 1 token (2 if host fee applies), and error `BorrowTooSmall` if the fee would consume the borrow (`reserve.rs:1141-1147, 1166-1213`; `processor.rs:1791-1800`).
- Host fee = `round(fee * host_fee_percentage)`, min 1 token; paid to the optional host receiver (`processor.rs:1871-1887`; `reserve.rs:1200-1207`). Remaining owner fee -> account 3 (`1888-1897`); principal -> account 1 (`1899-1906`).

---

## 2. LIQUIDATE — `process_liquidate_obligation_and_redeem_reserve_collateral` (`processor.rs:2228-2316`), core `_liquidate_obligation` (`2015-2225`)

### 2.1 Account order (`2238-2253`; builder `instruction.rs:1662-1707`)
0 source liquidity; 1 destination collateral (cToken ATA); 2 destination liquidity; 3 repay reserve; 4 repay reserve liquidity supply; 5 withdraw reserve; 6 withdraw reserve collateral mint; 7 withdraw reserve collateral supply; 8 withdraw reserve liquidity supply; 9 withdraw reserve liquidity fee receiver; 10 obligation; 11 lending market; 12 lending market authority; 13 user transfer authority; 14 token program.

### 2.2 Whitelisted liquidator (`2122-2127`)
- If `lending_market.whitelisted_liquidator` is `Some(l)`, then `user_transfer_authority_info.key` (account 13) must equal `l`; else `NotWhitelistedLiquidator` (`error.rs:202`). `None` = permissionless.
- This same account is the SPL authority for the repay transfer (`2206-2213`) and for the protocol-fee transfer (`2305-2312`), so it must be a tx signer and the authority/delegate of the source liquidity token account (enforced by SPL Token inside `spl_token_transfer`, `processor.rs:3371-3394`). There is no explicit `is_signer` check in the liquidate code path (only occurrences: `260, 359, 955, 1319, 1506, 1707, 2452, 2978, 3079, 3180`).
- Set only by the market owner via `process_set_lending_market_owner_and_config` (`265-273`); zero bytes in the packed market = `None` (`lending_market.rs:183-187`).

### 2.3 Refresh / staleness
- Repay reserve must be non-stale (`2064-2067`), withdraw reserve non-stale (`2090-2093`), obligation non-stale (`2104-2107`) → all need `RefreshReserve` (with oracles)/`RefreshObligation` in the same slot, before the liquidate instruction.
- The withdraw reserve is interest-refreshed in-instruction before redemption (`2273`, `_refresh_reserve_interest`); no oracle call.
- No rate-limiter checks on liquidation: `_redeem_reserve_collateral` is invoked with `check_rate_limits = false` (`2280-2295`, flag at `2294`).

### 2.4 Health gate and bonus
- Liquidatable iff `obligation.borrowed_value >= obligation.unhealthy_borrow_value` OR `obligation.closeable` (`2117-2120` → `ObligationHealthy`; the `closeable` flag is an unconditional bypass).
  - `borrowed_value` = Σ borrow `market_value * borrow_weight` (spot market price; `processor.rs:1099-1105`).
  - `unhealthy_borrow_value` = min(Σ deposit `market_value * liquidation_threshold`, 70_000_000) (`1036-1037, 1126`).
  - `super_unhealthy_borrow_value` = min(Σ deposit `market_value * max_liquidation_threshold`, 70_000_000) (`1038-1039, 1127-1128`).
- `calculate_bonus` (`reserve.rs:373-432`):
  - healthy + `closeable` → `{total_bonus: 0, protocol_liquidation_fee: 0}` (`374-380`; healthy + not closeable → `ObligationHealthy`);
  - if `unhealthy == super_unhealthy` (e.g. equal thresholds): `total = min(liquidation_bonus + protocol_liquidation_fee, 25%)` (`392-399`);
  - else `weight = min(max((borrowed-value - unhealthy)/(super_unhealthy - unhealthy), 0), 1)` (division error → 1), `total = min(liquidation_bonus + weight * (max_liquidation_bonus - liquidation_bonus) + protocol_liquidation_fee, MAX_BONUS_PCT)` (`408-431`).
  - `MAX_BONUS_PCT = 25` (`reserve.rs:33`), so the total (liquidator bonus + protocol cut) is capped at 25%. `protocol_liquidation_fee` is in deca bps: `Decimal::from_deca_bps` divides by 1000 (`math/decimal.rs:58-61`); max 50 = 5% (`reserve.rs:36`). Config validation enforces `max_liquidation_bonus*100 + protocol_liquidation_fee*10 <= 25*100` (`1057-1065`).
- The protocol cut is a component of `total_bonus`: seizure is sized as `repay_value * (1 + total_bonus)`; then `calculate_protocol_liquidation_fee(withdraw_liquidity_amount, bonus) = max(ceil((withdraw_liquidity_amount / (1+total_bonus)) * protocol_liquidation_fee), 1)` is transferred from the liquidator's redeemed liquidity to the reserve fee receiver (`processor.rs:2302-2312`; `reserve.rs:546-566`). Net liquidator bonus is the interpolated base bonus; the protocol fee is skimmed in addition.
- Exact seizure math, `calculate_liquidation` (`reserve.rs:435-540`), with `bonus_rate = 1 + total_bonus` (`448`):
  - Caller's `liquidity_amount` caps `max_amount = min(liquidity_amount, borrowed_amount_wads)` (`450-454`).
  - Partial branch (`liquidity.market_value > $1`): `liquidation_amount = min(obligation.max_liquidation_amount(liquidity), max_amount)` (`503-505`); `max_liquidation_amount = min(borrowed_value * 20%, liquidity.market_value, $500_000)` converted to token amount (`obligation.rs:178-190`; close factor 20 and $500k cap at `reserve.rs:24, 30`). `liquidation_value = liquidation_amount.market_value * bonus_rate` (`507-510`) then:
    - greater than collateral value → full collateral seized, repay/settle scaled by `collateral_value/liquidation_value` (`513-518`);
    - else `withdraw_amount = floor(deposited_amount * liquidation_value / collateral.market_value)` (`524-531`).
  - Full-liquidation special case (`liquidity.market_value <= $1`): ignores the close factor; seizes all collateral if the liquidation value >= collateral value, otherwise scales repay down (`460-499`).
  - Per call the repay is at most 20% of the obligation's weighted `borrowed_value`, ≤ the targeted borrow and ≤ $500k market value; the seized collateral can be up to the entire deposit in the targeted reserve when collateral value is the binding constraint (`513-518`, `468-474`).
- `closeable` is set by `process_set_obligation_closeability_status` only when the named reserve's `attributed_borrow_value >= attributed_borrow_limit_close`, obligation fresh, signer = risk authority or market owner, and `borrowed_value != 0` (`3125-3199`, esp. `3153-3157, 3169-3172, 3174-3183, 3185-3195`). A subsequent `RefreshObligation` resets `closeable = false` unless some deposit reserve is still above its close limit (`1132-1135`).

### 2.5 Other gates
- Borrow being repaid must be at index 0 of `obligation.borrows` (`2129-2138` → `InvalidAccountInput`). `RefreshObligation` swaps the borrow with the max `added_borrow_weight_bps` to index 0 (`1137-1140`, comparison strict `>` so ties keep the earliest). Effectively the repay reserve must be the max-borrow-weight borrow after refresh.
- `liquidity.market_value != 0` (`2131-2134`) and `collateral.market_value != 0` (`2142-2145`); `deposited_value != 0`, `borrowed_value != 0` (`2108-2115`).
- `repay_amount != 0 && withdraw_amount != 0` (`2173-2180`).
- Supply/authority/account identity checks (`2031-2093`): market owner, token program, reserve↔market, supply keys, collateral supply != destination, etc.
- No isolated-asset check in liquidation; isolated deposits contribute zero `liquidation_threshold` but may still be seized.
- State accounting: if the full collateral deposit is withdrawn, the withdraw reserve's `attributed_borrow_value` is decremented by the collateral's market value (`2190-2199`); no open/close attribution-limit check is performed on liquidation.
- Redemption behavior: `min(withdraw_amount, max_redeemable_collateral)` is redeemed to underlying liquidity; the remainder is delivered as cTokens to account 1 (`2273-2295; 2224`). Protocol fee receiver is checked only when a redemption occurs (`2297-2301`).

---

## 3. WITHDRAW / REDEEM

### 3.1 Standalone withdraw — `process_withdraw_obligation_collateral` (`processor.rs:1406-1442`)
- Accounts 0-7: source collateral, destination collateral, withdraw reserve, obligation, lending market, market authority, obligation owner (signer, `1506-1509`), token program; then `accounts[8..]` = one deposit-reserve account per `obligation.deposits`, in order (`1439`, consumed at `1595-1596`; keys sanity-checked `1178-1181`).
- Staleness is relaxed when the obligation has no borrows (commit `ed2f77cb` "relax staleness requirements when withdrawing with no borrows (#195)"):
  - withdraw reserve stale check only `&& !obligation.borrows.is_empty()` (`1489-1492`);
  - obligation stale check only `&& !obligation.borrows.is_empty()` (`1510-1513`).
- No oracle read anywhere; with no borrows, `max_withdraw_amount` returns the full `collateral.deposited_amount` (`obligation.rs:119-121`) and no borrow health is computed. With borrows, `max_withdraw_amount` uses `allowed_borrow_value - borrowed_value_upper_bound` and `price_lower_bound` (`obligation.rs:123-168`).
- No rate-limiter accounting at all in this instruction (`account_for_rate_limiter = false`, `1438`), and the reserve is not refreshed inside.
- Attribution: open-limit violation on any deposit reserve → `BorrowAttributionLimitExceeded` (`1595-1603`).

### 3.2 Redeem — `process_redeem_reserve_collateral` (`processor.rs:766-809`)
- Accounts 0-9: source collateral, destination liquidity, reserve, collateral mint, liquidity supply, lending market, market authority, user transfer authority, clock (not read), token program (`776-786`).
- It calls `_refresh_reserve_interest` itself (`788`, no oracle, clears staleness by updating slot), then `_redeem_reserve_collateral` with `check_rate_limits = true` (`789-803`, flag `882`).
- Rate limits: market limiter updated with `market_value_upper_bound(liquidity_amount)` (USD using stored price bounds) and reserve limiter with the token amount (`882-901`; messages "Market outflow limit exceeded! Please try again later." / "Reserve outflow limit exceeded! Please try again later."; `OutflowRateLimitExceeded`).
- Errors: `InvalidAmount` (zero), `ReserveStale` (`862-865`, unreachable after the internal interest refresh unless slot arithmetic fails), `InsufficientLiquidity` if available < redeemed (`reserve.rs:705-714`), `OutflowRateLimitExceeded`.

### 3.3 Withdraw + redeem — `process_withdraw_obligation_collateral_and_redeem_reserve_liquidity` (`processor.rs:2319-2375`)
- Accounts 0-11: source collateral, destination collateral, reserve, obligation, lending market, market authority, user liquidity, collateral mint, liquidity supply, obligation owner (signer), user transfer authority, token program; then `accounts[12..]` = deposit reserves (`2324-2337`, `2352`).
- Calls `_withdraw_obligation_collateral` with `account_for_rate_limiter = true` (`2339-2353`), which caps the withdraw to the market/reserve remaining outflow converted to collateral (`1537-1569`); stale checks relaxed when no borrows exactly as §3.1.
- Then `_refresh_reserve_interest` (`2358`) and `_redeem_reserve_collateral` with `check_rate_limits = true` (`2359-2373`).
- Comment at `2355-2357` states the refresh is needed precisely for the no-borrows case.

### 3.4 Dead-oracle behavior (exact)
- With no borrows, an owner can withdraw and redeem even if the reserve oracle is dead/stale: withdraw does not read oracles and skips the stale checks (`1489`, `1510`); the combined instruction self-refreshes interest (`2358`) and then redeems; standalone redeem self-refreshes interest (`788`). All pricing used is the last stored `market_price`.
- With borrows, withdraw requires non-stale reserve and obligation, which cannot be produced while refreshes fail (resident oracle error → whole tx reverts), so withdraw is blocked in practice.
- Deposits (`1238, 1301-1304`) and repay (`1941, 1959-1962`) likewise only need interest refresh/no oracle and work with a dead oracle.

---

## 4. FLASH LOAN — `process_flash_borrow_reserve_liquidity` (`processor.rs:2599-2627`), `_flash_borrow_reserve_liquidity` (`2630-2775`); repay `2777-2952`

- Accounts (borrow, `2604-2611`; builder `instruction.rs:1738-1763`): source liquidity, destination liquidity, reserve, lending market, market authority, instructions sysvar, token program.
- Accounts (repay, `2783-2792`; builder `1768-1793`): source, destination (reserve supply), reserve fee receiver (must equal config fee receiver, `2852-2855`), host fee receiver, reserve, lending market, user transfer authority (signer for transfers), instructions sysvar, token program.
- Refresh: only `_refresh_reserve_interest` for the borrow (`2614`; no oracle). No staleness check exists in either flash path.
- Disabled flag: `reserve.config.fees.flash_loan_fee_wad == u64::MAX` → `FlashLoansDisabled` (`2684-2687`; `error.rs:191`).
- No rate limiter, no `borrow_limit`, no obligation, no health checks. The only amount cap is `reserve.liquidity.borrow(amount)` requiring `available_amount >= amount` (`2761`; `reserve.rs:718-732`).
- Fee: `calculate_flash_loan_fees` (exclusive) = `amount * flash_loan_fee_wad/WAD` with the same 1-token minimum (2 with host), split into origination fee (reserve fee receiver) and host fee; both transferred on repay in addition to the principal (`2860-2863`, `2920-2949`; `reserve.rs:1150-1164, 1166-1213`).
- Anti-CPI / pairing gates:
  - both borrow and repay reject CPI calls (`is_cpi_call` program-id/stack-height test, `2690-2694`, `2866-2870`, `3447-3474`; errors `FlashBorrowCpi`, `FlashRepayCpi`);
  - borrow scans subsequent top-level instructions and requires a matching `FlashRepayReserveLiquidity` with `accounts[4] == reserve`, equal `liquidity_amount`, and `borrow_instruction_index == current_index`; a second flash borrow later in the tx and multiple repay instructions are rejected (`2705-2759`); repay re-validates the referenced instruction (`2873-2912`).
- Answer to "temporary capital for a borrow against distorted collateral": the flash-loan code itself neither reads nor writes any obligation and cannot change collateral valuation; it only moves tokens out of the reserve and requires the same amount plus fee to be returned by a later top-level instruction in the same tx. Any borrow executed in that tx is still gated by the §1.3 health inequality against obligation state refreshed in that same slot; the flash loan can provide tokens used by other instructions (e.g. deposits/repays) but there is no code path in the flash instructions that relaxes the borrow gate.

---

## 5. OBLIGATION REFRESH MATH — `process_refresh_obligation` (`processor.rs:973-1153`)

Accounts: obligation (0), then one non-stale reserve per `obligation.deposits` in order, then one per `obligation.borrows` in order; extra accounts rejected (`1111-1114`); keys checked (`1001-1006, 1053-1058`).

Per deposit (`992-1040`):
- `liquidity_amount = collateral_exchange_rate.collateral_to_liquidity(deposited_amount)` (`1018-1020`);
- `market_value = market_price * amount / 10^decimals` (spot, stored scaled price) (`1022`; `reserve.rs:156-165`);
- `market_value_lower_bound = min(market, smoothed, extra) * amount` (`1023-1024`; `reserve.rs:126-137, 184-195`);
- `collateral.market_value = market_value` (`1032`);
- `deposited_value += market_value` (`1033`);
- `allowed_borrow_value += market_value_lower_bound * LTV` (`1026, 1034-1035`);
- `unhealthy_borrow_value += market_value * liquidation_threshold` (`1027, 1036-1037`);
- `super_unhealthy_borrow_value += market_value * max_liquidation_threshold` (`1029-1030, 1038-1039`).

Per borrow (`1044-1109`):
- `ReserveType::Isolated` anywhere → `borrowing_isolated_asset = true` (`1070-1072`);
- interest accrued onto `borrowed_amount_wads` using the reserve's `cumulative_borrow_rate_wads` (`1074`);
- `market_value = market_price * borrowed_amount_wads` (`1099`; spot price);
- `liquidity.market_value = market_value` (`1102`);
- `borrowed_value += market_value * borrow_weight` (`1104-1105`) — used for the liquidation health/bonus checks;
- `borrowed_value_upper_bound += market_value_upper_bound * borrow_weight` (`1100-1101, 1106-1107`) — used for borrow power (`remaining_borrow_value`) and withdraw limits;
- `unweighted_borrowed_value += market_value` (`1108`) — used for attribution.

Stored fields (`1116-1128`): `deposited_value`, `borrowed_value`, `unweighted_borrowed_value`, `borrowed_value_upper_bound`, `borrowing_isolated_asset`, and the global caps `allowed_borrow_value = min(sum, 65_000_000)`, `unhealthy_borrow_value = min(sum, 70_000_000)`, `super_unhealthy_borrow_value = min(sum, 70_000_000)`.

Then: `last_update.update_slot` (`1130`); attribution values updated on deposit reserves and `closeable` possibly reset (`1132-1135`, see §2.4/`update_borrow_attribution_values` `1164-1215`); max-borrow-weight borrow swapped to index 0 (`1137-1140`); zero deposits/borrows filtered (`1142-1148`).

So in one sentence: deposits are risk-weighted with the LOWER price bound for borrow power and spot for health; borrows are weighted by `borrow_weight` and use the UPPER price bound for borrow power and spot for health; the extra oracle enters only the min/max price bounds and thus only limits borrows/withdrawals.

---

## 6. REFRESH_RESERVE — `process_refresh_reserve` (`processor.rs:516-532`), `_refresh_reserve` (`534-601`)

- Accounts: 0 reserve (writable); 1 pyth/main oracle account; 2 switchboard/secondary oracle account; 3 optional extra oracle account (`516-532`; builder `instruction.rs:1205-1227` passes exactly 3 + optional extra).
- Key equality is mandatory for both oracle slots: `reserve.liquidity.pyth_oracle_pubkey == account1.key` (`547-550` → `InvalidAccountInput`) and `reserve.liquidity.switchboard_oracle_pubkey == account2.key` (`553-558` → `InvalidOracleConfig`). No null-skip exists on these comparisons in the refresh path, so when a side is unset (`NULL_PUBKEY = nu11111111111111111111111111111111111111111`, `sdk/src/lib.rs:24-29`) the caller must pass an account whose key is exactly `NULL_PUBKEY`. (The null side is then handled inside the price getters, e.g. `pyth.rs:112-114`, `switchboard.rs:24-26`.)
- Price fetch: `get_price(Some(switchboard_feed), pyth_price)` (`560-561`) tries the pyth slot first (`get_single_price`, `3297-3300`), then the switchboard slot (`3303-3307`); if both fail → `InvalidOracleConfig` (`3311`). Dispatch is by account owner (`oracles/src/lib.rs:23-40`), not by slot name.
- Returns price `(market, Option<smoothed>)`; market is stored × `price_scale()` (`563`), smoothed (when present, i.e. Pyth/PythPull EMA) stored × `price_scale()` (`565-568`). If the pyth slot is `NULL_PUBKEY`, smoothed is forced = market (`594-596`, comment: switchboard-only reserves).
- Extra oracle: if `config.extra_oracle_pubkey == Some(p)` the account is REQUIRED and must match (`570-578` → `InvalidAccountInput` if missing); the extra price is stored raw (no scale, `580-583`). Its account is validated at init/config-update (`validate_extra_oracle`, `484-514`). `get_single_price_unchecked` skips staleness/confidence for Pyth and Switchboard-v2 but does check staleness for Switchboard On-Demand (`oracles/src/lib.rs:66-76`).
- Finish: pack reserve (`598`), then `_refresh_reserve_interest` (`600`) = `accrue_interest(clock.slot)` + `last_update.update_slot(clock.slot)` (`616-617`), which is what clears staleness for the rest of the tx.
- Error semantics: any failure is a returned Err → whole instruction/tx reverts (no partial write; the packed reserve happens only at the end, and Solana aborts the tx on instruction error). Specific errors: `InvalidAccountOwner` (`543-546`), `InvalidAccountInput` (`547-550`, `575-578`, missing extra `585-588`), `InvalidOracleConfig` (`553-558`, `3311`).

Oracle validity inside `get_single_price`:
- Pyth legacy: `get_price_no_older_than(clock, 240 slots)` (`pyth.rs:19, 121-126`), price ≥ 0 (`128-131`), `conf * 10 > price` rejected (`18, 136-143`); EMA read unchecked (`146-155`).
- Pyth Pull: age ≤ 120 s, `VerificationLevel::Full` (`pyth.rs:20, 184-190`), same conf check (`204-211`).
- Switchboard v2 / On-Demand: age < 240 slots, non-negative price, On-Demand range ≤ price/10 (`switchboard.rs:46, 53-56, 58-61, 75-82; 92, 100-103`).

---

## 7. LENDING MARKET — `lending_market.rs` + market-admin instructions

- Fields: `owner`, `risk_authority`, `whitelisted_liquidator: Option<Pubkey>`, `rate_limiter` (`lending_market.rs:12-33`).
- Packed length 290 (`lending_market.rs:83`). Field offsets (from `mut_array_refs!`, `102-115`): version 0, bump 1, owner 2..34, quote_currency 34..66, token_program_id 66..98, oracle_program_id 98..130, switchboard_oracle_program_id 130..162, rate_limiter 162..218 (56 bytes, `rate_limiter.rs:165`), **whitelisted_liquidator 218..250**, risk_authority 250..282, padding 282..290. Confirmed: 1+1+32+32+32+32+32+56 = 218. All-zero bytes unpack to `None` (`183-187`).
- Set path `process_set_lending_market_owner_and_config` (`processor.rs:242-290`):
  - signer must be a signer (`260-263`); if signer == current `owner`: updates `owner`, `risk_authority`, rate-limiter config, and `whitelisted_liquidator` (`265-273`);
  - else if signer == `risk_authority`: may only install a limiter config with `window_duration > 0 && max_outflow == 0` (disable outflows) (`274-281`);
  - else `InvalidMarketOwner` (`282-285`).
- `risk_authority` starts as the owner (`lending_market.rs:55`) and unpacks from zero as the owner (`188-195`).
- Other risk-authority powers: in `process_update_reserve_config`, risk authority may only disable reserve outflows and lower `borrow_limit`/`deposit_limit` (`2485-2499`); risk authority or owner may mark an obligation `closeable` (`3174-3183`). The market owner controls all reserve config and oracle keys (`2457-2484`). The program-level `5pHk2TmnqQzRF9L6egy5FfiyBgS7G9cMZ5RFaJAvghzw` may edit fee fields on permissionless markets (`47-49, 2500-2507`).

---

## 8. What an unprivileged external actor must satisfy (summary)

Borrow:
1. Own (or be signer for) the obligation and pass it + owner signer (`1703-1710`).
2. Obligation must have ≥1 deposit and non-zero `deposited_value` (`1715-1722`) and be refreshed this slot (`1711-1714`).
3. Borrow reserve refreshed this slot (`1680-1683`); all obligation reserves refreshed before `RefreshObligation`.
4. Pass correct token accounts: destination liquidity, borrow reserve supply, market authority PDA, fee receiver equal to config, token program equal to market (`1652-1679`, `1724-1735`). Deposit reserve accounts for every obligation deposit (`accounts[9..]`, `1855`, `1864-1867`).
5. Pass the borrow gate (§1.3), isolated rules (§1.4), attribution open limit (§1.5), `borrow_limit`/capacity (§1.6), rate limits (§1.7); pay borrow/host fees (§1.8).
6. Obligation may hold at most 10 deposits+borrows combined (`obligation.rs:21, 215-221, 272-278`).
7. Optional host fee receiver only after the deposit reserves (`1872`).

Liquidate:
1. Permissionless unless `whitelisted_liquidator` is set, in which case the whitelisted key must be the user transfer authority and sign the repay transfer (`2122-2127`, `2206-2213`).
2. Need the repay asset tokens in a token account whose authority/delegate is that signer.
3. Obligation unhealthy (`borrowed_value >= unhealthy_borrow_value`) or `closeable` (§2.4), with all three accounts (both reserves + obligation) refreshed this slot (§2.3).
4. The repaid borrow must be index 0 after refresh (max `added_borrow_weight_bps`) (§2.5).
5. Both borrow and collateral for the pair must have non-zero refreshed `market_value`; repay/withdraw must round non-zero (`2108-2180`).
6. Bonus/seizure per §2.4; protocol fee skimmed from redeemed liquidity.

Redeem / withdraw:
1. Withdraw/combined: obligation owner signer; no borrows → no oracle/freshness requirement; with borrows → reserve + obligation refreshed, health via `max_withdraw_amount`, attribution open limit; rate limiter only in the combined (redeem) leg.
2. Standalone redeem: any cToken holder; self-refreshing interest; market + reserve outflow limits apply; no oracle requirement.

Flash loan:
1. Top-level instructions only (no CPI), fee enabled, a matching later `FlashRepay` of the same amount (and fee) in the same tx; cap = `available_amount`; no rate limits/obligation/liveness checks.

Cross-cutting: no admin allowlist for borrowing; all health gating is the objective USD math in §1.3/§2.4/§5; the only discretionary gates on these paths are `whitelisted_liquidator` (liquidations) and `closeable` (allows liquidation of a healthy obligation).

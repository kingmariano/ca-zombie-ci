# Cega V1 — Adversarial Audit: unprivileged attacker paths (H-12 deep-dive)

Date: 2026-10-03 (session chain snapshot: ETH block 26,112,536; ARB block 511,332,647)

Scope: `cegaState_1`, `insanic_1` (FCNProduct/FCNVault/Calculations), `puppyLov_42161` (LOVProduct/LOVCalculations/FCNVault), `productViewer_1`, plus the deployed Pyth-adapter `Oracle` (fetched from Etherscan) and the live deployments below.

Attacker model: external EOA/contract with only public calls, own capital, flash loans. No DEFAULT/OPERATOR/TRADER/SERVICE role, no market-maker allowlist, no insider access. No transaction was broadcast; all chain interaction was `eth_call` / `eth_getCode` / `eth_getLogs`.

Deployed targets examined (all non-proxy, Etherscan `Proxy=0`, no initializer in any compiled source):

| Chain | Contract | Address |
|---|---|---|
| ETH | CegaState | 0x0730AA138062D8Cc54510aa939b533ba7c30f26B |
| ETH | FCNProduct "insanic" | 0x784e3C592A6231D92046bd73508B3aAe3A7cc815 |
| ETH | Calculations library | 0xb517944479e3e85ec1d26f607db9193706733d30 |
| ETH | Oracle BTC/USD,Pyth | 0x6579EC6cB3088543600f27C756c09676aCEC981E |
| ARB | CegaState | 0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed |
| ARB | LOVProduct "puppy-lov" | 0x6A9201Db9222cFb5164cfb8F192903270f8a6e93 |
| ARB | LOVCalculations library | 0x3c7442689b4d86ea1bc70fca5fda5ccc8b812b85 |
| ARB | Oracle BTC/USD,Pyth | 0xA2E380c0A76d4FBB54DA7BeeaA4A4B32803b09e7 |

---

## 0. Bytecode ⇄ source verification (task item 8)

Verified by recompiling the exact Etherscan standard-JSON (solc 0.8.17+commit.8df45f5f, optimizer 200 runs, viaIR=true) and diffing against `eth_getCode`. Libraries were pre-linked in the standard JSON `settings.libraries`, so the linked address bytes match too.

| Artifact | Runtime size | Result |
|---|---|---|
| FCNProduct (insanic) | 24,556 B | **exact match**; only diffs are the 7 `immutable asset` slots = USDC `0xA0b8…eB48` |
| LOVProduct (puppy-lov) | 24,568 B | **exact match**; only diffs are `immutable asset` = USDC `0xaf88…5831` |
| CegaState (ETH) | 8,722 B | **exact match**, no immutables; ARB code keccak identical (`0x65e73752…`) to ETH → same verified code |
| FCNVault instances (ETH 0xbd81…, ARB 0x8036…) | 3,779 B | **exact match** |
| Calculations / LOVCalculations libs | 3,000 B / 3,642 B | **exact match** (only the library self-address immutable differs) |
| Oracle (Pyth adapter, ETH) | 2,187 B | **exact match** |

All 48/43/31 ABI selectors are present in the deployed code and the compiled bytecode equals on-chain bytecode, therefore **no hidden extra public functions**. No `initialize`, no proxy, no `selfdestruct`, no `delegatecall` other than the compiler-generated calls into the verified linked libraries. `owner()`/`fcnProduct()` pointers confirmed: product → correct CegaState; vault → correct product (vault ownership is the product and cannot be transferred — FCNProduct has no arbitrary-call or ownership-transfer function).

Oracle write paths live-tested from a random address: `addNextRoundData` reverts `403:SA`, `updateRoundData` reverts `403:DA`. Oracle price data is **stale on both chains**: last round has `startedAt = 1,735,740,000` (2025-01-01) while chain time is 1,791,039,227 (2026-10-03) → any product call that reads the oracle reverts `400:T`.

---

## 1. Permissionless surface (modifier audit)

State-changing functions callable by anyone:
- `FCNProduct.addToDepositQueue` (543-554), `addToWithdrawalQueue` (601-616), `checkBarriers` (622-626), `calculateVaultFinalPayoff` (632-638), `calculateCurrentYield` (796-799) — `onlyValidVault` where applicable; queue functions are `nonReentrant`.
- `LOVProduct` equivalents: 593-608, 654-669, 675-679, 685-691, 830-833.
- `receiveAssetsFromCegaState` is effectively private (`require(msg.sender == address(cegaState))`).

Everything that moves USDC out (`sendAssetsToTrade` 777-790 incl. `marketMakerAllowList` check and `amount <= currentAssetAmount`; `collectFees` 684-699 incl. `PayoffCalculated` check and `feeRecipient` receiver; `processWithdrawalQueue` 706-749; `processDepositQueue`; all setters; `rolloverVault`) is role-gated. `FCNVault.deposit/redeem` are `onlyOwner` (product), and the product can only invoke them from role-gated functions using queue-recorded args.

---

## 2. Hypothesis verdicts (items 1–7)

### H1 — deposit/withdrawal queue index desync or misallocation (item 1) — **BLOCKED for unprivileged**
- `depositQueue`/`queuedDepositsCount` (FCNProduct 125, 120; pop at 575, 583) are mutated only by `addToDepositQueue` (push+increment, 547/552) and the trader-gated `processDepositQueue` (pop+decrement, 577-584). Both update array length and counter atomically; the entry itself carries `receiver` (Structs.sol `Deposit{amount,receiver}`), so no receiver confusion is possible.
- The queue is product-wide, so the **trader** chooses which vault a deposit is minted into (a user cannot bind a deposit to a vault). That is a trust/design risk, not attacker-controllable misallocation; the receiver is always credited in whichever vault is processed.
- LOV: `depositQueues[leverage]` is indexed by `vaultMetadata.leverage` (LOVProduct 625-633), so leverage-A entries **cannot** be consumed by a leverage-B vault. Cross-leverage consumption requires the default admin to relabel a vault's `leverage` via `setVaultMetadata` (364-372, `onlyDefaultAdmin`, target leverage must be allowed).
- The only count/array desync sources are admin-only `setVaultMetadata` (can overwrite `queuedWithdrawalsCount`) and `removeVault` (FCNProduct 332-339 deletes metadata without checking the withdrawal queue; LOV 379-388 checks queue length). If an admin desyncs, `processWithdrawalQueue`/`processDepositQueue` revert out-of-bounds and/or shares are stranded — not attacker-triggerable.
- LIFO processing means a trader calling `processDepositQueue(vaultA, 1)` consumes the *last* deposit; again trader-only discretion.

### H2 — `convertToShares`/`convertToAssets`, first-depositor/donation/Zombie (item 2) — **BLOCKED**
- `FCNVault.totalAssets()` reads `product.vaults(this).underlyingAmount` accounting (35-38). Direct USDC donations to the product do not change accounting → donation/inflation attack impossible.
- `convertToShares` returns `assets` when totalAssets==0 || totalSupply==0 (57); `convertToAssets` returns 0 when supply==0 (46). `processDepositQueue` blocks the dangerous `U==0 && S>0` state (`"500:Z"`, FCNProduct 569-570; LOV 623). Integer floors always favor the vault.
- `deposit`/`redeem` are `onlyOwner`; owner is the product (`FCNVault` 23-26) and cannot be changed by any product function. Non-owners cannot mint or burn shares.
- Residual dust (immaterial): after a full queued redemption the sequential floors can leave `S==0, U=dust>0`; after `rolloverVault`+`openVaultDeposits` (trader actions) the next depositor is minted 1:1 and captures the dust.

### H3 — `addToWithdrawalQueue` takes shares you do not own (item 3) — **BLOCKED**
- Only external transfer is `IERC20(vaultAddress).safeTransferFrom(msg.sender, address(this), amountShares)` (609). `from` is hardcoded to `msg.sender`, receiver recorded as `msg.sender` (611). Shares must come from the caller's balance/allowance; the product is the spender, so no victim allowance is consumed on an attacker's behalf. No path anywhere calls `transferFrom(victim, attacker, …)`.
- `vaultAddress` passes `onlyValidVault` (`vaultStart != 0`, set only by `createVault`/admin) → always a genuine FCNVault. FCNVault is stock OZ ERC20 (no hooks, no permit; `draft-IERC20Permit.sol` is in the bundle but not inherited). USDC (FiatToken) has no transfer hooks/callbacks. Queue functions are `nonReentrant`; `checkBarriers`/`calculate*` make only STATICCALLs to the oracle (`latestRoundData` is `view`), so even a hostile registered oracle cannot re-enter state-changing code.
- One theoretical DoS: a receiver blacklisted by USDC makes `processWithdrawalQueue` revert for the whole vault; an attacker cannot self-blacklist on demand, so not attacker-reachable.

### H4 — `calculateVaultFinalPayoff` timing (item 4) — **EXPLOITABLE (state-machine timing); needs trader completion**
Money custody: the product contract holds all USDC pooled; per-vault `underlyingAmount` is the accounting; payouts are executed only by the trader via `collectFees` + `processWithdrawalQueue`. The attacker cannot move funds alone, but normal settlement (trader completes payout for all matured vaults) lets the attacker free-ride on a tampered payoff.

- **F1 (High): any caller can permanently disable knock-in detection at expiry.** `Calculations.calculateCurrentYield` (20-32) requires status `Traded`; when `block.timestamp > tradeExpiry` it sets `TradeExpired` and returns (24-27). `Calculations.checkBarriers` (38-58) requires `Traded` (43) and is the **only** unprivileged way to set `isKnockedIn`. `calculateVaultFinalPayoff` (65-92) accepts `TradeExpired` and, with `isKnockedIn == false`, returns 100% principal (82-86). Therefore whoever calls `calculateCurrentYield` first after expiry locks out the knock-in permanently (admin can only rescue via `setKnockInStatus`, 530-537).
- **F2 (High/Med): the final payoff is recomputed from the live oracle on every call while status is `PayoffCalculated`.** The status gate (73-76) explicitly allows re-entry, and `principalToReturnBps` is re-read from `calculateKnockInRatio` (83, 101-122) at call time. Anyone can re-call until the trader executes `collectFees` (684-699 uses the current `vaultFinalPayoff`). The last caller before `collectFees` picks the payoff at the freshest spot; it can even be bundled in the same block in front of `collectFees`.

### H5 — `checkBarriers` forcing a false knock-in (item 5) — **BLOCKED**
- `if (uint256(answer) <= barrierAbsoluteValue)` (Calculations 53). A negative oracle answer casts to a huge uint256 → condition false (fail-closed, cannot force a latch). A zero answer would latch (0 <= barrier), but the attacker cannot make the service-fed Oracle return 0 (writes are SERVICE/DEFAULT gated, live-verified 403).
- `barrierAbsoluteValue == 0` is possible only via `addOptionBarrier` (382-404, trader) since `updateOptionBarrier` enforces `>0` (424-425) — privileged misconfig, not an unprivileged path.
- Staleness is checked on `startedAt`, not `updatedAt` (52); both are service-supplied in this custom Oracle. No attacker input. Griefing is limited to calling `checkBarriers` (no state downside).

### H6 — role gates / argument substitution (item 6) — **BLOCKED**
- `sendAssetsToTrade` checks `marketMakerAllowList(receiver)` and `amount <= currentAssetAmount`; allowlist is OPERATOR-only. `collectFees` requires `PayoffCalculated` and pays the CegaState-controlled `feeRecipient`. `receiveAssetsFromCegaState` requires `msg.sender == cegaState`; `cegaState` is set once in the constructor and has no setter. `rolloverVault` only resets fields. None of these can be invoked indirectly by an unprivileged caller.
- Callable-by-anyone `calculateVaultFinalPayoff` mutates state read by `collectFees`, but cannot alter the receiver or bypass `feeRecipient`; its effect is F1/F2 above.
- `collectFees`'s `currentAssetAmount -= totalFees` can revert if trading proceeds have not returned yet — a role-timing DoS, not attacker-triggerable.
- **F4 (Low, adjacent):** `rolloverVault` (755-769) does **not** clear `optionBarriers`/`optionBarriersCount`. After rollover the next trade inherits the previous trade's barriers; once the vault is `Traded`, a caller can latch a stale barrier if spot ≤ old barrier. Only the trader sets barriers, so it cannot be attacker-installed, and the impact (holders paid less) is not attacker-profitable; still a correctness bug.

### H7 — CegaState (item 7) — **BLOCKED**
- All 31 external functions are role-gated except view helpers; `moveAssetsToProduct` is TRADER-gated (202-214) and pulls funds *into* an operator-registered product. No initializer, no proxy, no `selfdestruct`/`delegatecall`, plain sequential storage. OZ `AccessControl` role admin for OPERATOR/TRADER/SERVICE defaults to `DEFAULT_ADMIN_ROLE`; `DEFAULT_ADMIN_ROLE` is fixed at construction (`msg.sender`) and can only be granted by itself. `renounceRole` is self-only; `grantRole` requires the role admin. No unprivileged escalation.

### H8 — bytecode cross-check (item 8) — **PASS**, see §0.

---

## 3. Findings with exploit paths

### F1 — High — unprivileged caller can block knock-in and force par settlement
File/lines: `insanic_1/contracts_Calculations.sol` 20-32 (`calculateCurrentYield` → `TradeExpired`), 38-58 (`checkBarriers` requires `Traded`), 65-92 (par when `!isKnockedIn`); exposed by `FCNProduct.sol` 796-799 / 622-626 / 632-638. Same in `puppyLov_42161/contracts_LOVCalculations.sol` 20-32/38-58/65-100.

Preconditions: vault `Traded`, `isKnockedIn==false`, `block.timestamp > tradeExpiry`, fixing spot < barrier, attacker holds Q of S shares (deposited while the queue was open, or tokens acquired).

Concrete sequence (attacker bundles 1 and 3; step 2 is the keeper that loses the race):
1. `FCNProduct.calculateCurrentYield(vault)` → status `TradeExpired`.
2. Keeper `checkBarriers(vault)` → reverts `500:WS` (requires `Traded`) — knock-in now unreachable (only `setKnockInStatus`, DEFAULT admin, can fix).
3. `FCNProduct.calculateVaultFinalPayoff(vault)` → `isKnockedIn==false` ⇒ `principalToReturnBps=10000`, `vaultFinalPayoff = U + coupon`.
4. Trader later calls `collectFees` + `processWithdrawalQueue`; each share redeems at `(U+coupon−fees)/S`.

Expected attacker profit: `Q/S · U · (1 − min(spot/strike)/10000)` vs. correct knock-in settlement, funded by Cega/MM or by the commingled product pool. Even with no position, the attacker can force depositors to be overpaid and Cega underpaid (protocol invariant violation).

### F2 — High/Med — payoff is recomputed from live oracle until `collectFees` (last-call-wins)
File/lines: `Calculations.calculateVaultFinalPayoff` 73-76 (allows `PayoffCalculated`), 82-84 (fresh `calculateKnockInRatio`), 88-91; `FCNProduct.collectFees` 686-695 (uses stored value with no timestamp freeze). Same in LOV (`LOVCalculations` 74-99, `LOVProduct` 715-733).

Preconditions: `isKnockedIn==true` (latched earlier), status `PayoffCalculated`, `collectFees` not yet executed, spot/strike recovered above the fixing ratio (or any higher oracle round arrives).

Sequence: attacker calls `calculateVaultFinalPayoff(vault)` whenever `calculateKnockInRatio` is higher (worst case: front-run `collectFees` in the same block). Then trader collects fees and processes withdrawals at the inflated `(U+coupon−fees)`. Profit: `Q/S · U · (r_new − r_fix)/10000`. With leverage >1 in LOV the loss side is multiplied (`LOVCalculations` 85-88), so the swing is larger. No function exists for the trader to freeze the fixing; only DEFAULT admin (`setVaultMetadata`) could override.

### F3 — Med — LIFO withdrawal queue + commingled pool ⇒ late queue-jumper is paid first in an insolvent pool
File/lines: `FCNProduct.addToWithdrawalQueue` 601-616 (push at end), `processWithdrawalQueue` 724-737 (`withdrawalQueue[queuedWithdrawalsCount-1]` = last pushed, processed first; pays from the single product USDC balance via `safeTransfer`, 730). LOV analogous 654-669 / 758-764. The product has no per-vault asset segregation: `sumVaultUnderlyingAmounts` is only accounting.

Preconditions: product USDC balance < sum of vault entitlements (e.g., trading proceeds not returned, a realized loss not yet reflected, or cross-leverage shortfall), trader about to process a queue.

Sequence: attacker holding shares front-runs the trader's `processWithdrawalQueue` with `addToWithdrawalQueue(vault, shares)`; being last in the array, the attacker's entry is redeemed first and paid in full; earlier entrants absorb the shortfall. No role is required for queue insertion; completion still requires the trader to process (normal ops).

Live check: not currently insolvent — ETH insanic USDC balance 138,575,232 == `sumVaultUnderlyingAmounts`; ARB puppy-lov USDC 129,897,864 == Σ`currentAssetAmount`. Conditional on an insolvency event.

### F4 — Low — stale option barriers survive `rolloverVault`; `removeVault` can strand queues
File/lines: `FCNProduct.rolloverVault` 755-769 (resets status/fields but not `optionBarriers`/`optionBarriersCount`), `removeVault` 332-339 (no withdrawal-queue check, deletes metadata). LOV `removeVault` 379-388 checks the queue; `rolloverVault` 789-803 has the same barrier issue.

Impact: next trade inherits old barriers (a caller can latch them once `Traded`); depositors can be paid less. Not attacker-installable; flagged as correctness risk. Removal of an FCN vault with a pending queue makes `addToWithdrawalQueue` revert (`400:VA`) and strands shares.

### F5 — Info/Live — oracle staleness freezes knock-in machinery
The deployed Pyth-adapter `Oracle` (source verified) only accepts data from SERVICE_ADMIN (`addNextRoundData`, `require(block.timestamp - 1 days <= _startedAt)`) and DEFAULT_ADMIN (`updateRoundData`). Last round on both chains is 2025-01-01; chain time is 2026-10-03. Consequence: `checkBarriers` and any knocked-in `calculateVaultFinalPayoff`/`calculateKnockInRatio` revert with `400:T` on live vaults. An unprivileged user can neither push data nor bypass the check. Note this currently *prevents* F1's latch (making F1 a fresh-deployment / resumed-oracle risk), but also blocks lawful knock-in settlement — a liveness failure for the protocol, not an attacker gain.

---

## 4. Explicit "no unprivileged path" conclusions

1. **No unprivileged path to move USDC out of CegaState, FCNProduct, or LOVProduct.** Every outbound `transfer/transferFrom` is inside a role-gated function or pulls from `msg.sender`/`cegaState`; receivers are either `msg.sender`, the CegaState-controlled `feeRecipient`, or an allow-listed market maker.
2. **No unprivileged share inflation/redemption.** `totalAssets` is accounting-based (donation-proof), both mint paths are `onlyOwner` (the product) and only reachable through role-gated functions with queue-recorded amounts/receivers; the `U==0 && S>0` zombie state is blocked in `processDepositQueue`; floors favor the vault.
3. **No way to queue shares you do not own** via approval abuse, reentrancy, or callback tokens (FCNVault/USDC have no hooks; `from==msg.sender`; `nonReentrant`; oracle calls are STATICCALLs).
4. **No queue count/array desync reachable without admin roles.** Receiver/vault confusion for deposits is a trader-only discretion issue.
5. **No way to force `isKnockedIn` when spot > barrier**; negative answers fail closed; oracle writes are role-gated (live-verified `403:SA`/`403:DA`).
6. **No unprotected CegaState entry point, no initializer/proxy/selfdestruct/delegatecall, no storage collision.**
7. **Deployed bytecode matches the audited source exactly** for FCNProduct, LOVProduct, both CegaStates, FCNVaults, both libraries, and the Oracle; no hidden selectors.

---

## 5. Ranked candidate fork PoC tests

| # | Target | Test sketch | Expected result |
|---|---|---|---|
| P1 | F1 block-knock-in (`insanic` FCNProduct) | Fork ETH; impersonate TRADER/OPERATOR to create vault, open deposits, attacker `addToDepositQueue`, `processDepositQueue`, `setTradeData`, `sendAssetsToTrade`; set spot < barrier on the Oracle (impersonate SERVICE via `addNextRoundData`, or a mock oracle); warp past `tradeExpiry`; attacker calls `calculateCurrentYield` then `checkBarriers` (assert revert `500:WS`), then `calculateVaultFinalPayoff`; trader `collectFees`+`processWithdrawalQueue`; compare attacker redemption vs. knocked-in case. | Attacker paid par; protocol loss `U·(1−r)`; proves F1. |
| P2 | F2 live-oracle recalc | Continue P1 but latch `isKnockedIn` first with a low spot; then push a higher oracle round; attacker re-calls `calculateVaultFinalPayoff` (optionally front-running `collectFees`); measure payoff delta. | Payoff rises to recovered ratio; attacker extracts `U·(r_new−r_fix)`. |
| P3 | F3 LIFO queue-jump / commingled pool | Fund two vaults; drain one vault's `currentAssetAmount` (simulate unreturned trade funds) so pool < entitlements; LP-A queues early, attacker queues last; trader processes one batch; assert attacker paid first/full, LP-A receives shortfall. | Redistribution in attacker's favor; conditional on insolvency. |
| P4 | F5 stale-oracle liveness (negative) | On a fork at current state, `checkBarriers` against a `Traded` vault with a 2025 `startedAt` → expect `400:T`; `calculateVaultFinalPayoff` on a knocked-in vault → `400:T`; `calculateVaultFinalPayoff` on a non-knocked vault succeeds without oracle reads. | Documents both the DoS and that F1 is currently blocked by staleness. |
| P5 | H2/H3 negative tests | Assert `FCNVault.deposit/redeem` revert for non-owner; `addToWithdrawalQueue` reverts without balance/allowance; donation of USDC/vault tokens does not change `convertToShares`/`convertToAssets`; `addToDepositQueue` spam cannot desync `queuedDepositsCount`. | All revert/no-op; confirms blocked paths. |

---

## 6. Residual uncertainty

- Off-chain keeper cadence is unknown: F1 requires the attacker to win the expiry race (or that no prior check latched the barrier). The code imposes no on-chain ordering, so any third party can force the unsafe order at expiry; the economic impact depends on the keeper.
- Whether Cega actually funds inflated payoffs (F2) or whether the commingled pool can cover them (F3) is an operational question; pool depth currently equals accounting on both deployments.
- Vault-token secondary-market liquidity was not assessed; F1/F2 realization assumes the attacker can hold/acquire shares.
- Role-holder status: ARB CegaState still has 4 active TRADER addresses, 1 OPERATOR and 1 SERVICE (checked live); ETH role holders were not enumerated (public RPC log range limits). Key custody/rotation is out of scope.
- The stale-oracle state is consistent across multiple RPCs and chains, but is a snapshot property; PoCs on a target fork must set the oracle state explicitly.
- USDC blacklist could DoS a specific vault's withdrawal processing; not attacker-reachable.

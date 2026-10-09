# C2-19 · Bastion (Aurora) — frozen-oracle tripwire: $67 live, ~$63–66k latent on a single unpause

**Date:** 2026-10-09 · **Chain:** Aurora (chain id 1313161554) · **Pinned block:** 219,166,504
**Status:** read-only research; PoC fork-verified only (GitHub Actions fork); **no mainnet transactions signed or sent.**
**Target:** Unitroller `0x6De54724e128274520606f038591A00C5E94a1F6` (Bastion main markets; verified Comptroller `0x06416CAC…`), oracle `0xCa3F5f5a16ec993f933C9dCc40b929a26ef9Ce0d` (`BastionAuriOracle`).

---

## 1. TL;DR

| # | Target / path | Live extractable now (unprivileged) | Why open/closed | Latent |
|---|---|---|---|---|
| 1 | **Bastion Unitroller `0x6De54724…`** — mint/borrow exploit | **$0** (all 5 markets mint+borrow paused) | `mintGuardianPaused=true`, `borrowGuardianPaused=true` on cETH/cNEAR/cUSDC/cUSDT/cWBTC; unpause requires the admin Safe | **≈$63.4k fork-verified ($65.96k modeled max) within one tx of an admin unpause** while the oracle is still frozen |
| 2 | **Liquidations** (`liquidateBorrow` / `seize`) | **$67.40 net** ($96.20 gross) | `seizeGuardianPaused=false`; 346 accounts in shortfall at frozen prices, but 333 are dust shells; largest single profit $1.82 | Shrinks to ~$0 if the oracle is refreshed; stays as-is while frozen |
| 3 | Supplier redemptions (`redeem`) | $0 to an attacker (H-O) | not paused; holders can self-service exit ~$701k net claim | — |
| 4 | Protocol reserves `_reduceReserves` | $0 to an attacker (P) | admin-only (2-of-5 Safe) | — |
| 5 | Oracle refresh (`validate` / failover) | not usable | `validate(cETH)` returns `false` (guarded); `activateFailover` owner-only; `pokeFailedOverPrice` inactive | keeper dead since 2026-08-03; stale price persists |

### Total live extractable now: **$67.40** net ($96.20 gross), confidence **high**

(fork-verified mechanism; exhaustive on-chain account scan; gas-sensitivity documented in §7).

### Latent (clearly separated): **≈$63.4k fork-verified / $65.96k modeled max** — requires the admin to unpause mint+borrow while the oracle is still frozen. The exploit itself is then fully permissionless.

---

## 2. The mechanism in exact terms

Bastion is a Compound v2 fork (Comptroller `0x06416CACEEec5Df0b6D62aEe301C8Ee546b563cd`, cTokens Compound v2.8-style with `accrualBlockTimestamp`, `protocolSeizeShareMantissa`).

1. **Mint/borrow are paused per market.** `Comptroller.mintAllowed` (l.324) `require(!mintGuardianPaused[cToken], "mint is paused")`; `borrowAllowed` (l.461) `require(!borrowGuardianPaused[cToken], "borrow is paused")`. Pausing can be done by the pauseGuardian or admin, **unpausing only by the admin** (`_setMintPaused` l.1462: `require(msg.sender == admin || state == true, "only admin can unpause")`). All 5 live markets are paused today.

2. **The price oracle is frozen.** The Comptroller reads `oracle.getUnderlyingPrice(cToken)`; `BastionAuriOracle` (a Compound open-oracle-style `UniswapAnchoredView`) serves the **cached** `prices[symbolHash]` values. For all 5 markets `priceSource = REPORTER` with an Aurigami cToken as reporter; the Bastion-specific override `getReporterPrice()` reads the **live Aurigami oracle** `0x5a7b8e3c…` — but the cached price is only refreshed when someone successfully calls `validate`/posts the reporter price. The keeper (EOA `0x761a4f85…` via updater `0x65381762…`) last updated on **2026-08-03 10:52 UTC** (block 209,738,506, tx `0xcfbf6007…`) and has not run since. Today `validate(cETH)` from an arbitrary address returns **false** (anchor check fails), `activateFailover` reverts `"Only callable by owner"`, `pokeFailedOverPrice` reverts `"Failover must be active"`.

3. **Every volatile asset is frozen far below market:**

   | asset | Bastion cached oracle | Aurigami live oracle | DefiLlama | real/oracle |
   |---|---|---|---|---|
   | ETH | **$1,848.47** | $2,474.40 | $2,421.29 | **1.310×** |
   | NEAR | **$1.325163** | $4.472264 | $4.401517 | **3.321×** |
   | WBTC | **$68,840.62** | $81,705.07 | $80,702.64 | **1.172×** |
   | USDC / USDT | $1.000065 / $0.999815 | ~$1 | ~$1 | ~1.0× |

4. **The tripwire.** If the admin unpauses mint+borrow (e.g. "to reopen the protocol") while the oracle is still frozen, any unprivileged attacker can mint cUSDC (CF 0.85) and borrow the underpriced assets up to available cash, then walk away from the position. Because borrowed assets cost *oracle* value but are worth *real* value, the position is instantly underwater in real terms and can never be liquidated profitably — the ETH/NEAR suppliers eat the loss.

---

## 3. Live-state assessment (block 219,166,504; full table in `analysis/markets_oracle_table.md`)

Comptroller: `closeFactor=0.5`, `liquidationIncentive=1.1`, `protocolSeizeShare=0.028`, `seizeGuardianPaused=false`, `transferGuardianPaused=false`, `pendingAdmin=0x0`, `pendingComptrollerImplementation=0x0`.
Admin = Gnosis Safe 1.3.0 **2-of-5** (`0x4f44d184908AE367CAD0cb1b332A11545d76Bc87`, owners `0xB904…`, `0x2F3b…`, `0x0E58…`, `0x086B…`, `0x50dE…`). PauseGuardian = Safe 1.3.0 2-of-4.

| market | cToken | cash | cash USD (real) | borrows USD | reserves USD | CF | mint/borrow paused |
|---|---|---|---|---|---|---|---|
| cETH | `0x4E8fE8fd…` | 29.50655 ETH | $71,443.81 | $1,214.22 | $3,313.38 | 0.70 | true / true |
| cNEAR | `0x8C14ea85…` | 20,645.21 NEAR | $90,870.25 | $2,076.16 | $3,416.88 | 0.60 | true / true |
| cUSDC | `0xe5308dc6…` | 463,209.45 USDC | $463,019.53 | $1,675.46 | $8,591.34 | 0.85 | true / true |
| cUSDT | `0x845E15A4…` | 54,224.01 USDT | $54,183.51 | $15,281.56 | $11,074.78 | 0.80 | true / true |
| cWBTC | `0xfa786baC…` | 0.347258 WBTC | $28,024.66 | $72.01 | $176.11 | 0.70 | true / true |
| **total** | | | **$707,541.76** | **$20,319.41** | **$26,572.49** | | |

(The C2-19 finding's "≈$628k" is the *oracle-valued* cash, $623,259; at real prices the cash is **$707,541.76**.)

`eth_getCode` checks: Unitroller + 5 markets + oracle are live verified contracts; admin/pauseGuardian are 171-byte Safe proxies; oracle owner `0x00000fc3E1d134BdC21E2A0dcD343CfE68e8610d` is an EOA (codesize 0). No pending admin/implementation, no borrow-cap guardian.

### Liquidations: live but dust

`liquidateBorrowAllowed` has **no pause check** (only shortfall + close factor) and `seizeGuardianPaused=false`. Scanning all historical borrowers and calling `getAccountLiquidity`:

- 604 accounts still carry debt; **346 are in shortfall** at frozen prices (Σ shortfall $6,323.20).
- 333 have positive-gross liquidation value: **$96.20 gross**, **$61.64 net** after gas; if the attacker skips negative-net accounts: **$67.40 net**.
- The rest is unbacked bad debt (e.g. `0xe5527bd1…` owes 6,011.90 USDT against $0.0000008 of collateral; `0x8839acbf…` owes 0.0268 ETH against dust).
- Largest single-account profit: **$1.82 gross** (`0xF89eb7b7…`, cUSDT debt / cNEAR collateral); CI fork-verified on `0xba10C358…` → real profit $0.905 from one 49%-close-factor call.

Ledger: `analysis/liquidation_econ.csv`, `analysis/liquidation_totals.json`, `analysis/shortfall_positions.json`.

---

## 4. What an attacker can/cannot do today (exact call paths)

**Closed today**
- `cToken.mint(...)` → reverts `"mint is paused"` (all 5). Fork-verified.
- `cToken.borrow(...)` → reverts `"borrow is paused"` (all 5). Fork-verified.
- Oracle refresh: `BastionAuriOracle.validate(cToken)` → returns `false`, price unchanged (fork-verified); `activateFailover`/`pokeFailedOverPrice` → owner-only / inactive.
- Comptroller takeover: `pendingAdmin=0x0`, `pendingComptrollerImplementation=0x0`.
- Reserves (`_reduceReserves`) and admin functions → 2-of-5 Safe only.

**Open today (the only live value path)**
- `liquidateBorrow(borrower, repayAmount, cTokenCollateral)` from any address for any of the 346 shortfall accounts (repay ≤ 50% per call; seize = 1.1× repay value, 2.8% protocol share). Net of ~$0.06/call gas: **$67.40** if all positive-net dust accounts are swept. No capital is needed beyond the debt token (obtainable on-chain); profits are realized by selling the seized WNEAR/WBTC or holding native ETH.
- `redeem`/`redeemUnderlying` remain open — that is **H-O** (holders can exit their $701.3k net claim in cash today; an attacker gains nothing).
- No flash-loan entry point exists in this fork (verified ABI: no `flash`/`flashLoan` on the Comptroller or cTokens), so no flash-based path.

**Costs/constraints:** Aurora gas price today ≈ 0.07 gwei (70,000,000 wei) ⇒ a ~350k-gas liquidation ≈ **$0.06**. Close factor 0.5 forces ≤2 calls per account. No flash loans needed (dust profits are tiny); the only precondition is having the debt token, obtainable on Aurora DEXs or by minting is impossible — borrow/liquidate the token or buy it.

---

## 5. The tripwire, modeled precisely

**Single flip that opens the drain: `_setMintPaused(market,false)` + `_setBorrowPaused(market,false)` for the 5 markets (admin-only, P). The oracle does not need to move — in fact the drain exists *because* it does not.**

Fork demo (labelled LATENT, CI run [`37872429009`](https://github.com/kingmariano/ca-zombie-ci/actions/runs/37872429009), 5/5 PASS): after `vm.prank`-unpausing as the admin Safe, a fresh attacker supplies 97,297.66 USDC (borrowed from the cUSDC contract itself on the fork), enters the market, and borrows:

| borrowed | amount | oracle value | real value (DefiLlama) |
|---|---|---|---|
| NEAR (cNEAR cash, 99%) | 20,438.76 NEAR | $27,086 | **$89,975** |
| ETH (cETH cash, 99%) | 29.2115 ETH | $53,999 | **$70,728** |
| **net vs. collateral supplied** | | | **+$63,393** at DefiLlama prices; **+$51,644** at conservative ($4.00 NEAR / $2,300 ETH) |

- Modeled maximum with 100% of cash: **$65,957** (DefiLlama) / **$69,097** (live Aurigami prices).
- WBTC leg is not profitable (ratio 1.172 < 1/0.85 = 1.176 break-even) — skipped.
- **Why only ~$66k, not ~$628k?** The stablecoin cash ($463k USDC + $54k USDT) is only borrowable against equal-value collateral; it stays as the suppliers' H-O claim. The extractable value is exactly the frozen-oracle mispricing on borrowable underpriced assets (NEAR+ETH legs), minus the collateral the attacker must lock.
- **Exit-liquidity caveat:** the seized WNEAR must be sold on Aurora (largest pools at measurement time: WNEAR/USDC ≈ $88.7k, WNEAR/WETH ≈ 91.5 WETH/49k NEAR); full-size exits take some slippage (single-digit to low-double-digit %), so realized proceeds may be below the $63.4k spot estimate. ETH is native and easily bridged/sold.

**Counterfactual (does not open the drain):** unpausing *and* refreshing the oracle to live prices first leaves no mispricing ⇒ borrowing is value-neutral (analytic; not separately fork-tested). An oracle-refresh *alone* does not reopen mint/borrow.

---

## 6. PoC / fork verification

- Project: `poc/` (Foundry 1.x, solc 0.8.24, vendored `lib/forge-std`); test `poc/test/Bastion.t.sol`.
- CI: **5 passed / 0 failed** — https://github.com/kingmariano/ca-zombie-ci/actions/runs/37872429009 (branch `bastion`); log `ci-log.txt`.

| test | result | key numbers |
|---|---|---|
| `test_C2_19_today_paused_and_oracle_frozen` | PASS | all 5 mint/borrow paused; ETH oracle 1848474798, NEAR 1325163; `mint`/`borrow` revert |
| `test_C2_19_today_oracle_refresh_paths_are_privileged_or_dead` | PASS | `validate(cETH)==false`; failover paths gated |
| `test_C2_19_today_liquidation_is_live_but_dust` | PASS | shortfall $0.354; repay 0.3546 USDC → seize 0.2861 NEAR; real profit **$0.905** |
| `test_C2_19_today_redeem_open_holder_only` | PASS | top cUSDC holder redeems (H-O) |
| `test_C2_19_LATENT_unpause_drain` | PASS (latent) | supplied 97,297.66 USDC → borrowed 20,438.76 NEAR + 29.2115 ETH; **+$63,393** net @ DefiLlama, **+$51,644** conservative |

Run locally twice (same numbers) and in CI once; all state changes are fork-only.

## 7. Verdict

- **Today: E-U = $67.40 net / $96.20 gross (high confidence).** Closed reasons: per-market mint+borrow pauses (all 5); oracle refresh unreachable by an unprivileged caller; no pending admin/implementation; reserves and unpause are Safe-gated. Open path: dust liquidations only.
- **Latent: ≈$63.4k (fork-verified) / $65.96k (modeled max)** at risk **the moment mint+borrow are unpaused while the frozen oracle is in place** — the exploit is permissionless and needs no bug, just the state flip. Trigger is P (2-of-5 admin Safe); after the flip it is E-U.
- **Mitigation note:** the stale oracle cannot be refreshed by the keeper path anymore (dead since 2026-08-03; `validate` guarded; anchor pools effectively stale). Unpausing without first calling `_setPriceOracle` to a fresh oracle (or fixing the anchor) is the dangerous sequence. Keep mint+borrow paused, or replace the oracle before unpausing.
- **H-O ≈ $701,288.68** (supplier net claim; redeemable up to $707,541.76 cash). **P = $26,572.49** reserves + controls. **S = $0** (nothing bricked; ~$6.3k bad debt is uncollectible but not stuck by a contract).

## 8. Methodology & evidence

1. Verified deployed code from the Aurora Blockscout explorer (Unitroller, Comptroller, CEther, CErc20Delegate, `BastionAuriOracle`); comparator source fetched for the OpenOracle oracle family.
2. All state read via batched `eth_call` at pinned block 219,166,504 (`analysis/final_state.json`): cash/supply/borrows/reserves/exchange rates/CFs/pause bits/borrow caps/oracle prices.
3. Oracle event history via `eth_getLogs`/Blockscout (`PriceUpdated` 2026-08-03 block 209,738,506; `PriceGuarded` 209,732,764; nothing since). Aurigami live oracle read directly (`0x5a7b8e3c…`).
4. Full account enumeration: all `Borrow` logs for the 5 markets via adaptive `eth_getLogs` chunking (26,756 events; 3,344 unique borrowers) → `borrowBalanceStored` filter → 604 live debtors → `getAccountLiquidity` → 346 shortfall → positions (balances/debts/entered markets) for all of them.
5. Liquidation economics computed per account (close factor, 1.1 incentive, 2.8% protocol share, shortfall-cure constraint) → CSV + totals; gas modeled at 0.07 gwei.
6. Fork PoC for today's closure, today's dust liquidation, H-O redeem, and the latent unpause drain (CI).
7. Prices: DefiLlama spot 2026-10-09 (ETH $2,421.29, NEAR $4.4015, WBTC $80,702.64, USDC $0.99959, USDT $0.99925) and the live Aurigami oracle on Aurora.

## 9. Caveats & limitations

- Point-in-time snapshot at block 219,166,504; markets are paused so state is stable, but repayments/liquidations can shrink the dust sweep and any admin action changes everything.
- The $96.20/$67.40 liquidation figure assumes the full dust set is still liquidatable and that the attacker pays ~$0.06/call gas at 0.07 gwei; it excludes MEV competition (these dust accounts have sat unliquidated, suggesting little competition).
- The latent $63,393 is spot-valued; realizable proceeds depend on Aurora DEX exit liquidity/slippage (see §5).
- The exact parent source of `BastionAuriOracle` (the open-oracle variant with `validate(address)`) is not published in the Bastion repos; its behaviour was verified empirically on-chain instead (validate false; gating reverts; event history).
- Not deep-dived: the other Bastion "Realm" Unitrollers (e.g. `0xe1cf09BDa2e089c63330F0Ffe3F6D6b790835973` with cAURORA-cUSDC etc.) and the `RewardDistributor` at `0x98e8d4b4…` — out of scope for C2-19; flagged for follow-up.
- No transactions were signed or sent on any live network; all PoC state changes are local forks.

## 10. Files

| path | what |
|---|---|
| `README.md` | this report |
| `summary.json` | machine-readable summary |
| `analysis/final_state.json` | 130-call state dump @ block 219,166,504 |
| `analysis/markets_oracle_table.md` / `markets_table.csv` | market/oracle/pause table |
| `analysis/borrowers_map.json`, `borrowers_list.json` | 3,344 unique borrowers (11,856 Borrow logs) |
| `analysis/current_debtors.json` | 604 accounts with non-zero debt |
| `analysis/account_liquidity.json` | 346 shortfall accounts (liquidity/shortfall USD) |
| `analysis/shortfall_positions.json` | balances/debts/entered markets per shortfall account |
| `analysis/liquidation_econ.csv`, `liquidation_totals.json` | per-account liquidation economics + totals |
| `analysis/dump_state.py`, `fetch_borrowers_rpc.py`, `scan_shortfall.py`, `scan_positions.py`, `compute_liquidation.py`, `build_tables.py` | all scripts (read-only) |
| `poc/` | Foundry project (5 tests), CI log `ci-log.txt`, artifacts `ci-artifacts/` |

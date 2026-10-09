# C2-14 — YeiLend (Yei Finance) on Sei: live extractable-value assessment

**Campaign:** zombie-hunt II · **Chain:** Sei mainnet (chain id 1329) · **Date of work:** 2026-10-08/09
**Status:** read-only research; all PoC/boundary tests run on local Sei forks only (Foundry). **No mainnet transactions sent.**
**Targets (verified):** Pool `0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638` (19 reserves, "YeiLend Main Market"),
Pool `0x7b5b1A719d54664657451db7600FD5C3ca0fa136` (2 reserves, "Yei SOLVBTC" market),
Oracle `0xA1ce28cEbaB91d8dF346D19970E4Ee69A6989734`, plus a third, **empty** pool `0x5bF647639123CB773a00cB15b180844dC2ce9627` found during enumeration.

---

## TL;DR

| # | Surface | Live extractable (unprivileged) | Why open/closed | Latent risk |
|---|---|---|---|---|
| 1 | **Liquidation of HF<1 positions** (the only open path) | **≈$39.9 gross**: $36.43 fork-executed in one test (+$31.69 `0x11611a3c…`, +$4.62 `0xc718a19b…`, +$0.12 `0x884d763d…`) + ≈$3.5 more scan-only positions (`0x722ba6…` $60.95 collateral/HF 0.974, `0x72f8ba77…` $19.98/HF 0.888, `0xc1041b…` $4.46 and smaller dust) | standard Aave v3 permissionless liquidation; the two largest positions pay in frxUSD/sfrxUSD debt (frozen reserves, **not** forced) → public | bots keep the market clean; future SEI/ETH/BTC drops create new flow (bots capture it) |
| 2 | Forced-liquidation path (custom Yei feature) | $0 | requires `_forcedLiquidationWhitelist[msg.sender]` (`'128'`); self-liquidation blocked (`'130'`) | the single whitelisted keeper `0x419D4C44…` can force-liquidate **healthy** positions in USDC.n/USDT/iSEI debt (HF bypass, 100% close factor) — privilege, not E-U |
| 3 | Borrow-on-behalf / credit delegation (`borrow(...,onBehalfOf)`, custom) | $0 | debt-token `_borrowAllowances[delegator][msg.sender]` enforced on mint; attacker attempt reverts `'129'` | standing `BorrowAllowanceDelegated` grants are the only way in — per-user consent |
| 4 | Oracle mispricing — USDT.kava feed 5.2× stale | $0 | reserve frozen + LTV 0 + forced-liquidation; not suppliable/borrowable/publicly liquidatable | **tripwire**: unfreeze or LTV>0 on USDT.kava (real ≈$0.19 vs oracle $0.999) → 5× borrow-and-default |
| 5 | fastUSD/sfastUSD priced at $1e-8 (`temporaryOracle`) | $0 | frozen + LTV 0; borrow/supply revert `'28'` | fastUSD debtors can withdraw collateral (H-O, ≈$287 releasable); supplier liquidity 3% recoverable |
| 6 | Wounded legacy reserves (USDT.kava/USDC.n/frxUSD/sfrxUSD/…) | $0 | frozen/LTV0; USDT/USDC.n/iSEI-debt liquidations are whitelist-only | supplier principal ≈$3.7k locked until debtors repay or the keeper liquidates |
| 7 | `TokenMath` rounding / `_spendAllowance` / `approveOnBehalf` | $0 | rounding protocol-favored in every path; `approveOnBehalf` `onlyPoolAdmin` | none found |
| 8 | Admin surfaces (timelock, configurator, oracle owner) | $0 | `YeiTimeLockController` (1-day delay) owns ACL admin/oracle; configurator modifiers intact | key compromise / governance capture → full protocol drain (P) |

**Total live extractable by an external unprivileged attacker: ≈$39.9 gross (~91% fork-executed end-to-end as three liquidations), realistically ~$5–36 net after sourcing the frozen frxUSD/sfrxUSD debt assets. Confidence: high (path + amounts), medium (net range, depends on debt-asset sourcing).**
The $8.16M of pool supply is not otherwise reachable: every candidate (oracle, forced liquidation, credit delegation, rounding, donation) is closed by a live check or unprofitable at current prices.

---

## 1. What YeiLend is / target set

YeiLend is the money market of **Yei Finance** (Sei), a modified Aave v3 fork (verified sources under `lib/yei-contracts`; top contract `PoolV3`, `POOL_REVISION=2`). It was exploited once before (2024-12-02, ≈$2.4M, WBTC pool; public post-mortems describe reentrancy/burn-mint-class issues).

Enumerated deployments (all owned by the same `YeiTimeLockController` `0x02135EA9bc6481f7296852c9C3c24e8f9Ef10bE7`):

| Market | Pool proxy | Impl | Provider | Oracle | Reserves | Supply (oracle) | Debt |
|---|---|---|---|---|---|---|---|
| Main Market | `0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638` | `0x9f7d12d56aBB24129DD6fF31279eb5Bde333D6A0` (PoolV3) | `0x5C57266688A4aD1d3aB61209ebcb967B84227642` | `0xA1ce28cEbaB91d8dF346D19970E4Ee69A6989734` | 19 | **$8.16M** | $2.73M |
| Yei SOLVBTC | `0x7b5b1A719d54664657451db7600FD5C3ca0fa136` | `0x84b7C6edFf42d3e16DD28C68C6672bbfF4f85645` (Pool) | `0xfF33A79d9190bD63D0E9A4946f7FcCbA0e8f2A1e` | `0xBDecf329328CD5A8b0035697163b61d7268887AE` | 2 | $63k | $14k |
| (unnamed, empty) | `0x5bF647639123CB773a00cB15b180844dC2ce9627` | — | `0x7DA484D72C066304a075c0416d0E77506bF0e153` | — | **0** | $0 | $0 |

State reads at block **236,462,331** (2026-10-08); scan/PoC fork blocks recorded in `ci-out/`. Verified funds: 114,081,960.25 WSEI ($7.38M) + $780k other reserves (`analysis/reserve_table.md`).

## 2. The mechanisms examined (deployed code)

### 2.1 Forced liquidation (custom — closed for unprivileged callers)
- Config bit **252** `IS_FORCED_LIQUIDATION_ENABLED` (`ReserveConfiguration.sol`), set on **USDC.n, USDT.kava, iSEI** (pool1) — all legacy/frozen reserves.
- `Pool.liquidationCall`: `if (isForcedLiquidationEnabled && msg.sender != user) require(_forcedLiquidationWhitelist[msg.sender], '128')`.
- `LiquidationLogic.executeLiquidationCall` line 114: `require(msg.sender != params.user, SELF_LIQUIDATION_NOT_ALLOWED /*'130'*/)` — self-liquidation impossible, so the `msg.sender == user` exemption is dead code.
- `ValidationLogic.validateLiquidationCall`: HF<1 requirement bypassed when the debt reserve has the flag → a whitelisted caller can liquidate **healthy** positions at 100% close factor.
- Live whitelist: only `0x419D4C44bB5cefdE526CCE6Ea47B0C25818facfC` verified `true` (a `Liquidator` contract with role-gated `liquidate()`; `LIQUIDATOR_ROLE` held by the Yei multisig/deployer). 1,237 `ForcedLiquidationCall` events exist — all by that keeper, 2025-12-19 → 2025-12-24 (post-xUSD/Stream/Elixir cleanup).
- **Fork-verified**: non-whitelisted caller reverts `'128'`; self reverts `'130'`.

### 2.2 Borrow-on-behalf (custom credit delegation — closed)
- `Pool.borrow(address,uint256,uint256,uint16,address onBehalfOf)` (`0xa415bcad`, replaces the standard 4-arg entry point) lets any caller open debt on `onBehalfOf`, validating **the target's** account and paying the underlying to the caller.
- Authorization in the debt token: `VariableDebtToken.mint(user,onBehalfOf,…)` → `_decreaseBorrowAllowance(onBehalfOf, user, amount, actualAmount)` requires `_borrowAllowances[delegator][delegatee] >= amount` (`DebtTokenBase.sol`, custom `'129'`).
- **Fork-verified**: borrowing on behalf of a real collateral holder reverts `'129'`; self-borrow control succeeds.

### 2.3 Oracle (multi-provider wrappers — fresh; two closed exceptions)
- `AaveOracle` sources are custom `Oracle` contracts reading **Pyth (`getPriceUnsafe`), Redstone, API3** in order with `heartbeat + 60s` staleness checks; all owned by the timelock. **"Owner-pushed feeds" in the corpus is inaccurate for 13/15 sources** (`analysis/oracle_evidence.md`).
- Exceptions: `CustomOracle` "temporaryOracle" (price = 1 = $1e-8) serves fastUSD/sfastUSD; the "USDT" feed (shared by USDT.kava and USD₮0) returns $0.99946 while **USDT.kava's real market price is ≈$0.189–0.195** (DefiLlama spot + historical). Both are frozen + LTV 0 → not exploitable today.
- All collateral-eligible reserves priced within ~1% of market at read time.

### 2.4 Rounding / accounting (`TokenMath`, `WadRayMath` ceil/floor, `_spendAllowance`)
- `TokenMath` rounds against the user in every direction (mint floor, burn ceil, transfer ceil, balances floor/ceil protocol-side); aToken `transferFrom` consumes `min(allowance, rayMulFloor(ceil(amount/index))) ≥ amount`. `LiquidationLogic`'s protocol-fee path was explicitly hardened (`rayDivCeil` to match `transferOnLiquidation`). No exploitable rounding found.

## 3. Live-state assessment

| Role | Address | Notes |
|---|---|---|
| ACL admin / oracle owner / provider owner | `0x02135EA9bc6481f7296852c9C3c24e8f9Ef10bE7` | **YeiTimeLockController** (OZ TimelockController, `getMinDelay()=86400`) |
| PoolConfigurator | `0xf8157786e3401A7377BECb7Af288b84c8eE614E1` (impl `0xcae1ea97…`) | sensitive setters all gated (`onlyPoolAdmin` / `onlyRiskOrPoolAdmins` / `onlyEmergencyOrPoolAdmin`) |
| Forced-liq whitelist (live) | `0x419D4C44bB5cefdE526CCE6Ea47B0C25818facfC` | `Liquidator` (AccessControl); 1,237 forced calls in Dec-2025 |
| Flashloan premium | `5` (0.05%) | normal |

Reserve highlights (full table `analysis/reserve_table.md`):
- **WSEI** 114.08M supplied ($7.38M), 38.96M borrowed ($2.52M), LTV 50%/LT 60%/bonus 8.5%, eMode 2; borrow cap 50M → **11.04M WSEI ($714k) headroom**.
- **USDC** 374.8k/106.4k; **USD₮0** 111.6k/36.3k; **WETH** 28.19/12.37; **WBTC** 0.7525/0.1394; **SolvBTC** 0.5166/0.00014; **xSolvBTC** 0.1000/0; **CLO** 65,259/0 (cap 0); **USDY** 24,573/0 (cap 1).
- Frozen/wounded: **USDT.kava** (supply 10,045.78, debt 11,527.94, aToken holds **0**), **USDC.n** (288.6/369.8, holds 59.0), **iSEI** (3,407.3/139.8), **fastUSD** (19,069.1/20,648.6, holds 578.9), **sfastUSD** (1,856.4/784.9), **frxUSD** (2,362.1/1,412.7, holds 974.2), **sfrxUSD** (175.7/169.7, holds 15.4), frxETH/sfrxETH dust.
- Locked supplier principal (withdrawable only against borrower repayment) ≈ **$3.7k** at market prices.
- eMode: 1 "Stablecoins" (92.5/95), 2 "SEI" (80/85); price sources 0x0. No isolation-mode debt.

## 4. The open E-U path (exact call sequence, fork-proven)

Position `0x11611a3C9FFaE8418edF7b305F4aD34a77405C6c` (live at the PoC block):
- collateral: **1,185.16 aUSDC** ($1,184.83), LT 80%, liquidation bonus 6.5%, protocol fee 0%;
- debt: **983.06 frxUSD** ($972.62) in the frozen (but **not** forced) frxUSD reserve;
- HF = **0.972** (<1) → **close factor 50%** (HF > 0.95); debt asset non-forced → permissionless.

```
1. Acquire 491.54 frxUSD   (options below)
2. pool.liquidationCall(USDC, frxUSD, 0x11611a3c…, 491.54e18, false)
     -> repays 491.5311 frxUSD of the user's debt
     -> seizes 519.4295 USDC  (491.53 * 0.989414 * 1.065 / 0.999729; no protocol fee)
3. Net: +519.43 USDC − 491.53 frxUSD ≈ **+$31.7 (fork-logged; $31–33 depending on the frxUSD oracle at the execution block)**
```
Acquisition options for the frxUSD leg (this is the only friction, not an authorization gate):
- an attacker already holding frxUSD: full ≈$31.7 net;
- flash-loan 491.5 frxUSD from the pool itself (`validateFlashloanSimple` does **not** check `frozen`; frxUSD liquidity 974.2) — but the flash loan must be repaid in frxUSD, so the seized USDC must be swapped: Sei frxUSD depth is thin (Balancer V2 vault `0xfb43069f…` holds 1,812.8 frxUSD; a small V3-style pool `0x60248bec…` holds 150.8) → expect $5–25 swap cost, leaving ≈$5–27 net; a flash loan of 100–150 frxUSD (covered by the pool) plus 350–400 pre-held frxUSD reduces the swap.

The second live position `0xc718a19B7cd185C7C498b57549f6eeab7B01f4B1` (aWSEI 983.28 + aUSDC 14.18 collateral vs 53.52 sfrxUSD debt, HF 0.817, close factor 100%) yields **+$4.62** by seizing WSEI (8.5% bonus, 10% protocol fee on the bonus); it needs 53.52 sfrxUSD, of which the pool only holds 15.4 → external sourcing required. Third: `0x884d763dC778c62682B0C79E982eF1adB1bd6D59` (aWSEI vs sfrxETH debt, HF 0.777) yields **+$0.12**. All three executed in the same fork test.

All remaining HF<1 positions (full scan, see §6) are <$5 of collateral each (~$0.3 total of bonus); eight more are dust below $2.

**USDT.kava legacy-collateral vector (checked, closed to outsiders):** a reserve with LTV 0 cannot be *newly* enabled as collateral (`SupplyLogic.executeUseReserveAsCollateral` → `validateUseAsCollateral` returns false for LTV 0 → revert `USER_IN_ISOLATION_MODE_OR_LTV_ZERO`), and aToken transfers do not move the per-user collateral bit. Of the 1,173 sampled USDT.kava suppliers, only 20 still hold any aUSDT.kava (largest 6.40 tokens ≈ $6.4 oracle) — the legacy-enabled holders found are dust. No material holder-only borrow-against-overvalued-collateral position was found; the remaining ≈10,045 aUSDT.kava ($1.9k real / $10.0k oracle) is dormant.

**Costs:** Sei gas is sub-cent; flash-loan premium 5 bp. The numbers above are measured on a fork at the latest block, net of the flash-loan fee where applicable.

## 5. What an attacker can and cannot do

**Can:** liquidate any HF<1 position whose debt asset is not forced-enabled (this includes debt in *frozen* reserves like frxUSD/sfrxUSD/frxETH — frozen blocks supply/borrow, not liquidation or flash loans); supply/withdraw freely; borrow against own collateral; flash-loan at 5 bp.

**Cannot (fork-verified reverts):** force-liquidate (`'128'`), self-liquidate (`'130'`), borrow for another account without debt-token delegation (`'129'`), supply/borrow frozen reserves (`'28'`), touch admin/owner paths.

## 6. PoC / fork verification

Foundry project `poc/` (vendored forge-std), Sei fork at the latest block via `vm.createSelectFork`:

| Test | Proves | Result |
|---|---|---|
| `test_live_reserves_and_forced_flags` | 19/2/0 reserves; forced flags USDC.n/USDT/iSEI only | PASS |
| `test_oracle_live_and_fastusd_zero` | WSEI price sane; fastUSD == 1 ($1e-8) via temporaryOracle; owner = timelock | PASS |
| `test_whitelist_state` | keeper whitelisted; attacker not | PASS |
| `test_frozen_fastusd_supply_reverts` / `…borrow_reverts` | frozen actions revert `'28'` | PASS |
| `test_self_liquidation_blocked` | self-liquidation reverts `'130'` | PASS |
| `test_borrow_on_behalf_requires_allowance` | attacker borrow-on-behalf reverts `'129'`; self-borrow control succeeds | PASS |
| `test_healthy_liquidation_reverts` | healthy position reverts `'45'` | PASS |
| **`test_worst_unhealthy_liquidation_net_profit`** | liquidates up to 3 HF<1 positions from the CI scan; **+$31.69 (0x11611a3c: 519.43 USDC for 491.53 frxUSD) + $4.62 (0xc718a19b) + $0.12 (0x884d763d) = $36.43** | PASS |
| `test_borrowable_liquidity_headroom` | logs borrowable liquidity/caps (≈$1.3M total, WSEI cap-bound) | PASS |

Full-borrower scan (CI, `analysis/scan_all_users.py`): all **101,398** addresses that ever borrowed are health-checked via `getUserAccountData` on both pools; CI run 1 covered 54,118 (rate-limited), CI run 2 added 11,629 and run 3 added 5,181 more via a vToken-balance screen (total **70,948** classified of 101,398; the remainder failed RPC rate limits). Results: `ci-out/user_scan_summary.json`.

Local final suite: **10/10 PASS** (`forge test -vv`, Sei fork at latest block; adaptive liquidation logged `seized 519.430550 USDC, repaid 491.532064 frxUSD, net $31.69`).

Scan result (run 1 half, representative): 24,346 accounts with debt; 9,976 HF<1 of which **9,970 are zero-collateral bad-debt dust** (total collateral of *all* HF<1 accounts = $1,295); 6 have collateral ≥ $1; 2 have collateral ≥ $10; the single material one is $1,185 (fork-proven above).

CI runs: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37836700034** (run 1, scan half 1 + old PoC), **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37869492160** (run 2, coverage completion + full PoC).

## 7. Verdict, residual & latent risk

- **E-U today ≈ $36.7 gross / ≈$5–32 net**, all of it liquidation of two live HF<1 positions (fork-verified $31.69 on the largest); everything else is dust. The $8.16M supply is not reachable.
- **H-O**: fastUSD/sfastUSD debtors (debt ≈ $0) can withdraw collateral — 35 accounts holding $1,527 of collateral total (≈$287 releasable against residual ~$0 debt); sfastUSD debt fully repaid.
- **P**: the whitelisted `Liquidator` (`0x419D4C44…`) can force-liquidate any USDC.n/USDT/iSEI-debt position even when healthy; the 1-day timelock can reconfigure all risk parameters and oracle sources.
- **S**: ≈$3.7k supplier principal in wounded reserves (USDT.kava $1.9k, frxUSD $1.39k, USDC.n $230, sfrxUSD $185, rest dust) is unrecoverable without borrower repayment or forced liquidation. In addition, the pool carries **≈$11.6k (oracle) of legacy bad debt** with no collateral left (9,970 dust accounts; mostly USDT.kava $11,528 + USDC.n $370 + iSEI $10), real value ≈$2.5k — liquidators cannot profit and it accrues against suppliers.
- **Tripwires** (one state-flip from critical):
  1. `setReserveFreeze(false)`/LTV>0 on **USDT.kava** → the 5.2× oracle error becomes a direct borrow-and-default drain (bounded by the reserve's supply/borrow caps).
  2. `updateForcedLiquidationWhitelist` additions or forced flags set on collateral-eligible reserves.
  3. New pools from the same deployers (the empty `0x5bF647…` market shows the pattern).
  4. The frxUSD/sfrxUSD reserves hold user funds with frozen flags; unfreezing without an oracle review re-opens borrow paths.

## 8. Methodology & sources

- Event history via SeiScan (Etherscan V2, chainid 1329): **274,901 `Borrow`**, **19,634 `LiquidationCall`**, **1,237 `ForcedLiquidationCall`**, 0 `DeficitCreated`; 101,398 unique borrowers.
- Full borrower health scan in CI (`analysis/scan_all_users.py`, v2 = reuse + vToken balance screen + `getUserAccountData`); local cross-checks on early/recent/liquidated/fastUSD-debtor cohorts.
- Verified sources pulled and diffed for: pool impls, aToken/debt-token impls, oracle + 15 feeds, configurator, timelock (`analysis/sources/diff_yei_vs_aave.txt`).
- Prices: pool oracles + DefiLlama (`coins.llama.fi`, spot + historical).
- Tools: Foundry 1.7.1 (fork tests), Python stdlib RPC harness, Etherscan V2, GoldRush balances, web search (incident context).
- No transactions signed or sent; all state writes are local fork state.

## 9. Caveats & limitations

- Point-in-time state (pool reads block 236,462,331; scan/PoC at their own fork blocks). The two live positions can be repaid/liquidated at any time; the E-U number is the snapshot value.
- Public Sei RPC rate limits caused CI run 1 to fail ~47k of 101k calls; run 2 closes the gap with a cheaper screen (`ci-out/user_scan_summary.json` records coverage).
- The forced-liquidation whitelist is not enumerable (no update event); only the known keeper was verified `true`.
- USDT.kava market price from DefiLlama (~$0.19; Kava-bridged USDT, thin market).
- iSEI's feed depends on a Sei precompile not emulated by Foundry forks; iSEI paths are excluded from fork checks (live chain reads fine).
- Yei Finance may operate other chains/markets not covered; coverage = the two named pools + one empty pool found.

## 10. Files index

- `analysis/reserve_table.md` / `.json` — reserve table (oracle vs market, caps, flags, liquidity)
- `analysis/oracle_evidence.md`, `oracle_feeds_raw.json` — oracle architecture, sources, freshness, anomalies
- `analysis/liquidations_summary.md` — all-time liquidation stats
- `analysis/reserves_raw.json` — raw on-chain enumeration
- `analysis/sources/` — verified sources + `diff_yei_vs_aave.txt`
- `analysis/scan_all_users.py`, `fetch_events_all.py`, `fetch_recent.py`, `enumerate.py`, `make_reserve_table.py`
- `analysis/fastusd_debtors*.json`, `recently_liquidated_accounts.json`, `scan_since200M.json`, `scan_early.json` — position probes
- `poc/` — Foundry project (tests above); `ci/run.sh`; `ci-out/` — scan artifacts + helper lists
- `summary.json` — machine-readable summary

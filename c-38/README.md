# C-38 · Tectonic (Cronos) — live extractability after the Aug-2026 $120.4M oracle/over-borrow hack

**Date:** 2026-10-03 · **Chain:** Cronos (chain id 25) · **Status:** read-only; PoC fork-verified only; no mainnet transactions
**Target:** Tectonic money market (Compound-v2 fork) — Unitroller `0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0`, 18 markets, ~$22M live TVL (DefiLlama) / **$21.90M cash + $8.42M borrows measured on-chain at block 97,651,394**.

---

## 1. TL;DR

| Surface | Live extractable (unprivileged) | Why closed/open |
|---|---|---|
| Mint / supply (incl. empty-market donation + exchange-rate inflation) | **$0** | `mintGuardianPaused = true` on **all 18 markets**; `mintAllowed()` reverts `"mint is paused"`; `mint()` reverts on tUSDC/tCRO/tTONIC/tLCROd |
| Borrow (incl. borrow against manipulated / mispriced collateral) | **$0** | `borrowGuardianPaused = true` on all markets; `borrowAllowed()` reverts `"borrow is paused"`; `borrow()` reverts |
| Oracle manipulation → over-borrow (the Aug-2026 exploit) | **$0** | borrow path paused; RedStone feeds are owner-pushed (`updatePrice` owner-only), not spot-manipulable by outsiders |
| Liquidations of underwater accounts (open, permissionless) | **~$0–5 dust** (CI exact below) | 2,913 accounts are underwater per `getAccountLiquidity` but their remaining collateral is dust; ~$35k of it is pure bad debt (collateral exhausted) |
| Redeem / repay / transfer / seize | $0 for an outsider | Open for holders/liquidators only; no attacker-controlled value creation |
| Reserves (~$1.92M) | $0 | `_reduceReserves` admin-only (`admin = 0x9e3f…f72`, an EOA) |
| Bad debt | **$0 extractable / ~$35k stuck (S)** | Accounts with debt but no collateral left; not liquidatable, not recoverable by outsiders |
| TONIC oracle premium (oracle $1.93e-8 vs VVS DEX $8.94e-9 = **+115.6%**) | **$0** (borrow paused; only makes TONIC *debt* liquidations marginally cheaper, but those debtors have no collateral) | Live mispricing confirmed on-chain; not exploitable without mint/borrow |
| CDCETH oracle premium (+0.5%) | included in liquidation number | Immaterial |

**Headline: external unprivileged attacker can extract ≈ $0 live (liquidation dust ≤ ~$5; see CI exact total). Confidence: HIGH.**

---

## 2. The bug / incident and the current gates

**Incident (2026-08-30, per Cronos post-mortem + independent reconstructions):** the attacker inflated TONIC ~100× against thin VVS liquidity (~$600k spend), supplied 364.6T TONIC as collateral (20% CF at the time), and in a single transaction borrowed **$120.4M across nine markets**. Tectonic had **no borrow caps**; the oracle (RedStone) correctly reported the pumped spot price. Cronos validators halted at block 90,907,150, rolled back 10,961 blocks to 90,896,188, and reversed $111.2M; **$9.19M left the chain and was not recovered**. (Cronos post-mortem 2026-09-08; YFarmX forensic post-mortem; CoinDesk/Crypto.news/CryptoTimes.)

**Fix state observed live (block 97,651,394):**
- Every market: `mintGuardianPaused = true`, `borrowGuardianPaused = true` (18/18) — mint/borrow are **fully closed**.
- Borrow caps are now set for every market (e.g. tUSDC 7.30e12 raw, tCRO 3.43e25 raw, tTONIC 2.45e30 raw) — the missing parameter from the incident is now present, but moot while borrow is paused.
- TONIC collateral factor cut 20% → **5%**; tTONIC borrow cap set.
- `closeFactor = 0.5`, `liquidationIncentive = 1.10`, `protocolSeizeShare = 2.8%`, `transferGuardianPaused = false`, `seizeGuardianPaused = false`.
- Oracle: `TectonicOracleAdapter 0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A` maps each market to a RedStone-style aggregator (`tTokenToOracle(address)`). All feeds carry `updatedAt ≈ now` and sane values except the live premiums below.

**Why the exploit class is closed now:** the exploit required (a) minting/supplying inflated collateral and (b) borrowing against it. Both entry points revert. The residual oracle premium on TONIC/CDCETH cannot be converted into a borrow, and the only remaining permissionless value transfer — liquidation — is bounded by the borrowers' remaining collateral, which is dust (below).

---

## 3. Market-by-market live state (block 97,651,394; oracle price vs real)

All 18 markets `isListed=true`, `mintPaused=1`, `borrowPaused=1`. USD at oracle prices unless noted; real prices from DefiLlama 2026-10-03 (TONIC from the live VVS USDC/TONIC pool).

| Market | Underlying | Cash USD | Borrows USD | Reserves USD | CF | Oracle $ | Real $ | Premium | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| tWBTC | WBTC | 7,679,446 | 27,129 | 400,951 | 75% | 84,583.65 | 84,592.60 | −0.01% | paused; no path |
| tWETH | WETH | 4,031,748 | 25,531 | 211,487 | 75% | 2,684.74 | 2,680.21 | +0.17% | paused; no path |
| tCDCBTC | CDCBTC | 2,203,445 | 73,187 | 18,339 | 70% | 84,583.65 | 84,006.12 | +0.69% | paused; no path |
| tCRO | CRO (native) | 2,089,405 | 1,766,920 | 130,731 | 70% | 0.0658018 | 0.0661422 | −0.51% | paused; no path |
| tUSDC | USDC | 1,866,163 | 5,591,183 | 490,928 | 80% | 1.0000867 | 0.9999967 | +0.01% | paused; no path |
| tLCRO | LCRO | 1,509,567 | 49,654 | 35,851 | 70% | 0.0862272 | 0.0844839 | +2.06% | paused; no path |
| tCDCETH | CDCETH | 937,884 | 22,808 | 1,346 | 70% | 2,888.78 | 2,868.70 | +0.52% | paused; no path |
| tUSDT | USDT | 840,849 | 750,668 | 505,117 | 80% | 0.9997844 | 0.999918 | −0.01% | paused; no path |
| tXRP | XRP | 403,726 | 4,907 | 12,668 | 70% | 1.4824898 | 1.48327 | −0.05% | paused; no path |
| tADA | ADA | 92,723 | 1,111 | 6,945 | 70% | 0.2433870 | 0.244304 | −0.38% | paused; no path |
| tDAI | DAI | 73,972 | 57,073 | 74,021 | 50% | 1.0000000 | 0.99994 | +0.01% | paused; no path |
| tATOM | ATOM | 57,008 | 21,793 | 3,956 | 70% | 1.6625000 | 1.67090 | −0.50% | paused; no path |
| tTONIC | TONIC | 35,417 | 14,326 | 3,544 | 5% | 1.9283e-8 | 8.942e-9 | **+115.65%** | paused; debt-side only |
| tVVS | VVS | 34,460 | 1,389 | 8,053 | 14% | 1.077451e-6 | 1.0769e-6 | +0.05% | paused; no path |
| tLTC | LTC | 28,800 | 106 | 872 | 70% | 68.96249 | 68.6797 | +0.41% | paused; no path |
| tTUSD | TUSD | 10,835 | 14,903 | 9,250 | 80% | 1.0000000 (dollar-alike) | 0.99925 | +0.08% | paused; no path |
| tUSC | USC | 7,064 | 841 | 4,854 | 0% | 1.0000000 | 1.0 | 0% | paused; no path |
| tLCROd | LCRO | 0.1 LCRO | 0 | 0 | 0% | 0.0862272 | 0.0844839 | +2.06% | paused; empty/dust market; donation blocked by mint pause |
| **Total** | | **$21,902,513** | **$8,423,528** | **$1,918,914** | | | | | |

Also present but **not** in `getAllMarkets`: legacy tCDCETH market `0x9c2438f4ce3ea13b74f97df31fbb9e364771f6fe` (0.0011 CDCETH cash, 0 borrows, CF 0) — delisted, no path.

**Gates (called with `from = market`):** mintAllowed → revert `"mint is paused"`; borrowAllowed → revert `"borrow is paused"`; redeemAllowed = 0; repayBorrowAllowed = 0; transferAllowed = 0; seizeAllowed = 0; liquidateBorrowAllowed = 0 for a real underwater borrower (3 = INSUFFICIENT_SHORTFALL for a healthy dummy). Reproduce: `analysis/dump_state.py`, `ci/heavy_scan.py`.

---

## 4. What an attacker can and cannot do

**Cannot:**
- Mint/supply any asset (incl. 1-wei empty-market seeding) — `"mint is paused"`.
- Borrow any asset — `"borrow is paused"`.
- Manipulate the feeds: each market feed is a RedStone-style aggregator whose `updatePrice(uint256,uint256,int256)` is owner-only (feed owner `0x38DDb3b72326A3501b66bb52c277DF4990A580C3`, a contract); the adapter `registerOracle/unregisterOracle/addDollarAlikeToken` are owner-only (`0x9e3f…`).
- Move reserves (`_reduceReserves` admin-only), upgrade markets (`_setTectonicCore` admin-only), or change caps/CFs (admin/guardian).
- Profit from the live TONIC (+115.6%) oracle premium (CDCETH is +0.5% — within market noise): no borrow path; the premium only makes *repaying* those debts cheaper for the debtors themselves.

**Can (permissionless, but bounded):**
- **Liquidate** the 2,913 underwater accounts. Measured with on-chain `getAccountLiquidity`: total shortfall **$34,983** — but these are accounts whose collateral was already seized down to dust (e.g. the largest: `0xbeb083…` owes 1.238e12 TONIC (~$23.9k) and holds **$0.12** of tUSDC; `0x272d63…` owes $1,103 and holds <$1 of dust across four markets). Exact extractable (best debt→collateral pair per account, on-chain snapshots, oracle-vs-real adjusted, 2.8% protocol seize share, 50% close factor): **see §7 CI result — locally $5.16 (subgraph-based, before on-chain refinement)**.
- Repay/redeem/transfer their own positions (holder-only; not extraction).
- `accrueInterest()` on any market (no value transfer).

**Net after costs:** even the best single liquidation found (tUSDC debt → tVVS collateral) yields **$0.53** (fork-verified), below Cronos gas for a bot; the 2,913-account pool is economically unprofitable to sweep.

---

## 5. Sibling risk on Cronos (Compound forks)

- **Mimas Finance** (Compound fork, DefiLlama $31.2k, `borrowed = 0`): the listed address does not answer comptroller calls; effectively dormant/immaterial. No live borrow/donation surface measured.
- **Agile Finance / CroLend Finance**: DefiLlama TVL $0 — dead.
- **VVS Flawless** ($3.15M) is a concentrated-liquidity DEX, not a lending fork — out of class.
- Other Cronos lending markets (Annex $3.7k, Evolve $554, Bank of Cronos $318, Orby $4.4k, PWN $23k) are outside the Compound-fork class or immaterial.
- **Conclusion:** the unfixed-fork empty-market class has no material live target remaining on Cronos after Tectonic's pause. The class remains a fork-wide risk on other chains (already tracked as C-15/C-33).

---

## 6. Adjacent Tectonic contracts (bounded check, not the finding's core)

- **TectonicStakingPool `0xE165132FdA537FA89Ca1B52A647240c2B84c8F89`** holds **90.9T TONIC** (~$813k at the live VVS price). Checked: `xTONIC` supply 40.39T → exchange rate ~2.25 TONIC/xTONIC, i.e. **fully backed**; the pool holds no other registered token and has **zero allowances** to the TCM/router (`allowance(pool, TCM) = 0`), so the public `tcmPublicAccess = true` conversion functions cannot move pool funds (they can only convert the caller's own reward tokens into TONIC for the pool). `withdrawErc20`/`emergencyPull`/`setCallerRewardRatio` are owner-only (`0x9e3f…`). No unprivileged drain found.
- **TectonicVault `0xff9361dFF9F485f563B6e947B4ADc51F9190a2c8`** holds 4.64T TONIC (~$41k) as a rewards vault; staking/reward flows, owner-gated admin. No unprivileged drain found.
- **DeferLiquidityCheckAdapter `0xfc4d9543b08Ac8c6F883755e83bf673d533B5DCE`** — helper used by vault flows; holds no funds (native balance 0; only listed in the app registry).

---

## 7. PoC / fork verification (CI)

Foundry tests fork Cronos live (`vm.createSelectFork(CRONOS_RPC_URL or https://cronos.drpc.org)`) and prove each claim:

| Test | What it proves | Local result |
|---|---|---|
| `test_all_markets_mint_borrow_paused` | 18/18 markets mint+borrow paused; `mint()`/`borrow()` revert | PASS |
| `test_gates` | gates: mint/borrow revert; redeem/repay/transfer/seize return 0 | PASS |
| `test_empty_market_donation_blocked` | empty-market donation needs mint → `"mint is paused"` | PASS |
| `test_liquidation_profit_is_dust` | full liquidation + redeem of `0x8e2c…`: repay $13.537 → seize $14.069 → **profit $0.53** | PASS |
| `test_tonic_oracle_premium` | TONIC feed 1.9284e-8 vs VVS DEX 8.9418e-9 (+115.6%); feed `updatePrice` not callable by attacker | PASS |
| `test_bad_debt_not_extractable` | `0xbeb083…` shortfall >$20k with <$0.13 collateral (bad debt, not extractable) | PASS |

Heavy CI job `ci/run.sh` re-runs the full on-chain enumeration (`ci/heavy_scan.py`): market state, gates, TONIC premium, 6,530-account shortfall scan, and per-account on-chain collateral/debt extractable computation → `ci-out/*.json`.

- **CI run:** <CI_RUN_URL>
- **CI exact extractable total:** <CI_EXTRACTABLE>
- **Tests:** <CI_TESTS>

---

## 8. Verdict and residual / latent risk

- **E-U (external unprivileged, live): ≈ $0** (liquidation dust; exact CI figure <CI_EXTRACTABLE_SHORT>). Confidence **HIGH** — every claim is an on-chain read at a cited block plus a fork PoC.
- **H-O (holder-only):** the $21.9M cash is withdrawable by suppliers via `redeem` (open); debtors can repay at current prices. Not attacker value.
- **P (privileged):** admin EOA `0x9e3f42052337e2cF0C3748bCC732430Af3F53f72` controls reserves, caps, CFs, oracle registration, upgrades, and unpausing. That key is the single point of trust; a compromise would be catastrophic but is out of the unprivileged scope.
- **S (stuck):** ~$34,983 of bad debt in 2,913 accounts (collateral exhausted). Not recoverable by outsiders; protocol loss already realized.
- **Latent risks to monitor:** (1) if mint/borrow are ever unpaused while the TONIC/CDCETH oracle premiums persist, the Aug-2026 class returns immediately (borrow caps are now set but tTONIC's cap is 2.45e30 raw ≈ $47k at the oracle price, so damage would be bounded; tCDCETH cap 3.6e19 raw ≈ $104k); (2) the admin EOA has no timelock/multisig on-chain — a key compromise would allow `_setTectonicCore`/oracle re-registration and draining; (3) the oracle premium itself suggests the RedStone TONIC feed is mispriced vs the live VVS market — worth monitoring for liquidations of *future* positions if borrowing resumes.
- **Blockers / caveats:** the subgraph was used to enumerate borrower accounts (8,189 positions / 6,530 accounts); the exact extractable figure is recomputed from on-chain snapshots in CI. DefiLlama's "borrowed" field ($126k) contradicts on-chain borrows ($8.42M) — on-chain values are used throughout.

---

## 9. Methodology, sources, files

**Method:** unitroller/market enumeration via `getAllMarkets` (18 markets) at Cronos block 97,651,394; per-market state (`getCash/totalBorrows/totalReserves/exchangeRateStored/borrowCaps/supplyCaps/markets()`); gates via `eth_call` with `from = market`; oracle mapping via `TectonicOracleAdapter.tTokenToOracle` + `latestRoundData`; borrower enumeration via Tectonic's official subgraph (`graph-v2.cronoslabs.com/subgraphs/name/tectonic/tectonic-main`, indexed to block 97,652,543); shortfall via `getAccountLiquidity` over all 6,530 borrower accounts; extractable via on-chain `getAccountSnapshot` + oracle-vs-real prices; fork PoC in Foundry.

**Sources:** Cronos post-mortem (2026-09-08) and coverage (CoinDesk, Crypto.news, CryptoTimes, DeFiNotebook, Satosh.ie); YFarmX forensic post-mortem; SigIntZero Tectonic analysis; DefiLlama prices/TVL; RedStone founder statement (oracle reported the pool price; missing borrow caps).

**Files:** `analysis/` (dump_state.py + state-97651394.json; subgraph_query.py + subgraph_borrowers.json; shortfall_scan.py + shortfall_accounts.json; extract_profit.py + extractable_liquidations.json; oracle_map.py + oracle_map.json; market_table.py + market_table.json; contracts_full.txt, chunk-_app JS registry, tcro.hex, pool/vault/tcm disassembly); `poc/` (Foundry, 6 tests); `ci/` (run.sh + heavy_scan.py); `ci-out/` + `ci-artifacts/` (CI results); `ci-log.txt`.

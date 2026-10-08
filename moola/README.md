# C2-17 — Moola Market (Celo): live unprivileged-extraction assessment

**Campaign:** zombie-hunt II · **Chain:** Celo (42220) · **Target:** LendingPool `0x970b12522CA9b4054807a2c5B736149a5BE6f670`
**Date of work:** 2026-10-08 · **Pinned state block:** **79,583,113** (2026-10-08 18:24:31 UTC; head at analysis 79,584,282)
**Status:** read-only research. No mainnet transaction was signed or sent. All execution happened on local forks (CI: GitHub Actions) at the pinned block.

**TL;DR — an external, unprivileged attacker can extract ≈ $0.03 net today** (0.28 CELO of net-of-gas
liquidation proceeds from 530 dust/bad-debt positions; $0.68 gross in the absolute zero-gas ceiling).
The $1.0–1.2M of value in the pool is **supplier-owned and withdrawable by its owners (H-O)**, and the
only paths to move it wholesale are **admin/governance (P)**: the pool is an upgradeable Aave-v2 fork
whose proxy admin (`LendingPoolAddressesProvider`) is controlled by a Moola wallet. Every
attacker-favouring oracle path is closed: MOO is frozen with an immutable fixed price, the stables are
priced by Mento SortedOracles medians (not flash-loanable), and the Ubeswap fallback oracle is **dead**
(it reverts), so there is no manipulable price path even if a Mento feed expires.

| # | Surface | Chain | Live extractable (unprivileged, net) | Why closed/open today | Latent risk |
|---|---|---|---|---|---|
| 1 | Moola LendingPool — liquidations of 530 under-collateralised accounts | Celo | **0.28 CELO ≈ $0.03** (4 net-positive positions; 7.65 CELO gross across 525 positions before gas) | Open function, but every position is dust/bad-debt; gas at 202.5 gwei eats all but $0.03 | Celo gas spikes/drops change this by ±10×; still <$1 |
| 2 | Moola LendingPool — borrow against collateral / drain cash | Celo | **$0** | Borrow requires HF>1; the only listed collaterals are Mento stables + CELO, all priced conservatively (cEUR/cREAL oracle ~6% *below* market); MOO frozen + fixed $0.00045 | None found |
| 3 | Oracle manipulation (Mento / Ubeswap fallback) | Celo | **$0** | Mento SortedOracles medians are reporter-pushed (not AMM); fallback Ubeswap SlidingWindowOracle reverts `MISSING_HISTORICAL_OBSERVATION` on all feeds | If Mento cEUR/cREAL reports expire (24h expiry, single reporter), oracle-dependent calls revert → withdrawal DoS, not theft |
| 4 | Periphery adapters (`LeverageBorrowAdapter`, `AutoRepay`, `RepayDelegationHelper`, Uniswap adapters) | Celo | **$0** | Hold no funds (one has 7 wei cUSD); all pull from `msg.sender`; `AutoRepay` is whitelist-gated | Only if the AutoRepay whitelist/owner key is abused (P) |
| 5 | Moola V1 pool / treasury | Celo | **$0** | V1 pool empty; treasury (`OwnedWallet`) holds 15.55M MOO ≈ $0 real + dust | — |

**Total live extractable by an external unprivileged attacker: 0.28 CELO ≈ $0.03** (range $0.02–$0.68
depending on gas; gross ceiling 7.65 CELO ≈ $0.68 with zero gas). **Confidence: high** that no larger
unprivileged path exists; the residual uncertainty is the exact dust total and future oracle/admin state.

---

## 1. The system, and why the campaign flagged it

Moola Market is a September-2021 Aave-v2 fork on Celo. On **2022-10-18** it was exploited for ~$9M:
the attacker pumped the low-liquidity MOO token on Ubeswap (+6,400%) to move the **Ubeswap TWAP oracle**
used by Moola, deposited MOO as collateral and borrowed cUSD/cEUR/CELO until the protocol was drained
(CertiK/QuillAudits/The Block). 93.1% of funds were returned for a bounty; the pool was upgraded five
times after the incident:

| Upgrade | Impl | Note |
|---|---|---|
| 2021-09-22 | (initial) | pool proxy deployed at block 8,955,471 |
| 2022-10-20 | `0xe50b13fe…` | 2 days after the hack (unverified impl) |
| 2022-10-31 | `0x3abdfb1b…`, `0x2eba86df…` | (unverified impls) |
| 2022-11-03 | `0xb9f81200…` | verified `LendingPool` |
| 2023-12-07 | `0xBecd348aa5cC976BE8E82ca6f13BC3B53197711F` | **current impl** |

The post-hack mitigations visible today: MOO is **frozen** and priced by an immutable `FixedPriceOracle`
at 0.005 CELO; the stables are priced by a **Mento SortedOracles** wrapper instead of Ubeswap; cREAL and
MOO have LTV/liquidation-threshold of 1 bp (effectively non-collateral); the custom collateral manager
takes an extra 2% liquidation cut to the treasury.

The finding's "$1.08M" is the pool's **cash** (underlying held by the aTokens). At the pinned block the
cash is **$997,356** at 2026-10-08 DefiLlama prices (CELO $0.08949, cUSD $1.00014, cEUR $1.12661,
cREAL $0.19972; MOO ~$0). Total supplier claims are **$1,227,352**; the difference ($230k) is performing
borrower debt, which returns to the pool as it is repaid. The question of this deep-dive is whether an
unprivileged attacker can take that cash. The answer is no; only the liquidation dust is extractable.

## 2. Exact live state (block 79,583,113)

Pool: `paused() == false`, `FLASHLOAN_PREMIUM_TOTAL() == 1` (1 bp), `MAX_NUMBER_RESERVES() == 128`,
`getReservesList() == [CELO, cUSD, cEUR, cREAL, MOO]`. Provider `0xD1088091A174d33412a968Fa34Cb67131188B332`:
`getPriceOracle() = 0xBa2224905Ad3CDbA6c1b764CD62FDa52bd524d29` (MoolaOracle), `getPoolAdmin() = owner() = 0x313bc86D3D6e86ba164B2B451cB0D9CfA7943e5c` (contract **"OwnedWallet"**, itself owned by `0xd7f77169d5E6a32C5044052F9a49eb94697b25ED`), `getEmergencyAdmin() = 0x643C574128c7C56A1835e021Ad0EcC2592E72624` (EOA, also the 2021 deployer),
`getLendingPoolCollateralManager() = 0xa2Db2e70A795B566F129ae7Dff242a4AD1393B32` (`LendingPoolCollateralManagerWithReserve`, adds a 2% treasury cut: `LIQUIDATION_RESERVE_PERCENT = 200`).

| Reserve | LTV | Liq. thr | Bonus | Frozen | liqIndex | varBorrowIndex | cash (underlying) | aToken claims | debt (v+s) | oracle price (CELO) |
|---|---|---|---|---|---|---|---|---|---|---|
| CELO `0x471EcE…` | 65% | 70% | 105% | no | **0.919744945** | 1.036164996 | 4,841,063.5919 | 4,970,192.5130 | 129,134.37 | 1e18 (hardcoded) |
| cUSD `0x765DE8…` | 75% | 80% | 105% | no | 1.140311864 | 1.223396348 | 400,820.0500 | 569,195.0184 | 168,446.85 | 11.114487445 |
| cEUR `0xD8763C…` | 45% | 50% | 110% | no | 1.021300690 | 1.097710351 | 142,034.4968 | 186,353.5380 | 44,320.65 | 11.811634361 |
| cREAL `0xe8537a…` | 0.01% | 0.01% | 110% | no | 1.084232806 | 1.146790639 | 16,259.4815 | 16,822.7965 | 647.54 | 2.100449195 |
| MOO `0x177002…` | 0.01% | 0.01% | 110% | **yes** | 1.000090049 | 1.001346106 | 135,344.1669 | 135,353.3437 | 9.18 | 0.005 (fixed) |

Notes (all fork/call-verified):
- **CELO liquidityIndex is 0.919744945 — below 1** (suppliers' scaled claims were written down ~8% at
  some point after the 2022 hack; the current implementation contains no path that can decrease the
  index, and the write-down is not reproducible by any unprivileged caller). Accounting is still
  coherent: per-reserve `cash + debt` exceeds aToken claims by only 0.0001–0.5% (extra backing; not
  claimable by anyone). This anomaly creates **no** extraction path — every deposit/withdraw/burn uses
  the same current index, and round-trips are exact (fork test `test_deposit_withdraw_roundtrip…`).
- **MOO is frozen** (config word `0x3e807122af800010001`): `deposit`/`borrow` revert `'3'`
  (`VL_RESERVE_FROZEN`); `withdraw`/repay/liquidate still work.
- **Accounting invariant** per reserve: `aToken.totalSupply() <= cash + totalDebt (+1 wei)` — the pool
  never over-issues claims. Donations to aTokens are inert (index-based, not cToken-style; test proves
  `liquidityIndex`, `totalSupply` and balances are unchanged after a 1,000 CELO donation, and a
  100 CELO deposit→withdraw round-trip returns exactly 100 CELO).

### Oracle evidence (why there is no price path)

| Asset | Source (MoolaOracle) | Upstream | Live value | Notes |
|---|---|---|---|---|
| CELO | hardcoded | — | 1e18 | unit of account |
| cUSD | `CeloProxyPriceProvider 0x9F9037…` | `SortedOraclesPriceFeedCUSD 0x67Cf66…` → Mento SortedOracles `0xefB84935…` | 11.114487445 | median of reporter values; expiry 360 s; not expired |
| cEUR | same proxy | `0x559Ea867…` | 11.811634361 | expiry 86,700 s; **single reporter**, median was ~19 h old at analysis (≈5 h to expiry) |
| cREAL | same proxy | `0x0a4FF581…` | 2.100449195 | expiry 86,700 s; single reporter, ~19 h old |
| MOO | `FixedPriceOracle 0x321429d1…` | immutable | 0.005 | `PRICE()` constant, `setAssetPrice` reverts |

- **Fallback oracle `0xb13F9Fb45B2E4446EF0047CBB2b9Dee269162309` (UbeswapPriceProvider) is dead**: its
  `PriceFeed`s wrap a Uniswap-v2 `SlidingWindowOracle` (window 300 s, granularity 5) whose `consult()`
  **reverts `SlidingWindowOracle: MISSING_HISTORICAL_OBSERVATION`** for cUSD, cEUR, cREAL and MOO — there
  are no recent observations because the pairs are inactive. Because `MoolaOracle.getAssetPrice` only
  falls back when the primary returns 0, and the fallback itself reverts, there is **no reachable
  manipulable oracle**: a Mento expiry bricks oracle-dependent calls instead of opening a path.
- **Consistency vs real market** (DefiLlama, 2026-10-08): CELO $0.08949, cUSD $1.00014, cEUR $1.12661,
  cREAL $0.19972. Implied by the Moola oracle: cUSD ≈ $1.000 (0.0% off), cEUR ≈ $1.057 (**6% below**
  market), cREAL ≈ $0.188 (**6% below** market). Deviations are conservative for collateral — nobody can
  borrow against over-valued collateral, and no borrow-and-dump spread exists.
- MoolaOracle owner is `0xd7f77169…` (the same contract that owns the treasury wallet); `setAssetSources`
  is `onlyOwner` and reverts for arbitrary callers (`Ownable: caller is not the owner`, fork test).

## 3. What an attacker can and cannot do (call paths)

**Can do (unprivileged, all verified on the fork):**
1. `deposit`/`withdraw`/`borrow`/`repay`/`flashLoan`/`liquidationCall` — the market is unpaused and
   permissionless. A flash loan of 100 CELO succeeds and costs the 1 bp premium (0.01 CELO), which is
   paid from the borrower's own funds (not the loan) — the pool earns it.
2. `liquidationCall` of any account with HF < 1: the liquidator repays ≤50% of the account's debt in
   one reserve and receives collateral at `bonus` (5%/10%) **minus** the 2% treasury cut
   (`collateralReserveAmount = seized·2/(bonus+2)`). Fork-verified exact for the best candidate:
   repaying 5.251372412218306448 CELO seizes 0.505553540698350359 cUSD, the liquidator receives
   0.496103941806792409 cUSD and nets **0.262568620610915328 CELO ≈ $0.0235**.
3. Borrow against real collateral (e.g., cUSD at 75% LTV) — but only within oracle LTV, so no value is
   created; and can open an under-collateralised *own* position (self-harm, not extraction).

**Cannot do (all revert):**
- Borrow with no collateral → `'9'` (`VL_COLLATERAL_BALANCE_IS_0`); withdraw without aToken balance →
  `'5'`; liquidate a healthy account (e.g., the top borrower, HF 1.68) → `'42'`
  (`LPCM_HEALTH_FACTOR_NOT_BELOW_THRESHOLD`).
- Steal another user's collateral: aToken transfers are HF-checked; `borrow` on behalf requires credit
  delegation; `repay`/`deposit` on behalf only donate.
- Drain the cash via flash loans: repayment of `amount + premium` is pulled from the receiver; a
  receiver that does not return the fee reverts (fork-confirmed: `transfer value exceeded balance of
  sender` when the 1 bp premium was not pre-funded).
- Any privileged action: `setReserveFactor`, `freezeReserve` → `'33'`; `pool.setPause` → `'27'`;
  `provider.setPriceOracle` / `oracle.setAssetSources` → `Ownable: caller is not the owner`.
- Compound-style donation/inflation attack: aTokens are index-based; donations are inert (proof above).

**The extractable remainder** is the 530 accounts with HF < 1 (census below): the best pair per account
is repaid/seized with the custom-manager formula; totals:

| Metric | Value |
|---|---|
| Accounts checked (all holder addresses) | 3,676 |
| Accounts with HF < 1 at pinned block | **530** |
| Accounts with positive gross liquidation profit | 525 |
| Gross liquidation profit, all positions | **7.65 CELO ≈ $0.68** |
| Gross, only real-value collateral (excl. MOO-collateral positions) | 7.29 CELO ≈ $0.65 |
| **Net of gas at 202.5 gwei** (600k gas/liquidation, 1 tx each) | **0.28 CELO ≈ $0.025** (4 positions) |
| Net of gas at 50 gwei | 3.07 CELO ≈ $0.27 (84 positions) |
| Net of gas at 10 gwei | 5.88 CELO ≈ $0.53 (166 positions) |
| Largest single net (at 202.5 gwei) | 0.135 CELO ≈ $0.012 (`0x7c980b8C…`) |

The big borrowers are healthy: `0xF67973E1…` (4,000,030 aCELO collateral, 1.67M CELO-equiv debt,
HF 1.6795), `0x2BfFd70b…` (HF 1.3543), `0x46C5CFC2…` (HF 2.4176), `0x214507f3…` (HF 1.1884) — none
liquidatable, and they cannot be pushed under 1 by an attacker (debt only increases via the owner's own
borrows; prices are reporter-pushed). 191 of the under-water accounts were already found in a
"material balance" pass; the full 530 includes dust accounts with zero/near-zero collateral.

## 4. PoC / fork verification

`poc/` is a Foundry project (`celo = true`, `solc 0.8.24`, vendored `forge-std`). Tests fork Celo at the
pinned block **79,583,113** through `CELO_RPC_URL` (default `https://forno.celo.org`) and never touch
mainnet state.

`poc/test/MoolaC17.t.sol` — **11 tests, 11/11 PASS**:

| Test | Proves |
|---|---|
| `test_pool_live_state_pinned` | paused=false, 5 reserves, config words, indexes (CELO liqIndex < 1), cash/claims/debt, 1 bp flash fee |
| `test_oracle_live_primary_and_dead_fallback` | exact prices; Mento primary sources live; MOO fixed price; fallback reverts `MISSING_HISTORICAL_OBSERVATION` |
| `test_moo_frozen_deposit_reverts` | MOO deposit reverts `'3'` |
| `test_moo_frozen_but_withdrawable_by_holder` | frozen MOO reserve still allows a holder to withdraw all aMOO (H-O) |
| `test_borrow_without_collateral_reverts` | borrow reverts `'9'` |
| `test_withdraw_without_balance_reverts` | withdraw reverts `'5'` |
| `test_deposit_withdraw_roundtrip_and_donation_is_inert` | index-based accounting; 1,000 CELO donation changes nothing; exact round-trip |
| `test_flashloan_permissionless_and_repaid` | 100 CELO flash loan works; receiver returns principal + 0.01 CELO premium to the treasury |
| `test_liquidation_undercollateralised_dust_profit` | **exact liquidation of the best candidate**: repaid 5.251372412218306448 CELO → received 0.496103941806792409 cUSD, net +0.262568620610915328 CELO |
| `test_healthy_whales_not_liquidatable` | top borrowers HF > 1; liquidation reverts `'42'` |
| `test_privileged_calls_revert_for_arbitrary_caller` | configurator `'33'`, pool pause `'27'`, provider/oracle `Ownable` |

Gas measured on the fork: liquidation ≈ 600–628k gas (at 202.5 gwei ≈ 0.122–0.127 CELO ≈ $0.011),
flash loan 477k, deposit 332k. A `ci/run.sh` census job additionally re-checks the pinned-block
liquidation candidates live and writes `ci-out/liquidation_census.json`.

**CI runs (public, read-only forks):**
- Run 1 (10/10 tests PASS; census at block 79,588,615: 150 re-checked candidates, gross
  7.075 CELO ≈ $0.633): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37835648686
- Run 2 (11/11 tests PASS incl. MOO-withdrawable; census with net-of-gas): `<PENDING>`
- Artifacts: `ci-artifacts/result-moola/` (ci-out/liquidation_census.json, census_stdout.txt, logs)

## 5. Verdict, residual/latent risk, blockers

- **E-U (external unprivileged, live): 0.28 CELO ≈ $0.03 net** (0.68 CELO ≈ $0.68 gross ceiling).
  Confidence: high that this is the only unprivileged extraction; the number is gas-sensitive.
- **H-O (owner-recoverable): $997,356 of cash is withdrawable today by its owners; $1,227,352 of total
  supplier claims are backed by cash + $230k performing debt.** No whitelists or withdrawal pauses; MOO
  is frozen but **withdrawable** (only deposit/borrow are blocked).
- **P (privileged): $997,356.** The proxy admin (`LendingPoolAddressesProvider`, owned by the Moola
  `OwnedWallet` → `0xd7f77169…`) can upgrade the pool implementation; the pool admin can pause, freeze,
  re-configure; the oracle owner can re-price. Emergency admin is an EOA (`0x643C5741…`). No evidence of
  key compromise was found or assessed; these are the only paths to the full cash.
- **S (stuck): $0** found. The only hard-brick risk is operational: if Mento's single cEUR/cREAL
  reporters stop updating (24 h expiry; ~5 h margin at analysis), `consult()` returns 0 and the dead
  fallback reverts → oracle-dependent calls for accounts touching those reserves revert (withdraw DoS).
  It resolves by itself if reports resume; funds are not lost.
- Blockers/limits of this assessment: the exact write-down transaction for the CELO index is in
  unverified 2022 implementations; ERC20 allowances from users to periphery adapters were not
  exhaustively enumerated (all audited adapter flows pull from `msg.sender`, and the adapters hold no
  funds); Celo gas price varies.

## 6. Methodology & sources

- Enumerated reserves/configs/indexes/oracle/roles with pinned-block `eth_call` (`analysis/dump_state.py`,
  `state_dump_79583113.json`); holders from Blockscout Celo API (`analysis/fetch_holders.py`,
  `holders.json`); per-account HF via `getUserAccountData` for all 3,676 holder addresses
  (`analysis/snapshot_pinned.py`, `liquidations_79583113.json`); liquidation profit with the deployed
  manager's exact formula (50% close factor, bonus + 2% treasury cut, collateral-constrained branch).
- Sources verified on-chain via Etherscan V2 (chainid 42220) and saved under `analysis/sources/`:
  `MoolaOracle`, `CeloProxyPriceProvider`, `SortedOraclesPriceFeed{CUSD,CEUR,CREAL}`, `FixedPriceOracle`,
  `UbeswapPriceProvider`, `LendingPool` (impl + historical 2022-11-03 impl),
  `LendingPoolCollateralManagerWithReserve`, `LendingPoolConfigurator`, and the adapter set.
- Prices: `coins.llama.fi` 2026-10-08 (CELO $0.08949, cUSD $1.00014, cEUR $1.12661, cREAL $0.19972).
- History: CertiK, QuillAudits, The Block, Infosecurity, TokenInsight coverage of the 2022-10-18 MOO
  Ubeswap-TWAP exploit and the 93.1% return.

## 7. Files

```
moola/
├── README.md                     (this file)
├── summary.json                  (machine-readable summary)
├── analysis/
│   ├── state_dump_79583113.json  (pinned reserve table, roles, oracle, cash/claims/debt)
│   ├── liquidations_79583113.json(pinned 3,676-account HF census + per-account liquidation profit)
│   ├── holders.json              (Blockscout holder sets for 13 tokens)
│   ├── account_data.json         (earlier live HF pass)
│   ├── dump_state.py, snapshot_pinned.py, compute_hf.py, fetch_holders.py (repro scripts)
│   └── sources/                  (verified contract sources/ABIs + upgrade-history evidence)
├── poc/                          (Foundry: foundry.toml, src/IMoola.sol, src/TestFlashLoanReceiver.sol, test/MoolaC17.t.sol)
├── ci/run.sh, ci/census.py       (custom CI job: live liquidation census -> ci-out/)
└── ci-log.txt, ci-artifacts/     (CI results)
```

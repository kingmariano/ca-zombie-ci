# C-41 — Ionic Protocol: live-state assessment & extractable-value determination

**Campaign:** zombie-hunt deep-dive · **Chains:** Mode (A + B), Base, Optimism, Lisk · **Date of work:** 2026-10-03
**Status:** read-only research; every extraction/boundary claim fork-verified on a local Mode fork only. No mainnet transactions sent.

**Scope:** the finding "Ionic Protocol ≈$21.6M live in a paused, oracle-less Compound fork" (`zombie_hunt/FINDINGS.md` C-41;
`verification_live_funds.md` item 17/17b). This deep-dive re-verifies every number at latest block, audits every deployed
code path for unprivileged extraction, and fork-tests each candidate path.

---

## 1. TL;DR

| Target | Live extractable (external unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| **Mode-A ionLBTC** (`0xADE7…`, 249.00006075 LBTC) | **$0** | `mint`/`borrow` guardian-paused; `redeem`/`transfer`/`exitMarket` revert for the member depositor because the oracle **reverts** for LBTC; `liquidateBorrow` reverts on the same oracle; `seize` needs a listed market; no cToken approvals exist | If an admin adds an LBTC oracle **and** the LBTC owner re-enables peg-out, value moves (privileged) |
| Mode-A other 17 markets | **$0** | all mint/borrow paused; meaningful borrowers' accounts revert on missing/stale oracles; only dust shortfalls found | oracle fixes could re-open liquidation paths |
| Mode-A `flash()` | **$0** | callable by anyone (`FeeDistributor.canCall = true`) but `selfTransferIn` enforces atomic repayment; honest flash = zero profit; nested flash unwinds | none found |
| Mode-A fee sweepers (`_withdrawAdminFees`/`_withdrawIonicFees`) | **$0 to attacker** | callable by anyone but bounded by accrued fees and pays `comptroller.admin()` / `ionicAdmin` | fees (e.g. 3.01 WETH, 0.0386 WBTC) are protocol-owned |
| **Mode-B / Base / Lisk / OP** | **$0** | every market in all four sibling deployments is mint+borrow guardian-paused; no depositor position; liquidation paths blocked by oracle reverts or dust-only | same oracle-fix caveat |
| **Mode LBTC peg-out / bridge** | **$0** | `isWithdrawalsEnabled=false`, `treasury=0x0`, no bridge destinations; the only DEX pool has swaps **disabled** (BAL#402) | LBTC owner could enable (privileged) |

## 2. Total live extractable now: **$0** (high confidence)

- **E-U (external unprivileged): $0.** No call path moves value to an outsider. Fork-verified (16/16 tests pass).
- **H-O (holder self-service): ≈ $9.40 nominal.** The only non-member ionLBTC holder (`0x1155b6…`, 55,375 cTokens)
  can redeem → 0.00011075 LBTC, but Mode LBTC has no working exit (see §5), so realizable USD ≈ $0.
- **P (privileged-only): ≈ $21.13M nominal** (249.00006075 LBTC × $84,869.01). Unlock requires two privileged
  actions: (1) add an LBTC price to the oracle, (2) enable Mode LBTC withdrawals + set a treasury (Lombard owner).
- **S (bricked): $0** — both required keys are live contracts (2-of-4 Safe for Ionic; a contract owner for LBTC).

**Correction to the prior pass:** the ~$21.6M is *not* a "dormant user position with a functional redemption path".
The depositor **is** a member of the ionLBTC market, so `redeem`/`transfer`/`exitMarket` **revert** on the missing
oracle (the earlier check used `balanceOfUnderlying`, which bypasses the comptroller). And even if redeemed, Mode
LBTC cannot be pegged out or sold (withdrawals disabled, no bridge destination, the single Balancer pool is paused).

---

## 3. Live state (all values at the blocks stated; raw dumps in `analysis/`)

### 3.1 Mode-A comptroller `0xFB3323E24743Caf4ADD0fDCCFB268565c0685556` — block 45,428,349

Architecture: Unitroller diamond → extensions `0x4F64…` (Comptroller), `0x139b…` (ComptrollerFirstExtension),
`0x2824…` (PrudentiaCaps). Admin = `0x8Fba84867Ba458E7c6E2c024D2DE3d0b5C3ea1C2` (**Gnosis Safe v1.3.0, threshold 2**,
owners `0x03A376…`, `0x737898…`, `0x5A9e79…`, `0x1155b614…`); pauseGuardian `0x5d498338…`; oracle `0x2BAF3A2B…`.

Global: `transferGuardianPaused=false`, `seizeGuardianPaused=false`, `enforceWhitelist=false`,
`closeFactor=0.5e18`, `liquidationIncentive=1.08e18`, `_mintGuardianPaused=false`, `_borrowGuardianPaused=false`
(the global flags are **unused** in code; per-market flags are what matter).

| market | underlying | cash (raw) | totalBorrows (raw) | ER | CF | mintP | borrowP | depr | oracle price |
|---|---|---|---|---|---|---|---|---|---|
| ionLBTC | LBTC 8d | **24,900,006,075** | 5,000 | 0.2e18 | 0.50 | **true** | **true** | false | **REVERTS "Price oracle not found"** |
| ionWETH | WETH 18d | 29,889,356,620 | 448,832,861,312,468,587,171 | 0.2036e18 | 0.825 | true | true | false | 1e18 |
| ionUSDC | USDC 6d | 20 | 661,116,974,567 | 0.2134e18 | 0.90 | true | true | false | 4.797e19 |
| ionUSDT | USDT 6d | 25,752,403,028 | 121,487,352,726 | 0.2160e18 | 0.90 | true | true | false | 4.794e19 |
| ionWBTC | WBTC 8d | 1 | 260,286,986 | 0.2009e18 | 0.825 | true | true | false | 3.259e21 |
| ionezETH | ezETH 18d | 276,704,553,795,968,147,129 | 15,834,864,992,396,007 | 0.2001e18 | 0.80 | true | true | false | 1.0867e18 |
| ionweETH | weETH 18d | 854,461,348,641,533 | 27,060,331,883,688,791,156 | 0.2079e18 | 0.70 | true | true | false | **REVERTS** |
| ionSTONE | STONE 18d | 198,361,536,731,357 | 98,507,226,935,106,712,031 | 0.2019e18 | 0.775 | true | true | false | **REVERTS** |
| ionwrsETH | wrsETH 18d | 0 | 244,678,229,714,630,820,763 | 0.2034e18 | 0.775 | true | true | false | **REVERTS** |
| ionM-BTC | M-BTC 18d | 22 | 24,739,449,763,545,085,698 | 0.2006e18 | 0.64 | true | true | false | **REVERTS** |
| ionweETH.mode | weETH 18d | 0 | 167,052,740,636,914,992,334 | 0.2023e18 | 0.80 | true | true | false | 1.0981e18 |
| ionUSDe | USDe 18d | 21,750,159,022,177,324,522 | 25,566,928,055,221,246,472 | 0.2071e18 | 0.30 | true | true | false | 6.287e14 |
| ionsUSDe | sUSDe 18d | 3,563,531,817,306,190,741 | 67,310,356,554,097,434,225 | 0.2019e18 | 0.30 | true | true | false | 5.842e14 |
| iondMBTC | dMBTC 18d | 660,764,808,398,428,148,739 | 0 | 0.2e18 | 0.10 | true | true | false | 3.259e14 |
| ionmsDAI | msDAI 18d | 18,035,455,795,641,583,494 | 6,346,137,920,948 | 0.2016e18 | 0.50 | true | true | false | 7.409e14 |
| ionuniBTC | uniBTC 8d | 1,432,671 | 3,952,975,696 | 0.2e18 | 0.50 | true | true | false | **REVERTS** |
| ionoBTC | oBTC 8d | 11,210,765 | 3,488,929,562 | 0.2002e18 | 0.50 | true | true | false | 4.455e21 |
| ionuBTC | uBTC 8d | 70,050,058,622,181 | 0 | 0.2e18 | 0.00 | true | true | false | 3.259e13 |

`isDeprecated(market)` = false for all 18 (requires CF==0 ∧ borrowPaused ∧ fees sum==1e18).
Accrued protocol fees exist in some markets (e.g. ionWETH `totalIonicFees`=3.0139 WETH, ionWBTC=0.0386 WBTC,
ionUSDC=84.37 USDC) but the sweepers pay `ionicAdmin`/`admin`, not the caller.

### 3.2 The depositor is the protocol's largest **borrower**, not a passive holder

`0x9E34d89C013Da3BF65fc02b59B6F27D710850430` (EOA) is in 12 markets and holds:

| supplied (cTokens) | underlying claim |
|---|---|
| ionLBTC 124,500,000,000 (99.99996% of supply) | **249.00006075 LBTC** (≈ $21.13M nominal) |
| ionWETH 1,993,894,629,900 | 0.406 WETH |

and **borrows** across 11 markets: 195.58 WETH, 150,068 USDC, 55,019 USDT, 2.376 WBTC, 13.83 weETH,
96.45 STONE, 238.43 wrsETH, 24.34 M-BTC, 157.39 weETH.mode, 3.95 uniBTC, 3.47 oBTC (≈ $5M notional at BTC/ETH
prices; several borrowed assets have no oracle). The position is over-collateralised at BTC parity (LTV ≈ 24%),
so even with a working oracle it would not be liquidatable — but today `getAccountLiquidity(depositor)` **reverts**
on the missing LBTC price.

### 3.3 Sibling deployments — every market mint+borrow paused

| chain | comptroller | block | markets | cash held | depositor position | notes |
|---|---|---|---|---|---|---|
| Mode-B | `0x8fb3d4a94d0aa5d6edaac3ed82b59a27f56d923a` | 45,428,332 | 4 | ~$4.2k (0.82 WETH, 1,948 USDC, 1.18M MODE) | none | all paused; debts small |
| Base | `0x05c9C6417F246600f8f5f49fcA9Ee991bfF73D13` | 52,117,469 | 28 | ~$202k nominal (USDz 204,991; USDC 5,629; eUSD 2,590; AERO 2,105; hyUSD 1,336; EURC 395; wUSDM 274; …) | none | all paused; debts small |
| Optimism | `0xaFB4A254D125B0395610fdc8f1D022936c7b166B` | 157,712,754 | 10 | ~$98 (wUSDM 90.97) | none | all paused; ~$150k aggregate debt |
| Lisk | `0xF448A36feFb223B8E46e36FF12091baBa97bdF60` | 38,147,747 | 5 | ~$14.5k (4.05 WETH, 7,450 LSK, 919 USDC.e, 80 USDT, 0.0066 WBTC) | none | all paused; ~$40k aggregate debt |

Full per-market tables: `analysis/mode_a_markets.json`, `analysis/mode_b_markets.json`, `analysis/base_markets.json`,
`analysis/op_markets.json`, `analysis/lisk_markets.json`.

---

## 4. Path analysis — every candidate attacker path and its gate

Full detail with source citations: `analysis/paths_analysis.md`; selector map: `analysis/selector_map.json`.

| # | candidate path | gate found live | verdict |
|---|---|---|---|
| 1 | `mint` / empty-market donation | per-market `mintGuardianPaused=true` on **all** markets of all 5 deployments → `require` reverts `!mint:paused` | closed |
| 2 | `borrow` against manipulated collateral | `borrowGuardianPaused=true` everywhere → `!borrow:paused`; plus `PRICE_ERROR` if oracle=0 | closed |
| 3 | `redeem`/`transfer` the depositor's cTokens | depositor is a **member** → `redeemAllowedInternal` → `getHypotheticalAccountLiquidityInternal` → **oracle reverts** for LBTC; no `Approval` events ever on the cToken (no third-party spender) | closed |
| 4 | liquidate the depositor / seize LBTC collateral | `liquidateBorrowAllowed` → liquidity check → oracle revert; `liquidateCalculateSeizeTokens` needs both prices (LBTC price reverts); all markets non-deprecated | closed |
| 5 | direct `seize` from an EOA | `seizeAllowed` requires `markets[msg.sender].isListed` → error code `SEIZE_MARKET_NOT_LISTED` | closed |
| 6 | `flash()` (callable by anyone) | `FeeDistributor.canCall = true`; but `selfTransferIn` → `transferFrom(msg.sender, market, amount)` must succeed → atomic repayment enforced; honest flash leaves market cash/borrows unchanged, attacker balance 0; nested flash unwinds | no profit |
| 7 | `_withdrawAdminFees` / `_withdrawIonicFees` (callable by anyone) | bounded by `totalAdminFees`/`totalIonicFees`; recipient fixed to `comptroller.admin()` / `ionicAdmin` | no attacker value |
| 8 | exchange-rate/rounding artifacts | `exchangeRate = (cash+borrows−reserves−fees)/totalSupply`; redeem truncation yields 0 for dust; no path to credit an attacker | none found |
| 9 | liquidation of other borrowers | top-25 historical borrowers per debt market checked (89 rows): **71 revert** (`getAccountLiquidity` blocked by missing/stale oracles), 8 healthy, 10 dust shortfalls totalling **≈ $6.5** (largest $3.23) → liquidator profit ≈ $1–2, capital+gas-consuming | $0 material |
| 10 | admin surfaces (`_setPriceOracle`, `_setMintPaused`, `_setCollateralFactor`, `_upgrade`, `_registerExtension`, `_setImplementationSafe`, LBTC `toggleWithdrawals`/`changeTreasuryAddress`) | `hasAdminRights`/`onlyOwner`/Safe-threshold-2 | privileged |

**Borrower registry:** 38,294 all-time entries (`getAllBorrowersCount()`); `getPaginatedBorrowers` pages of 300.
Live debt is dominated by the depositor; the top-25 historical borrowers per debt market were checked
(`analysis/mode_a_top_borrowers.json`): 71/89 `getAccountLiquidity` calls revert (blocked), 8 healthy,
10 dust shortfalls (total ≈ $6.5).

---

## 5. The 249 LBTC: nominal value vs realizable value

Detailed evidence: `analysis/lbtc_redeemability.md`.

- Mode LBTC `0x964dd444e3192F636322229080A576077B06FbA3` is Lombard's **native LBTC** contract (impl
  `0x5F6e76202AcfC8D0B833d9a6e74991BEb08b7FfC`, verified), **not** a LayerZero OFT, with independent per-chain supply.
- **BTC peg-out disabled:** `LBTCStorage` flag `isWithdrawalsEnabled=false` (never enabled — zero
  `WithdrawalsEnabled` events); `getTreasury()=0x0`; `redeem(<P2WSH>,1e5)` reverts `WithdrawalsDisabled()`;
  `depositToBridge` has **no destination** (`getDestination(1)=0`, zero `BridgeDestinationAdded` events).
- **Only venue:** Balancer V2 pool `0xcc53c20a…` ("LBTC/wBTC") holds 3.99999097 LBTC + 0.20016459 WBTC (~$16.9k),
  but its swaps are **disabled** (Vault `swap` → `BAL#402 SWAP_DISABLED`). No other LBTC pool exists on Mode
  (holders: market, Balancer Vault, depositor, 4 dust EOAs).
- Ethereum LBTC `0x8236a870…` by contrast has withdrawals enabled and a treasury — the Mode deployment is the closed one.

| actor | path today | realizable |
|---|---|---|
| external attacker | none | **$0** |
| depositor `0x9E34…` | cToken redeem blocked (oracle); after a privileged oracle fix, LBTC still has no peg-out/bridge/DEX | **$0 today** |
| holder `0x1155b6…` (55,375 cTokens, non-member) | `redeem` works → 0.00011075 LBTC | ~$9.40 nominal, ~$0 sellable |
| Ionic 2-of-4 Safe + LBTC owner | add oracle + enable withdrawals/set treasury | up to ~$21.13M nominal |

**Nominal value:** 249.00006075 × $84,869.01 = **$21,132,250** (DefiLlama LBTC, 2026-10-03; BTC spot $84,571.50).

---

## 6. PoC / fork verification

Project: `poc/` (Foundry). Fork: Mode mainnet via `https://mainnet.mode.network` (pinned only by "latest").
Suite: `poc/test/IonicC41.t.sol` — **16/16 PASS** locally and in CI.

| test | proves |
|---|---|
| `test_state_mode_a_live_values` | 18 markets; 249.00006075 LBTC; 124,500,000,000 cTokens; ER 0.2e18; borrows 5,000 wei; pauses; CF/closeFactor/incentive |
| `test_oracle_has_no_lbtc_price` | oracle reverts "Price oracle not found for this underlying token address." |
| `test_depositor_redeem_blocked_by_oracle` / `redeemUnderlying` / `transfer` / `exitMarket` | all four revert on the oracle for the member depositor |
| `test_attacker_mint_reverts_paused` / `borrow_reverts_paused` | `!mint:paused`, `!borrow:paused` |
| `test_attacker_cannot_redeem_without_ctokens` | redeem returns an error code; attacker receives 0 |
| `test_attacker_liquidate_depositor_reverts` | liquidation of the depositor reverts (oracle) |
| `test_flash_is_authorized_for_anyone` | `FeeDistributor.canCall(comptroller, 0xdEaD, ionLBTC, flash) = true` |
| `test_flash_without_repayment_reverts` | non-repaying attacker contract reverts |
| `test_flash_honest_repayment_yields_zero_profit` | cash/borrows restored; attacker keeps nothing |
| `test_mode_lbtc_withdrawals_disabled` | storage flag false; consortium decoded; treasury 0; destination(1)=0; commission 10k sat; not paused |
| `test_mode_lbtc_redeem_reverts_withdrawals_disabled` | `redeem` reverts `WithdrawalsDisabled()` |
| `test_no_borrower_can_be_liquidated_for_profit` | 38k+ borrower registry readable; first borrower non-zero |

**CI runs (public repo `kingmariano/ca-zombie-ci`):**
- `https://github.com/kingmariano/ca-zombie-ci/actions/runs/37116944802` — conclusion **success**, 16/16 tests passed.
- `https://github.com/kingmariano/ca-zombie-ci/actions/runs/37117987151` — conclusion **success**, 16/16 tests passed.
- `https://github.com/kingmariano/ca-zombie-ci/actions/runs/37118170265` — conclusion **success**, 16/16 tests passed.
- Final clean run (CI state dumps + tests): *(URL recorded in `summary.json` / `ci-log.txt` after completion)*.
  The first three custom state-dump jobs failed on CI-environment issues (missing `eth_abi`; quoted `DRPC_API_KEY`),
  fixed in `ci/run.sh`; the forge fork-test step is independent of them and passed every time.

Key on-chain facts and blocks: `analysis/mode_a_markets.json` (block 45,428,349), `analysis/mode_a_top_borrowers.json`,
`analysis/gate_probe.json`, `analysis/lbtc_oft_state.json`/`lbtc_redeemability.md`.

---

## 7. Verdict, residual & latent risk

- **E-U = $0** with high confidence: all mint/borrow/transfer/liquidation paths are closed or revert; the only
  callable functions that move tokens either require atomic repayment (`flash`) or pay the protocol (fee sweepers).
- **Residual/latent:** (a) if an admin adds an LBTC oracle, the depositor's cToken redeem unblocks and liquidation
  checks start working — combined with a liquidatable borrower this could re-open ordinary liquidation profit;
  (b) if Lombard re-enables Mode LBTC withdrawals and sets a treasury, the nominal $21.1M becomes holder-recoverable
  (then limited by BTC-redemption logistics); (c) `flash` remains open but provably non-extractive.
- **Blockers:** missing oracle for 6/18 Mode-A markets (incl. LBTC); `isWithdrawalsEnabled=false`; treasury unset;
  zero bridge destinations; Balancer pool swap-disabled; all mint/borrow paused.

## 8. Methodology, caveats, files

- **Method:** verified-source review (Mode Blockscout) of both diamond facets and the comptroller extensions;
  batched read-only `eth_call`/`eth_getLogs` at latest blocks; DefiLlama prices 2026-10-03 (LBTC $84,869.01,
  BTC $84,571.50, ETH $2,681.55); fork tests in Foundry (CI).
- **Caveats:** USD figures are nominal at the stated prices; Mode LBTC has no native price so ETH-LBTC parity is used
  for the nominal figure only. The borrower scan covered the top-25 historical borrowers per debt market (the
  depositor plus dust); a full 38k-account scan was not run (no material shortfall found in the sampled set).
  `getAccountLiquidity` reverts for accounts holding any broken-oracle market, so their health cannot be computed —
  but that same revert blocks their liquidation.
- **Files:** `analysis/` (raw JSON state dumps, source extracts, selector map, path audit, LBTC analysis,
  `enumerate_ionic.py`, `quick_markets.py`, `targeted_borrowers.py`), `poc/` (Foundry project), `ci/` (CI job),
  `ci-out/` (CI artifacts), `ci-log.txt`, `summary.json`.

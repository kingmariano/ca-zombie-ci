# C2-16 — ApeSwap Lending (BSC): live extraction assessment

**Campaign:** zombie-hunt II · **Finding:** C2-16 · **Chain:** BNB Smart Chain (56) · **Date:** 2026-10-08
**Status:** read-only research; PoC fork-verified on CI only; **no mainnet transactions signed or sent**.
**Targets:** Unitroller (Comptroller proxy) `0xAD48B2C9DC6709a560018c678e918253a65DF86e` (impl `0xEaEe8D2EAb5BDE5AD05153dc375fa78fE5cA7d5e`, `ComptrollerV0_05`), 10 OToken markets, Registry/Ministry `0xAE933Da5860559080F47e594504CE5445D86f78a`, RainMaker `0x5CB93C0AdE6B7F2760Ec4389833B0cCcb5e4efDa`.
**Block of record:** 126,489,929–126,503,091 (2026-10-08).

---

## TL;DR

| Target | Live extractable (external unprivileged) | Why closed today | Latent risk |
|---|---|---|---|
| ApeSwap Lending (10 markets, $225.9k cash) | **$0.00** (high confidence). Gross liquidation dust ≤ ~$0.9; net of gas ≈ $0 | **All 10 markets are hard-paused for mint AND borrow** (deprecation pause, 2025-10-20 notice). Only repay/redeem/liquidate/transfer remain. The 87 shortfall accounts are dust (max single gross liquidation ≈ **$0.15**, fork-proven). Donation/exchange-rate inflation is unmonetizable with mint paused. Oracles are fresh Chainlink feeds (2-min-old) — not flash-manipulable | Admin resume (1 Timelock/Safe action set) + oBANANA collateral-cap lift re-opens a **~$226k drain with ~$0.10 of BANANA** (fork-proven). Ministry admin is a **single EOA** (key risk: arbitrary oracle → mass liquidation seize) |

**Total live extractable now (E-U): $0.00** — confidence **high**.
**H-O (suppliers self-redeem): ≈ $225,776** of cash (first-come-first-served) + $32,184 borrows that can return.
**P (privileged): ≈ $225,941** (unpause/oracle/caps/admin reserve powers); key-risk EOA noted.
**S (stuck today): ≈ $165** in the oBNBx market (dead Chainlink feed bricks 7 member accounts; admin-fixable).

---

## 1. What the protocol is and why it matters

ApeSwap Lending Network is a Compound-v2 fork built on Ola Finance ("LeN") technology (`ComptrollerV0_05`, `CErc20DelegateV0_05`), deployed on BSC and deprecated in 2025. The official notice (lending.apeswap.finance) states: *"The ability to deposit/borrow additional funds will be paused on Oct 20th 2025, and all users are kindly encouraged to pay off their loans and withdraw their funds."* The pause is live on-chain for all 10 markets (verified below).

The corpus flagged it as an "old Compound fork; own-token/thin-asset markets; donation class" with **$191,464 verified cash**. This deep-dive re-measured live state, audited every unprivileged value path and fork-tested the survivors.

## 2. Live market state (block ~126.49M; full table in `analysis/market_table.json`)

| market | cash (tok) | cash USD | borrows USD | claims USD | ER | CF | LF | LI | mint/borrow paused | oracle price | real price |
|---|---|---|---|---|---|---|---|---|---|---|---|
| oBANANA | 1,591,482.77 | $0.00¹ | $0.00 | $0.00 | 3.096e26 | 0.40 | 0.70 | 1.12 | true/true | 1e12 ($1e-6) | ~$1.0e-10² |
| oETH | 6.1395 | $14,964.73 | $556.26 | $15,517 | 2.079e26 | 0.70 | 0.75 | 1.10 | true/true | $2,442.61 | $2,437.44 |
| oBUSD | 34,946.63 | $34,873.21 | $5,046.97 | $39,883 | 4.762e26 | **0.00** | 0.75 | 1.10 | true/true | $1.0000 | $0.9979 |
| oUSDT | 11,378.98 | $11,371.27 | $12,645.83 | $22,568 | 2.948e26 | 0.70 | 0.75 | 1.10 | true/true | $0.99914 | $0.99932 |
| oCake | 6,127.18 | $12,949.46 | $351.22 | $13,280 | 2.655e26 | 0.40 | 0.50 | 1.12 | true/true | $2.11757 | $2.11344 |
| oUSDC | 31,778.55 | $31,767.80 | $3,893.46 | $32,795 | 3.088e26 | 0.70 | 0.75 | 1.10 | true/true | $0.99984 | $0.99966 |
| oBNB | 60.4505 | $44,086.76 | $6,223.66 | $50,234 | 2.246e26 | 0.70 | 0.75 | 1.10 | true/true | $726.92 | $729.30 |
| oBTCB | 0.92671 | $74,680.16 | $3,435.59 | $78,091 | 2.078e26 | 0.70 | 0.75 | 1.10 | true/true | $81,443.13 | $80,586.11 |
| oDOT | 980.0931 | $1,002.15 | $30.56 | $1,032 | 2.186e26 | 0.50 | 0.60 | 1.12 | true/true | $1.03676 | $1.02250 |
| oBNBx | 0.30563 | $246.10 | $0 | $246 | 2.000e26 | 0.60 | 0.60 | 1.12 | true/true | **REVERTS** | $805.23 |
| **Σ** | | **$225,941.64** | **$32,183.55** | **$253,647.35** | | | | | | |

¹ BANANA cash = 1.59M tokens; real market price ~$1.0e-10 (Coinbase/CMC, 2026-10-08) → ~$0.0002. The FixedPriceOracle instead values BANANA at $1e-6 — **~10,000× over the real market** — but with mint/borrow paused and the oBANANA active-collateral cap at 1 wei-USD this overvaluation is currently inert.
² Coinbase $0.0(9)8477; CMC ~$1.01e-10; BSC DEX pools (PCS `0x5C8A…`, ApeSwap `0xF65C…`) imply $1.3e-10 — both pools hold only ~$45–60 of BNB.

**Oracles.** 8 of 10 underlyings use `ChainlinkPriceOracle` `0x7c37BF8dBd4Ae90cdf45d382cEB1580c5d9300CC` with **no staleness check** (`latestRoundData().price` only). All feeds were **fresh** at read time (timestamps ≈ now − 2 min; `analysis/oracle_feeds.tsv`). BANANA uses `FixedPriceOracle` `0x660DC9a3…` (immutable: `require(existingPrice == 0)`, no setter path). BNBx's feed `0xc4429B53…` **reverts** on `latestRoundData()` → `getUnderlyingPrice` reverts for the whole market (see §5).

**Pauses.** `mintGuardianPaused` and `borrowGuardianPaused` are `true` for all 10 markets (read at block 126,489,929; both global legacy flags are false but unused by the fork's checks). Fork/eth_call: `mint` and `borrow` on every market revert `"paused"` (see PoC test 1).

## 3. The bug classes audited (exact terms)

The fork (verified source, `analysis/src/`) is Compound v2 with Ola additions: per-market `liquidationFactorMantissa`, `liquidationIncentiveMantissa`, `activeCollateralUSDCap`, a Ministry registry oracle, pool-wide reentrancy guard, and role-based governance (`OlaLenCaptain`). We audited:

1. **Empty-market donation / exchange-rate inflation.** `exchangeRateStored = (cash + borrows − reserves)/totalSupply`. A donation is value-neutral to the donor: it raises the exchange rate for all existing cToken holders 1:1 with the donated amount. The profitable "first-depositor inflation" variant requires a subsequent `mint` by a victim — **mint is paused on every market**, so no victim can mint and the attacker cannot mint a share of their own donation. `redeem` floors in the pool's favour; `redeemUnderlying` floors the cToken burn. **No extraction.**
2. **Own-token/thin-asset collateral manipulation.** oBANANA's oracle is 10,000× above the real BANANA price and oBANANA has $1.59M of nominal cash — the classic "borrow against over-valued own-token" drain. Blocked three ways: borrow paused; `activeCollateralUSDCap(oBANANA)=1` (any new activation reverts); BANANA is effectively valueless. **Latent only** (§6).
3. **Stale oracle.** No staleness check exists in the fork's Chainlink wrapper, but all feeds were updating (≤2 min) and match real prices within ~1%. BNBx's feed is dead → its market is bricked, not exploitable (price 0/revert blocks liquidations *and* redemptions for members).
4. **Redeem/borrow rounding.** Compound-standard truncations; no borrow path is open and redeem truncations accrue to the pool. No path.
5. **Liquidation paths.** Permissionless and NOT pausable in this fork (`seizeAllowed` pause setter was deliberately removed). We enumerated **all current cToken holders (1,194 addresses from GoldRush + full log reconstruction in CI)**, checked `getAccountLiquidityByLiquidationFactor` for every one, and found **87 accounts with shortfall** — all dust: total seizeable collateral **$14.68**, total gross bonus **$0.88** (stored values; post-accrual interest since last touch <1%). The largest single account (0x0e546d42…) yields **$0.15 gross** (fork-proven end-to-end).
6. **Admin reachability.** `admin` = `OlaLenCaptain` `0x7638B5A0…` (roles: admin → `TimelockController` `0x564bE05e…`; pausers/resumers/maintainers/security = Gnosis Safes). The Ministry's admin — which can `setOracleForAsset` **directly, bypassing the Safes** — is a **plain EOA `0x7c1d6e7C…`** (key risk, §6). All admin paths are P.

## 4. What an attacker can and cannot do (call paths)

| Path | Live? | Gating check (live value) |
|---|---|---|
| `mint` / `mint()` (CEther) | ❌ | `require(!mintGuardianPaused[cToken], "paused")` — true ×10 |
| `borrow` | ❌ | `require(!borrowGuardianPaused[cToken], "paused")` — true ×10 |
| `redeem` / `redeemUnderlying` | ✅ (own funds) | `redeemAllowedInternal`: only if caller is in that market does the oracle/liquidity check run |
| `repayBorrow` / `repayBorrowBehalf` | ✅ | `repayBorrowAllowed` (listed only) |
| `liquidateBorrow` | ✅ | shortfall > 0 by liquidation factor; close factor fixed 0.5; bonus 10–12%; **dust only** |
| `transfer` / `transferFrom` cTokens | ✅ | global `transferGuardianPaused=false`; members with dead-feed market revert (see §5) |
| `enterMarkets` / `exitMarket` | ✅/⚠️ | activation caps (oBANANA=1, oBNBx≈0) block new activation; no borrow to use it for |
| direct ERC-20 donation to a cToken | ✅ | raises ER; no monetization (mint paused) |
| `claimComp` on RainMaker | ✅ | `grantCompInternal(user)` pays **the holder**, not the caller; RainMaker holds only 482,614 BANANA (~$0.00005) |
| admin (`_setMintPaused(false)`, `_setBorrowPaused(false)`, `_setCustomOracle`, `_setActiveCollateralCaps`, `_setCollateralFactor`, `_reduceReserves`, `setOracleForAsset`) | P | `OlaLenCaptain` roles / Ministry admin EOA |

**Conclusion of the call-path audit:** the only unprivileged value-moving entry points that remain live are redeem (own funds), repay, transfer, and liquidation. Liquidation is the only one that could pay a *third party*, and its entire live surface is <$1 gross.

## 5. Negative results / bricked state (do not re-investigate)

* **oBNBx is bricked (S ≈ $165).** Its Chainlink feed `0xc4429B53…` reverts, so `getUnderlyingPriceForCToken(oBNBx)` reverts. Any account that has *entered* the oBNBx market (7 accounts, `activeCollateralCTokenUsage = 956,359,268` units = 0.19127 BNBx ≈ **$154.02**) is globally blocked from redeeming/exiting/transferring **any market they are a member of** — the liquidity calc iterates `accountAssets` and hits the dead oracle (fork-proven: member `redeem`/`transfer` revert). The `0x…dEaD` holder (0.013789 BNBx ≈ $11.10) is unreachable in practice. Non-members (`0xc333A03e…`, `0xc2F6EcCe…`) can still redeem ≈ $80.98 (H-O). The Ministry admin could repair it with `setOracleForAsset` (P-fix); the Comptroller's `_setCustomOracle` cannot be used because its sanity check reads the same dead Ministry price.
* **RainMaker** holds only BANANA (worthless); claims pay holders. Not a target.
* **`_reduceReserves` / reserve powers**: admin-only; reserves total ~$4,478 (not extractable by outsiders).
* **Donation into oBNBx/oBANANA**: no profit (mint paused; no third-party mint victims; oracle/cap blocks collateral use).
* **Interest accrual**: lazily checkpointed (oBANANA untouched ~10+ months); post-accrual changes to the dust liquidation numbers are <1% (borrow rates 4e-10–1.9e-9 per block; `analysis/market_table.json`).

## 6. Latent risk (what one state flip re-opens)

1. **Resume + cap lift → ~$226k drain (fork-proven).** `OlaLenCaptain._resumeAllBorrow()` (resumer Safe `0x7b26A27a…`) + `_setActiveCollateralCaps([oBANANA],[max])` (maintainer Safe/EOA) → attacker supplies ~$0.10 of BANANA (600B tokens at real price), which the FixedPriceOracle values at $600k, and borrows every market's cash: **> $150k measured in the fork test** (full ~$225.9k capacity). This is the "own-token overvaluation" drain the corpus flagged, currently fenced by two independent privileged switches.
2. **Ministry EOA key risk.** `0x7c1d6e7C7240f9218a71cf54C1908f1713093A32` is an EOA that is (a) Ministry admin — `setOracleForAsset` for any asset with no timelock/safe — and (b) an `OlaLenCaptain` maintainer. A compromised key can point an asset at a malicious oracle, force shortfalls, and liquidate/seize collateral cheaply (P-class exposure ≈ collateral at risk, up to ~$254k of claims). The other roles (pausers, resumer, security/oracles manager) are Safes; the Captain admin is a `TimelockController`.
3. **Stale feeds.** The fork ignores `updatedAt`; any future feed freeze silently freezes prices (as BNBx shows). Monitor.

## 7. PoC / fork verification

Foundry project `poc/` (fork-only; `BSC_RPC_URL`), CI job `ci/scan.py` (full log reconstruction + holder scan). Results:

| Test | Proves | Result |
|---|---|---|
| `test_pauseWall_allMarkets` | mint+borrow revert `"paused"` on all 10 markets | see ci-log |
| `test_redeemWorksForSupplier` | supplier redeem works (H-O) | see ci-log |
| `test_oBNBx_memberStuck_nonMemberRedeems` | dead-feed bricking (S) + non-member redeem (H-O) | see ci-log |
| `test_largestLiquidation_dust` | largest live liquidation end-to-end: repay $1.50 → seize $1.65 (profit $0.15 gross) | see ci-log |
| `test_fullScan_postAccrual` | post-accrual scan of all candidates: shortfall count, seizeable $, gross profit bound | see ci-log |
| `test_latentUnpauseDrain` | (admin-simulated) resume + cap lift → >$150k borrowed with ~$0.10 BANANA | see ci-log |

CI runs: **(pending — filled when the run completes)**. Scan outputs land in `ci-out/` (artifact) and `ci-log.txt`.

## 8. Verdict

* **E-U today: $0.00 (high confidence).** Every new-value path (mint, borrow) is hard-paused; the only third-party-paying path (liquidation) has a total live surface of <$1 gross across all 87 shortfall accounts, net ≈ $0 after BSC gas (~$0.07–0.1/tx). Donation/exchange-rate inflation has no monetization without mint; oracles are fresh and not flash-manipulable.
* **H-O ≈ $225,776** cash redeemable by suppliers (oBNBx members' $154 and the dead address's $11 are excluded as stuck), plus **$32,184** of borrows that can return to markets (dust bad debt ~$200).
* **P ≈ $225,941**: admin can resume/oracle/route; latent fork-proven drain >$150k. Key risk: single-EOA Ministry admin.
* **S ≈ $165** (oBNBx dead feed), admin-fixable.

**Blockers / caveats.** (1) Historical `eth_getLogs` coverage depends on the CI RPC's archive window; the vendored GoldRush holder snapshot is the fallback (address list may miss very recent transfers — cToken transfers are rare and state is static). (2) USD values use DefiLlama prices 2026-10-08 (BANANA from CMC/DEX). (3) Fork tests are CI-only; no mainnet transactions.

## 9. Methodology & sources

* On-chain reads via BSC public RPC (block 126,489,929–126,503,091): Comptroller/Unitroller, 10 OTokens, Ministry/Registry, ChainlinkPriceOracle, FixedPriceOracle, OlaLenCaptain, TimelockController, RainMaker — all addresses above; raw dumps in `analysis/`.
* Verified sources (Etherscan V2, chainid 56): `ComptrollerV0_05`, `CErc20DelegateV0_05`, `RegistryV1_1`, `Ministry`, `ChainlinkPriceOracle`, `FixedPriceOracle`, `OlaLenCaptain`, `SingleAssetDynamicRainMaker` (`analysis/src/`).
* Holder/participant enumeration: GoldRush `token_holders` (1,194 unique current holders) + full `Transfer`/`Borrow` log reconstruction in CI; liquidation scan via `getAccountLiquidityByLiquidationFactor` for every holder.
* Prices: DefiLlama `coins.llama.fi` (2026-10-08), Coinbase/CMC for BANANA; BSC DEX pool reserves read on-chain.
* Deprecation notice: `lending.apeswap.finance` (Oct-20-2025 pause of deposits/borrows).
* Files: `analysis/market_table.{json,md}`, `analysis/markets.tsv`, `analysis/cash.tsv`, `analysis/oracles.tsv`, `analysis/oracle_feeds.tsv`, `analysis/liquidity_scan.json`, `analysis/shortfall_detail.json`, `analysis/obnbx_members_detail.json`, `analysis/profit_calc.py`; `poc/`; `ci/`.

# Omm (ICON) — Phase-2 deep dive: live unprivileged extractability

**Date:** 2026-10-13 · **Chain:** ICON mainnet (`nid 0x1`, live block ≈ 119,469,355) · **Target:** Omm money market (Aave-v1-style fork) + Omm 2.0 sICX staking
**Status:** read-only; no transactions sent; no secrets; all state reads are public-RPC `icx_call`/`icx_getBalance` at recorded blocks. Source-audit + live-gate proof (no ICON fork tooling exists — see §7).

---

## 1. TL;DR

| Target | Live value in custody | Extractable by external unprivileged attacker (E-U) | Why closed/open | Latent risk |
|---|---|---|---|---|
| Omm money market — core `cxfb312bbd…ea94` | **$150,414.55** (94,760.06 USDS + 55,654.49 IUSDC @ contract oracle) | **$0** | **All 6 reserves `isFreezed=1`** → `deposit()`/`borrow()` revert ("Reserve is frozen"); **`isLiquidationEnabled()=false`**; admin force-liquidation requires `_from == admin` EOA; every state-moving fn is owner/governance/contract-gated; the 2023-01-21 `redeem` exploit is fixed on-chain (post-fix ABI + source) | Owner EOA can upgrade/unfreeze (P). Oracle overvalues USDS ~436× / IUSDC ~10.5× vs DEX, but frozen reserves make it unusable. Realizable DEX value of the cash ≈ **$3.0K**, not $150K |
| Omm 2.0 staking / "Staked ICX Manager" `cx43e2eec…06e0` | **38,919,590.83 ICX** backing 27,271,515.80 sICX (≈ **$563K** @ ICX $0.014465 / **$474.8K** @ contract-oracle ICX $0.012198) + 1,802,379.10 ICX liquid | **$0** | All admin fns `onlyOwner` (`Context.getOwner()`, owner EOA); user paths are fair conversions (stake mints at `getTodayRate()`, unstake burns the caller's sICX and pays only the recorded receiver, `claimUnstakedICX` pays only the recorded receiver, `delegate` moves own votes). sICX mint/burn guarded to the staking SCORE | Owner/emergency-manager EOA keys (P). sICX is redeemable by holders (H-O) |
| Rewards `cx4f2d73…ef6f` | ~2.74M OMM (≈$400 notional; DEX-realizable ≪ that) | **$0** | `claimRewards` is `onlyLendingPool` and pays the user; `distribute()` is permissionless but mints OMM per schedule to the pool (no attacker gain); all config fns governance/owner | none material |
| FeeProvider `cx4f3c2e…b4fb` | 21.66 USDS + 89.62 IUSDC + 1.87 sICX + 5,869.5 OMM (≈$113 oracle / ~$9 DEX-realizable) | **$0** | `transferFund` onlyGovernance; `setLoanOriginationFeePercentage` onlyOwner | none material |

## 2. Total live extractable now

- **E-U (external unprivileged): $0.00 — confidence HIGH.**
- **H-O (holder-recoverable):** $150,414.55 money-market cash (oToken holders pro-rata; realizable ≈ $3.0K at DEX marginal) **plus** the Omm 2.0 staking custody (38,919,590.83 ICX backing sICX ≈ $563K market / $474.8K at the contract's own ICX oracle) — sICX-holder-recoverable, separate custody from the triaged money market.
- **P (privileged):** owner/admin EOAs retain upgrade + param + force-liquidation powers over both systems.
- **S (bricked):** $0 — redeem/repay/unstake/claim paths are all live and callable.

Live value vs triage: triage recorded $150,404.37 (cash-only, contract oracle). Live re-read: **$150,414.55** (+$10, price/index drift). Triage's "376d" staleness flag is confirmed and now explained: the money market was frozen in 2023 and retired; only withdrawals/repays remain.

## 3. Mechanism — why it is closed (exact terms)

Omm v1 is a Java-SCORE port of Aave v1 (`github.com/ommfinance/openmoneymarket-contracts`; deployed ABI matches post-2024 main, incl. the 2024 "liquidation by admin" code). The 2023-01-21 exploit ($1,891,477.80, "redeem logic flaw") was a **pre-fix** `LendingPoolImpl.redeem(Address _oToken,…)` that called an attacker-supplied contract and trusted its returned `reserve`/`amountToRedeem` — redeem without deposit. The **live** ABI is the fixed one: `redeem(Address _reserve, int _amount, bool _waitForUnstaking)` resolving the oToken via `LendingPoolCore.getReserveOTokenAddress()` (fix commits `23974eeb`, `009bd263`, PR #166; LendingPool last updated 2024-03-13, block 78,837,571).

Today every extraction class is gated:

| Call path | Gate (deployed source) | Live value |
|---|---|---|
| `LendingPool.deposit` / `tokenFallback{method:deposit}` | `reserveData.isActive` **and** `isFreezed` (`AbstractLendingPool.deposit`) | **`isFreezed=0x1` on all 6 reserves** → reverts |
| `LendingPool.borrow` | same freeze check + `isReserveBorrowingEnabled` + LTV/health checks (`LendingPoolImpl.borrow`) | frozen → reverts |
| `LendingPool.tokenFallback{method:liquidationCall}` | `AbstractLendingPool.liquidationCall` → `if (!isLiquidationEnabled()) revert` | **`isLiquidationEnabled()=false`** |
| `tokenFallback{method:liquidateUsers}` | `_from.equals(admin.get())` (`LendingPoolImpl.liquidateUsers`) | admin = EOA `hx2344c053…b0581` (P) |
| `LendingPool.transferToken` | `onlyOwnerOrElseThrow` (`Context.getOwner()`) | owner EOA (P) |
| `setLiquidationStatus`, `addAdmin`, `setBridgeFeeThreshold`, `setFeeSharingTxnLimit` | `onlyOwnerOrElseThrow` | owner EOA (P) |
| `LendingPoolCore.transferToUser` / `updateStateOn*` | `onlyLendingPool()` / `onlyLiquidationManager()` (caller == address from local AddressProvider map) | guarded |
| `LendingPoolCore.liquidateFee` | `onlyLiquidationManager()` | guarded |
| `LendingPoolCore.addReserveData` / `updateIsActive` / `updateIsFreezed` / `update*` | `onlyGovernance()` (caller == Governance SCORE `cx8190de91…4838`) | guarded |
| `PriceOracle.setOMMPool` | `checkOwner()` (`Context.getOwner()`) | owner (P) |
| `AddressManager.setAddresses` / `addReserveAddress` / `addAddress*` / `set*Addresses` | `checkOwner()` | owner (P) |
| `FeeProvider.transferFund` | `onlyOrElseThrow(GOVERNANCE)` | guarded |
| `Rewards.claimRewards` | `onlyOrElseThrow(LENDING_POOL)`; pays `_user` | own rewards only |
| `Rewards.distribute` | permissionless, but mints OMM per `RewardWeightController.precompute(day)` to the pool | no attacker gain |
| `OToken.mintOnDeposit` / `DToken.mintOnBorrow` | `onlyLendingPool` / `onlyLendingPoolCore` | guarded |
| `sICX.mint*` / `burnFrom` | `only(minter)` = staking SCORE (`IRC2Mintable`/`IRC2Burnable`) | guarded |
| `Staking.set*` / `toggleStakingOn` / `updatePreps` | `onlyOwner()` (`Checks.onlyOwner` → `Context.getOwner()`) | owner EOA `hx33908de1…fdc2` (P) |
| `Staking.stakeICX` / `unstake` / `claimUnstakedICX` | fair: mint at `getTodayRate()`; burn caller's sICX; pay only `receiverAddress` recorded at unstake | no theft path |
| `Staking.delegate` / `delegateForUser` | own/caller-scoped vote percentages only | no fund path |
| `DaoFund` withdraw | `onlyOrElseThrow(GOVERNANCE)` | guarded |

Chain-native gate proof: `icx_call` on any of these TX methods returns `SCOREError(-30009) E0009:AccessDenied` (RPC refuses non-readonly methods), and public ICON RPCs do not expose `debug_estimateStep` — therefore the deployed Java source (provenance-matched to the live ABI) + live flag reads + historical event logs are the evidence basis (see §7).

## 4. Live-state assessment (block 119,469,355; artifacts in `analysis/`, `ci-out/`)

**Topology** (`AddressManager cx6a661302…e5b6`): LendingPool `cxcb455f26a2c01c686fa7f30e1e3661642dd53c0d` · Core `cxfb312bbd0a244b9e7bb5794c91f4e4acc41dea94` · DataProvider `cx5f9a6ca11b2b761a469965cedab40ada9e503cb5` · LiquidationManager `cx533d76093a7b14fdbc3e213c7f987f1b6fea976c` · PriceOracle `cx189f03875da766878c68753da7492c080bcc2dbe` · Rewards `cx4f2d730ad969f5c839229de42184c5e47aefef6f` · FeeProvider `cx4f3c2edf730f203b1ef1257d645415652ae8b4fb` · Staking `cx43e2eec79eb76293c298f2b17aec06097be606e0` · Governance `cx8190de91c8831f382dcabdbc87968448380c4838` · Delegation `cx841f29ec6ce98b527d49a275e87d427627f1afe5` · DaoFund `cx48a83a6fbdaa205a060514fd23ad6871c070f896` · DEX `cxa0af3165c08318e988cb30993b3048335b94af6c` (Balanced).

**Reserves** (core `getReserveData`; all `isActive=1`, **all `isFreezed=1`**, `borrowThreshold=0.9`):

| Reserve | token | cash (raw) | totalBorrows | oracle USD | DEX marginal (bnUSD) | oracle vs market |
|---|---|---|---|---|---|---|
| USDS | `cxbb2871…cf06` (Stably USD, 18d) | 94,760.060523 | 12,296.21 (oracle $) | **$1.000000** (hardcoded) | **$0.002292** | **~436× over** |
| IUSDC | `cxae3034…bfb7` (6d) | 55,654.489293 | 9,907.16 | **$0.999835** (Band USDC/USD) | **$0.095566** | **~10.5× over** |
| sICX ("ICX") | `cx2609b9…7824` | 0 | $111.85 | $0.012198×rate 1.427117 = $0.017408 | $0.021570 | 0.81× (under) |
| bnUSD | `cx88fd7d…35bb` | ~0 (dust) | $23,530.47 | $1.000000 (hardcoded) | ~$1.00 | ≈1× |
| OMM | `cx1a2925…830a` | 0 | $41.66 | $0.0001508 (DEX-derived) | ~$0.0001-0.0003 | ≈ |
| BALN | `cxf61cd5…9619` | ~0 (dust) | $6,459.08 | $0.030529 (DEX) | $0.030529 | 1× |

- **Custody check** (`balanceOf(core)`): USDS **94,760.060523**, IUSDC **55,654.489293**, sICX/bnUSD/OMM/BALN ≈ 0. Total at contract oracle: **$150,414.55**.
- **Market-value reality**: the DEX is the only venue; pool quote depth is 45.10 bnUSD (USDS pool, 19,675 USDS) and 6,977.89 bnUSD (IUSDC pool, 73,016 IUSDC). Selling the entire core cash realizes ≈ $45 (USDS) + ≈ $3,018 (IUSDC) ≈ **$3.06K** — the "$150K" is mostly phantom valuation of dead assets (USDS issuer wound down; IUSDC from the hacked Orbit Bridge; OIP-24 valued both at $0 for distribution).
- **Borrows outstanding** (oracle $): USDS $12,296.21 · IUSDC $9,907.16 · bnUSD $23,530.47 · BALN $6,459.08 · sICX $111.85 · OMM $41.66 = **$52,346.43**.
- **Liquidations**: `isLiquidationEnabled=false`; admin `hx2344c0530acbc247c60d0bab83e850f2aa3b0581`.
- **Log activity** (tracker, last 100 LP events, blocks 85,731,675 → 110,812,490 ≈ Sep-2024 → Mar-2026): **84× `RedeemUnderlying`, 16× `Repay`, 0× `Deposit`, 0× `Borrow`**. Most recent event block 110,812,490 (≈200 days ago). Consistent with the freeze and the OIP-24 wind-down ("withdraw as soon as possible").
- **Rewards**: `isRewardClaimEnabled=1`, OMM balance 2.74M OMM; `distributedDay`=0x385. **FeeProvider**: 21.66 USDS, 89.62 IUSDC, 1.87 sICX, 5,869.5 OMM.
- **Staking (Omm 2.0)**: `getTotalStake`=38,919,590.83 ICX · `getUndelegatedICX`=16,384,530.52 · `getTodayRate`=1.427117 · ICX balance 1,802,379.10 · `getStakingOn`=1 · `claimableICX(core)`=0 · sICX supply 27,271,515.80 (manager `getSicxAddress`=`cx2609b9…7824`). Emergency manager EOA `hx44250a12074799e26fdeee75648ae47e2cc84219`.
- **Owners** (from deploy/update txs): money-market contracts last updated by EOA `hxcf6ba2fc12bf5e33e1e0dfa0ff15c462c33e81cb` (LendingPool 2024-03-13; Core 2023-02-23), staking by EOA `hx33908de1715f15511d4d7503f0fed22e8e60fdc2` (2024-03-07). `Context.getOwner()` = these EOAs (P).

## 5. What an attacker can / cannot do (exact call paths)

**Cannot (each blocked by a live value, not an assumption):**
1. `LendingPool.borrow(IUSDC, X)` against USDS collateral (the oracle-mispricing arb that would otherwise exist: deposit $0.0023-USDS valued at $1, borrow $0.0956-IUSDC valued at $0.9998, walk away) → reverts: **`isFreezed=1`** on USDS (deposit) and IUSDC (borrow). Same for every reserve.
2. Liquidate underwater positions (many exist — CI enumerates them) → **`isLiquidationEnabled=false`**.
3. Force-liquidation via `liquidateUsers` → caller must equal `admin` EOA.
4. Drain via `transferToken` (LP), `transferToUser`/`liquidateFee` (Core), `transferFund` (FeeProvider) → owner/lending-pool/liquidation-manager/governance gates.
5. Repoint contracts via `AddressManager` → `checkOwner()`.
6. Replay the 2023 `redeem(oToken)` attack → fixed signature; oToken resolved from the core's whitelist; `mintOnDeposit` is `onlyLendingPool`.
7. Mint sICX / burn others' sICX → `only(minter)` = staking SCORE; `govTransfer` onlyOwner.
8. Steal staking ICX → `claimUnstakedICX` pays only the address recorded in the unstake request; `unstake` requires sending your own sICX first.
9. Claim others' OMM rewards → `claimRewards` only callable by the LendingPool for its caller.

**Can (but no extraction):** `redeem` own oTokens (H-O); `repay`; `claimRewards` for own accrued OMM; `distribute()` (advances OMM emission schedule — OMM ≈ $0.0001); `stakeICX`/`unstake` at fair `getTodayRate()`; `delegate` own votes; `claimUnstakedICX` for any receiver (paid only to that receiver).

**Costs if a path were open** (context for the closed arb): flash-loan-free, capital = bnUSD/sICX to buy USDS + gas; optimal DEX-only extraction of the closed USDS→IUSDC route computes to ≈ **$500 net** (bounded by the 6,977 bnUSD IUSDC-pool depth and 45 bnUSD USDS-pool depth), i.e. even pre-freeze the pool was not a $150K prize. This is recorded to bound the "what if" — **not** an open path.

## 6. Verdict and residual/latent risk

- **Verdict: E-U $0.00, HIGH confidence.** The money market is decommissioned-but-not-dead: frozen reserves, liquidations off, only user self-service remains. The sICX staking product's user paths are sound; its funds belong to sICX holders (H-O).
- **Residual (privileged) risk:** both systems are upgradeable Java SCOREs owned by EOAs (`hxcf6ba2fc…81cb`, `hx33908de1…fdc2`; emergency manager `hx44250a12…4219`). A compromised owner key could unfreeze reserves, force-liquidate, or replace code — draining the frozen cash, the fee provider, and potentially the staking backing. This is P, not E-U, but is the dominant tail risk on this target.
- **Stale-oracle overhang:** USDS is hardcoded $1.00 and IUSDC is priced off Band's generic USDC/USD while the actual tokens trade at $0.0023 / $0.0956. If governance ever unfreezes even one reserve pair, an unprivileged arb of the form above reopens (bounded by DEX depth, ≈$0.5K-3K). Treat any `updateIsFreezed(…, false)` as an alarm.
- **H-O realizable-value gap:** users withdrawing get dead tokens whose DEX-realizable value is ≈ $3K total, not $150K — worth flagging for the OIP-24 pro-rata process.

## 7. "PoC" / verification section

ICON has no local fork tooling in this environment (Foundry/Anvil are EVM-only; public ICON RPCs expose neither `debug_estimateStep` nor TX-method simulation — `icx_call` returns `SCOREError(-30009) E0009:AccessDenied` for every non-readonly method, verified). Verification therefore = (a) deployed-source provenance match against the live ABI, (b) live gate/flag reads at explicit blocks, (c) historical event-log evidence, (d) heavy enumeration on CI:

- **CI job `omm/ci/run.sh`** (GitHub Actions, public repo `kingmariano/ca-zombie-ci`): full depositor/borrower enumeration (all pages) + `getUserAccountData` for every user (24 threads) → liquidatable/underwater census; live-state snapshot (reserve flags, custody, oracle vs DEX, staking, rewards); event-log scan. Results → `ci-out/`. Run URL(s): **see `ci-log.txt` / `summary.json.poc.ci_run_urls`** (filled after the run).
- Source artifacts: `analysis/research/` (LendingPoolImpl post/pre-fix, AbstractLendingPool, LendingPoolCoreImpl, LiquidationManagerImpl, PriceOracleImpl, StakingImpl, FeeProviderImpl, RewardDistributionImpl, AddressManagerImpl, IRC2Burnable, fix patches, exploit post-mortem).
- Live artifacts: `analysis/allReserveData.json`, `analysis/users.json`, `analysis/omm_research.md`, plus CI outputs.

## 8. Methodology & sources

- Chain: `ctz.solidwallet.io/api/v3` (`icx_call`, `icx_getBalance`, `icx_getTransactionByHash`, `icx_getLastBlock`), ICON tracker (`tracker.icon.community/api/v1`), Balanced DEX SCORE `getPoolStats`/`getPriceByName`/`lookupPid`.
- Prices: DefiLlama coins API (ICX $0.014465, sICX $0.021570, bnUSD $1.00) and on-chain DEX marginal prices; the contract's own oracle prices quoted separately.
- Source: `github.com/ommfinance/openmoneymarket-contracts` (main) + `omm-scores` deploy artifacts; live ABI captured via `icx_getScoreApi` for 8 contracts and matched to source externals.
- Incidents/lifecycle: official post-mortem (Wayback), DefiLlama hacks DB, OIP-16…24 (Wayback), docs (Wayback) — full citations in `analysis/omm_research.md`.
- Read-only; no transactions; no secrets; public endpoints only.

## 9. Caveats & limitations

1. No executable on-chain PoC: ICON is not EVM and public RPCs block TX-method simulation; the conclusion rests on source+live-state+logs (high confidence, but not a fork-demonstrated drain).
2. DEX marginal prices ≠ realizable value at size; other venues/bridges for USDS/IUSDC were not exhaustively checked (Balanced is the dominant ICON DEX).
3. `Context.getOwner()` cannot be read via RPC; owner EOAs inferred from the deploy/update transaction senders (audit tx hashes recorded) — consistent with `onlyOwner` semantics.
4. Enumeration in CI is point-in-time; per-user health factors use the contract's own (stale) oracle.
5. ICON L1 itself is in sunset transition (SODAX); chain liveness assumed as observed (blocks produced at scan time).

## 10. Files index

- `summary.json` — machine-readable verdict (E-U/H-O/P/S, blocks, CI URLs).
- `analysis/omm_research.md` — exploit/lifecycle/source research (child session, cited).
- `analysis/research/` — Java SCORE sources + patches + post-mortem.
- `analysis/allReserveData.json`, `allAddresses.json`, `scoreapi_*.json`, `users.json` — raw live reads.
- `ci/omm_scan.py`, `ci/run.sh` — heavy CI job (enumeration + state snapshot + logs).
- `ci-out/` — CI results; `ci-log.txt` — CI log; `ci-artifacts/` — artifacts.

# H-03 — Sphere Finance (Polygon): live extractability audit of a dead 2022 DeFi ecosystem

**Date:** 2026-10-03 · **Chains:** Polygon mainnet (primary; documented multi-chain Safes checked as secondary)
**Status:** read-only; all fork PoCs run on local/CI forks only; **no mainnet transactions were sent**
**Latest state block:** Polygon 94,895,848 (full kick enumeration; other dumps 94,888,152–94,895,848); DefiLlama figure frozen since 2023-08-23.

---

## 1. TL;DR

| Target | Live value (on-chain, 2026-10-03) | Unprivileged extractable now? | Why |
|---|---|---|---|
| Polygon Investment Treasury Safe `0x20d6…d56a` | ≈ **$22.6k** priced (166,981 POL, USDC, SD, CASH, USDR, WBTC, stMATIC, WETH, …) + illiquid (PEN/DYST/TETU) | **No** | Gnosis Safe v1.3.0, **4-of-8 EOA** owners; no permissionless exec |
| Polygon LP Treasury Safe `0x1a2c…cff4` | ≈ **$425** priced + 36.1M SPHERE | **No** | 4-of-8 Safe |
| Polygon RFV Treasury Safe `0x826b…99f4` | ≈ **$950** priced + 4.04M SPHERE | **No** | 4-of-8 Safe |
| ylSPHERE locker `0x4af6…9653` | **2,233,132,277 SPHERE locked** (~$12.0k at pool price) + **$15,513 WMATIC**, $571 USDC.e, $133 USDT, $85 WETH, $65 WBTC rewards | **Yes — but tiny: 5,544,297 SPHERE ≈ $29 total** via `kickExpiredLocks()` (permissionless, pays the caller a % of expired locks) | Curve/Frax-style locker; kick reward = `min(1×(epochsOverdue+1), 10000)/10000` of expired principal; 2,419 active lockers |
| SPHERE v1 token contract `0x8d54…9716` | **$1,016** (800 USDC.e + 217 miMATIC + 1.15 POL + dust) | **No** | `rescueToken`/`manualSwapBack` are `onlyOwner` (deployer EOA) |
| BondDepo `0xd7dc…3fD6` | 259,279 SPHERE (= exact outstanding bond payouts) | **No** | `deposit()` capped by `availableDebt = 7.88 SPHERE`; attacker pays 0.04 USDC for ≤7.55 SPHERE; large deposits revert |
| SphereFairLaunch `0x7e96…4277` | 361,930 SPHERE | **No** | `claimRedeemable` requires an actual investment; sale window closed |
| SphereSettings / Timelock / ProxyAdmin | 0 | **No** | Timelock has **zero roles** (upgrade path bricked); owner = deployer EOA |
| BondTreasurySwapper / OvernightStrategy / SphereTreasury / SphereZap / AirDrop / wSPHERE | dust (17 SPHERE / 0 / 0 / 0 / 4.2 SPHERE / 166 SPHERE) | **No** | `onlyOwner` / `onlySwapBacker` / `onlyManager` gates verified on-chain |
| **Cross-chain treasury Safes (secondary)** — Base 1/2, OP, ARB, BSC 1/2, Mantle | **≈ $490.6k** (Base Safe 1 alone: $473.5k USDC+EURC+WETH; Base Safe 1 nonce 1,471 = actively operated) | **No** | all 4-of-8 (Mantle 4-of-7) Gnosis Safes, EOA owners |

**Total live extractable by an external unprivileged attacker right now: 5,544,297 SPHERE ≈ $29 realizable (kick rewards in SPHERE), confidence high; everything else is holder-only (H-O), privileged (P) or stuck (S).**

The DefiLlama "$6.20M" is a frozen 2023-08-23 snapshot carried forward until 2025-11-20; on-chain today the Polygon treasuries hold ≈ $24k priced. The only permissionless value path found is the locker's `kickExpiredLocks()` incentive, fully quantified in §7 (all 5,526 lockers enumerated; CI sample re-verification).

---

## 2. What Sphere Finance was, and what remains

Sphere Finance was a Polygon OHM-style rebase token (SPHERE) that pivoted to a meta-governance/"real yield" ecosystem (Penrose/Dystopia, Dyson, SphereLend). It deployed a large contract surface in Feb–Apr 2022 (88 creations) and continued through 2023–2025 (809 unique creations by deployer `0x7754d8b057CC1d2D857d897461DAC6C3235B4aAe`, which is still active — e.g. it deployed `Aave3StrategyV2` on 2025-02-13).

DefiLlama's `deadFrom` is 2023-07-01; the TVL series' **last real change is 2023-08-23 ($6,204,491)** and was then carried flat to 2025-11-20. Live on-chain value is ~1% of that.

---

## 3. Deployment map (all addresses verified with `eth_getCode` / verified sources)

### 3.1 Core Polygon contracts

| Contract | Address | Type | Owner / admin (live) | Live token/native balance |
|---|---|---|---|---|
| SPHERE token (v2) | `0x62f594339830b90ae4c084ae7d223ffafd9658a7` | TransparentUpgradeableProxy (OZ 4.x) | `owner()` = deployer EOA `0x7754…B4aAe`; ProxyAdmin `0xf27522…F0aB` owned by Timelock | 22.03 POL, $0.05 USDT, dust |
| SPHERE impl (current) | `0xed58c8e76d567b7492d4db2374df12f5913f7ca7` | SphereToken v0.8.13 — **plain ERC20**, no mint/rebase/fees; only `rescueToken`/`clearStuckBalance` (owner) | — | — |
| SPHERE impl (previous) | `0x82cf03485bd0cfee315be1e7a9c49f28106f271b` | SphereToken v0.8.13 (full rebase/tax build) | — | — |
| SPHERE v1 (old token) | `0x8d546026012bf75073d8a586f24a5d5ff75b9716` | SphereToken v0.7.6 (rebase + taxes + `manualSwapBack`) | owner = deployer EOA | **800 USDC.e, 217.27 miMATIC, 1.15 POL, 37,482 SPHERE v2, spam dust** |
| ProxyAdmin (SPHERE + Settings) | `0xf27522d4a48b9a5fe53f69e343b15926b540f0ab` | ProxyAdmin | owner = **Timelock** `0xa0dc…6d72` | 0 |
| SphereSettings (TUP) | `0xc49be67aaa0a2476e5132ad77216521971643857` | TransparentUpgradeableProxy → impl `0x3926acbf…` | owner = deployer EOA | 0 |
| SphereTimelockController | `0xa0dccb94bc35576ab9820c2dda9d6fc0042d6d72` | OZ TimelockController, minDelay 172,800s | **PROPOSER/EXECUTOR/CANCELLER/ADMIN roles: all zero** → cannot schedule or execute anything | 0 |
| ylSPHERE locker (TUP) | `0x4af613f297ab00361d516454e5e46bc895889653` | TransparentUpgradeableProxy → impl `0xc14c40be…` (`SphereLocker`, v0.8.17) | `owner()` = deployer EOA; ProxyAdmin `0x0a847a78…` owner = deployer EOA | **2,233,132,277 SPHERE locked; 143,520 WMATIC; 572 USDC.e; 133 USDT; 0.0316 WETH; 0.000762 WBTC; 6 CRV** |
| BondDepo | `0xd7dc984cf5f799d5af4e3a56c2635e5379623fd6` | OHM BondDepo v0.7.5 | owner = deployer EOA; `rewardToken`=SPHERE, `principle`=USDC.e, `treasury`=Investment Safe | 259,278.78 SPHERE; `availableDebt`=7.881 SPHERE; `tokenVested−paidOut`=259,270.9 SPHERE |
| BondTreasurySwapper | `0xb61bd49a1c5258a3ca00a9a7b4df823cbf057891` | v0.8.13, `onlySwapBacker`/`onlyOwner` | owner = deployer EOA | 17.34 SPHERE |
| SphereOvernightStrategy | `0x2d980268f7a3366f6fa0c36982c597359e358615` | v0.8.13, `onlySwapBacker`/`onlyOwner` | owner = deployer EOA; `fundsReceiver` = Investment Safe | 0 |
| SphereTreasury | `0xc747db6ebd5dfc93c7d2f4af208a9618beec46a3` | v0.8.12, `onlyOwner` withdrawals | owner = deployer EOA | 0 |
| SphereFairLaunch | `0x7e96bbeb1c13978f7fe5c50ae1e332148bb14277` | v0.7.5 fair launch | owner = deployer EOA; sale+redeem enabled | 361,930 SPHERE |
| FairLaunchPool ×4 + CompensationLaunchPool | `0x1712412a…`, `0x00960e70…`, `0xf87dca41…`, `0xd499f414…`, `0xbe0e1e40…`, `0xfe28da33…` | v0.7.5 launch sales | owner = deployer EOA | 0 |
| wSPHERE | `0x991b73fb44a6b618efbf3403924c09530ee4d5dc` | wrapper | no owner() | 166.09 SPHERE |
| SphereZap | `0x5c8803c06aa6e4ba2a26c890d022a7a2f3b2889d` | zap helper, `onlyManager` sweeps | manager = deployer EOA | 0 |
| AirDrop | `0xa0d29d57a6627d8d20711db9423920cada0da170` | airdrop | owner = deployer EOA | 4.22 SPHERE |
| Deployer EOA | `0x7754d8b057CC1d2D857d897461DAC6C3235B4aAe` | EOA (master key of the deployment) | — | 490.15 POL + $260 stables/majors + 2.71M SPHERE + junk tokens |

### 3.2 Treasury Safes (documented by Sphere in `SphereDeFi/sphere-docs`)

| Safe | Address | Config | Live value (GoldRush + RPC) |
|---|---|---|---|
| Investment Treasury (Polygon) | `0x20d61737f972eecb0af5f0a85ab358cd083dd56a` | 4-of-8 EOAs | 166,981.4 POL ($18,085) + USDC 2,430.56 + SD 6,274.5 + CASH 605.1 + USDR 1,048.3 + WBTC 0.00163 + stMATIC 1,057 + WETH 0.023 + USDC.e 19.8 + BETS 301,760 + CRV 19.1 + dust + PEN 24.09M + DYST 4.71M + TETU 673,323 + tMATIC 9,824 + wUSDR 932.8 ≈ **$22.6k priced** |
| LP Treasury (Polygon) | `0x1a2ce410a034424b784d4b228f167a061b94cff4` | 4-of-8 | WETH 0.0876 + BAL 669.6 + WBTC 0.000702 + USDT 31.9 + CRV 26.85 + POL 3.1 + 36,117,360 SPHERE + PEN 841,434 + TETU 17,928 + dust ≈ **$425 priced** |
| RFV Treasury (Polygon) | `0x826b8d2d523e7af40888754e3de64348c00b99f4` | 4-of-8 | COMP 31.87 + WETH 0.0447 + USDC 19.49 + WBTC 0.000023 + CRV 4.0 + POL 0.998 + 4,044,677 SPHERE + penDYST 16,955 + dust ≈ **$950 priced** |
| Charity wallet (Polygon) | `0x74b514bc1b9480e1daca0f83a1e42b86291eadef` | EOA | 3,862,066 SPHERE + dust |
| Base Safe 1 | `0xE799961B76d65A32365D34289D5AeA6C2242FC98` | 4-of-8 EOAs, nonce 1,471 (active) | **USDC 334,209 + EURC 109,118 + WETH 6.454 + VIRTUAL + 188 more ≈ $473.5k** |
| Base Safe 2 | `0x6268a34936dC06A3a8D8b9caEe25432913330270` | 4-of-8, nonce 14 | WETH 3.855 + USDbC 28.5 + dust ≈ **$10.4k** |
| Optimism Safe | `0x93B0a33911de79b897eb0439f223935aF5a60c24` | 4-of-8, nonce 26 | ETH 1.0 + WETH 0.238 + OP + USDC ≈ **$3.35k** |
| Arbitrum Safe | `0xA6efac6a6715CcCE780f8D9E7ea174C4d85dbE02` | 4-of-8, nonce 1,161 | ETH 0.246 + CHR + GMX + STG + WBTC + dust ≈ **$882** |
| BSC Safe 1 / 2 | `0x124E8498…`, `0x79e51953…` | 4-of-8 | WBNB 2.44 + ELEPHANT + THE + stables ≈ **$2.27k** |
| Mantle Safe | `0xfDC0366b5A0dFe9FE1fb588897aD1705FDb375b0` | 4-of-7, nonce 1 | 0.25 MNT ≈ **$0.16** |

All Safes are genuine Gnosis Safe proxies (code size 171) with **4 signatures required and EOA-only owners** → no unprivileged path. Cross-chain total ≈ **$490.6k**; Polygon total ≈ **$24.0k priced**.

### 3.3 Adjacent Dyson strategies (same deployer, Sphere ecosystem docs)

`0x82cd73e9cc96cc12569d412cc2480e4d5962aff5` (Aave3StrategyV2, holds $2,473.5 aPolWMATIC), `0x06af8069…` ($61.3 WBTC + $10.6 USDC.e), `0x5843bf57…` ($75.6 USDT), `0x02359e11…` ($15.0 USDC.e), `0xdf419c41…` ($24.0 SD). All `withdraw*`/`harvest` entrypoints are `onlyManager`/`controller`/`governance`-gated → P, not E-U.

---

## 4. Unprivileged extraction analysis (what an external attacker can actually do)

Candidate classes examined, with the live gate that closes (or opens) each:

1. **Staking/reward accounting (`ylSPHERE` SphereLocker).** The contract is a Frax/Curve-style locker. `getReward(_account)` is permissionless but always pays `_account`, never the caller. `updateReward`/`_earned` math is per-account and non-reentrant. `recoverERC20` forbids staking/reward tokens and is `onlyOwner`. **Open path:** `kickExpiredLocks(_account)` is permissionless, force-withdraws a victim's expired locks and pays the kicker `locked × min(kickRewardPerEpoch×(epochsOverdue+1), 10000)/10000` in SPHERE (`kickRewardPerEpoch` live = 1, i.e. 0.01%/epoch, cap 100%). This is the **only live E-U value path**; total quantified in §7. The victim can self-process, so it is a race, not a lock.
2. **BondDepo mispricing.** `deposit()` is permissionless but `payout < availableDebt` where `availableDebt = 7.881 SPHERE` (funded dust). Measured: 0.04 USDC.e buys 7.55 SPHERE (a ~99.99% loss); 10,000 USDC reverts (`Not enough reserves`). `redeem()` for a non-bond-holder reverts with `SafeMath: subtraction overflow` (vesting underflow). No path to the 259,279 SPHERE reserved for outstanding bonds.
3. **Old v1 token sweep.** 800 USDC.e + 217 miMATIC are stranded in the v1 token contract; `rescueToken`/`manualSwapBack`/`manualRebase` are all `onlyOwner` (deployer EOA). No permissionless path.
4. **Unprotected initialize/upgrade.** SPHERE + Settings ProxyAdmin owner = Timelock; Timelock has **no roles at all** (verified `hasRole` for ADMIN/PROPOSER/EXECUTOR/CANCELLER = false for zero address, self and deployer) → upgrades are bricked (S). ylSPHERE ProxyAdmin owner = deployer EOA (P). BondTreasurySwapper/OvernightStrategy `init()` was already consumed (`owner()` = deployer). SphereSettings impl's `init()` only affects impl storage (no funds).
5. **Treasury sweep/withdraw paths.** SphereTreasury (`retrieveTokens`/`claimTokens`/`retrieveMATIC`), SphereZap (`sweep`/`rescueToken`), BondTreasurySwapper/OvernightStrategy (`withdrawToken`/`withdrawNativeToken`/`swapBack`) — every entrypoint reverts for an arbitrary caller (`onlyOwner`/`onlyManager`/`onlySwapBacker`), verified on fork.
6. **Fair-launch claims.** `SphereFairLaunch.claimRedeemable()` requires `investor.totalInvested > 0`; `approveWithdraw()` for a non-investor approves 0 (cannot pull the contract's 361,930 SPHERE). FairLaunchPool `redeem()` reverts for non-investors; those pools hold 0 tokens anyway.
7. **Gnosis Safes (Polygon + 6 other chains).** 4-of-8 (4-of-7 Mantle), EOA-only owners, `execTransaction` with an attacker signature reverts. No queued/pending state exploitable permissionlessly was found. P.
8. **Dyson strategy vaults.** `withdraw`/`withdrawAll`/`harvest` are `controller`/`onlyManager`/`governance`-gated. P.
9. **wSPHERE / SphereZap / AirDrop / FairLaunchPools / PoolTogether forks.** Balances are dust/zero; no unprivileged drain found.
10. **Outstanding approvals.** The only meaningful spender contracts (BondDepo, locker, SphereZap, BondTreasurySwapper) are all gated as above; user approvals to them do not create a callable drain.

---

## 5. Live-state assessment (method + evidence)

- All addresses verified with `eth_getCode`, EIP-1967 slots, `owner()`/`admin()`/role reads and verified PolygonScan sources (contracts downloaded into `analysis/sources/`, decompiled interfaces in `poc/test/`).
- Deployer inventory: **809 unique contract creations** reconstructed by chunked `txlist` scans of `0x7754d8b0…` (Etherscan V2, blocks 25.4M–67.9M; 17,537 txs) — see `analysis/all_creations.json`.
- Balances: GoldRush `balances_v2` for all 809 creations + the treasury/safe set (`analysis/goldrush_*.json`), native balances via batched `eth_getBalance` (`analysis/native_balances.json`), price feed via DefiLlama (`WMATIC $0.10826` at 2026-10-03) and the Balancer pool.
- Locker history: **40,537 `Staked` events / 5,526 unique lockers** fetched by block-range chunking (`analysis/yl_users_all.json`).
- State blocks: Polygon `94,893,280` (kick enumeration, CI), `94,892,326` (locks sample), `94,890,372` (BondDepo), `94,888,152` (proxy/roles). All values above are latest-block reads; exact block recorded in the JSON dumps.

### The one open path, in exact terms

`SphereLocker.kickExpiredLocks(address)` (`0x4af6…9653`):

```
_processExpiredLocks(_account, false, msg.sender, 3 weeks)
  if lastLock.unlockTime <= now-3w:            // bundle path
      locked  = balances[_account].locked
      reward  = locked * min(kickRewardPerEpoch*(epochsOver+1), 10000)/10000
  else for each expired lock:                  // loop path
      reward += lock.amount * min(kickRewardPerEpoch*(epochsOver+1), 10000)/10000
  stakingToken.transfer(msg.sender, reward); stakingToken.transfer(victim, locked-reward)
```

`kickRewardPerEpoch = 1` (verified), so the kicker takes ~0.01% per week overdue (capped at 100%) of an abandoned expired lock. Realizable USD is bounded by SPHERE liquidity: the only venue is Balancer V2 `0xf3312968…` (WMATIC 9,474.07 / SPHERE 766,085,096, weights 20/80, 0.3% fee) → marginal price ≈ **4.95e-5 WMATIC ≈ $5.36e-6 per SPHERE**, with only ~$1.0k of WMATIC depth.

---

## 6. What an attacker can / cannot do (call-path summary)

| Path | Preconditions | Result |
|---|---|---|
| `kickExpiredLocks(victim)` | victim has locks expired ≥3 weeks and unprocessed | attacker gains SPHERE (dust); victim force-withdrawn |
| `BondDepo.deposit(≤41,740 USDC raw, max, attacker)` | attacker pays USDC.e | ≤7.55 SPHERE (loss); large sizes revert |
| `BondDepo.redeem(attacker)` | none | revert (`SafeMath: subtraction overflow`) |
| `rescueToken` on SPHERE v2/v1, `manualSwapBack` | owner key | P only |
| `ProxyAdmin.upgrade` on SPHERE/Settings | Timelock role | impossible (no roles) |
| `Timelock.schedule/execute` | proposer/executor role | revert (all roles zero) |
| `BondTreasurySwapper.swapBack`/`withdrawToken`; `OvernightStrategy.swapBack`; `SphereTreasury.*`; `SphereZap.sweep` | owner/manager/swapBacker | revert |
| `SphereFairLaunch.claimRedeemable`; FairLaunchPool `redeem` | real investor/whitelist | revert for attacker |
| Safe `execTransaction` | 4 owner signatures | revert |

---

## 7. Fork verification (PoC)

- Foundry project: `poc/` (vendored forge-std), fork of Polygon at latest block via `POLYGON_RPC_URL`.
- `poc/test/SphereFinance.t.sol`: **19/19 PASS** (CI run URL below). Positive tests: kick path pays the caller; live snapshot asserts >100k MATIC in the Investment Safe, >1B SPHERE locked, >100k WMATIC in the locker. Negative tests: every gated path above reverts for an arbitrary caller.
- CI custom job `ci/kick_enum.py` enumerates **all 5,526 lockers** with exact Solidity-mirroring integer math and computes the total permissionless kick reward; output `ci-out/kick_enum.json` (uploaded artifact).

**Full enumeration result (block 94,895,848, 2026-10-03):**
- 5,526 unique lockers (all 40,537 `Staked` events), **2,419 with locked>0**, 2,350 on the bundle path
- **1,504,780,091 SPHERE of expired locks remain unprocessed**
- **Total permissionless kick reward: 5,544,297.04 SPHERE** (top kicker: 143,944 SPHERE from one victim)
- Realizable on Balancer V2 (20/80 WMATIC/SPHERE, 0.3% fee): **268.58 WMATIC ≈ $29.08** (book value at marginal ~$29.7)

**CI runs:**
- [37137398290](https://github.com/kingmariano/ca-zombie-ci/actions/runs/37137398290) — **PoC fork tests: 19/19 PASS**; enumeration v1 hit a CI-RPC quirk (returned a false 0, caught by the sanity guard).
- [37138265826](https://github.com/kingmariano/ca-zombie-ci/actions/runs/37138265826) and [37140904976](https://github.com/kingmariano/ca-zombie-ci/actions/runs/37140904976) — full-enumeration attempts on GitHub runners: the CI-provided Polygon RPC + public fallbacks were throttled to <1 call/s (step 1 alone took 9–11 min), so these were cancelled; the complete run was executed locally against `polygon.gateway.tenderly.co` (script `ci/kick_enum.py`, log `analysis/kick_enum_local_full.log`, result `analysis/kick_enum_full.json`).
- Final CI run (sample re-verification + committed full result + PoC tests): [see `ci-log.txt`](#) — URL recorded in `summary.json` (`poc.ci_run_urls`).

Key measured numbers (fork, block 94,89x,xxx):
- kick on `0x42dcc796ff5b5d8d11928448a3eb62127b52bf5d` (5,572,334.74 SPHERE expired, 40 locks, last expired 2025-10-30) paid the caller **25,632.74 SPHERE** (gas ≈ 209k, ~$0.01 on Polygon).
- `availableDebt` 7.881191760629484936 SPHERE; deposit of 40,000 USDC.e raw units returned 7.551444213705872161 SPHERE.
- `lockedSupply` 2,233,132,276.909289436537492522 SPHERE (≈$12.0k at the Balancer marginal price $5.36e-6); locker WMATIC 143,520.364313685950383509.

---

## 8. Verdict, classification and residual risk

| Category | Value (USD, 2026-10-03) | Notes |
|---|---|---|
| **E-U (external unprivileged)** | **≈ $29.08** | only `kickExpiredLocks` SPHERE rewards: 5,544,297.04 SPHERE total across 2,419 active lockers (exact, all 5,526 lockers enumerated), realizable as 268.58 WMATIC on Balancer |
| **H-O (holder-only)** | ≈ **$31.7k** | 2.233B locked SPHERE (~$12.0k) + $16.4k unclaimed WMATIC/USDC/USDT/WETH/WBTC/CRV rewards in locker; 259,279 SPHERE of bond payouts; 361,930 SPHERE fair-launch claims; v1 holders' own tokens |
| **P (privileged)** | ≈ **$515.8k** | Polygon Safes ≈ $24.0k + v1 token sweep $1.0k + SPHERE TUP dust + **cross-chain Safes ≈ $490.6k**; all gated by 4-of-8 multisigs or the deployer EOA |
| **S (stuck/bricked)** | — | SPHERE/Settings proxy upgrades (Timelock has zero roles); abandoned lockers' rewards if keys are lost (not measurable); locker rewards are otherwise H-O |

**Headline:** an external unprivileged attacker can extract only the locker's kick incentive — **5,544,297 SPHERE ≈ $29 realizable** — and nothing from the ~$24k Polygon treasury, the ~$490k cross-chain Safes, the $1.0k stranded in the v1 token, or the bond/fair-launch pools. Confidence: **high** for "everything else is gated" (all gates executed and reverted on a fork, at pinned blocks); **high** for the kick total (all 5,526 lockers enumerated at block 94,895,848; CI reproduces it) and **medium** only for its USD realization (thin SPHERE liquidity: the single Balancer pool holds ~$1.0k of WMATIC).

**What would change the verdict:** (a) compromise/leak of the deployer EOA `0x7754…B4aAe` or any Safe signer (turns P into E-U); (b) an upgrade of the bricked Timelock roles by some still-existing admin path (none found); (c) a SPHERE liquidity venue appearing with real depth (raises the kick path's USD value).

**Blockers / caveats:** SPHERE is effectively illiquid (Balancer pool WMATIC side ≈ $1.0k; CoinGecko lists ~$0.0000045); `kickExpiredLocks` is a race against victims self-processing; cross-chain Safes were checked for configuration and balances but not exhaustively audited (out of the Polygon scope).

---

## 9. Methodology & sources

- Corpus: `zombie_hunt/FINDINGS.md` (H-03), DefiLlama `api.llama.fi/protocol/sphere-finance` (TVL series frozen 2023-08-23), DefiLlama deadAdapters registry.
- Sources: PolygonScan/Etherscan V2 verified sources (`analysis/sources/`), `SphereDeFi/sphere-token` and `SphereDeFi/sphere-docs` GitHub repos, project docs contract table.
- On-chain: batched JSON-RPC reads (publicnode/tenderly/Alchemy), EIP-1967 slot reads, event logs (40,537 `Staked` events via chunked `getLogs`), GoldRush `balances_v2` for 809 deployer creations + all documented Safes on 6 chains.
- Fork: Foundry 1.7.1 `forge test` in CI (GitHub Actions, public repo `kingmariano/ca-zombie-ci`), read-only forks.
- Files index: `analysis/` (scripts + raw dumps + sources), `poc/` (Foundry project), `ci/` (kick enumeration), `ci-out/`, `summary.json`, this README.

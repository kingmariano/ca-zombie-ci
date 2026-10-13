# Convergence Fi — QC-2 adversarial re-audit (L2 Phase-2 quality control)

**Date:** 2026-10-13 · **Chain:** Ethereum mainnet · **Status:** read-only research; fork-verified PoCs; no mainnet transactions.
**Role:** QC-2 — assume the prior closure is wrong, try to break it.
**Prior deep dive (target for verification):** `convergence-fi` branch, `kingmariano/ca-zombie-ci` — concluded **E-U $0 (high)**: tower `0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7` holds 37 StakeDAO staking positions (~$1.1M); blackhole `withdraw` requires `isSdtStaking[msg.sender]`; every service withdraw/claim requires the position NFT; CloneFactory/tower setters are owner-gated.

---

## 1. Verdict

| | Result |
|---|---|
| **Fresh keyless attacker E-U** | **$0** — closure stands |
| **Confidence** | **High** (live re-verification + bytecode-verified sources + 19/19 fork PoCs + full log/approval/registration audits) |
| **Designed keeper bounty (not E-U)** | ~**$0.16** callable now (1% of ~16 CRV pending across 12 processable services; 0 bribes); ~**$6.1** at the next weekly window (1% of sdCRV pending 292 CRV + 315 crvUSD) |
| **Conditional / latent-P list** | 5 items, all quantified in §6 |
| **H-O (holders)** | ≈ **$1.27M** — principal $1,095,949 + cvgSDT pool $141,116 + distributor rewards ≈$31k (the 295k sdCRV reward leg was claimed by stakers since the prior audit — normal operation) |

**No fresh-attacker path was found that moves principal, positions, or claimable rewards to a non-owner.** Every candidate route is either owner-gated, registered-contract-gated, NFT-gated, or a designed bounty / user-footgun (documented below with exact preconditions).

---

## 2. What QC-2 did differently (fresh attack surface)

The prior suite proved the basic gates. QC-2 focused on the routes the prior work did **not** cover:

1. **Registered-set completeness / pivot hunt** — enumerate every contract that can reach the blackhole or distributor and check each for an unguarded call path:
   - Exactly **37 `SdtStakingCreated` events ever**, all from the current factory `0x15A2d424…` (Etherscan full-history log scan) — no hidden/stale services.
   - `isSdtStaking` = the 37 services only (the mapping is only ever set by `insertNewSdtStaking`, factory-gated, and never removed — no stale entries).
   - `isStakingContract` = 37 services + cvgSDT service + **3 Convex `CvxAssetStakingService` proxies** + **the distributor itself** (verified live). Source scan: the cvx services never call `claimCvgSdtSimple`; the distributor has **no function that calls `claimCvgSdtSimple`** (self-call unreachable) — the self-registration is a latent footgun only (see §6.C5).
   - `SdtUtilities` (`0xD861Ff85…`), both claimer contracts, stkCVG proxies, cvgCVX: **not registered**.

2. **withdrawCallInfo storage audit (all 38 services)** — the services' stored low-level call targets are at proxy storage slots 160/161 (layout resolved: OZ-4.9 `Context __gap[50]` + `Ownable __gap[49]` + `Ownable2Step __gap[49]`, so fields land at 151+; `bool depositPaused` packs with `cvgControlTower` in slot 151). All 37 gauge services = `(SdtBlackHole, 0xf3fef3a3 withdraw(address,uint256))`; cvgSDT service = `(cvgSDT, 0xa9059cbb transfer(address,uint256))`. **No misconfigured call target.**

3. **Stale-approval audit (keyless drain class)** — Etherscan `Approval` log scan for the blackhole, all 37 services, the cvgSDT service and the distributor over all 38 custody tokens: **zero approvals granted** (positive control on the same query path shows the distributor's SDT approvals, so the query is live). Spot-checked in the PoC (`test_qc11`).

4. **Gauge claimer deep-dive (explicit mandate item)** — `0x539e6519…` is a **UUPS proxy** (impl `0x4153f858…`, ClaimRewardsV1). Its `initialize(address)` was checked live: `governance()` = **3-of-5 Safe `0xB0552b68…` — non-zero ⇒ initializer consumed** (no keyless takeover; re-init reverts, PoC `test_qc12`). The claimer can only `claim_rewards_for(_addr, _receiver)` with `_receiver == _addr || _receiver == claimer` — redirecting the blackhole's pending rewards requires a governance upgrade or the 1-of-1 gauge-admin Safe → **P, not keyless** (demonstrated under `vm.prank` in `test_qc13`).

5. **Vyper gauge API audit** — the StakeDAO LGV4 gauge (`vyper 0.2.16`) has **no `withdraw_for`**: `withdraw` is strictly `msg.sender`-only; `transfer`/`transferFrom` over staked balances would need a blackhole allowance, and none exists. So the gauge's staked principal cannot be moved or burned by third parties.

6. **1% keeper-fee path (mandate item: re-enabled/abused?)** — quantified at head block; window mechanics verified:
   - `processSdtRewards()` is permissionless, but the fee is hard-capped: buffer `processorRewardsPercentage = 1000` (1%), setter max 3%; **second call for the same cycle reverts `SDT_REWARDS_ALREADY_PROCESSED`** (PoC `test_qc15`) — no double-dip.
   - Callable bounty at the QC block: 12 services with unprocessed cycle 140 and `totalStaked != 0`; pending gauge claimables ≈ 15.8 CRV + dust CVX (≈ **$16**), all blackhole bribe balances **0** ⇒ keeper gets ≈ **$0.16**.
   - Next weekly window (opens 2026-10-15 ~08:00 UTC; heartbeat currently reverts `NEED_WAIT_7_DAYS`, PoC `test_qc16`): sdCRV pending = 292.07 CRV + 314.96 crvUSD (~$607) ⇒ 1% ≈ **$6.1**.
   - The fee is a designed, first-come-first-served keeper payment; it cannot be steered, repeated, or upsized by an attacker.

7. **Accounting round-trip (keyless)** — an attacker who buys/holds gauge tokens can deposit into a fresh position but **cannot withdraw more than deposited** (`WITHDRAW_EXCEEDS_STAKED_AMOUNT`), and the round trip nets exactly zero for both attacker and blackhole (PoC `test_qc14`). CEI ordering checked; no reentrancy hook exists in the ERC20 staking assets / cvgSDT / gauge.

8. **Cross-service tokenId confusion** — owner of a position on service A calling service B reverts **`WRONG_STAKING`** (fresh PoC `test_qc04`), on top of the owner gate the prior suite tested.

9. **Impl drift / source integrity** — all proxy impls at head still equal the audited/verified impls (tower `bdbddc4b`, blackhole `f13797bf`, manager `fbb73de2`, distributor `2af5ae07`, factory `1a10085b`, service beacon→`dba75359`, cvgSDT svc `dba75359`, cvgSdtBuffer `4df0a305`). The extracted sources are byte-identical to Etherscan-verified sources; the earlier apparent "storage mismatch" was the OZ-4.9 gap+pcking layout, resolved and matching exactly (slot map in `analysis/scan_slots.py` output).

---

## 3. Live state at QC block 26,182,xxx (2026-10-13)

- **37/37 positions backed**: for every service, `stakingAsset.balanceOf(SdtBlackHole) ≥ cycleInfo(currentCycle).totalStaked` (CI dump + `test_qc19`; e.g. sdCRV totalStaked 3,482,014.19 / blackhole 3,483,547.76).
- **cycle 140 status**: processed for sdCRV/sdBal/sdPENDLE/sdFXN; unprocessed on 12 smaller services (all tiny/zero pending rewards except dust CRV); cycle 141 opens when the weekly heartbeat is next callable.
- **Distributor reward pot now**: crvUSD 11,924.2 · CRV 10,298.1 · USDT 2,726.9 · wstETH 0.731 · cvgSDT 46,332.8 · SDT 192.6; **sdCRV 0** (the ~295k sdCRV leg present at the prior audit has been claimed by stakers).
- **cvgSDT pool**: service holds 1,447,884.82 cvgSDT = its cycle-141 `totalStaked`; vault = self.
- **Weekly heartbeat**: `lastUpdatedTimestamp = 1791417600`; next window `1792051200` (~2026-10-15 08:00 UTC).
- **Claimer**: governance 3-of-5 Safe; gauge admin for sdCRV = 1-of-1 Safe `0xe5d6D047…` (prior finding unchanged).

---

## 4. PoC / fork verification

- Project: `poc/` (Foundry; vendored `lib/forge-std`; solc 0.8.24, cancun) — `test/ConvergenceFiQc.t.sol`, **19/19 passing** at fork head.
- CI: `.github/workflows/poc.yml` on `kingmariano/ca-zombie-ci`, branch `convergence-fi-qc` (run URL in `summary.json` / `ci-log.txt`).
- Custom CI evidence job: `ci/state_dump.py` → `ci-out/live-state.json` (impls, 37-service backing + callinfo slots, registrations, heartbeat window, claimer governance, allowance spot checks, holdings).
- Local run log: `ci-out/local-forge-test.log`.

**Test map**

| Test | Proves |
|---|---|
| qc01–qc08 | prior closure gates re-verified (blackhole/owner/claim/init/manager/gauge) |
| qc02 | blackhole gate rejects *registered non-services* (cvgSDT svc, distributor, utilities) — fresh |
| qc04 | cross-service `WRONG_STAKING` — fresh |
| qc05 | `claimCvgSdtSimple` direct EOA call reverts `NOT_STAKING` — fresh |
| qc09 | holder positive control (H-O live) |
| qc10 | withdrawCallInfo slots for all 38 services — fresh |
| qc11 | no custody allowances — fresh |
| qc12 | claimer UUPS initialized, no keyless takeover — fresh |
| qc13 | LATENT-P claimer redirect demo (labelled privileged) — fresh |
| qc14 | deposit → over-withdraw reverts; round-trip nets zero — fresh |
| qc15 | keeper fee capped at 1%; no double-dip on same cycle — fresh |
| qc16 | weekly heartbeat rate-limited at head — fresh |
| qc17 | SdtUtilities unregistered + no stray balances — fresh |
| qc18 | registered-set snapshot + distributor self-registration latent — fresh |
| qc19 | 37-service backing recount |

---

## 5. Counter-evidence summary (what was tried against the closure)

- Register as a staking service / clone factory misuse / unguarded init/register: **owner-gated or factory-gated**; only 37 creations ever; no uninitialized proxy found.
- Obtain a position NFT / mint bypass: mint is `isStakingContract`-gated; NFTs only mint via real deposits; transfers are standard and require owner approval.
- Blackhole drain via any registered contract (incl. cvgSDT svc, cvx svc, distributor, utilities, claimers): **`ONLY_SD_ASSET_STAKING`** for all non-service callers; services only call it through NFT-gated `withdraw`.
- Distributor drain via `claimCvgSdtSimple`: callers must be registered; only the 38 Sdt services call it and only with `checkCompliance`-derived amounts; cvx services never call it; self-call unreachable.
- Gauge principal/reward redirects: `withdraw` self-only; `transferFrom` needs an allowance (none exists); claimer/claim redirect paths are privileged (governance/admin) and only reach *pending* rewards.
- Stale approvals / migration paths: none (approval log scan across all custody tokens); no stale `isSdtStaking` entries; impls unchanged.
- Keeper-fee abuse beyond design: capped at 1%, once per service per cycle, cannot be repeated or steered; live value ≈ $0.16 now / ≈ $6.1 next window.
- Accounting edges (deposit/withdraw/claims): over-withdraw reverts; pro-rata claim math cannot over-claim a cycle; `sdtRewardCount` footgun only *under*-claims (funds stay in distributor; no attacker gain).

---

## 6. Conditional / latent list (exact preconditions; never E-U)

| # | Path | Precondition | Live value | Class |
|---|---|---|---|---|
| C1 | `processSdtRewards()` keeper fee | Be first to call when a cycle is unprocessed; pays gas | ~$0.16 now; ~$6.1 next window; $0 bribes | Designed bounty (not E-U) |
| C2 | Claimer UUPS upgrade → `claim_rewards_for(blackhole, claimer)` | 3-of-5 Safe `0xB0552b68` signs upgrade (or key compromise) | pending gauge rewards only (≈$607 now) | P-latent |
| C3 | Gauge admin `set_claimer` → redirect blackhole pending rewards | 1-of-1 Safe `0xe5d6D047` owner key | pending gauge rewards only | P-latent (prior-flagged) |
| C4 | SdtUtilities stray-balance capture (`convertAndStake*` stakes `balanceOf(address(this))`) | Tokens must be strayed/donated to SdtUtilities first | 0 today | Conditional (not protocol funds) |
| C5 | Distributor self-registration (`isStakingContract[distributor]=true`) | A future upgrade would have to add a distributor→`claimCvgSdtSimple` self-call; unreachable today | 0 today | Latent footgun |
| C6 | User footguns: `sdtRewardCount` too small drops rewards (stay in distributor unclaimable); user-set `minCvgSdtAmountOut` swap slippage MEV-able | user error / MEV | n/a | Footgun (no attacker gain beyond MEV on the user's own claim) |

**What would change the verdict:** an owner/claimer/gauge-admin key compromise (P), a governance upgrade adding a permissionless call path, or a StakeDAO-side gauge/proxy change (third-party). None is keyless today.

---

## 7. Methodology, sources, caveats

- On-chain reads via `cast` + JSON-RPC at blocks 26,182,xxx (2026-10-13); full history via Etherscan V2 logs (`SdtStakingCreated`, `Approval`); verified sources from Etherscan V2 for the service impl `0xdba75359…`, utility/fee-collector/cvx-service/beacons; storage-layout probing (`analysis/scan_slots.py`, `analysis/live_verify.sh`, `analysis/keeper_and_callinfo.sh`, `analysis/approval_scan.py`).
- Fork PoCs run locally and on CI (`.github/workflows/poc.yml`, public repo, read-only).
- Caveats: pricing not re-run (state/backing verified, not re-priced; H-O figure carries the prior pricing with a noted distributor-reward drawdown); the keeper-window figures are point-in-time and move with weekly gauge accrual; "designed bounty" classification follows the framework treatment of intended permissionless incentives.

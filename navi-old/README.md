# C2-54 — NAVI (Sui) old package versions: closure re-verification and residual quantification

**Date:** 2026-10-10 · **Chain:** Sui mainnet · **Status:** read-only; dev-inspect / dry-run only; **no transactions signed or sent**; public keyless endpoints only (Sui GraphQL + gRPC fullnode, DefiLlama/CoinGecko).

**Finding under test (ZOMBIE-HUNT-II C2-54):** *"NAVI old versions (Sui) — RewardFunds 1.5M/869k/385k raw; CLOSED (version=16 gate) — retained."*

**Verdict of this re-verification:** the closure is **CONFIRMED** for the main NAVI market (lineage A): every deployed old package version (v1–v25) aborts on the live version gate, only the current v26 executes, and no ungated value-moving path exists. Residual: **≤ ~$0.39 (dust)** of unprivileged extraction on NAVI's separate **staging deployment** (lineage B) due to a *different* bug — a documented reward-checkpoint flaw (missing checkpoint treated as index 0) — reachable only against 8 legacy active pools whose combined remaining budget and funds balances are dust-sized. The ~$875k of reward funds across both deployments is **not** attacker-extractable: it is user-claimable (H-O) and/or admin-withdrawable (P).

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| **Lineage A — NAVI main market** (original pkg `0xd899cf7d…`, 26 versions; Storage `0xbb4e2f4b…` v16, IncentiveV2 `0xf87a8acb…` v16, IncentiveV3 `0x62982dad…` v16) | **$0** | All v1–v25 abort on the version gate (`storage.version == constants::version()`); only v26 passes. No ungated value-moving entry in any version (52 versions / 818 modules scanned). No unprivileged version-field writer. | Admin `version_migrate` state-flip (privileged only) |
| **Lineage B — NAVI staging deployment** (original pkg `0xa49c5d1c…`, 21 versions; Storage/Incentive at version 15; current v21 `0xc371fc61…` matches) | **≤ $0.39 (dust)** | Current-version claim path is callable; the deprecated v1/v2 reward accounting reads a missing per-user checkpoint as index 0 → retroactive credit. Bounded by 8 active pools' remaining budgets + 2 dust funds balances (0.2818 vSUI + 0.2036 NAVX). Proven by dev-inspect payout (+15,918,193 raw vSUI). | Documented bug (navi-smart-contracts PR #13, closed unmerged); NAVX/CERT pools only |
| **Staging V2 funds pools** (USDT $98.5k + USDC $98.4k + dust) | **$0** | Their `IncentivePool`s are **inactive** (`pool_objs` has 8 entries, none USDT/USDC) and `get_pool_from_funds_pool` scans `pool_objs` only → unclaimable. Admin `withdraw_funds(&OwnerCap)` is the only path (cap `0xfe2f9147…` owned by active address `0xdf6bff0f…`) → **P**. | None for an attacker; key-loss would flip to S |
| **Oracle package** (`0xca441b44…`, 5 versions; PriceOracle v4) | **$0** | Version-gated (only v5 passes); all price writes require `OracleAdminCap`/`OracleFeederCap` (owner `0x39c70d4c…`); v5 keeper path only accepts signed Pyth/Supra/Switchboard data (by design). | Admin cap downgrade footgun (privileged only) |

**Total live extractable now: ~$0.39 (dust)** — main market $0 + staging ≤$0.39. **Confidence: high** (main closure: dynamic gate matrix over all 26 versions + static analysis of all modules; staging bound: mechanism proven by dev-inspect payout, budget arithmetic exact).

---

## 2. The mechanism, exactly

### 2.1 Lineage A version gate (why old versions are dead)

NAVI's lending package is one Sui upgrade lineage: **original package `0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca`, 26 versions**. Live objects carry a `version` field; every state-changing entry calls a gate that compares it against the constant compiled into that package version:

* **v1–v13:** inline check in `storage::version_verification` — `assert(storage.version == K)` else `abort 43000` (no `version`/`constants` module yet).
* **v14–v26:** `storage::version_verification` → `version::pre_check_version(storage.version)` → `assert(storage.version == constants::version())` else `abort 1400`.

Expected constants per version (extracted from bytecode; `storage` module for v1–v13, `constants` module for v14–v26):

| pkg v | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| expects | 2 | 2 | 3 | 3 | 3 | 5 | 5 | 5 | 6 | 6 | 6 | 6 | 6 | 7 | 8 | 8 | 9 | 10 | 10 | 11 | 12 | 13 | 14 | 15 | 15 | **16** |

Live `Storage` `0xbb4e2f4b…` is at **version 16** → only **v26** passes. The gate is called at the top of every value-moving path (directly or transitively through `storage::update_state` / balance functions and `incentive_v*::update_reward*` / claim paths). The `version` field has exactly one writer per object, all cap-gated (`storage::version_migrate(&StorageAdminCap,…)`, `incentive_v2::version_migrate(&OwnerCap,…)`, `incentive_v3::version_migrate` is `public(friend)`, `flash_loan::version_migrate(&StorageAdminCap,…)`) — no unprivileged writer, hence no bypass.

### 2.2 Lineage B staging checkpoint bug (the only live unprivileged path found — dust)

The staging deployment (`0xa49c5d1c…`, 21 versions; live Storage/Incentive version 15; current package v21 `0xc371fc61…`) is a separate NAVI codebase generation. Its deprecated `incentive_v2` claim path is *not* gated out (v21's constant 15 matches the live objects) and contains the **reward-checkpoint bug** documented in `naviprotocol/navi-smart-contracts` **PR #13 (closed unmerged, 2026-09-13)**: in `calculate_one`, a user absent from `index_rewards_paids` defaults `paid = 0`, so `total_rewards = index_reward × effective_amount` — i.e. an account that never held the asset appears to have earned the pool's entire historical index applied to its *current* balance, then claims it.

`claim_reward`/`claim_reward_non_entry`/`claim_reward_with_account_cap` iterate **only** `pool_objs` (8 active pools) via `get_pool_from_funds_pool`, and each payout is capped by `total_supply − distributed` (per pool) and by the funds-pool balance. Active pools reference only the **NAVX** (`0x015a4aa9…`, balance 0.2036 NAVX) and **vSUI/CERT** (`0x1ca8aff8…`, balance 50.11 vSUI) funds:

| active pool | funds | asset | option | remaining | index/RAY |
|---|---|---|---|---|---|
| `0x106cbb59…` | vSUI | 6 (haSUI) | 1 | 0.0657 vSUI | 0.0171 |
| `0xa0746535…` | vSUI | 6 | 3 | 0.1000 vSUI | 0.0854 |
| `0xe718ba2f…` | vSUI | 8 (NAVX) | 1 | 0.0668 vSUI | 0.00029 |
| `0x2e5a1810…` | vSUI | 8 | 3 | 0.0493 vSUI | 0.00064 |
| `0x9445141d…` | NAVX | 6 | 1 | 0.4382 NAVX | 0.0840 |
| `0xf8bc5a8c…` | NAVX | 6 | 1 | 0.9469 NAVX | 0.1664 |
| `0xa21c4406…` | NAVX | 6 | 3 | 1.0000 NAVX | 0.8545 |
| `0x903fbec2…` | NAVX | 8 | 1 | 0.6680 NAVX | 0.0029 |

**Maximum unprivileged extraction = min(Σ remaining, funds balances) = 0.2818 vSUI + 0.2036 NAVX ≈ $0.39** (dust). All 186 other pools (including every USDT/USDC-budget pool) are inactive and unreachable through the claim path. Deposits into the staging market are possible (`Pool<haSUI>`/`Pool<NAVX>` are live shared objects; Storage unpaused), so a fresh attacker can create the required balance, claim, and withdraw in one PTB.

---

## 3. Live-state assessment (all reads at Sui checkpoint 332,277,185 = CI run; local reads at 332,273,471–332,277,554; block/checkpoint recorded in artifacts)

### Lineage A — main market

| Object | Address | Type origin | version field | Notes |
|---|---|---|---|---|
| Storage | `0xbb4e2f4b6205c2e2a2db47aeb4f830796ec7c005f88537ee775986639bc442fe` | `0xd899cf7d…::storage::Storage` | **16** | `paused=false`, 35 reserves, ~999,553 users |
| IncentiveV2 | `0xf87a8acb8b81d14307894d12595541a73f19933f88e1326d5be349c7a6f7559c` | `0xe66f07e2…::incentive_v2::Incentive` | **16** | `pool_objs` empty; 9 V2 funds pools, all balance 0 |
| IncentiveV3 | `0x62982dad27fb10bb314b3384d5de8d2ac2d72ab2dbeae5d801dbdb9efa816c80` | `0x81c40844…::incentive_v3::Incentive` | **16** | 24 pools / 43 rules / 9 reward coin types, all `enable=true` |
| PriceOracle | `0x1568865ed9a0b5ec414220e8f79b3d04c77acc82358f6e5ae4635687392ffbef` | `0xca441b44…::oracle::PriceOracle` | 4 | only oracle v5 passes |
| StorageAdminCap | `0x538d34538c5e70743831869b9fd5e9f1d3a957a9e546651094496fd3e0113ec6` | — | — | owner `0x39c70d4c…` |
| OwnerCap (manage) | `0x40ef406d7db9a2257bf0f8357b2a6a0a61fd77f0e46057a70bb8627ac05779b8` | — | — | owner `0x39c70d4c…` |

Package versions/addresses: 26-entry map in `analysis/object-version-map.json`; v9=`0xe66f07e2…`, v22=`0x81c40844…`, v23=`0xee004123…` (Nov-2025 announcement), v24=`0x1e4a13a0…`, v25=`0xc37b8136…`, v26=`0x512f2826…` (current).

### Lineage B — staging deployment

| Object | Address | version field | Notes |
|---|---|---|---|
| Storage (sample; 10+ exist, all v15) | `0x111b9d70174462646e7e47e6fec5da9eb50cea14e6c5a55a910c8b0e44cd2913` | 15 | unpaused; 39 reserves; haSUI/NAVX pools live |
| IncentiveV2 (parent) | `0x952b6726bbcc08eb14f38a3632a3f98b823f301468d7de36f1d05faaef1bdd2a` | 15 | 194 pools (8 active), 7 funds |
| Funds pools | USDT `0xf78f9269…` ($98,479.81), USDC `0x6797966d…` ($98,417.09), vSUI `0x1ca8aff8…` (50.11 vSUI), NAVX `0x015a4aa9…` (0.2036 NAVX), haSUI `0x29659ecf…`, afSUI `0x68505acd…`, SUI `0x524e28ad…` | — | only vSUI/NAVX referenced by active pools |
| OwnerCap / StorageAdminCap | `0xfe2f914717cdadc594dcfbd70bdf0ecbe85b1cb7ad780487b42cd54d43b1b50f` / `0xc8a63170…` | — | owner `0xdf6bff0f…` (active; last sent tx 2026-07-27) |

### Reward funds — complete census (44 objects, $875,104.21 at 2026-10-10 ~02:40 UTC; see `analysis/reward-funds-census.json`)

| Deployment / type | objects | USD |
|---|---|---|
| Main `0x81c40844…::incentive_v3::RewardFund` | 15 | **$674,547.89** (vSUI $429.1k, DEEP $113.3k, FDUSD $78.3k, WAL $25.6k, NAVX $18.4k, NS $6.5k, BLUE $815, HAEDAL $594, IKA $577, stSUI $3) |
| Staging `0xacc64a32…::incentive_v3::RewardFund` | 13 | $3,499.58 |
| Main `0xe66f07e2…::incentive_v2::IncentiveFundsPool` | 9 | **$0** (all balances 0) |
| Staging `0xa49c5d1c…::incentive_v2::IncentiveFundsPool` | 7 | **$197,056.74** (USDT $98.5k + USDC $98.4k + dust; **admin-only, P**) |
| Legacy `…::incentive::IncentiveBal` (v1) | 59 | **$0** (all balances 0) |

Note: the finding's raw figures "1.5M/869k/385k" are point-in-time/approximate; the current exact census above supersedes them (1.5M ≈ NAVX fund; the others do not match today's balances — balances move with claims/deposits; e.g. three main funds decreased mid-census at 2026-10-10 02:33Z).

---

## 4. What an attacker can / cannot do

**Cannot (main market):**
* Call any old version's entry points against live state — dev-inspect matrix: v1–v13 → abort `43000` at `storage::version_verification`; v14–v25 → abort `1400` at `version::pre_check_version`; only v26 → SUCCESS. (CI artifact `gate-matrix.json`.)
* Claim rewards via an old version: v9 `incentive_v2::claim_reward` aborts `7999` at `incentive_v2::version_verification` (funds pool would have been empty anyway); v22 `incentive_v3::version_verification` aborts `1400` on the live IncentiveV3.
* Bypass the gate: no unprivileged writer of any `version` field; the gate is on the first instructions of every value path; private/friend helpers are unreachable externally.
* Extract from the legacy v1 `incentive` module: its claim family is ungated (the legacy `Incentive` object `0xaaf735bf…` has no version field) but user-scoped and **all 59 legacy `IncentiveBal` objects are empty** (balance 0).
* Drain the reward funds via the current path: `claim_reward*` is user-scoped (`tx_context::sender` or `AccountCap` owner), computes only accrued-minus-claimed with saturating math, marks claimed before `balance::split`, and enforces market-id consistency (`verify_market_storage_incentive` / `verify_market_incentive_funds`). A fresh user's claim succeeds with 0 payout (positive control, CI `claim-path.json`).
* Reach the staging USDT/USDC funds: their pools are inactive (`pool_objs` = 8, NAVX/vSUI only).
* Update prices via any old oracle version: gate + caps (see §1).

**Can (only residual found — dust):**
* On the **staging deployment** only: deposit haSUI/NAVX into a staging Storage, then `incentive_v2::claim_reward` (v21) as the sender, receiving `index_reward/RAY × effective` from an active pool (capped by remaining budget and fund balance), then withdraw the deposit. Proven payout: **+15,918,193 raw vSUI (0.0159 vSUI)** to an existing supplier with no prior claim record. Whole-surface bound: **≤ 0.2818 vSUI + 0.2036 NAVX ≈ $0.39**.

---

## 5. Proofs (dev-inspect only; no transactions)

* **Gate matrix, all 26 main-lineage versions** — CI `ci-out/gate-matrix.json` (v1–v13 abort 43000; v14–v25 abort 1400; v26 SUCCESS) + local `analysis/raw/gate_matrix_detail.txt`.
* **Claim-path tests** — CI `ci-out/claim-path.json`: v9 `claim_reward` → abort 7999 at `incentive_v2::version_verification`; v22 iv3 gate → 1400; v26 iv3 gate → SUCCESS. Local: v26 fresh-user `claim_reward_entry` → SUCCESS with zero payout.
* **Static gate analysis** — `analysis/gate-analysis.json` / `.md`: 52 package versions / 818 modules; per-version ungated public/entry inventory; no ungated value-moving path on live objects in any version; 543 immediate-abort deprecation stubs.
* **Staging checkpoint-bug proof** — `analysis/raw/sim_Bclaim2.json` + CI `ci-out/lineageB-claim.json`: sender `0x9f4c3fee…` (haSUI balance 929,608,909 units, absent from `index_rewards_paids`) claims vSUI → balance change **+15,918,193 CERT**. The `index_rewards_paids` table for that pool holds only 3 users, each at the current index (e.g. `0x67856930…` → 0 payout).
* **Object/version map** — `analysis/object-version-map.json`, `analysis/lineageB_pools_decoded.json` (all 194 staging pools decoded from BCS), `analysis/reward-funds-census.json`.
* **CI runs (public):**
  * Run 1 (gate matrix, claim tests, main census): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38018083607
  * Run 2 (adds lineage-B gate constants, staging claim proof, staging funds): see `ci-log.txt` / final run URL recorded below.
* Everything is reproducible from `ci/run.sh` (public Sui GraphQL + DefiLlama only; no keys).

---

## 6. Verdict, residual and latent risk

* **C2-54 closure CONFIRMED for the main market** (`version=16` gate): old versions are callable but abort; current version is the only executable one; no ungated path; reward funds are H-O/P, not E-U. `$0`.
* **Residual (new, bounded):** staging deployment checkpoint bug → **≤ $0.39 dust E-U** (NAVX/vSUI pools). The documented fix (navi-smart-contracts PR #13) was closed unmerged; NAVI's deprecated v1/v2 claim paths remain exploitable wherever active pools + non-empty funds exist — today only the staging deployment with dust balances. The staging USDT/USDC $196.9k is **P** (OwnerCap holder active), not claimable.
* **Latent / monitor:**
  * Main-market admin `version_migrate` could re-activate an old constant (e.g. set `Storage.version` to a value matching an old package); this is privileged-only but would immediately arm that version's code. Monitor `Storage.version` changes (currently 16).
  * Staging pools remain open (`closed_at=0`) with unclaimed budgets; if NAVI ever re-funds them (or adds USDT/USDC pools to `pool_objs`), the checkpoint bug becomes valuable. Monitor staging `pool_objs`/fund balances.
  * Legacy main `incentive` claims stay ungated (no version field) but have $0 balances; monitor if legacy funds are ever re-filled.

**Blockers:** none for the closure (gates verified live). Staging extraction requires a haSUI/NAVX deposit (markets unpaused; pools live) and is bounded by budgets/funds to dust.

---

## 7. Methodology & sources

* Sui public GraphQL (`https://graphql.mainnet.sui.io/graphql`) and gRPC (`fullnode.mainnet.sui.io:443`, reflection) — object reads, module disassembly, `ListDynamicFields`, and **dev-inspect** (`simulateTransaction`, checks disabled) for every dynamic test. No signing keys, no transactions.
* Package/object enumeration: `packageVersions`, per-version `package(address, version)` module disassembly (pagination-aware — GraphQL module connections default to 20 and silently truncate), `objects(filter:{type})`, dynamic-field BCS decoding (struct layouts from module disassembly).
* Prices: DefiLlama (`coins.llama.fi`), CoinGecko fallback for three legacy bridge tokens; USD at 2026-10-10 ~02:40 UTC.
* Web/source corroboration: NAVI developer docs (2025-11-17 & 2026-02-11 upgrade announcements), public contracts repo `naviprotocol/navi-smart-contracts` (v26 sources, PR #13), `naviprotocol/navi-sdk` (`address.ts`, `addressStg.ts`), HackenProof bounty page.
* Three child subagents contributed: reward-fund census, static gate analysis (52 versions/818 modules), adjacent packages (oracle/staging/objects) — all read-only, public endpoints only.

**Caveats:** dev-inspect is not a signed transaction; shared-object versions are resolved at latest; balances/prices are point-in-time (checkpoints recorded); the staging dust bound assumes a deposit path (pools exist and are shared, but a full deposit→claim→withdraw PTB was not executed end-to-end — the payout mechanism itself is dev-inspect-proven); USD figures use the stated price snapshot. No mainnet transactions were ever sent.

**Files index:** `README.md`, `summary.json`, `analysis/object-version-map.json`, `analysis/reward-funds-census.{json,md}`, `analysis/gate-analysis.{json,md}`, `analysis/adjacent-packages.{json,md}`, `analysis/lineageB_pools_decoded.json`, `analysis/raw/*` (raw reads, disassemblies, scripts), `ci/run.sh`, `ci-out/*` (CI proofs), `ci-log.txt`, `ci-artifacts/`.

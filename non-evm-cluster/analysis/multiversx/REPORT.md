# C2-55 · MultiversX remnants — abandoned & legacy custody deep-dive (`child-multiversx`)

**Status: READ-ONLY.** No transaction was signed or sent to any network. All mainnet interactions were
keyless HTTP GET/POST read queries (`api.multiversx.com`, `gateway.multiversx.com`, GitHub raw/tree APIs,
`coins.llama.fi`). No secrets or keyed endpoints appear in any file below.

- **Chain:** MultiversX mainnet (`erd_chain_id = 1`), epoch **2258**, reference block
  **nonce 35,578,436 / round 36,396,548 / ts`1791606898` = 2026-10-10T04:34:58Z** (`raw/latest_block_final.json`).
  All balance reads were taken 2026-10-10 03:15–04:37 UTC (API "latest" at fetch time; fetch timestamps in `raw/`).
- **Prices used** (all 2026-10-10): EGLD **$4.033253723488384** (`coins.llama.fi/prices/current/coingecko:elrond-erd-2`,
  ts `1791600774`); WEGLD **$4.026669** and MEX **$6.087087452169736e-07** (token `valueUsd` fields from
  `api.multiversx.com`, same window); EGLDMEX LP **$4.0692** (computed: 2 × 64,948.2603 WEGLD × $4.0267 / 128,523 LP supply).
- Scope: legacy/abandoned MultiversX (ex‑Elrond) contracts holding EGLD/ESDT value — legacy Maiar Exchange / xExchange v1.x
  farms, legacy locked-asset (LKMEX) plumbing, legacy delegation ("Community Delegation" v0.5.x), price-discovery
  remnants, legacy simple-lock, and accidental deposits. Task: measure exactly and classify **E-U / H-O / P / S**.

## 1. TL;DR

| # | Target | Live funds (top items) | USD | Class | Why closed / open |
|---|--------|------------------------|-----|-------|-------------------|
| 1 | **Legacy delegation "MultiversX Community Delegation"** `erd1qqq…shuwt` | 1,584,732.64 EGLD user-owed (136,994.54 EGLD liquid in contract; rest staked in nodes) | **$6,391,628.80** | **H-O** | Users' own stake; `claimRewards`/`unStake`/`unBond`/`stake` live (158/5/9/19 in last 200 txs). No permissionless value mover (dust cleanup & `claimUnusedFunds` are `#[only_owner]`). |
| 2 | **xExchange deprecated v2 farm** `erd1qqq…8aqhkg` | 40,509.198 EGLDMEX LP (+ virtual 377.2B-MEX unclaimed rewards minted as LKMEX on claim) | **$164,840.03** | **H-O** | Position owners only (`exitFarm`/`claimRewards`); live activity (daily claims, recent exit). |
| 3 | **Legacy farm v1.3-locked #0** `erd1qqq…m070jf` | 16,002.902 EGLDMEX LP | **$65,119.01** | **H-O** | `exitFarm` live (`getState=1 Active`). |
| 4 | **Legacy farm v1.3-locked #2** `erd1qqq…0zkpen` | 75,691,579,841 MEX (reward reserve; also custodies EGLDMEX via farm positions) | **$46,074.13** | **H-O** | `exitFarm` succeeds (12 recent successful exits); `migrateFromV1_2Farm` requires caller = old farm. |
| 5 | **Legacy proxy v1 (locked-asset proxy)** `erd1qqq…89fxnl` | LKMEX 28,715,843,579.84 + EGLDMEX 4,909.43 LP + MEXFARML 25.45B (locked-farm SFT, unpriced) + LKLP 518.1 | **$37,457.06** priced | **H-O** | Users exit daily (`exitFarmProxy`/`removeLiquidityProxy`); deployed code has no mint of wrapped tokens; migration needs proxy-minted wrapped SFT. |
| 6 | **Legacy metabonding staking** `erd1qqq…7zczse` | LKMEX 31,912,309,911.89 (= `getTotalLockedAssetSupply` 31,912,301,983.84) | **$19,425.30** | **H-O** | Users actively `unstake`/`unbond` (recent success); pause storage empty. |
| 7 | **Legacy farms v1.2 (3)** `…lxallh` / `…6lwewp` / `…zdry5` | 4,525.75 EGLDMEX LP; 2.54B + 0.277B + 31.11B MEX (incl. 10.06B farming reserve on #2) | **$39,066.86** | **H-O** | `exitFarm` requires farm token and is live (state=2=Migrate); `acceptFee` is a donation only; owner funcs gated by owner/router. |
| 8 | **Legacy farms v1.3-unlocked (8) + custom (1)** | 15.09B + 0.43B MEX | **$9,391.82** | **H-O** | Reward leftovers claimable by farm-position owners (screened; WASM exports + balances). |
| 9 | **Legacy simple-lock 0/1/2** `…z6vt84` / `…cw6ek` / `…yjapr5` | simple_lock_0: 1,869.08 WEGLD ($7,526) + LKLP 15,286.94 + locked-farm SFTs; simple_lock_1: 5,059,125 ASH ($1,654) + LKLP 352; simple_lock_2: spam tokens | **$9,209.08** | **H-O** | `unlockTokens` requires the contract-issued LK SFT (live success in simple_lock_1); `upgrade` is protocol-owner path. |
| 10 | **Maiar price-discovery v2/v1 (3)** `…3r492` / `…k7k8` / `…hhywk` | 292.35 WEGLD + launched tokens (ITHEUM/CRT/ASH) left for redeem | **$1,180.90** | **S (bricked)** | All in phase 4 = Redeem, but `redeem()` forwards to `simple_lock_legacy_0.lockTokens` which **does not exist** → tx fails, `returnMessage: "invalid function (not found)"` (proof `raw/pd0_fail_tx.json`). Owner-only `setLockingScAddress` is the only fix (latent P). |
| 11 | **Accidental LKMEX inside WEGLD-swap system SCs** `…3ntjj3` / `…drukln` | 150,003 + 318.44 LKMEX ($0.09 — LKMEX/MEX = $6.087e-7) + 10 MEX + 0.152 WEGLD ($0.61) | **$0.70** | **S** | Wrapping SC exposes `unwrapEgld/wrapEgld/rebalance` only — no ESDT withdrawal; tokens deposited by mistake are unrecoverable. |
| 12 | Locked-asset distribution (legacy) `erd1qqq…sphddm` | **0** (drained/claimed) | $0 | **S** | No EGLD/ESDT left; dead end. |

**Screened, no extraction interest:** Growth Dividend Fund & Ecosystem Growth Fund (419,136.93 EGLD each — governance
funds, P), Protocol Sustainability Fund (14,510.40 EGLD, P), 188 delegation providers (10,914,354.94 EGLD locked;
active H-O), WEGLD swap EGLD backing (584k EGLD; active system backing), 24 active v2 farms + current xExchange/DEX
contracts (active), five unlabelled MEX-holding SCs (identified as an active pair/lending/swap contracts, activity
hours old), Hatom/XOXNO/AshSwap etc. (live protocols).

## 2. Headline

| Category | USD | Confidence | Meaning |
|---|---|---:|---|
| **E-U** (external unprivileged extractable) | **$0.00** | **high** | Every value-moving endpoint found requires either a position SFT issued by that contract (farm/wrapped/LK/redeem token), a whitelisted caller, or the owner address. No third-party value mover is callable by outsiders. |
| **H-O** (holder/user-only recoverable) | **$6,782,224.00** | high | User stakes & positions (mostly the legacy delegation contract; farms/LKMEX plumbing ≈ $390.6k). |
| **P** (privileged / governance-only) | **$227.05** | high | Unclaimed SC `developerReward` across the 73 screened candidates (deployer-only). |
| **S** (stuck / bricked) | **$1,181.78** | high | Price-discovery leftovers bricked by a missing endpoint at the configured locking SC ($1,181.08) + accidental LKMEX/WEGLD at the WEGLD swap ($0.70). See §4.8–4.9. |

Machine-readable ledger: `raw/ledger.json` (per-token rows + totals); script: `scripts/compute_ledger.py`.

## 3. Discovery — criteria & counts

Target classes defined **before** scanning:
(a) legacy Maiar Exchange/xExchange v1.x contracts (farms v1.2/v1.3, deprecated v2 farm, proxy-dex v1, simple-lock,
locked-asset factory & distribution, price-discovery); (b) legacy Elrond/MultiversX delegation (the single central
"legacy delegation" contract); (c) LKMEX/MEX locked-asset plumbing; (d) accidental/stray ESDT deposits to abandoned
system SCs; (e) large SC accounts with EGLD/ESDT balances (discovery sweep).

Enumeration sources (not blog lists):
- `multiversx/mx-exchange-service` `src/config/mainnet.json` (authoritative live service config) → **73 contract
  addresses** (`raw/candidates.json`): router/pairs/proxy v1+v2/locked factory/metabonding/simple-lock ×3/WEGLD-swap ×3/price-discovery ×3/
  fees/energy/token-unstake/escrow/etc. + farms v1.2 ×3, v1.3 ×17, v2 ×25 (incl. 1 deprecated).
- `multiversx/mx-exchange-sc` (source, tags, `legacy-contracts/*`); `multiversx/mx-delegation-sc` (legacy delegation
  v0.5.x + `latest`); `multiversx/mx-api-service` config (`contracts.delegation`, `contracts.metabonding`);
  DefiLlama MultiversX protocol universe (27 protocols) for deprecated-version screening.
- Live sweeps: `GET /accounts?withBalance=true` (balance-sorted) pages 0–12 → top 325 accounts, all SCs > 100 EGLD
  inspected (`raw/top_accounts_p*.json`); `GET /providers` → 188 delegation providers; top holders of `LKMEX-aab910`
  and `MEX-455c57` → every SC holder identified.
- Verification/source of record: `GET /accounts/{addr}/verification` for all 75 addresses → 49 verified deployments,
  full deployed source extracted to `raw/sources_verified/` (520 files); WASM export lists for all 74 candidate
  deployments (`raw/wasm_exports.json`).

Counts: **75 addresses measured** (73 config candidates + legacy delegation + legacy metabonding; plus balance-sorted
account sweeps and provider/holder lists). EGLD + all ESDT/nonce-paged MetaESDT balances were read for the 20
primary legacy targets with exhaustive `/tokens` and `/nfts` pagination (`raw/full_balances.json`, `raw/candidate_balances.json`)
to avoid the 100-nonce truncation; **12 notable legacy targets hold non-zero value** and are dossiered below. Deep
source-level audit: 13 deployments (all xExchange legacy code paths that hold value + delegation); screened
not-source-verified: 5 (v1.3-unlocked/custom farms, simple-lock 0/1 — screened via WASM exports + live activity).

Note on measurement integrity: initial `/accounts/{addr}/nfts?size=100` reads truncated MetaESDT (LKMEX is split over
thousands of nonces). All headline totals were re-read with full pagination (e.g., proxy v1 LKMEX 14.48B → **28.72B**
after paging; metabonding 2.58B → **31.91B**, matching its own `getTotalLockedAssetSupply`).

## 4. Target dossiers

### 4.1 Legacy delegation — "MultiversX Community Delegation" (v0.5.8+)
- Address `erd1qqqqqqqqqqqqqpgqxwakt2g7u9atsnr03gqcgmhcv38pt7mkd94q6shuwt`, deployed `1596559368` (2020-08-04),
  owner `erd1ghg3vusfhy0wx92kvafw2kxhu2pdz8rrt3kr6yd3zapfwwwfd94qvnkddh`, `isUpgradeable=true`.
- **Live funds** (read 2026-10-10, epoch 2258): account balance **136,994.53627969887 EGLD**;
  `GET /delegation-legacy` (`raw/delegation_legacy_global.json`): `totalActiveStake = 1,536,016.913153813867855056`,
  `totalUnstakedStake = 2,983.086846186132144944`, `totalDeferredPaymentStake = 45,116.219335112700635512`,
  `totalWithdrawOnlyStake = 616.416316203580088866`, `numUsers = 35,601`; `getTotalDelegationCap = 1,539,000 EGLD`,
  `getServiceFee = 1000 (10%)`, `getMinimumStake = 10 EGLD`, `getOwnerMinStakeShare = 0`, `getNumBlocksBeforeUnBond =
  1,440,000`. **User-owed total = 1,584,732.6357 EGLD = $6,391,628.80**; liquid in contract = 136,994.54 EGLD
  ($552,533.72); remainder staked in the network for the contract's nodes.
- **Audit:** user endpoints `stake/unStake/unBond/claimRewards/delegateVote` act only on the caller
  (`latest/src/user_stake_endpoints.rs`: `require!(self.not_paused())`, caller-id checks; `unBond` needs the caller's
  entry). Owner-only: `dustCleanupActive/WaitingList` (both `#[only_owner]`), `claimUnusedFunds` (`#[only_owner]`,
  `latest/src/node_activation.rs`), node management, cap/fee setters, `pause`, `upgrade`.
- **Unprivileged paths tried:** none exist for third-party value; `getUnBondable` (user arg) and global views are
  read-only. **Classification: H-O (high).** Evidence of live withdrawal: last 200 txs = 158 `claimRewards`,
  19 `stake`, 9 `unBond`, 5 `unStake` over ~8 days (`raw/community_delegation_txs200.json`).
- Binary check: deployed exports ⊇ repo `v0_5_8_full` exports; deployed additionally has `delegateVote`, `getVotingPower`,
  `upgrade` (governance build), matching repo `latest`. Version view returns `"0.5.8"`.

### 4.2 Deprecated xExchange v2 farm (`farm-with-locked-rewards`)
- `erd1qqqqqqqqqqqqqpgqapxdp9gjxtg60mjwhle3n6h88zch9e7kkp2s8aqhkg`; `getState=1 (Active)`;
  `getFarmTokenSupply = 40,509,198,308,039,516,131,244` (= 40,509.198 units); LP token `EGLDMEX-0be9e5`.
- **Live funds:** **40,509.198308 EGLDMEX LP = $164,840.03** (LP priced from the live MEX/WEGLD pair
  `erd1qqq…p6shh2`: reserves 64,948.2603 WEGLD + 429,639,229,262 MEX, LP supply 128,523). Virtual remaining rewards:
  `getRewardReserve = 377,240,593,878,236,682,297,637,864,900` (≈377.2B MEX-equivalent, minted as LKMEX by the
  energy factory at claim time — no MEX is held for it). Contract holds no other tokens.
- **Audit:** `exitFarm/claimRewards/claimBoostedRewards` send only to the position owner (verified ABI + source
  `raw/sources_verified/farm_v2_deprecated_0/`, codeHash `580f656492023a423177b40510ab1623a259367fc3bab19c86563524a32434b9`).
  Live activity: 11 claims + 1 exit in last 12 txs; latest claim ts `1791594625`. **H-O (high).**

### 4.3 Legacy farms v1.3 "locked rewards" (source-verified, all 8)
- Largest: `…0zkpen` (see TL;DR #4): balance 75,691,579,841.10 MEX ($46,074.13), `getRewardReserve =
  50,861,632,739,248,945,314,481,243,378`, `getFarmTokenSupply = 153,527,809,287,059,405,758,397,071,441`,
  `getState=1`. `…m070jf`: 16,002.902 EGLDMEX LP ($65,119.01). Others hold small MEX/LP (total v1.3-locked ≈ $120.6k
  incl. custom incl. LP).
- **Audit (deployed source `elrond-wasm 0.28.0`, codeHash `6b9d9a0f…` for `…0zkpen`):**
  - `exitFarm` requires `State::Active` + own farm token → pays farming tokens + LKMEX via locked factory.
  - `migrateFromV1_2Farm` `require!(caller == config.old_farm_address)` (live config on `…0zkpen` points to v1.2 farm
    `…zdry5`, which no longer exposes any migrate endpoint) → dead migration switch, not callable by users.
  - `setRpsAndStartRewards` also requires `caller == old_farm_address`; `setFarmMigrationConfig`/`setFarmTokenSupply`
    `#[only_owner]`.
- Live proof: 12 recent successful `exitFarm`. **H-O (high).**

### 4.4 Legacy farms v1.2 (3) + migration plumbing
- `…lxallh` (4,525.752 EGLDMEX = $18,416.19 + 2,543,550,050.016 MEX = $1,548.28 + reserve 2,543.55B-raw-value matched),
  `…6lwewp` (276,572,401.64 MEX; LP side ≈ 0 after EGLDUSDC migration), `…zdry5` (farming token = MEX itself;
  farming reserve `0x207fcbef1a9fb3f99a724c81` = 10,058,016,944.46 MEX, reward reserve 20.18B MEX; contract balance
  31,105,504,352.67 MEX = reserve + farming reserve + ~0.87B MEX fees).
- **Audit (verified source, codeHash `bac43c58…`):** `exitFarm` `require!(state == State::Migrate)` — live state = **2
  (Migrate)** → exits allowed (earn LP + attributed compounded MEX); farm token supply check binds payouts to position
  owners. `acceptFee` is **permissionless but deposit-only** (takes MEX, adds to fee/reward accounting — cannot move
  value out). Owner funcs (`setPerBlockRewardAmount`, `end_produce_rewards_as_owner`, `pause/resume`, setters) gated by
  `require_permissions` (owner **or router**). Live proofs: recent successful `exitFarm` on all three.
  **H-O (high).** The owner/router could redirect the fee surplus (`setPerBlockRewardAmount` → distributes fees into
  `reward_per_share`) — privileged, not extractable.

### 4.5 Legacy proxy v1 (`proxy-dex`, locked-asset)
- `erd1qqqqqqqqqqqqqpgqrc4pg2xarca9z34njcxeur622qmfjp8w2jps89fxnl`, codeHash
  `8bab3716a1a92bad1b5cb77b97a09cce1ffabd56b954d881b93e1b480984c3d2`, verified full source extracted.
- **Live funds (all-nonce paged):** LKMEX **28,715,843,579.84** ($17,479.59) + EGLDMEX **4,909.433** LP ($19,977.47) +
  MEXFARML-28d646 25,449,846,412.56 (locked-farm MetaESDT, unpriced) + LKLP-03a2fa 518.10 + EGLDMEXFL/MEXFARM/MEXRIDE
  locked-position SFTs (unpriced). Balance itself 0.0969 EGLD.
- **Audit:** deployed endpoints = `exitFarmProxy`, `removeLiquidityProxy`, `migrateV1_2Position` (+ owner setters).
  `exitFarmProxy` requires the proxy-minted wrapped-farm SFT; `removeLiquidityProxy` requires wrapped-LP SFT and maps
  `locked_assets_invested` exactly; `migrateV1_2Position` requires wrapped-farm SFT + intermediated farm and relays to
  the old farm's `migrateToNewFarm` (old farm no longer exports it → migration fails, exits remain available). No
  endpoint mints wrapped SFTs and none moves third-party value; burning on exit is bounded by the user's own wrapped
  amount. Live proof: `exitFarmProxy`/`removeLiquidityProxy` succeed daily (30 recent, latest ts `1791521611` — 2026-10-09).
  **H-O (high).**

### 4.6 Legacy metabonding staking
- `erd1qqqqqqqqqqqqqpgqt7tyyswqvplpcqnhwe20xqrj7q7ap27d2jps7zczse`, verified source (`raw/sources_verified/metabonding_staking_legacy/`,
  codeHash `4a9b2afa13eca738b1804c48b82a961afd67adcbbf2aa518052fa124ac060bea`).
- **Live funds:** LKMEX **31,912,309,911.89** ($19,425.30); `getTotalLockedAssetSupply = 31,912,301,983.84` EGLD-raw
  (matches stake accounting, delta ≈ 7,928 LKMEX = stray donations); 687,201.10 MEX ($0.42).
- **Audit:** `stakeLockedAsset/unstake/unbond` require `not_paused` and operate on the caller's entry only; `unbond`
  sends the caller's LKMEX. `pause/unpause` owner-only. Pause storage unset (not paused). Live proof: recent
  `unstake`/`unbond` successes (last 50 txs are all unbond/unstake; latest ts `1790789664`). **H-O (high).**

### 4.7 Legacy simple-lock family (0/1/2)
- `…z6vt84` (`LKLP-a35a60` 15,286.94, WEGLD 1,869.08 = $7,526.15, ITHEUM/CRT/ASH, locked-farm SFTs),
  `…cw6ek` (ASH 5,059,125.13 = $1,654.19, LKLP 352.01, locked-farm SFTs), `…yjapr5` (spam-token dust).
- **Audit:** deployed endpoints are `unlockTokens`, `exitFarmLockedToken`, `farmClaimRewardsLockedToken`,
  `removeLiquidityLockedToken` + `upgrade` (protocol-owner) — **no `lockTokens`** (confirmed by `vm-values/query`:
  "function not found"). `unlockTokens` burns the contract-issued LK token and returns the original tokens
  (verified source `simple_lock_legacy_2`; `unlockTokens` succeeds in simple_lock_1 recently, latest `1790367372`).
  **H-O (high)** for token holders; the spam tokens sent directly to `…yjapr5` are unrecoverable (**S**, ≈$1, plus a
  few hundred WEGLD-backed spam tokens each of ≤50 WEGLD nominal but with no market). Note: these contracts predate
  the v2 simple-lock (`locked-asset/simple-lock`) that still has `lockTokens`.

### 4.8 Maiar price-discovery (v1/v2) — the one genuine "bricked" finding
- `…3r492`, `…k7k8`, `…hhywk`. All three: `getCurrentPhase = 4` (**Redeem**), `getLockingScAddress` = raw
  `0000000000000000050083e5224b667e199b5427248aa882841e617587ba5483` = bech32
  **`erd1qqqqqqqqqqqqqpgqs0jjyjmx0cvek4p8yj923q5yreshtpa62jpsz6vt84` = simple_lock_legacy_0** (decoded here).
- **Live funds:** 97.548848 + 49.335008 + 145.461604 WEGLD (**$1,177.18**) + launched tokens (12,729.96 ITHEUM $2.82,
  2,293.66 CRT $0.17, 2,760.03 ASH $0.90) — total **$1,180.90**, held for redeem-SFT holders.
- **Mechanism:** `redeem()` (verified source `price-discovery` elrond-wasm 0.36.1) mints the pro-rata bought tokens and
  calls `lock_tokens_and_forward` → `lockTokens` on the configured locking SC. The legacy simple-lock only exposes
  `unlockTokens` (no `lockTokens`), so **every redeem reverts**: raw proof `raw/pd0_fail_tx.json`
  (`txHash 62f1ce1040951db5beea265e6cb20e09ed33a00d289035ffb0b87b262a7e7bd4`, 2025-11-22, status `fail`,
  SCR `returnMessage: "invalid function (not found)"`); 5 failed redeems total Dec 2024–Nov 2025 with no successful redeem in
  that window; PD_1 has the identical code hash and PD_2 the same verified source, same phase and same locking SC, so the
  same call path bricks all three. `withdraw` is not allowed in Redeem phase.
- **Classification: S (bricked) at contract level; latent P** = owner-only `setLockingScAddress` can repoint to a
  working locker (or `upgrade`). No E-U path. Confidence: high (direct revert proof).

### 4.9 Accidental ESDT inside WEGLD-swap system SCs — stuck
- Shard-1 `…3ntjj3` holds **150,003 LKMEX** ($0.09) + `EGLDMEXF-5bcc57` 0.0732; shard-2 `…drukln` holds
  **318.441 LKMEX** ($0.0002) + 10 MEX + 0.152 WEGLD ($0.61). Deployed exports: `wrapEgld/unwrapEgld/getLockedEgldBalance/
  isPaused/pause/unpause/rebalance/callBack` — **no ESDT withdrawal**; `rebalance` (owner) moves EGLD only.
  **S (high), total $0.70.** (Their EGLD balances 303,770/261,030/18,942 EGLD are active WEGLD backing — not remnants.)

### 4.10 Locked-asset distribution (legacy) — empty
- `…sphddm`: zero EGLD, zero tokens (fully claimed). Endpoints `claimLockedAssets/setCommunityDistribution/...` exist
  but nothing to claim. Dead end (**S/empty**).

### 4.11 Locked-asset factory (LKMEX minter/owner) — no balance, roles only
- `…4q7th` owns `LKMEX-aab910`; verified source; `unlockAssets` is **permissionless** and unlocks the caller's own
  LKMEX against the on-chain schedule (all 2021–22 milestones now matured → 100% unlockable; confirmed by live
  successful `unlockAssets` txs, latest ts `1791572581`). `createAndForward` requires caller ∈ whitelist (farms/proxy);
  `pause/whitelist/setBurnRole/setTransferRole` owner-only; `isPaused` unset. Holds no funds (its 108 LKMEX nonces are
  zero-balance placeholders). **No E-U** (unlock only mints MEX to the caller against their own burned LKMEX).

### 4.12 Screened-out classes (no remnant value or active)
- Foundation/governance funds: Growth Dividend Fund `…kl58yg` 419,136.93 EGLD; Ecosystem Growth Fund `…pt29xm`
  419,136.93 EGLD; Protocol Sustainability Fund `…ntl2g3` 14,510.40 EGLD — **P**, not abandoned (no unprivileged path).
- Legacy simple-lock `upgrade`/farm `pause`-family functions owned by `erd1ss6u80ruas2phpmr82r42xnkd6rxy40g9jl69frppl4qez9w2jpsqj8x97`
  (xExchange ops account; also MEX owner) — privileged.
- Unlabelled large-MEX SCs `…j939`, `…5tqk`, `…x7me7`, `…sccx`, `…krxs`: identified as an active lending market
  (redeem/reduceReserves/setBorrowCap), an active AMM (addLiquidity/swapTokensFixedInput = MEX/USDC pair deployed
  2022-02), etc.; txs hours old; excluded (active).
- 188 delegation providers (10.91M EGLD locked) — active delegation, H-O by users, out of "remnant" scope.
- 24 active v2 farms + current xExchange contracts — active (kept as reference rows in `raw/candidate_balances.json`).

## 5. E-U audit — endpoint/gate inventory (what was tested)

Static gates (source-verified deployments) + live read-only probes (`vm-values/query`) on every target that holds value:

| Target | Public state-changers | Gate that blocks third-party extraction | Probe/evidence |
|---|---|---|---|
| proxy v1 | exitFarmProxy, removeLiquidityProxy, migrateV1_2Position | requires proxy-minted wrapped SFT; burn ≤ user wrapped amount; migration relay to now-endpointless old farm | source + live exits |
| farm v1.2 ×3 | exitFarm, acceptFee | exit needs own farm token, `State::Migrate` (live=2); acceptFee = donation | `getState`=2; source |
| farm v1.3-locked ×8 | exitFarm, migrateFromV1_2Farm, setRpsAndStartRewards | own farm token; caller==old farm for migration/rps | source v1.6 module + live config; `getState`=1 |
| farm v2 deprecated | enter/claim/exit/merge/boosted | own farm token; payouts to owner | source + live claims |
| metabonding | stakeLockedAsset, unstake, unbond | caller's own entry only; not paused | source + live unbonds |
| simple lock 0/1/2 | unlockTokens, exitFarmLockedToken, removeLiquidityLockedToken, upgrade | contract-issued LK/proxy SFT; upgrade owner/protocol | exports + live unlocks |
| community delegation | stake, unStake, unBond, claimRewards, delegateVote | per-caller accounting; owner-only for nodes/dust/claimUnusedFunds | repo latest source; live txs |
| price discovery ×3 | deposit(closed), withdraw(closed), redeem | `redeem` reverts (missing `lockTokens` at locker) — nobody can move the pools | failed tx returnMessage |
| locked factory | unlockAssets, createAndForward | unlockAssets touches only caller's LKMEX; createAndForward whitelist-only | source + live unlocks |
| WEGLD swap shards | wrap/unwrap/rebalance | none moves ESDT | exports |

**Result: E-U = $0.00 (high confidence).** No endpoint was found that lets an unprivileged caller move value not
already owned by them; the two most dangerous relays (`migrateV1_2Position`, `migrateFromV1_2Farm`) are bound to
contract-minted tokens and old-farm callers respectively.

## 6. Negative results / dead ends (do not re-investigate)
- Locked-asset distribution `…sphddm`: zero balance (fully claimed).
- Locked-asset factory `…4q7th`: zero balance; funds roles only.
- Price discovery leftovers: redeem reverts with `invalid function (not found)` — measured, not assumed.
- WEGLD-swap stray LKMEX: unrecoverable (no ESDT withdraw in code).
- Migration endpoints: dead switches (old farm cannot call; proxy migration relays to a removed endpoint).
- v1.2 farm "surplus" MEX beyond reserves is tiny accounting dust (fees), not extractable.
- Farm token supplies / wrapped positions are bound to their SFT holders; no forging path (all SFTs are contract-issued
  with on-chain attributes).

## 7. Confidence, caveats & blockers
- **Confidence high** for every classification above: values are exact on-chain reads (block-ref epoch 2258), and the
  decisive gates are either source-verified (49 deployments, full sources in `raw/sources_verified/`) or proven by
  live transaction outcomes.
- Caveats:
  - LKMEX is valued at MEX parity ($6.087e-7). Unlock is live and matured (100%), but LKMEX outstanding (434.7B,
    ~$264.6k) is illiquid if force-sold; the ledger's LKMEX lines (~$37k across proxy+metabonding) are small relative
    to the delegation figure, so this does not change the headline materially.
  - The community-delegation stake is reported as "user-owed" (owner min-stake share = 0). Unbonding is subject to the
    network's 1,440,000-block unbond period; claims/unstakes are live.
  - `MEXFARML`, `LKLP`, locked-farm position SFTs and simple-lock locked SFTs are reported raw/unpriced (no liquid
    market); their USD is excluded, so H-O is conservative (understated), E-U unaffected.
  - Not source-verified: v1.3-unlocked/custom farms, simple-lock 0/1, community delegation v0.5.8 binary
    (repo binary export-diffed; governance delta matched). Screened via WASM exports + live activity; no public
    value-mover surfaced.
  - "No E-U" is bounded to the targets measured (75 addresses / 12 dossiers). A zero-day in the deployed legacy WASM
    itself cannot be excluded by source audit alone (fork-PoC would be the next step); nothing in the runtime evidence
    (5+ years of operation, active third-party exits) suggests a hidden drain endpoint.
- **Blockers for extraction:** none for users (H-O paths live); extraction bricked for PD pools (S) until owner action.

## 8. Files index
- `REPORT.md` (this file), `summary.json`.
- `scripts/`: `mvx_api.sh` (API helper), `fetch_balances.py`, `fetch_full_balances.py` (nonce-paged), `build_candidates.py`,
  `summarize_balances.py`, `wasm_exports.py`, `wasm_fetch.py`, `fetch_verification.py`, `extract_verified_sources.py`,
  `vmq.py` (vm-values/query), `compute_ledger.py`.
- `raw/`: `latest_blocks.json`, `latest_block_final.json`, `price_egld.json`, `mx_exchange_service_mainnet.json`,
  `candidates.json`, `candidate_balances.json`, `full_balances.json`, `ledger.json`, `wasm_exports.json`,
  `providers_all.json`, `delegation_legacy_global.json`, `community_delegation_txs200.json`, `pd0_fail_tx.json`,
  `top_accounts_p0..p12.json`, `verification/` (54 payloads; 49 verified), `verification_summary.json`, `sources/` (repo files),
  `sources_verified/` (520 deployed-source files), `delegation_v0_5_8_full.wasm`.
- Key addresses (bech32): delegation `erd1qqqqqqqqqqqqqpgqxwakt2g7u9atsnr03gqcgmhcv38pt7mkd94q6shuwt`;
  proxy v1 `erd1qqqqqqqqqqqqqpgqrc4pg2xarca9z34njcxeur622qmfjp8w2jps89fxnl`;
  metabonding `erd1qqqqqqqqqqqqqpgqt7tyyswqvplpcqnhwe20xqrj7q7ap27d2jps7zczse`;
  deprecated v2 farm `erd1qqqqqqqqqqqqqpgqapxdp9gjxtg60mjwhle3n6h88zch9e7kkp2s8aqhkg`;
  v1.3-locked#0 `erd1qqqqqqqqqqqqqpgqyawg3d9r4l27zue7e9sz7djf7p9aj3sz2jpsm070jf`;
  v1.3-locked#2 `erd1qqqqqqqqqqqqqpgq7qhsw8kffad85jtt79t9ym0a4ycvan9a2jps0zkpen`;
  simple locks `…s0jjyjmx0cvek4p8yj923q5yreshtpa62jpsz6vt84`, `…gqawujux7w60sjhm8xdx3n0ed8v9h7kpqu2jpsecw6ek`,
  `…gq6nu2t8lzakmcfmu4pu5trjdarca587hn2jpsyjapr5`; PDs `…gq38cmvwwkujae3c0xmc9p9554jjctkv4w2jps83r492`,
  `…gq666ta9cwtmjn6dtzv9fhfcmahkjmzhg62jps49k7k8`, `…gqq93kw6jngqjugfyd7pf555lwurfg2z5e2jpsnhhywk`.

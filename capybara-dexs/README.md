# Capybara Dexs (Kaia) — live extractable-value assessment (L2 Phase-2, zombie-hunt II)

**Date:** 2026-10-13 · **Chain:** Kaia (8217) · **Status:** read-only; PoC fork-verified on CI only; **no mainnet transactions signed or sent**
**Target:** Capybara Dexs — Wombat-exchange fork ("DynamicPool" + "HighCovRatioFeePool" lineage) · 9 pools, 24 assets, 1 staking master
**Evidence blocks:** state dump `229,631,779` · fork PoC `229,673,758` · triage `229,512,567`
**CI (7/7 PASS):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38364396117

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why open/closed | Latent risk |
|---|---|---|---|
| **KRWO leg, pool `0x4b63ec62`** (USDT→KRWO) | **$13.55** one-shot (200 USDT → 284,871.7 KRWO ≈ $213.6 at market FX) | Pool's KRWO oracle = 0.000667 USDT/KRWO (implies USD/KRW 1500); market USD/KRW ≈ **1334** → KRWO ≈ $0.000750. Pool sells KRWO at ~0.000702 → 6.8% edge. Bounded by pool's KRWO cash ($1.14k) and price impact. **Fork-verified exact execution.** | Realization depends on redeeming/selling KRWO at ~par (issuer GimSwap / Kaia DEX). If not realizable, edge ≈ $0. |
| **wGCKLAY leg, pool `0x5cde6338`** (WKLAY→wGCKLAY) | **$7.33** one-shot (30,000 WKLAY → 24,680.6 wGCKLAY = 30,157.05 WKLAY at the live GCKLAY rate) | Pool cov-ratio skew (WKLAY r=0.479 vs wGCKLAY r=1.201); oracle itself is **accurate** (live GCKLAY rate). 0.52% edge, bounded by pool wGCKLAY cash ($7.1k). Fork-verified. | Realization via wGCKLAY.unwrap → GCKLAY → unbond (delay/permissioning unknown) or DEX sale. |
| Plain pools skew edges (USDC→USDT `0x540cce8e`, stgUSDC→stgUSDT `0x2c0537f3`) | **$1.15** combined (measured at analysis block) | Pool ratio skew in 2-asset plain pools | − |
| **Same-asset deposit→withdraw** (the "deposit bonus") | **$0** | Deployed deposit mints extra LP for under-covered assets, but the withdrawal equilibrium haircut claws it back **exactly** (fork-verified: 1000 USDT → 1329.2 LP → 1000.000000 USDT) | None |
| Swaps generally | ≈ market (measured all pairs/sizes) | Wombat-style invariant + dynamic price factors keep prices within ~0–6% of market; cycles negative after fees | Stale WKLAY oracles (0.1428/0.1562/0.0969 vs market 0.0466) are largely cancelled by the pools' out-of-equilibrium state; only the small windows above remain |
| **LP holders (H-O)** | **≈ $155.3k** redeemable (cash value; liability $161.2k) | ~80–90% of every LP supply is staked in the MasterWombat proxy (`0x3CA3…`); stakers withdraw successfully **weekly** (last: 2026-10-12). Fork-verified LP→underlying exit (1000 LP-WKLAY → 1044.35 WKLAY). | Owner can upgrade pools and divert (see P) |
| **Owner (P)** | **≈ $158.7k** (all pool underlying) + **$2.12k** tip buckets | ProxyAdmin `0xa1588a71…` owner = EOA `0x663434b7…`; pool owner/dev/feeTo = same EOA; assets owned by same EOA (`setPool` redirects underlying); `transferTipBucket` owner-only; `fillPool` dev-only | Single EOA key; unverified proxy code |
| **MasterWombatV3 farm** | **$0** | `allocPoint`=0 for all pools (deprecated getter), rewarders = `0x0`, `voter` = `0x0`, `pendingTokens` empty; no WOM-style rewards accrue. Master holds only user-staked LP (H-O) | − |
| Dust pool `0x4c7216d5` | **$0** (1 gwei stKAIA) | Single-asset dust pool; `tipBucketBalance` underflows (cosmetic) | − |

**Total live extractable by an external unprivileged attacker (E-U): ≈ $22.4 upper bound; ≈ $9 conservative floor (excluding KRWO realization risk).**
**Confidence: medium-high** — mechanics are fork-verified against the deployed bytecode; the KRWO realization leg is the main uncertainty.

---

## 2. What Capybara is, and the class under test

Capybara Dexs is a Klaytn/Kaia deployment of a **Wombat-exchange fork**: a stableswap with asset/liability accounting, per-asset LP tokens ("Assets"), coverage-ratio fees and dynamic relative-price oracles.

* 9 pool proxies (EIP-1967) sharing implementation `0x974205ce…` (35.8 kB, solc 0.8.18, **unverified**), e.g. `0x6389dBfa…`, `0x5cDE6338…`, `0x4b63eC62…`.
* 24 Asset (LP) tokens (some proxied, all unverified) — e.g. `LP-WKLAY` `0x92E9850c…`, `LP-stKAIA` `0xb10528E8…`, `LP-KRWO` `0xc608ee9E…`.
* 1 staking master proxy `0x3CA30C862769b5de7987D2E2db4c1A72800A1Da1` ("Capybara: Boostedmaster proxy", impl `0x5953ffb5…`, solc 0.8.18) — a **MasterWombatV3** variant (errors renamed `POOL_*`, no `wom()`/`veWom()` getters).
* ProxyAdmin `0xa1588a71d8efff6e5872888ff294ba7bf5817eee` (owner = EOA `0x663434b7099f17B7238291A09c6a0b3a237A4fAD`).

Deployed fingerprints: custom errors `POOL_FORBIDDEN()=0xcc83193d`, `POOL_SAME_ADDRESS()=0x6635667a`, `POOL_EXPIRED()=0xe69cb5ab`, `POOL_ASSET_NOT_EXISTS()=0xf74d709d`, `POOL_ZERO_LIQUIDITY()=0x74ff5c20`; `toUint256` revert string `"value must be positive"`. The deployed deposit math deviates from upstream Wombat (`exactDepositLiquidityInEquilImpl`) for under-covered assets in dynamic pools — behaviour modelled and bounded by fork tests (see §5.2).

The class under test is the standard "abandoned stableswap with residual TVL" surface: pool math (invariant/rounding), LP mint/burn, dynamic-oracle mispricing, farm reward accounting, and admin gating. There is **no factory, no k-invariant, no skim/sync** (Wombat architecture; the analogue "tip bucket" is owner-only, §5.4).

---

## 3. Live-state assessment (block 229,631,779; re-verified at fork block 229,673,758)

### 3.1 Pools (all unpaused, owner/dev/feeTo = `0x663434b7…`)

| pool | assets (underlying) | amp | haircut | start/end cov ratio | mintFeeThr |
|---|---|---|---|---|---|
| `0x6389dBfa…` | USDT, WETH, WKLAY | 0.1 | 0.04% | 1.1 / 1.8 | 0.1 |
| `0x5CDE6338…` | WKLAY, sKLAY, stKAIA, wGCKLAY, npKLAY | 0.002 | 0.002% | 1.2 / 1.5 | 0.01 |
| `0x4b63eC62…` | USDT, KRWO, WKLAY | 0.1 | 0.04% | 1.2 / 1.8 | 10 |
| `0x1de15784…` | stgUSDT, stgWETH, WKLAY | 0.1 | 0.04% | 5.0 / 10.0 | 10 |
| `0x540cce8e…` | USDT, USDC (plain, no oracle) | 0.00025 | 0.001% | 5.0 / 10.0 | 0.01 |
| `0x2c0537f3…` | stgUSDT, stgUSDC (plain) | 0.00025 | 0.001% | 5.0 / 10.0 | 10 |
| `0x005a8ed5…` | rstKAIA, stKAIA | 0.002 | 0.002% | 1.5 / 1.8 | 0.01 |
| `0x872e7e74…` | USDT, WALK, GRND | 0.1 | 0.04% | 1.5 / 1.8 | 0.1 |
| `0x4c7216d5…` | stKAIA (dust: 1 gwei) | 0.002 | 0.002% | 1.5 / 1.8 | 0.01 |

### 3.2 Value (prices: DefiLlama + on-chain rates; USD/KRW 1334)

* Underlying held by asset contracts: **$158,724.07**
* Pool `cash` (accounting): **$155,317.75** · LP `liability` claims: **$161,249.23**
* Top positions: stKAIA 1.492M ($76.8k, pool `0x5CDE`), WKLAY 660k ($30.8k, `0x6389`), WKLAY 238k ($11.1k, `0x1de1`), wGCKLAY 124k ($7.1k), WKLAY 142k ($6.6k), USDT 4.9k ($4.9k), rstKAIA 74.5k ($3.9k), stgWETH 1.44 ($3.6k), stKAIA 56.6k ($2.9k), WETH 0.91 ($2.3k), USDT pools ($1.8k, $1.7k, $1.7k, $1.2k) …
* Full table: `analysis/final_valuation.json`. Drift vs triage ($167,342 @ block 229,512,567): −5% (prices + the won's appreciation vs the KRWO oracle).

### 3.3 Roles / gating (all verified by call)

| Actor | Address | Powers |
|---|---|---|
| Owner/dev/feeTo (all pools) | EOA `0x663434b7099f17B7238291A09c6a0b3a237A4fAD` (no code) | `pause`, `setAmpFactor`, `setHaircutRate`, `setFeeTo`, `transferTipBucket`, `removeAsset`, `fillPool` (dev) |
| ProxyAdmin (pools + master) | `0xa1588a71d8efff6e5872888ff294ba7bf5817eee` (5,267 B), owner = same EOA | `upgrade` / `upgradeAndCall` on every pool and the master |
| Asset owners (24 LP tokens) | same EOA | `setPool` (redirect pool link), `setMaxSupply` |
| Master owner | `0x5280C2D41DBBb9E17664A6C560194d99f329bBb6` | `pause`, `setVoter`, `emergencyWomWithdraw`, `setRewarder` |
| Master state | `voter=0x0`, `basePartition=1000`, rewarders `0x0`, `paused=false` | farm dormant; no rewards accruing |

### 3.4 Oracles (dynamic pools)

* `getRelativePrice()` per asset: WKLAY `1.0` (base, pool `0x5CDE`), sKLAY `1.45926`, stKAIA `1.11886`, wGCKLAY `1.22195`, npKLAY `1.11209`; pool `0x6389`: USDT `1.0`, WETH `2480.43`, **WKLAY `0.14281` (stored, stale vs market 0.0466)**; pool `0x4b63eC62`: USDT `1.0`, **KRWO `0.000667` (stored, stale vs market 0.000750)**, WKLAY `0.09693`; pool `0x1de1`: stgUSDT `1.0`, stgWETH `3274.98`, WKLAY `0.15625`.
* stKAIA / wGCKLAY oracles are **computed live on-chain** (staking + GCKLAY contracts). Fork test asserts `P(wGCKLAY) == GCKLAY rate = 1.221947701805343276` (exact). WKLAY and KRWO are stored values.

---

## 4. What an attacker can and cannot do (exact call paths)

**Can (fork-verified):**

1. **KRWO stale-oracle arb — `pool 0x4b63eC62`, ≈ +$13.55**
   `USDT.approve(pool, 200e6)` → `pool.swap(USDT, KRWO, 200e6, 0, attacker, deadline)` → 284,871.700641 KRWO (quote == execution, fork-verified). Or the equivalent `deposit(USDT, 200e6, …)` → `withdrawFromOtherAsset(USDT, KRWO, lp, …)` → same 284,871.700641 KRWO. At market FX (1334 KRW/USD) that is $213.56 for $200 → +$13.55. Optimum at ~200 USDT (larger sizes lose: +$7.85 @400, −$26.8 @600 — price impact + cov-ratio effects). Preconditions: 200 USDT; gas ≈ 0.85–0.97M.
2. **wGCKLAY skew edge — `pool 0x5CDE6338`, ≈ +$7.33**
   `WKLAY.approve(pool, 30,000e18)` → `pool.swap(WKLAY, wGCKLAY, 30,000e18, 0, …)` → 24,680.589 wGCKLAY, worth 30,157.05 WKLAY at the live GCKLAY rate (1.2219477) → +157.05 WKLAY (+0.52%) ≈ +$7.33. Realization: `wGCKLAY.unwrap()` → GCKLAY → unbond to KLAY (delay/process), or DEX sale. Gas ≈ 0.46M.
3. **Plain-pool skew edges** (measured at analysis block, deployed quotes): `USDC→USDT` pool `0x540cce8e` +$0.55 @300 USDC; `stgUSDC→stgUSDT` pool `0x2c0537f3` +$0.60 @100 stgUSDC; `WKLAY→stgWETH` pool `0x1de15784` +$0.38 @1,000 WKLAY.

**Cannot (verified dead ends):**

* **Same-asset deposit→withdraw "bonus" capture** — the deployed deposit mints extra LP for under-covered assets (e.g. +47% liability for USDT in `0x6389`), but the withdrawal equilibrium haircut claws it back exactly: fork test deposits 1000 USDT → 1329.196 LP → withdraws → **1000.000000 USDT**. All 24 assets' round trips measured ≤ 1.0019.
* **Swap cycles / cross-asset round trips** — all ordered pairs × sizes swept against the **deployed** quotes; net of the small edges above, everything is ≤ 1.00 (fees + cov-ratio limits).
* **Tip bucket extraction** — `transferTipBucket` reverts `Ownable: caller is not the owner`; `fillPool` reverts `POOL_FORBIDDEN (0xcc83193d)` (fork-verified). Buckets total **$2,117.5**, owner/dev-only.
* **Farm rewards** — `allocPoint=0` (all pools), no rewarders, no voter, `pendingTokens` empty; nothing accrues or is claimable.
* **Pause/param abuse** — `setHaircutRate` etc. revert for non-owner (fork-verified).

---

## 5. PoC / fork verification

**Project:** `poc/` (Foundry, forge-std vendored). **Run:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38364396117 — `Ran 7 tests … 7 passed; 0 failed` (fork of Kaia mainnet at block **229,673,758**, public RPC).

| test | result | key numbers |
|---|---|---|
| `test_krwo_stale_oracle_swap_executes` | PASS (gas 851,778) | quote == executed = **284,871,700,641** raw KRWO for 200 USDT |
| `test_krwo_stale_oracle_deposit_withdraw_other` | PASS (gas 973,124) | deposit 200 USDT → 194.073 LP → **284,871,700,641** KRWO |
| `test_wgcklay_skew_edge_executes` | PASS (gas 459,762) | 30,000 WKLAY → 24,680.589 wGCKLAY = 30,157.05 WKLAY at GCKLAY rate |
| `test_oracles` | PASS | `P(wGCKLAY) == GCKLAY rate` (live); `P(WKLAY) 0x6389 = 0.142813…` (stored/stale) |
| `test_admin_gates_and_lp_exit` | PASS (gas 619,064) | tip bucket WKLAY = 11,654.95 (owner-only); `withdraw 1000 LP → 1044.35 WKLAY` (H-O exit works) |
| `test_same_asset_roundtrip_neutral` | PASS (gas 723,300) | 1000 USDT → 1329.196 LP → **1000.000000 USDT** |
| `test_quote_consistency` | PASS | quote==execution across 50–400 USDT |

Earlier CI runs failed on (a) GitHub `foundryup` attestation 500 (transient) and (b) two compile/allowance bugs in the PoC itself; all fixed.

---

## 6. Verdict, residual and latent risk

* **E-U now: ≈ $22.4** (upper bound, sum of per-path maxima at the analysis block; realistic ≈ $15–22). It is *arbitrage*, not a contract bug: the pools' dynamic oracles lag the market (KRWO vs KRW FX; plus small invariant-skew windows). All amounts are bounded by the pools' cash on the payout side.
* **H-O: ≈ $155.3k.** LP tokens are ~80–90% staked in the MasterWombat proxy; stakers are actively exiting (successful `withdraw` txs on 2026-10-07/09/10/12) and the LP→underlying path is fork-verified. Realized value is subject to each asset's coverage ratio (haircut/bonus at withdrawal).
* **P: ≈ $158.7k** (all pool underlying) via the ProxyAdmin upgrade, plus **$2.12k** tip buckets via `transferTipBucket`; the same EOA owns the assets (`setPool`).
* **S: $0** (dust pool `0x4c7216d5` ≈ 1 gwei stKAIA; cosmetic tip-bucket underflow there).
* **Latent risk:** (1) the KRWO edge grows if USD/KRW strengthens further (oracle frozen at USD/KRW≈1500); (2) the WKLAY oracles are 2–3.4× stale — if a future trade pushes a pool back toward equilibrium, the WKLAY sell window could widen materially (bounded by the pools' non-KLAY cash ≈ $17k across `0x6389`/`0x4de1`/`0x4b63`); (3) single-EOA ownership + upgradeable unverified proxies = full-drain risk if the key is compromised.

**Blockers to a larger E-U:** swaps already track market within fees; the deposit bonus is exactly cancelled by the withdrawal haircut; the tip bucket and every parameter/upgrade path are owner/dev-gated; the farm has no emissions.

---

## 7. Methodology, sources, caveats

**Method:** triage target (`0x3CA30C86…` master) → Sourcify/Kaiascan checks (unverified) → bytecode selector/error fingerprinting → matched Wombat lineage (v1-core repo + verified Arbitrum deployment + GCKLAY token source) → exact integer WAD model (`analysis/wombat_math.py`) validated against deployed quotes (withdraw: exact; swaps: exact/≤0.3%; deposits: bounded by fork tests) → exhaustive pair/size sweeps on **deployed** quotes (`swap_sweep.py`, `maxprofit_sweep.py`, `krwo_probe.py`) → fork PoC on CI.

**Sources:** Kaia public RPC `https://public-en.node.kaia.io` (+ `https://kaia.drpc.org` fallback); Kaiascan API (contract codes/holders/txs; public frontend-bundle auth, no secrets stored); DefiLlama `coins.llama.fi`; USD/KRW spot ≈1334 (Oct 12–13, 2026); wombat-exchange/v1-core (GitHub); tintinweb sanctuary (Arbitrum Wombat Pool); wGCKLAY verified source (Kaiascan); on-chain GCKLAY `totalSupply/totalShares`.

**Caveats:** (1) pool/master implementations are **unverified** — behavior modelled + fork-verified, not source-diffed; (2) KRWO realization at ~$0.00075 is the main E-U uncertainty (issuer redemption / DEX depth unproven); (3) wGCKLAY realization requires unwrap/unbond or a buyer; (4) prices for obscure tokens (npKLAY/rstKAIA/wGCKLAY) use oracle-consistent rates; (5) per-path maxima are not simultaneously executable; (6) all USD values are indicative at the stated block.

**Files:** `README.md` (this) · `summary.json` · `analysis/` (state dumps, selectors, models, sweeps, final valuation) · `poc/` (Foundry fork tests) · `ci-log.txt` · `ci-out/` · `ci-artifacts/`.

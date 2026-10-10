# Folks Finance (Algorand) — live-custody / extraction assessment

**Date:** 2026-10-10 · **Chain:** Algorand mainnet · **Status:** read-only; no mainnet transactions; dryrun unavailable on public nodes (see §6).
**Round:** evidence rebuilt at round **65,847,915** (algod; last status seen 65,847,980). Every raw dump carries its own round.
**Prices** (coins.llama.fi, 2026-10-10): ALGO $0.115425, USDC $0.99973, USDt $0.99921, gALGO $0.117300, xALGO $0.142021, goBTC $82,081.71, goETH $2,490.32. Unpriced: gALGO3, Planets, PLP/TMP LP tokens.

**Scope:** all Folks-owned legacy Algorand apps: v1 lending pools (18), v1 oracle + adapter, v1 reserve account, gALGO liquid-governance distributors (4/5a/5b/6 + 7–14) and dispenser, xALGO (consensus + stake&deposit), v2 pools (25) + aux (manager, deposits, deposit-staking, loans, oracles). App set derived from the DefiLlama adapter (`projects/folks-finance/{v1,v2}`), the v1 SDK on npm (`folks-finance-js-sdk@0.16.3`), `docs.folks.finance/developer/contracts.md`, and indexer application searches.

> Evidence note: the full 141-app sweep (all deployer-created apps) was performed at round 65,840,032; after an environment reset the evidence set was rebuilt for the 44 apps relevant to the conclusions (`folks/raw/app_<id>.json`, `folks/raw/folks_escrow_summary.json`). Earlier and rebuilt numbers agree to <0.03% except normal price drift.

---

## TL;DR

| Target | Live funds (on-chain) | USD | Classification | Gate |
|---|---|---|---|---|
| **v1 lending pools (18)** | priced escrow $80,761.56 (ALGO 218,453.009896; USDC 32,118.740504; USDt 8,241.230896; goBTC 0.046334; goETH 0.547151; gALGO 85,558.709858 +$10,036; unpriced: gALGO3 42,887.86, Planets 189,641.94, small PLP/TMP) | **H-O $45,224.60** / **S $45,572.95** | redeem open to fAsset holders; deposits/borrows paused | `is_paused=1`; redeem "r" has no pause check |
| **gALGO govDist14** (2629511242) | 4,404,873.669968 ALGO | **$508,431.34** | **H-O** (unclaimed P14 refunds; claims observed round 65,010,362) | distributor claim records; `is_burning_paused=0` |
| **gALGO govDist 4/5a/5b/6** | 168,565.960599 ALGO total | **$19,456.68** | mixed **H-O/S** | `is_burning_paused=1`; `can_claim_algo_rewards=1` |
| **v2 deposit staking** (1093729103) | 38,838.113567 ALGO + 19,840.342184 TINY | **$4,482.88** + TINY | **H-O** (live; activity round 65.0M) | public stake/unstake methods |
| **xALGO** (consensus 1134695678) | active stake 259,292,473.920737 ALGO; live product | ~$29.9M | **live (H-O)** | live stake/unstake |
| **v2 pools (25)** | e.g. ALGO pool escrow 49,401,723.06642 ALGO; USDC pool 668,971.729137 USDC | live (DefiLlama: $57.7M Algorand TVL) | live (H-O/P) | live |

**E-U proven today: $0** (no unprivileged path to take more than one's own claim). Live E-U **candidate**: stale-oracle liquidations on remaining v1 loans (mechanism proven, amount unquantified — CI candidate, §4/§5).

---

## 1. Mechanism / audit (deployed code)

### 1.1 v1 lending pool template — app 686498781 (TEAL v5; same template for all 18 pools; dump: `raw/folks_v1_algo_teal_686498781.txt`)
Methods (ApplicationArgs[0]): `sd, ud, d, r, b, rc, ib, rb, l, ui, p, pr, ap, al, pl, rl`.
- `d` **deposit**: `GroupSize==2` and **`is_paused == 0`** assert — blocked on all 18 pools (`is_paused=1`); mints fAsset = amount × 1e14 / deposit_interest_index.
- `r` **redeem / withdraw** (confirmed by v1 SDK `prepareWithdrawTransactions`, which sends the fAsset axfer and calls "r"): verifies group[-1] is `axfer` of `f_asset_id` sender→app; pays **inner pay = fAsset × deposit_interest_index / 1e14**; then `total_deposits -= payout` (uint64; underflow ⇒ tx fails). **No `is_paused` check** → redeem stays open today.
- `b` borrow: `is_paused==0` + loan-app gating + `total_borrows ≤ total_deposits` — blocked.
- `l` **liquidate**: permissionless; requires gtxn0 call to the oracle **adapter** (751277258) and the borrower's loan app; protocol fee pays the reserve account.
- `ui` interest update: ramps `borrow_interest_index`/`deposit_interest_index`, updates `latest_update`, recomputes rates — **never changes `total_deposits`**.
- `pl` (Lock&Enter provide-liquidity): `is_paused==0` required; increases `total_deposits` — blocked.
- Admin-gated (`txn Sender == XQEOICBG6FMMBBWTBOWCMVJX5IQEDUSBF6L4MTSIALWRWODSOV2THX6GTU` = **MainnetReserveAddress** in the v1 SDK; a normal Folks key, balance 2,445.607206 ALGO, last activity round 65,788,886): `p, pr, sd, ud, rc, ib, rb, rl` → **P**.

**Accounting consequence:** cumulative `r` payouts are capped by the current `total_deposits` (underflow guard) even when the escrow holds more. Surplus escrow (`escrow − total_deposits`) has **no unprivileged exit** (all money-moving branches checked: `r`, paused `b`/`d`/`pl`, admin) → **S** until/unless Folks unpauses (P), which would let new depositors absorb it.

### 1.2 v1 oracle (956833333) — **frozen since 2023-02-20**
All 8 price entries carry timestamp **1676901891 = 2023-02-20** (e.g. ALGO 28,955,447/1e8 = **$0.2896**; USDt $0.99999; USDC $1.0001). `updater_addr` = JGHXR7EQBBTIHW4FBVP4NQ5OF6ZU5NZ765653O7ZM7UFEKBK6CYLY4NE4I; the adapter's update is gated to the reserve account. Today: ALGO $0.1154 (2.5× lower), goBTC $82.1k (vs ~$24k), goETH $2.49k (vs ~$1.65k).
**Consequences:** (a) ALGO-collateralised loans cannot be liquidated (collateral marked 2.5× too high) → pool bad debt; (b) loans collateralised in appreciated assets can be liquidated far below market by any unprivileged liquidator **if such loans remain open** — liquidation activity was observed at rounds 64,970,572–64,970,872 (Sep 2026).

### 1.3 xALGO / gALGO / v2 (live products)
- xALGO consensus (1134695678): active proposer stake **259,292,473.920737 ALGO**; `can_immediate_mint=1`; live (activity round 65.0M). Escrow holds 9,789,207,157.674165 xALGO (unminted supply of the 1e16 cap — not value) + 550.79 ALGO.
- gALGO dispenser (793119194): 9,995,597.485199914 gALGO (burned-supply residue, no value) + 0.83 ALGO.
- v2 (current generation): 25 pools with manager 971350278, deposits 971353536, deposit-staking 1093729103, loans 971388781/971388977/971389489/1202382736/1202382829/3184333108, oracles 1040271396/971323141 updated within hours (round 65.84M), adapter 971333964. Legacy superseded pools still hold funds: WBTC_old 1067289273 (0.213278 WBTC), WETH_old 1067289481 (2.751441 WETH) ≈ $24.4k (H-O), plus all other v2 pools (live).

## 2. v1 pools — live balances and split (round 65,847,915)

| App | Underlying | Escrow (raw) | Escrow USD | total_deposits (redeem cap) | Redeemable USD (H-O) | Stuck surplus USD (S) |
|---|---|---|---|---|---|---|
| 686498781 | ALGO | 218,453,009,896 µA | 25,214.88 | 83,721.482536 | 9,663.53 | 15,551.35 |
| 794055220 | gALGO | 85,558,709,858 | 10,036.01 | 85,558.709858 | 10,036.01 | 0 |
| 686500029 | USDC | 32,118,740,504 | 32,110.19 | 11,912.266478 | 11,909.09 | 20,201.09 |
| 686500844 | USDt | 8,241,230,896 | 8,234.73 | 155.535652 | 155.41 | 8,079.32 |
| 686501760 | goBTC | 4,633,392 | 3,803.17 | 0.028914 | 2,373.30 | 1,429.86 |
| 694405065 | goETH | 54,715,090 | 1,362.58 | 0.422134 | 1,051.25 | 311.33 |
| 751285119 | Planets | 189,641,937,398 | unpriced | 178,226.031728 | unpriced | 11,415.905670 |
| 694464549 | gALGO3 | 42,887,856,915 | unpriced | 42,887.856915 | ~escrow | 0 |
| TMP/PLP ×10 | LP | 1,090.52 / 1,966.02 / 60.16 / 62.36 / 118.93 / 188.83 / 0.99 / 0.06 / 0 / 0.02 | unpriced | = escrow | ~escrow | ~0 |
| **Total priced** | | | **80,761.56** | | **35,188.59** | **45,572.95** (+gALGO $10,036.01 H-O) |

Raw evidence: `raw/folks_v1_analysis.json`, `raw/folks_escrow_summary.json`, `raw/app_<id>.json`. fAsset backing (ALGO pool): fALGO outstanding 231,683.496973 vs nominal claim value 255,585 ALGO at dii 110,290,739,309,644 — the pool can pay only up to `total_deposits` (83,721.48 ALGO); first-mover race; nominal under-collateralisation ≈ $15.5k. No live AMM market found for v1 fALGO (only Pact pool with 686505742, app 3262165809, API TVL $0.00; Tinyman not exhaustively scanned — caveat).

## 3. Special contracts (round 65,847,915)

| App | What | Raw ALGO | USD | Note |
|---|---|---|---|---|
| 2629511242 | govDist14 | 4,404,873.669968 | 508,431.34 | claims observed r65,010,362; `is_burning_paused=0` |
| 793119270 | govDist4 | 20,691.194443 | 2,388.30 | `is_burning_paused=1` |
| 887391617 | govDist5a | 46,692.444844 | 5,388.64 | idem |
| 902731930 | govDist5b | 5,979.703637 | 690.08 | idem |
| 991196662 | govDist6 | 95,202.617675 | 10,987.64 | idem |
| 1093729103 | v2 deposit staking | 38,838.113567 + 19,840.342184 TINY | 4,482.88 | activity r65.0M; live |
| 1134695678 | xALGO consensus | 550.79 + 9,789,207,157.674165 xALGO (unminted) | ~64 | live product |
| 793119194 | gALGO dispenser | 0.83 + 9,995,597.485199914 gALGO (burned) | ~0 | |
| 971368268 | v2 ALGO pool | 49,401,723.06642 + fALGO residue | ~5.70M | live |
| 971372237 | v2 USDC pool | 668,971.729137 USDC | ~668,926 | live |
| 3184317016 | v2 ECO ALGO pool | ≈549,266.936161 | ~63,400 | live |

## 4. Candidate unprivileged paths tried and outcomes

1. **Take pool surplus without fAssets** — only `r` moves underlying to non-admin senders, requires fAsset axfer, capped by `total_deposits`. → **closed** (surplus = S).
2. **Fake-asset redeem** — `gtxn 1 XferAsset == f_asset_id` assert. → **closed**.
3. **Admin bypass (pause/rewards/pl/rl)** — `txn Sender == reserve address`. → **closed (P)**.
4. **Deposit-mint arbitrage** — `d`/`pl` require `is_paused==0`; mint rate symmetric with redeem. → **closed**.
5. **Frozen-oracle liquidations** — permissionless `l`, being exercised (Sep 2026); profitable only for remaining open loans with appreciated collateral. → **open candidate (E-U), unquantified** (CI candidate script `scripts/enumerate_v1_loans.py`).
6. **Redeem race** — buy fALGO (if market existed) and redeem first; value comes from other holders' claims, no protocol value; no live market found. → **not counted as E-U**.

## 5. Classification summary

- **E-U:** $0 proven; candidate: stale-oracle liquidation upside on remaining v1 loans (~24/25/13/13 loan-or-lock local-state accounts on ALGO/USDt/goETH/goBTC pools; ~100 total) — needs per-loan enumeration + health calc (CI candidate).
- **H-O:** v1 pools **$45,224.60** (priced: 35,188.59 + gALGO 10,036.01) + govDist14 **$508,431.34** + v2 deposit staking **$4,482.88** (+ TINY); xALGO/v2 live.
- **P:** v1 admin (reserve key) unpause/rewards; v2 manager roles.
- **S:** v1 surplus escrow **$45,572.95** priced (+ unpriced) + govDist 4/5a/5b/6 leftover **$19,456.68** (burn paused; reward claims possibly open).

**Confidence:** high for balances/mechanism (TEAL + raw state + round cited); medium for govDist14 split (claim records not enumerated) and for the stale-oracle E-U candidate (mechanism proven, amount not quantified).

## 6. Blockers / dead ends
- `POST /v2/transactions/dryrun` and `/v2/teal/dryrun` return **404** on mainnet-api.algonode.cloud and mainnet-api.4160.nodely.dev → no dryrun; `/v2/transactions/simulate` exists but requires a funded sender (no state injection). Gate proofs are static TEAL + observed on-chain successes (redeems/liquidations).
- v1 loan enumeration (to price the E-U candidate) is heavy → CI candidate (script provided).
- v1 fALGO secondary markets not exhaustively scanned (Tinyman) — caveat.

## 7. Files
- `raw/folks_escrow_summary.json`, `raw/app_<id>.json` (44 apps), `raw/folks_v1_analysis.json`, `raw/asset_info_cache.json`, `raw/prices_2026-10-10.json`
- TEAL dumps: `raw/folks_v1_algo_teal_686498781.txt`, `raw/folks_v1_oracle_teal_956833333.txt`, `raw/folks_govdist14_teal_2629511242.txt`
- Scripts: `scripts/algo_lib.py`, `scripts/rebuild_evidence.py`, `scripts/enumerate_v1_loans.py` (CI candidate)
- External evidence: Folks v1 SDK `folks-finance-js-sdk@0.16.3` (npm): `prepareWithdrawTransactions` → method "r"; `MainnetReserveAddress` = XQEOIC…

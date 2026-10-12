# Swerve (Ethereum) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Ethereum mainnet · **Status:** read-only; fork PoC only; no mainnet transactions.
**Finding:** `l2-triage-a` row 15 — Swerve, triage $303,995 ("Curve fork; pool still holds stables").
**Re-verified live:** **$304,688.46** virtual book (LP-claimable) + $5.50 admin surplus + $30,384.52 stuck USDT in the DAO proxy.

---

## 1. TL;DR

| Target | Live value (USD) | E-U (external unprivileged) | Why | Latent risk |
|---|---|---|---|---|
| **swUSD stableswap pool** `0x329239599afB305DA0A2eC69c58F8a6697F9F88d` (DAI/USDC/USDT/TUSD) | **$304,688.46** book ($304,693.96 actual) | **+$0.2971 gross / ≈+$0.25 net on-chain (high confidence)** + **conditional +$4.0877 gross (medium)** | Pool code is internally fair to the wei (get_dy == exchange; exact source = Curve's live sUSD pool bytecode), but **stale vs market**: its underweight USDC leg and near-par TUSD pricing are mispriced against DefiLlama prices, so plain swaps capture a small spread; everything else (admin, governance, LP loops, donations, gauge, LP minter) is provably closed | Arb depends on market spreads & pool composition; may vanish if arbed or prices converge; conditional path depends on TUSD sourcing; MEV-visible |
| **Swerve gauge** `0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa` (96.24% of LP staked) | $293,231 (in the book above) | $0 | Curve original LiquidityGauge; `withdraw` live and actively used (real exits at blocks 26,128,304–26,130,030); no admin functions | none material |
| **DAO proxy** "Swerve DAO" `0x2638d2680AB4914126ee05b9c5EE95bAC311A95E` | 30,408.429720 USDT = $30,384.52 | **$0** | **S (stuck)**: `burners(USDT)=0`; `set_burner(USDT, ≠0)` reverts for everyone incl. the admin (Tether `approve` returns no data → Vyper returndata check); no other token-moving function | Residual MAX allowances DAI/USDC/TUSD → EOA `0xcDEDb901…`: future inflows of those tokens sweepable; future USDT inflows equally stuck |
| **Reward stack** (TokenMinter, SWRV, GaugeController, veSWRV) | $0 (SWRV no market) | $0 | `mint(gauge)` pays only caller's own claim; controller admin `0xdEaD`; veSWRV locks owner-withdrawable | SWRV re-pricing (immaterial) |
| **Pool admin-fee surplus** | $5.4966 (4 coins) | $0 | `withdraw_admin_fees()` requires `owner`; owner = `0x0` → **S** | none |

### Total live extractable now

> **E-U = +$0.2971 gross ≈ +$0.25 net on-chain** (single `USDC→DAI` swap of 1,480 USDC; gas ≈ $0.05). Confidence: **high** (fork-proven; exact-math sim matches to the wei; deep-liquidity coins only).
> **Conditional E-U = +$4.0877 gross ≈ +$4.05 net** (`TUSD→DAI` of 5,414 TUSD) — requires sourcing TUSD at its DefiLlama price ($0.9986); **on-chain TUSD DEX depth is ≈ $0** → medium confidence, off-chain acquisition assumed. A par-unit accounting variant (+$1.17) is *not* market-profitable (−$0.145; test-documented).
> **H-O = $304,688.21** (swUSD holders pro-rata, net of the on-chain E-U skim; gauge 96.24% + 116 holders). **P = $0.** **S = $30,390.02** ($5.50 pool surplus + $30,384.52 proxy USDT).
> Grand total live custody = **$335,078.48**.

---

## 2. The mechanisms in exact terms

### 2.1 Architecture (verified against source + bytecode)
- Pool `0x3292…` is a Solidity 0.6.10 `YPoolDelegator`: fallback does exactly 1 DELEGATECALL (0 CALL/SSTORE, no upgrade function) to hardcoded impl `0xA5407eAE9Ba41422680e2e00537571bcC53efBfD`.
- **The impl bytecode is Curve's live sUSD pool** (Vyper 0.1.0b17, deployed 2020-04-20 by Curve's deployer): impl's own storage = coins [DAI, USDC, USDT, sUSD], LP `crvPlain3andSUSD` (0xc25a3a3b…), owner 0xecb4…, A=256. Swerve's delegator reuses that exact battle-tested bytecode with Swerve's own storage (coins [DAI, USDC, USDT, TUSD]; identical decimals/config: `USE_LENDING=[F,F,F,F]`, `TETHERED=[F,F,T,F]`, `PRECISION_MUL=[1,1e12,1e12,1]`).
- Storage layout mirrors the Vyper layout (coins `keccak(0)+i`, underlying `keccak(1)+i`, balances `keccak(2)+i`, A=3, fee=4, admin_fee=5, owner=6, token=7, deadlines 8–14, is_killed=15). Verified live (owner=0, token=swUSD, deadlines 0, is_killed 0, kill_deadline 0x5fa0fb44 expired).
- LP token swUSD `0x77C6E4a5…` (Vyper 0.2.4): **minter = pool** (pool can `mint`/`burnFrom`; and its `transferFrom` minter-bypass exists but no reachable pool path calls LP transfer/set_minter — audited). Deployer `0xa6df4fcb…` retains no roles.

### 2.2 Ownership history = admin surface fully dead
`NewAdmin` lineage: deployer → DAO proxy `0x2638d268…` (2020-09-08, block 10,818,872) → `0x2E322C04…` (2023-04-02, block 16,961,381 — the Halborn-documented governance takeover) → **`0x0` (2023-04-06, block 16,984,235)**. The whitehat set `admin_fee=0` (blocks 16,961,449/16,984,222) before renouncing. On 2023-03-25 a *permissionless* `DAO.withdraw_admin_fees(pool)` call pulled the accrued 33.33% fees ($123.6k) into the proxy; the DAI/USDC/TUSD part was later swept by EOA `0xcDEDb901…` to Binance/OKX (child-B). Today every admin selector reverts for every caller, incl. via the DAO proxy (fork-tested).

### 2.3 The E-U: pool-vs-market mispricing (stale plain pool)
Internally the pool is perfectly fair — `get_dy` == `exchange` output (±5 wei), exact Vyper math reproduced to the wei (96/96 quote grid, 6/6 LP round trips) — but it has drifted from **market** prices (DefiLlama 2026-10-12: DAI 1.00034, USDC 0.99975, USDT 0.99921, TUSD 0.99860):
1. **USDC→DAI (deep liquidity, E-U headline):** USDC is the pool's short leg (74,120.27 vs DAI 75,005.74) and trades below DAI at market. `exchange(1,0,1480e6)`: in $1,479.6361 → out $1,479.9332 = **+$0.2971** (fork-exact). Optimal size ~1,465–1,480 USDC; larger sizes decay; the LP-op variant (proportional add excluding TUSD → DAI+USDT imbalance removal) reaches +$0.3316 gross but 3 txs.
2. **TUSD→DAI (conditional):** TUSD trades at $0.99860 while the pool prices it ≈ par. `exchange(3,0,5414e18)`: in $5,406.4219 → out $5,410.5096 = **+$4.0877** (fork-exact; optimum 5,450). **Caveat:** TUSD on-chain DEX depth is ~$0 (uniV2 TUSD/USDT pair emptied; TUSD/USDC ≈ $2.1k/side; uniV3 tiers ~0) → sourcing 5,414 TUSD at ~$0.9986 assumes off-chain (CEX/OTC) liquidity; strictly on-chain executable subset remains the ~$0.30 path.
3. **Par-vs-market correction (documented):** the naive "curvature-slack" capture (proportional add → USDT-rich removal → exit) yields **+$1.1663 in par units** but **−$0.14498 at market prices** (extracted USDT trades below the input basket) — fork-proven in `test_slack_capture_par_vs_market`. Never inflate par-unit shifts.

### 2.4 Everything else is closed (fork-tested, 17/17)
- Admin/params/ownership/kill/withdraw_admin_fees: revert for everyone (owner=0; deadlines 0). DAO-proxy wrappers die on the same gate. `is_killed=0`; kill_deadline expired 2020-11.
- Swap/LP internal math: fair to the wei; round trips lose (2×fee); 256-run fuzz; full make-rich→deposit→skewed-exit cycle −$67.82/$60k; imbalanced single-leg +$8.95 par is par-accounting only.
- Donations (surplus $5.4966 + any donation): only `withdraw_admin_fees` reads actual balances → frozen forever; VP/get_dy bit-identical after a +1,000 DAI donation.
- LP token: EOA mint/burn/set_minter revert; pool never calls LP transfer/transferFrom/set_minter → minter bypass unreachable; minter can never change.
- Gauge: `user_checkpoint`/`withdraw` live; live staker exit proven with **exact** pro-rata payouts; claimable SWRV 0; TokenMinter pays only the caller's own claim; veSWRV/SWRV worthless.
- Delegator: no upgrade path; getters equivalent; no hidden entry points (impl's six non-dispatched 4-byte constants all revert; present in Curve's yPool bytecode too).
- Reentrancy: no ETH/ERC-777 hooks; all 5 mutators `@nonreentrant`; Vyper 0.1.0b17 not in the 2023 CVE set.

---

## 3. Live-state assessment (block 26,173,731–26,174,168)

| Item | Value |
|---|---|
| Virtual balances (LP book) | DAI 75,005.743491044521345789 · USDC 74,120.265381 · USDT 81,118.909394 · TUSD 74,604.782023302163442796 → **$304,688.46** |
| Actual balances | +0.31888 DAI / +1.47425 USDC / +1.92072 USDT / +1.78704 TUSD → surplus **$5.4966 (S)** |
| LP swUSD | supply 284,914.257245196369584766; minter = pool |
| Gauge | staked 274,199.686492129967389502 (96.24%); controller admin `0xdEaD` |
| Non-gauge holders | 116 addresses, 10,714.570753 swUSD ($11,458.21); top holders EOAs |
| Owner/admin | owner `0x0`, A=100, fee=3e6 (0.03%), admin_fee 0, all deadlines 0 |
| DAO proxy | 30,408.429720 USDT (S); admins = EOA `0x996E539a…` (Sept-2026 handover) |
| SWRV | supply 21,238,511; minter TokenMinter; price ≈ $0 |

Triage $303,995 → live $304,688.46 (+0.23%); no material change.

---

## 4. Attacker can / cannot

**Can (E-U):** `exchange(1,0,1480e6)` with 1,480 USDC (or LP variant) → **net ≈ +$0.25** (high); `exchange(3,0,5414e18)` → **+$4.05** if TUSD is sourced at market (medium; on-chain TUSD depth ≈ $0). One-time-ish: spreads close as the pool/rebalancing moves; repeat until the mispricing converges.
**Cannot:** call any admin selector (owner=0); claim the $5.50 surplus or donations; drain reserves via LP/swap loops (fair; par-slack not market-profitable); mint/burn others' LP; move gauge stakers' LP; extract from TokenMinter/veSWRV; move the DAO proxy's 30.4k USDT (even as admin).

---

## 5. PoC / fork verification (CI)

- Suite: `poc/test/SwerveLive.t.sol` — **17/17 PASS** on the final CI run (fuzz 256 runs).
- CI runs:
  - intermediate (12 tests, layout/interface iteration): `.../runs/38202421386` (5/12, superseded)
  - green: `.../runs/38205261742` (15/15) · `.../runs/38205912061` (15/15, source-hash evidence in ci-out/)
  - **FINAL market-priced run: `https://github.com/kingmariano/ca-zombie-ci/actions/runs/38207640307` — Suite result: ok. 17 passed; 0 failed (logs carry USDC→DAI +$0.2971, TUSD→DAI +$4.0877, par-vs-market −$0.14498).**
- Key fork numbers: USDC→DAI **+$0.2971**; TUSD→DAI **+$4.0877**; par slack +$1.1663 vs market −$0.14498; full-cycle −$67.82/$60k; swap round trip −$1.1998/$2k; staker exact exit 30.6308 vs 30.6306 (vp); donation $1,000.3189 stuck; proxy USDT $30,408.429720 stuck.
- Exact-math corroboration: `analysis/curve_sim.py` (get_D/get_y/remove_liquidity_imbalance) reproduces on-chain burns to the wei; market-priced optimizer in `analysis/` (TUSD-free vs TUSD families; mirror check: holder book loss == attacker gain).
- **Child A** (`analysis/childA_pool_adversarial.md`, delivered) independently concluded E-U=$0 on the paths it enumerated under a "fair-quote/cross-venue-excluded" reading; it missed the market-priced spread capture. Its independent validations (96/96 quotes, 6/6 LP round trips to the wei, admin/LP/reentrancy closure) corroborate all non-arb conclusions and are folded in. **Child B** (`analysis/childB_reward_stack.md`) covers the reward stack + DAO proxy (its S=$30,383.84 at its price snapshot).

---

## 6. Verdict & residual risk

**E-U = +$0.30 gross / ≈+$0.25 net on-chain (high; deep-liquidity coins only), plus +$4.05 conditional on off-chain TUSD sourcing (medium). H-O $304,688.21 · P $0 · S $30,390.02.** The pool is admin-less and internally fair; the only live edge is its drift from market (USDC short leg + TUSD near-par pricing). Residual: spreads converge as the arb is taken (the $0.30 path is one swap, MEV-visible); TUSD depth could change; the DAO proxy's 30.4k stays stuck; conditional exposure to the 0xcDED allowances for future inflows.

---

## 7. Methodology, caveats, files

- Read-only cast/RPC + Etherscan V2 sources/logs; DefiLlama prices (stated snapshot 2026-10-12); GoldRush holders; DEX depth checks (uniV2/sushi/uniV3 reserves for TUSD); exact-math simulation; Foundry fork PoC on GitHub Actions (public repo; no secrets).
- Caveats: USD valuation at the stated DefiLlama snapshot (par-valuation would overstate stablecoin-composition deltas — explicitly demonstrated); the TUSD $4.09 branch is acquisition-gated (on-chain depth ≈ $0); MEV competition may take the residual; CI forks at latest (public RPCs can't pin archive state) and was run repeatedly with stable results.
- Files: `README.md` · `summary.json` · `analysis/` (sources/, curve_sim.py, child A+B audits, state dumps, arb/depth evidence) · `poc/` (Foundry, `test/SwerveLive.t.sol`) · `ci/run.sh` · `ci-out/` · `ci-log.txt` · `ci-artifacts/`.

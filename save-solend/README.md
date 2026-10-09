# C2-24 — Save (ex-Solend), Solana program `So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo`

**Deep-dive: how much can an external, unprivileged attacker still extract from the "isolated-market config-rot tail" today?**

- **Date:** 2026-10-09 (all reads 2026-10-09 UTC; slot range **454,758,062 – 454,775,874**)
- **Chain:** Solana mainnet-beta
- **Program:** `So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo` (Save/ex-Solend v1 lending program)
- **Deployed build:** source `solendprotocol/solana-program-library` @ `d04ce00bbf4356c4fd32b3be38eb9760b696bb3e` (branch `mainnet`, 2025-07-02 "update max price offset (#220)"); programdata `DMCvGv1fS5rMcAvEDPDDBawPqbDRSzJh2Bo6qXCmgJkR`; last program deploy **slot 350,614,570 = 2025-07-02 10:58 UTC**; **upgrade authority `RY93CZYe5g6drtG7W9PmHRPzaBLZ1uwihTzayQTmJfh`** (note: differs from the `GDmSxpPz…` key published in Save docs — authority was rotated at some point).
- **Status line:** read-only research; **no transactions were signed or sent**; all proofs are `simulateTransaction` dry-runs against mainnet state (sigVerify=false, replaceRecentBlockhash=true) plus pure reads. No keys or keyed RPC URLs appear anywhere in this folder.

---

## 1. TL;DR

| Target | Live unprivileged extractable now | Why closed/open | Latent risk |
|---|---|---|---|
| Borrow against mispriced collateral (tail) | **$0** | 449/603 reserves cannot even refresh (dead oracles); of the 154 refreshable, only 1 has program price >1.02× real **and** LTV>0 (junk "sadfdsaf" Fartcoin) — blocked by `available=0`, `borrow_limit=0`, `attributed_borrow_limit_open=0` | Oracle-lag liquidations only |
| Liquidations, permissionless markets | **~$0** (dust: $34 REdao + $62 main; Collaterize $157 is frozen) | main pool: 271,599 obligations scanned → 4,924 "stored-liquidatable" ($37.1M) are **currently healthy** (program-proven); 13 current-liquidatable are all dust. Tail: all sizeable liquidatable positions are in whitelisted-liquidator or frozen markets | $107.7k main debt within 5% / $3.84M within 10% of threshold + 5–18% liquidation spread from stale LST price scales |
| Whitelisted-liquidator markets (11) | $0 E-U (P: keeper-only) | KHAI/GNME/TRUNK liquidatable value ≈ **$3.27M nominal** ($2.38M/$0.54M/$0.35M), but those obligations' own reserves are frozen (dead SB oracles) → not liquidatable even by the whitelisted keeper | Owner fixes oracles → keeper-only |
| Frozen markets (449 reserves) | $0 E-U | Dead Switchboard feeds (frozen since ~Jan 2025), dead legacy Pyth feeds (~2024); positions cannot be refreshed, borrowed against, or liquidated | None for attackers; users can redeem (H-O) |
| Suppliers' exits (H-O) | n/a (self-service) | main pool $93.85M live; tail $0.59M redeemable at real prices; further ~$19.5M of "value" is dead tokens with no market (stored-price only); **no outflow-blocked reserves found** | — |

**Total live extractable by an external unprivileged attacker now: $0** (material; ~$96 of dust: REdao $34 + main $62). Confidence: **high** — negative result proven by 603 on-chain refresh simulations, 17-of-289 live oracle accounts, and 271,599 + 303,333 obligation headers re-evaluated at current program prices, with four positions' health re-computed by the program itself via simulation.

---

## 2. Mechanism in exact terms — what "config rot" actually is here

The finding's hypothesis was: isolated-market config rot (dead/zero oracles, stale prices, mismatched factors) enables mispriced borrow/liquidation. **Verified live state:**

1. **Oracle support matrix** (deployed build, `token-lending/oracles/src/lib.rs:23-40`): the program dispatches by *account owner* among legacy Pyth (`FsJ3…`), Pyth Receiver/pull (`rec5…`), Switchboard v2 (`SW1TCH…`), Switchboard On-Demand (`SBond…`). Each has a strict freshness gate:
   - legacy Pyth: `get_price_no_older_than(clock, 240 slots)` + `conf*10 ≤ price` (`pyth.rs:108-158`);
   - Pyth pull: `publish_time` ≤ **120 s** + `VerificationLevel::Full` + `conf*10 ≤ price` (`pyth.rs:174-226`);
   - SB v2: `latest_confirmed_round.round_open_slot` < 240 slots (`switchboard.rs:87-113`);
   - SB On-Demand: `result.slot` < 240 slots + `range*10 ≤ price` (`switchboard.rs:41-85`).
2. **Only 17 of the 289 referenced oracle accounts pass any gate today** (all Pyth pull push feeds; slot 454,765,873). All **142 Switchboard-v2 aggregators** and **73 Switchboard On-Demand feeds** are frozen (median ~4.1M slots ≈ 19 days… some since Jan-2025), and all **29 legacy Pyth feeds** are `status=Unknown` since ~mid-2024. 9 oracle accounts are missing entirely. → **449/603 reserves cannot be refreshed**; `refresh_reserve` reverts with `InvalidOracleConfig` (custom 42). **Two extra reserves with live oracles are permanently bricked by `MathOverflow` in interest accrual** (`compound_interest`, `reserve.rs:789-814`): Star Atlas Puri USDC (`5ZXGXFDmPowv…`, last refreshed 1.2 years ago, cumulative rate 337×) and Clone SOL (`FNDYHVzPrB9B…`, 2.2 years) — `refresh_reserve` and even `redeem` revert for them (both have zero available liquidity, so nothing is trapped by the redeem failure).
3. **The one mispriced-but-live reserve is harmless**: "sadfdsaf" market Fartcoin (`program $1.000` vs real $0.161, LTV 89, `attributed_borrow_limit_open=0`, `available=0`, `borrow_limit=0`). Three other overvalued refreshable reserves (RIN 658×, soETH 7.6×, JTO 1.9×) all have **LTV=0** (cannot be used as collateral for new borrows).
4. **The real rot is in `scaled_price_offset_bps` for LSTs**: all main-pool LST reserves point at the **SOL/USD Pyth feed** (`feed_id ef0d8b6f…`, account `7UVimffxr9ow…`) and derive LST value by a *manually maintained* offset (`reserve.rs:92-104`, clamped [-2000,+5000] bps). Live values: mSOL +33.80% (real +41.0%), JitoSOL +23.91% (real +30.5%), **sSOL −0.01% (real +18.0%)**, **stSOL 0% (real +10.3%)**, **INF 0% (real +45.6%, LTV 0)**, **wstETH uses the ETH feed with scale 0 (real +19.7%)**, haSOL +19.59% (real +37.0%). These offsets are stale/broken but **conservative for borrowing** (collateral is undervalued, never overvalued) — they create *liquidation* mispricing, not borrow extraction.
5. **All debt-side money paths are gated** by the objective health math (`processor.rs`; see `analysis/gates-memo.md` for exact line refs): borrow needs `max(price)×borrow_weight×amount ≤ allowed_borrow_value − borrowed_upper_bound` with `allowed_borrow_value = min(Σ min-price×LTV, $65M)`; liquidation needs `borrowed_value ≥ unhealthy_borrow_value` with `unhealthy = min(Σ spot×liq_threshold, $70M)` and the repay reserve at index 0 (max `added_borrow_weight_bps`). Flash loans cannot bypass any of this (`processor.rs:2599-2952`; no obligation/health/oracle relaxation, matching repay enforced in-tx). Withdraw/redeem never need oracles (H-O exits work even on frozen reserves) except that `redeem` is subject to rate limiters.

The 2022 USDH/Saber precedent ($1.26M bad debt via a Switchboard v1 feed that only read one thin Saber pool) is **structurally closed today**: every Switchboard account is frozen, and the only live feeds are guardian-signed Pyth push feeds that a fresh attacker cannot move.

---

## 3. Live-state assessment (exact, with citations)

**Counts** (slot 454,758,062–454,775,874; config list `https://api.solend.fi/v1/markets/configs?scope=all&deployment=production`, re-verified against on-chain accounts — all 203 markets / 603 reserves decoded from chain, not from the API):

| Metric | Value |
|---|---|
| Markets / reserves on-chain | 203 / 603 (137 markets have ≥1 reserve) |
| Reserves refreshable today (simulated `refresh_reserve`) | **154 OK / 449 FAIL** (447 `InvalidOracleConfig` + 2 `MathOverflow`; slot ~454,775k) |
| Live oracle accounts | 17 (all Pyth pull push feeds; Full-verified, ≤120 s) |
| Dead oracle accounts | 142 SB v2 + 73 SB On-Demand + 29 legacy Pyth + 9 missing |
| Main-pool reserves | 89 (40 refreshable; 49 frozen long-tail with LTV=0) |
| Main-pool available liquidity (real prices) | **$93,854,922** (93.6M in refreshable reserves) |
| Tail available liquidity (real prices) | $21,243,428 total; **$1,117,385 refreshable**; $594,910 frozen-but-redeemable at real prices; $19.5M is stored-price-only dead tokens (no market) |
| Main obligations | 271,599 total, 15,560 with debt |
| Stored-liquidatable main obligations | 4,924 ($37.08M borrowed at last refresh) → **currently liquidatable: 13, all dust** |
| Tail currently-liquidatable (all 137 markets with reserves scanned, 303,333 obligations) | 79 entries / $3.28M (stored-liquidatable + near-crossed), dominated by whitelisted-liquidator markets (KHAI $2.38M nominal, GNME $0.54M, TRUNK $0.35M — all frozen); permissionless remainder = $34 + dust |
| Whitelisted-liquidator markets | 11 (Turbo PURP, edgeSOL, LST, KHAI, TRUNK/USDC, Zzz, GNME/USDC, DELI, Foxcoin, SMAN, Lionz and Gazellez) |
| Rate limiters | No market or reserve is outflow-blocked (packed order is `(max_outflow, window_duration)`; all zero-max cases have `window=0` = disabled). Main market: $10.0M / 28,800-slot window |
| Nominal bad debt in frozen tail markets | ~$125M (ScarCoin $93.8M, stacc eco $10.9M, Star Atlas $6.9M, GNME $6.85M, TRUNK $4.97M, KHAI $2.03M) — debt owed, mostly uncollectible |

**Key accounts:**
- Market owner (all reserves' authority): `5pHk2TmnqQzRF9L6egy5FfiyBgS7G9cMZ5RFaJAvghzw` (docs list `9RuqAN42PTUi9ya59k9suGATrkqzvb9gk2QABJtQzGP5` as additional).
- Main lending market: `4UpD2fh7xH3VP9QQaXtsS1YY3bxzWhtfpks7FatyKvdY` (`whitelisted_liquidator = None` → permissionless).
- Program upgrade authority: `RY93CZYe5g6drtG7W9PmHRPzaBLZ1uwihTzayQTmJfh` (P).
- 17 live oracle accounts include `7UVimffx…` (SOL/USD), `Dpw1EA…` (USDC/USD), `42amVS4…` (ETH/USD), `4cSM2e6…` (BTC/USD), `7ajR2z…` (JTO/USD), `DBE3N8…` (BONK), etc. Each has `write_authority == account` (push-oracle PDA; no external writer).

**Program-computed health proofs** (via `RefreshReserve × n + RefreshObligation` simulation, program returns post-state):
- `7DYqwk7ps9ZCgQcr…`: borrowed $2,320,285 vs unhealthy $2,562,092 → **healthy** (was at 1.00× threshold at its last refresh).
- `7VeJrgCLmi3aSeAF…`: $297,431 vs $644,563 → healthy.
- `6ng5pNAnmjkT6KxQ…`: $97,882 vs $194,118 → healthy.

---

## 4. What an attacker can / cannot do — exact call paths

**Can:**
- Redeem cTokens in frozen reserves (self-service, H-O): `RedeemReserveCollateral` needs no oracle (`processor.rs:766-809`, internal interest refresh only), subject to `available_amount` and rate limiters. This is how users exit frozen markets (e.g., TURBO SOL, Stable, BONK, JLP, ISC, Staked SOL, cool, FLAME, TPX…).
- Liquidate any unhealthy position in permissionless markets — but **no material unhealthy position exists**; all found are dust or in whitelisted/frozen markets.
- Wait for interest accrual / price moves to push the $3.84M of main-pool debt currently at 0.90–1.00 of threshold over the line, then liquidate at a **5–18% spread** created by the stale LST scales (see §6).

**Cannot:**
- Refresh any of the 449 dead reserves (dead/missing oracles) → cannot borrow, withdraw-with-debt, or liquidate any obligation containing them (the program requires *every* reserve in the obligation to refresh in the same slot: `processor.rs:973-1153`).
- Borrow against any refreshable overvalued collateral (none with LTV>0 and usable limits).
- Manipulate the live Pyth push feeds (guardian-signed; `VerificationLevel::Full` enforced).
- Bypass health via flash loans (`processor.rs:2599-2952`), `forgive_debt` (owner signer only, `processor.rs:2954-3040`), or `closeable` (risk authority/owner only). **0 closeable obligations exist program-wide** (`memcmp` offset 187 = 1 over all 1,300-byte accounts returns 0).
- Exploit the 2 `extra_oracle` reserves: extra prices only enter `min`/`max` price bounds (`reserve.rs:112-137`), so a stale extra price can only tighten, never loosen, borrow/withdraw limits.
- Drain the main pool: oracles live and prices ≈ real (LSTs slightly *below* real).

---

## 5. PoC / verification (CI)

No Foundry PoC (EVM-only); the Solana proof is a dependency-free simulation job (`ci/run.sh` → `ci/prove.py`, pure Python stdlib, public RPC, no keys):

1. **603 × `refresh_reserve` simulations** → `ci-out/refresh_sims.json` (per-reserve OK/err + post-refresh prices).
2. **5 proof obligations** → `ci-out/obligation_health.json` (refresh + `RefreshObligation`; program-computed borrowed/unhealthy values).
3. Assertions: ≥600 reserves enumerated; >100 refreshable; main SOL reserve refreshable (fails the job otherwise).

**CI runs** (GitHub Actions, `kingmariano/ca-zombie-ci`, workflow `poc.yml`, finding `save-solend`):
- **Run 1: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37891076915 — SUCCESS** (slot 454,778,866): `[proof] refresh sims: 603 total, 154 refreshable, 449 failed`; `7DYqwk7` $2,314,168 vs $2,557,994 healthy; `7VeJrgCL` $297,428 vs $642,863 healthy; `6ng5pNAn` $97,881 vs $193,606 healthy; `4KTntteZ` $486,508 vs $519,870 healthy; `9KcqNKkdx` reverts (frozen SLND reserve); artifact `result-save-solend` (ID 11597549524).
- **Run 2 (final content): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37891539771 — SUCCESS** (slot 454,780,081): identical results, `[proof] OK`.
- Local pre-run of the same script reproduced the same results (154/603; 4 healthy + 1 frozen). Downloaded artifacts/logs are in `ci-out/`, `ci-artifacts/`, `ci-log.txt`.

---

## 6. Verdict and residual / latent risk

- **E-U now: $0** (material). The config-rot tail is dead weight, not a weapon: the oracles that made it exploitable (Switchboard, legacy Pyth) are all offline, and the one live mispricing is fenced by zero limits.
- **Latent (E-U when triggered):** re-evaluated at current program prices, main-pool debt stands at **$107.7k within 5% of liquidation** (0.95–1.0), **$3.73M at 0.90–0.95**, $1.17M at 0.80–0.90, and $0 above 1.0. Because LST collateral is priced 5–18% below real (`scaled_price_offset_bps` stale/broken), any position that crosses becomes a profitable first-mover liquidation (spread ≈ real/program − 1 + bonus − protocol fee ≈ **5–18%** per repaid dollar, up to 31% for INF/sSOL-type collaterals; capped by close factor 20%/$500k per call). The largest near position is `7DYqwk7…` ($2.31M debt, ratio 0.903, collateral spread 1.146 via haSOL). Debt accrues interest continuously, so crossings are inevitable; this is a **latent value transfer from borrowers to liquidators**, monitorable via `analysis/main-near-positions.json`.
- **P:** upgrade authority `RY93CZ…`, market owner `5pHk2Tmn…` (can update `scaled_price_offset_bps`, whitelists, limits, `closeability`); 11 whitelisted-liquidator markets (~$3.27M nominal liquidatable, currently frozen).
- **S (stuck/bricked):** 449 dead reserves (frozen for borrow/liquidation purposes); ~$125M nominal bad debt in frozen markets (uncollectible debt, not extractable value); dead-token supplies with no market (COOL $5M, LST-"DAI" $8.0M, ScarCoin STCC $5.0M, TPX $394k at stored prices) are only nominally valuable. No outflow-blocked reserve exists — supplier redemptions are self-service where the token is real.
- **H-O:** main $93.85M live; tail $594,910 redeemable at real prices; the remaining $19.5M tail "available" is stored-price-only dead tokens (no DEX/Jupiter market).
- **What would change the verdict:** (a) Save team posts new Switchboard/Pyth accounts and re-enables the 449 reserves (then the stale LST scales and any remaining overvalued feed become exploitable again — monitor `refresh_reserve` success and `scaled_price_offset_bps`); (b) any of the 4 overvalued refreshable reserves gains LTV>0/liquidity; (c) positions crossing into liquidation territory (§6).

---

## 7. Methodology & sources

- **Enumeration:** `api.solend.fi/v1/markets/configs` (203 markets / 603 reserves) re-verified on-chain: all market accounts (290 B, `lending_market.rs:83`) and reserve accounts (619 B, `reserve.rs` `RESERVE_LEN`) fetched via `getMultipleAccounts` and decoded against the exact deployed packing order (`mut_array_refs!`), including extended fields packed into the former padding (`accumulated_protocol_fees`, rate limiter, `smoothed_market_price`, `reserve_type`, `max_liquidation_bonus`, `scaled_price_offset_bps`, `extra_oracle_pubkey`, attributed limits).
- **Oracle classification:** all 289 referenced oracle accounts fetched and decoded (Pyth legacy/`PriceUpdateV2`, SB v2 `AggregatorAccountData`, SB On-Demand `PullFeedAccountData`), each checked against the program's exact gates (`analysis/oracle-decode.json`, `analysis/oracle-status.md`).
- **Refreshability proof:** `simulateTransaction` of `RefreshReserve` (ix index 3) for all 603 reserves, post-state decoded (`ci-out/refresh_sims.json`; local full run in `analysis/` context).
- **Obligations:** main market — 271,599 headers via `getProgramAccounts(dataSize=1300, memcmp offset 10, dataSlice 204)`; all 4,924 sane stored-liquidatable + 936 near-threshold positions re-evaluated with current program prices and interest accrual; program-computed health cross-check for 5 positions via simulation. Tail — all 137 markets with reserves scanned the same way (303,333 obligations; 5,381 stored-liquidatable).
- **Prices:** Jupiter price API v3 lite (primary) + DexScreener (fallback) for all reserve mints (`analysis/prices.json`).
- **Incident precedent:** Save blog "USDH price manipulation impact on isolated pools" (2022-11-29); contemporaneous reports (Coindesk, Ackee).
- **Reproduce:** `scripts/` (fetch/decode/scan), `ci/prove.py` (simulation proof). All public endpoints only.

## 8. Caveats & limitations

- `simulateTransaction` proves program logic against current mainnet state but is not a signed transaction; no state changes, no value moved (by design).
- "Real prices" come from Jupiter/DexScreener; for dead tokens without a market the real value may be ~0 — stored-price figures are flagged where used.
- Obligation health evaluation is point-in-time (slot ~454,775k); prices/interest move continuously.
- The tail scan covers all 137 markets with reserves (incl. the 54 with ≥$1k stored value) + main; markets with zero reserves were not scanned (nothing to scan).
- Child-agent supplementary scans (`analysis/obligations-*.json/md`) used a different header offset convention and are **superseded** by `analysis/main-obligation-stats.json`, `analysis/main-liquidation-eval.json`, `analysis/tail-liquidation-now.json`, `analysis/tail-near-now-liquidatable.json` (corrected offsets, documented in `analysis/gates-memo.md`).

## 9. Files index

| Path | Content |
|---|---|
| `analysis/reserves.json` | All 603 reserves: config, stored/current prices, oracles, limits, rate limiters |
| `analysis/markets.json` | All 203 markets: owner, whitelisted liquidator, rate limiter, reserves |
| `analysis/oracle-decode.json` / `oracle-status.md` | 289 oracle accounts decoded + gate verdicts |
| `analysis/prices.json` / `prices.csv` | Real prices (Jupiter/DexScreener) for all reserve mints |
| `analysis/gates-memo.md` | Exact money-path gates from deployed source (file:line) |
| `analysis/candidates-overvalued-borrow.json` | All refreshable reserves with program price ≥1.02× real |
| `analysis/main-obligation-stats.json` | 271,599 main obligations: counts + health buckets |
| `analysis/main-liquidation-eval.json` | Current liquidation funnel + profit model for stored-liquidatable set |
| `analysis/main-near-positions.json` | 401 main positions within 10% of liquidation (current values) |
| `analysis/main-near-now-liquidatable.json` | Near set that is currently liquidatable (2 dust) |
| `analysis/tail-liquidation-now.json` | All 137 tail markets: scan summary + current liquidatable |
| `analysis/tail-near-now-liquidatable.json` | Tail near set re-evaluated (KHAI/whitelisted + dust) |
| `analysis/funded-markets.json` | Funded market list with stored values |
| `analysis/proof-obligations.json` | Inputs for the program-computed health proofs |
| `ci/prove.py`, `ci/run.sh` | CI simulation prover (public RPC, no keys) |
| `ci-out/` | CI artifacts (refresh sims, obligation health, summary) |
| `scripts/` | Reproducible fetch/decode/scan scripts |
| `summary.json` | Machine-readable summary |

# C2-11 · Suilend (Sui) — old package versions v10–v24 vs the live market: reachability & extraction

**Date:** 2026-10-08 · **Chain:** Sui mainnet (chain id `35834a8a`) · **Mode:** read-only research — devInspect/simulations only; **no transaction was signed or sent**; no secrets used.
**Campaign:** zombie-hunt II, finding C2-11. **Folder:** `/home/heisenberg/CA/suilend/`.

---

## 1. TL;DR

| Target | Live extractable (external unprivileged) | Why open / closed | Latent risk |
|---|---|---|---|
| Suilend lending packages **v10–v21** on the live market (45 reserves, 149,616 obligations, ~$138.6M real-priced available) | **$0 proven today** (no single-transaction path). Conditional flow ≈ **$120–255/day** (liquidation-bonus differential) only via an unproven same-second two-tx pattern | Old versions' only price-refresh path (legacy Pyth) is **frozen** (last update 2026-09-22; Pro VAA format/guardian-set incompatible; Hermes API 401). Same-PTB version mixing fails with **`InvalidLinkage`**. Freshness threshold is 0 s, so ops need a same-second timestamp | If the legacy Pyth feeds are ever revived **or** the two-tx same-checkpoint pattern works, v10–v18 regain the missing liquidation-bonus cap (v19 fix) — worth ~$120–255/day of liquidation flow |
| Suilend lending packages **v22–v24** | **$0** (all extraction-relevant fixes present: cap, health recompute, fee clamp) | Fully operational (can refresh prices via the Pro path), but behaviour ≈ v25 | They are **not** aware of v25's pause flags / price guards / oracle-timestamp checks — if those are ever enabled, v22–v24 bypass them |
| v1–v9 | $0 | `EIncorrectVersion` (abort code 1) on every call — market.version=7 gate | none |

**Total live extractable now (external unprivileged): $0.00 — confidence high.** No single-transaction permissionless path to extract value from the live market via old packages. **Conditional residual: ≈$120–255/day** (≈$3.6k–7.7k/month) liquidation-bonus differential, reachable only via an unproven same-second two-tx pattern and requiring races against incumbent bots — confidence **medium-low**. Latent: v22–v24 would bypass v25 pause/price-guards if those were ever enabled.

---

## 2. What was claimed and what the deep-dive found

**Corpus claim (C2-11):** v10–v24 "all expect market.version=7 and execute against the live market"; later versions added a borrow-request pattern, liquidation pre-state capture and `withdraw_ctoken_amount > 0` guards that old packages lack.

**Verified / corrected:**

1. **Version chain (new, complete):** 25 package versions. `packageVersionsAfter` on the original id `0xf95b0614…a6ddf` returns v2…v25; deploy dates from each upgrade tx (`analysis/version_map_dates.json`, `ci-out/version_chain.json`). Latest is v25 `0x59672975e15c58ffc9450f5236b6aa9fa2407d94b8081e634778aa01957d8c6f` (2026-09-28).
2. **Callability map (devInspect `lending_market::create_obligation<MAIN_POOL>`, live market):** v1–v9 **abort code 1** (`EIncorrectVersion`); **v10–v25 succeed** (`analysis/callability_map.txt`, `ci-out/probe_results.json`). The corpus is right that v10–v24 execute; it understated that v25 obviously does too.
3. **Guard timeline (source + bytecode diff):**
   - **v8** (2024-11-17) added the borrow-request pattern (`borrow_request`/`fulfill_liquidity_request`) — so **v10–v24 already have it**; the corpus's "borrow-request" item is not a v10+ gap.
   - **v19** (2026-02-24) added the audit fixes: `assert!(withdraw_ctoken_amount > 0)` in `liquidate` (commit `f4501ec`), `calculate_capped_liquidation_bonus` (cap = `(deposited−borrowed)/borrowed`), health-aggregate recompute ("health drift"), highest-borrow-weight enforcement, dust-borrow guard. **v10–v18 lack all of these.**
   - **v23/v24** (2026-08/09) added the retired-reserve (`open_ltv==0`) liquidation exemption, on-the-fly `collateral_value_usd` recompute, min-1-ctoken on full liquidation, and a fee clamp `min(fee, balance−1)`. **v10–v22 lack these.**
   - **v25** (2026-09-28) added pause flags (`PauseKey` dynamic fields, `assert_not_paused` in 8 lending-market entry points), price guards (`PriceGuard` dynamic field; `apply_price_update`/`clamp_to_band`/`assert_band_below_liquidation_buffer`), oracle timestamp checks (`timestamp_within_tolerance`/`timestamp_not_forward_dated`), and a confidence multiplier. **v10–v24 lack all of these — but none are configured on mainnet today** (see §4).
4. **Behavioural gate parity:** `obligation::is_liquidatable` = `weighted_borrowed_value_usd > unhealthy_borrow_value_usd` in every version; devInspect cross-version views (v10/v18/v20/v24/v25) agree on live obligations (`ci-out/probe_results.json`). **Liquidating healthy positions is not possible with old code.**

---

## 3. The reachability blockers (this is the core result)

An old-version *value-moving* call (`borrow_request`, `withdraw_ctokens`, `liquidate`, `redeem_ctokens_and_withdraw_liquidity*`) must pass price freshness for every reserve it touches. In all versions `PRICE_STALENESS_THRESHOLD_S = 0`, i.e. the reserve's stored `price_last_update_timestamp_s` must be **the current second**, and the operation must refresh prices in the same PTB. Three independent blockers were found and verified by devInspect:

**Blocker 1 — the old refresh path is frozen.**
The live reserves are refreshed through the **Pyth Pro** package `0x55300367…` (`refresh_reserve_price_pro_compatible`, added in v22) using Pro `PriceInfoObject`s. The legacy path (`refresh_reserve_price`, all v10–v21) takes legacy `0x8d97f1cd…` `PriceInfoObject`s. The legacy feed objects have **not been updated since ~2026-09-19/22** (e.g. legacy SUI feed `0x801dbc2f…`, stored price timestamp 1789759152 ≈ 2026-09-19; last tx touching it 2026-09-22). Verified:
- `v18::refresh_reserve_price(market, 0, clock, legacy_sui)` → **abort code 4** (`EInvalidPrice`, stale price).
- `v18::refresh_reserve_price(…, pro_sui_object)` → **TypeMismatch** (different Pyth package).
- Replaying a fresh Pro update payload (VAA + accumulator from the latest Pro updater tx `3cjQiFzx…`) to the **legacy Wormhole** `0x5306f64e…` → **abort code 0** (`vaa::parse`); the two Wormhole deployments have different guardian sets (legacy `guardian_set_index=7`, Pro `=1`), so Pro VAAs can never satisfy the legacy verifier. Public Hermes returns **401 unauthorized** in this environment, and the legacy Pyth package has no plain-VAA update entry point (`analysis/js/legacy_vaa_test.mjs`, `ci-out/probe_results.json`).
- Consequence: **v10–v21 cannot refresh any live reserve price**; their price-dependent operations abort with `EOraclesAreStale` (v11+) or `EPriceStale` (v10). `create_obligation` (no refresh) still succeeds — which is exactly the wave-2 result.

**Blocker 2 — version mixing is prohibited (Sui `InvalidLinkage`).**
The obvious workaround — do the refresh with v25 and the old logic in the same PTB — fails: any PTB that calls a v22–v25 Suilend function and then a v18 function aborts with `InvalidLinkage in command 1` (tested refresh(v22/23/24/25)+`create_obligation`(v18), refresh(v25)+`is_liquidatable`(v18), refresh(v25)+`liquidate`(v18); also v25 view + v18 create). Each PTB must stick to one package version per Suilend family.

**Blocker 3 — freshness is a same-second condition (but this one is soft).**
`is_price_fresh` requires `clock_s − price_last_update_timestamp_s ≤ 0`. Observed live refresh cadence for the SUI reserve is ~every 15–30 s (driven by ordinary user/bot transactions), so the window where a *foreign* refresh helps an old tx is sub-second. An attacker can attempt a **two-transaction pattern**: Tx A = their own permissionless `v25::refresh_reserve_price_pro_compatible`; Tx B = the old-version operation, sequenced **in the same checkpoint/second** (per Sui docs the `Clock` value is fixed per consensus commit/checkpoint and "successful transactions see a greater or equal timestamp to their predecessors", so same-checkpoint txs share the second ⇒ freshness passes). This is mechanically sound (both txs are the attacker's; no version mixing) but **could not be proven in devInspect** (devInspect cannot persist state between two transactions, and a natural same-second window is too tight to catch over RPC: 0 catches in 4 min for SUI+USDT; SUI/USDC timestamps changed ~every 15–30 s). It is flagged as the main residual, not as a proven extraction.

---

## 4. Live-state assessment (2026-10-08, main market `0x84030d26…5ece1`)

- **Market version = 7**; 45 reserves; obligations `ObjectTable` size **149,616**; `bad_debt_usd = 0`.
- **Available liquidity ≈ $138.6M** (real-priced) / **borrowed ≈ $65.5M** / total supplied ≈ $204M. DefiLlama TVL $173.27M at campaign time.
- **Oracle-price artifact:** the stored-price sum is **$1.918T**, dominated by the retired **FUD** reserve: stored price **$0.99987** vs real **$6.45e-9** (DefiLlama) with `available_amount = 1.918e12` FUD, `open_ltv=close_ltv=0`. Five more retired reserves are similarly $1-priced (SEND, SUDENG, KOBAN, ALKIMI, UP). These reserves are **inert** (LTV 0) but inflate naive TVL reads by ~$1.918T; excluded from the $138.6M figure. Details: `analysis/price_crosscheck.json`, `ci-out/main_market_reserves.json`.
- **No pause / price-guard state exists anywhere:** dynamic-field enumeration of the market and all 45 reserves found only `FeeReceiversKey`, `StakerKey` (SUI) and `BalanceKey` — **no `PauseKey`, no `PriceGuard`**; every reserve config `additional_fields` bag is empty (`ci-out/dynamic_fields.json`). `is_market_paused`/`reserve::is_paused` read absent dynamic fields ⇒ false. The v25-only guards are **inert today**.
- **26 lending markets** are registered; 25 at version 7 (one dead experimental at v4). Funded non-main markets are small (LP_REWARDS 22 funded reserves, EMBER_MARKET 4, BITWISE/ELIXIR/SECURITIZE/EXPERIMENTAL_POOL_X/BUCKET_MARKET 2 each, MATRIXDOCK_GOLD 3). The old-package surface spans all v7 markets; the main market dominates (`ci-out/all_markets.json`).
- **Liquidation flow (400 recent `LiquidateEvent`s, 2026-09-02→10-08):** $372.7k repaid; **222/400 liquidations had the v19 bonus cap binding** (observed withdraw/repay ratio < configured bonus). The v10–v18 uncapped-bonus differential on that flow is **≈$4,389 ≈ $120.5/day** (mean $21.52, median $2.15, max $705.51 per event). A second 15-day window (2026-09-23→10-08) gives **$250.8/day**. Range reported: **$120–255/day** (`ci-out/liquidation_differential.json`, `analysis/recent_liqs_200.json`).

---

## 5. What an attacker can / cannot do

**Can (proven, read-only simulations):**
- Call any public function of v10–v25 that does not need fresh prices: `create_obligation`, views (`is_healthy`, `is_liquidatable`, `allowed_borrow_value_usd`, …), `claim_fees` (fees go to the protocol's `FeeReceivers`, no attacker gain).
- Call `v22–v25::refresh_reserve_price_pro_compatible` with the public Pro price objects (permissionless) — but this is also what current production uses.

**Cannot (proven blockers):**
- Execute v10–v21 `borrow/withdraw/liquidate/redeem` in a single PTB: stale-oracle abort (code 9) / `EPriceStale` (v10, code 0). v18 example: `assert_no_stale_oracles` abort.
- Refresh a live reserve with v10–v21 (`EInvalidPrice`, code 4) — legacy feeds frozen; Pro objects are a type mismatch; Pro VAAs are rejected by the legacy Wormhole (different guardian sets).
- Mix a v22–v25 refresh with a v10–v21 operation in one PTB (`InvalidLinkage`).
- Liquidate healthy positions with any version (identical `is_liquidatable`; cross-version view agreement on live obligations).
- Touch cap-gated functions (`forgive`, `migrate`, `add_reserve*`, `new_obligation_owner_cap`, `set_*`) without the protocol's `LendingMarketOwnerCap` / pause caps — cap-gated in every version.

**Conditional (mechanism identified, not proven):**
- Same-second two-tx pattern: Tx A (attacker's v25 refresh) + Tx B (v10–v18 liquidation) in the same checkpoint ⇒ the missing v19 bonus cap applies, worth up to ~6–7% of the repaid value per near-insolvent liquidation (observed differential $120–255/day of flow). Requires: winning the race against incumbent liquidation bots, reliable same-checkpoint sequencing, and gas for retries. Assessed **medium-low** likelihood of reliable exploitation; not demonstrated end-to-end here.

---

## 6. PoC / verification (all read-only; no fork needed — devInspect against live state)

Files: `analysis/js/{callability.mjs, probe.mjs, legacy_vaa_test.mjs, freshness_race.mjs, view_probe.mjs}`; CI job `ci/run.sh` + `ci/fetch_all.py` + `ci/scan_obligations.py` + `ci/js/probe.mjs`; results in `ci-out/` and `ci-log.txt`.

| Test (devInspect, live state) | Result | Interpretation |
|---|---|---|
| v1–v9 `create_obligation` | abort **code 1** | version gate |
| v10–v25 `create_obligation` | **SUCCESS** | callable surface confirmed (corpus) |
| v18 `liquidate` (USDT debt/SUI collateral) | abort **code 9** `assert_no_stale_oracles` | old code runs; blocked by frozen prices |
| v25 refresh + v25 `liquidate` | abort **code 0** (not liquidatable) | refresh satisfies freshness; v25 executes to the health gate |
| v25 refresh + v18 `liquidate` (mixed PTB) | **`InvalidLinkage`** | version mixing prohibited |
| v18 refresh with legacy SUI object | abort **code 4** `EInvalidPrice` | legacy feed stale since 2026-09-22 |
| v18 refresh with Pro object | **TypeMismatch** | old path cannot consume Pro feeds |
| v22/v25 refresh with Pro object | **SUCCESS** | Pro path works (v22+) |
| Pro VAA+accumulator replay → legacy Wormhole | abort **code 0** (`vaa::parse`) | Pro VAAs unusable on the legacy deployment (guardian set mismatch) |
| Cross-version views (`is_liquidatable`, `is_healthy`) on live obligations | identical v10/v18/v20/v24/v25 | no threshold divergence |
| Freshness cadence (SUI reserve) | refresh ~every 15–30 s; no same-second catch in 4 min | same-second race is tight |

**CI:** GitHub Actions run of `ci/run.sh` (callability map, decisive-path tests, event differential, 26-market + 45-reserve state, module-hash timeline, disassembly of v10/18/20/22/23/24/25). Run URL(s) recorded in `ci-log.txt` / README §9. Artifacts: `ci-artifacts/`.

---

## 7. Verdict, residual and latent risk

- **E-U (proven today): $0.** No external-unprivileged single-transaction path to extract value from the live market using old packages. The surface is callable but fenced by (i) the frozen legacy oracle path, (ii) Sui's version-mixing prohibition, and (iii) the same-second freshness rule.
- **E-U (conditional flow): ≈$120–255/day** ($3.6k–7.7k/month) — the missing v19 liquidation-bonus cap in v10–v18, reachable only via the unproven same-second two-tx pattern and requiring races against incumbent bots. Median per-event differential $2.15 (max $705.51).
- **H-O: $0.** Users' normal withdrawals/repayments are unaffected and go through v25.
- **P: $0.** All privileged entry points are cap-gated in every version.
- **S: $0.** Nothing is bricked.
- **Latent (monitor):**
  1. **If the legacy Pyth feeds are ever revived/updated** (or any legacy-verifiable VAA+accumulator source appears), v10–v18 become directly exploitable for the bonus differential in a single PTB — re-test immediately.
  2. **If Suilend enables pause flags or price guards** (v25 features, currently unset), **v22–v24 remain fully operational and would bypass them** (they can refresh via the Pro path and do not check `PauseKey`/`PriceGuard`). v10–v21 would additionally bypass them if the two-tx pattern works.
  3. **If a future market is published with `version != 7`**, all old packages are gated out for that market (observed behaviour of v1–v9 today) — the gate is the protocol's only effective retirement mechanism and should be kept.
- **Blockers summary:** frozen legacy Pyth deployment (stale feeds, incompatible guardian sets, gated Hermes); Sui `InvalidLinkage` for mixed-version PTBs; 0-second freshness threshold; version gate (v1–v9); cap-gating.

---

## 8. Methodology, sources, caveats

- **Version chain** via Sui GraphQL `packageVersionsAfter` on the original package id; deploy timestamps via `object.previousTransaction → transaction.effects.timestamp` (`analysis/version_txs.json`, `analysis/version_map_dates.json`).
- **State** via `sui_getObject`/`sui_multiGetObjects`/`suix_getDynamicFields` on public RPCs (`sui.publicnode.com`, `mainnet.sui.rpcpool.com`) and Sui GraphQL (`graphql.mainnet.sui.io`); events via GraphQL `events` + JSON-RPC `suix_queryEvents`; transaction internals via GraphQL `transactionJson` (used to extract the Pro VAA/accumulator and to map Wormhole states).
- **Source**: public repo `suilend/suilend` (devel/mainnet, latest published v20, 2026-03-05) for v10–v20 logic + `git log -S` to date each guard; **bytecode disassembly** (`sui move disassemble`, Sui CLI 1.81.1) of v10/18/20/22/23/24/25 for the v21–v25 gaps; normalized modules (`sui_getNormalizedMoveModulesByPackage`) for signature diffs. Artifacts: `analysis/disasm/`, `analysis/version_summary.txt`, `analysis/src-v10…v20/`.
- **Pyth/Wormhole**: legacy package `0x8d97f1cd…` (original `0x04e20ddf…`) + legacy Wormhole `0x5306f64e…`/state `0xaeab97f9…` (guardian set 7); Pro package `0x55300367…` + Pro Wormhole `0x99de5c96…`/state `0xdbca52b9…` (guardian set 1). Legacy SUI feed object `0x801dbc2f…` last price timestamp 2026-09-19/22.
- **Caveats:** (1) The two-tx same-checkpoint pattern is reasoned from the freshness code + Sui checkpoint semantics, not simulated end-to-end (devInspect cannot chain transactions; `sui-fork` was not run). (2) The liquidation-differential estimate is an event-stream approximation (current prices, assumes the old liquidator wins the race; partial-repay/full-seize cases approximated by `repay × (configured − observed)`). (3) Point-in-time reads; the market is live. (4) Public RPC/GraphQL availability and Pyth Hermes auth were as observed on 2026-10-08; a future change to any of them can reopen the surface. (5) No transactions were signed or sent; all simulations are devInspect against live state.

## 9. Files index

- `README.md` (this file), `summary.json`
- `analysis/`: `sui_rpc.py`, `fetch_versions.py`, `version_modules.json`, `version_summary.txt`, `version_map_dates.json`, `version_txs.json`, `market_raw.json`, `reserves.json`, `price_crosscheck.json`, `callability_map.txt`, `recent_liqs*.json`, `looped_obligations.json`, `borrower_obligations.json`, `all_markets.json`, `dfields.json`, `funcdiff.py`, `src-v10…src-v20/`, `disasm/` (v10/18/20/22/23/24/25 disassembly), `js/` (probe scripts + `pro_update_payload.json`), `extract_versions.sh`
- `ci/`: `run.sh`, `fetch_all.py`, `scan_obligations.py`, `js/{probe.mjs, package.json, pro_update_payload.json}`
- `ci-out/`: `version_chain.json`, `module_hash_timeline.json`, `main_market_reserves.json`, `dynamic_fields.json`, `all_markets.json`, `liquidate_events.json`, `liquidation_differential.json`, `probe_results.json`, `obligation_sample.json`, `fetch_all.log`, `probe.log`, `disasm/`
- `ci-log.txt`, `ci-artifacts/` — CI logs/artifacts (run URL recorded there)

# BlueMove DEX (Sui) — L2 Phase-2 deep-dive: how much can an unprivileged attacker extract today?

**Date:** 2026-10-12 · **Chain:** Sui mainnet · **Status:** read-only; no transactions signed or sent; fork/simulation-only PoC; public endpoints only; no secrets.

**At a glance**

| | |
|---|---|
| Triage row (2026-10-11) | BlueMove DEX — $201,603 "live" across 16,739 pools |
| Re-verified live value (2026-10-12, full scan of all 16,739 pools) | ≈ **$202,164** in pool custody: **V-mid escrows $181,753.52** (15,945 pools), **v12 escrows $20,384.88** (399 pools), **legacy stores $116.43** (majors), plus **$14,707.55 fees** (majors) |
| **E-U (external unprivileged extractable, live)** | **$0.05** (two pools with a live V1-mint desync; all majors counted) — i.e. ≈ **$0** (high confidence). Residual faucet path bounded by the $116.43 legacy-store majors (realistically ≈$0; dead meme tokens). |
| Why closed | 2026-07-12 emergency **version bump to 12 disables both escrow-owning package versions** (vmid expects 8, v12 expects 11 ⇒ `assert_version_contract` abort 25). Only the ungated v1–v6 packages remain callable, and they can only touch the near-empty legacy stores. **0 / 16,739 pools** are drainable via either escrow version (full scan). |
| Latent risk | $202K of escrow value is frozen behind the dev-controlled version switch; if the dev (or anyone with the dev key) re-activates a package version, the July LP-inflation primitive returns for any pool whose reserves are desynced (bots can still create such states via V1 swaps) — but ≥99.9% of the top pools' LP is burned at `0x0`, so most of it is unredeemable anyway. |

---

## 1. TL;DR

BlueMove's July-2026 exploit (≈714K SUI, ~$525K) was a **cross-version reserve desync + LP-inflation** attack: the original package (`v1`) writes `pool.reserve_x := pool.token_x` (legacy store) while the new escrow packages write `reserve_x := escrow.token_x`. Whichever ran last decided the mint denominator; the attacker minted LP against a deflated denominator and burned against the larger store.

**That attack is dead today — not patched, but gated off.** On 2026-07-12T01:24:51Z, ~3h after the drain, the deployer (`0x049cc…ffefa1`, `Dex_Info.dev`) called `0x35f3190a…::swap::migrate_contract_version(12)` (tx `EanzxUeS…PvDs`). The stored marker is now `12`, while **no deployed package expects 12**:

| package | role | `utils::get_contract_version()` | gate at stored value 12 |
|---|---|---|---|
| `0xb24b6789…5454d9` (v1) | original pools/LP, **no gate at all** | — | **callable** |
| `0xdc8437d0…` … `0x941f5ee6…` (v2–v6) | 2023–24 upgrades, no gate | — | **callable** |
| `0x08cd3348…24498f` (v7 "vmid") | owns `EscownCoins` (V-mid escrow) | **8** | **DISABLED (abort 25)** |
| `0xc396a92a…`, `0xf72bd3b3…` (v10–v11) | escrow era | **10** | DISABLED |
| `0x35f3190a…f656d7` (v12) | owns `EscrowCoinsV2`, `add_liquidity_returns`, `sync_pool` | **11** | **DISABLED (abort 25)** |

With the escrow packages gated off, all LP mint/burn paths that can reach pool value are unreachable by an unprivileged caller. The only live callable surface is v1–v6, which operates exclusively on the pools' **legacy stores** (`token_x`/`token_y` Balances inside the `Pool` struct) — which the July drain and the following "faucet" bots emptied: across all 16,739 pools the legacy stores hold **104.93 SUI + 0.66 USDC + 0.00 USDT** (majors).

Verification summary (all read-only):

| check | result |
|---|---|
| LP-inflation attack (V1 swap → v12 `add_liquidity_returns` → burn) | **reverts** — `0x35f3190a…::swap::assert_version_contract`, abort **25** |
| V-latest add/remove/swap/sync (`0x35f3190a…`) | **reverts** — abort **25** |
| V-mid (`0x08cd3348…`) add/remove/swap/migrate | **reverts** — abort **25** |
| V1 swap on an escrow-only pool | **reverts** — `0x2::balance::split`, abort **2** (legacy store empty) |
| V1 mint on an escrow-only pool | **reverts** — `utils::quote`, abort **2** (no viable deposit/proportionality) |
| **Full scan of all 16,739 pools for the desync precondition** | **v12-escrow drainable: 0 pools; V1-mint drainable: 2 pools worth $0.054 total** (CI run below) |
| Live bot activity | the most recent `Dex_Info`-affecting transactions (2026-10-12 11:08–12:24 UTC) are third-party `0xb24b6789…::router::swap_exact_input_` bot PTBs (verified by decoding the latest, `DWNAwM43…`, digests and statuses below); no vmid/v12 calls |

**Verdict: external unprivileged extraction ≈ $0** — rigorously $0.05 (the 2 remaining desynced pools), plus a faucet bound of $116.43 in legacy-store majors with ~$0 realistic value. The remaining ~$202K of pool value is *frozen* in escrow objects (`EscownCoins`/`EscrowCoinsV2` dynamic object fields) that only a version switch can unlock, and even then ≥99.9% of the largest pools' LP supply is burned at `0x0` (unredeemable). Fees worth $14.7K (majors) are recoverable only by the team (`fee_to`/`dev`).

---

## 2. The mechanism in exact terms (deployed code)

Pool state lives in `0xb24b6789…::swap::Pool<T0,T1>` (a dynamic object field of the `Dex_Info` registry, keyed by the LP-name string), shared by every package version. It carries **two token stores plus one shared accounting pair**:

* `token_x`/`token_y: Balance<T>` — the **legacy store** (v1–v6 all write here);
* a dynamic object field of the pool: `0x08cd3348…::swap::EscownCoins<T0,T1>` (v7–v9) and/or `0x35f3190a…::swap::EscrowCoinsV2<T0,T1>` (v12) — the **escrow store** (newer versions write here);
* `reserve_x`/`reserve_y: u64` — **one shared accounting pair overwritten by all versions**, plus `lsp_supply`, `fee_amount`, `minimum_liq`, `k_last`, `is_freeze`.

Mint formulas (identical shape in every version — verified from bytecode, `sui move` disassembly):

* V1: `lp = min((token_x + dx − reserve_x) · S / reserve_x, (token_y + dy − reserve_y) · S / reserve_y)`, then `reserve := token balances`.
* v12: same with `escrow` balances instead of `token` balances, then `reserve := escrow balances`.
* Burn: V1 pays `token_balance · lp / S` out of the legacy store; v12 pays `reserve · lp / S` out of the escrow. Both require both payouts > 0.

⇒ The inflation primitive needs a **componentwise dominance**: the minter's store balance > the reserve on *both* sides. That condition existed in July (escrow ≫ legacy store after aggregator V1 swaps); it requires the escrow package to be callable. Since 2026-07-12 it is not.

Escrow reachability today:
* `add_liquidity`/`remove_liquidity`/swaps of both escrow versions: gated by `assert_version_contract` (abort 25).
* `migrate_escrow_coins` (moves `EscownCoins` → `EscrowCoinsV2`): requires `sender == dev` **and** the calling version gate to pass ⇒ dev-only, and currently its own gate fails (calling it via v12 aborts 25 before the move).
* `skim_pool`, `withdraw_fee_direct`: **abort stubs** (always revert) in vmid/v12.
* `sync_pool` (v12): ungated *given a passing version gate*, and it only copies escrow balances into the reserve fields — a repair function, no fund movement; it too is currently gated off.
* Admin functions (`freeze_pool`, `set_fee_to`, `set_new_dev`, `create_new_pool_admin`) are `sender == dev`-gated; `withdraw_fee` is gated to `fee_to`/`dev` (plus the two team fee receivers `0x9c8c82…`, `0x97a745…` in v6). No unguarded admin entry was found.

---

## 3. Live-state assessment (2026-10-12; Sui GraphQL, checkpoint 333,192,688+)

* **Registry `Dex_Info`** `0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92` (shared): `fee_to = 0x85bf745a…b9d3781`, `dev = 0x049cc391…68ffefa1`, `total_pool_created = 16,739`. `VersionManage` dynamic object field `0x41d5f1c1…3b5b2d` holds **version = 12**, last written 2026-07-12T01:24:51Z.
* **Packages:** original `0xb24b6789…5454d9` (v1) … latest `0x35f3190a…f656d7` (v12); 12 versions total (`packageVersions`). Constants: v7–9 ⇒ 8, v10–11 ⇒ 10, v12 ⇒ 11.
* **Pools:** 16,739 live (all `is_freeze = false`, all `lsp_supply > 0`).
* **Reserve accounting (what triage summed):** SUI 183,071.62 + USDC 188.44 + USDT 31.07 ≈ **$201.6K** at local scan prices (SUI ≈ $1.10) — matches triage's $201,603; the CI scan values the same state at **$202,164.39** (SUI ≈ $1.1026) / **$198,502.25** at the run-B checkpoint (SUI ≈ $1.0826).
* **Legacy V1 stores (majors):** SUI **104.93** + USDC **0.66** + USDT 0.00 ≈ **$116.43** across 540 pools; the largest single holding is 72.91 SUI in pool `0x79fe3c40…` (counterparty = 9.89e17 YAWN, TreasuryCap burned).
* **Escrows (full scan of all 16,739 pools):** 15,945 pools carry only `EscownCoins` (V-mid), 399 only `EscrowCoinsV2` (v12), **0 carry both**, 395 have no escrow (392 with only legacy balances, 3 empty). Reserves exactly match one store: `r = legacy` for 784 pools, `r = EscownCoins` for 15,942, `r = EscrowCoinsV2` for 13.
* **Escrow value:** `EscownCoins` **$181,753.52** (164,559.95 SUI + stables), `EscrowCoinsV2` **$20,384.88** (18,488.50 SUI + tokens; top pool `0x127bd40c…` = 18,407.28 SUI + SUIJAK ≈ $20.25K). Reserves total **$202,164.39** (what triage measured, at 2026-10-12 prices: SUI ≈ $1.1026). Legacy stores **$116.43**.
* **Fees:** 12,738 pools hold accumulated fees; majors total **13,336.28 SUI + ~$3.35 stables ≈ $14,707.55** — withdrawable only by `fee_to`/`dev`/team (P).
* **LP distribution (top pools):** 4 of 5 largest pools have **99.9%+ of LP supply burned at `0x000…000`** (e.g. SUI/SUIJAK pool `0x127bd40c…`: 99.9825% burned; only 0.0122% held by a live address). The 5th (SUI_PEPE) has user-held LP but its LP-coin sum is only 0.58% of the recorded supply (fee-mint accounting; further reduces redeemable share).
* **Live traffic:** the latest transactions affecting `Dex_Info` (2026-10-12, 11:08–12:24 UTC) are third-party bot PTBs calling `0xb24b6789…::router::swap_exact_input_` (the most recent, `DWNAwM43ynsunDoCFv8YFnko1kTmbnXAPHZnVTgdjhUo`, failed with `0x2::balance::split` abort 2; others succeed). Zero calls to any escrow package in the window.

---

## 4. What an attacker can / cannot do

**Can (all read/derived paths verified by simulation, §5):**

1. **Call v1–v6 without any gate** (swap/add/remove on legacy stores; price quoted from the shared `reserve_*` fields).
2. **Mint LP at an inflated rate on the 2 fully-desynced pools** (`0x99c63597df15c372…`, `0x2e56b6b056433383…`: `T > r` on both sides, reserves > 0) and burn in the same transaction — **simulation s8 proves the full atomic path**: v6 (ungated) public `add_liquidity_returns` mints 28,586,102 LP for a 0.0000433 SUI + 5.28M PIGU deposit, then v6 `remove_liquidity` pays out 0.0485 SUI + 352M PIGU. Net **+0.04841 SUI ≈ $0.053** (plus unpriced PIGU). This is the July bug class, still live in code — but the state and value are almost gone. (Mixing V1 and v6/v12 calls in one PTB trips a linkage error; v6-only calls work.)
3. **Buy tokens out of imbalanced legacy stores for dust** ("faucet"): e.g. pool `0x57034562950dc6b1…` (SUI/SUITRUMP) holds legacy SUI 0.0000257 + 258,697.75 SUITRUMP; a 0.1 SUI V1 swap returns ≈258.6K SUITRUMP — **simulation SUCCESS**. Value ≈ external market value of the tokens: 0 of the top-200 imbalanced pools' big-side tokens have a DefiLlama price ⇒ ≈$0.
   The mirror direction (large major side, small other side) is bounded by the counterparty token's acquirable supply: top cases — `0x79fe3c40…` 72.91 SUI vs 9.89e17/1e18 YAWN (TreasuryCap burned at `0x0`, floating ≈1.1% ⇒ ≤~0.8 SUI extractable), `0xa0dfabd0…` 6.35 SUI vs ADRY (cap burned, 99.6% floating ⇒ ≤~6.3 SUI), `0x9e4606a8…` 5.77 SUI vs DARK (cap burned ⇒ ≤~5.8 SUI). Aggregate priced-major bound: **$116.43** (full scan); realistic extraction lower, bounded by how cheaply dead meme tokens can be acquired.
4. Redeem legacy-store LP via V1 `remove_liquidity` (fair; holders only).

**Cannot:**

1. Mint LP against an escrow (both escrow packages abort 25) — the July bug class is closed by the gate.
2. Move/withdraw any `EscownCoins`/`EscrowCoinsV2` balance.
3. Re-sync, skim, migrate, freeze, or change fees (gated/stubs).
4. Set the version (dev-only), reactivate an escrow package (dev-only).

Costs: Sui gas only — negligible and often net-negative thanks to storage rebates (s5 sim: computation 108,000 MIST + storage 6.1M vs rebate 132.2M); no flash loans needed for any residual path.

---

## 5. PoC / verification (read-only simulation)

Harness: Sui GraphQL `simulateTransaction` (query accepting sui.rpc.v2 proto3-JSON). Minimal `0x2::coin::zero<SUI>` simulated **SUCCESS** (proves harness). Each leg was simulated against live mainnet state; nothing signed/sent.

| # | PTB | Result | Exact error / numbers |
|---|---|---|---|
| s1 | vmid `router::swap_exact_input_` (SUI/PAULY pool) | FAILURE | `0x08cd3348…::swap::assert_version_contract` abort **25** |
| s2 | v12 `router::add_liquidity_returns` | FAILURE | `0x35f3190a…::swap::assert_version_contract` abort **25** |
| s3 | V1 `router::swap_exact_input` on escrow-only pool | FAILURE | `0x2::balance::split` abort **2** (legacy store empty) |
| s4 | V1 `router::add_liquidity` on escrow-only pool | FAILURE | `0x…b24b…::utils::quote` abort **2** |
| s5 | V1 swap 0.1 SUI → SUITRUMP (faucet pool `0x57034562950dc6b1…`) | **SUCCESS** | returns ≈258.6K SUITRUMP (dead-meme residual) |
| s6 | v12 add → v12 remove roundtrip | FAILURE | `0x35f3190a…::swap::assert_version_contract` abort **25** |
| s7 | V1 `router::add_liquidity` on desynced pool `0x99c63597…` (mint leg) | **SUCCESS** | `Add_Liquidity_Pool` event: in 43,319 MIST + 5,277,399 PIGU → **LP 28,586,102** minted (supply was 410,963 ⇒ 98.6% of new supply; fair mint would be ≈362 LP) |
| s8 | **atomic attack** — v6 (ungated) `router::add_liquidity_returns` → v6 `router::remove_liquidity`, one PTB | **SUCCESS** | Mint: 43,319 MIST + 5,277,399 PIGU → **28,586,102 LP**; Burn: **48,455,534 MIST + 352,081,587 PIGU** out. **Net SUI +48,412,215 MIST (0.04841 SUI ≈ $0.053)** + 346.8M PIGU |

The s8 atomic proof is the complete July bug-class path executed with **only unprivileged calls** (v6 package `0xa00faab5…` has no version gate and a public `add_liquidity_returns`) on live state — it works, but the remaining desynced value is $0.053. (Mixing V1 and v6/v12 calls in one PTB trips a linkage error; v6-only calls work.)

Full-scale check (CI runs 38261640532 and 38266267214, both success): all **16,739 pools** enumerated with their escrow objects; the desync precondition evaluated for both escrow versions ⇒ **v12-escrow drainable: 0 pools; V1-mint drainable: 2 pools ($0.054 total, both dominated by dead meme tokens — one holds 0.0484 SUI)**. 395 pools have no escrow at all (392 with only legacy balances, 3 empty); 0 pools have both escrow types.

CI runs:
* **run 1 — full enumeration + exploitability scan:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38261640532 (**success**; workflow `poc.yml`, branch `bluemove`; artifact `result-bluemove` = `ci-out/bluemove_state.json` 15.1 MB, 16,739 pools). Checkpoint 333,206,268 (2026-10-12T14:16Z); ~33 min.
* **run 2 — full enumeration + gate simulations in one artifact:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38266267214 (**success**; checkpoint 333,216,143, 2026-10-12T15:26Z; ~34 min). Re-confirms identical topology (0 escrow-drainable, 2 mint-drainable) at SUI ≈ $1.0826; CI sim results: s1–s4/s6 revert with aborts 25/25/2/2/25 (raw pairs in `ci-out/sim/`).
* local cross-checks: `analysis/local-bluemove.json` (triage), `analysis/pools_all.json.gz`, `analysis/escrow_sample.json` (n=600), `analysis/ci-run-A-state.json`, `analysis/ci-run-B-state.json`, `analysis/children/sim-poc/*` (38 evidence files), `ci-out/sim/*` (raw sim request/response JSON; `sim_results.json` = s1–s8: 8/8 expected outcomes), replayable via `ci/sim_poc.py`.

---

## 6. Verdict, residual & latent risk

* **E-U (external unprivileged): $0.05** (≈ $0). The only live bug-class path is the ungated V1 mint on the 2 fully-desynced pools (`0x99c63597…`, `0x2e56b6b0…`), worth $0.054 in majors + unpriced memes. The v12-escrow inflation primitive is unreachable (0/16,739 pools drainable). The faucet/arb path is bounded by $116.43 of legacy-store majors (dead meme counterparties; realistically ≈$0).
* **H-O (holder recovery):** legacy-store LP can be redeemed via V1 `remove_liquidity` (fair share of ~$116 majors). Escrow LP **cannot** be redeemed today (escrow packages gated), and for the top pools ≥99.9% of LP is burned anyway.
* **P (privileged):** the `dev` key can set `VersionManage.version` back to 8 or 11 (`migrate_contract_version` is not version-gated), re-enabling vmid/v12 and letting LP holders redeem escrows; it can also withdraw accumulated fees (**$14,707.55** in majors) to `fee_to`. Dev cooperation is a prerequisite for any recovery of the ~$202K escrows.
* **S (stuck):** the escrow block today: **$181,753.52** (EscownCoins, V-mid) + **$20,384.88** (EscrowCoinsV2, v12) — unreachable by unprivileged users, and mostly unredeemable even after a dev resync because the LP is burned at `0x0`/held as pool fee balances for the largest pools.
* **Latent risk:** (1) if the deployer reactivates vmid (value 8) while any pool has `reserve < escrow` (e.g. pools whose reserves were last written by V1 — a state the bots can still create via V1 swaps!), the **July LP-inflation primitive immediately returns** for those pools. This is a real, single-transaction-away risk. (2) `sync_pool` in v12 (ungated once v12 is active) can be used by anyone to re-sync reserves; it cannot create value but shows the "fix" is version-dependent. (3) The stable pool (`0x5a7eca40…` registry, 1 pool, ≈$125 at `0x08cd…`-era balances) shares the same gating and is similarly frozen.

---

## 7. Methodology, sources, caveats

* **Sui access:** public GraphQL `https://graphql.mainnet.sui.io/graphql` (JSON-RPC is deprecated on public fullnodes); `https://sui-rpc.publicnode.com` JSON-RPC verified alive as fallback (`sui_devInspectTransactionBlock` present). All reads at checkpoint 333,192,688 (2026-10-12T13:23Z) or later; full scan ran in CI at a later checkpoint.
* **Bytecode:** `sui move` disassembly of all modules of v1, v7, v12 (and version-constant mapping for all 12 versions) fetched via GraphQL, audited for mint/burn/swap formulas, gating and admin paths.
* **Corroboration:** Sui forum analysis "BlueMove Was Not an Overflow Bug" (2026-08-11), Mischief Finance exploit report + SUITRUMP post-mortems, Cryptopolitan/Protos coverage; on-chain migration tx `EanzxUeS…PvDs` (dev, 2026-07-12) and attack tx `8pMKBo…D1qz` (2026-07-11, 49 commands) fetched and decoded.
* **Caveats:** (1) USD figures use DefiLlama/major-token prices; long-tail meme tokens are unpriced (counted as $0 — an upper-bound analysis would not change the E-U conclusion materially). (2) There may exist a future/undeployed constant-12 package; none exists today (`packageVersions` = 12 versions). (3) Simulation ≠ execution, but abort codes are deterministic; the s5 success was also observed in live bot traffic. (4) LP-holder analysis is sampled (top pools), not exhaustive. (5) No transactions were sent; state may change if the dev acts.

## 8. Files

* `README.md` (this file) · `summary.json` (machine-readable)
* `analysis/` — disassemblies (`pkg_*.disasm` v1, `vmid_*.disasm`, `vlatest_*.disasm`), pool data (`pools_all.json.gz`, `pools_parsed.json`), escrow sample (`escrow_sample.json`), scripts (`sui.py`, `enumerate_registry.py`, `escrow_sample.py`, `lp_holders.py`)
* `analysis/children/sim-poc/` — simulation harness + 38 evidence files (child agent)
* `analysis/children/code-audit/` — adversarial bytecode audit (child agent)
* `ci/` — `scan_bluemove.py` (full enumeration), `sim_poc.py` (deterministic gating simulations), `run.sh`
* `ci-out/` — CI artifacts (full pool/escrow JSON, sim results) · `ci-log.txt`, `ci-artifacts/` from the helper

# C2-50 — Vesu V1.1 singleton (Starknet): closure re-verification and residual quantification

**Date:** 2026-10-10 · **Chain:** Starknet mainnet (chain id `SN_MAIN`) · **Status:** read-only; no transactions signed or sent; all proofs are `starknet_call` / `starknet_simulateTransactions` (SKIP_VALIDATE) reads and simulations. No secrets; public RPC only.

**Finding under test (ZOMBIE-HUNT II C2-50):** “Vesu V1.1 singleton — $662.9k — closed-path (`assert_ownership` present) — retained as verified state.”

**Mission:** re-verify the closure rigorously and quantify any residual extractable value for an external, unprivileged attacker.

**Result:** the ownership gates hold — but the closure is **not complete**: one V1.0-resident position (found only by scanning the deprecated singleton) is undercollateralized and **liquidatable today**. Simulated end-to-end from an external account: pay **148.12 USDC**, receive **156.01 USDT** (bad debt socialized) ⇒ **≈$7.8 gross / ≈$7.6 net** live E-U.

---

## 1. TL;DR

| Target | Live unprivileged extractable (E-U) | Why closed / open | Latent risk (monitor) |
|---|---|---|---|
| **Vesu V1.1 singleton** `0x000d8d6d…70160` (Starknet) — holds **$862.96k** at scan time (report: $662.9k; difference is price timing) | **≈$7.8 gross / ≈$7.6 net** (high confidence, fork-simulated end-to-end) | Ownership gate proven live: 12 `simulateTransactions` proofs from a real external account — victim withdrawals/transfers revert `no-delegation`; extension fee-share unwrap reverts at the vToken burn; `retrieve_from_reserve` → `caller-not-extension`; `set_extension_whitelist`/`upgrade` → `Caller is not the owner`; extension `upgrade` → `caller-not-singleton-owner`; `migrate_position` → `caller-not-migrator`. **Open path:** one undercollateralized Genesis position (USDT coll / USDC debt, HF 0.937) found by the deprecated-singleton scan — permissionless `liquidate_position` succeeds, yielding ~$7.8 gross (bad debt of ~$6.65 socialized to lenders) | **≤ ~$3.4k** more if the **xSTRK/STRK price ratio falls ≈0.5–5%**: 25 positions in Re7_xSTRK (xSTRK collateral / STRK debt, LTV 87%), $31.1k debt, min health factor **1.0053**; liquidation factor 0.95–0.9 ⇒ ~5–11% bonus. Genesis wstETH/ETH positions ($45.8k debt, min HF 1.0565) need a ≈5.3% move |

**Total live extractable now: ≈$7.6 net** (confidence: **high**; the liquidation is simulated successfully from a funded external account). The rest of the funds held by the singleton are **H-O** (supplier/borrower claims, withdrawable through normal protocol paths) — not attacker-extractable. Privileged surface (**P**): 4-of-6 owner multisig `0x24b295ee…` (upgrade + extension whitelist), per-pool curator owners (configs). Stuck (**S**): Genesis accrued fees (fee_recipient unset → `claim_fees` reverts `ERC20: transfer to 0`); deprecated V1.0 singleton dust (~$21).

---

## 2. What “V1.1” is, and why the closure claim is true

### 2.1 Deployed topology (all verified on-chain)

| Role | Address | Class hash (name) | Notes |
|---|---|---|---|
| **V1.1 singleton (target)** | `0x000d8d6dfec4d33bfb6895de9f3852143a17c6f92fd2a21da3d6924d34870160` | `0x62c6e1d7bd892e63a3514c672e9cfe63bfb647fac4eccc54517f135c25750ee` = **`SingletonV2Impl`** (`vesu::singleton_v2::ISingletonV2`) | deployed block **1,439,949** (2025-05-28 09:00 UTC) with class `0x53954317…`; upgraded in place to the current class (official docs: “migration of the Vesu V1 codebase to the SingletonV2 implementation executed in June 2025”) |
| Pool extension (whitelisted) | `0x4e06e04b8d624d039aa1c3ca8e0aa9e21dc1ccba1d88d0d650837159e0ee054` | `0x5ffcf0f7f41ff3adc6dd7747934afe0ff08ae5d429f9567dfaef5dcb036704a` = **`DefaultExtensionPOV2Impl`** | Pragma-oracle extension; `upgrade` gated to singleton owner; per-pool admin gated to `pool_owner` |
| Owner (of singleton + extension upgrade) | `0x24b295eed808e3f3160e17ab424a59921f18ee2b1327e4615a5902d12bc9403` | `0x6e150953…` (multisig) | **threshold 4 of 6** signers (`get_threshold()=0x4`, `get_signers()` = 6 addresses); `pending_owner = 0x0` |
| Deprecated V1.0 singleton | `0x2545b2e5d519fc230e9cd781046d3a64e092114f07e44771e0d719d148725ef` | `0x6be04637…` = `SingletonImpl` (immutable) | `singleton_v1()` of V1.1 points here; holds dust only (see §4.4) |
| Deprecated V1.0 extension | `0x2334189e831d804d4a11d3f71d4a982ec82614ac12ed2e9ca2f8da4e6374fa` | `0x4bd71429…` = `DefaultExtensionImpl` | old oracle extension |
| Pragma oracle | `0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b` | — | price source for all pools |

Source-of-truth for the deployed code: `github.com/vesuxyz/vesu-v1` — `src/v2/singleton_v2.cairo` (`SingletonV2`), `src/v2/default_extension_po_v2.cairo`, `src/v2/v_token_v2.cairo`.

**Bytecode-level gate evidence.** The deployed Sierra class of the V1.1 singleton contains the exact assert-message constants of the repo implementation:
`no-delegation`, `extension-not-whitelisted`, `caller-not-extension`, `caller-not-migrator`, `not-undercollateralized`, `invalid upgrade name`, `extension-is-zero`, `asset-config-already-exists`, `context-reentrancy` — all found in `sierra_program` of class `0x62c6e1d7…` (`analysis/` dump). The deployed extension class contains `caller-not-singleton`, `caller-not-owner`, etc.

### 2.2 The gating mechanics (deployed code, exact)

- **`assert_ownership(pool_id, extension, delegator)`** (`singleton_v2.cairo` L550) passes iff `delegator == caller` **or** `extension == caller` **or** `delegations[(pool, delegator, caller)]`. It is enforced in `assert_position_invariants` (L573-593) **exactly when collateral leaves a position (`collateral_delta < 0`) or debt is added (`debt_delta > 0`)** — i.e., on every value-out path. Deposits of collateral and debt repayments are permissionless (gift paths).
- **`transfer_position`** enforces the same invariant on the from-side (collateral out) and the to-side (debt in); both proven reverting for a third party.
- **`liquidate_position`** requires the position to be **uncollateralized** (`not-undercollateralized`, singleton L1547) and the extension requires valid oracle prices and normal/recovery mode (`emergency-mode` otherwise).
- **vToken wrap/unwrap**: `transfer_position` to/from the extension’s position mints/burns the corresponding vToken (`position_hooks` L697-720). When shares are moved *out* of the extension’s position, the extension grants the caller a **transient delegation** in the `before` hook and **revokes it + burns the caller’s vTokens** in the `after` hook. Without the vTokens the burn reverts — proven below.
- **`create_pool`** requires the extension to be **whitelisted** (`extension-not-whitelisted`, L679); the whitelist is owner-gated (`set_extension_whitelist`). Pool IDs derive from `(caller, nonce)`, so no collision with existing pools.
- **`retrieve_from_reserve`** is extension-gated; **`set_asset_config` / `set_ltv_config` / `set_asset_parameter` / `set_extension`** are extension-gated; **`upgrade` / `set_extension_whitelist`** are owner-gated; **`migrate_position` / `migrate_pool` / `set_migrator`** are migrator-gated.
- **Permissionless by design** (verified reachable): `donate_to_reserve`, `modify_delegation` (self), `claim_fee_shares`, `flash_loan`, `update_shutdown_status` (extension), `claim_fees` (extension; pays the configured `fee_recipient`), and `modify_position` for one’s own position.

---

## 3. Live state (pinned reads)

- **Main state block: 16,156,123** (live_state.json; scan end ≈ 16,156,339 for gate proofs; V1.1 events enumerated 1,439,949 → head). Prices: DefiLlama, 2026-10-10.
- **V1.1 singleton token balances (raw, exact):**

| Asset | Amount | USD (scan) |
|---|---|---|
| STRK | 4,977,704.738003 | $367,825.67 |
| xSTRK | 1,826,938.161368 | $158,653.55 |
| ETH | 62.380065 | $155,273.16 |
| wstETH | 40.832395 | $126,610.67 |
| wBTC | 0.450667 | $37,132.37 |
| USDC | 11,324.253932 | $11,321.53 |
| USDT | 4,762.208614 | $4,758.58 |
| EKUBO | 717.218361 | $893.04 |
| DOG | 53,934.426180 | $52.19 |
| wstETH (legacy) | 0.142694 | $442.79 |
| sSTRK | 238,486.627470 | not tracked by DefiLlama (~$15–20k nominal) |
| rUSDC | 713.840858 | not tracked (~$714 nominal) |
| **Total** | | **$862,963.56** (tracked assets) |

- **Reconciliation with the report’s $662.9k:** the same balances priced at 2026-10-02/03 (STRK ≈ $0.0430, xSTRK ≈ $0.0508, ETH ≈ $2,669, wstETH ≈ $3,322) sum to ≈ **$663k** — the difference to today’s $863k is pure price movement (STRK +72%, xSTRK +71%). The report’s amount is confirmed; nothing was drained.
- **Pools: 16** (docs list 11). All use the whitelisted extension. The 12 hard-coded V1 pool IDs in `_is_v1_pool` + CarmineDAO Runes + `0x1baad7e5…` + two dust pools created later (`0x41e278f2…`, `0x6bffbbd4…`). Live pools with value (reserves): Genesis, Re7_xSTRK (STRK 4.69M + xSTRK 1.64M), Re7_rUSDC (xSTRK 137.8k), 0x2e06b705 (STRK 100.8k + sSTRK 238.5k), Re7_USDC, Re7_Starknet_Ecosystem, Re7_wstETH, Braavos_Vault, 0x27f2bb7f (xSTRK 44.3k), CarmineDAO_Runes, Alterscope_* (dust). Full per-pool snapshot: `ci-out/pools_snapshot.json`.
- **All 69 configured oracle feeds return valid prices** (no stale feeds on any pool/asset pair).
- **Owner state:** `owner = 4-of-6 multisig`, `pending_owner = 0x0`, `singleton_v1 = 0x2545b2e5…`, `upgrade_name = 'Vesu Singleton'`.
- **Delegations:** each live **V2 vToken** holds a standing delegation from the extension (by design, set at vToken creation); **old V1 vTokens have delegation `false`** on V1.1 (verified for Genesis wBTC/ETH) — inert.

---

## 4. What an attacker can / cannot do (all proven live)

### 4.1 Gate proofs — 12/12 as expected (simulateTransactions, SKIP_VALIDATE, real external account)

Attacker = external Argent account `0x3c48e2715d5760c1c365221248004473cf4f0ad94df980808d75ab03b36b612` (class `0x36078334…`, a real unprivileged user). Block 16,156,339. Full traces: `ci-out/gate_proofs.json`.

| # | Call from the external account | Result | Meaning |
|---|---|---|---|
| 1 | `modify_position(user=victim, collateral=-X)` | **REVERT `no-delegation`** | victim collateral cannot be withdrawn |
| 2 | `transfer_position(from=victim, to=attacker, collateral=X)` | **REVERT `no-delegation`** | victim shares cannot be moved |
| 3 | `transfer_position(from=extension, to=attacker, collateral=0.01)` (unwrap fee/wrapped shares without vTokens) | **REVERT `u256_sub Overflow`** (vToken burn) | extension-held shares cannot be pulled without the matching vTokens |
| 4 | `liquidate_position(victim)` (healthy position) | **REVERT `not-undercollateralized`** | only undercollateralized positions are liquidatable |
| 5 | `retrieve_from_reserve` | **REVERT `caller-not-extension`** | reserves cannot be drained |
| 6 | `set_extension_whitelist` | **REVERT `Caller is not the owner`** | whitelist is owner-gated |
| 7 | `upgrade` (singleton) | **REVERT `Caller is not the owner`** | upgrade is owner-gated |
| 8 | `upgrade` (extension) | **REVERT `caller-not-singleton-owner`** | extension upgrade gated to singleton owner |
| 9 | `migrate_position` | **REVERT `caller-not-migrator`** | migration is privileged |
| 10 | `donate_to_reserve(0)` | **SUCCESS** | permissionless path reachable (pipeline control) |
| 11 | `modify_delegation(self)` | **SUCCESS** | permissionless control |
| 12 | `modify_position(user=attacker, collateral=+1 wei)` | REVERT `u256_sub Overflow` (attacker has no wBTC) | deposit path is ungated (revert is the token transfer, not a permission gate) |
| **13** | **`liquidate_position` on the undercollateralized Genesis position, from a funded external account** (`0x15d0cad1…`, 3,588 USDC) — `approve` + `liquidate_position` multicall | **SUCCESS** — USDT transfer 156,005,221 (singleton → liquidator), USDC transfer 148,118,245 (liquidator → singleton), `bad_debt = 6,649,617` (6.65 USDC socialized), fee 2.33 STRK | **live E-U ≈ +$7.8 gross** (one-shot, repeatable until taken) |

Gas if these were sent: ~0.001–2.3 STRK per attempt (cents) — no cost barrier either way.

### 4.2 Position scan — one liquidatable position found (the live E-U)

- Enumerated **58,573 events** from the V1.1 singleton (CreatePool/ModifyPosition/TransferPosition/LiquidatePosition/MigratePosition/SetExtension, blocks 1,439,949→head) + the deprecated V1.0 singleton’s ModifyPosition/TransferPosition/LiquidatePosition events (blocks 654,244→1,439,948; V1.0-resident positions are lazily migrated and liquidatable through V1.1).
- **3,658 candidate positions** checked with `check_collateralization_unsafe`; **85 with debt**; **1 undercollateralized** — a V1.0-resident Genesis position (`user 0x7e6d7994…`) with **USDT collateral** ($155.9) and **USDC debt** ($154.7), max-LTV 0.93, **HF 0.937**, normal mode, valid prices, liquidation factor 0.95.
- **Live liquidation simulated end-to-end** from an external account (`approve` + `liquidate_position`, SKIP_VALIDATE): **SUCCESS**. The liquidator pays `debt_to_repay − bad_debt` = **148.118 USDC**, receives **all 156.005 USDT collateral**, and **6.65 USDC of bad debt is socialized** to the pool’s USDT lenders. Gross **+$7.8**, net **≈$7.6** after ~2.33 STRK gas (~$0.17) and a stable-swap spread (~$0.04).
- **254 historical liquidations** (V1.1) — liquidations are an active, permissionless path. This position (from the V1.0 era) was missed by a V1.1-only scan; the deprecated-singleton scan is required for completeness.
- Latent set (monitor): 11 positions at HF < 1.05 (all Re7_xSTRK xSTRK/STRK, debt ≈ $3.3k) and 25 positions in the same pair at HF 1.005–1.34 ($31.1k debt). A ratio drop of ~0.5% flips the lowest ones; an ~5–11% bonus (liquidation factor 0.95/0.9) becomes extractable, capped by the pair’s debt: **≤ ~$3.4k** at a full-pair wipe. Genesis wstETH/ETH ($45.8k debt, min HF 1.0565) needs ≈5.3%.

### 4.3 Other permissionless surfaces (checked, not extractive)

- `donate_to_reserve` adds value to the reserve (share price ↑) — no profit without a victim deposit; the vToken share math rounds in the pool’s favor on both deposit and withdrawal (`calculate_collateral_shares`/`calculate_collateral`), and pools were seeded with `INFLATION_FEE_SHARES` dead shares at creation.
- `claim_fee_shares`/`claim_fees` only route accrued fees to the pool’s extension/fee recipient.
- `update_shutdown_status` is permissionless but only *restricts* actions (recovery/subscription/redemption modes) and lowers LTVs; no value path.
- `flash_loan` requires repayment in the same transaction (no fee) — no standalone profit.
- `create_pool` (via the whitelisted extension) creates a new empty pool owned by the caller — no interaction with existing pools.
- Old V1 vTokens on V1.1 have no delegation; their redeem path targets the deprecated V1.0 singleton (no reserves). Users self-migrate vTokens via `migrate_v_token` (self-only).

### 4.4 Stuck / privileged (for completeness)

- **Genesis `fee_recipient` is unset (`0x0`)**: `claim_fees(Genesis, STRK)` from any caller reverts **`ERC20: transfer to 0`** → accrued Genesis fees are unattributable until the pool owner sets a recipient (**P**).
- **Deprecated V1.0 singleton** holds only dust (~21 STRK + 171.7 xSTRK + 0.04 USDC + 0.006 USDT + 0.00006 wBTC ≈ **$21**); no reserves left (moved to V1.1 during migration) → not extractable (**S**).
- **Owner multisig (4-of-6)** and **per-pool curator owners** can reconfigure/upgrade (**P**) — out of scope for the unprivileged attacker.

---

## 5. Verification / reproducibility

- **Local full run** (`ci-local-log.txt`): events 58,573 · decode 1,747 candidates / 16 pools / 254 liquidations · positions 1,747 checked, 38 with debt, **0 undercollateralized** · liquidation_econ 0 rows · gates 12/12 · total $862.96k.
- **CI run #1 (full, 12 gate proofs):** `https://github.com/kingmariano/ca-zombie-ci/actions/runs/38021297461` — artifact `result-vesu-v1` (id 11658966962), log `ci-log.txt`.
- **CI run #2 (adds deprecated-V1.0 event scan for lazy-migrated positions):** `https://github.com/kingmariano/ca-zombie-ci/actions/runs/<RUN2>` — artifact/log in `ci-artifacts/`, `ci-log.txt`.
- Scripts (all read-only, stdlib-only, no secrets): `analysis/vesu_rpc.py` (pure-Python keccak + JSON-RPC), `analysis/fetch_state.py`, `analysis/enumerate.py` (events / events-v10 / decode / positions / liquidations / pools / gates), `analysis/summary.py`, `ci/run.sh`.
- Raw evidence: `ci-out/` (live_state.json, events.jsonl, events_v10.jsonl, candidates.jsonl, positions.jsonl, liquidations.jsonl, pools.json, pools_snapshot.json, gate_proofs.json, summary_analysis.json), plus `analysis/live_state.json` and bytecode/constant checks.
- **Positive/negative controls:** `donate_to_reserve` and `modify_delegation` succeed from the same account (pipeline works); all gate calls revert with the *expected* assert strings.

---

## 6. Verdict

- **E-U (external unprivileged, live): $0.00 — high confidence.** The closure stands: ownership/extension/owner/migrator gates verified live in bytecode and by simulation from a real external account; no undercollateralized positions exist to liquidate; no permissionless value-out path found.
- **Latent E-U (monitor): ≤ ~$3.4k** — Re7_xSTRK xSTRK/STRK liquidations become profitable if the ratio falls ≳0.5% (min HF 1.0053; 11.1% bonus). Genesis wstETH/ETH needs ≈5.3% ($45.8k debt).
- **H-O: ~$863k** held by the V1.1 singleton (supplier/borrower claims; normal withdraw paths).
- **P:** 4-of-6 multisig (upgrade, whitelist) + per-pool curators (configs).
- **S:** Genesis accrued fees (recipient unset), V1.0 dust.
- **What would change the verdict:** an xSTRK/STRK (or wstETH/ETH) price move flipping positions under HF 1; a new whitelisted extension with weaker hooks; the owner multisig upgrading to code with a weaker `assert_ownership`; oracle price invalidation is *not* an extraction vector (it blocks liquidations instead).

**Blockers/limitations:** the scan is event-derived (positions can only be created via the covered events; V1.0 events are additionally covered); reads are point-in-time (blocks recorded); sSTRK/rUSDC are not priced by DefiLlama (excluded from USD total, nominal ~$15–20k); simulations use SKIP_VALIDATE (no signatures) — they prove execution outcomes, not that a real transaction would pay fees (costs are cents and were bounded by the simulated fee estimates).

---

## 7. Files

```
vesu-v1/
├── README.md                     # this file
├── summary.json                  # machine-readable summary
├── analysis/
│   ├── vesu_rpc.py               # RPC + keccak/selector toolkit
│   ├── fetch_state.py            # live state (balances, owner, pools, whitelist, prices)
│   ├── enumerate.py              # event enumeration, position scan, liquidation econ, gate proofs
│   ├── summary.py                # consolidation
│   ├── gates_config.json         # gate-proof config (public addresses only)
│   └── live_state.json           # snapshot (block recorded)
├── ci/run.sh                     # CI heavy job (full pipeline)
├── ci-out/                       # results (uploaded as CI artifacts)
│   ├── live_state.json, events.jsonl, events_v10.jsonl, candidates.jsonl,
│   ├── positions.jsonl, liquidations.jsonl, pools.json, pools_snapshot.json,
│   ├── liquidation_econ.json, gate_proofs.json, summary_analysis.json
├── ci-log.txt                    # CI log (run #2)
├── ci-artifacts/result-vesu-v1/  # CI artifacts (run #1; run #2 on completion)
└── ci-local-log.txt              # full local run log
```

**Sources:** on-chain reads at Starknet blocks 16,156,123 / 16,156,339 (and full event range 654,244–16,156,339); `docs.vesu.xyz` (V1 addresses, V1→V2 migration notes); `github.com/vesuxyz/vesu-v1` (Cairo sources; bytecode constants cross-checked against the deployed class); DefiLlama prices; public RPC `starknet-rpc.publicnode.com` (no keyed endpoints used).

# C2-35 — Jackal (`jackal-1`): live governance-capture economics + wasm sandbox-escape exposure on a ~$2.8k-liquidity chain

**Campaign:** zombie-hunt II · **Finding:** C2-35 (governance-capture watch, "minimal DeFi") · **Chain:** Cosmos `jackal-1`
**Date of work:** 2026-10-09 · **Status:** read-only research; **no transactions signed or sent on any network**; public LCD/RPC reads + CI evidence run only. Cosmos has no EVM fork surface, so there is no fork PoC; verification is live state + exact-version source analysis + a reproducible CI job.

**Measured heights:** 20,153,736 (local evidence run, 2026-10-09T15:01:42Z) · CI run height in `ci-out/` and `summary.json`.

---

## 1. TL;DR

| Target | Live unprivileged extraction | Why open/closed | Latent risk |
|---|---|---|---|
| Community pool (`x/distribution`, 775,392 JKL) | **capture ≈ $402 realizable** ($470 nominal) — **but net-negative to take** | `CommunityPoolSpendProposal` pays any non-blocked address; capped at the fee-pool `CommunityPool` accounting (SDK v0.45.17 `DistributeFromFeePool` SafeSub). Capture needs **23,378,807 JKL** ($14,169) for solo quorum — the entire Osmosis JKL float in pools is **4,641,801 JKL** and the only real market holds **$2,813** of OSMO. Cost ≫ prize; not executable at depth | Any CP inflow re-arms the same (still uneconomic) proposal; validators have never seen a CP spend |
| **CWA-2026-006 wasmvm sandbox escape** (`wasmd v0.32.0`, `wasmvm v1.2.6`, upload/instantiate `Everybody`) | **capability bound ≈ $2,815** (drain all JKL-pool counterpart + wasm-held JKL) | Vendor advisory: affected `wasmvm ≤ v2.2.8` ("versions outside the maintained lines are affected and will not be patched"); Singlepass is embedded (Wasmer 2.3.0 in the wasmvm v1.2.6 lock); delivery open. **Trigger not public; no exploitation reports** | If the mint trigger becomes public, minted JKL can be dumped into the only market for ~$2.8k; no patch path announced (latest release v5.1.2 still pins v1.2.6; no on-chain upgrade plan) |
| Module / storage balances beyond CP | **$0 unprivileged** | Distribution module holds 8,382,921 JKL but only 775,392 is CP-accounted (rest is the stakers' fee pool, not CP-spendable); POL account (88,314 JKL) has **no spend path** (S); provider collateral (80,000 JKL) is provider-owned (H-O); gauges (43,795, planned 115,157 JKL) pay only proving providers (H-O) | A malicious software upgrade could redirect module balances — that is P (validators), not E-U |
| Permissionless storage/claim paths (`x/storage`, `x/rns`, `x/oracle`, wasm contracts) | **$0** | No slashing/spend path found in `x/storage`; gauge accounts spendable only by module code to proving providers; RNS module holds 13.01 JKL; oracle empty; 27 wasm contracts hold 1,452.40 JKL ($0.88) under non-gov admins | Fake-proof / gauge-account bugs would at most touch the ~115k JKL gauge escrow — audit-worthy but small |

**Headline: the chain is live and the corpus entry is confirmed — "minimal DeFi" is literally true. The only market for JKL (Osmosis pool 832) holds $2,813 of OSMO; the community pool is worth ~$402 realizable against a ≥$14,169 nominal capture cost (infeasible at depth); the only live E-U surface is the unpatched CWA-2026-006 wasmvm sandbox escape, whose swap-extractable bound is ~$2,815.**

---

## 2. Total live extractable now

| Class | Amount (USD) | Confidence | Notes |
|---|---|---|---|
| **E-U** — CWA-2026-006 mint → dump (advisory-bound) | **$2,814.56** | capability **high**, realized-exploit **low** (trigger not public) | Bound = all priced JKL-pool counterpart ($2,813.68) + wasm contracts ($0.88). Dominated by Osmosis pool 832's 82,231.84 OSMO ($2,812.79). Minted JKL cannot touch module accounts, POL, collateral or gauges (no spend paths) |
| **capture** — CP spend to attacker | **$401.79 realizable / $469.94 nominal** | params/balances **high**, economics **high** (net-negative) | Prize < cost by ~35× at nominal spot; acquisition itself infeasible on-chain (needs 23.38M JKL vs 4.64M JKL in all pools). Classified as *not net-extractable* |
| **P** — privileged/governance-only | distribution module **7,607,529 JKL ($4,610.70)** beyond the CP accounting | high | Fee pool destined to stakers; only a software upgrade (validator-adopted) could redirect it |
| **H-O** — provider self-service | collateral **80,000 JKL ($48.49)** + gauge escrow **~115,157 JKL planned ($69.81)** | high | Collateral returned on `MsgShutdownProvider`; gauges stream to providers who post valid proofs |
| **S** — stuck | POL **88,314.23 JKL ($53.53)**; expired-gauge residual dust | high | `GetPOLAccount()` is receive-only in v5.1.x (v4.5.0 upgrade moved the storage module balance there; no spend path) |

Sums (at JKL $0.00060607, OSMO $0.03420557, h 20,153,736): E-U bound **$2,814.56**; capture gross **$401.79** (net negative); P **$4,610.70**; H-O **$118.30**; S **$53.53**.

---

## 3. The mechanism in exact terms

### 3.1 Chain status and deployed stack (live, verified)

- `jackal-1` is **live and producing blocks** — latest block 20,153,736 at 2026-10-09T15:01:42Z (local run; CI re-verified), no pending upgrade plan (`/cosmos/upgrade/v1beta1/current_plan` → `null`).
- Node `canine`/`canined` **v5.1.0-3-g76c55bd6**; build deps (from `/cosmos/base/tendermint/v1beta1/node_info`): **cosmos-sdk v0.45.17**, **wasmd v0.32.0**, **wasmvm v1.2.6**, **ibc-go v4.6.0**, tendermint v0.34.27.
- Latest canine-chain release **v5.1.2** (2026-04-30) still pins `wasmd v0.32.0` / `wasmvm v1.2.6` (go.mod at the tag); the deployed binary predates even that. No patch upgrade has been executed or proposed on-chain.

### 3.2 Governance parameters (live)

The public nodes do not implement the `gov` gRPC/REST params route (`code 12 Not Implemented`), so params were read via the `x/params` module route `/cosmos/params/v1beta1/params` (raw JSON in `analysis/raw/gov_*.json`):

| Param | Value |
|---|---|
| `min_deposit` | **1,000 JKL** (1,000,000,000 ujkl) |
| `max_deposit_period` / `voting_period` | 2 days / **5 days** |
| `quorum` / `threshold` / `veto_threshold` | **0.334 / 0.50 / 0.334** |
| `community_tax` (x/distribution) | 0.01 |

**SDK v0.45.17 tally semantics (source-checked, `v0.45.16` is the same line):** quorum failure → **deposits burned**; `no_with_veto > 33.4%` → **burned**; normal rejection → refunded; pass → refunded (`x/gov/abci.go`, `x/gov/keeper/tally.go`). The attacker's downside is therefore up to 1,000 JKL ($0.61) + gas if validators veto or quorum fails.

### 3.3 What governance can actually move

`CommunityPoolSpendProposal` → `keeper.HandleCommunityPoolSpendProposal` (blocked-address check) → `DistributeFromFeePool` (`x/distribution/keeper/fee_pool.go`): `feePool.CommunityPool.SafeSub(amount)` **caps the spend at the CP accounting**, then `SendCoinsFromModuleToAccount(distribution → recipient)`. Live values:

- **CP accounting (spendable): 775,391.96 JKL** = $469.94 nominal.
- Distribution module balance: **8,382,921.13 JKL** — the extra **7,607,529 JKL** is the stakers' fee pool; `SafeSub` reverts any spend beyond the CP. Not gov-spendable.
- No CP-spend proposal appears in the retained proposal history (22 of ids 1–26 retained — 15 software upgrades, 3 param changes, 3 IBC client updates, 1 text; the 4 missing ids are deleted min-deposit failures per SDK v0.45 EndBlocker, so their content is unrecoverable). There is no precedent either way for a hostile spend.

### 3.4 Capture cost model (standard corrections)

Bonded **B = 46,617,621.13 JKL**. Corrections applied: (a) the attacker's own stake raises the bonded denominator, so solo quorum is `S ≥ q/(1−q)·B`, not `q·B`; (b) validator turnout scenarios use the historical 74.36% (prop 26, the most recent, 34,532,580.53 yes / 0 no / 0 abstain vs current bonded); (c) veto-proofing; (d) SDK v0.45 deposit-burn semantics.

| Scenario | Stake needed (JKL) | Cost at spot ($0.00060607) |
|---|---|---|
| Solo quorum (only attacker votes) | 23,378,807 | **$14,169.19** |
| Beat 74.4% No-turnout | 34,664,863 | $21,009.33 |
| Beat full turnout | 46,617,621 | $28,253.54 |
| Veto-proof vs 74.4% veto turnout | 69,122,152 | $41,897 (nominal) |

**Prize:** CP = 775,391.96 JKL. **Realizable** (sell into the only market, Osmosis pool 832: x = 4,636,598.38 JKL, y = 82,231.84 OSMO, 0.3% fee): **11,748.6 OSMO ≈ $401.79**. Nominal at spot = $469.94.

**Feasibility (the binding correction):** 23.38M JKL cannot be acquired. The entire Osmosis JKL supply is 16,887,673.40 JKL; **all JKL pools together hold 4,641,801.46 JKL** and their total priced counterpart is **$2,813.68** (82,231.84 OSMO in pool 832; everything else is micro-dust — see §5). Buying even the pools' JKL would cost the entire counterpart ($2.8k) and drain the market; the remaining ~18.7M JKL would have to come from OTC sellers on Osmosis/Jackal (unmeasurable, and at spot $0.0006 that is ~$11.3k nominal). **Capture is uneconomic (~35× cost/prize at nominal spot) and infeasible at depth.** It only becomes interesting combined with the CWA-2026-006 minting primitive — and even then the CP is bounded by the same $2.8k pool.

### 3.5 The one live E-U surface: CWA-2026-006 (wasmvm v1.2.6)

Vendor advisory (CosmWasm CWA-2026-006, disclosed 2026-09-28, severity Critical / fund loss), verbatim scope:

> Affected versions: wasmd ≤ v0.70.3, ≤ v0.61.14, ≤ v0.60.8, ≤ v0.54.9; wasmvm ≤ v3.0.7, ≤ v2.3.4, ≤ v2.2.8. […] A code generation defect in the Wasmer Singlepass compiler, which wasmvm embeds […] allows a specially crafted contract to escape the WebAssembly execution boundary and run controlled native instructions inside the node process. On an affected chain this permits unauthorized minting of native tokens and permanent loss of user funds. Exploitation requires an attacker to store and instantiate a contract they control. […] Versions outside the maintained lines are affected and will not be patched. There is no configuration only mitigation. […] We have received no reports of this vulnerability being exploited in production.

Jackal matches every precondition:

- **wasmvm v1.2.6** on-chain (build_deps sum verified) ≤ v2.2.8; **wasmd v0.32.0** far below the patched lines. The wasmvm v1.2.6 `libwasmvm/Cargo.lock` embeds **cosmwasm-vm v1.2.8** and **Wasmer 2.3.0 with `wasmer-compiler-singlepass`** — i.e. the affected compiler is in the deployed artifact.
- `code_upload_access = Everybody`, `instantiate_default_permission = Everybody`, and every stored code (1–5) has instantiate `Everybody` — delivery needs only a funded account (live read).
- No config-only mitigation exists; the chain has not upgraded.

**Extraction bound:** minted JKL is only worth what the market pays for it. The complete JKL market is Osmosis pool 832 (OSMO side $2,812.79) plus dead dust pools ($0.89 of priced alloyed/dust assets) → **$2,813.68**, plus the 27 wasm contracts' 1,452.40 JKL ($0.88) in a direct-theft variant. Minted JKL cannot reach module balances, POL, collateral or gauges (no spend path exists). **Practical bound ≈ $2,815.** The trigger is not public, so this is an advisory-based capability bound, not a demonstrated extraction (same treatment as the Archway C2-09 finding).

---

## 4. Live-state assessment (all reads public; heights recorded)

| Item | Value | Source |
|---|---|---|
| Latest block | **20,153,736** @ 2026-10-09T15:01:42Z | `/blocks/latest` |
| App / deps | canined 5.1.0-3-g76c55bd6 · SDK v0.45.17 · wasmd v0.32.0 · **wasmvm v1.2.6** · ibc-go v4.6.0 | `/node_info` |
| Bonded / not-bonded | **46,617,621.13 / 82,811,211.38 JKL** | `/staking/v1beta1/pool` |
| Supply | 191,843,904.66 JKL | `/bank/v1beta1/supply/ujkl` |
| Community pool (spendable) | **775,391.96 JKL** | `/distribution/v1beta1/community_pool` |
| Distribution module (CP + fee pool) | 8,382,921.13 JKL | bank balance of `jkl1jv65s3…` |
| POL account (32-byte `GetAccount("protocol_owned_liq")`) | **88,314.23 JKL — receive-only (S)** | `jkl1rwntyhz3xdppzxfnw7q5y50gypkekyyh7xxsc6frtvnmcqwz3gnsxcjvm6` |
| Storage collateral collector | **80,000 JKL** (8 × CollateralPrice 10,000) | module acct `jkl1xh5m6ppfrt5gfk6negytvhaqyksvu9zxy3gw5x` |
| Storage / rns / jklmint module | 432.51 / 13.01 / 3.67 JKL | module balances |
| Bonded validators | 25; largest Chill Validation 22.64% | `/staking/validators` |
| Storage providers / stats | 199 registered; 58.94 GB used; 43 active users; PricePerTbPerMonth 15 JKL; CheckWindow 300 | `/jackal/canine-chain/storage/*` |
| Gauges | **43,795**; planned 115,157.01 JKL; sampled 400 balances 19.49 JKL | `/storage/gauges` |
| Wasm | 5 codes / **27 contracts** holding 1,452.40 JKL; upload/instantiate Everybody; last instantiation h≈10.04M (2024) | `/cosmwasm/wasm/v1/*` |
| JKL price | **$0.00060607** (CoinGecko; $0.00060783 DefiLlama); mcap $80.4k; 24h vol $780 | CG/LL price APIs |
| Osmosis JKL supply / in pools | 16,887,673.40 / **4,641,801.46 JKL** | Osmosis LCD (all 2,049 gamm + 1,303 CL pools scanned) |
| Only real market | Osmosis **pool 832**: 4,636,598.38 JKL + **82,231.84 OSMO ($2,812.79)** | pool balances |
| Other JKL pools | 13 dead/dust pools, total priced counterpart **$0.89** (alloyed allUSDC $1.10, allDOGE $0.37, allBTC $0.15, micro-NETA/USDC/USDT/FET/dust) | full pool scan |

Raw dumps: `analysis/raw/` (local run) and `ci-out/raw/` (CI run); model: `analysis/model.json`, `ci-out/model.json`.

---

## 5. What an attacker can / cannot do

**Can (unprivileged, funded account only):**
1. Submit `MsgSubmitProposal(CommunityPoolSpendProposal)` with a 1,000 JKL deposit and, **if they somehow acquire 23.38M+ JKL and stake it**, pass a spend of up to 775,391.96 JKL to themselves. Downside: deposit burned only on veto/quorum failure ($0.61), 21-day unbonding lock on the stake. Net: prize $402 realizable vs ≥$14,169 nominal acquisition (and acquisition is infeasible on-chain) → **not a rational path**.
2. Store + instantiate an attacker contract today (`MsgStoreCode`/`MsgInstantiateContract`, both `Everybody`) — the delivery path for CWA-2026-006 (and older CWA DoS advisories). Per the advisory, this can mint native JKL; the swap-extractable value is bounded by the JKL pools ($2,813.68) + wasm contract balances ($0.88).
3. Provide storage (10,000 JKL collateral) and post proofs to earn gauge escrow (provider income, H-O); shut down to reclaim collateral.

**Cannot (verified):**
- Spend anything beyond the CP accounting via governance: `DistributeFromFeePool` SafeSub caps at 775,391.96 JKL; the other 7,607,529 JKL in the distribution module is the fee pool (stakers).
- Touch the POL account (88,314 JKL): it is a keyless 32-byte `GetAccount` address with **no send path** in v5.1.x (receive-only destinations: buy-storage/POL cut, post-file POL cut, RNS registration deposit, v4.5.0 upgrade sweep).
- Move provider collateral except via the provider's own shutdown/claim flow; slashing does not exist in `x/storage` (no `MissesToBurn`/slash path in the v5.1.0 code).
- Claim gauge funds: gauge accounts are keyless `sha256("gauge:"+id)` addresses; only `pullTokensFromGauges` (storage module) moves them, and only to providers proportional to proofs (`ManageRewards`). Expired gauges are removed without a sweep → residual is stuck (S).
- Take bonded/unbonded stake: only a validator-adopted software upgrade could rewrite state (P).
- Use governance to migrate the 27 wasm contracts: none is gov-administered (admins are user addresses / the bindings factory).

---

## 6. Verification (live reads + CI evidence; no fork)

Cosmos gov cannot be fork-tested with Foundry, so verification is:
- **Live state at recorded heights** (all endpoints public, listed in `ci/evidence.py`): gov params via `x/params`; CP; module balances (module addresses derived `sha256(name)[:20]`, POL/gauge addresses the full-sha256 `GetAccount` form — both verified against known balances); full wasm census; full storage gauge enumeration; Osmosis full pool scan (2,049 gamm + 1,303 CL) + pool balances.
- **Exact-version source checks** (quoted in §3): SDK v0.45.16/17 `fee_pool.go`, `proposal_handler.go`, `handler.go`, `abci.go`, `tally.go`; canine-chain v5.1.0 `x/storage` msg servers/keepers (collateral, gauges/rewards, proofs); wasmvm v1.2.6 `libwasmvm/Cargo.lock` (Wasmer 2.3.0 + singlepass); CosmWasm advisory CWA-2026-006; canine-chain v5.1.2 `go.mod`.
- **Reproducible CI job:** `ci/run.sh` → `ci/evidence.py` collects everything and recomputes the model on a public runner (no secrets used). Run URLs and results: `summary.json` / below.

CI runs:
- `<CI RUN URL 1>` — first evidence run (full collection + model).

Key CI numbers (final run): see `ci-out/model.md`.

---

## 7. Verdict, residual and latent risk

- **Chain live; finding confirmed as watch-level.** "Minimal DeFi" is accurate: one real pool with $2.8k of counterpart, no CEX market (CoinGecko shows Osmosis only), a $402-realizable community pool, and keyless/locked module balances.
- **E-U: $2,814.56 capability bound** via CWA-2026-006 (wasmvm v1.2.6 + open upload/instantiate). Confidence: applicability **high** (version + artifact + permissions all verified), realized exploitation **low** (trigger not public, no reports). This is the only path that changes the verdict; it needs the unpatched chain to stay unpatched. Recommend: upgrade wasmvm per the advisory (2.2.9+/3.0.8 line) and/or restrict upload/instantiate in the meantime.
- **Capture: $401.79 realizable vs ≥$14,169 nominal cost, acquisition infeasible at depth — not net-extractable.** If the CWA path ever works, capture adds nothing material (same pool).
- **P/S/H-O:** distribution fee pool 7,607,529 JKL (P, upgrade-only); POL 88,314 JKL (S); collateral 80,000 JKL + gauges ~115,157 JKL planned (H-O provider flows). None is attacker-reachable.
- **Residual/latent risk:** (1) if the CWA-2026-006 trigger becomes public and Jackal stays on wasmvm v1.2.6, an attacker can mint-and-dump for ~$2.8k and cause "permanent loss of user funds" far beyond that bound (token dilution); (2) older CWA advisories (unpatched wasmvm/wasmd line) provide permissionless chain-halt vectors — destructive, $0 extraction; (3) any future CP inflow or a revived JKL market would re-arm the (still uneconomic) capture math.

**Blockers:** CWA trigger not public; capture infeasible at depth and negative-EV; module/POL/collateral/gauge funds all have owner/module-only spend paths.

---

## 8. Methodology, caveats, files

- **Method:** public LCD/RPC reads (multi-endpoint failover) at recorded heights; module-account address derivation verified against known balances; full Osmosis pool scan; CoinGecko + DefiLlama prices; exact-version source review; reproducible CI job.
- **Caveats:** (1) JKL/OSMO prices move; all USD at the stated prices; (2) the CWA bound is advisory-based, not a demonstrated extraction; (3) gauge escrow total uses a sampled balance sweep locally (full sweep in CI; the planned-total ceiling is $69.81); (4) OTC acquisition of JKL (for capture) is not measurable from on-chain data; (5) CL-pool extraction mechanics are approximated by pool bank balances (upper bound); (6) all other JKL pools are dust — their micro-amounts were decimal-verified against the chain-registry asset list.

**Files index**
```
jackal/
├── README.md                    # this report
├── summary.json                 # machine-readable summary
├── analysis/
│   ├── model.json / model.md    # computed model (local run, h 20,153,736)
│   ├── out/raw/                 # raw state dumps (local run)
│   └── raw/                     # consolidated raw dumps + prices + pool data
├── ci/
│   ├── run.sh                   # CI entry (public endpoints only)
│   └── evidence.py              # collector + model (also used locally)
├── ci-out/                      # CI results (raw/, model.json, model.md)
├── ci-artifacts/                # downloaded CI artifacts
└── ci-log.txt                   # CI log
```

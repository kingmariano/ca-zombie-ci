# BlueMove (Sui) — Phase-2 · sim-poc child · findings

Scope: build a working `simulateTransaction` harness on the public Sui GraphQL endpoint, prove the
JSON transaction format, build the parameterized attack PTB (V1 swap → escrow-version add →
remove), simulate it against pool `0x32999b…4368` (SUI/PAULY), and record exact results.
Read-only: nothing was signed, sent, or executed. Simulation/dry-run only, public endpoints only.

**TL;DR**
1. The JSON format is cracked and the minimal harness is proven (simulated `coin::zero<SUI>` → **SUCCESS**).
2. The parent's attack recipe **does not run** against `0x32999b…` — each leg aborts deterministically
   (details below). **No profit is reachable on this pool in the current chain state.**
3. Root cause discovered on-chain: the stored `VersionManage.version = 12`, while the two
   escrow-owning packages assert against their own constants **8** (`0x08cd33…`, "vmid") and **11**
   (`0x35f3…`, parent's "v-latest") → both are **version-gated OFF** (`assert_version_contract` abort 25).
   Only the original package `0xb24b…` (no version gate) remains callable, and it only uses the
   pool's own legacy store, which is **empty** for this pool → all V1 ops abort too.
4. Live traffic confirms it: 21 of the last 25 Dex_Info transactions call
   `0xb24b6789…::router::swap_exact_input_` (V1); **zero** calls to vmid/vlatest.
5. Fallback path `sui_devInspectTransactionBlock` **is available** on `https://sui-rpc.publicnode.com`
   (not needed — JSON format worked).

---

## 1. Verified request format (Evidence: `evidence/minimal.*`, `graphql_schema_*.json`)

`simulateTransaction` is a **query** (not a mutation) on `https://graphql.mainnet.sui.io/graphql`:

```graphql
query Sim($tx: JSON!, $checks: Boolean, $gasSelect: Boolean) {
  simulateTransaction(transaction: $tx, checksEnabled: $checks, doGasSelection: $gasSelect) {
    effects { digest status executionError { message identifier abortCode module { name } function { name } } effectsJson }
    outputs { returnValues { value { json bcs type { repr } } } }
  }
}
```

`transaction` is the **proto3 JSON of `sui.rpc.v2.Transaction`** (partial specification allowed).
Working minimal example (`evidence/minimal.tx.json`, response `... SUCCESS`):

```json
{
 "sender": "0x0feb54a7…ebb3",
 "kind": {
  "kind": "PROGRAMMABLE_TRANSACTION",
  "programmableTransaction": {
   "inputs": [],
   "commands": [
    {"moveCall": {"package": "0x000…0002", "module": "coin", "function": "zero",
                  "typeArguments": ["0x000…0002::sui::SUI"], "arguments": []}}
   ]
  }
 }
}
```

Rules proven during the PoC:
* **No `gasPayment` needed with `doGasSelection: true`** (node picks gas for the sender; it substitutes
  a mock gas object — `effectJson.gasObject.objectId = 0xffff…ffff`). `checksEnabled: false` accepted.
* **Pure values must live in `inputs`**, never inline in commands: `{"kind":"PURE","pure":"<base64 BCS>"}`
  (u64 = 8-byte LE; address = 32 bytes). Command args reference them: `{"kind":"INPUT","input":N}`.
* Args: `{"kind":"GAS"}` | `{"kind":"INPUT","input":N}` | `{"kind":"RESULT","result":N}` |
  `{"kind":"RESULT","result":N,"subresult":j}`.
* **Result indexing:** each command that returns values occupies **one result slot** (global counter).
  Multi-return commands (e.g. `router::add_liquidity_returns` → 3 values) are read with `subresult`
  0/1/2 — verified against a real mainnet tx (`evidence/live_v1_usage_tx.json`) and by simulation.
* Shared input: `{"kind":"SHARED","objectId":"0x…","version":"<initialSharedVersion>","mutable":true,"mutability":"MUTABLE"}`
  (Dex_Info initialSharedVersion = **1587827**). Both `mutable` and `mutability` accepted.
* `splitCoins.amounts` is `repeated Argument` — pass input refs, not pures (a pures-based attempt gets
  `unknown variant 'PURE', expected one of 'ARGUMENT_KIND_UNKNOWN','GAS','INPUT','RESULT'`).

Reproduce: `python3 scripts/gql_sim.py evidence/minimal.tx.json minimal`

---

## 2. Parameterized attack PTB & simulation results (pool `0x32999bec…4368`, SUI/PAULY)

Generator: `scripts/build_ptb.py` (all `.tx.json`), runner: `scripts/gql_sim.py`,
summary: `scripts/show_effects.py` → `evidence/simulation_summary.json`.
Every request/response pair is saved verbatim (`evidence/<label>.graphql_request.json` / `.graphql_response.json`).

| # | PTB (commands) | Result | Digest | Error (exact) |
|---|----------------|--------|--------|----------------|
| minimal | `coin::zero<SUI>` | **SUCCESS** | `G8hfY8…jfy` | — (output[0] = Coin<SUI>, balance 0) |
| t1 | V1 `router::swap_exact_input<SUI,PAULY>` (1 MIST) | FAILURE | `CRSpR6…qvSf` | `balance::split` abort **2** — V1 pays out of its own store (empty) |
| t2 | vmid `router::swap_exact_input_<SUI,PAULY>` | FAILURE | `67PVrJ…rFtj` | `0x08cd33…::swap::assert_version_contract` abort **25** |
| t3 | 0x35f3 `router::swap_exact_input_<SUI,PAULY>` | FAILURE | `F8x9ed…y8QS` | `0x35f3…::swap::assert_version_contract` abort **25** |
| t4 | vmid `add_liquidity_returns` (zero PAULY) | FAILURE | `LWSttN…mkS6` | vmid version gate abort **25** (3rd command) |
| t5 | 0x35f3 `add_liquidity_returns` (zero PAULY) | FAILURE | `2Yrknb…XesF` | 0x35f3 version gate abort **25** (3rd command) |
| t6 | **parent recipe**: V1 swap → 0x35f3 add → 0x35f3 remove | FAILURE | `UXvFeN…iHFu` | `InvalidLinkage in command 4` (pre-execution; see §5) |
| t7 | vmid swap_ → vmid add → vmid remove | FAILURE | `4b1Guf…tUkj7` | vmid gate abort **25** (2nd command) |
| t7b | 0x35f3 swap_ → 0x35f3 add → 0x35f3 remove | FAILURE | `me7rej…rkoaaEX` | 0x35f3 gate abort **25** (2nd command) |

No balance/object effects beyond gas are produced by any failing tx (status FAILURE ⇒ atomic rollback).
The attack PTB therefore **does not simulate through to a state change on this pool** — not because of
the format/harness, but because of the on-chain state (§3).

---

## 3. Why it fails — verified on-chain state (Evidence: `state_snapshot.json`, `versionmanage_object.json`)

Version gate (`assert_version_contract` reads a dynamic object field on Dex_Info keyed by Dex_Info's
own ID, compares against the calling package's compile-time constant — vmid/vlatest disasm, verified live):

| Package | Role | `utils::get_contract_version()` (live) | Gate result |
|---|---|---|---|
| `0xb24b6789…5454d9` | V1 (Pool/Dex_Info/LSP, legacy store) | **no gate** | callable |
| `0x08cd3348…24498f` | vmid (defines `EscownCoins`, this pool's escrow type) | **8** | **ABORT 25** |
| `0x35f3190a…f656d7` | parent's "v-latest" (defines `EscrowCoinsV2`) | **11** | **ABORT 25** |

Stored marker: `VersionManage` object `0x41d5f1c1…b5b2d` (dynamic object field on Dex_Info),
type `0x08cd33…::swap::VersionManage`, `version = 12`, last written by a transaction calling
`0x35f3190a…::swap::migrate_contract_version` (digest `EanzxUeS…PvDS`, sender `0x049cc391…ffefa1` = Dex_Info.dev).
So the deployer's own migration **disabled both escrow-owning packages** (12 ≠ 8, 12 ≠ 11).
Unless a package compiled with constant 12 exists outside this review's scope, **escrow coins
currently cannot be moved by any known package**.

Pool `0x32999b…4368` snapshot (all live, block-tip):

- Pool type `0xb24b…::swap::Pool<0x2::sui::SUI, 0xe71317…::pauly::PAULY>`; dynamic-field key
  `"BlueMove-000…002::sui::SUI-e71317…::pauly::PAULY-LP"`; version 683015983, digest `3TzQ7h…RFHq`.
- V1 store (`token_x`/`token_y` balances): **0 / 0** ⇒ V1 functions cannot pay anything out
  (`swap` → `balance::split` abort 2; `add` → u128 subtraction underflow (`balance − reserve`);
  `remove` → abort 10 on zero payout). Verified for swap: t1.
- Escrow (derived object `0xd198fb63…f522a8`, type `0x08cd33…::swap::EscownCoins<SUI,PAULY>`):
  48,514,964 MIST + 7,057,080,047,242 PAULY units. `reserve_x/reserve_y` equal these values
  (last writer = vmid-era), `lsp_supply = 18,326,236,966`. **Currently unreachable** through
  callable code (vmid gated off; V1 never touches the escrow).
- Dex_Info `0x3f2d9f…6e92`, version 1044635716, `initialSharedVersion 1587827`.

Live usage corroboration (“is anything actually working today?”): of the last 25 transactions touching
Dex_Info, **21 call `0xb24b…::router::swap_exact_input_`** (integrated by third-party bots such as
`0xd5a9689f…::t`, `0x474aca8c…::m`, `0xdae8a7db…::m`); 12/25 succeed, 13/25 revert.
The most recent Dex_Info-mutating tx (`DWNAwM43…`) itself failed with the same
`balance::split` abort 2 seen in t1. No vmid/vlatest calls in the window.

---

## 4. Mechanism of the July-2026 class (from disassembly; for the record)

`Pool<T0,T1>` (defined once in `0xb24b`, shared by all versions) carries BOTH representations:
`token_x/token_y: Balance<T>` (legacy V1 store) **and** `reserve_x/reserve_y: u64` (shared bookkeeping).

* **V1 mint** (`add_liquidity`): `delta = token_balance − reserve_x` (u128; underflow abort if
  `token_balance < reserve`), `lp = min(delta_x·S/reserve_x, delta_y·S/reserve_y)`, then
  `reserve_* := token_balance_*`.
* **vmid/vlatest mint**: same formula but `delta = escrow_balance − reserve_x`, then
  `reserve_* := escrow_balance_*` (escrow = `EscownCoins` / `EscrowCoinsV2` dynamic object field of the pool).
* **vmid/vlatest burn** (`remove_liquidity`): payout `= reserve_* · lp / S` — but **paid out of the escrow**.
* **V1 burn**: payout `= token_balance_* · lp / S` — paid out of the V1 store.
* **V1 swap**: quotes with `reserve_x/reserve_y` (`get_amount_out` asserts `amount_in>0` and both
  reserves > 0; 0.2% fee = 9980/10000) but pays out of `token_balances`; afterwards `reserve_* := token_balance_*`.

⇒ The exploit family = write a *small* reserve with one version while a *large* balance sits in the
other store, then mint LP against the small denominator and burn against the big store.
**Exploitability prereqs:** (a) the escrow-owning package must be gate-enabled (it is not, today), and
(b) there must exist state with `reserve < balance_of_the_paying_store` (this pool: no; reserve==escrow
and V1 store empty). Independent sampling (parent's `escrow_sample.json`, n=600) currently flags
**0 drainable pools** (v1 or v2), and the live bot traffic is ~50% reverting — consistent with the
exploit window being closed by the version bump rather than with ongoing extraction.

## 5. Notes / open items

* **`InvalidLinkage in command 4` (t6)** — the composed PTB (V1 call + 0x35f3 call + `LSP` type args)
  fails in pre-execution linkage resolution, while each leg run separately reaches the runtime aborts
  above. Root cause not fully diagnosed (may be resolver behavior for mixed upgraded-package sets in
  simulation). It does not change the conclusion: t5/t7b already prove the escrow-version gate abort.
* **Where is the version-12 package?** The migration wrote 12 via `0x35f3::migrate_contract_version`.
  If a constant-12 package exists, it is the only one that could currently move escrow coins
  (and vmid-only pools like the test pool would need it to unfreeze). Worth a follow-up if not
  already known to the parent.
* **Escrow funds may be frozen** on legacy (`EscownCoins`) pools: with vmid gate-off and V1 unable to
  touch escrows, `EscownCoins` balances are only movable by a constant-12 package. Sample top pool
  `0x127bd40c…` holds ≈$18.4k in a `EscrowCoinsV2` escrow in this state.
* Fallback (not needed): `sui_devInspectTransactionBlock` exists on `https://sui-rpc.publicnode.com`
  (returns a typed param error, i.e. method present; requires 32-byte sender + BCS `txBytes` base64).
  A BCS encoder was therefore not built.
* Simulation caveats: `checksEnabled:false` + `doGasSelection:true` (mock gas object `0xffff…`);
  no signatures are checked; successful simulation ≠ mainnet execution feasibility, but abort codes
  and object/balance deltas are deterministic for valid PTBs.

## 6. Reproduction

```bash
cd analysis/children/sim-poc
python3 scripts/gql_sim.py evidence/minimal.tx.json minimal          # harness proof (SUCCESS)
python3 scripts/build_ptb.py                                         # rebuild T1–T7b tx JSON
python3 scripts/gql_sim.py evidence/t5_vlatest_add_zero_pauly.tx.json t5_check   # gate abort 25
python3 scripts/show_effects.py                                      # table + simulation_summary.json
python3 scripts/state_snapshot.py                                    # refresh state_snapshot.json
```

## 7. File inventory

* `scripts/` — `gql_sim.py` (GraphQL sim runner), `build_ptb.py` (parameterized PTB generator),
  `show_effects.py` (response summarizer), `state_snapshot.py` (live-state capture).
* `evidence/` — `minimal.*` (format proof), `t1…t7b.*` (per-leg + full recipe: tx JSON, exact
  request, exact response), `simulation_summary.json`, `state_snapshot.json`, `pool_state.json`,
  `function_signatures.json` (live router signatures incl. vmid/0x35f3), `versionmanage_object.json`
  (version=12 + writer tx), `live_v1_usage_tx.json` (real on-chain result-indexing reference),
  `dex_info_dynamic_fields.json` (pool-name/key convention), `graphql_schema_*.json`,
  `graphql_simulation_result_schema.json`.

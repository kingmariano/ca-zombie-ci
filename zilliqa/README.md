# C2-58 — Zilliqa legacy staking / Z2 deposit — deep-dive (zombie-hunt II)

**Date:** 2026-10-10 · **Chains:** Zilliqa 2 (EVM, chainId 32769) carrying the migrated
Zilliqa 1 legacy (Scilla) state · **Status:** read-only; every claim verified live via
keyless RPC `https://api.zilliqa.com`; **no transactions signed or sent**; CI re-verified
([run 38024793214](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38024793214), 21/21 checks).

**Finding under test (C2-58):** “Zilliqa legacy staking / Z2 deposit — $4.91M / $12.64M —
core contracts, admin/multisig-gated (no path).”
**Mission:** verify rigorously whether any external unprivileged extraction exists, and quantify.

---

## 1. TL;DR

| Target | Live value (CI block 37,772,814 / 2026-10-10) | Unprivileged extractable? | Why closed | Latent risk |
|---|---|---|---|---|
| **Legacy SSNList staking** (Scilla impl `0xa7c67d49…`, proxy `0x62a9d5d6…`) | **1,388,481,925.05 ZIL ≈ $4.88M** | **No — $0** | All legacy Scilla txns are dead since 2026-07-20 (block 31,759,109) and rerouted to the escrow since 2026-09-22; the only EVM route (`scilla_call` precompile) is caller-allowlisted to 100 contracts since 2026-06-16. Every one of the 56 deployed transitions is `IsProxy`-gated (the impl can only be driven by its Scilla proxy) plus caller-scoped/admin/verifier gated | Funds **frozen (S)** pending Zilliqa’s recovery framework; admin = 2-of-5 multisig (P, unreachable today); verifier can only distribute funds it attaches itself (bounded by `AssertCorrectRewards`) |
| **Legacy admin multisig** (`0x38c986f6…`, 2-of-5) | **5,533.69 ZIL ≈ $19.43** | No — $0 | Scilla contract; unreachable like all Scilla today | **P** (inert) |
| **Z2 staking deposit v9** (proxy `0x…5a494c4445504f53495450524f5859`) | **3,575,198,943.17 ZIL ≈ $12.55M** | **No — $0** | Staker-scoped: `unstake`/`withdraw`/`depositTopup`/`setRewardAddress` require `msg.sender == controlAddress` (verified revert `Unauthorised` `0xd7a2ae6a`); upgrade is system-only (`msg.sender == address(0)`); `reinitialize` armed (verified revert `InvalidInitialization` `0xf92ee8a9`); proxy has no admin function, admin slot = 0 | **H-O**: 24 stakers can self-service unstake + withdraw after 461,680 blocks (~5.3 days) |
| **Escrow / ZK claim vault** (`0x…5a494c31455343524f5750524f5859`) | **2,568,681.35 ZIL ≈ $9.0k** | **No — $0** | `lodge()` only accepts funds; `claim()` requires a Groth16 proof bound to (old_address, new_address, chain_id); garbage proof reverts | **H-O** for lodge depositors (recovery path, live since 2026-09-22) |

**Total live value in the C2-58 cluster: 4,966,255,083.26 ZIL ≈ $17.44M** (at ZIL = $0.0035113,
DefiLlama, CI run). **External unprivileged extractable now: $0.00 — high confidence.**
Split: **H-O $12,562,782.31 · S $4,875,441.33 · P $19.43 · E-U $0.00.**

---

## 2. The mechanism in exact terms

C2-58 is a **custody/freeze** finding, not a bug: two core staking systems hold ~5.0B ZIL,
and the question is whether their gating can be bypassed.

1. **Legacy staking (ZIP-11/ZIP-19 Scilla, migrated to Z2 at genesis).** The SSNList
   implementation holds all stake (1.388B ZIL). The **deployed** code (extracted from chain,
   65,230 bytes of Scilla source — a newer revision than the GitHub master) was audited
   transition-by-transition: **all 56 transitions are `IsProxy`-gated** (47 call `IsProxy`
   directly; the 9 `Migrate*` transitions call `ValidateMigration`, which expands to
   `IsPaused; IsProxy; IsAdmin`). Value outflows are caller-scoped (`initiator` is set by
   the proxy to `_sender`) or admin/verifier gated; `DrainContractBalance` additionally
   requires `paused == true`; the verifier’s `AssignStakeReward` can only distribute the
   ZIL it attaches to the call (`AssertCorrectRewards`).
2. **Z2 deposit v9 (EVM core contract).** Stakes are per-BLS-key with a `controlAddress`;
   only the control address may `unstake`, `withdraw`, top-up, or re-point addresses.
   The proxy is a pure delegatecall shell (no admin entrypoint); upgrades are applied by
   the protocol via a system call (`_authorizeUpgrade` requires `msg.sender == address(0)`).
3. **Reachability kill-switches (the decisive gates).** The Z2 mainnet fork schedule
   (verified live) closed every route to the legacy Scilla code:
   * `disable_zilliqa_txn_execution = true` at block **31,759,109 (2026-07-20 16:37 UTC)** —
     all legacy Scilla transactions rejected;
   * `zil_transfers_only_to_escrow = true` at block **36,383,379 (2026-09-22)** — legacy
     txns are rerouted to the escrow contract as plain transfers/LODGE; they can never
     invoke a Scilla transition;
   * `allow_scilla_call_precompile_to_be_called_from_addresses` (100 contracts) at block
     **29,108,584 (2026-06-16)** — the only EVM→Scilla route (`scilla_call` precompile
     `0x…5a494c53`) rejects any caller not on the list and fails the whole transaction;
   * `disable_permanently_scilla_precompiles` is scheduled only at block 99,999,999 (~2028).

Deployed-code verification: the deposit impl code (22,972 bytes) is **byte-identical to
`zq2/zilliqa/src/contracts/deposit_v9.sol`** except the 3 immutable slots; the SSNList
gating was audited from the **on-chain Scilla source** (`analysis/onchain_ssnlist_scilla.txt`,
`analysis/DEPLOYED-CODE-AUDIT.md`), plus live state (`contractadmin`, `paused=false`, 2-of-5
owners).

---

## 3. Live-state assessment (all reads CI block 37,772,814 / local 37,770,483–37,774,656)

| Contract | Address | Code | Balance | Roles / state |
|---|---|---|---|---|
| SSNListProxy (ZIP-19) | `0x62a9d5d611cdcae8d78005f31635898330e06b93` (zil1v25at4s3eh9w34uqqhe3vdvfsvcwq6un3fupc2) | Scilla | 0 ZIL | admin = multisig, impl = `0xa7c67d49…` |
| SSNList impl (ZIP-19) | `0xa7c67d49c82c7dc1b73d231640b2e4d0661d37c1` (zil15lr86jwg937urdeayvtypvhy6pnp6d7p8n5z09) | Scilla | **1,388,481,925.046 ZIL** | contractadmin = `0x38c986f6…`; verifier = `0x412b55a0…`; paused = **false**; minstake = 10M ZIL |
| Admin multisig | `0x38c986f6252a32b1c0fa732784c1a94e9f42a394` | Scilla | **5,533.69 ZIL** | **2-of-5** (owners in CONTRACT-MAP; created block 6,744,947) |
| Verifier | `0x412b55a0ebc1001f930aba8dc107022a3a2ba484` | EOA (no code) | — | can only `AssignStakeReward` (funds it attaches itself) |
| Z2 deposit proxy | `0x00000000005a494c4445504f53495450524f5859` | EVM minimal proxy | **3,575,198,943.17 ZIL** | impl slot = `0x05dff05a…`; admin slot = 0 |
| Z2 deposit impl v9 | `0x05dff05a33aca5d190f8f78a47aebaa002f55d31` | EVM | (stake at proxy) | version=9; 24 stakers; total stake 3,568,928,130.68 ZIL; withdrawal period 461,680 blocks |
| Escrow proxy | `0x00000000005a494c31455343524f5750524f5859` | EVM minimal proxy | **2,568,681.35 ZIL** | impl = `0x3a1af903…`; admin slot = 0 |
| `scilla_call` precompile | `0x000000000000000000000000000000005a494c53` | precompile | — | caller allowlist (100 contracts) active |

A child enumeration (`analysis/enumeration/REPORT.md`) closed the address set from four
independent directions (launch blogs, developer docs, explorer labels, on-chain
cross-references): **no hidden value holder exists** in the legacy staking cluster beyond
the two headline holders + the 5,533.69 ZIL admin multisig; phase-0/1.0 proxies, impls and
deployer wallets, gZIL (fully minted-out, zero ZIL) all hold 0.

Details, raw outputs and reproduction commands: `analysis/CONTRACT-MAP.md`,
`analysis/GATE-EVIDENCE.md`, `analysis/DEPLOYED-CODE-AUDIT.md`, `analysis/FORK-SCHEDULE.md`,
`analysis/BLOCKED-RECIPIENTS-SCAN.md`, `analysis/evidence_latest.json`.

---

## 4. What an attacker can and cannot do

**Cannot (all verified by `eth_call` simulation, no tx sent):**
* Call any Scilla transition directly (legacy txns rejected/rerouted; precompile
  allowlist rejects random callers — random → `AddFunds` **reverts**, allow-listed →
  **succeeds `0x`**).
* Call the SSNList **implementation** with a forged `initiator = admin` even from an
  allow-listed caller: `IsProxy` fails (`_sender` can never be the Scilla proxy from an
  EVM frame).
* Call the SSNList **proxy** as a non-admin: `IsAdmin` fails (`initiator` = the EVM
  caller); delegator transitions only touch the caller’s own entry.
* Withdraw/drain the Z2 deposit: `withdraw(real 48-byte BLS key)`, `unstake(real key, 1)`,
  `depositTopup(real key)`, `setRewardAddress(real key, x)` from a random caller all
  revert `Unauthorised()` (`0xd7a2ae6a`).
* Re-initialize or upgrade the deposit: `reinitialize()` reverts `InvalidInitialization()`
  (`0xf92ee8a9`); `_authorizeUpgrade` requires the system caller; the proxy has no admin
  function and its admin slot is zero.
* Claim escrowed funds: `claim()` requires a valid Groth16 proof; garbage proof reverts.

**Could only be done by privileged actors (P, and currently unreachable):**
* The **2-of-5 multisig** could call `DrainContractBalance` on the SSNList (its intended
  emergency path, and only while the contract is paused) — but it cannot be invoked at all
  today (legacy txns dead, not on the precompile allowlist).
* The **verifier EOA** (`0x412b55a0…`) can call `AssignStakeReward` only to distribute
  funds **it attaches to the call** (`AssertCorrectRewards` caps SSN rewards at the
  attached amount); it cannot mint from staker principal. Inert today.

**Allowlist-bypass check (child report `analysis/allowlist/REPORT.md`):** NO bypass, high
confidence. All 24 allow-listed contracts that embed the precompile constant are
fixed-target ZRC-2→ERC-20 facades (target fixed in storage/immutables, compile-time
constant transitions); the other 76 cannot reach the precompile; no generic forwarder
exists. Even allow-listed callers cannot move SSNList value (`IsProxy` reverts).

**Cost to attempt:** the closed paths revert before any value moves; there is no net-profit
path to report (gas spent on reverts only).

---

## 5. Verification / CI

* **Collector:** `analysis/scripts/collect_evidence.py` — **21/21 assertions PASS in CI**
  (run 2), writing `ci-out/zilliqa_evidence.json` + `ci-out/zilliqa_summary.txt`.
  * CI runs: [38024023094](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38024023094)
    (initial, 19/19) and [38024793214](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38024793214)
    (final, 21/21, head block 37,773,538, ZIL $0.0035113).
  * Local reproduction: `python3 analysis/scripts/collect_evidence.py out.json`.
* **Deployed-code audit:** `python3 analysis/scripts/audit_deployed_ssnlist.py` regenerates
  the 56-transition guard table from live `eth_getCode` (output:
  `analysis/deployed_ssnlist_guards.txt`).
* **Bytecode diff:** `analysis/onchain_impl.hex` vs `analysis/artifact_v9_deposit.hex`
  (60 differing bytes = the 3 immutable slots only).
* **Why no Foundry fork PoC:** Z2 implements custom precompiles (`scilla_call`) that
  standard revm/anvil does not, and the critical gates are consensus/fork-level (legacy
  txn routing) — a local EVM fork would not faithfully reproduce them. The live `eth_call`
  battery is the strongest available simulation and is re-run in CI.
* Child verifications (independent): `analysis/allowlist/REPORT.md` (allowlist-bypass
  deep-dive) and `analysis/enumeration/REPORT.md` (staking-contract enumeration).

---

## 6. Verdict and residual / latent risk

* **Verdict: E-U $0.00 (high confidence).** The report’s “admin/multisig-gated (no path)”
  classification is correct for attackers. Refinement: the legacy staking is **S (frozen)**
  today — not even holders can move it — the Z2 deposit ($12.55M) and escrow ($9k) are
  **H-O** (holder self-service / proof-gated), and the multisig dust is **P** ($19.43).
* **Latent risks (monitor):**
  1. If `disable_zilliqa_txn_execution` / `zil_transfers_only_to_escrow` were ever
     reverted *before* the migration completes, legacy staking becomes live again with the
     same (sound) gating — H-O for stakers, P for the 2-of-5 multisig. An attacker still
     gains nothing without a code bug.
  2. If the precompile allowlist were expanded to include a generic forwarder contract that
     an attacker can drive, arbitrary Scilla calls become possible *as the attacker*
     (call-mode 1 resolves to the original signer). Even then, SSNList extraction remains
     blocked by `IsProxy` + admin/caller scoping (child-verified; allowlist report).
  3. Multisig owner keys and the verifier key are the only privileged risks; both are inert
     because Scilla execution is unreachable.
  4. The recovery framework (escrow + ZK proofs) is the intended route for staked funds;
     until it covers staking positions, the 1.388B ZIL remains stuck (S).
* **Blockers encountered:** none material; the chain, contracts and state are fully
  reachable via the public RPC. `debug_traceCall` is disabled on the public endpoint
  (revert reasons obtained via revert data / call semantics instead).

---

## 7. Methodology & sources

* Live reads via keyless `https://api.zilliqa.com` (Z2, `zilliqa2/v0.21.10`): `eth_call`,
  `eth_getBalance`, `eth_getStorageAt`, `eth_getCode`, `eth_getBlockByNumber`; legacy
  methods `GetBalance`, `GetSmartContractSubState`, `GetSmartContractInit`; Scilla
  state-read precompile `0x…5a494c92`.
* Sources: `Zilliqa/zq2` (main): `z2/resources/chain-specs/zq2-mainnet.toml`,
  `zilliqa/src/exec.rs`, `zilliqa/src/precompiles/scilla.rs`, `zilliqa/src/blocked_recipients.rs`,
  `zilliqa/src/contracts/deposit_v9.sol`, `zilliqa/src/contracts/escrow/{escrow_v1,verifier}.sol`;
  deployed SSNList Scilla source (on-chain, `analysis/onchain_ssnlist_scilla.txt`);
  `Zilliqa/staking-contract` (lineage); Zilliqa Ledger-incident post-mortem (2026-08-20);
  DefiLlama prices.
* Caveats: balances are point-in-time (staking deposit flows daily); USD uses ZIL
  $0.0035113 (CI) / $0.0035066 (local run). The finding’s $4.91M/$12.64M match our
  $4.88M/$12.55M at today’s price. All corpus numbers were re-derived from chain state,
  not copied.

## 8. Files index

```
zilliqa/
├── README.md                          ← this report
├── summary.json                       ← machine-readable summary
├── analysis/
│   ├── CONTRACT-MAP.md                ← addresses, roles, balances, gating
│   ├── GATE-EVIDENCE.md               ← raw gate-test outputs + source snippets
│   ├── DEPLOYED-CODE-AUDIT.md         ← deployed SSNList transition/guard audit (56/56 IsProxy)
│   ├── deployed_ssnlist_guards.txt    ← regenerated guard table (block-stamped)
│   ├── onchain_ssnlist_scilla.txt     ← deployed SSNList Scilla source (eth_getCode, ground truth)
│   ├── FORK-SCHEDULE.md               ← fork heights/timestamps and effects
│   ├── BLOCKED-RECIPIENTS-SCAN.md     ← sweep-list scan (staking contracts absent)
│   ├── evidence_latest.json           ← latest collector output (21/21 PASS)
│   ├── evidence_20261010T042014Z.json ← first local run
│   ├── deposit_v9.sol / ssnlist.scilla / proxy.scilla / multisig_wallet.scilla
│   ├── onchain_impl.hex / artifact_v9_deposit.hex / dep_proxy_code.txt
│   ├── zq2-mainnet.toml / multisig_state.json
│   ├── allowlist/                     ← child verification: allowlist bypass deep-dive (REPORT.md)
│   ├── enumeration/                   ← child verification: staking-contract enumeration (REPORT.md)
│   └── scripts/                       ← collect_evidence.py, audit_deployed_ssnlist.py, zil_bech32.py
├── ci/run.sh                          ← CI job (collector + summary)
├── ci-out/                            ← CI artifacts (evidence JSON + summary)
├── ci-log.txt / ci-artifacts/         ← fetched CI logs/artifacts
└── poc/                               ← empty (see §5: no faithful local fork for Z2)
```

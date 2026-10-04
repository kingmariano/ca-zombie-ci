# H-35 Dossier — GnosisSafeProxy `0xdd7c49D1bA862b1285710A30E20C2438b13AE532`

- **Chain:** Metis Andromeda (chain id 1088), RPC `https://andromeda.metis.io/?owner=1088`
- **Finding:** H-35 (zombie-hunt campaign, Metis chain — "metis-orphans" deep-dive)
- **Snapshot blocks:** 23238718, 23238798, 23238812 (all reads pinned; 2026-10-04)
- **Method:** read-only `eth_call`/`eth_getStorageAt`/`eth_getCode` via `cast` at explicit blocks; Blockscout v2/v1 APIs (blockscout andromeda-explorer); safe-deployments repo; firecrawl/web research. No transactions were sent; nothing was signed.
- **Evidence:** `safe_state.json`, `owners.json`, `txs.json`, `owners_research.md`, `raw/` (see §11)

---

## 0. Verdict (TL;DR)

**There is no unprivileged extraction vector. E-U = 0 METIS ($0).**
The 1,847,552.364 METIS held by the Safe is **owner-gated by a 4-of-6 EOA multisig** (GnosisSafeL2 v1.3.0, official Safe "eip155" deployment, no modules, no guard, canonical fallback handler), and every one of the 17 historical Safe transactions was authorized by signatures matching the then-current threshold.

- **Classification: E-U $0 / 0 METIS — confidence HIGH.**
- Remainder is **H-O** (held by owners; privileged-only access): **1,847,552.364 METIS ≈ $18,475,523.64 at METIS ≈ $10** — confidence MEDIUM-HIGH (value and gating are certain; the "Metis EDF" org label is inferred from strong circumstantial evidence).
- Not classified as **P** (no partial/pending path) or **S** (not stuck/locked — owners can move it; indeed they move funds periodically).
- Org identification: **Metis Foundation / MetisDAO — Metis Ecosystem Development Fund (Metis EDF), sequencer-mining allocation wallet** (3,000,000 METIS endowment received 2023-12-20).

---

## 1. Verified live state (all values re-read on-chain)

| Field | Value | How read / block |
|---|---|---|
| `masterCopy` (storage slot 0) | `0xfb1bffC9d739B8D520DaF37dF666da4C687191EA` | `eth_getStorageAt` slot 0 @ 23238718, 23238798, 23238812 |
| `VERSION()` | `1.3.0` | `eth_call` via proxy and singleton @ 23238718 |
| `getThreshold()` | **4** | `eth_call` @ all three blocks; storage slot 4 = `0x…04` |
| `getOwners()` | 6 owners (table §5) | `eth_call` + owners mapping linked-list walk + slot 3 = 6 |
| `nonce()` | **17** | `eth_call`; storage slot 5 = `0x11` (17) |
| `getModulesPaginated(0x1,100)` | `[]` (no modules) | `eth_call` via proxy @ 23238718 |
| guard (`keccak256("guard_manager.guard.address")`) | `0x0` (none) | `eth_getStorageAt` @ all three blocks |
| fallback handler (`keccak256("fallback_manager.handler.address")`) | `0x017062a1dE2FE6b99BE3d9d37841FeD19F573804` | `eth_getStorageAt` @ all three blocks |
| METIS balance | **1,847,552.364 METIS** = `1847552364000000000000000` wei | `eth_getBalance` @ 23238812 |
| Safe proxy code | 171 bytes, codehash `0xb89c1b3bdf2cf8827818646bce9a8f6e372885f8c55e5c07acbd307cb133b000` | `eth_getCode` @ 23238718 |
| Singleton code | 23,800 bytes, codehash `0x21842597390c4c6e3c1239e434a682b054bd9548eee5e9b1d6a4482731023c0f` | `eth_getCode` @ 23238718 |
| `domainSeparator()` | `0x296fe1df5ffeefed62159417a4f51b329759f9aabcf38d58d81348e2c5c1eaa7` | `eth_call` @ 23238718 |
| Owner code (all 6) | `0x` (no code, no EIP-7702 delegation) | `eth_getCode` @ latest ≥ 23238812 and @ 23238718 |

Historical check: the previously established WIP values (threshold 4, nonce 17, 6 owners, empty modules, fallback handler `0x017062…`, balance 1,847,552.364) were all reproduced exactly at explicit blocks. One WIP nuance corrected below (§4, `threshold()`/`getGuard()` are simply not external functions in this build).

---

## 2. Contract identity & integrity (exact)

- **Proxy:** standard 171-byte `GnosisSafeProxy` (v1.3.0). Singleton fixed in storage slot 0 at construction; no upgrade function exists in v1.3.0 proxies.
- **Singleton = GnosisSafeL2 v1.3.0 — the official Safe deployments "eip155" variant.**
  - Explorer-verified source: `GnosisSafeL2`, Solidity `v0.7.6+commit.7338295f`, optimizer **off**, verified 2022-01-08.
  - On-chain codehash `0x21842597390c4c6e3c1239e434a682b054bd9548eee5e9b1d6a4482731023c0f` **exactly equals** the codeHash listed in `safe-deployments/src/assets/v1.3.0/gnosis_safe_l2.json` for both the `canonical` address `0x3E5c63644E683549055b9Be8653de26E0B4CD36E` and the `eip155` address `0xfb1bffC9d739B8D520DaF37dF666da4C687191EA` (ours). So ours is **byte-identical to canonical SafeL2 v1.3.0** — a name-brand deployment, not a fork.
  - Confirmed runtime L2 behavior: `SafeMultiSigTransaction` / `SafeModuleTransaction` events (L2-only events, 17 emitted).
- **Fallback handler = official safe-deployments v1.3.0 `CompatibilityFallbackHandler`, eip155 address `0x017062a1dE2FE6b99BE3d9d37841FeD19F573804`.**
  - On-chain codehash `0x03e69f7ce809e81687c69b19a7d7cca45b6d551ffdec73d9bb87178476de1abf` **matches the official codeHash** exactly.
- **Proxy factory = official eip155 `GnosisSafeProxyFactory` `0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC`** (codehash matches official `0x337d7f54…`).
- **Source-vs-upstream diff:** all 17 extracted verified source files diff against `safe-global/safe-contracts` tag `v1.3.0` with **only a trailing-newline difference** (0 changed lines of code). Stronger still: both deployed contracts' on-chain codehashes **equal the official safe-deployments codeHashes** (§2 above), which pins the exact canonical bytecode. No backdoors/modifications.
- All three Metis deployments were created by `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` (the canonical Safe **singleton factory**, deterministic deployments) — see creation txs in `raw/singleton_explorer.json`, `raw/handler_explorer.json`, `raw/creator_info.json`.

**Conclusion:** the code holding 1.85M METIS is genuine, unmodified Safe v1.3.0. No custom/unofficial code risk.

---

## 3. Modules / guard / fallback-handler analysis

- **Modules: none, and none ever.** `getModulesPaginated` via the proxy returns `[]`; module mapping slot 1 is empty; there are **zero `EnabledModule`/`DisabledModule` events in the wallet's entire history**, and zero `SafeModuleTransaction` events. `execTransactionFromModule` therefore reverts as unauthorized for every address.
- **Guard: none, and none ever.** Guard storage slot is zero; `setGuard(address)` is protected by the `authorized` modifier (`require(msg.sender == address(this))`), i.e. only reachable via owner-approved `execTransaction`; there are zero `ChangedGuard` events.
  - Quirk: this v1.3.0 build's `GuardManager.getGuard()` is **internal** (confirmed in verified source line 43 and singleton bytecode: no external `0xc9106389` selector). The earlier WIP claim "getGuard() reverted via the proxy" is fully explained: the selector does not exist externally, so the call is forwarded to the fallback handler, which doesn't implement it either, and reverts empty. There is no guard, and none can exist unnoticed.
- **Fallback handler:** the canonical CFH. Mechanics in v1.3.0: the Safe's `fallback()` **CALLs** the handler (not delegatecall) and appends the original caller address to the calldata; inside the handler `msg.sender` is therefore the Safe. Exposed functionality:
  - EIP-1271 `isValidSignature(bytes,bytes)` and `isValidSignature(bytes32,bytes)` — view-only; both paths require owner signatures (`checkSignatures` on the Safe) or `signedMessages` (settable only through owner-approved `SignMessageLib` delegatecall; none ever happened — see §7). Cannot move funds.
  - Token callbacks `onERC1155Received` / `onERC1155BatchReceived` / `onERC721Received` / `tokensReceived` — pure selector returns / no-ops; cannot move funds. (One inbound spam-NFT transfer in 2024 called the callback; no value moved.)
  - `getModules()` — pass-through to `Safe.getModulesPaginated()` (reads the Safe's modules → `[]`).
  - `simulate(address,bytes)` — calls `Safe.simulateAndRevert(...)`, which **always reverts** (source-verified assembly `revert`), so any code execution in Safe context via this path is state-discarding. No state change is possible.
  - `supportsInterface`, `getMessageHash`, `getMessageHashForSafe`, `NAME`/`VERSION` — views.
  - **Verdict: the handler cannot move funds, cannot change state, and cannot upgrade anything.** Even if replaced (owner-gated), it runs as a separate contract (CALL semantics), not in the Safe's storage context.

---

## 4. Attack-vector analysis (exhaustive, with verdicts)

Legend: ❌ = impossible/unprivileged path closed; ✅ = would work but requires owner keys (privileged); ⚠ = noted, non-extracting.

| # | Vector | Verdict | Basis |
|---|--------|---------|-------|
| 1 | `execTransaction` with forged/insufficient signatures | ❌ **NO** | v1.3.0 `checkSignatures` requires exactly `threshold` (4) signatures from distinct owners, strictly ascending (`GS026`), all ECDSA (EOA owners), unless v==1 pre-approved hashes or EIP-1271 contract sigs exist. All 17 historical execs carried exactly 2/2, 3/3, or 4/4 signatures. No `ExecutionFailure` ever. Attacker cannot produce 4 owner ECDSA signatures. |
| 2 | `approveHash` abuse | ❌ **NO** | `approveHash(bytes32)` sets `approvedHashes[msg.sender][hash]` — earlier WIP note confirmed: only the calling owner can approve. **Zero `ApproveHash` events in history** → no pre-approved hashes exist at all. |
| 3 | `signMessage` permissionless marking (`signedMessages`) | ❌ **NO** | v1.3.0 removed `signMessage` from the singleton (it lives in `SignMessageLib`; selector `0x85a5affe` absent from singleton bytecode; `sign_message_lib.json` exists in safe-deployments v1.3.0). `signedMessages` is only set by an owner-approved `execTransaction` delegatecall to `SignMessageLib` (or a module). No `SignMsg` events and no delegatecall ops ever → mapping pristine. |
| 4 | EIP-1271 `isValidSignature` misuse | ❌ **NO** | View-only; still requires owner signatures or a signed message; even success only returns `0x1626ba7e`. Cannot transfer METIS or approve hashes. |
| 5 | `execTransactionFromModule` | ❌ **NO** | No modules ever enabled (events, mapping, paginated getter) → `isModuleEnabled(attacker) == false` for every address; the function reverts. |
| 6 | `enableModule` / `disableModule` externally | ❌ **NO** | `authorized` = `msg.sender == address(this)`; only reachable via an owner-approved self-call. |
| 7 | `setGuard` / guard-based interference | ❌ **NO** | Same `authorized`; guard slot zero; zero events. |
| 8 | `setFallbackHandler` swap → malicious handler | ❌ **NO** | `FallbackManager.setFallbackHandler` is `authorized`; zero `ChangedFallbackHandler` events; current handler is the canonical one. |
| 9 | Proxy upgrade / `masterCopy` swap | ❌ **NO** | v1.3.0 `GnosisSafeProxy` stores singleton in slot 0, set at construction; no upgrade/admin function; slot 0 verified = official SafeL2 eip155. |
| 10 | `delegatecall` operation via `execTransaction` | ❌ **NO** | Only reachable with 4 owner signatures; all 17 historical execs used `operation = 0` (call), never 1 (delegatecall). |
| 11 | `simulateAndRevert` state manipulation | ❌ **NO** | Source-verified: always `revert`s after the delegatecall, discarding all state. Any caller, zero effect. |
| 12 | `handlePayment` / attacker-chosen gas params to siphon funds | ❌ **NO** | `handlePayment` runs only *inside* `execTransaction` after signature validation; `gasPrice`/`gasToken`/`refundReceiver` are covered by the signed tx hash. An attacker cannot trigger a payment without 4 valid signatures. |
| 13 | Nonce replay / cross-chain replay | ❌ **NO** | EIP-712 domain separator binds chainId (1088) + verifying contract; nonce is monotonic and part of the signed payload; nonce 17 = 17 execs exactly. |
| 14 | ECDSA malleability / signature tricks | ❌ **NO** | Malleability still requires a valid owner signature over the exact tx hash; not an extraction path. |
| 15 | EIP-7702 delegation on an owner EOA | ❌ **NO** | All 6 owners `eth_getCode = 0x` at the latest block (checked repeatedly); no `0xef0100…` marker. No delegated contract can act as an owner. |
| 16 | Owner is contract-controlled with a permissionless method | ❌ **NO** | All owners are code-less EOAs (nonces/balances normal). None of them forwards calls to the Safe. |
| 17 | Unsolicited token callbacks / spam tokens as a trap | ⚠ **Noted, harmless** | The Safe received 3 spam tokens (incl. one fake "Metis" from a dead-address and an ERC-1155 with `onERC1155Received` callback in 2024). Callbacks returned selectors; no approvals given; the Safe never called those tokens. Value-less. |
| 18 | Fallback-handler reentrancy | ❌ **NO** | v1.3.0 uses CALL (separate storage context). Handler functions that call back into `msg.sender` (= the Safe) are reads (`domainSeparator`, `signedMessages`, `checkSignatures`, `getModulesPaginated`) or the revert-only `simulateAndRevert`. No privileged reentry; no value path. |
| 19 | Forced METIS / selfdestruct into the Safe | ⚠ **Noted** | Only adds value. |
| 20 | Gas-griefing / DoS on Safe ops | ⚠ **Noted** | Not an extraction vector; no evidence of active DoS. |
| 21 | Historic v1.1.x–v1.2.0 Safe bugs (e.g., delegatecall storage, `execTransactionFromModule` issues) | ❌ **N/A** | Deployed version is v1.3.0. |
| 22 | Key compromise / social engineering of signers | ✅ **Privileged only** | Not unprivileged. Requires ≥4 of 6 external EOA keys. On-chain hygiene observations: one operator (`0xb41b842A…`, 403 METIS for gas) proposes/executes everything; one key (`0x0be0515B…`) has never transacted; the other four sign intermittently. See §9 for the historical 2-of-3 window. |

**No vector yields unprivileged value transfer.** The only complete bypass would be compromise of 4 distinct owner EOA keys (or 4 colluding owners), which is the wallet's intended security model.

---

## 5. Owner set (6 EOAs) — full detail

| Owner | Added (event) | Nonce | Balance (METIS) | Code / 7702 | Notes |
|---|---|---|---|---|---|
| `0x02836327aCE76966d0c062A8A25bCBB04e1A0BaB` | initial (setup, threshold 2) | 129 | 4.826 | `0x` / no | Active EOA; also uses an Ethereum Safe. |
| `0xAdabeccd521dAcE92c85Be0265b84Ca577937882` | initial | 151 | 4.813 | `0x` / no | Executed nonces 0–1 (2023). |
| `0x923170a08b58b18B119e4972DE8d5710b65D1a30` | initial | 43 | 15.734 | `0x` / no | **Created the Safe** via the official factory; executed nonce 2; interacts with sibling EDF Safe. |
| `0xb41b842AA0f803eA815eE9A4EEF956ddF8745a66` | nonce 0, 2023-12-20 15:48 UTC | 72 | 403.093 | `0x` / no | **Executes all 2025–2026 transactions**; owner of Aave-on-Metis "Guardian" Safe `0x97177cD8…` per Aave permissions book. |
| `0x0be0515B5369952e4536E0ed2c8133C7F40a0C96` | nonce 1, 2023-12-20 23:05 UTC | 0 | 0 | `0x` / no | **Never sent a single transaction** — cold signer. |
| `0xFA30D7D32288C2F27cD5a099dB7507B085b36071` | nonce 2, 2023-12-21 16:10 UTC | 24 | 7,210.912 | `0x` / no | Holds the largest owner balance. |

No owner was ever removed. No explorer labels exist for any of the six (checked via Blockscout v2). Full research log in `owners_research.md`.

---

## 6. Organization identification

**Most likely owner/operator: Metis Foundation / MetisDAO — the Metis Ecosystem Development Fund (Metis EDF).** Evidence:

1. **Timing & amount match:** the fund was announced **2023-12-18** with **4,600,000 METIS**, split officially as **3,000,000 METIS sequencer mining / 1,600,000 METIS ecosystem funding** (metis.io blog; The Block; @MetisL2 X post). On **2023-12-20**, funder `0x26eC4FF77DF305d5a9A7660E046dd1c06ce517f6` (a Metis ops EOA active since Dec-2021) sent **exactly 3,000,000 METIS to this Safe**, **1,390,000 METIS to sibling GnosisSafeProxy `0xeA0f824C…`**, and **200,000 METIS to EOA `0x1e6A6ad3…`** = 4,590,000 total (~the full 4.6M endowment).
2. **Signer-set overlap:** sibling Safe `0xeA0f824C…` (threshold 4/7) has the **same 6 owners + `0x65e4926E…`**; same singleton, same handler. One operational cluster.
3. **Role evidence:** owner `0xb41b842A…` is also a signer of the Aave-on-Metis Guardian Safe (Aave DAO permissions book, METIS-V3.md); the EDF funds sequencer/ecosystem operations.
4. **Spending pattern:** 2026 outflows flow to an ops wallet which forwards to a Bulksender mass-distribution contract (`bulksendEther`), consistent with ecosystem reward/grant disbursements rather than exchange or personal custody.
5. **No contrary evidence:** no incident report, leak, or governance post about the wallet; no public label naming a different org; the address is not published by Metis (identification is by on-chain linkage).

Caveat: the exact address is not officially published anywhere we could find, so the label carries **medium-high** (not absolute) confidence; the on-chain facts carry high confidence.

---

## 7. Transaction history & accounting

Wallet created **2023-12-20 00:58:20 UTC** (block 9778033) by owner `0x923170a0…` through the official factory (`createProxyWithNonce`, singleton `0xfb1bff…`, `setup(owners=[0x02836327, 0xAdabeccd, 0x923170a0], threshold=2, fallbackHandler=0x017062a1…)`, saltNonce 1703033908069).

Setup & governance phase (all success, all ECDSA sigs = threshold):

| Time (UTC) | nonce | Action | Thr | Sigs |
|---|---|---|---|---|
| 2023-12-20 00:58:20 | — | creation via factory | 2 | — |
| 2023-12-20 15:21:20 | — | **+1 METIS** received from `0x26eC4FF7…` | — | — |
| 2023-12-20 15:22:50 | — | **+2,999,999 METIS** received from `0x26eC4FF7…` | — | — |
| 2023-12-20 15:48:20 | 0 | `addOwner(0xb41b842A…)` | 2 | 2/2 |
| 2023-12-20 23:05:20 | 1 | `addOwner(0x0be0515B…)` + threshold→3 | 2 | 2/2 |
| 2023-12-21 16:10:20 | 2 | `addOwner(0xFA30D7D3…)` + threshold→4 | 3 | 3/3 |

Outflows (all `execTransaction`, operation = 0/call, all executed by `0xb41b842A…` except as noted, all **4/4 signatures at threshold 4**):

| # | Time (UTC) | Amount (METIS) | Recipient | Notes |
|---|---|---|---|---|
| 3 | 2025-12-26 22:53 | 210,000 | `0x7Ea5c408…` | partner/pass-through |
| 4 | 2025-12-27 16:48 | 199,999.99999999997 | `0x7Ea5c408…` | (2025 wallet re-activation) |
| 5 | 2026-05-27 04:17 | 90,000 | `0xB6bB55B1…` | ops/payout wallet |
| 6 | 2026-06-04 14:16 | 44,000 | `0xB6bB55B1…` | |
| 7 | 2026-06-29 15:46 | 30,000 | `0x0f33AF4D…` | → Bulksender distribution |
| 8 | 2026-07-30 20:44 | 32,000 | `0x0f33AF4D…` | |
| 9 | 2026-07-30 20:45 | 87,710 | `0xB6bB55B1…` | |
| 10 | 2026-08-04 17:58 | 70,000 | `0xB6bB55B1…` | |
| 11 | 2026-08-23 15:39 | 87,412.60 | `0xB6bB55B1…` | |
| 12 | 2026-08-26 19:44 | 31,000.000000000004 | `0xB6bB55B1…` | |
| 13 | 2026-08-27 01:15 | 50,173.99999999999 | `0xB6bB55B1…` | |
| 14 | 2026-09-01 17:40 | 30,000 | `0xB6bB55B1…` | |
| 15 | 2026-09-28 03:06 | 27,000.000000000004 | `0x0f33AF4D…` | |
| 16 | 2026-09-28 13:44 | 163,151.036 | `0xB6bB55B1…` | most recent tx |

**Accounting check (exact):** received 3,000,000 − sent 1,152,447.636 = **1,847,552.364 METIS** = the live balance read at every snapshot block. ✅

Event audit (42 logs total, whole history): 17× `SafeMultiSigTransaction` (L2), 17× `ExecutionSuccess`, 3× `AddedOwner`, 2× `ChangedThreshold`, 1× `SafeSetup`, 2× `SafeReceived`. **Zero** `ExecutionFailure`, `EnabledModule`, `DisabledModule`, `ChangedGuard`, `ApproveHash`, `SignMsg`, `SafeModuleTransaction`, `ChangedFallbackHandler`.
Token events: only 3 inbound spam transfers (never touched by the Safe). No ERC-20 approvals ever executed.

**Purpose:** dormant Dec-2023→Dec-2025 reserve, then monthly-ish outflows of 27k–163k METIS to ops/distribution wallets — consistent with a **treasury/disbursement wallet for the EDF sequencer-mining allocation** (fund grant/sequencer rewards). No bridge/staking contract interactions.

---

## 8. "Fewer than 4 confirmations" audit

- **17 executions, 0 failures, 0 with signature count below their own threshold.** Signature packs are all clean multiples of 65 bytes (2, 3, or 4 ECDSA signatures; no contract sigs, no approve-hash entries, no remainder bytes).
- **3 executions** have `threshold_at_exec < 4` (nonces 0, 1, 2 with thresholds 2, 2, 3) — these were the owner/threshold setup calls in Dec-2023, executed **while those lower thresholds were current** (and before any METIS ever left the wallet).
- Historical risk window: the 3,000,000 METIS arrived at 2023-12-20 15:21–15:22 UTC while the wallet was still **2-of-3** (initial owners). Threshold became 3 at 23:05 and **4 at 2023-12-21 16:10**, before the first outflow (2025-12-26). The only period in which fewer than 4 keys could have moved funds was that ~25-hour setup window (and no funds moved then). This window is closed; the wallet has been 4-of-6 throughout all spending.
- Every outflow transaction (nonces 3–16) = exactly **4 distinct owner signatures / threshold 4**.

---

## 9. Final classification

| Bucket | Amount | USD @ METIS ≈ $10 | Confidence |
|---|---|---|---|
| **E-U (unprivileged extraction)** | **0 METIS** | **$0** | **HIGH** (exhaustive vector analysis; no modules/guard; canonical code; 4-of-6 EOAs; all stacks verified on-chain) |
| **H-O (owner-gated holdings)** | **1,847,552.364 METIS** | **$18,475,523.64** | MEDIUM-HIGH (amount + gating certain; "Metis EDF/Foundation" label inferred) |
| P (partial/pending path) | none found | — | HIGH |
| S (stuck/locked) | not applicable — funds are movable by owners and have moved | — | HIGH |

Owner-key risk (privileged, not E-U): 4-of-6 threshold with one historically idle key; 14 recent transactions signed by the same 4+ signers with a single submitting key; no on-chain signs of compromise. This is operational risk, not an unprivileged extraction path.

---

## 10. Evidence files

| File | Content |
|---|---|
| `safe_state.json` | Verified state at block 23238812 (singleton, threshold, owners, modules, guard, handler, balances, codehashes) |
| `owners.json` | Per-owner code/7702/balance/nonce at block 23238812 + `latest` |
| `txs.json` | Full curated history: setup, owner changes, funding, 17 executions with threshold/sig counts, totals/accounting, event audit |
| `owners_research.md` | Owner & counterparty research + org evidence chain + search log |
| `raw/` | Raw responses: Blockscout address/tx/token/log JSONs, decoded logs, verified & upstream sources + diff, singleton/proxy/handler bytecode, safe-deployments files |
| `reads_state.sh`, `final_state.sh`, `decode_logs.py`, `build_txs.py` | Reproducible read scripts (read-only) |

Key block numbers: 9778033 (creation), 9786880/9786892 (funding), 9792959, 9810213 (threshold raises), 23238718/23238798/23238812 (verification snapshots).

---

## 11. Residual uncertainty / trust assumptions

1. **Org label**: "Metis EDF / Foundation" is inferred from the 4.59M/4.6M split on the announcement day, allocation-matched amounts, sibling-Safe signer overlap and distribution behavior. The exact address is not officially published; confidence medium-high.
2. **Source verification**: integrity rests on the explorer's verified-source match + our diff vs `safe-contracts v1.3.0` + official codehash equality in `safe-deployments` (both canonical and eip155 share our codehash). No local bytecode rebuild was performed (kept light per instructions); all runtime probes (selectors, storage semantics, L2 events, linked-list owners) corroborate v1.3.0 behavior.
3. **Off-chain key hygiene** cannot be assessed from chain data. The E-U verdict is unaffected (unprivileged), but H-O risk depends on signer custody.
4. No transactions were signed/sent; no mainnet state was modified.

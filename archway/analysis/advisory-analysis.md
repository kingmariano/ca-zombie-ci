# C2-09 Archway — CosmWasm advisory mapping against the deployed stack

Deployed: wasmvm **v1.5.5** (module zip hash-matched), cosmwasm-vm v1.5.8, Wasmer 4.2.2,
wasmd **v0.51.0** (archway fork of 0.50.2), wasmd line EOL (no 0.51 patches exist).
Upload + instantiate permissions: **Everybody**. Sources: CosmWasm advisories repo
(`github.com/CosmWasm/advisories`), OSV/GHSA, wasmvm/cosmwasm/wasmd source.

| Advisory | Severity | Affected range (per advisory) | Deployed 1.5.5 affected? | Effect | Trigger | Patch |
|---|---|---|---|---|---|---|
| **CWA-2025-001** (GHSA-23qp-3c2m-xx6w) | Medium | wasmvm < 1.5.8 | **YES** — fix absent in hash-matched zip | **Chain crash** (CWE-476 in FFI empty-slice handling) | Malicious contract | wasmvm 1.5.8 (memory.rs null-ptr for empty slices) |
| **CWA-2025-002** (GHSA-mx2j-7cmv-353c) | Medium | wasmvm < 1.5.8 (cosmwasm-vm < 1.5.10) | **YES** — cosmwasm-vm pin v1.5.8 lacks gas charges | **Block-production slowdown** (host calls / memory reads not gas-metered) | Malicious contract | wasmvm 1.5.8 / cosmwasm-vm 1.5.10 |
| **CWA-2025-004** | Low | wasmd ≥0.40 <0.55.1 | YES (0.51.0) | Sub-message can skip gas | Contract | wasmd 0.55.1+ |
| **CWA-2025-005** | Low/Med | wasmd ≥0.40 <0.55.1 | YES (0.51.0) | IBC entrypoints don't charge setup cost (node work) | Contract | wasmd 0.55.1+ |
| **CWA-2025-006** | Low/Med | wasmd ≥0.51.0 <0.55.1 | YES (0.51.0) | Contract error during IBC channel open doesn't abort open | Contract | wasmd 0.55.1+ |
| **CWA-2025-007** | Medium | wasmd ≤0.54.2 | **YES** (0.51.0) | **Stack overflow → node crash / chain halt** via unbounded reply recursion | Malicious contract (mechanism public) | wasmd ≥0.54.3 (no 0.51 line) |
| **CWA-2026-003** | — | wasmd ≤0.54.7 | **YES** (0.51.0) | Significant block-production delays | Attacker contract | wasmd 0.54.7/0.60.6/0.61.10 (no 0.51 line) |
| **CWA-2026-005** | High | wasmvm ≤2.2.7/2.3.3/3.0.6 ("only supported listed"; older lines affected) | **YES** (1.5.5) | **Chain stall** via huge numbers of Wasm locals | Malicious contract (store+execute) | wasmvm 2.2.8+ (limits + gas) |
| **CWA-2026-006** | **Critical — fund loss** | wasmvm ≤2.2.8/2.3.4/3.0.7 + "versions outside the maintained lines are affected and will not be patched" | **YES** (1.5.5, Wasmer 4.2.2) | **Wasmer Singlepass sandbox escape → native code in node process → unauthorized minting of native tokens + permanent loss of user funds** | Store + instantiate attacker contract; no governance/validator key needed where upload/instantiate open | wasmvm 2.2.9/2.3.5/3.0.8 (Wasmer 7.4.2, Sep 28 2026) |

Not applicable to 1.5.5: CWA-2025-003 (affects exactly 1.5.8), CWA-2026-001/002/004
(2.x/3.x lines / IBCv2), and all earlier CWAs fixed before 1.5.5.

## Key facts

- CWA-2026-006 timeline: report 2026-08-18; chains notified 2026-09-03; private patch
  2026-09-10; **public disclosure 2026-09-28** — 7 days before this measurement. No
  Archway release or governance action has responded.
- CWA-2026-006 mitigation note: "There is no configuration only mitigation that removes
  the vulnerability... Restricting code_upload_access and instantiate_default_permission
  to governance or an allowlist raises the bar... Disabling MsgStoreCode/MsgInstantiate
  blocks new delivery entirely." Archway has **none** of these restrictions live.
- "A contract already stored on chain by an attacker remains a path even where those
  parameters are restricted" — Archway's 889 codes/6,644 contracts are not screened.
- The exact crafted-Wasm trigger for CWA-2025-001/002/006 is not public ("More detail
  will be added here once chains have had a chance to upgrade"), so the capability is
  vendor-confirmed but the end-to-end exploit is **not reproduced in this work**.
- CWA-2025-007's mechanism (recursive submessages from a reply handler) is publicly
  described and is the most straightforward of the halt paths to implement.

## Consequence classification

- **DoS/halt (no theft):** CWA-2025-001, 2025-002, 2025-007, 2026-003, 2026-005.
  Direct attacker profit: **$0**; damage = chain liveness. No Archway-specific value
  extraction follows from a halt (see README §6).
- **Theft (E-U):** CWA-2026-006 — the only advisory in the set that converts to value
  extraction, and it is reachable by "any ordinary funded account" where upload and
  instantiate are open.

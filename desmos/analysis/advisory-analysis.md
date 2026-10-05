# C2-10 Desmos — advisory applicability (exact)

Deployed: **wasmvm 1.5.2 / 1.5.3**, **ibc-go/v7 7.4.0** (see `version-evidence.md`). Chain binary has not been upgraded since v7.1.1 (2024-08-08).

## A. wasmvm — CWA-2025-001 / CWA-2025-002

| | CWA-2025-001 | CWA-2025-002 |
|---|---|---|
| GHSA | GHSA-23qp-3c2m-xx6w | GHSA-mx2j-7cmv-353c |
| Summary | **Malicious smart contract can crash the chain** | Malicious contract can slow down block production |
| Affected | wasmvm < 1.5.8 (also 2.0.0–2.0.5, 2.1.0–2.1.4, 2.2.0–2.2.1) | wasmvm < 1.5.8 (cargo < 1.5.10) |
| Patched | 1.5.8 / 2.0.6 / 2.1.5 / 2.2.2 | 1.5.8 (cargo 1.5.10) |
| Trigger | "can only be triggered *reliably* with a malicious contract, so permissioned chains are much less likely to be affected" | "attack requires a malicious contract" |
| Desmos | **VULNERABLE** (1.5.2/1.5.3 < 1.5.8) | **VULNERABLE** |

Live Desmos preconditions (all verified on-chain, 2026-10-05, h≈30,863,3xx):
- `code_upload_access = ACCESS_TYPE_EVERYBODY`; `instantiate_default_permission = ACCESS_TYPE_EVERYBODY` (gRPC `cosmwasm.wasm.v1.Query/Params`).
- 34 wasm codes already stored, all `ACCESS_TYPE_EVERYBODY`; 26 codes have instantiated contracts (≈60 contracts).
- No whitelist/allowlist: any address can `MsgStoreCode` a malicious contract and instantiate/call it. Cost = one tx fee in udsm (no listing fee).
- wasmd v0.45.0 runs wasmvm as a Go dependency compiled into the node binary — the vulnerable Rust VM is inside every validator.

## B. ibc-go — ASA-2025-004 (earlier) and ISA-2025-001 (full)

| | ASA-2025-004 | ISA-2025-001 |
|---|---|---|
| GHSA | GHSA-jg6f-48ff-5xrw | GHSA-4wf3-5qj9-368v |
| Published | 2025-02-28 | 2025-03-12 |
| Summary | Non-deterministic JSON unmarshalling of IBC acknowledgement → chain halt | Same, extended to **all applications** beyond transfer |
| Affected v7 | < 7.9.2 | < 7.10.0 |
| Patched v7 | 7.9.2 | 7.10.0 |
| Desmos | **VULNERABLE** (7.4.0) | **VULNERABLE** (7.4.0) |

Mechanics of the v7.10.0 fix (`modules/core/04-channel/keeper/packet.go`, `AcknowledgePacket`):
```go
var ack types.Acknowledgement
err := types.SubModuleCdc.UnmarshalJSON(acknowledgement, &ack)
if err == nil {
    ackBz := ack.Acknowledgement()
    if !bytes.Equal(ackBz, acknowledgement) {
        return sdkerrors.Wrap(types.ErrInvalidAcknowledgement, "acknowledgement marshalling error")
    }
}
```
i.e. the vulnerable version accepts acknowledgement bytes that do **not** round-trip through the canonical JSON marshaller; re-marshalling during ack handling produces state/execution divergence across nodes → app-hash mismatch → **chain halt**. The release note states: *"If the vulnerability is exploited before 2/3 is patched, the chain will halt."*

Precondition (advisory text): *"Any user that can open an IBC channel can introduce this state to the chain."* Desmos specifics:
- Standard `MsgChannelOpenInit` is permissionless; `app/app.go` (v7.1.1) registers the standard IBC router (`transfer`, `ibc-profiles`, `wasm` via `wasm.NewIBCHandler`, `icahost`, `icacontroller`) with **no channel-opening allowlist / permissioned-channel middleware**. The 2025 workaround ("permission Channel Opening") requires a code change; none exists on this binary.
- The attacker can use the permissionless wasm upload to deploy an IBC-enabled contract and open a channel to a counterparty app they control, then relay a crafted acknowledgement.

## C. Halt impact

Both classes give an unprivileged attacker a **reliable, cheap chain halt** (single-digit USD in fees):
- wasm: upload + instantiate/call a malicious contract (reliable crash per CWA-2025-001).
- IBC: open a channel + craft an acknowledgement (halt per ISA-2025-001).

Neither path moves funds. See `halt-extraction-analysis.md` for the value-extraction analysis (result: $0).

## D. Negative/limiting checks

- No newer Desmos release exists to upgrade to; the chain is not merely un-upgraded but **end-of-line** (latest release v7.1.1). Patching requires a new coordinated release + upgrade proposal.
- IBC relaying on Desmos is sparse (Osmosis client last updated ~47 h before the snapshot vs 9-day trusting period; props 50/51 had to recover the expired client in Jan/Sep 2026), so the IBC vector is operationally slower, while the wasm vector does not depend on relayers.

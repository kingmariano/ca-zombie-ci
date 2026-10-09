# C2-34 — IBC reachability and today's behavior

**Date:** 2026-10-09 · Read-only public LCD reads + source inspection. Raw: `analysis/ibc_state.json`.

## 1. Mechanism (what the advisories fix)

Both advisories concern **non-deterministic JSON unmarshalling of an IBC acknowledgement** in the
acknowledgement processing path:

- ASA-2025-004 (GHSA-jg6f-48ff-5xrw): ibc-go `< 7.9.2` (v2–v7) and v8 `< 8.6.1`; fix v8.6.1 in
  `modules/apps/transfer/ibc_module.go` (`OnAcknowledgementPacket`).
- ISA-2025-001 (GHSA-4wf3-5qj9-368v): `< 7.10.0` and v8 `>= 8.0.0-alpha.1 < 8.7.0`; fix v8.7.0 in
  `modules/core/04-channel/keeper/packet.go` (`AcknowledgePacket`) — extends the protection to all apps.

Fix semantics (authoritative): after unmarshalling, **re-marshal the acknowledgement with ibc-go's
codec and require byte equality with the supplied bytes**; otherwise return
`ErrInvalidAcknowledgement` ("acknowledgement marshalling error"). Pre-fix, acknowledgements that
unmarshal but do not round-trip canonically could be processed into divergent state across nodes →
app-hash divergence → **chain halt**. The advisories describe a liveness impact only (no fund-loss
primitive), and state: *"Any user that can open an IBC channel can introduce this state to the chain."*

The exact internal Go-JSON divergence (the specific non-canonical encodings) is not spelled out in the
public advisories; the fix's round-trip byte-equality condition is the public statement of the
vulnerable condition. This is a documentation gap, not a verdict gap: the fix is present and effective.

## 2. Is the path permissionlessly reachable on dYdX? (reachability analysis)

**Yes in principle, for a hypothetical unpatched build.** Channel opening is NOT permissioned on
dYdX: the app's internal-message list (`protocol/app/msgs/internal_msgs.go`, `protocol/lib/ante/internal_msg.go`
@ protocol/v9.7.1) marks only IBC **params-update** messages as gov-only
(`MsgUpdateParams` for transfer/ICA-host/client/connection). `MsgChannelOpenInit` /
`MsgChannelOpenTry` are ordinary user messages — anyone can open a channel (paying fees), matching
the advisory's precondition. The crafted acknowledgement must then be committed on the counterparty
and relayed with a valid proof — feasible for an attacker-controlled counterparty (or any counterparty
whose module can be induced to write the crafted ack).

**But the live chain is patched** (see `fork-patch-verification.md`), so the state cannot be
introduced: a non-canonical ack is rejected as a failed tx, and block production continues.

## 3. Live IBC state (public LCD, 2026-10-09)

| Item | Value |
|---|---|
| Channels | **123 total** — 76 OPEN, 42 CLOSED, 5 TRYOPEN; ports: `icahost` 83, `transfer` 40 |
| Connections | **47 total** — 40 OPEN, 3 TRYOPEN, 4 INIT |
| Canonical USDC route | `transfer/channel-0` (OPEN, unordered) ↔ counterparty `transfer/channel-33` (Noble); total Noble USDC supply on dYdX = **70,772,323.76 USDC** |
| stDYDX route | `transfer/channel-1` ↔ counterparty channel-160 (Stride); supply 513.38 stDYDX |
| Other transfer channels | 40 transfer channels in total (history incl. closed) |

Reads: `https://dydx-dao-api.polkachu.com/ibc/core/...` at height ~108,685,774–108,729,261
(2026-10-09T07:01Z–14:46Z); CI re-derivation at height 108,686,391 (run 37897247041) reports the same
123 channels / 47 connections.

## 4. Today's behavior (patched)

With the fork fix in place, submitting/relaying a non-round-trippable acknowledgement causes
`AcknowledgePacket` to return `ErrInvalidAcknowledgement` before proof verification and the app
callback; the `MsgAcknowledgement` transaction fails as a normal error, no state is committed, and
the chain keeps producing blocks. The transfer-module check gives the same protection for ICS-20
acks specifically. There is no halt, and no value moves.

## 5. Verdict

- Reachability precondition (permissionless channel opening) **exists**, but the vulnerable code path
  is **closed** on the live chain.
- Residual risk is monitor-only: re-check the `protocol/go.mod` replace line and the two fix markers
  for every future dYdX release (especially the pending v9.8 upgrade).

# C2-34 — Advisory → live dYdX chain mapping (consolidated)

**Date of reads:** 2026-10-09 (live dydx-mainnet-1 height ~108.69M at 07:00–07:15Z).
**Method:** public LCD/RPC reads + public GitHub sources only. No secrets, no transactions.

## 1. The two advisories (ibc-go "non-deterministic ack unmarshal → chain halt")

| Advisory | GHSA | Published | Affected (as published) | Fix releases | Fix location |
|---|---|---|---|---|---|
| **ASA-2025-004** | GHSA-jg6f-48ff-5xrw | 2025-02-27/28 | ibc-go `< 7.9.2` (v2–v7 lines); **v8 `< 8.6.1`** | v7.9.2 / **v8.6.1** | `modules/apps/transfer/ibc_module.go` — `OnAcknowledgementPacket` re-marshal byte-equality check |
| **ISA-2025-001** | GHSA-4wf3-5qj9-368v | 2025-03-12 | ibc-go `< 7.10.0` (v2–v7); **v8 `>=8.0.0-alpha.1 < 8.7.0`** | v7.10.0 / **v8.7.0** | `modules/core/04-channel/keeper/packet.go` — `AcknowledgePacket` re-marshal byte-equality check (extends protection to all apps) |

Quotes (GitHub Advisory Database, fetched 2026-10-09):

- ASA-2025-004: *"An issue was discovered in IBC-Go's deserialization of acknowledgements that results in non-deterministic behavior which can halt a chain. Any user that can open an IBC channel can introduce this state to the chain."* Workaround: *"it is possible to permission Channel Opening"*. Criticality: Critical (Considerable Impact; Almost Certain Likelihood).
- ISA-2025-001: same wording; *"The following patch is in addition to the previous patch which now extends the same protection to all applications beyond transfer."* Criticality: High (Considerable Impact; Likely Likelihood). OSV GO-2025-3517 maps the affected symbol to `modules/core/04-channel/keeper.Keeper.AcknowledgePacket`.

Impact class: **chain halt (liveness / DoS only)** — no fund-loss primitive is described in either advisory; the fixed state is a packet acknowledgement, and the patch merely rejects non-round-trippable acks.

## 2. What the live chain actually runs

- `dydx-mainnet-1`, app versions reported by independent public nodes: **9.7.1** (commit 5935cb7c…, dydx-rest.publicnode.com) and **9.7.0** (commit 67a3c716…, dydx-dao-api.polkachu.com), build dep **`github.com/cosmos/ibc-go/v8 v8.5.1` with an EMPTY sum** — the empty sum marks a module replaced by the `replace` directive (cosmos-sdk, cometbft, iavl, ibc-go all show empty sums and are all replaced by dydxprotocol forks).
- `protocol/go.mod` at tags `protocol/v9.7.0`, `protocol/v9.7.1` and `main` (raw.githubusercontent.com, fetched 2026-10-09):
  `github.com/cosmos/ibc-go/v8 => github.com/dydxprotocol/ibc-go/v8 v8.0.0-rc.0.0.20250312180215-8733b3edf43a`
  → the built code is the dYdX fork at commit **8733b3edf43a**, dated **2025-03-12T18:02:15Z** (same day as the ISA-2025-001 publication, hours before/around it).

### 2.1 Does the fork contain the fixes? — YES, both

Fetched from `raw.githubusercontent.com/dydxprotocol/ibc-go/8733b3edf43a/…` (2026-10-09):

| Fix | File | Marker in fork | Line |
|---|---|---|---|
| ASA-2025-004 | `modules/apps/transfer/ibc_module.go` | `bz := types.ModuleCdc.MustMarshalJSON(&ack); if !bytes.Equal(bz, acknowledgement) { … "acknowledgement did not marshal to expected bytes" … }` inside `OnAcknowledgementPacket` (func at line 230, check at 245–247, before keeper call) | 245–247 |
| ISA-2025-001 | `modules/core/04-channel/keeper/packet.go` | `err := types.SubModuleCdc.UnmarshalJSON(acknowledgement, &ack); if err == nil { ackBz := ack.Acknowledgement(); if !bytes.Equal(ackBz, acknowledgement) { … "acknowledgement marshalling error" … } }` inside `AcknowledgePacket` (func at line 358, check at 431–435, before proof verification/app callback) | 431–435 |

Both hunks are semantically the same as the upstream v8.6.1 / v8.7.0 fixes (compare files fetched from `cosmos/ibc-go` at those tags).

**Therefore: the live dYdX chain is NOT affected by the halt advisories**, despite the self-reported `ibc-go/v8 v8.5.1` version string. The version-string match to the vulnerable ranges (v8.5.1 < 8.6.1 and < 8.7.0) is what caused the corpus flag; the effective code is the patched fork.

### 2.2 No ack-deserializing middleware

Live build deps (247 entries, polkachu node) contain **no** ibc-hooks, **no** packet-forward-middleware, **no** wasm/08-wasm. Only slinky (oracle), grpc middleware, uber ratelimit. So the "middlewares that serialize acks" caveat in the advisories does not apply either.

## 3. Upgrade history relevant to the patch

- The fork pin (`8733b3edf43a`) is present in every checked v9.x protocol release (see `fork-version-matrix.json`, child-verified).
- Gov proposal **395** (passed 2026-09-07): software upgrade to **v9.7**, plan height 105,002,000 — the live chain (9.7.0/9.7.1) is the result.
- Gov proposal **398** (in voting period at read time, submitted 2026-10-08, voting ends 2026-10-11T02:23Z; tally yes 161.4M / abstain 15.5M / no 0 → quorum met, passing): software upgrade to **v9.8**, plan height **109,170,000**, binaries `v9.8.0-9ab4e17a` on the dYdX S3 release bucket. The v9.8.0 source commit was not yet public on GitHub at read time, so its ibc-go pin could not be independently checked; the running v9.7.x build is already patched regardless.
- `current_plan = null` (no plan executed/queued outside gov).

## 4. Reachability (for completeness / latent-risk framing)

Per the advisories the vulnerable state can be introduced by *any user that can open an IBC channel*. On dYdX (see `ibc-reachability.md`), channel opening is permissionless by default unless gated; the chain has N live channels/connections (see that file). **This reachability does not matter today because the code path is patched at the pinned commit** — a non-canonical ack is rejected with `ErrInvalidAcknowledgement` ("acknowledgement marshalling error") and the tx fails; the chain continues producing blocks.

## 5. Verdict

- **Patched (high confidence).** Effective ibc-go code = dydxprotocol fork commit 8733b3edf43a with both fix checks; live v9.7.x binaries pin that commit; both independent nodes agree.
- **E-U extraction: $0** (halt class has no theft primitive; and the vector is closed).
- **DoS: $0 realized** (closed). Latent only if a future release drops the fork/replace or regresses — monitor `protocol/go.mod` replace line per release.

# C2-34 — Fork patch verification: dYdX's vendored ibc-go is patched for both advisories

**Date:** 2026-10-09 · **Method:** public GitHub raw/API + proxy.golang.org; no transactions; no secrets.
**Raw data:** `raw/gomods/protocol-v*-go.mod` (24 tags), `raw/commit-8733b3edf43a.json`,
`raw/fork-commits-page1.json`, `raw/fork-*.go`, `raw/upstream-*.go`, `raw/proxy/*`,
`analysis/fork-version-matrix.json`, `analysis/module-artifact-check.md`.

## 1. The fork's security history (from the fork repo itself)

`dydxprotocol/ibc-go` commit list (`raw/fork-commits-page1.json`):

| Commit | Date (UTC) | Message | Meaning |
|---|---|---|---|
| `8733b3edf43a` | **2025-03-12T18:02:15Z** | "fix packet test by adding ctx" (PGP-signed, GitHub `verified: true`; parent `8b909d54ce09`) | **Fork tip pinned by every dYdX release since v8.0.8** |
| `8b909d54ce09` | 2025-03-12T18:01:30Z | "Merge commit from fork" | ISA-2025-001 fix merge (published 2025-03-12) |
| `e238a5667825` | **2025-02-28T14:25:59Z** | "fix: remove packet data remarshaling (#8065)" | ASA-2025-004 fix cherry-pick (published 2025-02-27/28) |
| `5cd00bf00e29` | 2025-02-28T14:24:33Z | "Merge commit from fork" | — |
| `ef088baf7b6c` | 2025-02-28T14:13:06Z | "Chore/revert ibc proto updates (#7887)" | part of the v8.6.1 patch set |
| `2551dea41cd3` | 2023-11-10 | "update changelog for v8.0.0 release" | fork base = upstream v8.0.0 |

The fork is a v8.0.0 base with dYdX's own patches; **dYdX cherry-picked both halt fixes on the same day each advisory was published**.

## 2. Fix markers per ref (verified)

| Ref | ASA-2025-004 marker (`acknowledgement did not marshal to expected bytes`, transfer) | ISA-2025-001 marker (`acknowledgement marshalling error`, core `AcknowledgePacket`) |
|---|---|---|
| upstream `cosmos/ibc-go` v8.0.0 | absent | absent |
| upstream v8.5.1 (the version STRING dYdX reports) | absent | absent |
| upstream v8.6.1 (ASA fix) | **present** | absent |
| upstream v8.7.0 (ISA fix) | present | **present** |
| fork `e238a5667825` (v8.0.7) | **present** | absent |
| **fork `8733b3edf43a` (v8.0.8+, live v9.7.x)** | **present** (line 247, inside `OnAcknowledgementPacket`) | **present** (line 435, inside `AcknowledgePacket` @ line 358) |

## 3. Release matrix (dydxprotocol/v4-chain tags → effective ibc-go)

See `analysis/fork-version-matrix.json` for the full table. Summary:

- **v8.0.1 – v8.0.6** (2024): `github.com/cosmos/ibc-go/v8 => github.com/cosmos/ibc-go/v8 v8.0.0` — **upstream v8.0.0, vulnerable to both advisories** (historical; these releases are long superseded).
- **v8.0.7** (2025-02-28+): fork `e238a5667825` — ASA fixed, ISA not yet (window of a few days).
- **v8.0.8 onward** (2025-03-12+): fork `8733b3edf43a` — **both fixed**; includes v8.0.8–v8.0.13, v8.1.0, v8.2.0, and **all v9.0.0–v9.7.1**.
- Live nodes run **v9.7.0 / v9.7.1** (node_info, 2 independent endpoints) → both fixes.

## 4. Artifact-level and live evidence (see `module-artifact-check.md`)

- proxy.golang.org `.info` ties the pseudo-version to git commit `8733b3edf43a5fa412e65e0cc2ad75c3902b9014` (2025-03-12T18:02:15Z).
- The module **zip** contains both fix markers; its dirhash `h1:aF1rORtUApr+N6dWsNiT/G9H2ysfjyj5DiVRU8CRDaU=` **equals the go.sum entry** in v4-chain `protocol/v9.7.1/protocol/go.sum`.
- Live `node_info` on 4 endpoints (`analysis/node_info_dydx_{publicnode,polkachu,polkachu2,kingnodes}.json`): app 9.7.0/9.7.1, `github.com/cosmos/ibc-go/v8 v8.5.1` with **empty sum** (replaced), while non-replaced deps carry `h1:` sums.

## 5. Adversarial questions considered

- *Could the live binary use unpatched upstream v8.5.1 despite the replace?* No: the replace is in the release go.mod, the go.sum hash matches the patched artifact, and the build info's empty sum marks the module as replaced. Four independent node endpoints agree.
- *Could the fork commit contain the fix but not the code path?* No: the core check sits in `AcknowledgePacket` (the MsgAcknowledgement handler) before proof verification and the app callback; the transfer check sits in `OnAcknowledgementPacket` before the keeper call.
- *Middleware re-serialization caveat?* N/A — no ibc-hooks/packet-forward/wasm in build deps.

## 6. Verdict

**PATCHED — high confidence.** The chain has been immune to the ISA/ASA-2025 ack-halt class since protocol v8.0.8 (2025-03-12), and the live v9.7.x build pins the same fully patched fork commit.

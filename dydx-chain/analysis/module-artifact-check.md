# C2-34 — Module-artifact check: the exact built ibc-go code contains both fixes

**Date:** 2026-10-09. Read-only, public sources. This closes the loop beyond git-ref inspection:
the content-addressed Go module artifact that the dYdX v9.7.x binaries were built against is pinned
in `go.sum` and contains both advisory fixes.

## 1. Pseudo-version → git commit

`https://proxy.golang.org/github.com/dydxprotocol/ibc-go/v8/@v/v8.0.0-rc.0.0.20250312180215-8733b3edf43a.info`:

```json
{"Version":"v8.0.0-rc.0.0.20250312180215-8733b3edf43a",
 "Time":"2025-03-12T18:02:15Z",
 "Origin":{"VCS":"git","URL":"https://github.com/dydxprotocol/ibc-go",
           "Hash":"8733b3edf43a5fa412e65e0cc2ad75c3902b9014"}}
```

The pseudo-version is exactly the module version required (and replaced-to) by
`dydxprotocol/v4-chain` `protocol/go.mod` at tags `protocol/v9.7.0`, `protocol/v9.7.1` and `main`
(checked 2026-10-09). Timestamp 2025-03-12T18:02:15Z = the day ISA-2025-001 was published.

## 2. Artifact downloaded and inspected

- `https://proxy.golang.org/github.com/dydxprotocol/ibc-go/v8/@v/v8.0.0-rc.0.0.20250312180215-8733b3edf43a.zip`
- zip bytes: 18,560,193; sha256 recorded in `analysis/fork-module-zip.sha256`.
- Extracted from the zip:

| File in artifact | sha256 (16-hex prefix) | Fix marker found |
|---|---|---|
| `…/modules/apps/transfer/ibc_module.go` | `e7012c72d1e6e5e1…` | line 247: `acknowledgement did not marshal to expected bytes` (ASA-2025-004 fix, inside `OnAcknowledgementPacket`) |
| `…/modules/core/04-channel/keeper/packet.go` | `cb8403ab9de7e53c…` | line 435: `acknowledgement marshalling error` (ISA-2025-001 fix, inside `AcknowledgePacket`) |

## 3. Content hash matches dYdX's go.sum (supply-chain pin)

dirhash of the module zip (Go `dirhash.HashZip` algorithm, recomputed in Python):

```
h1:aF1rORtUApr+N6dWsNiT/G9H2ysfjyj5DiVRU8CRDaU=
```

`dydxprotocol/v4-chain` `protocol/v9.7.1/protocol/go.sum` contains:

```
github.com/dydxprotocol/ibc-go/v8 v8.0.0-rc.0.0.20250312180215-8733b3edf43a h1:aF1rORtUApr+N6dWsNiT/G9H2ysfjyj5DiVRU8CRDaU=
```

→ The hash of the artifact we inspected is byte-for-byte the artifact pinned by the dYdX release
the live nodes run (v9.7.x, nodes report 9.7.0/9.7.1). **The built code contains both fixes.**

## 4. Live build-info corroboration

`/cosmos/base/tendermint/v1beta1/node_info` on two independent public nodes reports
`github.com/cosmos/ibc-go/v8 v8.5.1` with an **empty sum** — the signature of a replaced module
(all dydxprotocol-replaced deps show empty sums; non-replaced deps carry `h1:` sums). The effective
module is the fork above; the version string `v8.5.1` is only the *requirement* line that the
replace overrides.

## 5. Verdict

**Patched — high confidence.** Three independent evidence layers agree:
1. git tree at commit 8733b3edf43a contains both fix hunks (raw.githubusercontent);
2. the content-addressed module zip contains both fix hunks;
3. the zip's h1 hash matches the go.sum pin of the live v9.7.x release.

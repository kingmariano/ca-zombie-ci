# C2-10 Desmos — deployed-version evidence (live)

Read-only queries against public endpoints, 2026-10-05. Raw node_info dumps:
`analysis/nodeinfo-v711.json`, `analysis/nodeinfo-v710.json`.

## Live node binaries (from `application_version.build_deps`)

| endpoint | moniker | app | SDK | wasmvm | wasmd | ibc-go | cometbft |
|---|---|---|---|---|---|---|---|
| `api.mainnet.desmos.network` (official) | desmos-m-fullnode-op3-lon | **7.1.1** (`0e53a67d`) | v0.47.10 | **v1.5.3** | v0.45.0 | **v7.4.0** | v0.37.4 |
| `desmos-rest.staketab.org` | Staketab-snap | **7.1.0** (`00b333c1`) | v0.47.10 | **v1.5.2** | v0.45.0 | **v7.4.0** | v0.37.4 |
| `rest.cosmos.directory/desmos` (LB, sampled 6×) | both of the above | 7.1.0 / 7.1.1 | — | v1.5.2 / v1.5.3 | — | v7.4.0 | — |

Query:
```
curl -s https://api.mainnet.desmos.network/cosmos/base/tendermint/v1beta1/node_info | jq '.application_version.build_deps'
```

## Upstream release state

- `desmos-labs/desmos` latest release: **v7.1.1, published 2024-08-08**. No releases after (checked `releases?per_page=10`).
- `desmos-labs/mainnet` has no post-2024 upgrade directory entry; last on-chain software-upgrade proposal is **#48 "Desmos v7.1.0 upgrade"** (passed 2024-05-03). Props 50/51 (2026) only *recover the IBC client to Osmosis* — no binary upgrade.
- Therefore the chain has run **unpatched 2024-era binaries for ~2 years**; it is affected by all 2025 interchain-stack advisories.

## Patched-version comparison

| component | deployed | advisory | patched in | vulnerable? |
|---|---|---|---|---|
| wasmvm | 1.5.2 / 1.5.3 | CWA-2025-001 (chain crash) | 1.5.8 | **YES** |
| wasmvm | 1.5.2 / 1.5.3 | CWA-2025-002 (block slowdown) | 1.5.8 / 1.5.10 | **YES** |
| ibc-go/v7 | 7.4.0 | ISA-2025-001 (chain halt) | 7.10.0 | **YES** |

Confidence: **high** — the versions come from the running nodes' own `build_deps` (compiled-in library versions), not from docs.

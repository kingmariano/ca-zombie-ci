# C2-09 Archway — version & deployment evidence (all read-only)

All reads 2026-10-05. Chain `archway-1`. Heights noted per item.

## 1. Live node reports (authoritative for the running binary)

Source: `GET https://api.mainnet.archway.io/cosmos/base/tendermint/v1beta1/node_info`
(saved: `analysis/node_info.json`; raw app_version captured in `ci-out/node_info_raw.json` by CI)

| field | value |
|---|---|
| network | archway-1 |
| app_name / version | `archway` **v10.1.0** |
| git_commit | `f56aca02c0b26131b08e6edb2df8d7f492e4246d` |
| cosmos_sdk_version | v0.50.10 |
| build_deps: wasmd | `github.com/CosmWasm/wasmd v0.51.0` (replaced in-tree by `archway-network/archway-wasmd v0.50.2-archway`) |
| build_deps: **wasmvm** | **`github.com/CosmWasm/wasmvm v1.5.5`** sum `h1:XlZI3xO5iUhiBqMiyzsrWEfUtk5gcBMNYIdHnsTB+NI=` |
| build_deps: ibc-go | `github.com/cosmos/ibc-go/v8 v8.7.0` |
| build_deps: cometbft | v0.38.17 |

Multiple independent nodes report the same network/cometbft; the app version above is
self-reported per node (build_deps is compiled into the binary).

## 2. Cryptographic hash confirmation

- `sum.golang.org/lookup/github.com/!cosm!wasm/wasmvm@v1.5.5` →
  `github.com/CosmWasm/wasmvm v1.5.5 h1:XlZI3xO5iUhiBqMiyzsrWEfUtk5gcBMNYIdHnsTB+NI=`
  — **byte-identical to the live node's build_deps sum**. The running binary was built
  against the genuine upstream wasmvm v1.5.5 module, not a fork.
- Go module zip `proxy.golang.org/.../v1.5.5.zip` sha256
  `669a4752ff88402db67985ef95f8b2e63185a4d4d673df6d4b514d6eae71909e` (inspected by
  `ci/wasmvm_poc.sh`; contains the prebuilt `libwasmvm.x86_64.so`, 11,459,088 bytes).

## 3. The deployed artifact's Rust pins (from the hash-matched module zip)

| artifact | wasmvm v1.5.5 (deployed) | wasmvm v1.5.8 (patched floor) |
|---|---|---|
| tag time (Go proxy `.info`) | 2024-09-23 | 2025-02-04 |
| cosmwasm-vm pin | **v1.5.8** (lacks gas-metering fix, see §4) | v1.5.10 (fixed) |
| Wasmer | **4.2.2** | 4.2.2 (still; Wasmer 7 only in 2.2.9/2.3.5/3.0.8, Sep 2026) |
| `libwasmvm/src/memory.rs` empty-slice null fix (CWA-2025-001) | **absent** (`ptr: data.as_ptr()`) | present (`if data.is_empty() { null }`) |

cosmwasm-vm v1.5.8 source check: `read_region_small_cost`/`charge_host_call_gas` = 0 hits;
cosmwasm-vm v1.5.10 = 3 hits. So the deployed VM lacks the CWA-2025-002 host-call/memory
gas charges.

## 4. Archway's own release history (no fix shipped)

- Latest release: **v10.1.1-tachyon-security-patch (2026-01-20)** — CometBFT-only patch,
  `go.mod` still pins `github.com/CosmWasm/wasmvm v1.5.5`.
- v10.1.0 (2025-03-17) `go.mod`: `wasmvm v1.5.5`, `wasmd v0.51.0`, `ibc-go v8.7.0`
  (`analysis/archway_releases.json`; repo `archway-network/archway`).
- Last commit on `main`: 2025-03-19. No released Archway binary fixes any of
  CWA-2025-001/002/007, CWA-2026-003/005/006.

## 5. Wasm module configuration (live)

`GET /cosmwasm/wasm/v1/codes/params` (h 17,644,198 and re-checked h 17,644,323):

```json
{"params":{"code_upload_access":{"permission":"Everybody","addresses":[]},
           "instantiate_default_permission":"Everybody"}}
```

- 889 stored codes by 91 distinct creator addresses (code 889 uploaded recently by a
  fresh address) — permissionless upload is actively used, not just configured.
- 6,644 contract instances enumerated (all codes → contracts → contract_info).

## 6. Chain activity

Latest block at measurement: 17,644,323, time 2026-10-05T16:03:52Z — chain live and
producing blocks. No upgrade plan pending (`/cosmos/upgrade/v1beta1/current_plan` = null).
No emergency governance proposal after the 2026-09-28 CWA-2026-006 disclosure (latest
proposal #60, 2026-01-17).

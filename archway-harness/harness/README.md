# archway-harness — local execution lab (wasmvm v1.5.5 / Wasmer 4.2.2)

Executes CosmWasm contracts against the **exact engine Archway mainnet runs**, in-process,
with no chain interaction. This is the Cosmos equivalent of a fork test: store → instantiate
→ execute, gas-metered, deterministic.

## Proven working (2026-10-06)

```
$ ./harness -wasm contracts/minimal/target/wasm32-unknown-unknown/release/minimal.wasm \
    -init '{"seed":42}' -exec '{"loop":{"n":100000}}' -repeat 3
StoreCode OK (checksum 4fdd1a71…)
instantiate gas 11,726,550,089
3x execute gas 368,285,890,072 each — identical output across runs
```

Also validated against wasmvm's own `testdata/hackatom.wasm` (contract executed; parse error
returned correctly).

## Build

```bash
# 1. Go harness (links the prebuilt libwasmvm.x86_64.so from the wasmvm v1.5.5 Go module)
go build -o harness .

# 2. Test contract — IMPORTANT: CosmWasm 1.x requires a Rust toolchain predating the
#    bulk-memory default (Rust >= 1.82 emits memory.copy which the wasmvm 1.x gatekeeper
#    rejects). We use 1.81.0:
rustup toolchain install 1.81.0 --profile minimal
rustup target add wasm32-unknown-unknown --toolchain 1.81.0
cd contracts/minimal
cargo +1.81.0 build --release --target wasm32-unknown-unknown
```

## Usage

```bash
./harness -wasm contract.wasm \
  [-init '{"…"}'] [-exec '{"…"}'] \
  [-repeat N] [-gas N] [-memory-mb 32] \
  [-capabilities "iterator,staking,stargate,cosmwasm_1_1,cosmwasm_1_2,cosmwasm_1_3,cosmwasm_1_4"] \
  [-print-debug] [-out report.json]
```

- `-gas` is in **wasmvm gas units**; wasmvm's own tests use `500_000_000_000` (5e11). A trivial
  instantiate costs ~1.2e10, an empty execute ~3.7e11.
- Exit codes: `0` ok; `1` contract/VM error (JSON report still written); **`139` (SIGSEGV) /
  `134` (SIGABRT) = the VM/contract crashed the process** — this is how we detect crash-class
  triggers (CWA-2025-001 style) and must be caught by the CI wrapper, not the harness itself.

## Engine details (exact chain match)

| Component | Version | Source |
|---|---|---|
| wasmvm (Go module) | **v1.5.5** | `go.mod` — hash-matched to the live node `build_deps` |
| libwasmvm | v1.5.5 prebuilt `libwasmvm.x86_64.so` | shipped inside the Go module |
| cosmwasm-vm | v1.5.8 | pinned by wasmvm 1.5.5 |
| Wasmer | **4.2.2** (Singlepass) | pinned by wasmvm 1.5.5 |

## Notes

- The mock KVStore/gas/querier/GoAPI implementations live in `main.go`; they match the
  interfaces wasmvm expects and are sufficient for contract-behavior testing.
- For differential testing against the **patched** engine (wasmvm 3.0.8 / Wasmer 7.4.2), use a
  separate binary built from a different module path (`github.com/CosmWasm/wasmvm/v3`), then
  diff outputs for the same contract/inputs.
- No network calls, no keys, no chain interaction — pure local execution.

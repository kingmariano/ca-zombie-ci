# archway-wasmer-lab — CWA-2026-006 differential campaign (CI)

Wasmer-level labs for the CWA-2026-006 trigger hunt, built and run **only on GitHub Actions**.

## Labs

| Crate | Engine | Role |
|---|---|---|
| `lab-422-sp` | Wasmer **4.2.2** Singlepass | **chain-exact target** (wasmvm 1.5.5) |
| `lab-742-sp` | Wasmer **7.4.2** Singlepass | patched reference |
| `lab-742-cl` | Wasmer **7.4.2** Cranelift | semantic oracle |

## Tests

1. **R1 patterns** (`patterns` mode) — static linear-memory guard probe with sentinel mmaps at
   base+{6,7,8,9,10} GiB (Wasmer #6879 / internal#5).
   *Prior result (local, non-CI): Singlepass 4.2.2/4.3.7 trap on all targets (32-bit add +
   carry trap); Cranelift 4.3.7 escapes at +6/+7 GiB.*
2. **P1 drift probe** (`drift <wat> <iters>`) — Hexens "WASMageddon" shape: result-bearing
   `if/else` spilled to memory inside a loop + host-import call. The host import reads native
   `rsp`; a downward drift per iteration (expected ~16 bytes) proves the
   `release_locations_value()` `adjust_stack` bug (Wasmer >=2.1.0 <7.0.0; present in 4.2.2).

## Outputs

`ci-out/patterns-*.txt`, `ci-out/drift-*.jsonl`, `ci-out/wasmer_campaign.log`.
Artifact name: `result-archway-wasmer-lab`.

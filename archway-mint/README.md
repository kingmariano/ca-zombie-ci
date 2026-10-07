# archway-mint — E8: archwayd Go-ABI mint-path target analysis

**Purpose.** Convert "control-flow hijack in the archwayd process" (E1–E6 proven) into
"a call that mints (or otherwise moves value)" — the M3 milestone of the CWA-2026-006
campaign. This folder is the dedicated, fast-iteration CI job for that analysis
(no Rust builds): static work on the exact mainnet binary `archwayd_linux_amd64`
v10.1.0 (non-PIE `ET_EXEC`, entry `0x44f889`, stripped).

**Runs on:** GitHub Actions via `poc.yml` with `finding=archway-mint`
(`ci/run.sh` → `e8/run_campaign.sh`). All outputs under `ci-out/`.

## Outputs (artifact `result-archway-mint`)

| File | What |
|---|---|
| `archwayd_functions.txt` | full function inventory from `.gopclntab` (`entry_hex \t name`) |
| `e8_mint_candidates.txt` | x/bank keeper methods: MintCoins / SendCoins / BurnCoins / AddCoins / InputOutputCoins / SetBalance / *FromModule* |
| `e8_bank_all.txt` | all bank package / keeper functions for context |
| `e8_xmint.txt` | x/mint package (BeginBlocker, keeper) |
| `e8_wasmd.txt` | x/wasm keeper functions |
| `e8_ctx.txt` | sdk.Context construction / KVStore access helpers |
| `e8_runtime.txt` | runtime stack machinery (morestack/newstack/growstack) |
| `e8_msgserver.txt` | MsgServer methods (tx entry points) |
| `e8_target_disasm.txt` | Go-syntax disassembly of the top mint targets |
| `e8_xrefs.txt` | direct call sites (addresses) reaching the mint targets |
| `e8_gadgets.txt` | categorised ROP/JOP gadgets: rsp pivots (strong/arith), indirect branches, write primitives |

## Tools

- `e8/pclntab_dump/` — tiny Go tool: parses `.gopclntab` with `debug/gosym` and prints
  every function (validated locally on stripped + static binaries).
- `e8/xref_scan.py` — maps direct `call`/`jmp` operands in the GNU objdump dump to the
  pclntab function table, per target.
- `e8/gadget_scan.py` — categorised gadget scanner over the GNU objdump dump.

## Next (post-artifact analysis)

1. Pick the mint target with the cheapest argument staging (prefer short frames, no
   `morestack`, arguments reachable from the hijack register set).
2. Map the plan to the E6c gadget catalog (first-stage pivot is a compile-time constant:
   archwayd is non-PIE).
3. Feed the E7 leak (holder spill-slot host pointers) into the stage-2 chain layout.
4. Prove the call on a local archwayd (dev genesis) on CI before any mainnet step.

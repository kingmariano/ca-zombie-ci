# poc/

No Foundry/EVM PoC: C2-49 is Starknet/Cairo. All proofs are read-only Starknet
RPC simulations and historical trace replays:

- `../analysis/ci_starknet_proofs.py` — P1 state, P2 M1 withdraw sim (OK),
  P3 M2 withdraw sim (revert), P4 solver withdraw sim (OK), P5 caller-0 gate
  probes, P6 cross-market collect_order traces, P7 external-surface counts.
- `../analysis/sim_withdraw_M1_top.json` — saved M1 withdraw simulation trace.
- `../analysis/sim_withdraw_M2_last.json` — saved M2 withdraw revert trace.
- `../analysis/events_*.json` — event scans (deposits/withdraws/orders).

Run in CI via `bash ci/run.sh` (see `../ci/run.sh`), results in `../ci-out/`.

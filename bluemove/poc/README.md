# PoC note

BlueMove is a **Sui Move** protocol — Foundry/EVM tooling does not apply. The proof-of-concept here is a
set of **read-only `simulateTransaction` dry-runs** executed against live Sui mainnet state:

- harness + 8 deterministic cases: `../ci/sim_poc.py` (writes `../ci-out/sim/`)
- raw request/response pairs: `../ci-out/sim/*.request.json`, `*.response.json`
- summary: `../ci-out/sim/sim_results.json` (s1–s4/s6 revert with the exact abort codes; s5/s7/s8 succeed)
- deep-dive harness with 38 evidence files: `../analysis/children/sim-poc/`

No transactions were signed or sent anywhere; nothing in this folder executes on a chain.

# C2-25 — Simulation evidence (live mainnet, read-only)

All runs are `simulateTransaction` with `sigVerify=false` + `replaceRecentBlockhash=true`.
**No transaction was signed or sent.** Keyless public RPC (`solana-rpc.publicnode.com`,
fallback `api.mainnet-beta.solana.com`). Fee payer accounts are only used as simulation payers
(`Eknz…` is the market owner; `Gwqwy…` is the program upgrade authority) — no keys involved.

Harness: `ci/run_sims.py` (solders). Each case executes two instructions in one transaction:

1. `RefreshReserve` (tag 3) for the target reserve → makes it non-stale (proves oracles are live).
2. `SetConfig` (tag 14) payload `0e 01 00×200` (ConfigType variant 1 = reserve config, all-zero
   values) with accounts `[market, owner, reserve, clock, rent, token program, pyth program,
   larix oracle program, larix oracle id]`.

Because the payload is all-zero, a run that passes all authorization gates must stop later at
config-value/oracle validation — that is the **"passed the gates"** signal. A run that fails at a
gate stops earlier with a gate-specific error.

## Results (slot ≈ 454,765,700; 2026-10-09)

| case | program | reserve | market passed | owner signer | err | meaning |
|---|---|---|---|---|---|---|
| `main-baseline` | main | `GaX5diaQ…` (mSOL, $900k avail) | own market `5geyZJd…` | yes | `Custom 42` | passed all gates; stops at oracle-config validation |
| `aux-baseline` | aux | `6P4bZnbS…` (USDC, $92.5k avail) | own market `5enDUZdp…` | yes | `Custom 42` | passed all gates |
| `aux-mismatch-market` | aux | `6P4bZnbS…` | **different** market `5abm8Nyi…` | yes | `Custom 5` | **REJECTED: reserve↔market check** |
| `aux-owner-not-signer` | aux | `6P4bZnbS…` | own market | **no** | `Custom 12` | **REJECTED: owner must sign** |

Raw logs (from `ci-out/local-run.log`):

```
===== main-baseline =====
err: {"InstructionError": [1, {"Custom": 42}]}
Program log: Instruction: Refresh Reserve
Program log: Instruction: Set Config
Program log: The larix oracle price account provided is not match the larix oracle program in lending market
Program log: Input oracle config is invalid

===== aux-baseline =====
err: {"InstructionError": [1, {"Custom": 42}]}
Program log: Instruction: Refresh Reserve
Program log: Instruction: Set Config
Program log: The larix oracle price account provided is not match the larix oracle program in lending market
Program log: Input oracle config is invalid

===== aux-mismatch-market =====
err: {"InstructionError": [1, {"Custom": 5}]}
Program log: Instruction: Refresh Reserve
Program log: Instruction: Set Config
Program log: Reserve provided is not owned by the lending program
Program log: Input account owner is not the program address

===== aux-owner-not-signer =====
err: {"InstructionError": [1, {"Custom": 12}]}
Program log: Instruction: Refresh Reserve
Program log: Instruction: Set Config
Program log: Lending market owner provided must be a signer
Program log: Input account must be a signer
```

## Additional controls run during the investigation

- `SetConfig` with data `[14]` only → `"Failed to unpack instruction data"` (payload required).
- `SetConfig` with `0e 00 …` (market-config variant) and zeroed fields →
  `"New owner provided is not owned by the system program"` + `"Market config err"` (custom 45) —
  market-level path is owner-gated too.
- Swap experiments in **both directions** on aux (reserve of market A + market B and vice-versa,
  same owner, same program) → both fail with `Custom 5`. Baselines with the reserve's own market
  pass. The only input changing pass/fail is the market account.
- Owner-not-signer control was validated against a *neutral fee payer* (`Gwqwy…`), because a fee
  payer is always a transaction signer. With a neutral payer the same call fails with
  `"Lending market owner provided must be a signer"` (custom 12).
- `RefreshReserve` succeeds today for the main mSOL reserve and the aux USDC reserve → the oracle
  feeds needed by the path are live (the gate is the check, not a dead oracle).

## Reproduction

```
python3 ci/run_sims.py ci-out     # writes ci-out/sim-results.json + prints logs
```

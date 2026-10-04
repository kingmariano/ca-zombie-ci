# GHSA-7g4w-cg88-2cq2 defect analysis for KiiChain

## The exploit chain (Cosmos Labs post-mortem + KiiChain incident report)

1. Attacker precomputes the CREATE address of a future helper contract.
2. Attacker sends `MsgCreateVestingAccount` (permissionless) creating a
   **delayed-vesting account at that exact address**, funded with 2 KII.
3. Attacker deploys helper bytecode to the same address (EVM `CREATE` succeeds
   because the account has no code/nonce). The address is now simultaneously a
   Cosmos vesting account and an EVM contract.
4. Helper calls the **staking precompile** `delegate(address,string,uint256)`
   at `0x0000000000000000000000000000000000000800` with amount **2 KII + 1 wei**
   from `address(this)`. The Cosmos EVM `StateDB` only mirrors the account's
   *spendable* balance (0); the staking keeper delegates the *locked* balance.
   The post-delegation write-back subtracts the full amount from the spendable
   view → **unchecked underflow to ≈2²⁵⁶**.
5. Helper sends `2²⁵⁶ − victim_balance` to a victim with a large balance →
   **overflow nets the victim's balance to the attacker** (supply-neutral).
6. Sweep to the attacker EOA, bridge out via Hyperlane.

## The three defect classes and their live status on KiiChain

| # | Defect | Upstream cosmos/evm | KiiChain live v7.4.2 | Live evidence |
|---|---|---|---|---|
| 1 | `StateDB.SubBalance` underflow on vesting post-delegation write-back | fixed in v0.6.2 / v0.7.2 (#1176) | **fixed** — fork v0.6.2-fork.2 includes the panic guard | `eth_call` delegate(1 wei) from the one non-blocklisted vesting account returns `rpc error: code = Internal desc = state balance underflow for 0x8Cdab0fa359AC467…` |
| 2 | Unchecked `StateDB.AddBalance` overflow (victim-balance wrap) | **not patched in v0.6.2/v0.7.2** (per advisory, only the underflow was patched) | **fixed** — KiiChain fork commit `27fe1aa3b0` (2026-08-24) adds `AddOverflow` panic | `state balance overflow for %s` present in the live binary; public fork source + unit test `TestAddBalanceOverflowPanics` |
| 3 | EVM contract deployment on a non-base (vesting) account — the setup enabler | **not patched upstream** (KiiChain statement) | **fixed** — KiiChain fork commit `8f31a33939` (2026-08-24) adds `IsBaseAccountOrEmpty` panic in `CreateAccount`; **plus** ante decorator rejects all vesting-account creation; **plus** incident-address blocklist | `cannot deploy EVM contract on top of non-base account %s`, `vesting account creation is disabled`, `address is blocked: …` all observed live |

KiiChain's public statement ("two of the three defects are still unfixed
upstream at Cosmos Labs") is true **for upstream** — but the live KiiChain
chain does not run upstream `cosmos/evm`; it runs `KiiChain/evm-private
v0.6.2-fork.2`, which contains all three guards. The corpus implication that
KiiChain remains exposed is therefore **incorrect for the live chain**.

## Live probes (2026-10-04, blocks ~10,665,4xx–10,665,6xx)

Method: `eth_call` (read-only simulation, no tx) to the staking precompile with
`delegate(delegator, validator, 1 wei)` from each of the 22 incident addresses
(`kiivaloper1p98dndmkjwx8tc87f85cceae5jxq5rztecy5wp`).

Result over the 22 addresses (`analysis/raw/live_probes.json`):

- **18 × `execution reverted: address is blocked: <bech32>: unauthorized`**
  (incident bank-send restriction; `app/blockedaddrs/restriction.go`).
- **1 × underflow guard panic**: `0x8cdab0fa359ac467c80c19de3fee5a543e258365`
  (= `kii13ndtp734ntzx0jqvr80rlmj62slztqm9agzwce`, the one exploit vesting
  account that still holds 2 KII locked and was *not* swept) — the exact
  primitive is intercepted by the patch:
  `rpc error: code = Internal desc = state balance underflow for 0x8Cdab0fa359AC467C80C19dE3fee5a543E258365`.
- **3 × insufficient funds** (2 attacker EOAs + 1 base-account helper, all with
  0 spendable).
- All 22 EVM balances = 0; the 19 helper addresses still have contract code
  (deployed, drained, owner-gated); replay of the original sweep call
  `0x01681a62(attacker)` returns success but moves 0.

The 19 delayed-vesting accounts were all created on 2026-08-22 between
20:31 and 22:32 UTC (`end_time` − 365 d), each with `original_vesting` = 2 KII;
18 show the exploit signature `delegated_free = 1 wei, delegated_vesting = 2 KII`.
They are listed in `analysis/raw/vesting_accounts.json` / `vesting_evm.json`.

## Residual attack surface for the GHSA vector

An unprivileged attacker today cannot:

- create a vesting account (ante rejects `MsgCreateVestingAccount`,
  `MsgCreatePeriodicVestingAccount`, `MsgCreatePermanentLockedAccount`, incl.
  nested in `authz.MsgExec`);
- deploy a contract onto a non-base account (`CreateAccount` panics);
- trigger the delegation underflow (guard panics; blocklist reverts first on
  the 18 drained accounts);
- overflow any balance (`AddBalance` panics);
- move the incident addresses' funds (bank-send restriction on both `from` and
  `to`; all spendable balances already swept to zero).

No EVM-level PoC can reproduce the defect in an anvil fork because the bug is in
the Cosmos node's Go code (StateDB + staking precompile), not in contract
bytecode. The reproduction is therefore (a) the live `eth_call` guard panic and
blocklist reverts above, and (b) the fork's own unit tests executed in CI
(`ci/run.sh` clones `KiiChain/evm v0.6.2-fork.2` and runs
`TestSubBalanceUnderflowPanics` + `TestAddBalanceOverflowPanics`).

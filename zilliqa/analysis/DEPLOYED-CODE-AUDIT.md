# C2-58 — Deployed SSNList code audit (on-chain ground truth)

The **deployed** SSNList implementation (`0xa7c67d49c82c7dc1b73d231640b2e4d0661d37c1`)
is a **newer revision** than the `Zilliqa/staking-contract` GitHub master (it includes
delegator-swap, commission, migration and pause features). The deployed Scilla source is
readable directly from chain: `eth_getCode` returns 65,230 bytes of Scilla source
(`scilla_version 0 … library SSNList`), saved verbatim as `onchain_ssnlist_scilla.txt`
(this is the ground truth audited below; the GitHub file is lineage only).

## Guard architecture (deployed)

* `IsProxy()` — `is_proxy = builtin eq _sender init_proxy_address` — **every one of the 56
  transitions is IsProxy-gated**: 47 call `IsProxy` directly; the 9 `Migrate*` transitions
  call `ValidateMigration`, which itself expands to `IsPaused; IsProxy; IsAdmin initiator`.
  The implementation can only ever be driven by the SSNListProxy; a direct EVM→precompile
  call can never satisfy it.
* `IsAdmin(initiator)` — `initiator == contractadmin` (the 2-of-5 multisig).
* `CallerIsVerifier(initiator)` — `initiator == verifier`.
* `IsNotPaused` / `IsPaused` — `paused` flag (live: **false**).
* `DelegExists(ssnaddr, deleg)` — `exists deposit_amt_deleg[deleg][ssnaddr]`.

The proxy always relays with `initiator := _sender`, so `initiator` is the real caller.

## Value-moving transitions (audit result)

| Transition | Guards | Scope / bound |
|---|---|---|
| `WithdrawStakeRewards(ssnaddr, initiator)` | IsNotPaused, IsProxy, DelegExists(ssnaddr, initiator) | pays the caller's own accrued delegator rewards (`SendDelegRewards initiator reward`) |
| `WithdrawStakeAmt(ssnaddr, amt, initiator)` | IsNotPaused, IsProxy | `WithdrawalStakeAmt initiator ssnaddr amt` reads `deposit_amt_deleg[initiator][ssnaddr]`; `AdjustDeleg` requires `amt <= own delegation`; enqueues the caller's own `withdrawal_pending[initiator]` |
| `CompleteWithdrawal(initiator)` | IsNotPaused, IsProxy | releases only the caller's own pending withdrawals after `bnum_req` |
| `WithdrawComm(initiator)` | IsNotPaused, IsProxy | pays `comm_rewards` of `ssnlist[initiator]` to that SSN's own `rec_addr`; non-SSN callers revert `SSNNotExist` |
| `ReDelegateStake(ssnaddr, to_ssn, amount, initiator)` | IsNotPaused, IsProxy | moves the caller's own delegation between SSNs |
| `RequestDelegatorSwap` / `ConfirmDelegatorSwap` / `RejectDelegatorSwap` / `RevokeDelegatorSwap` | IsNotPaused, IsProxy (+ `IsValidSwapAddr`) | request stored under the caller; `Confirm`/`Reject` require `deleg_swap_request[requestor] == initiator` (only the designated new address can complete); no self/cyclic swaps |
| `AssignStakeReward(list, initiator)` | IsNotPaused, IsProxy, CallerIsVerifier | reward amounts are scaled from `totalstakeamount`; `UpdateStakeReward` enforces `AssertCorrectRewards` (cumulative SSN rewards ≤ the ZIL the verifier **attaches** to the call); leftovers go to the verifier's receiving addr — **the verifier cannot mint rewards from staker principal** |
| `DrainContractBalance(amt, initiator)` | **IsPaused**, IsProxy, IsAdmin(initiator) | the emergency exit; requires the contract to be paused AND the 2-of-5 admin |
| `DelegateStake`, `AddFunds` | IsNotPaused/IsProxy | inbound only (adds stake) |
| `Pause` / `UnPause` / `UpdateAdmin` / `UpdateVerifier` / `Update*` / `AddSSN` / `Clean*` / `Populate*` / `AddSSNAfterUpgrade` / `UpdateDeleg` / `Migrate*` | IsProxy + IsAdmin (Migrate also requires IsPaused) | admin-only (P) |

## Implications

1. **No unprivileged value path exists even if Scilla calls were reachable**: every
   outflow is either caller-scoped to the caller's own stake/rewards/commission, or
   admin/verifier gated, or inbound. `DrainContractBalance` additionally needs
   `paused == true`.
2. Today the question is moot: Scilla calls are unreachable (legacy txns disabled/rerouted;
   precompile caller allowlist), so even the admin cannot operate the contract.
3. The 2-of-5 multisig is the only address that can `DrainContractBalance` (after pausing);
   the verifier can only redistribute funds it attaches itself.

Reproduce: `python3 analysis/scripts/audit_deployed_ssnlist.py` (regenerates the guard
table from the live `eth_getCode` output; raw table in `deployed_ssnlist_guards.txt`).

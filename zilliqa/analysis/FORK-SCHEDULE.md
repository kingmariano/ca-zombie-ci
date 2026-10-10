# C2-58 — Z2 mainnet fork schedule (chain spec + live timestamps)

Source: `Zilliqa/zq2` → `z2/resources/chain-specs/zq2-mainnet.toml` (copy in this folder),
fork entries cross-checked against live block timestamps via `eth_getBlockByNumber`.
Current head at verification: block **37,772,614** (2026-10-10 ~04:25 UTC).

| Height | Live UTC | Fork / flag | Effect |
|---|---|---|---|
| 4,770,088 | 2025-06-23 | migration boundary | Z1→Z2 state import (legacy history archive) |
| 4,957,200 | 2025-06-29 | `scilla_call_gas_exempt_addrs` | first interop allowlist (gas-exempt) |
| 27,152,370 | — | `disable_interop_native_zil_transfers_0`, journal-API transfers | value-carrying scilla_call calls disabled |
| 27,546,174 | 2026-05-26 | `tighten_precompile_rules` | static-call + calldata tightening |
| **29,108,584** | **2026-06-16 11:21** | **`allow_scilla_call_precompile_to_be_called_from_addresses` (100 contracts)** | **only these 100 callers may invoke `scilla_call`; all others fail the tx** |
| **31,759,109** | **2026-07-20 16:37** | **`disable_zilliqa_txn_execution = true`** | **all legacy Zilliqa (Scilla) transactions rejected** |
| 34,844,968 | 2026-09-02 15:43 | `blocked_recipients_001.bin` (1,460,781 addresses, 14 regions) | protocol-level sweep of listed accounts (balance → region destination, nonce → u64::MAX) |
| 36,383,378 | 2026-09-22 08:15 | `deploy_escrow_contract_v1`, `blocked_recipients_002.bin` (508,861 addresses, 16 regions) | claim-vault deployment + sweep #2 |
| **36,383,379** | **2026-09-22 08:15** | **`zil_transfers_only_to_escrow = true`** | **legacy txns rerouted to the escrow (LODGE or plain transfer to escrow only)** |
| 37,410,000 | 2026-10-05 13:12 | `blocked_recipients_003.bin` (100,831 addresses, 4 regions) | sweep #3 |
| 99,999,999 | future (~2028) | `disable_permanently_scilla_precompiles = true` | scheduled permanent disable of Scilla precompiles |

Implications for C2-58:

* The **legacy staking contracts are unreachable**: legacy txns cannot call Scilla
  contracts (routed to escrow), and the only EVM route (`scilla_call` precompile) is
  restricted to 100 allow-listed contracts (verified: random caller reverts).
* The **allowlist** (2026-06-16) predates the incident hard fork (2026-07-20); it was part
  of the Z2 transition hardening.
* The **sweep lists** (2,070,473 addresses total) do **not** contain the staking
  contracts, the multisig, the verifier, the deposit proxy, or the escrow — their live
  balances are intact (see `analysis/BLOCKED-RECIPIENTS-SCAN.md`).
* The **escrow + ZK claim vault** is the live recovery path (deployed 2026-09-22); staking
  positions are not yet covered by it (the Zilliqa post-mortem says staked funds "will need
  the recovery path once that is ready").

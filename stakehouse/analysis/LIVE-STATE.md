# Stakehouse live-state evidence (block 26,178,656 / reads 2026-10-12)

All values read-only via archive RPC (`eth_call`, `eth_getBalance`, `eth_getStorageAt`, logs) and the beacon-chain API.
Raw files: `live_balances_1.json`, `impl_map.json`, `accounts_raw.json`, `accounts_state.json`, `knots_summary.json`,
`validator_indices.json`, `fullsweep_reported.json`, `am_balance_history.json`, `am_outflows.json`, `am_all_logs.jsonl` (in /tmp during work; key extracts below).

## 1. Custody snapshot (ETH balances, block 26,178,656)

| Contract | Address | ETH |
|---|---|---|
| **AccountManager** (proxy) | 0xDd6E67942a9566A70446f7400a21240C5f71377C | **64.305717944108928421** |
| StakeHouseUniverse | 0xC6306C52ea0405D3630249f202751aE3043056bd | 0 |
| TransactionRouter | 0x03F4310bfE3968934bC11DfA17B8DF809D7DEA80 | 0 |
| SLOTRegistry | 0xC01DC3c7F83B12CFdF6C0AAa09c880EB45c48569 | 0 |
| savETHRegistry | 0x88E6c7072B867F9546a232548a5D3271986B3C0c | 0 |
| savETHTransactionRouter | 0x9CbC2Bf747510731eE3A38bf209a299261038369 | 0 |
| savETHBatchRouter | 0x1D1f35aA28Ac454DA4b11b89971F5F8E6B207d37 | 0 |
| ShanghaiSweepReporting | 0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0 | 0 |
| FullWithdrawals | 0x8F6839b0AcD8d7c7d2f01C1C7ECCa982Ca354333 | 0 |
| dETH / savETH tokens | 0x3d1E5Cf16077F349e999d6b21A4f646e83Cd90c5 / 0x00ee7ea7ca2b5cc47908f0cad1f296efbde1402e | 0 (supply 16.887594 / 4.910564) |

## 2. Proxies & implementations (EIP-1967 slot 0x3608…bbc)

| Proxy | Impl | Verified? |
|---|---|---|
| AccountManager 0xDd6E… | 0x9227cb6d3388c7247f4726cbbb9c6f1f1def1504 (upgraded block 18,191,957, 2023-09-22) | no |
| TransactionRouter 0x03F4… | 0x6930f6c44a3c505c80bd07e81d157476b648258c | no |
| ShanghaiSweepReporting 0x64f4… | 0xdf39face16519376e47bba3b9be15e69d8a66f2c | no |
| FullWithdrawals 0x8F68… | 0xb4d61d73d4f66ad07132fd71b073ba67f67db149 | no |
| StakeHouseUniverse 0xC630… | 0xbcb6f4effb9eb8ed31453cc8bdae9703c6d1ff9b | yes (bundles AccountManager stub) |
| SLOTRegistry 0xC01D… | 0xe950159ccdf36f6dc661dec0e0de75113455bf63 | yes (SlotSettlementRegistry) |
| dETH 0x3d1E… | 0xf51fc5ae556f5b8c6dcf50f70167b81ceb02a2b2 | yes |

## 3. Roles / access control

- Core modules (StakeHouseAccessControls 0xba86e2917a98c4d6bcb171516252348f1e06fffd; 9 grants, 0 revocations):
  Universe, AccountManager, TransactionRouter, SLOTRegistry, savETHRegistry, savETHTransactionRouter, savETHBatchRouter,
  ShanghaiSweepReporting (block 18,192,233), FullWithdrawals (block 18,192,233).
- AccountManager `withdrawETH`/`rageQuitKnot`/`markKnotAsWithdrawn`/`setLifecycleExited`/`updateAccountState`/`update*FromReport`/`registerValidatorInitials`
  → all revert `"Only core"` for an attacker (bytecode modifier at 0x21ac; fork + eth_call proven).
- PROXY_ADMIN_ROLE: moved 0xac49e8d5… → **0x8869a94df9200c75116a285e12e85c24179129e1** at block 19,561,695.
- Designated verifier (both withdrawal contracts): **0x9785f8e50229ebd2b3788452abc31d1942394e0c** (enabled blocks 18,191,314 / 18,191,317).
  EOA (code 0), **nonce 0** — off-chain signer only.

## 4. Knot census (85 accounts; keys from `InitialsRegistered` events; pairing confirmed via `blsPubKeyToAccountArrayIndex`)

| Lifecycle | Count | Notes |
|---|---|---|
| 5 UNSTAKED | 48 | all fully claimed (48 `FullWithdrawalExecuted`, 1,557.451161 ETH) |
| 1 INITIALS_REGISTERED | 35 | never deposited; totalSent = 0 |
| 3 TOKENS_MINTED | **1 (knot 44)** | validator 747,994 exited; 31.086158519 ETH unclaimed |
| 4 EXITED | **1 (knot 78)** | validator 1,109,420 exited; 32.005324832 ETH unclaimed; enabled=1, withdrawn=0 |

## 5. The two orphaned full sweeps

| | knot 78 | knot 44 |
|---|---|---|
| BLS key | 0x97d7b76d…07e7 | 0x8f691a27…b9ad |
| Validator index | 1,109,420 | 747,994 |
| Exit | exit_epoch 301,323; withdrawn block 20,482,055 (2024-08-08) | exit_epoch 404,478; withdrawn block 23,726,929 (2025-11-04) |
| AM inflow | 32.005324832 ETH | 31.086158519 ETH |
| Beneficiary | EOA 0xddb50ffd… (enabled=1, withdrawn=0) | smart wallet 0x246269f8… (45-byte clone; owner 0x831138ee…; enabled=0) |
| Final sweep reported? | no (isFullSweepReported(idx)=0; no SweepReported after block 20,478,005) | no |
| Claim needs | verifier-signed final report | rage quit **+** verifier-signed final report |

Residual: 64.305717944108928421 − 32.005324832 − 31.086158519 = **1.214234593 ETH** legacy dust (pre-2024 residue).

## 6. History / liveness

- 117 ETH outflows ever (1,573.310748 ETH): 48 full claims (1,557.451161) + 69 partial (15.859586).
- Last `FullWithdrawalExecuted`: block 20,234,472 (2024-07-04). Last `SweepReported`: block 20,478,005 (2024-08-06, for validator 1,109,420 pre-exit).
- Total inflows ever ≈ 1,637.616 ETH (≈49–50 beacon deposits × 32 + 37.6 rewards/top-ups) — reconciles exactly.
- No AccountManager transactions in 2025–2026; the two inflows are system-level beacon withdrawals.

## 7. Gate strings extracted from deployed bytecode (evidence of gating)

- AccountManager: "Only core", "Only depositor", "Only mutable", "Invalid account state", "Status can not decrease", "Sufficient blocks must pass before streaming", "Failed to transfer".
- FullWithdrawals: "Not in the past", "Withdrawal epoch not set", "Active balance", "Effective balance", "Already reported", "Signature expired", "Invalid final sweep", "Key mismatch", "Invalid recipient", "Not rage quit", "Not final sweep", "Final sweep <= 15", "Only manager", "ECDSA: invalid signature", "ReentrancyGuard: reentrant call".
- ShanghaiSweepReporting: "Zero sweeps", "Zero reports", "Inconsistent array lengths", "No data", "Sweep already reported", "Signature expired", "Invalid Report", "Invalid total ETH sent for BLS key", "Invalid sum", "Not rage quit", "Amount minted is too small", "Reported", "Duplicate", "Only manager", "Only core", "No sweeps", "Invalid recipient", "Inconsistent index", "Not first sweep", "Invalid first sweep amount", "Set size is zero", "ECDSA: invalid signature", "ReentrancyGuard: reentrant call".
- TransactionRouter: "Not exiting", "Invalid AES", "Invalid rage quit assistant", "Invalid key from assistant", "Invalid key", "Invalid StakeHouse", "No slashing", "Exit Fee", "Xfer to AM", "Recipient cannot be zero", "Credentials", "Exiting", "ECDSA: invalid signature", "Only mutable".

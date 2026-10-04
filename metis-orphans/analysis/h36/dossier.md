# H-36 Dossier — ERC1967 "Vault" proxy `0x17A30350771d02409046A683b18Fe1C13cCFC4A8`

**Chain:** Metis Andromeda (1088) · **Status:** verified on-chain · **Date:** 2026-10-04
**Pinned block for all state reads:** `23238718` (2026-10-04 05:26:54 UTC, hash `0x…` recorded in `h36_state.json`)
**Latest re-check block:** `23238770` (2026-10-04 05:52:10 UTC) — identical state
**Cross-checked RPCs:** `andromeda.metis.io` (primary) + `metis.drpc.org` (fallback) — identical results
**Read-only:** all checks were `eth_getStorageAt` / `eth_call` simulations / explorer GETs. No transaction was signed or sent.

---

## 1. Verdict (TL;DR)

| Field | Value |
|---|---|
| **Classification** | **E-U — no unprivileged extraction path; $0 hostile-extractable** |
| **Orphan status** | **NOT an orphan** — actively operated KuCoin-linked hot-wallet vault (last payout 2026-08-11) |
| **Funds at risk (unprivileged)** | **$0.00** |
| **Funds held (privileged custody)** | **68,713.855 METIS = 68,713,855,000,000,000,000,000 wei** |
| **USD @ METIS ≈ $10** | **≈ $687,138.55** |
| **Confidence (no unprivileged path)** | **0.97** |
| **Confidence (KuCoin attribution)** | **0.85** |
| **H-O / P / S** | H-O ruled out (live, owner-operated). Privileged-only risk exists (see §8), not an unprivileged path. |

The campaign hypothesis that this vault is abandoned/orphaned is **disproven**: it is a payment vault for a KuCoin-linked operation, controlled by a 3-of-6 Gnosis Safe (PAYER role) plus EOAs, with continuous activity through 2026-08-11 and an exact balance reconciliation of all lifetime flows.

---

## 2. Verified state table (block `23238718`)

| Item | Value | Evidence |
|---|---|---|
| Proxy code | 680 bytes, codehash `0x330b9f1afee9d71fb2ee42927a996a39889a45323883a66a194e210ab850d111` | `h36_state.json` |
| EIP-1967 impl slot `0x360894…2bbc` | `0xd62dEdee92074458B1C31133E6601CB6b87E844B` | `h36_state.json`, re-checked at latest + drpc |
| Impl code | 9,713 bytes, codehash `0xa26c75cbd788e67e36ad8849d3abfa7cc958ca51164fbbe12fefc1dcf99627cb`, verified `Vault`, solc 0.8.9 | `h36_state.json`, `h36_impl.json` |
| EIP-1967 admin slot `0xb53127…6103` | `0x00…00` (no admin / not transparent proxy) | `h36_state.json` |
| EIP-1967 beacon slot `0xa3f0ad…3d50` | `0x00…00` | `h36_state.json` |
| `_initialized` slot `0x00` | **`0x…01`** → `_initialized = 1`, `_initializing = 0` | `h36_state.json` (both RPCs) |
| Owner storage slot `0x97` (151) | `0x…52c904abc83fd537a508f56fc6f3d723ff5403e1` | storage scan `storage_batch_resp.json` |
| `owner()` | `0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1` | `h36_state.json` |
| METIS balance | **68,713.855 METIS** | both RPCs, block `23238718` and `23238770` |
| `proxiableUUID()` via proxy | reverts `UUPSUpgradeable: must not be called through delegatecall` (OZ `notDelegated`, expected) | `h36_state.json` |
| Impl contract itself | slot0 = `0x01` (locked by `constructor() initializer {}`), `owner()` = `0x0` | §5 |
| Upgrade events (all time) | **exactly 1** — `Upgraded(0xd62dEdee…)` at creation block `0xed825c` (15,565,404); **no upgrade ever** | `logs_upgraded.json` |
| `Initialized` event | 1 — same creation tx `0x32821b3e…` (initialize called during deployment) | `logs_initialized.json` |
| Ownership events | 2 — deployer → `0x52c904…` (transferOwnership, block `0xed829c`); deployer init | `logs_ownership.json` |

### Can `initialize()` be re-called?
**No.** Storage slot `0x00` = `0x…01` proves `_initialized = 1`. Live proof (simulation): `initialize()` from an arbitrary caller reverts `Initializable: contract is already initialized`. Same for the implementation contract directly (`impl slot0 = 0x01`). There is no re-initialization path.

---

## 3. Role-holder analysis (block `23238718`)

Role hashes: `PAYER_ROLE = keccak256("PAYER_ROLE") = 0x8ec07e268e32cae7f300b49ad34f20106d088445cb9d9b2d62cbd864638308b2`, `PAYEE_ROLE = 0x95ed160efa56927d40641b26c79df8395a2e4f8f170168fedfa462234b4c3a46`; all three roles have admin `DEFAULT_ADMIN_ROLE` (`0x00`). Raw: `h36_roles.json`, `roles_raw.txt`.

| Role | Holder | Type | Notes |
|---|---|---|---|
| DEFAULT_ADMIN_ROLE (2) | `0xd534b9530425E9F32b7281f4FfCcA97203A182aD` | **EOA** (codesize 0) | also Safe signer |
| | `0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1` | **EOA** (codesize 0) | also owner(), PAYER_ROLE, Safe signer |
| PAYER_ROLE (2) | `0x96ED493C74e23e4FAAd2409e59eD2d4eC8f64E52` | **contract** (124 B) | **Gnosis Safe L2 v1.3.0 proxy**, threshold **3**, 6 owners, **modules []**, guard slot = 0, fallback-handler slot = 0, singleton `0xf66F5d84c6e094b57eFAa3D264f9C38E32fc9CD4`, nonce 16 |
| | `0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1` | **EOA** | single-key PAYER |
| PAYEE_ROLE (3) | `0xD6216fC19DB775Df9774a6E33526131dA7D19a2c` | **EOA** | received 0.01 METIS (2024-03-23) |
| | `0xC519c75cF9DE75311E6797cB3a3c641a01bdB1d5` | **EOA** | main depositor + payout recipient; 60,610 lifetime txs; active 2026-10-04 |
| | `0xE7f7F1e591c198A394335A4905D931457Faf9332` | **EOA** | deposited 0.2 METIS (2024-03-22) |

**Can any role holder be triggered permissionlessly?** No.
- The only contract role-holder is the Safe. Safe execution requires **3-of-6** owner signatures; `getModulesPaginated` = `[]` (no module escape hatch); guard storage slot `keccak256("guard_manager.guard.address")` = 0; fallback-handler storage slot `keccak256("fallback_manager.handler.address")` = 0 (unknown selectors on the Safe simply return empty; no delegatecall path to the Vault). `getOwners`/`getThreshold` verified by raw `eth_call` (`0xa0e67e2b`, `0xe75235b8`).
- All other role holders are EOAs (codesize 0 at the pinned block) — they cannot be called.
- Safe owner set history: initial owners (setup 2024-03-21) `[0x1caEB632…, 0xE8402e0e…, 0x857Dc443…, 0x52c904…, 0xd534b953…, 0xf636bDE8…]`; on 2024-12-27 two `swapOwner` calls replaced `0xE8402e0e…` → `0xad60Ab02…` and `0x857Dc443…` → `0xddFC422f…`. Raw: `bctx_0x34c846a2.json` (setup calldata), `bctx_0x033e0659.json`, `bctx_0x4cfcebfd.json` (swapOwner `0xe318b52b`).

### Role grant history (event logs, complete)
Deployer `0xb1757585…` at block `0xed825c`–`0xed82a3` (2024-03-21): granted DEFAULT_ADMIN to self; PAYER to Safe + `0x52c904`; PAYEE to 3 EOAs; DEFAULT_ADMIN to `0x52c904` + `0xd534b953`; transferred ownership to `0x52c904`; **revoked its own admin**; then tipped `0x52c904` 0.02456 METIS. No role changes since. Raw: `logs_rolegranted.json`, `logs_rolerevoked.json`, `logs_ownership.json`.

---

## 4. Owner `0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1` (task 3)

- **EOA** (codesize 0 at pinned block and now), no public label on Metis Blockscout, no ENS, no web hits.
- Roles: `owner()`, DEFAULT_ADMIN_ROLE, PAYER_ROLE, and one of the 6 signers of the PAYER Safe. Received the deployer's tip.
- **It is not a multisig.** Single-key control of `upgradeTo`/`upgradeToAndCall` and `transferOwnership`. This is a **privileged single point of failure** (key compromise → malicious upgrade → drain), but it is *not* an unprivileged path. `transferOwnership` was verified as onlyOwner (attacker simulation reverts `Ownable: caller is not the owner`).
- "Lure into upgrading": not applicable — requires the private key; classified as privileged (P-adjacent), not an attack vector for this finding.

---

## 5. Implementation contract `0xd62dEdee92074458B1C31133E6601CB6b87E844B`

- Verified source: **`Vault`** (solc 0.8.9) = OZ UUPS + Ownable + AccessControlEnumerable + ERC721Holder. Full source saved at `../h36_impl.sol`; ABI `../h36_impl_abi.json`; explorer JSON `../h36_impl.json`.
- Value-moving entry points **all** require `onlyRole(PAYER_ROLE)`; payee additionally must hold `PAYEE_ROLE` (`_checkRole(PAYEE_ROLE, payee)` before every transfer). `receive()` accepts ETH. `_authorizeUpgrade` = `onlyOwner`. No `selfdestruct`, no arbitrary call/delegatecall, no sweep.
- Deployed **2023-06-29** by `0x720d5253495EBe64D08A6aa41e0d59D5E2eC2D0F`, which is tagged **"KuCoin: Hot Wallet Vault 15"** on Metisscan/routescan (`bs_impdep_txs.json`; web evidence in `h36_identity.json`).
- Locked against initialization by `constructor() initializer {}` (impl slot0 = `0x01`, impl owner = `0x0`); direct calls to the impl revert (`onlyProxy`: "Function must be called through delegatecall"; initialize: "already initialized").
- Complete ABI function list (26 fns, `h36_abi_functions.txt`): roles/gating + `initialize`, `upgradeTo(AndCall)`, `transferEther`/`batchTransferEther`, `transferErc20`/`batchTransferErc20`, `transferErc721`/`batchTransferErc721`, `onERC721Received`, ownable/accesscontrol views. Nothing callable-with-value for an outsider.

---

## 6. Transaction history & purpose (task 4)

Complete lifetime history: **16 external txs, 50 internal-tx rows, 1 token transfer** (`bs_*_transactions.json`, `bs_*_internal-transactions.json`, `h36_flows.json`).

**Deposits (receive()) — 75,173.29 METIS total**
| Date (UTC) | METIS | From |
|---|---|---|
| 2024-03-22 08:55:42 | 0.2 | `0xE7f7F1e5…` (PAYEE EOA) |
| 2024-03-24 01:03:13 | 1,213.18279262018 | `0xC519c75c…` |
| 2024-03-24 12:03:12 | 229.435800685172 | `0xC519c75c…` |
| 2024-03-29 10:08:21 | 19,740.921208712498 | `0xC519c75c…` |
| 2025-11-28 11:01:24 | 3,989.55019798215 | `0xC519c75c…` |
| 2026-02-10 00:23:28 | 50,000 | `0xC519c75c…` |

**Payouts — 6,459.435 METIS total** (all `transferEther`; 14 of 15 executed through the 3-of-6 Safe `execTransaction`, 1 direct by the owner EOA): 0.1 (2024-03-22) · 0.01→`0xD6216fC1` (2024-03-23, owner EOA) · 1,440 (2024-03-26) · 0.1 · 0.1 · 1 · 10 (2024-12-27) · 2 · 0.1 · **5,000 (2025-08-24)** · 2.025 · 1 · 1 · 1 · 1 (2026-08-11) — every one after 2024-03-23 to `0xC519c75c…`.

**Reconciliation (exact):** 75,173.29 − 6,459.435 = **68,713.855 METIS** = on-chain balance. ✅
**Purpose:** hot-wallet/payment vault: one counterparty (`0xC519c75c…`, a 60k-tx operational wallet that transacts with KuCoin-labeled hot wallets) funds the vault and receives most payouts; occasional dust/invoice-size payouts; 5,000/1,440 METIS rebalances. **Last activity 2026-08-11 11:12:58 UTC.**
**Other assets:** only 185 units of a valueless spam token `0x2a8307eA…` ("Metis", symbol "Claim on: airdrop-metis.com", 224,962 holders) airdropped 2024-06-17 from `0xDeadDeAd…deAD0000`; **no NFTs/ERC-1155**; no other ERC-20. Even the spam token can only move via PAYER+PAYEE roles.

---

## 7. Identity / project (task 6)

**KuCoin hot-wallet vault infrastructure** (confidence 0.85):
- The Vault implementation deployer `0x720d5253…` is tagged **"KuCoin: Hot Wallet Vault 15"** on Metisscan/routescan.
- The Vault address `0x17A3…C4A8` is in hildobby's CEX list as **KuCoin** ("KuCoin 29/40") and is listed in **KuCoin's Proof-of-Reserves report** on Avalanche C-Chain.
- On Avalanche, `0x17A3…` is an ERC1967Proxy with implementation `0x78ca07D0…` = verified **`Vault`** (identical source family: PAYER_ROLE/PAYEE_ROLE/transferEther), **created by the same EOA `0xb1757585…`** (`getcontractcreation`).
- On Metis, `0xb1757585…` (a cross-chain deployer active on 10+ chains) created three proxies at nonces 0–2 on 2024-03-21, all pointing at impl `0xd62dEdee…`; siblings `0x78ca07D0…`/`0x3D0362fD…` remain owned by the deployer with 0 balance.
- No known incident/exploit found for this vault. `0xC519c75c…`'s counterparties per routescan labels include KuCoin hot wallets; its deposits/payouts are the vault's only economy.

Caveat: the Metis instance itself carries no local explorer tag, and no KuCoin statement about Metis specifically was found; attribution rests on the deployer tag + cross-chain address attribution.

---

## 8. Exhaustive unprivileged attack-vector table

All simulations via `eth_call` at block `23238718` from `0x1111…1111` (attacker) unless noted. Raw: `h36_gating.json`, `gating_raw.txt`, `gating_raw2.txt`.

| # | Vector | Live gating check | Result |
|---|---|---|---|
| a | `upgradeTo` / `upgradeToAndCall` | `onlyProxy` + `_authorizeUpgrade` → `onlyOwner`; owner = EOA `0x52c904…` | **REVERT** `Ownable: caller is not the owner`; direct-impl call reverts `Function must be called through delegatecall` |
| b | Re-`initialize()` | OZ `initializer`; storage slot0 = `0x01` | **REVERT** `Initializable: contract is already initialized` (proxy and impl) |
| c | Role-gated transfers | `onlyRole(PAYER_ROLE)` + `_checkRole(PAYEE_ROLE,payee)`; PAYER = 1 EOA + 1 3-of-6 Safe (no modules/guard/fallback), PAYEE = EOAs | **REVERT** missing PAYER_ROLE for all of `transferEther`, `batchTransferEther`, `transferErc20`, `batchTransferErc20`, `transferErc721`, `batchTransferErc721`. Positive controls: `transferEther(payee1,1)` simulates OK from both PAYER holders; from PAYER to non-PAYEE reverts missing PAYEE_ROLE |
| c2 | Trigger role holder permissionlessly | Safe needs 3-of-6 signatures; modules `[]`; guard=0; fallback=0; other holders are EOAs | **No path** |
| c3 | Role administration | `grantRole`/`revokeRole` → `onlyRole(DEFAULT_ADMIN_ROLE)`; holders = 2 EOAs | **REVERT** missing `0x00` role; `renounceRole` only for self (no-op for attacker) |
| d | `receive()` donation | adds funds; no shares/accounting to exploit | Harmless; increases balance only |
| e | Storage collision / arbitrary delegatecall via fallback | proxy delegates only to fixed impl; impl has no fallback | **REVERT empty** for `0xdeadbeef` / `setApprovalForAll` (proves no fallback) |
| f | `selfdestruct` / force-feed | impl has no selfdestruct; forcing METIS in changes nothing | Not applicable |
| g | Any role-free function with value effect | Complete ABI enumerated (26 fns); only role-free writes are `renounceOwnership` (owner) and `renounceRole` (self only) | **REVERT**/no-op; nothing moves funds |
| h | `onERC721Received` | returns `0x150b7a02`; no state/value | No value |
| i | Direct impl calls | `onlyProxy` guards `upgradeTo`; impl initialized/locked | **REVERT** |
| j | Key compromise / signer collusion (privileged) | owner EOA can upgrade; 3-of-6 Safe + PAYER EOA can transfer | **Privileged only — out of scope for E-U**, flagged as operational risk |

**If any unprivileged path existed it would be written here — none does.** The only value-moving calls require (i) owner key, or (ii) PAYER role (1 EOA key or 3-of-6 Safe signatures), or (iii) DEFAULT_ADMIN key + grant.

---

## 9. Final classification

**E-U — economically unextractable by any unprivileged actor.** $0 hostile-extractable; 68,713.855 METIS (≈$687,138.55 at METIS≈$10) remains under privileged custody. **H-O ruled out** — this is not orphaned/abandoned: an active KuCoin-linked vault operated via a 3-of-6 Safe, last payout 2026-08-11, with all flows fully reconciled. **P** applies only to the legitimate key holders (owner EOA upgrade power; PAYER Safe). **S** not applicable.

- Unprivileged extraction: **$0.00** · Confidence **0.97**
- Total held: **68,713.855 METIS / $687,138.55** · Confidence in balance **1.00** (two RPCs, pinned block, exact wei)
- Attribution to KuCoin: Confidence **0.85**
- What would change the verdict: compromise of owner EOA `0x52c904…`, ≥3/6 Safe signer compromise, or a future implementation upgrade (none since deployment).

---

## 10. Evidence index (all under `analysis/h36/`)

| File | Content |
|---|---|
| `h36_state.json` | pinned-block state: slots, codehashes, balance, owner, proxiableUUID revert |
| `h36_roles.json` / `roles_raw.txt` | role hashes, members, EOA/contract classification, Safe params |
| `h36_gating.json` / `gating_raw*.txt` | 24 live gating simulations incl. all value functions |
| `h36_flows.json` | deposits/payouts with tx hashes, reconciliation, other assets |
| `h36_identity.json` | attribution table + web sources |
| `h36_abi_functions.txt` | complete function inventory |
| `storage_batch_resp.json` | full storage scan slots 0–300 (found slot0=1, slot 0x97=owner) |
| `logs_*.json` | Upgraded / Initialized / OwnershipTransferred / RoleGranted / RoleRevoked (all-time) |
| `bs_addresses_*` | Vault address, counters, transactions, internal txs, token transfers, token balances |
| `bs_safe_*`, `bctx_*.json` | Safe meta/history; decoded setup + execTransaction calldata |
| `bs_deployer_txs.json`, `bs_impdep_txs.json`, `bs_payee_txs.json` | deployer, impl-deployer, main counterparty histories |
| `payer_contract.json`, `safe_singleton.json`, `spam_token.json`, `rs_avax*.json` | verified sources / cross-chain evidence |
| `read_state.sh`, `read_roles.sh`, `gating_sims*.sh` | reproducible read-only scripts |

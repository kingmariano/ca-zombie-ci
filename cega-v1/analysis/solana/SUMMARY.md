# Cega V1 — Solana Program Deep-Dive (zombie-hunt)

- **Program**: `3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs` (executable, upgradeable)
- **ProgramData**: `28qdJRKpfu1VGBbrSk7MEhdQV2fnfLyRNC4vsv6rVtQc`
- **Upgrade authority**: `5d8d3PSxKDb6knunoweZ8jZYoDmgEEGMVJdqJBTgjvRx`
- **Binary**: 2,380,576 B payload, sha256 `b874c2cec6c96e90c43e98e4c9e443ee6113724226b92dfb5455e159acd3c14a`, last deploy slot 317,515,655 (≈ Jan 2025)
- **Method**: read-only mainnet RPC (`getProgramAccounts`, `getMultipleAccounts`, `getSignaturesForAddress`, `getTransaction`). No transaction was signed or sent.
- **Artifacts**: `state.json` (machine-readable), `decoded_state.json`, `token_balances.json`, `tx_activity_100.json`, `cega_vault_idl.json`, `programdata.bin`, `zellic_cega_vault_patch_review.pdf`, fetch/decode scripts.

## 1. Program account inventory

| type | discriminator | size | count |
|---|---|---|---|
| State | `d8926b5e…` (sha256 `account:State`) | 212 | 1 |
| Product | `664c37fb…` | 285 | **23** |
| Vault | `d308e82b…` | 514 | 157 |
| StructuredProductInfoAccount | `098bb361…` | 332 | 157 |
| OptionBarrier | `21378748…` | 367 | 382 (IDL layout implies 332 → schema drift) |
| QueueHeader | `ea55cfb2…` | 88 | 180 |
| QueueNode | `96b27001…` | 80 | 14 |
| DepositInfo | `6539dcf8…` | 113 | 3,082 |

All discriminators match the public IDL's account names (`sha256("account:Name")[0..8]`).

**State** (`3nFsMoYYifWFqYHALwxoD7hAm85fg5zm9n1n1DCzqqZX`):
`programAdmin = CX2zeerdycdmvanADFzrWe1p4N48hiwfzfq2mW8VYqop` (= feeRecipient), `admin = FMs1U19BfkLU3cunEa3yNZU69isCLBq59HK1eiFoLmx6`, `nextAdmin = same`, `traderAdmin = AuFniTGJZEibC4tBgkdZscPmVPUbSLn6xqmAgpPJpJFm`, `programUsdcTokenAccount` field = default pubkey (unused). `productAuthority` PDA = `4nhbsUdKEwVQXuYDotgdQHoMWW83GvjXENwLsf9QrRJT`.

## 2. Products (all underlying = USDC `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v`)

| product | PDA | active | USDC now | counter `underlyingAmount` | vaults | maxDeposit |
|---|---|---|---|---|---|---|
| genesis-basket-2 | `45eBn7xc…gckB` | no | 82,669.62 | 127,761.84 | 24 | 11,700,000 |
| cruise-control-2 | `5LZJ8Msc…nrcY` | **yes** | 78,147.66 | 165,667.66 | 24 | 16,350,000 |
| go-fast-2 | `9r8JiBWh…XfMg` | **yes** | 44,255.46 | 73,717.24 | 24 | 8,700,000 |
| supercharger | `HGAp6kzG…T9dz` | **yes** | 40,607.78 | 49,844.35 | 8 | 2,000,000 |
| insanic-2 | `HkGKcjAs…Vr7C` | **yes** | 16,935.71 | 45,065.23 | 24 | 7,050,000 |
| autopilot | `7tzhqhfD…aUbw` | no | 2,214.92 | 7,587.62 | 9 | 6,100,000 |
| starboard | `Hc7bcPzU…FuMi` | no | 556.89 | 3,812.37 | 4 | 2,000,000 |
| solana-summer-2 | `GJesRYMR…cPdX` | no | 39.29 | 39.28 | 2 | 150,000 |
| genesis-basket-test | `A6yMeMsq…HVgJ` | yes | 29.42 | 1,820.74 | 2 | 1,000,000 |
| cruise-control-1 | `9qLfzq5S…Eimi` | no | 8.00 | 8.00 | 1 | 1,000,000 |
| test-1 | `ZEGWkTsr…aTiP` | no | 3.84 | 16.20 | 14 | 100 |
| alick-demo | `67GquXd3…BuGW` | yes | 3.03 | 18.16 | 1 | 1,000,000 |
| test-2 | `AHantkxT…rkN9` | no | 1.00 | 1.00 | 1 | 1,000,000 |
| summer-basket-test | `5sjouDxq…j1bw` | no | 0.10 | 1.24 | 4 | 1,000,000 |
| genesis-basket-1 | `D7WWRbn5…NLpL` | no | 0.02 | 0.02 | 2 | 1,000,000 |
| go-fast-test | `35sjRfSM…r8pD` | no | 0.01 | 10,012.26 | 3 | 500,000 |
| cruise-control-test | `BQJvJvSa…tAc1` | no | 0.002 | 9,999.92 | 1 | 2,000,000 |
| insanic-test | `D4fhKAnu…n8rhg` | no | 0 | 10,054.79 | 5 | 100,000 |
| test-3, go-fast-1, test-4, fel-test, solana-summer-1 | … | no | 0 | 0–0.74 | 0–1 | — |

`underlyingAmount` is a **cumulative counter**, not current custody (e.g. cruise-control-2 counter 165.7k vs 78.1k held; genesis-basket-2 counter 127.8k vs 82.7k held).

**DefiLlama's ~$168k** = sum of `underlyingAmount` for the three *pure options* products `insanic-2 + supercharger + go-fast-2` (45,065.23 + 49,844.35 + 73,717.24 = **168,626.82**). The adapter skips `isActive=false` products, which is why genesis-basket-2/starboard/autopilot (options+bonds) are excluded despite still holding funds.

## 3. Live USDC custody (measured on-chain)

All program-controlled USDC token accounts are owned by the **productAuthority PDA** `4nhbsUdK…rRJT` (product PDAs themselves own no token accounts):

| bucket | USDC |
|---|---|
| active product token accounts (6) | 179,979.06 |
| inactive product token accounts (17) | 85,493.69 |
| program USDC account `BTStJZTJvscGRive34P6ShujjqK4GBBRs93bg1Y4B7Y4` (derived PDA, not the default State field) | 208,068.26 |
| **total program-controlled USDC** | **473,541.02** |

No Token-2022 accounts. ~350 additional non-USDC token accounts (option/redeemable tokens of old vaults) hold negligible value; largest 2×10,000 of obscure test mints, plus 821.42 starboard withdraw-queue redeemable tokens.

## 4. Pending/queued positions (zombie evidence)

- **Withdraw queues: 10,841.15 USDC queued across 8 vaults / 13 nodes.** Notably:
  - `cruise-control-test` vault#0: claim **10,000.00 USDC**, but the product token account holds **0.002055 USDC** (vault status 3 = PayoffCalculated). Under-collateralized by ~9,999.998.
  - `starboard` vault#0: claim **821.42 USDC**, product account holds **556.89 USDC** (status 5 = ProcessingWithdrawQueue). Under-collateralized by ~264.53.
  - Others covered: genesis-basket-2 1.00/82,669; supercharger 16.02/40,608; cruise-control-1 0.60/8.00; test-1 2.01/3.84; summer-basket-test 0.10/0.10.
- **Deposit queue: 1.00 USDC** (single node, admin's own, genesis-basket-test).
- 33 of 36 `processWithdrawQueue` calls in the last 100 program txs failed inside the SPL burn/transfer with **"insufficient funds"** — consistent with the under-collateralized queues above. The successful one paid out 28,604.65 USDC (cruise-control-2 vault, burn 23,921.92 redeemable).
- `DepositInfo`: 3,082 accounts / 1,624 users / 51,001,791 USDC summed — these PDAs (`[userKey, vault]`) are historical receipts since 2022, never closed (still created on new deposits) and are **not** current custody or current claims.
- Vault statuses: 114× WithdrawQueueProcessed, 23× NotTraded, 9× Traded, 6× ProcessingWithdrawQueue, 4× PayoffCalculated, 1× DepositQueueProcessed.

## 5. Instruction surface (45 instructions, from `cega_vault.json`, discriminators verified against mainnet txs)

Discriminator scheme: Anchor `sha256("global:" + snake_case(name))[0..8]` (the IDL names are camelCase). On-chain Anchor IDL account: **absent**.

| signer gate | instructions |
|---|---|
| **no signer (permissionless)** | `calculateCurrentYield`, `calculateVaultPayoff`, `calculationAgent` |
| user | `depositVault`, `addToDepositQueue`, `withdrawVault`, `transferToCega`, `acceptAdminUpdate` |
| payer (any) | `fundProductAuthority` |
| admin | `updateFees`, `initializeProduct`, `updateOptionBarrierDetails`, `updateProductFees`, `updateTenorInDays`, `setProductDepositQueue`, `setProductState`, `overrideVaultBarriers`, `overrideOptionBarrierPrice`, `transferBetweenProducts`, `overrideVaultStatus`, `rollbackKnockOutEvent`, `createTokenMetadata`, `updateTokenMetadata`, `updateUnderlyingAmount` |
| programAdmin | `initializeState`, `updateAdmin`, `updateFeeRecipient`, `updateTraderAdmin`, `updateMapleAccount` |
| traderAdmin | `initializeVault`, `initializeStructuredProduct`, `initializeOptionBarrier`, `initializeProgramUsdcAccount`, `updateVaultEpochTimes`, `updateMaxDepositLimit`, `updateApr`, `processDepositQueue`, `processWithdrawQueue`, `transferToProgramUnderlyingTokenAccount`, `sendFundsToMarketMakers`, `transferToProductUnderlyingTokenAccount`, `collectFees`, `rolloverVault`, `overrideObservationPeriod`, `setOptionBarrierAbs` |

Value-out instructions (`processWithdrawQueue`, `sendFundsToMarketMakers`, `transferToProductUnderlyingTokenAccount`, `collectFees`, `transferBetweenProducts`, `updateUnderlyingAmount`) are all admin/traderAdmin-gated; user instructions can only move user-signed funds **into** program accounts or enqueue claims. Validation strings extracted from the binary show explicit checks for token-account ownership, mint, receiver mismatch, vault/trader admin (`InvalidUserUnderlyingAccountOwner`, `Reciever token account mismatch`, `InvalidVaultAdmin`, `InvalidTraderAdmin`, `MissingRequiredSignature`, Anchor owner/discriminator constraints). No missing-signer or arbitrary-account substitution was found.

## 6. Upgrade authority & governance

`5d8d3PSx…jvRx` is a system-owned, zero-data, 1 SOL account that has **never been observed as a transaction signer** — consistent with a **Squads v3 multisig vault PDA** (program `SMPLecH534NA9acpos4G6x7uf3LWbCAwZQE9e8ZekMu`; multisig account `ETzCPEqBUk4ehX2Jqv9MhKLxiNaQpGiVGoqmj548nUpF`, owner SMPLecH, 410 B).
Evidence:
- 2024-08-12 tx `k63Pvm6f…zwCit`: signer member `AmtZcfRf…e1rTu` → Squads `ExecuteTransaction` → BPFLoader **Upgrade** of `3HUeoo…` (authority `5d8d3PSx…`).
- 2025-01-31 tx `Ysvxg1Vs…ruWU`: signer member `DtEVWZdw…xa2R1` → Squads `ExecuteTransaction` → BPFLoader **Upgrade** of `3HUeoo…`.
- 2022-12-16 BPFLoader `SetAuthority` handed the authority from `31Jum3uf…eVQTa` to `5d8d3PSx…`.
The authority's last observed activity: 2025-01-31 (19 sigs total, 0 errors). Threshold/member set were not parsed.

## 7. Source/IDL availability

- **SDK + IDL**: `https://github.com/cega-fi/cega-sdk-sol` → `src/idl/cega_vault.json` (v0.1.0, 45 instructions, 89 errors, 21 types; last commit 2024-10-15). npm `@cega-fi/cega-sdk-sol@1.1.0`. Saved as `cega_vault_idl.json`.
- **Program source**: not public. Binary strings reveal path `programs/cega-vault/src/{lib,account,context,utils,types,validation}.rs` and all instruction names/logs (`Instruction: DepositVault` etc.), plus the full custom error list — used to cross-check the IDL. Deployed OptionBarrier account is 367 B vs 332 B implied by the IDL (schema drift, program newer than SDK).
- **On-chain IDL**: absent (checked PDA `anchor:idl` and legacy `create_with_seed` addresses).
- **Zellic**: "Cega Vault Smart Contract Patch Review" saved as `zellic_cega_vault_patch_review.pdf` (from `github.com/Zellic/publications`); it covers the EVM contracts, not the Solana program.

## 8. Recent activity (last 100 program signatures, 2025-11-30 → 2026-09-24)

46/100 succeeded. Instruction mix: `OverrideVaultStatus` 39 (38 by admin; zombie-vault cleanup), `ProcessWithdrawQueue` 36 (33 failed — see §4; by traderAdmin), `WithdrawVault` 5 (all succeeded, users), `SendFundsToMarketMakers` 1 (failed). CPI mix: Burn ×33, TransferChecked ×35 (mostly the failing queue processing).

**Active probing observed**: account `FoCZvQdRkj7PuAqGupo9XXS7aEtSfGG8SpoZAxHg4DjN` sent 18 minimal-account txs on 2026-09-24/25 (16 errors) calling `ProcessWithdrawQueue`/`OverrideVaultStatus`; all rejected at the account layer (`AnchorError 3007 AccountOwnedByWrongProgram`, custom 0x1). Separately `HWLAWoYX…W8i9` fired 50 failing txs in 9 seconds on 2026-07-28 at dozens of random programs with empty data (generic spam; not Cega-specific). Neither suggests a bypass.

## 9. Verdict

**No unprivileged extraction path is visible.** All USDC sits in PDAs owned by the productAuthority PDA; every outbound path requires admin/traderAdmin signatures (or a Squads-approved program upgrade), and live probes with substituted accounts were rejected by ownership/signer checks.

**Blockers / residual risk**:
1. **Privileged drain risk**: traderAdmin (`AuFniT…pJFm`) and admin (`FMs1U1…oLmx6`) are single keypairs that can move/redirect all 473.5k USDC or rewrite vault accounting; programAdmin (`CX2zee…Yqop`) can rotate them.
2. **Under-collateralized zombie claims** (~10,264 USDC): `cruise-control-test` (10,000 claim vs 0.002 backing) and `starboard` (821.42 claim vs 556.89 backing); `processWithdrawQueue` for these fails with insufficient funds. No user-side path to recover without the missing backing or admin top-up.
3. **Schema drift**: deployed OptionBarrier layout differs from the public IDL; the IDL is a 2024 snapshot while the program was last upgraded ~Jan 2025 (deployer keys not re-verified beyond instruction-name/discriminator matching).
4. **Upgrade risk**: multisig-gated (Squads v3) but not immutable; threshold/members unknown.
5. DefiLlama TVL is derived from counter fields, not balances — it overstates pure-option custody (~168.6k counter vs 101.8k actually held in those three products) and omits ~85.5k held by inactive products.

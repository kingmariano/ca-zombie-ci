# Stakehouse (Blockswap) — L2 Phase-2 deep dive: live unprivileged extraction

**Campaign:** zombie-hunt II · L2 watchlist Phase 2 · **Finding:** L2-Triage-A row 30 (`stakehouse`)
**Chain:** Ethereum (chain id 1) · **Date of work:** 2026-10-12 · **Status:** read-only; PoC fork-verified only; no mainnet transactions.
**Triage input:** $160,401 (GoldRush) = 64.3057 ETH in the AccountManager. Re-verified at block 26,178,656: **exactly 64.305717944108928421 ETH**. The protocol is dead (last user activity 2024; last ETH distribution 2024-07-04), and the whole balance is **not self-service withdrawable today** — every payout path requires the protocol's off-chain *designated verifier* signature, which has been dormant since 2024-08-06.

> One-liner: an external unprivileged attacker can extract **$0** from Stakehouse. The AccountManager vault (64.3057 ETH ≈ $160k) is gated by `isCoreModule(msg.sender)` ("Only core"); all user-facing payout paths (FullWithdrawals claim, Shanghai sweep/partial withdrawals) additionally require an ECDSA signature from the designated verifier `0x9785f8e5…` (an EOA with **nonce 0** that signs only off-chain) plus knot-ownership gates. The 64.3 ETH decomposes exactly into two orphaned full-validator sweeps (32.0053 ETH for knot 78, 31.0862 ETH for knot 44) + 1.2142 ETH legacy dust; the two beneficiary parties (an active EOA and a smart wallet owned by `0x831138ee…`) could claim *if the verifier ever signs again* — latent **$161,798** ($2,516/ETH), currently stuck.

---

## 1. TL;DR

| # | Target (Ethereum) | Live value now | External unprivileged extraction (E-U) | Why closed | Latent risk |
|---|---|---|---|---|---|
| 1 | **AccountManager** `0xDd6E6794…` (vault) | **64.3057 ETH** | **$0** | every ETH-moving function is `require(accessControls().isCoreModule(msg.sender), "Only core")` — fork-proven | none (core set is 9 fixed protocol contracts) |
| 2 | **FullWithdrawals** `0x8F6839b0…` (full-sweep claim) | pays from #1 | **$0** | needs `isUserEnabledForKnotWithdrawal[msg.sender]` (rage quit), `!userWithdrawn`, a valid final-sweep report **and a designated-verifier ECDSA signature** ("Signature expired"/"ECDSA: invalid signature"/"Not rage quit" in bytecode) | knot 78's 32.0053 ETH + knot 44's 31.0862 ETH claimable by their owners if the verifier signs |
| 3 | **ShanghaiSweepReporting** `0x64f4fCFb…` (partial withdrawals) | pays from #1 | **$0** | report validation ("Invalid Report", "Active balance", "Invalid total ETH sent for BLS key") + verifier ECDSA + per-user rage-quit gates + `Sweep already reported` replay guard; fork-proven reverts | 21.37 ETH "reportedNotWithdrawn" counters are **stale** (not a separate pot; see §5) |
| 4 | **TransactionRouter** `0x03F4310b…` (rage quit / exit entry) | — | **$0** | caller must be the knot's user/smart-wallet owner or an authorized representative; rage quit burns the caller's own derivatives | — |
| 5 | **RageQuitAssistant** instances (dust) | 0.665519 ETH across 46 assistants | **$0** | permissionless claims pay **recorded beneficiaries only** (dETH/sETH/collateralised-slot owners) | residual dust claims for the recorded parties |
| 6 | dETH / savETH tokens | 16.89 / 4.91 supply | **$0** | redemptions burn caller-owned dETH 1:1 for the same wei (traced); reporting/minting needs the verifier signature | — |
| 7 | 23 LSD networks (LSM + vaults + sETH) | dust only (≈0.1 ETH) | **$0** | all network contracts hold ~0 ETH (parallel scan, block 26,178,916) | — |

**Total live extractable by an external unprivileged attacker today: $0.00 (confidence HIGH).**
Latent (verifier-dependent) holder recovery: **$161,798.49** (64.3057 ETH @ $2,516.08; DefiLlama ETH price 2026-10-12). Currently **S/P** (stuck unless the privileged off-chain verifier key signs again).

---

## 2. The protocol and the live custody

Stakehouse (Blockswap Network) is a 2022–2023 liquid-staking protocol on Ethereum. "KNOTs" are validators; the protocol's **AccountManager** is the beacon-chain withdrawal credential for every KNOT (`0x010000000000000000000000dd6e67942a9566a70446f7400a21240c5f71377c`), so every validator sweep/full withdrawal lands there. Distribution is handled by two 2023 "withdrawals" core modules:

```
StakeHouseUniverse 0xC6306C52… (registry, core module)
  ├── AccountManager 0xDd6E6794…      ← holds 64.3057 ETH (vault; withdrawETH/rageQuitKnot = "Only core")
  ├── TransactionRouter 0x03F4310b…   ← user entry: registerValidator, rageQuitKnot, voluntaryWithdrawal…
  ├── SLOTRegistry 0xC01DC3c7…        ← collateralised SLOT + userWithdrawn/enabled flags
  ├── savETHRegistry 0x88E6c707… / savETHTransactionRouter 0x9CbC2Bf7… / savETHBatchRouter 0x1D1f35aA…
  ├── ShanghaiSweepReporting 0x64f4fCFb…  ← partial sweeps + partial withdrawals (verifier-signed reports)
  └── FullWithdrawals 0x8F6839b0…         ← final/full sweep claims (verifier-signed reports)
```

Core-module set (from `StakeHouseAccessControls 0xba86e291…` logs; 9 grants, 0 revocations): Universe, AccountManager, TransactionRouter, SLOTRegistry, savETHRegistry, savETHTransactionRouter, savETHBatchRouter, ShanghaiSweepReporting (granted block 18,192,233), FullWithdrawals (block 18,192,233). The implementation of the AccountManager (UUPS proxy, upgraded 2023-09-22 at block 18,191,957) is **unverified on Etherscan**; the gating was recovered from the deployed bytecode and fork-tested.

---

## 3. The mechanism: why an attacker gets nothing

Every path that moves ETH out of the AccountManager is gated on **at least two** independent conditions:

1. **Vault gate (AccountManager, fork-proven):** `withdrawETH(address,uint256)` and `rageQuitKnot(...)` call `accessControls().isCoreModule(msg.sender)` and revert `"Only core"` for anyone else. Bytecode: modifier at `0x21ac`, revert string `0x4f6e6c7920636f7265` ("Only core"); dispatch table has 34 selectors (verified by disassembly).
2. **Verifier signature (FullWithdrawals / ShanghaiSweepReporting):** all report/withdrawal entry points take a `VerifierSignature {deadline, v, r, s}` and verify it against the designated verifier via `ECDSA.recover` (`"Signature expired"`, `"ECDSA: invalid signature"`), with per-sweep replay guards (`"Already reported"`, `"Sweep already reported"`, `"Duplicate"`).
3. **Ownership gate:** the report paths require `slotRegistry.isUserEnabledForKnotWithdrawal[user][knot]` and `!userWithdrawn` (`"Not rage quit"`, `"Not enabled for withdrawal"`), i.e. the claimant must have rage-quit/burned the knot's derivatives first; `rageQuitKnot` itself requires the caller to be the knot's user/smart-wallet owner or authorized representative.

The designated verifier `0x9785f8e50229ebd2b3788452abc31d1942394e0c` is an **EOA with zero code and nonce 0** — it was only ever used to sign reports off-chain (the "DepositRouter" committee signer). It is still `isDesignatedVerifier == true` on both contracts, but the last sweep report was at block 20,478,005 (2024-08-06) and the last full claim at block 20,234,472 (2024-07-04). Without that signature nothing can be claimed — including by the rightful knot owners.

Fork PoC (`poc/test/StakehousePoC.t.sol`, 6/6 PASS, block 26,178,656):
- `test_01`: direct attacker calls to `withdrawETH` / `rageQuitKnot` / `markKnotAsWithdrawn` / `setLifecycleExited` → all revert `"Only core"`.
- `test_02`: **the only gate is core status** — impersonating FullWithdrawals, `withdrawETH(attacker, 1 ETH)` succeeds.
- `test_03`: attacker `reportFinalSweepAndWithdraw` for knot 78 reverts at report validation ("Active balance").
- `test_04`: attacker `reportSweeps`/`reportAndWithdrawETH` revert "Invalid Report"/"Zero sweeps".
- `test_05`: live state of the two unclaimed sweeps + verifier EOA/nonce-0.
- `test_06`: the "reportedNotWithdrawn" counters are stale (knot 81 claimed 32.065710 ETH while its counter still reads 0.065710).

---

## 4. Where the 64.3057 ETH actually is (exact decomposition)

Balance at block 26,178,656: **64.305717944108928421 ETH**. All-time flows: 1,637.616 ETH in (≈49–50 beacon deposits ×32 ETH + 37.6 ETH rewards/top-ups) → 1,573.311 ETH out (48 full claims 1,557.451 + 69 partial 15.860) → 64.306 left.

Two full-validator withdrawals arrived **after the last distribution** and were never claimed:

| Inflow | Block | Date | Validator | Amount | Knot | Beneficiary | State |
|---|---|---|---|---|---|---|---|
| 1 | 20,482,055 | 2024-08-08 | 1,109,420 | 32.005324832 ETH | **knot 78** (key `0x97d7b76d…`) | EOA `0xddb50ffd…` | lifecycle EXITED, `enabled=1`, `withdrawn=0`, final sweep **unreported** |
| 2 | 23,726,929 | 2025-11-04 | 747,994 | 31.086158519 ETH | **knot 44** (key `0x8f691a27…`) | smart wallet `0x246269f8…` (45-byte clone, owner `0x831138ee…`) | lifecycle TOKENS_MINTED, `enabled=0` (needs rage quit first), final sweep **unreported** |
| — | — | — | — | 1.214235 ETH | legacy dust | various | pre-existing unclaimed residue |

Both claims require: (a) the knot enabled (`enabled=1`) and not yet withdrawn; (b) a valid final-sweep report signed by the dormant verifier. Knot 78 is one signature away; knot 44 additionally needs the owner's rage quit (which itself needs the off-chain report + committee signature for the ETH2 report). Neither is possible for an outsider, and neither is possible for the owners **today** (verifier dormant).

## 5. Negative results / dead ends (with evidence)

- `reportedNotWithdrawn` sum = 21.3727 ETH across 85 knots — **not a separate live pot**: it is stale accounting. E.g. knot 81's counter still reads 0.065710 ETH after its 32.065710 ETH full claim (block 19,626,256). The only real unclaimed value is the two final sweeps + 1.2142 dust.
- No `SweepReported` event after block 20,478,005 (2024-08-06) and no `FullWithdrawalExecuted` after block 20,234,472 (2024-07-04): the off-chain reporting pipeline is dead.
- `isFullSweepReported` is `false` for both orphaned sweeps (withdrawal indexes 55,146,846 and 107,072,512).
- The AccountManager received no transactions in 2025–2026; the two inflows are system-level beacon withdrawals (visible only as balance deltas and block `withdrawals` entries).
- All 48 UNSTAKED knots already claimed (48 `FullWithdrawalExecuted` events); 35 knots never deposited. Only knots 78 (EXITED, enabled=1) and 44 (TOKENS_MINTED, enabled=0) hold unclaimed full sweeps.

## 6. What an attacker can and cannot do (exact paths)

| Attempt | Call | Result |
|---|---|---|
| Drain vault directly | `AccountManager.withdrawETH(attacker, 64.3e18)` | revert `"Only core"` (modifier 0x21ac → `accessControls.isCoreModule(msg.sender)`) |
| Rage-quit someone else's knot | `AccountManager.rageQuitKnot(attacker, key, …)` | revert `"Only core"` |
| Fake a withdrawal state | `markKnotAsWithdrawn` / `setLifecycleExited` / `updateAccountState` / `update*FromReport` | revert `"Only core"` |
| Claim knot 78's orphaned sweep | `FullWithdrawals.reportFinalSweepAndWithdraw(32e18, key78, [], finalSweep, report, sig)` | revert at report validation (`"Active balance"`); even with a perfect report, the verifier ECDSA check (`"Signature expired"`/`"ECDSA: invalid signature"`) and `"Not rage quit"` block it |
| Claim via partial withdrawals | `ShanghaiSweepReporting.reportAndWithdrawETH(...)` / `reportSweeps(...)` | revert `"Zero sweeps"` / `"Invalid Report"`; verifier signature + per-sweep replay guards required |
| Become a claimant | `TransactionRouter.rageQuitKnot(user, key, …)` | only the knot's user/smart-wallet owner or an authorized representative; burns the caller's own derivatives |
| Claim an assistant's dust | RageQuitAssistant `dETHClaim/sETHClaim/collateralisedSlotOwnerClaim/nodeOperatorClaim` | pays the recorded beneficiary index only; no attacker redirection |
| Upgrade the vault | `AccountManager.upgradeTo(newImpl)` | `PROXY_ADMIN_ROLE` = 0x8869a94d… only (`"Only mutable"`) |

Costs: none of the above is a viable attack — every path reverts before any value moves; the only "successful" unprivileged interaction is paying gas. Flash loans are irrelevant (no oracle/price/rounding surface touches the vault).

## 7. PoC / fork verification

- `poc/test/StakehousePoC.t.sol` — **6/6 PASS** at pinned fork block 26,178,656 (archive RPC; falls back to `latest` when the CI RPC is non-archival).
  - `test_01` AccountManager direct calls (9 functions) → `"Only core"` (gas 442,210)
  - `test_02` vault pays only on core-module instruction (impersonated FullWithdrawals, +1 ETH; gas 65,226)
  - `test_03` attacker full-sweep claim reverts (gas 48,252)
  - `test_04` attacker sweep report/withdraw reverts (gas 96,487)
  - `test_05` live state: 64.305717944108928421 ETH, knot-78 enabled/not-withdrawn, knot-44 not-enabled, verifier EOA + nonce 0 (gas 167,170)
  - `test_06` stale `reportedNotWithdrawn` counter for claimed knot 81 (gas 29,295)
- CI run: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38310577743** — `success`, all 6/6 tests PASS; custom `ci/run.sh` state dump (block 26,179,073) confirms the balance is unchanged (64.305717944108928421 ETH) and both knots still unclaimed. Log: `ci-log.txt`; artifacts: `ci-artifacts/result-stakehouse/ci-out/{state.json,state_dump.txt}`.

## 8. Verdict, residual and latent risk

- **E-U: $0.00 (high confidence).** No permissionless function pays the caller; the vault is core-gated; all payouts are verifier-signature-gated.
- **Latent (verifier-dependent): $161,798.49** ($80,528.03 knot 78 + $78,215.34 knot 44 + $3,055.11 dust) for the recorded beneficiaries (H-O in nature, but not self-service today → **S/P** until the designated verifier signs again).
- **P:** the verifier EOA/team can unlock all 64.3 ETH for the recorded beneficiaries at any time (privileged).
- No pause/blacklist involved; no upgrade risk for an attacker (PROXY_ADMIN_ROLE moved to `0x8869a94d…` at block 19,561,695).

## 9. Methodology & sources

- Live reads at block 26,178,656 (eth_call/eth_getBalance/eth_getStorageAt via archive RPC), Etherscan V2 logs/ABI, beacon-chain API for validator identities.
- Bytecode disassembly (pyevmasm/heimdall) of AccountManager impl `0x9227cb6d…`, TransactionRouter impl `0x6930f6c4…`, ShanghaiSweepReporting impl `0xdf39face…`, FullWithdrawals impl `0xb4d61d73…`; audit text (Runtime Verification, "Blockswap Stakehouse Withdrawals", 2023-06-29); npm `@blockswaplab/stakehouse-protocol-abis` 2.2.6; verified sources: StakeHouseUniverse package, SlotSettlementRegistry, dETH.
- Parallel deep dives (children): `analysis/childA/sweep_reporting_gating.md` (deployed-selector map, per-function gates, signature-coverage oracle: **all report fields signed except `report.stakeHouse`** — latent front-run window inside the report deadline; payout paths burn caller-owned dETH 1:1 and pay `msg.sender`; reporter bot dead since 2024-08-07), `analysis/childB/` (FullWithdrawals/SweepReporting heimdall decompiles + router gate strings), `analysis/childC/` (46 assistants 0.665519 ETH dust; 23 LSD networks ~0 ETH; verifier EOA never transacted; QueueFlushETHClaim no events).
- Files: `README.md` · `summary.json` · `analysis/LIVE-STATE.md` (consolidated evidence) · `analysis/*.json` (state dumps) · `analysis/*.py` (read-only scripts) · `analysis/childA|childB|childC/` (parallel deep dives) · `poc/` (Foundry project, 6 tests) · `ci/run.sh` (state dump) · `ci-out/` · `ci-log.txt` · `ci-artifacts/`.

## 10. Caveats, files index

- The AccountManager/TransactionRouter/FullWithdrawals/SweepReporting implementations are unverified; gating was recovered from bytecode + live simulations (fork-verified). Confidence high but not source-level.
- The designated verifier's key existence cannot be determined on-chain; if the key still exists (team custody), the funds are recoverable (privileged); if lost, they are permanently stuck (S).
- Values in USD use DefiLlama ETH price at 2026-10-12; ETH/USD moves the headline.

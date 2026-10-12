# Child-A — ShanghaiSweepReporting (deployed impl) function gating & extractability analysis

**Target**: SweepReporter proxy `0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0` (mainnet), implementation `0xdf39face16519376e47bba3b9be15e69d8a66f2c`
**EIP-1967 impl slot** (`0x360894a1…392bbc`) = `0x…df39face16519376e47bba3b9be15e69d8a66f2c` (read live at block 26178897; admin slot `0xb5312768…5d6103` = 0)
**Bytecode identity**: on-chain runtime == the bytecode this analysis was performed on; copy saved at `evidence/impl_runtime.hex`, re-fetched from `eth_getCode(impl)` at block 26179094 (20,488 bytes / 40,976 hex chars).
**Compiler**: solc 0.8.13 (CBOR tail; ipfs `Qmdg38D9yKQ2zoiEpUNAus4WXLR7rvnYoei717rTmzuoZe`). Not verified on Etherscan/Sourcify; GitHub source repo unavailable → analysis is bytecode-level + dynamic.

---

## 0. Critical version mismatch (read first)

The deployed implementation is an **older build than the newer `IShanghaiSweepReporting` interface** (interface sources kept at `evidence/IShanghaiSweepReporting.sol` / `evidence/IDataStructures.sol`); in the deployed code the same tasks are served by **different selectors** (functions renamed and/or one signature changed). Dispatch table (32 entries) extracted with pyevmasm — see `evidence/dispatch_table.json`, `evidence/selector_to_body.json`.

| Task function (new ABI) | New selector | **Deployed selector** | Stub / body | How identified |
|---|---|---|---|---|
| `reportSweeps(report,sig,state)` | 0x4435f228 | **0x556b7541** | stub 0x038b, body 0x1006 | live calldata decode; trace calls savETH `mintDETHReserves`; signature+validation path |
| `reportAndWithdrawETH(bool,report,sig,state)` | 0x6ddf0bd5 | **0x67fbfe86** | stub 0x045b, body 0x1c42 | bool-first calldata (evmole), calls internal report body 0x1006 at 0x1c4e, then jumps into unwrap body 0x23c2 at 0x23b8 |
| `reportSweepsForMultipleBLSPublicKeys(report[],sig[],state[])` | 0x724782f1 | **0x04c32fd2** | stub 0x01e8, body 0x0695 | live calldata decode (arrays); per-report trace: ecrecover + `mintDETHReserves` (mints dETH) |
| `reportSweepsPostRageQuit(report,sig,state)` | 0xb2e10926 | **0x6184bf91** | stub 0x03cb, body 0x18c5 | body requires AM lifecycle == 4 (EXITED) else `Not rage quit`; no mint in trace (lifecycle=4 read live in tx 0x227dea07…) |
| `batchReportSweepsPostRageQuit(report[],sig[],state[])` | 0x5ebdb7f9 | **0x5d007a99** | stub 0x03ab, body 0x175b | live calldata decode (arrays); per-report trace: ecrecover + lifecycle read, **no** mint |
| `unwrapDETH(bytes,uint256)` | 0x690b4c40 | **0x690b4c40** (same) | stub 0x047b, body 0x23c2 | same selector; trace = burn+withdraw |
| `batchUnwrapDETH(bytes[],uint256[])` | 0x2b98c640 | **0x2b98c640** (same) | stub 0x02ca, body 0x0aa5 | same selector; tx trace 0x3a731f5d… |
| `updateTotalETHSentToBlsPublicKeyFromFinalReport(bytes,uint256)` | 0xc4d10d91 | **0x4a1a8df6** = `(bytes,uint256,uint256)` (extra uint256) | stub 0x030a, body 0x0d25 | canonical selector match; body gates + mapping writes (isSweepReported) |
| `init(address,address,uint256)` | 0x86863ec6 | **0x86863ec6** (same) | stub 0x054b, body 0x293b | dangling-address writes, AM cache, already-initialized |
| `manageDesignatedVerifier(address,bool)` | 0x7ec2e278 | **0x7ec2e278** (same) | stub 0x04bb, body 0x269f | live trace: `Only manager` |

Other deployed functions (live-verified read-only views): `isSweepReported` 0xb8f0a9ab, `totalETHSentToBlsPublicKey` 0x678e15d9, `totalSweepsReportedAgainstUnknownTopUpsForBlsPublicKey` 0xf78844a6, `totalReportedETHNotWithdrawn` 0x61cd11e1, `totalReportedUnknownTopUpsForBlsPublicKey` 0xa4850c03, `getListOfUnreportedWithdrawalIndexes` 0x17ffd8af, `validatorIndexToBLSKey` 0x8e33771f, `previewTotalMintableDETH` 0x83147048, `getSumOfUnreportedSweeps` 0x7b172270, `getSweepsHashFromSweepsArray` 0xe6618789, `hasBLSPublicKeyBeenReportedInShanghai` 0x86421457, `getHashOfBlsPublicKey` 0x17ab1b56, `isDesignatedVerifier` 0x22bbe554, `universe` 0x554c1b1f, `validatorSetSizeBeforeShanghai` 0x4b705bd0, `cachedAccountManagerAddress` 0xa68645a3, `getAccountManagerCoreModule` 0xa9956aef, `getSavETHRegistryCoreModule` 0x80ca2193, `upgradeTo` 0x3659cfe6, `upgradeToAndCall` 0x4f1ef286, plus the deployed `isValidShanghaiReport`-equivalent **0x0626f5ac** (view, body 0x080f) which is the shared signature validator.

Live activity ever seen on-chain (Etherscan txlist, 186 txs): only selectors `0x5d007a99` (70), `0x04c32fd2` (54), `0x2b98c640` (39), `0x556b7541` (17), `0x6184bf91` (5) + proxy creation. No upgrade txs.

---

## 1. Signature verification (shared gate for all report functions)

Deployed validator = selector **0x0626f5ac** (view, returns bool), body **0x080f**. `reportSweeps` calls it internally at 0x1119–0x1123 with `(report, sig, state)`.

* ECDSA: `ecrecover` precompile (`STATICCALL` to address 0x1) observed in tx traces (e.g., 5 calls in tx 0x9b651f5f…); ECDSA helpers at 0x2f05 (`recover`) and 0x2f1e (s/v validation); ECDSA revert strings at file offsets 0x3e4f/0x3eb0/0x3f11/0x3f7d.
* Signer acceptance: recovered address masked to 160 bits, then `SLOAD` of mapping **slot 0xcc** (`isDesignatedVerifier`) at **0x092f–0x0938**; validator returns that bool.
* Domain/typehash constants observed: `PUSH32 0x1fefd659…bb86` at 0x0813; contract-name string `"ShanghaiSweepReporting"` at byte offset 0x2ae2 (used in the EIP-712 domain/name path). Exact EIP-712 type string not recoverable from bytecode without source; **field coverage was instead proven empirically** with the deployed validator as an oracle (below).
* `EIP712Signature` = `(uint248 deadline, uint8 v, bytes32 r, bytes32 s)`; deadline is an **ETH1 block number**.

### 1.1 Field-coverage matrix (empirical, read-only eth_call of deployed validator 0x0626f5ac with a real valid signature; mutation flips result)

| Field mutated | validator result | conclusion |
|---|---|---|
| `report.blsPublicKey` | reverts `Key mismatch` in report bodies; validator false | signed + separately cross-checked vs state key |
| `report.totalETHSentToBLSKey` | false | signed |
| `report.sumOfAllSweeps` | false | signed |
| `report.sweeps.length` | false | signed |
| each `sweep.{withdrawalIndex,validatorIndex,recipient,amount}` (incl. last element) | false | signed |
| `sig.deadline` | false | signed |
| `sig.r`/`sig.s`/`sig.v` | false / `ECDSA: invalid signature` | signing key enforced |
| `state.blsPublicKey`, `withdrawalCredentials`, `slashed`, `uint64 fields` | false | signed |
| **`report.stakeHouse`** | **true (still valid!)** | **NOT covered by the signature** |

The `stakeHouse` gap is material (see §6, uncertainty item 1). Replay of old signatures is additionally blocked by `block.number > deadline` (a replayed 2024 tx now reverts `Signature expired`).

---

## 2. Per-function verdict table

ETH-recipient expressions are the decisive part. The contract itself never sends ETH with `CALL` carrying value (no value-bearing CALL found); ETH leaves the system via `AccountManager.withdrawETH(address,uint256)` selector **0x4782f779** on the AccountManager proxy `0xDd6E67942a9566A70446f7400a21240C5f71377C` (only-core; see §3/§5).

| # | Function (deployed) | Caller gates (caller ≠ privilege) | Signature gate | ETH recipient | Ordering / reentrancy | Verdict |
|---|---|---|---|---|---|---|
| 1 | `reportSweeps` **0x556b7541** body 0x1006 | permissionless relay; `require(sweeps.length>0)` `Zero sweeps` @0x102d (check 0x100a–0x1048); `require(block.number ≤ deadline)` `Signature expired` @0x106d (0x104a–0x1098); `Key mismatch` check 0x1099–0x1118; `Invalid Report` @0x1144 if validator false (call @0x1123); `Invalid induction` @0x11e5 (totalETHSent×1e9 ≥ 32e18); `Invalid total ETH sent for BLS key` @0x1235 (d1 read @0x119e); `Invalid sum` @0x1365; internal @0x3475 (`No sweeps` @0x3498) marks per-sweep `isSweepReported` (SLOAD @0x3647, revert `Sweep reported` @0x366b, SSTORE @0x36d7 slot 0xcd), requires `sweep.recipient == cachedAccountManagerAddress` (`Invalid recipient` @0x35bd, slot 0xcf read @0x3548), `Inconsistent index` @0x3740, `Not first sweep` @0x395e, `Invalid first sweep amount` @0x3a96, `Set size is zero` @0x3ba0 | **Yes** (ECDSA of designated verifier) | none directly (mints dETH to the knot's index via savETH `mintDETHReserves` CALL @0x16df) | effects before interactions: mappings updated before savETH mint call; no reentrancy guard on report path but no ETH/value out | no free payout; reporting is by design permissionless-with-signature |
| 2 | `reportAndWithdrawETH` **0x67fbfe86** body 0x1c42 | calls internal report body 0x1006 @0x1c4e (→ all gates of #1); `Amount minted is too small` @0x1f3e only when minted==0 and `!optimistic` (check 0x1f19–0x1f69); withdrawal amount = **min(minted, dETH.balanceOf(msg.sender))** (balanceOf CALLER @0x233a, min @0x238d–0x239e) | Yes (via #1) | **msg.sender** (via unwrap body 0x23c2, recipient = CALLER) | same unwrap ordering | cannot pay more than the caller's own dETH; optimistic only *skips* withdrawal when minted==0 |
| 3 | `reportSweepsForMultipleBLSPublicKeys` **0x04c32fd2** body 0x0695 | `Zero reports` @0x6b7, `Inconsistent array lengths` @0x70b/@0x75a; per report → body 0x1006 (#1) | Yes (per report) | none directly (mints dETH) | loop; effects inside #1 | same as #1 |
| 4 | `reportSweepsPostRageQuit` **0x6184bf91** body 0x18c5 | `require(lifecycle == 4 EXITED)` else `Not rage quit` @0x19e9 (AM `blsPublicKeyToLifecycleStatus` @0x1946, check 0x19cd); `Zero sweeps` @0x1a3b; `Signature expired` @0x1a7b; `Invalid Report` @0x1b52; `Invalid sum` @0x1c20; writes `totalReportedETHNotWithdrawn` add (slot 0xd3) | Yes (validate @0x1b31) | none (no mint — verified by trace) | effects only | no payout; accounting-only |
| 5 | `batchReportSweepsPostRageQuit` **0x5d007a99** body 0x175b | `Empty array` @0x177d, `Inconsistent array length` @0x17cc/@0x181b; per report → body 0x18c5 (#4) | Yes (per report) | none (no mint) | loop; effects inside #4 | same as #4 |
| 6 | `unwrapDETH` **0x690b4c40** body 0x23c2 | `nonReentrant` slot 0x9a (SLOAD @0x23c7, revert `ReentrancyGuard: reentrant call` @0x23e8); internal 0x38b8: `totalReportedETHNotWithdrawn[blsKey] -= amount` (SSTORE @0x38eb; underflow reverts if amount > credited); savETHRegistry burn call @0x24a4 (selector **0xf2556a85**, args `(bytes blsKey, address owner, uint256 amount)` with owner = CALLER — traced); AM `withdrawETH` call @0x251d (selector 0x4782f779, args `(CALLER, amount)`) | none (permissionless by design) | **msg.sender** — traced: AM pays exactly `0xb0e83c2d…` (the caller) the same wei amount burned from the caller's dETH (`0x67eab853ae20000` in tx 0x3a731f5d…, block 18376889) | checks-effects-interactions: d3 decrement + guard before external calls; guard reset after | **no extraction without burning caller-owned dETH 1:1**; attacker eth_call trace → revert `Not minted` (savETH rejects non-entitled key/owner) |
| 7 | `batchUnwrapDETH` **0x2b98c640** body 0x0aa5 | same internal as #6; `No data` @0xac7, `Inconsistent array length` @0xb16 | none | **msg.sender** per element (same unwrap logic) | same as #6 | same as #6 |
| 8 | `updateTotalETHSentToBlsPublicKeyFromFinalReport(bytes,uint256,uint256)` **0x4a1a8df6** body 0x0d25 | **`require(accessControls().isCoreModule(msg.sender))` else `Only core`** — internal 0x332d called @0xd2c: universe slot 0x99 SLOAD @0x3333 → `accessControls()` @0x336f → `isCoreModule(CALLER)` @0x33f2 → revert @0x3446; plus `Invalid induction` @0xd5a, `Smaller not possible` @0xdca, `Sweep already reported` @0xe29 (isSweepReported read @0xdfc) | n/a | none | writes d1 (`totalETHSentToBlsPublicKey`, SSTORE @0xe57) + isSweepReported=true (SSTORE @0xe85) after checks | unprivileged caller blocked (`Only core`; live trace) |
| 9a | `manageDesignatedVerifier` **0x7ec2e278** body 0x269f | reads universe (slot 0x99) → `accessControls()` (STATICCALL 0x26e1) → `accessControls.0x956c1ca5(msg.sender)` (STATICCALL @0x2764) → require true else `Only manager` @0x27b9; sets `isDesignatedVerifier[addr]` (mapping 0xcc, SSTORE @0x2810) | n/a | none | live trace from attacker: revert `Only manager` | blocked |
| 9b | `init` **0x86863ec6** body 0x293b | `Initializable` gate: `Initializable: contract is already initialized` @0x2979/0x299f; no other caller gate (one-shot) | n/a | none | writes universe 0x99 (@0x2a1a), `isDesignatedVerifier[arg]` (@0x2a3a), cached AM 0xcf from `universe.accountManager()` (@0x2a61/@0x2ac3), set-size 0xd0; live trace from attacker: revert already-initialized | consumed; blocked |

Byte offsets are offsets into the deployed runtime bytecode (`evidence/impl_runtime.hex`); see region dumps in `evidence/` for the full listings.

---

## 3. Where the ETH actually is, and the only ETH-out primitive

* AccountManager proxy `0xDd6E67942a9566A70446f7400a21240C5f71377C` balance at block 26179104: **64.30571794410892 ETH**.
* Its ETH-out functions `withdrawETH(address,uint256)` (0x4782f779) and `rageQuitKnot` are `only core`: `require(accessControls().isCoreModule(msg.sender), "Only core")`. Verified live with a direct attacker call to the AM: trace reverts `Only core` (call chain: `universe.accessControls()` → `AccessControls 0xba86e2917a98c4d6bcb171516252348f1e06fffd . isCoreModule(attacker)`).
* The SweepReporter **is** a core module (`isCoreModule(0x64f4fCFb…) == 1`), so any ETH paid out is paid through the paths above: burn dETH from `msg.sender` → AM pays `msg.sender` the same wei amount.

---

## 4. Live verification (all read-only; no state changes)

| Check | Result | Block |
|---|---|---|
| EIP-1967 impl slot | `0x…df39face16519376e47bba3b9be15e69d8a66f2c` | 26178897 |
| `isDesignatedVerifier(0x9785f8e50229ebd2b3788452abc31d1942394e0c)` | **1 (true)** | 26179104 |
| `isDesignatedVerifier(0x…dEaD)` | 0 | 26179104 |
| `universe()` | `0xC6306C52ea0405D3630249f202751aE3043056bd` | 26179104 |
| `cachedAccountManagerAddress()` / `getAccountManagerCoreModule()` | `0xDd6E67942a9566A70446f7400a21240C5f71377C` | 26179104 |
| `getSavETHRegistryCoreModule()` | `0x88E6c7072B867F9546a232548a5D3271986B3C0c` | 26179104 |
| `validatorSetSizeBeforeShanghai()` | 563,068 | 26179104 |
| `totalReportedETHNotWithdrawn(key i=0 0xb9df4050…)` | 1,406,681,564,000,000,000 wei (== knots_summary, 1.4066 ETH) | 26179104 |
| `totalReportedETHNotWithdrawn(key i=4)` | 1,111,809,040,000,000,000 | 26179104 |
| `totalReportedETHNotWithdrawn(key i=5)` | 127,098,632,000,000,000 | 26179104 |
| `totalETHSentToBlsPublicKey(key i=0)` | 32,000,000,000,000,000,000 | 26179104 |
| `isSweepReported(0xb8b366)` (a real reported sweep) | true | 26179104 |
| `SweepReported` topic0 | `0x903c69891897b38f2a8fd69fd972cd0ad4cd1ba34f1ece8a3101bffe4bd8b906` (= keccak `SweepReported(uint256,uint256,uint256)`) | — |
| Attacker `init(...)` trace | revert `Initializable: contract is already initialized` | latest |
| Attacker `manageDesignatedVerifier` trace | revert `Only manager` | latest |
| Attacker `updateTotalETHSentToBlsPublicKeyFromFinalReport` trace | revert `Only core` | latest |
| Attacker `unwrapDETH(key i=0, 0.1 ETH)` trace | revert `Not minted` (inside savETHRegistry 0xf2556a85) | latest |
| Direct attacker AM `withdrawETH(attacker,0.1 ETH)` | revert `Only core` | latest |

**Reporter bot status**: `SweepReported` logs on the proxy: **1,931 logs** from block 18294390 (2023-10-06) to block **20478005 (2024-08-07)**, then nothing for >2 years (head 26,179,0xx). Monthly counts: 2023-10 483, 2023-11 20, 2023-12 45, 2024-01 84, 2024-02 131, 2024-03 247, 2024-04 25, 2024-05 80, 2024-06 740, 2024-07 51, 2024-08 25. **The reporting bot is dead.**

---

## 5. Why an attacker cannot extract the AccountManager ETH through this contract

1. **Payouts require burning caller-owned dETH 1:1.** All ETH-out paths (`unwrapDETH`, `batchUnwrapDETH`, `reportAndWithdrawETH`) end in: internal 0x38b8 (`totalReportedETHNotWithdrawn[blsKey] -= amount`) → savETHRegistry `0xf2556a85(blsKey, msg.sender, amount)` which burns dETH **from the caller** (traced: `dETH.burn(msg.sender, amount)`, tx 0x3a731f5d…), then AM `withdrawETH(msg.sender, amount)`. Same wei amount in all three calls; recipient = caller. No free/replayed claim.
2. **Reporting (which mints dETH) requires a designated-verifier ECDSA signature** over the report fields + deadline + validator state (`Invalid Report` @0x1144 etc.), with deadline (`Signature expired`) and per-sweep replay marking (`Sweep reported`, `isSweepReported` slot 0xcd) preventing duplicates. Live verifier `0x9785f8e5…` is enabled; forging is not possible from an EOA without the key.
3. **Direct AM calls are blocked** (`Only core`), and the only contract that can pass the core check and moves ETH (`0x64f4fCFb…`) enforces (1). Attacker `unwrapDETH` trace reverts at the savETH gate (`Not minted`), before any ETH movement.
4. **Admin/state surfaces**: `init` consumed; `manageDesignatedVerifier` gated `Only manager`; `updateTotal…` gated `Only core`; `upgradeTo/upgradeToAndCall` are ERC-1967 UUPS paths (upgrade authorization reads slots 0x99/0x4910…; no tx ever upgraded this proxy; admin slot is 0).

---

## 6. Verdict

**An unprivileged attacker cannot extract any of the AccountManager's 64.3057 ETH via the deployed ShanghaiSweepReporting contract.** The blocking gates, specifically:

* `reportSweeps`/`reportAndWithdrawETH`/multi/post-RQ: designated-verifier ECDSA signature (`Invalid Report` @0x1144); deadline (`Signature expired` @0x106d); per-sweep `isSweepReported` (`Sweep reported` @0x366b) + accounting checks — an attacker cannot mint dETH.
* `unwrapDETH`/`batchUnwrapDETH`/`reportAndWithdrawETH` withdrawal leg: burn of caller-owned dETH via savETHRegistry `0xf2556a85` (traced 1:1) + `totalReportedETHNotWithdrawn` decrement (underflow-safe) before AM `withdrawETH(msg.sender, amount)` — no payout without burning your own dETH.
* Direct `AccountManager.withdrawETH(address,uint256)` (0x4782f779): `Only core` (live trace).
* Admin functions: `init` consumed; `manageDesignatedVerifier` `Only manager`; `updateTotal…` `Only core`.

### Uncertainty / open items (honest caveats)

1. **`report.stakeHouse` is NOT covered by the verifier signature** — proven live with the deployed validator (mutation of that field still validates; see `evidence/signature_coverage.json`). Execution uses it: the traced report passed its calldata `stakeHouse` straight into savETHRegistry `mintDETHReserves(stakehouse, blsKey, amount)` (tx 0xa3250dca…, block 19026430, deadline 19026554 = +124 blocks ≈ 25 min: calldata stakehouse == mint arg0 == `0x11778993cf…`; trace `traces/0x556b7541_1_trace.json`). savETH then only checks `universe.stakeHouseToKNOTIndex(stakehouse) != 0` (live: registered stakehouse `0x11778993…`→1, other registered `0xadc1a642…`→7, random address→0) and `stakehouse.hasMemberRageQuit(blsKey) == false` before writing per-stakehouse accounting (disassembly of savETH impl `0xd72ac684…` body 0x2e8b). Consequence sketch: a front-runner could take a valid signed report inside its deadline window (observed window ≈ 2 min to ~25 min of blocks) and swap the (unsigned) stakehouse, changing where the dETH credit lands — **whether that converts to attacker-claimable ETH depends on savETHRegistry internals (credit mapping keyed partly by the supplied stakehouse) and is NOT proven here**. This is the one genuine gating weakness found and it should get a PoC on a fork; it does not, by itself, move ETH from the AM.
2. Exact original function names for the 8 renamed selectors are unverified (private repo); identification is behavioral (calldata shapes, revert strings, traces) and is solid for the roles, less so for literary names.
3. The EIP-712 type string/domain separator could not be extracted from bytecode; the *field coverage* is empirical (Table 1.1).
4. `0xf2556a85` (savETHRegistry burn entrypoint) and `0x4782f779` (AM withdrawETH) names come from openchain lookup/behavior; their internal checks beyond the traces shown (isCoreModule, burn-from-owner, lifecycle, "Not minted") were not fully bytecode-audited (different contracts, other children's scope).

---

## 7. Evidence files (all under `stakehouse/analysis/childA/`)

> NOTE: the parent `stakehouse/analysis/` tree (incl. its `refs/`) was reset by another process during this run; every artifact below was re-generated from mainnet within this folder. The implementation copy used is `evidence/impl_runtime.hex` (eth_getCode block 26179094) — byte-identical to the original on-chain impl.

| File | Content |
|---|---|
| `evidence/impl_runtime.hex`, `evidence/impl_address.txt`, `evidence/impl_slot.txt` | on-chain impl bytecode (block 26179094), address, EIP-1967 slot value |
| `evidence/dispatch_table.json`, `evidence/selector_to_body.json`, `evidence/selector_map.json` | dispatch table (32 entries), stub→body map, deployed↔interface naming |
| `evidence/disasm_full.txt` | full linear disassembly |
| `evidence/region_*.txt` | annotated dumps: reportSweeps p1–p3, reportAndWithdrawETH, post-RQ, multi, batch-post-RQ, unwrapDETH, batchUnwrapDETH, updateTotal, manageVerifier, init, validator, shared internals 0x3300–0x3c00, ECDSA helpers |
| `evidence/calldata_*.hex` | real mainnet calldata per selector (txs listed in `evidence/network_txs.json`) |
| `traces/*_trace.json` | callTracer traces: report flows (mint), batchUnwrapDETH (burn↔withdraw 1:1), attacker paths (init/manage/updateTotal/unwrap/AM) |
| `evidence/signature_coverage.json` | validator oracle results: stakeHouse NOT covered; all other fields covered |
| `evidence/live_checks.json` | live reads: verifier status, AM balance 64.3057 ETH, key accounting, isSweepReported |
| `evidence/revert_reasons.json` | replay/negative eth_call results (`Signature expired`, `Invalid Report`, `Key mismatch`) |
| `evidence/logs_summary.json`, `evidence/logs_sweepreported_page*.json` | 1,931 SweepReported logs; first/last blocks & monthly histogram |
| `evidence/network_txs.json` | tx hashes/blocks used |
| `evidence/IShanghaiSweepReporting.sol`, `evidence/IDataStructures.sol` | interface sources for reference |
| `scripts/extract_dispatch.py`, `scripts/verify_live.py`, `scripts/attacker_paths.py`, `scripts/rebuild_network_evidence.py` | reproducible generation of the above |

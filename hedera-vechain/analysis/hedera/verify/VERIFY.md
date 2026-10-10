# VERIFY — Independent re-verification of H2-06 conclusion (Hedera / Stader HBARX)

**Verifier:** child verification subagent (independent of the parent H2-06 analyst)
**Date:** 2026-10-10 · **Chain:** Hedera mainnet (chain id 295)
**Mode:** read-only. No transactions signed/sent; only keyless public RPC (`https://mainnet.hashio.io/api`), mirror-node REST (`mainnet-public.mirrornode.hedera.com`) and Sourcify reads. No secrets in files.
**Scope:** re-derive from primary sources the parent's claim **E-U = $0.00** for Stader HBARX, independently re-read deployed code/storage, re-run adversary simulations with a *different* attacker, and hunt for any missed unprivileged value path.

---

## VERDICT: **CONFIRMED — E-U = $0.00 (high confidence)**

Every substantive claim re-verified against primary sources (Sourcify payloads, live runtime bytecode, live storage, mirror node, keyless `eth_call`). The deployed code was recompiled locally from the Sourcify sources with solc 0.8.9; the live runtime bytecode is byte-for-byte identical to Sourcify's `onchainBytecode` for all three core contracts, and the compiler layout explains every live storage slot. All unprivileged extraction candidates revert at access/scope gates; no missed path was found.

**Corrections (do not change the verdict; details in §4):** (1) Rewards recipients are owner-*changeable*, not constructor-fixed — the parent's §4.7 text is wrong (its own sims contradict it); (2) node-proxy dust is exactly 2.00 HBAR, not ≤1.0004; (3) mirror snapshot for the staking balance lags the live EVM by 6 tinybar (immaterial); (4) V2 staking is dead also because it is `paused=true`, not only because it lacks the HBARX supply key.

**Live total custody (measured this run):** 411,519,291.46 HBAR ≈ **$38,192,875.72** @ $0.09280944178736515 (DefiLlama, ts 1791637385) — unchanged classification: H-O with a latent privileged (P) overhang. **E-U = $0.00.**

**Reference heights:** Hedera EVM blocks **100,954,251 – 100,954,792** (state reads + sims); latest block ts `1791637793`.

---

## 1. Method (independent re-derivation, not trust)

| Step | What was done | Where |
|---|---|---|
| Source | Fresh Sourcify fetch for `0x…158d97`, `0x…158d71`, `0x…158dac`, `0x…158d72` | `sourcify_*_full.json`, `*.sol` |
| Bytecode | `cast code` vs Sourcify `onchainBytecode`/`recompiledBytecode`, keccak-compared | §2 |
| Layout | Recompiled the verified sources with **solc 0.8.9** (`forge build`, local) → `forge inspect … storage-layout`; matched every live slot to public getters | `solccheck/` |
| Storage | `cast storage` slots 0–26 (staking), 0–6 (undel), 0–10 (rewards), 0–20 (V2 staking) | `raw/reads.log`, `raw/v2s_checks.log` |
| Value | `eth_getBalance` + mirror account reads for all addresses in 0.0.1412455–0.0.1412530 | `raw/mirror_accounts_range.json` |
| Attackers | `0.0.10912431` = `0x…0a682af` (38,057 HBAR, ED25519) and `0.0.10912430` = `0x…0a682ae` — **different from the parent's 0x1111…1111** | `raw/sims_a682af.log`, `raw/sims_second_attacker.log` |
| Sims | 45-call attack matrix + liveness controls, all raw outputs kept | `raw/*.log` |

**Environment note:** Hashio `eth_call` requires the sender to be an existing Hedera account (`Sender account not found` for 0x2222…/0x1111-style non-existent addresses in my first run). My attacker accounts were real, unprivileged, random accounts. Second environment note: JSON-RPC `value`/`balance` are **weibar** (1 tinybar = 1e10 weibar) while contract-internal accounting is **tinybar** — a first `stake()` probe at tinybar scale reverted `invalidDepositAmount` purely for that reason; re-run at 1.00000001 HBAR.

---

## 2. Per-claim verification table

### Claim 1 — V3 Staking `0.0.1412503` / `0x…158d97`
**CONFIRMED (all sub-claims).**
- Sourcify (independent fetch): `match="match"`, `runtimeMatch="match"`, `matchId 26806079`, `verifiedAt 2026-03-25T11:16:59Z`, `proxyResolution.isProxy=false`, compiler `0.8.9+commit.e5eed63a`, contract `contracts/V3/Staking.sol:Staking`.
- Runtime bytecode: live keccak `0x6e681bbb5f26ff95f435a7b61752f3d8b92fef1693394fab4105a4e930dd04a4` **==** Sourcify `onchainBytecode` keccak (21,830 B, `equal=True`). `recompiledBytecode` differs only at byte 21,787 — inside the CBOR metadata (`ipfs` placeholder) — i.e. code identical, metadata-only diff, as expected for `"match"`.
- Balance: `eth_getBalance` = `388247836915426260000000000` weibar = **38,824,783,691,542,626 tinybar = 388,247,836.91542626 HBAR** (parent quoted the identical tinybar value). Mirror snapshot ts 1791619740 read `…620` (Δ = 6 tinybar = $5.6e-7; mirror lag, noted).
- Storage (live) decoded with the recompiled layout:

| slot | raw (live) | decoded |
|---|---|---|
| 0 | 1 | `ReentrancyGuard._status` = 1 (unlocked) |
| 1 | `0x…0cb93500` | `_paused=false` (low byte) ‖ `_owner=0x…cb935` |
| 2 | `0x…0cb935` | `_ownerCandidate` |
| 3 | 14400 | `lockedPeriod` |
| 4 | **0** | `withdrawQueue.length` = **0** (empty, never used — see §3 A3) |
| 5 | `0x…1ad3eb` | `timelockOwner` |
| 6 | `0x…1ad3eb` | `timelockOwnerCandidate` ‖ `isStakePaused=false` ‖ `isUnstakePaused=false` ‖ `nodeStakingActive=false` (packed, all 0) |
| 7 | 1e8 | `minDeposit` (1 HBAR) |
| 8 | 1e20 | `maxDeposit` |
| 9 | 27039345636300414 | `totalSupply` == HBARX supply |
| 10 | 38824639151071461 | `balanceBefore` (stale) |
| 11 | `0x…158dac` | `rewardsContractAddress` |
| 12 | `0x…cba44` | `hbarxAddress` |
| 13 | `0x…14fbab` | `operator` |
| 14 | `0x…158d71` | `undelegationContractAddress` |
| 15 | 26 | `nodeProxyAddresses.length` |

(The parent's published map was correct for these slots; note the 3 pause bools share slot 6, slot 4 confirmed as the queue length.)
- Getters: `owner=0x…cb935` (0.0.833845), `timelockOwnerNewCandidate=0x…1ad3eb` (0.0.1758187), `getExchangeRate=143586254`, `paused=false`, `decimals=1e8`, `nodeProxyAddresses(0)=0x…158D72`, `(25)=0x…158d95`.

### Claim 2 — only unprivileged value paths; fund-mover/operator/admin gates
**CONFIRMED (reproduced with a different attacker `0x…a682af`, and spot-checked with `0x…a682ae`).**
Full ABI enumerated (45 functions + `receive`/`fallback` emit-only, no delegatecall/selfdestruct/assembly in source; bytecode is exactly the compiler output, so none exist).

| # | call (from attacker) | raw result |
|---|---|---|
| 1 | `queueAllFunds(attacker)` | revert `0x83632027` = `invalidOwner()` |
| 2 | `queuePartialFunds(attacker,1e8)` | revert `0x83632027` |
| 3 | `withdraw(0)` / `withdraw(1)` | revert `0x8a581ab7` = `invalidIndex()` (queue length 0) |
| 4 | `cancelWithdraw(0)` | revert `0x83632027` |
| 5 | `proposeTimelockOwner`/`acceptTimelockOwnership`/`cancelTimelockOwnerProposal` | revert `0x83632027` |
| 6 | `pause`/`unpause`/`updateStake(UnP)ause*`/`updateMinDeposit`/`updateMaxDeposit`/`setLockedPeriod`/`setRewardsContractAddress`/`setUndelegationContractAddress`/`updateOperatorAddress`/`updateNodeStakingActive` | revert `Ownable: caller is not the owner` |
| 7 | `acceptOwnership` / `cancelOwnerProposal` | revert `You are not the owner` (candidate = 0xcb935) |
| 8 | `stakeWithNodes([],0)`, `collectRewards([0])`, `withdrawFromNodes()` | revert `0xb25a821e` = `invalidOperator()` |
| 9 | `unStake(1e8)` / `unStake(1)` | revert `0xd96e4d38` = `hbarXTransferFailed()` (HTS `TOKEN_NOT_ASSOCIATED_TO_ACCOUNT`); no HBARX ⇒ no payout |
| 10 | `fallback`/`receive` with value | success, emit only (no accounting effect) |

- `unStake` sender-scoping/fairness control: from the operator (a real HBARX holder) `unStake(1e8)` **succeeds** and returns exactly `0x…088ef3ce` = **143,586,254 tinybar** (= 1 HBARX × live rate) — fair pro-rata, no bonus; the operator does not gain at pool expense.
- Value can only ever move to `msg.sender` (stake/unStake), the fixed `undelegationContractAddress`, the fixed node proxies, or fixed/owner-set reward recipients. Nothing pays an arbitrary attacker-chosen address.

### Claim 3 — V3 Undelegation `0.0.1412465` / `0x…158d71`
**CONFIRMED (and strengthened).**
- Sourcify `exact_match` (`matchId 26566544`), live keccak `0xdb1ec281…2638af` **==** Sourcify onchain+recompiled. Layout recompiled: `_owner(0)=0x…cb935`, `_ownerCandidate+_paused(1)`, `_status(2)=1`, `unbondingTime(3)=86400`, `stakingContractAddress(4)=0x…158d97`, `undelegationsMap(5)`.
- `undelegate(attacker)` value=1 → revert `Only staking contract can undelegate`; value=0 → `Undelegate amount must be greater than 0` (order proven).
- `withdraw(0)`/`withdraw(1)` from a stranger → **Panic `0x4e487b71…32`** (their own array empty, OOB).
- Live pending entry demonstrated (H-O path is real): user `0x…5990ae` (0.0.5869742) unstaked 700 HBARX at ts 1791619740; `undelegationsMap(user,83)` = `(timestamp 1791619740, amount 100510378282 tinybar = 1005.10378282 HBAR)` — exactly 700 × 1.43586254. Controls: owner pre-release → `Release time not reached`; deleted entry → `Undelegation not found`; **stranger `withdraw(83)` → Panic 0x32** (cannot touch another user's entry).
- Recent mirror call history for 0.0.1412465: 100/100 latest calls are `withdraw(uint256)` with `call_result 0x` — users actively claim.

### Claim 4 — V2 legacy pair
**CONFIRMED (stronger reason for death).**
- V2 Undelegation `0.0.1027587` (`0x…fae03`), unverified on Sourcify. Independent selector extraction (opcode-walked dispatch table) = 15 selectors, exactly the V3 Undelegation design (`undelegate(address)`, `withdraw(uint256)`, `setStakingContractAddress`, `setUnbondingTime`, Ownable/Pausable set, `undelegationsMap` getter). Live gates: `undelegate` → same string `Only staking contract can undelegate`; `withdraw(0/1/2)` stranger → Panic 0x32; `pause` → onlyOwner; `stakingContractAddress()=0x…fae04`; `unbondingTime=86400`; `paused=false`; `owner=0x…cb935`. Balance **2,339,387.82465309 HBAR**.
- V2 Staking `0.0.1027588` (`0x…fae04`): balance **0**; `totalSupply=117,394,347.321542295` (stale); `undelegationContractAddress=0x…fae03`; `hbarxAddress=0x…cba44`; **`paused()=true`** → `stake()`/`unStake()` revert `Pausable: paused`; `withdraw(0)` → `No funds to withdraw`; `queueAllFunds`/`cancelWithdraw` → `You are not the owner`. It is additionally not the HBARX supply key (not the treasury either). 35-selector inventory shows no new value-moving path beyond the same Timelock set (`withdrawQueue` length = 3, all entries zeroed — historical cycles, no funds). → dead.
- HBARX supply key = V3 staking contract only (see Claim 6), so V2 `unStake` could never burn; confirmed.

### Claim 5 — V3 Rewards `0.0.1412524` / `0x…158dac`
**CONFIRMED for E-U; one factual correction.**
- Sourcify `exact_match` (`matchId 26567390`); live keccak `0x2cf5e3b8…cca070` == Sourcify; layout: `_owner(0)`, `_ownerCandidate+_paused(1)`, `_status(2)`, `emissionRate(3)=59,027,777`, `genesisTimestamp(4)`, `lastRedeemedTimestamp(5)=1,791,590,069`, `epoch(6)=1433`, `daoFeesPercentage(7)=12`, `stakerAddress(8)=0x…158d97`, `daoAddress(9)=0x…cb932` (0.0.833842). Balance **16,438,854.70851088 HBAR**.
- `distributeStakingRewards()` from attacker → **success (`0x`)**; pays only `stakerAddress` (= V3 staking) and `daoAddress` (0.0.833842), split 88/12. No attacker gain.
- **Correction:** the parent wrote "recipients are constructor-fixed (no setters)". The deployed ABI/source has `setStakerAddress`, `setDaoAddress`, `setDaoFeesPercentage`, `setEmissionRate` — all `onlyOwner` (attack sims → `Ownable: caller is not the owner`). Recipients are *owner-changeable* (P), not attacker-changeable; E-U unchanged, but the privileged surface is slightly larger than the parent described.

### Claim 6 — HBARX token `0.0.834116`
**CONFIRMED.** mirror token: `decimals 8`, `total_supply 27039345636300414` == staking `totalSupply()` (exact), `treasury_account_id = 0.0.1412503` (staking), `supply_key = 0a0418979b56` → decoded protobuf Key/ContractID = **contract 0.0.1412503 only**; `admin_key` = threshold **3 of 5** ED25519; `wipe_key/freeze_key/kyc_key/pause_key/fee_schedule_key = null`; `pause_status = NOT_APPLICABLE`; `custom_fees` empty. Token is live, not deleted. Holders: staking contract dust 126,298 units (0.00126298 HBARX); operator 6.251726 HBARX; NodeProxy owner 7.0185 HBARX; V2 staking 0.

---

## 3. My own attack attempts (creative, falsification-directed)

| # | Hypothesis | Method | Result |
|---|---|---|---|
| A1 | Create a timelock withdrawal paying me | 45-call matrix incl. all Timelock/Ownable/operator fns from two fresh attackers | All gated (§2). No queue entry can be created; `withdraw` has nothing to pay. |
| A2 | Sweep a stale `withdrawQueue` entry | slot4=0 verified via recompiled layout; `withdrawQueue(i)` getter; historical checks | **Length 0.** Also: `delete` does NOT shrink the array (proof: V2 staking length=3 with zeroed entries) → length 0 proves the queue was **never used**. No stale entries can exist. |
| A3 | Steal another user's pending unbond | stranger `withdraw(83)` while user 0x5990ae's 1005.10 HBAR entry is live | **Panic 0x32** — index reads `undelegationsMap[msg.sender]`; attacker's own array is empty. Entry owner pre-release gets `Release time not reached`. No cross-user path. |
| A4 | Rounding gain on `stake`→`unStake` | exact-integer bound with live B,S over 7 magnitudes incl. maxDeposit | Net ≤ **−1 tinybar** every time (floors always favor pool). `raw/attack_math.txt`. |
| A5 | Donation to inflate own claim | analytic: hold fraction x, donate d | Net = (x−1)·d < 0; negative for every x<1. Donations only enrich other holders. |
| A6 | JIT capture of pending reward stream | permissionless `distributeStakingRewards` timing math | Pending now 28,170.42 HBAR = **0.007256%** of pool; capturing 100% requires owning 100% of supply (ROI ≈ 0.007% of cost). Negative. |
| A7 | Reentrancy via `unStake` (no `nonReentrant`) | verified-source control-flow analysis of both contracts; live fair-rate control | `unStake`'s only calls: HTS precompiles (no callback) + fixed `undelegationContractAddress`, whose `undelegate` makes **zero** external calls. No attacker code runs. Operator control `unStake` returned exactly the fair rate. No vector. |
| A8 | Hijack a node proxy's 2 × 1 HBAR | enumerated 26 proxies via getter **and** array storage at `keccak(15)`; sims on the funded ones | `transferFund`/`receiveFunds` = `onlyStakingContract` (stakerAddress = staking, set-once); `lockStakingContract` = onlyOwner + already set; even a hypothetical owner cannot move funds (no owner-withdraw exists). Funds can only return to staking via operator-gated `withdrawFromNodes`. **Not extractable.** |
| A9 | Mint/burn HBARX directly | token key audit + function inventory | Supply key = staking contract only; only mint path is `stake()` pro-rata; no wipe/freeze/kyc. Nothing for an outsider. |
| A10 | Hidden bytecode (delegatecall/selfdestruct/fallback) | source == deployed bytecode equality (hash-proven); grep of sources; ABI fallback/receive emit-only | No hidden code; `fallback`/`receive` only emit events. |
| A11 | Unresolved selector abuse on V2 staking | extracted all 35 dispatch selectors; one unknown `0xd18ab923` (absent in 4byte + openchain) | Unresolvable name, but the contract is **paused**, holds **0 HBAR**, and cannot burn/mint HBARX (not supply key). Immaterial. |
| A12 | Missed value in neighborhood accounts | mirror sweep 0.0.1412455–0.0.1412530 (72 accounts) | Only the 3 known contracts hold material value; dust: 0.00036385 + 1 + 1 + 0.1 + 0.02304822 ≈ 2.13 HBAR in EOA/proxy accounts; nodes proxies exactly 2.00 HBAR, locked to staking flow. No claimable third-party value. |

**Conclusion of adversarial pass: no path found; E-U = $0.00 stands.**

---

## 4. Discrepancies vs the parent's dossier (all non-material to E-U)

1. **§4.7 "Recipients are constructor-fixed (no setters)" — wrong.** `setStakerAddress`/`setDaoAddress`/`setDaoFeesPercentage`/`setEmissionRate` exist and are `onlyOwner`. The parent's own sim rows 17–18 test these setters, contradicting the text. E-U unaffected (owner-gated); latent P surface is larger than described (owner can redirect the entire 16.44M HBAR reward stream and 12% fee flow).
2. **Node-proxy total: 2.000000 HBAR, not "≤1.0004".** Two proxies hold exactly 1 HBAR: `0.0.1412476` (array index 7) and `0.0.1412488` (index 18). Corrected total custody: **411,519,291.46 HBAR ≈ $38,192,875.72** (parent: 411,519,289.46 / $37.91M at a slightly different price).
3. **Mirror snapshot lag:** individual mirror read for 0.0.1412503 = `38,824,783,691,542,620` tinybar (ts 1791619740) vs live EVM `…626` (Δ 6 tinybar). The parent's quoted `…626` matches the live EVM; the mirror discrepancy is a snapshot/timing artifact, immaterial ($5.6e-7).
4. **V2 staking death reason:** parent cited zero balance + not supply key (correct). Stronger: `paused()=true` — `stake()`/`unStake()` revert `Pausable: paused`; `withdraw(0)` → `No funds to withdraw`.
5. **Rewards verification provenance:** parent described it as "matches verified bundle"; in fact Rewards is directly Sourcify-verified (`exact_match`, own `matchId`), which strengthens their claim.
6. **NodeProxy owner:** not mentioned by the parent; actual owner = `0x…c1cb9` (0.0.793785), *not* the main owner 0xcb935 — irrelevant to funds (no owner withdrawal exists), recorded for completeness.
7. **Hashio requirement:** `eth_call` needs an existing sender account; the parent's `0x1111…` works because it resolves as an existing account/alias, but generic "attack" addresses can fail with `Sender account not found` (my first matrix run had to be redone). Future re-runs should use a real, unprivileged account.

---

## 5. Residual / latent risk (unchanged from parent, re-confirmed)

- **P:** `timelockOwner` `0.0.1758187` (3-of-5) can `queueAllFunds(<to>)`; after `lockedPeriod` 14,400 s anyone (even an outsider) can execute `withdraw(index)` paying `<to>` — 100% of staking custody. **Owner** `0.0.833845` (2-of-3) can re-point `undelegationContractAddress` (future unstake HBAR diverted), change operator/rewards, pause user paths; **Rewards owner** (same 0xcb935) can redirect the reward stream. Token admin (3-of-5) can rotate keys. All privileged, none counted as E-U.
- **Liveness:** owner can pause `stake`/`unStake`; node-staking cycles (operator, every ~1.2 days) temporarily flip `nodeStakingActive`; pending unbonds remain claimable after `unbondingTime` (verified live: entry owner can claim after release).
- Would change the verdict: a signature/key compromise of the 2-of-3 owner or 3-of-5 timelock/admin keys (turns P into real loss), or a new unprivileged function appearing in a future code upgrade (none — the contracts are immutable, no proxy).

---

## 6. Files (all under `analysis/hedera/verify/`)

| File | Content |
|---|---|
| `VERIFY.md` | this report |
| `state_check.json` | machine-readable re-read values, gates, discrepancies |
| `sourcify_staking_full.json`, `sourcify_undel_full.json`, `sourcify_rewards_full.json`, `sourcify_nodeproxy_full.json` | independent Sourcify payloads |
| `Staking.sol`, `Timelock.sol`, `Ownable.sol`, `HederaTokenService.sol`, `Undelegation.sol`, `Rewards.sol`, `NodeProxy.sol` | verified sources (re-extracted) |
| `staking_abi.json`, `undel_abi.json`, `rewards_abi.json` | ABIs |
| `live_*_code.hex`, `onchain_sourcify_*.hex`, `norm_sourcify_*.hex` | live vs Sourcify bytecode |
| `solccheck/` | local solc 0.8.9 project + storage layouts |
| `run_reads.sh`, `run_sims.sh`, `token_bal_check.sh` | reproducible read-only scripts (keyless RPC) |
| `raw/reads.log`, `raw/sims_a682af.log`, `raw/sims_second_attacker.log`, `raw/liveness_probes*.log`, `raw/proxy_checks.log`, `raw/v2s_checks.log`, `raw/v2_selector_map.txt`, `raw/attack_math.txt`, `raw/mirror_*`, `raw/user_*` | raw evidence |

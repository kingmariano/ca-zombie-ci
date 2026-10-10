# H2-06 / Hedera — Stader HBARX deep dive

**Date:** 2026-10-10 · **Chain:** Hedera mainnet (HTS + Hedera EVM, chain id 295 / 0x127)
**Status:** read-only; no transactions signed or sent. All proofs are chain-native read-only
simulations (`eth_call` / mirror-node reads) on live state; no fork state was modified.

**Headline: E-U = $0.00 (high confidence).** No external, unprivileged extraction path found.
Custody measured: **411,519,289 HBAR ≈ $37.91M** — holder-recoverable (H-O) or streamed to holders,
with a latent privileged (P) overhang via the 3-of-5 multisig timelock owner (documented, not
counted in E-U).

**Reference heights**
- Hedera EVM block (Hashio `eth_blockNumber`): **100,952,989**
- Mirror-node state/price reads: account-balance timestamps ≈ `1791619740`–`1791631079` (2026-10-10)
- HBAR price (DefiLlama, ts 1791631079): **$0.09212996414711659**

---

## 1. TL;DR table

| Target (Hedera) | Live value measured | Class | **E-U** | Why closed | Latent risk |
|---|---|---|---|---|---|
| Stader V3 Staking `0.0.1412503` | **388,247,836.92 HBAR ≈ $35.77M** | H-O (HBARX backing) | **$0** | only `stake`/`unStake` (sender-scoped, pro-rata); fund-mover `queueAllFunds/queuePartialFunds` = `timelockOwner` only; `withdraw(index)` permissionless but queue length = 0 and pays only owner-set recipient; operator fns `onlyOperator`; admin fns `onlyOwner` | 3-of-5 multisig timelockOwner can `queueAllFunds` → `withdraw` after 4 h (P, 100% of custody); token admin can rotate supply key (P) |
| V3 Undelegation `0.0.1412465` | **4,493,210.01 HBAR ≈ $0.41M** | H-O | **$0** | `undelegate` requires `msg.sender == staking`; `withdraw` reads `undelegationsMap[msg.sender]` and pays `msg.sender` | none found |
| V2 Undelegation (legacy) `0.0.1027587` | **2,339,387.82 HBAR ≈ $0.22M** | H-O (forgotten claims) | **$0** | same design: `withdraw` sender-scoped (OOB → Panic 0x32 for a stranger); `undelegate` gated to dead V2 staking | none found |
| V3 Rewards `0.0.1412524` | **16,438,854.71 HBAR ≈ $1.51M** | H-O\* (reward pool) | **$0** | `distributeStakingRewards()` is permissionless but pays fixed `stakerAddress` (staking, 88%) + `daoAddress` (12%); no setter for recipients | none found (no attacker gain) |
| HBARX token `0.0.834116` | supply **270,393,456.363 HBARX** | — | **$0** | supply key = V3 staking contract only; no wipe/freeze/kyc/pause keys | admin 3-of-5 can change keys/supply key (P) |
| V2 Staking (dead) `0.0.1027588` | 0 HBAR | S/dead | **$0** | balance 0; not the HTS supply key holder → `unStake` burn impossible | none |
| NodeProxy ×26 (`0.0.1412466…1412495`) | 2.00 HBAR total | — | **$0** | `receiveFunds/transferFund` = `onlyStakingContract`; all empty (node staking inactive) | operator could re-activate node flow (P, no value at risk today) |

\* rewards pool is protocol-owned and streamed to holders (88%) + dao (12%); see §5.

---

## 2. Contract reconstruction (deployed reality)

All contracts are **immutable (no proxies)**: Sourcify `proxyResolution.isProxy=false`; mirror-node
`admin_key=null` on the contract accounts.

| Role | Account | EVM address | Evidence |
|---|---|---|---|
| V3 Staking | `0.0.1412503` | `0x…158d97` | Sourcify **match**, `contracts/V3/Staking.sol:Staking`, solc 0.8.9 |
| V3 Undelegation | `0.0.1412465` | `0x…158d71` | Sourcify **match**, `contracts/V3/Undelegation.sol:Undelegation` |
| V3 Rewards | `0.0.1412524` | `0x…158dac` | read from Staking storage slot 11; `Rewards.sol` (matches verified bundle) |
| NodeProxy ×26 | `0.0.1412466`…`0.0.1412495` (8 active entries) | `0x…158d72`… | Sourcify match, `NodeProxy.sol` |
| HBARX token | `0.0.834116` | `0x…cba44` | HTS; 8 decimals; supply **270,393,456.363300414** |
| V2 Staking (dead) | `0.0.1027588` | `0x…fae04` | balance 0; `undelegationContractAddress()=0x…fae03` |
| V2 Undelegation | `0.0.1027587` | `0x…fae03` | `stakingContractAddress()=0x…fae04`; unverified but selector-set ≡ V3 Undelegation (see §4.6) |
| Ownable owner | `0.0.833845` | `0x…cb935` | **2-of-3** ED25519 KeyList |
| Timelock owner | `0.0.1758187` | `0x…1ad3eb` | **3-of-5** ED25519 KeyList (same key bytes as HBARX token admin key) |
| Operator | `0.0.1375147` | `0x…14fbab` | single ED25519 key |
| DAO address | `0.0.833842` | `0x…cb932` | `Rewards.daoAddress()` |

Storage decode of V3 Staking (calibrated against public getters):
slot1 = `_paused(0)‖owner(0xcb935)`; slot2 `ownerCandidate=0xcb935`; slot3 `lockedPeriod=14400`;
**slot4 `withdrawQueue.length = 0`**; slot5 `timelockOwner=0x1ad3eb`; slot6 `timelockOwnerCandidate=0x1ad3eb`;
slot9 `totalSupply=27039345636300414`; slot10 `balanceBefore=38824639151071461`;
slot11 `rewardsContractAddress=0x158dac`; slot12 `hbarxAddress=0xcba44`; slot13 `operator=0x14fbab`;
slot14 `undelegationContractAddress=0x158d71`; slot15 `nodeProxyAddresses.length=26`.

Live flags: `paused=false`, `isStakePaused=false`, `isUnstakePaused=false`, `nodeStakingActive=false`,
`getExchangeRate()=143586254` (1.43586254 HBAR/HBARX), `lockedPeriod=14400` (4 h), `minDeposit=1 HBAR`,
`maxDeposit=1e12 HBAR`.

## 3. Live value (exact reads)

| Account | HBAR | USD @ $0.09213 | Note |
|---|---:|---:|---|
| `0.0.1412503` V3 Staking | 388,247,836.91542625 | $35,769,259.30 | `eth_getBalance` = 388247836915426260000000000 weibar; mirror = 38,824,783,691,542,626 tinybar |
| `0.0.1412465` V3 Undelegation | 4,493,210.00823861 | $413,959.28 | pending withdrawals, unbondingTime = 86400 s |
| `0.0.1027587` V2 Undelegation | 2,339,387.82465309 | $215,527.72 | legacy unclaimed |
| `0.0.1412524` Rewards | 16,438,854.7085 | $1,514,511.09 | emissionRate 59,027,777 tinybar/s ≈ 51,000 HBAR/day → ~322 days remaining |
| Node proxies (26) | 2.00 | ~$0 | all empty; node staking inactive |
| **Total custody** | **411,519,289.4568** | **$37,913,257.38** | |

Token supply (mirror, `0.0.834116`): total_supply `27039345636300414` = V3 staking `totalSupply()`
(exact match). Supply key = contract `0.0.1412503` (decoded `0a0418979b56` → contract 1412503);
admin key = 3-of-5 KeyList; **wipe/freeze/kyc/pause keys absent**.

## 4. Adversarial audit of every value-moving path

### 4.1 V3 Staking — user functions
- `stake()` (payable, `whenNotPaused nonReentrant`): requires rewards balance > 0; mints
  `msg.value × totalSupply / (balance − msg.value)` (floor → favors pool). No extraction; staker
  receives exactly pro-rata HBARX.
- `unStake(amount)`: requires HBARX **allowance + balance** from `msg.sender` (HTS
  `transferToken(hbarx, msg.sender, this, amount)`); burns it; pays
  `amount × balance / totalSupply` (floor) into the undelegation contract recorded to `msg.sender`.
  Sender-scoped. No `nonReentrant`, but the only external call is to the trusted, immutable
  undelegation contract (no callback) — no reentrancy vector.
- Rate manipulation (donation / JIT): donations only benefit all holders pro-rata; capture would
  require owning ~all 270.4M HBARX. Pending reward chunk ≈ 17.7k HBAR on a 388M HBAR pool
  (≈0.0046%) — economically null; noted, not exploitable.

### 4.2 V3 Staking — fund-mover functions (Timelock)
- `queueAllFunds(to)` / `queuePartialFunds(to, amount)` — `checkOwner` = **timelockOwner** (`0.0.1758187`, 3-of-5). Attacker simulation → revert `0x83632027` (`invalidOwner`).
- `withdraw(index)` — permissionless trigger, `nonReentrant`; pays only `withdrawQueue[index].to`
  after `lockedPeriod`; **queue length = 0** (slot 4 = 0; `withdraw(0)` → `0x8a581ab7` `invalidIndex`).
- `cancelWithdraw` — timelockOwner only (`0x83632027`).
→ No unprivileged entry can be created; no funds can be redirected.

### 4.3 V3 Staking — node-staking functions
- `stakeWithNodes`, `collectRewards`, `withdrawFromNodes` — `onlyOperator` (`0.0.1375147`). Attacker sims → `0xb25a821e` (`invalidOperator`). Operator can only move funds to/from the 26 fixed NodeProxy contracts; NodeProxy `receiveFunds/transferFund` are `onlyStakingContract`, so funds cannot leave the system to an operator-chosen address.

### 4.4 V3 Staking — admin functions
- `pause/unpause`, `updateStakeIsPaused/updateUnStakeIsPaused`, `updateMinDeposit/updateMaxDeposit`,
  `setRewardsContractAddress`, `setUndelegationContractAddress`, `updateOperatorAddress`,
  `updateNodeStakingActive` — `onlyOwner` (`0.0.833845`, 2-of-3). Attacker sims → `Ownable: caller is not the owner`.
  `updateNodeStakingActive` can only *freeze* user paths (liveness), it cannot redirect funds.

### 4.5 V3 Undelegation
- `undelegate(to)` — `require(msg.sender == stakingContractAddress)`; attacker with value=1 →
  revert `Only staking contract can undelegate`. Records `undelegationsMap[to]`.
- `withdraw(index)` — reads `undelegationsMap[msg.sender][index]`, pays `msg.sender` after 86400 s;
  stranger with no entry → Panic `0x32` (OOB). Sender-scoped; H-O.
- `setStakingContractAddress` — settable once, `onlyOwner`; already set to `0x…158d97`.
- `setUnbondingTime`, `pause/unpause` — `onlyOwner`.

### 4.6 V2 legacy pair
- V2 Staking `0x…fae04`: balance 0; `totalSupply()` stale (117,394,347.321 HBARX-era units);
  HTS supply key is held by **V3** staking, so V2 `unStake` cannot burn/mint → dead.
- V2 Undelegation `0x…fae03`: 2,339,387.82 HBAR; `stakingContractAddress()=0x…fae04`;
  `unbondingTime()=86400`; `paused=false`. Selector set extracted from runtime bytecode
  (`withdraw(uint256) 2e1a7d4d`, `undelegate(address) da8be864`, `pause 8456cb59`, `unpause 3f4ba83a`,
  `acceptOwnership 79ba5097`, `proposeOwner b5ed298a`, `setStakingContractAddress 1c1f8aa3`,
  `setUnbondingTime 6a3d9251`, getters) ≡ V3 Undelegation design. Stranger `withdraw(0)` → Panic `0x32`
  (sender-scoped, out-of-bounds); mirror-node call history shows a **successful withdraw on 2026-01-06**
  (`1767671074`) → path still live. Unclaimed user balances (H-O).

### 4.7 Rewards
- `distributeStakingRewards()` — permissionless (`whenNotPaused nonReentrant`); attacker sim returns
  success. Pays `epochDelta × emissionRate` to `stakerAddress` (staking) minus `daoFeesPercentage=12%`
  to `daoAddress=0.0.833842`. Recipients are **owner-settable** (`setStakerAddress`/`setDaoAddress`/
  `setDaoFeesPercentage`, all `onlyOwner`; attacker sims revert `Ownable: caller is not the owner`).
  No attacker gain; repeated calls simply stream the same rate×time. Owner can only change
  `emissionRate`/recipients/fee.

### 4.8 HBARX token (HTS)
- Supply key = V3 staking contract (only it can mint/burn). No wipe/freeze/kyc/pause keys → no
  admin confiscation of user HBARX. Admin key (3-of-5) can rotate keys (P), not extract directly.

## 5. Classification & totals

| Category | HBAR | USD | Basis |
|---|---:|---:|---|
| **E-U** | **0** | **$0.00** | every extraction candidate reverts at an access/scope gate (sims in §6) |
| H-O | 411,519,289.46 | $37,913,257.38 | staking backing redeemable by HBARX holders (unStake), pending withdrawals (V3 4.49M + V2 2.34M), rewards pool streamed to holders (16.44M; 12% dao) |
| P | 0 counted | $0 | latent overhang: timelockOwner 3-of-5 can `queueAllFunds` → `withdraw` after 4 h (100% of staking custody); owner can pause; token admin can rotate supply key. Documented, not counted to avoid double counting |
| S | 0 | $0 | no bricked value; all claim paths verified live |

## 6. Proof / simulations (all read-only `eth_call`, no state change)

RPC: `https://mainnet.hashio.io/api` (keyless). Attacker address `0x1111…1111`.

| # | Call (from attacker) | Result | Gate proven |
|---|---|---|---|
| 1 | `queueAllFunds(attacker)` | revert `0x83632027` | `invalidOwner` (timelock) |
| 2 | `queuePartialFunds(attacker, 1e18)` | revert `0x83632027` | `invalidOwner` |
| 3 | `withdraw(0)` | revert `0x8a581ab7` | `invalidIndex` (queue empty) |
| 4 | `cancelWithdraw(0)` | revert `0x83632027` | `invalidOwner` |
| 5 | `updateNodeStakingActive()` | revert `Ownable: caller is not the owner` | owner-gated |
| 6 | `pause()` | revert `Ownable: caller is not the owner` | owner-gated |
| 7 | `stakeWithNodes([],0)` | revert `0xb25a821e` | `invalidOperator` |
| 8 | `collectRewards([0])` | revert `0xb25a821e` | `invalidOperator` |
| 9 | `unStake(1e8)` | revert `0xd96e4d38` / `INSUFFICIENT_TOKEN_BALANCE` | needs own HBARX+allowance |
| 10 | V3 Undelegation `undelegate(attacker)` (value 1) | revert `Only staking contract can undelegate` | staking-only |
| 11 | V3 Undelegation `withdraw(0)` | Panic `0x32` | sender-scoped OOB |
| 12 | V2 Undelegation `withdraw(0)` | Panic `0x32` | sender-scoped OOB |
| 13 | Rewards `distributeStakingRewards()` | success (`0x`) | permissionless but pays fixed staking/dao |
| 14 | `setUndelegationContractAddress(attacker)` | revert `Ownable: caller is not the owner` | owner-gated |
| 15 | `setRewardsContractAddress(attacker)` | revert `Ownable: caller is not the owner` | owner-gated |
| 16 | `updateOperatorAddress(attacker)` | revert `Ownable: caller is not the owner` | owner-gated |
| 17 | Rewards `setStakerAddress(attacker)` | revert `Ownable: caller is not the owner` | owner-gated |
| 18 | Rewards `setDaoAddress(attacker)` | revert `Ownable: caller is not the owner` | owner-gated |

CI: `ci/run.sh` re-runs the full matrix against live state and writes `ci-out/hedera_probes.json`
with pass/fail per probe (run URL in `../README.md`).

**CI evidence:** run 1 — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38049734864
(23/23 probes PASS, Hedera EVM block 100,953,284; artifact
[`result-hedera-vechain`](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38049734864/artifacts/11669405500)).
A final re-run covers the extended probe set (rows 14–18) plus the other chains.

## 7. Residual / latent risk

1. **P (privileged) overhang — 100% of custody:** timelockOwner `0.0.1758187` (3-of-5 ED25519, same
   key list as HBARX admin) can `queueAllFunds(<addr>)` and, after 4 h, anyone (even the attacker)
   can execute `withdraw(index)` paying `<addr>`. Key compromise ⇒ $35.8M staking custody at risk.
2. **Owner `0.0.833845` (2-of-3)** can pause user paths and change the undelegation/rewards/operator
   addresses → can re-point `undelegationContractAddress`; combined with timelock powers, P.
3. **JIT reward capture:** bounded to the pending distribution delta (≤ ~0.0046% of TVL per cycle at
   today's sizes); not profitable net of market cost of HBARX.
4. **Liveness:** `updateNodeStakingActive`/pause can block `stake/unStake`; users' claims remain
   honored in the undelegation contracts.

## 8. Coverage statement

- **Fully audited:** V3 Staking (verified source ≡ deployed bytecode, full function inventory,
  live storage decode, 13 live attack simulations), V3 Undelegation (verified source + sims),
  Rewards (source + live reads + sim), NodeProxy (source + empty balances), HBARX HTS keys,
  V2 legacy pair (selectors + live calls + historical success), role accounts (key structures).
- **Not deep-dived:** none material. The 26 NodeProxy instances were checked for balances and one
  source (all share the template); no value present.

## 9. Files

- `state.json` — machine-readable dump (addresses, balances, slots, flags, USD).
- `Staking.sol`, `Undelegation.sol`, `Rewards.sol`, `Timelock.sol`, `NodeProxy.sol`, `Ownable.sol` — verified sources.
- `staking_v3_abi.json`, `staking_v3_sources.json`, `undel_v3.json` — Sourcify payloads.
- `v2_undel_selectors.txt` — selector extraction.
- `ci/probe_hedera.sh` — CI probe script (called by `../ci/run.sh`).

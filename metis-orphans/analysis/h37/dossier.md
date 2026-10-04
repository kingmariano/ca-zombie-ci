# H-37 — "Mining" contract `0x7077f35063f17EE1B84678334d261Ccf47980271` (Metis Andromeda, chain 1088)

**Subject:** Metis DAC staking/mining contract holding **13,217.96182843 METIS**.
**Verdict:** **H-O** — the entire balance is *user principal held for stakers*, wei-for-wei collateralized. Unprivileged attacker extractable today: **0 METIS**. Not owner-withdrawable. Not stuck (each staker can retrieve principal via `emergencyWithdraw`).
**Confidence:** high.

---

## 1. Live state (pinned block)

All reads at **block 23238720**, hash `0x0a85059fa9d18b1aac4f58222ae01b38c6389b4b9ece1e7046dfa3c41409a8f3`, ts `1791091696` (2026-10-04T05:28:16Z). RPCs: `andromeda.metis.io` + cross-check `metis.drpc.org`.

| Field | Value |
|---|---|
| `owner()` | `0x855E37b6068a44BdAb574c86C1817a374623225E` (EOA; deployer; creation tx `0x6c2524…38d4`, block 2260, 2021-11-25) |
| `paused()` | **true** — since `setPaused(true)` tx `0x8115169b…5ee0`, block **751102** (2022-02-04 08:36:30Z). Only `setPaused` call ever; never unpaused. |
| `Metis()` | `0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000` (symbol "Metis") |
| `MetisPerSecond()` | **0** (set to 0 at block 594699, 2022-01-22 06:56:40Z, tx `0xa840203f…633b`) |
| `startTimestamp()` | `1637996400` (2021-11-27T07:00:00Z, past) |
| `totalAllocPoint()` | `100` |
| `poolLength()` | `2` |
| `teamAddr()` | `0x0` |
| `distributor()` | `0xD45Ad4eE4FF123aaB5649Baf5081298372dcfE43` |
| `DAC()` | `0xa030a0983f3427BeD5472435A347DB334a1dC8e8` (TransparentUpgradeableProxy; impl `0x6aa0ABD1…b279`, ProxyAdmin `0x4196AAf5…7873`) |
| `DACRecorder()` | `0xF8CafA257658131Bf781Fd2e48c916eD690267eF` |
| `MIN_DEPOSIT` / `MAX_DEPOSIT` | `10e18` / `2000e18` |
| **METIS balance** | **`13217961828430000000000` wei = 13,217.96182843 METIS** (identical on both RPCs) |

### Pools (both stake METIS itself, not LP tokens)

| pid | token | allocPoint | lastRewardTimestamp | accMetisPerShare | Σ `userInfo.amount` |
|---|---|---|---|---|---|
| 0 | METIS | 0 | 1642834600 (2022-01-22) | 0 | **0** |
| 1 | METIS | 100 | 1666077678 (2022-10-18) | 363665918906146 | **13,217.96182843 METIS** |

### Principal invariant — the decisive check

For **all 4,850 unique participants ever** (from 7,027 `Deposit` / 10,509 `Withdraw` / 763 `EmergencyWithdraw` events; deduped), I batched 9,700 `userInfo(pid,user)` calls at the pinned block:

```
Σ_pid Σ_user userInfo[pid][user].amount = 13,217,961,828,430,000,000,000 wei
contract METIS balance                  = 13,217,961,828,430,000,000,000 wei
delta = 0 wei
```

The contract holds **exactly** the stakers' principal: no excess rewards, no dust, no deficit. 268 addresses still have a nonzero stake (top 10 = 60.0%; largest = 2000 METIS = `MAX_DEPOSIT`). Full per-user map: `userinfo_all.json`.

### Exit-path tests (eth_call at pinned block)

- `emergencyWithdraw(1)` from top holder `0xab917dab…8e43` → **succeeds** (would return 2000 METIS).
- `withdraw(0x0,1,0)` from same → **reverts `paused`**.
- `pendingMetis(now,1,top)` → `5.39227188496272 METIS` — this is a *DACRecorder vault* reward (`sendRewardToVault`), **not** paid from Mining's METIS; frozen while paused.

---

## 2. Source audit — money paths (`h37_mining.sol`, identical to official `MetisProtocol/Metis-Mining` `contracts/Mining.sol`)

METIS leaves the contract in exactly four places; **no admin sweep exists**:

| Function | Guards | METIS movement | Can it exceed own entitlement? |
|---|---|---|---|
| `deposit(_creator,_user,_pid,_amount,_dacId)` | **`onlyDAC`**, `notPaused` | `safeTransferFrom(_user, this, _amount)` — pulls collateral **in**; `user.amount = user.amount + _amount` only in the same `dacState == Active` branch that enforces `MIN_DEPOSIT ≤ remaining ≤ MAX_DEPOSIT` | No — amount recorded ⟺ equal METIS received |
| `withdraw(_creator,_pid,_amount)` | `notPaused`; creator: `isCreator(msg.sender)`; member: `!isCreator(msg.sender) && _creator == creatorOf(msg.sender)` | `safeTransfer(msg.sender, _amount)` after `remaining = user.amount.sub(_amount)` (SafeMath) | No — `_amount ≤ userInfo[pid][msg.sender].amount` |
| `dismissDAC(_dacId,_pid,_creator)` | `onlyDAC`, `notPaused`, **`DAO_OPEN` (currently false)**, `isCreator(_creator)` | `safeTransfer(_creator, creator.amount)`; amount→0 | No — pays the creator their own recorded amount |
| `emergencyWithdraw(_pid)` | **`require(paused)` only** (no DAC identity check) | `safeTransfer(msg.sender, user.amount)`; then amount→0, rewardDebt→0 | No — caller's own amount only |

`updatePool`/`massUpdatePools` are permissionless but only call `distributor.distribute(...)` (mints METIS **to DACRecorder**) and update `accMetisPerShare`; they never touch the contract's METIS.

### Reward accounting / DAC gating

- Rewards are **minted** via the external `distributor` and credited to `DACRecorder` (`Mint` event); user reward claims are paid by `DACRecorder.sendRewardToVault` **out of DACRecorder's own balance** (`stakedMetis` = 105,376.88 METIS), to a `Vault` for the user. Mining's METIS balance is never a reward source.
- **Deposit is `onlyDAC`.** The DAC (`createDAC` / `joinDAC` / `increaseDeposit` in the official `DAC.sol`) checks `Metis.allowance(msg.sender, Mining) >= amount` and Mining then pulls `amount` **from the beneficiary** with `safeTransferFrom(_user, …)`. `joinDAC` is additionally invitation-code gated; `createDAC` requires the user not already be in a DAC. So `user.amount` can never be inflated without an equal, real METIS deposit — a DAC membership gate (whitelist-like) plus 1:1 collateral.
- `DACRecorder.checkUserInfo`/`userWeight` drive reward shares, not principal.

### Classic-bug checklist (all checked, none exploitable for theft)

- **(a)** `emergencyWithdraw` **does** reset `rewardDebt = 0` → no double-dip.
- **(b)** `updatePool` is called before user actions in `deposit` (L820), `withdraw` (L880), `dismissDAC` (L937).
- **(c)** `add`/`set`/`setMetisPerSecond`/`setMinDeposit`/`setMaxDeposit`/`setStartTimestamp` are `onlySetter`; `setter` is private and has **no setter-change function** (= deployer).
- **(d)** SafeMath is used throughout despite solc 0.6.12; underflow reverts (worst case DoS on a stale-weight user, not theft).
- **(e)** `pendingMetis` is view-only, DAC-weight based, capped by distributor balance; not used in state.
- **(f)** No DAC membership bypass to uncollateralized `user.amount` (see above).
- **(g)** Zero-amount `deposit` only re-bases `rewardDebt` (harvest); no METIS out.
- **(h)** No reentrancy guard, but METIS is a plain ERC20 (no hooks) and the balance equals the principal sum exactly, so there is no excess to double-spend; `withdraw` updates `user.amount` before the transfer.
- **(i)** `setTeamAddr`/`setDistributor` are `onlyOwner`; `teamAddr=0`; they redirect newly minted rewards, not principal.
- **(j)** No pause bypass: `deposit`/`withdraw` are `notPaused`, `emergencyWithdraw` intentionally requires `paused`.
- **(k)** `startTimestamp` is in the past; emissions already 0.
- **(l)** The only permissionless METIS mover is `emergencyWithdraw` (own amount).

---

## 3. Exploit-path analysis (formulas)

For any attacker `A` without a stake:

```
max_extractable(A) = Σ_pid userInfo[pid][A].amount
```

- `A` has never deposited → `userInfo[pid][A].amount = 0` for all pids → `max_extractable = 0`.
- `A` cannot increase it: `deposit` is `onlyDAC`; every DAC deposit path pulls an equal amount of METIS from `A` (so net gain 0, and `MIN_DEPOSIT=10 METIS`/`MAX=2000`), and deposits are currently blocked by `paused=true` anyway.
- `withdraw` reverts (`paused`) and in any case pays only `A`'s own recorded amount.
- `dismissDAC` requires `onlyDAC` **and** `DAO_OPEN == false` → reverts.
- `emergencyWithdraw` pays only `A`'s own recorded amount (0 for `A`).
- No owner function transfers METIS to the owner or anyone else; owner can only pause/unpause and change addresses.

For each of the 268 current stakers `S`: `emergencyWithdraw(1)` returns exactly `userInfo[1][S].amount` (verified by successful simulation for the top holder). Σ over all stakers = 13,217.96182843 METIS = contract balance, so every claim is fully backed; there is no "last withdrawer" shortfall.

**Adjacent note (not H-37's balance):** `emergencyWithdraw` does not clear DACRecorder state (`stakedMetis`/weights stay stale), and it zeroes `rewardDebt`, so if the owner ever unpauses, a user could re-claim pending DAC-vault rewards (`weight·share/1e18 − 0`). That is a potential drain on the **DACRecorder vault** (105,376.88 METIS), not on this contract's 13,217.96 METIS.

---

## 4. Web research

- Project: **Metis DAC staking** ("Metis Mining", official repo `github.com/MetisProtocol/Metis-Mining`; deployed `Mining.sol` is identical to the repo, whitespace-only diff).
- Official announcement: `metis.io/blog/metis-dac-staking-starts-nov-26` — stake 10–2,000 METIS, rewards from Nov 26 2021, first-second output 0.0185 METIS/sec.
- User reports: Reddit `r/METIS_IO` "Metis DAC – stuck tokens but can't connect" and "Mining" ("the DAC is already closed, only can do staking") — consistent with the Feb-2022 pause and the need to use `emergencyWithdraw`.
- No exploit/hack incident found for this contract; owner `0x855E37b6…225E` is an EOA, not publicly identified (active Metis user/deployer; routescan/metisscan profile).

---

## 5. Final classification

| | |
|---|---|
| **Classification** | **H-O — user principal held for stakers** |
| **Exact amount** | **13,217.96182843 METIS** (`13217961828430000000000` wei) |
| **USD @ METIS $10 (task baseline)** | **$132,179.62** |
| Live reference (CoinGecko 2026-10-04, $3.41) | ~$45,073 (informational only) |
| **Unprivileged attacker take TODAY** | **0 METIS** |
| Owner-withdrawable | **No** (no sweep function) |
| Stuck | **No** — retrievable by each staker via `emergencyWithdraw` while paused (simulated successfully); reward claims are frozen, principal is not |
| **Confidence** | **High** |

**Three strongest reasons**

1. **Wei-exact collateralization:** batched on-chain `userInfo` for all 4,850 participants gives Σ `user.amount` = 13,217.96182843 METIS = contract balance **exactly, delta 0 wei** (cross-checked on two RPCs). There is no excess to steal and no shortfall.
2. **Every outbound METIS transfer is caller-scoped:** the only movers are `withdraw` (≤ caller's own `user.amount`), `emergencyWithdraw` (caller's own amount), `dismissDAC` (`onlyDAC` + `DAO_OPEN=false` → reverts), plus `deposit` pulling collateral in; no admin sweep exists. An attacker with no stake extracts 0.
3. **No uncollateralized way to inflate `user.amount`:** `deposit` is `onlyDAC`, and all DAC entry paths (`createDAC`/`joinDAC`/`increaseDeposit`) require the user's METIS allowance and result in `safeTransferFrom(_user, Mining, amount)` — 1:1 backing; deposits are additionally frozen by `paused=true` since block 751102 (2022-02-04).

Evidence: `evidence.json`, `userinfo_all.json`, `mining_logs_dedup.json`, `gh_Mining.sol`, `gh_DAC.sol`, `gh_DACRecorder.sol` — all in `/home/heisenberg/CA/metis-orphans/analysis/h37/`.

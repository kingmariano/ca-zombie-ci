# C-24 — DxSale legacy Liquidity Locker: live extractable-value determination

**Campaign:** zombie-hunt · **Chain(s):** BNB Chain (primary), Ethereum, Polygon, Arbitrum, Avalanche, Gnosis, Celo, Harmony · **Date of work:** 2026-10-03
**Status:** read-only research; PoC/fork tests verified on local BSC forks only (via GitHub Actions runners). **No mainnet transactions sent.**
**Scope:** the DxSale legacy LP-locker family (finding C-24): the drained v1 locker `0xEb3a…` plus every sibling deployment/fork found on-chain; owner-privileged vs permissionless extraction paths; live custody of all lockers.

---

## TL;DR

| Surface | Live unprivileged extractable (E-U theft) | Why | Latent / privileged (P) |
|---|---|---|---|
| **v1 buggy locker `0xEb3a` (BSC, ~$400k custody)** | **$0.00** (max theoretical surplus **$0.001** dust) | Replay bug is live (fork-proven with a real unprivileged record), but every still-locked record's token balance is fully covered by **that same wallet's own records** — replay only returns the holder's own funds early, never a third party's | Owner records can drain one contested token: **$745.27** |
| **v1-family lockers ETH `0x1Ba00C14`, Polygon `0xEb3a`** | **$0** | Only dead/unpriced tokens remain; no surplus over record entitlements | — |
| **Fixed family** (`0x5b5e`, `0x8655`, ETH/Poly/Avax/… siblings, ~$6.8M custody) | **$0** | Verified source: time-gated single claim; `platformRelease` is owner-only and pays **the beneficiary** | Owner can release a user's lock early **to that user**; owner cannot take funds |
| **Variant family** (`0x2D0454`, `0x81E0eF68` BSC; ETH `0x916a…`; etc., ~$1.09M custody) | **$0** | Fork-tested: single claim, caller-scoped, payout = recorded amount; no replay, no owner sweep | None found |
| **V3 escrow registry** (`0xFEE2…` BSC, 2,558 locks / 1,020 funded escrows, ~$4.32M) | **$0** | Each escrow is Ownable by its beneficiary; `unlockTokensAfterTimestamp()` is owner-gated and pays the owner | None found |
| **Aggregate locked custody** | — | H-O **$8.85M** (holders' claims incl. early self-withdrawals) + S **$3.73M** (time-locked/stuck) | P **$745.27** |

**Total live extractable by an external unprivileged attacker (theft of others' funds): ≈ $0.00** (high confidence).
**Total directly extractable by the current owner/admin: $745.27** (the attacker-held v1 locker can drain one contested token; no owner sweep exists anywhere else).
The remaining custody (~$12.58M measured) is **other people's locked funds**, recoverable by their owners (H-O) or time-locked (S), not extractable by a third party.

**The broken-lock-integrity note:** on the v1 lockers, ~$100k of still-locked (2030–2100 unlock dates) deposits can be withdrawn **now** by their own holders through the replay bug — a real failure of the "locked until" promise, but self-service, not theft.

---

## 1. The mechanism, exactly

### 1.1 Verified source of the drained locker

`0xEb3a9C56d963b971d320f889bE2fb8B59853e449` (BSC) is **verified** as `DxLockLPDep` (solc 0.6.12) — despite the incident write-ups saying it was unverified. The relevant function, verbatim:

```solidity
function unlockToken(uint256 userLockerNumber) public {
    require(DXLOCKERLP[msg.sender][userLockerNumber].exists, "err: LockDep - user doesnt have a locker!");
    require(DXLOCKERLP[msg.sender][userLockerNumber].locked, "err: LockDep - user's tokens are not locked!");
    uint256 payoutAmount = DXLOCKERLP[msg.sender][userLockerNumber].lockedAmount;
    require(payoutAmount > 0, "err: LockDep - must have atleast 1 payout vested!");

    if (block.timestamp > DXLOCKERLP[msg.sender][userLockerNumber].lockedTime) {
        DXLOCKERLP[msg.sender][userLockerNumber].locked = false;
    }

    require(IERC20(DXLOCKERLP[msg.sender][userLockerNumber].lpAddress).balanceOf(address(this)) >= payoutAmount, "err: Locker - no more tokens left to refund");
    require(IERC20(DXLOCKERLP[msg.sender][userLockerNumber].lpAddress).transfer(msg.sender, payoutAmount), "err: Locker - Token refund to creator failed!");
    emit onUnlock(msg.sender, ...);
}
```

**The bug:** the time check is inverted. When a lock is **still active** (`block.timestamp <= lockedTime`), the function **does not revert and does not consume the record** — it pays out `lockedAmount` on every call. Only *after* expiry does it clear the `locked` flag (making the post-expiry claim single-use). A still-locked record is therefore an infinite money printer against the locker's whole balance of that token:

- `createLocker` (payable, `lockFees`) records a lock and pulls the tokens via `transferFrom`; `_locktime` must be **in the future** — so every attacker lock is a "still active" record.
- Replay transfers `lockedAmount` repeatedly until `balanceOf(locker) < lockedAmount`, i.e. it drains **all other lockers' funds for that token** (floor division remainder stays).
- The attacker created 1,035 records (all locked until 2036) and replayed them; DarkNavy measured **667,465 `onUnlock` events in 1,362 txs across 45 LP tokens**; public reporting: ~$7.3M.

The May-2026 incident was executed by the locker's **owner** (ownership moved to `0xC457…` ~269 days earlier, ~80 hops), but the replay itself is a **permissionless primitive**: any record holder can do it with no owner rights. The attacker additionally used `changeFees(1)` to make record creation cheap and an EIP-7702 batch account to spam calls.

### 1.2 The fixed family (same product, patched)

`0x5b5e94485c9628793B01A38762921Dc37B6829b6` (BSC) is also verified `DxLockLPDep` (0.6.12). Its `unlockToken` starts with:

```solidity
require(block.timestamp > DXLOCKERLP[msg.sender][userLockerNumber].lockedTime, "tokens are still locked");
```

then clears `locked` and pays **once**. `platformRelease(lockerOwner, index)` is `onlyOwner` and transfers to `lockerOwner` (the beneficiary) — an early-release convenience, **not** an owner withdrawal. No sweep function exists.

### 1.3 The variant family (older DxLock code)

`0x2D045410f002A95EFcEE67759A92518fA3FcE677` and `0x81E0eF68e103Ee65002d3Cf766240eD1C070334D` (BSC) plus siblings on other chains use an older struct/ABI (different `createLocker` selector `0x129fa7e8`, no `platformRelease`, extra vesting fields). Fork-tested behavior: `unlockToken(j)` succeeds **once** for an eligible record (single ERC-20 transfer from the locker to `msg.sender`), a second call reverts, and a third-party caller reverts — **no replay, caller-scoped** (§4).

### 1.4 V3 escrow registry

BSC LP-storage registry `0xFEE2A3f4329e9A1828F46927B424DB2C1624985` (owner `0x2EF31266…`, DxSale team) records 2,558 locks. Each record points to a per-lock escrow (`lpLockContract`) that actually holds the LP. Sampled escrows are `Ownable` with **owner == the recorded beneficiary** (`lockOwner`); the release function `0xfb8d0536` = `unlockTokensAfterTimestamp()` reverts `Ownable: caller is not the owner` for anyone else and transfers the LP to the owner, then calls `registry.unlockLocker(id)`. Self-custody, no team backdoor.

---

## 2. Live state (2026-10-03, BSC enumeration block 125,414,390; fork tests 125,433,171)

### 2.1 Locker census — every deployment found

Sources: DefiLlama adapter config (including commented-out entries), BscScan verified-source matches by name/bytecode family, and the drain transaction participants. Families are distinguished by runtime code hash and by the presence/absence of the `"tokens are still locked"` constant and by fork-tested behavior.

| Chain | Address | Code hash (family) | Locks | Fee (wei) | Owner | Live behavior |
|---|---|---|---|---|---|---|
| BSC | `0xEb3a…3e449` | `0x9235c786` (v1 buggy, verified) | 9,749 | 1e33 | `0xC457…FA69` (attacker) | replay bug; ~$400k self-owned balances (no third-party surplus) |
| BSC | `0x8655…679a` | `0xf4ad4d81` (fixed family) | 3,363 | 1e46 | attacker | time-gated single claim |
| BSC | `0x5b5e…29b6` | `0x43e1dd3e` (fixed, verified) | 14,223 | 1e38 | attacker | time-gated single claim |
| BSC | `0x2D04…E677` | `0x17123b18` (variant) | 4,938 | 1e31 | attacker | single claim, caller-scoped |
| BSC | `0x81E0…334d` | `0x89dcc2f3` (variant) | 3,970 | 1e38 | attacker | single claim, caller-scoped |
| BSC | `0xFEE2…4985` | V3 LP registry (2,558 locks) | 2,558 | — | `0x2EF31266…` (team) | escrows beneficiary-owned |
| Ethereum | `0x1Ba0…0fbD` | `0x9235c786` (v1 buggy) | 37 | 1e33 | `0x0684…860B` | replay bug; dead tokens |
| Ethereum | `0x916a…6B8E` | `0x17123b18` (variant) | 43 | — | `0x0684…860B` | variant |
| Ethereum | `0xc68C…25D3` | `0x43e1dd3e` (fixed) | 149 | — | `0x47BAcf…` (original) | fixed |
| Ethereum | `0xe740…0BDD` | `0x0985b05b` (fixed) | 7 | — | `0x47BAcf…` | fixed |
| Ethereum | `0xBae2…0D96` | `0x89dcc2f3` (variant) | 42 | — | `0x47BAcf…` | variant |
| Polygon | `0xEb3a…3e449` | `0x8a3401ff` (v1 buggy) | 112 | 1e33 | `0x47BAcf…` | replay bug; dead tokens |
| Polygon | `0x6FCC…7666` | `0xca05c53a` (fixed) | 95 | — | `0x47BAcf…` | fixed |
| Polygon | `0x0360…9cDe` | `0x43e1dd3e` (fixed) | 77 | — | `0x47BAcf…` | fixed |
| Polygon | `0xb556…43cd` | `0x89dcc2f3` (variant) | 62 | — | `0x47BAcf…` | variant |
| Arbitrum | `0x51f4…6Df4` | `0x43e1dd3e` (fixed) | 23 | — | `0x47BAcf…` | fixed |
| Arbitrum | `0xdf17…c645` | `0x9e446a24` | — | — | `0x47BAcf…` | (no lockerNumberOpen) |
| Avalanche | `0x77D0…7809` | `0x43e1dd3e` (fixed) | 660 | — | `0x47BAcf…` | fixed |
| Avalanche | `0x10f4…7b95` | `0x89dcc2f3` (variant) | 30 | — | `0x47BAcf…` | variant |
| Gnosis | `0x832C…0D37` | `0x915fa6e3` (fixed) | 0 | — | `0x47BAcf…` | empty |
| Gnosis | `0x554d…d199e` | `0xd7b644df` | — | — | `0x47BAcf…` | variant-ish |
| Celo | `0xC706…8b38` | `0x43e1dd3e` (fixed) | 1 | — | `0x47BAcf…` | fixed |
| Harmony | `0x1345…95aE` | `0x89dcc2f3` (variant) | 10 | — | `0x47BAcf…` | variant |
| Harmony | `0xd5F1…C6dD` | `0x8a755e63` (fixed) | 0 | — | `0x47BAcf…` | empty |

(Full per-locker record/token dumps and valuation: `analysis/`, `ci-out/`.)

### 2.2 Key state facts (read at BSC block 125,414,390; fork tests at 125,433,171)

- **All five BSC legacy lockers are owned by the May-2026 drain wallet** `0xC4574DDEF299e7E563971e200433e592EeaaFA69`.
- Fee gates sit at absurd values (1e31–1e46 wei) on the BSC lockers **at rest** — normal users cannot create records. `lockFees` on the drained v1 = `1e33` wei. Archive reads (Ankr) show the fee was already 1e33 at every sampled block around the May-2026 drain, yet the attacker's 1,035 records carry `startTime` 2026-05-27/28: the owner (EIP-7702 batch account) must toggle the fee **inside the same batch transaction** (`changeFees(1)` → `createLocker` → `changeFees(1e33)`), which is an owner-only capability. This matches the "fee→1 wei" reporting while the at-rest value never left 1e33.
- The attacker's 1,035 records on `0xEb3a` are still `locked=true`, `lockedTime≈2095e6` (year 2036). Most of their recorded tokens were drained to ~0; the only remaining contested balance reachable through attacker records is **$745.27** on token `0x833ce423…` (P). `unlockToken` for their already-drained records reverts `"no more tokens left to refund"`.
- `0x5b5e` and `0x8655` still hold thousands of locked positions; all future-locked records revert `"tokens are still locked"`; expired records are single-claim.
- Variants `0x2D0454`/`0x81E0eF68` hold ~$754k/~$337k of ERC-20s (GoldRush quotes; see §5); every record is single-claim and caller-scoped. On `0x81E0`, 652 of 794 sampled wallets (82%) have at least one currently-claimable record (their own funds).
- V3 escrows: 1,020 of 2,558 hold balances; 287 are still future-locked; all 12 sampled escrow owners equal the recorded beneficiary.

---

## 3. What an unprivileged attacker can do — call paths

| Path | Preconditions | Verdict |
|---|---|---|
| **Replay `unlockToken` on a still-locked record** (v1 family only) | A record you own with `locked=true`, `lockedTime > now`, `amount <= locker balance of token` | **Works** (fork-proven, §4) — but every live v1 token balance is ~$0 → **$0 today**. Requires an existing record (creation fee bricked) unless the owner lowers it. |
| Create a new record to replay (v1) | `msg.value >= lockFees` = 1e33+ wei | Impossible for a normal user; owner-only re-arm |
| Replay on fixed family | `lockedTime > now` reverts; post-expiry single claim | $0 |
| Replay on variant family | second call reverts; third-party call reverts | $0 |
| Drain via V3 escrow | `unlockTokensAfterTimestamp()` owner-gated; owner = beneficiary | $0 |
| Sweep / rescue / arbitrary transfer | none of the families expose one | $0 |
| `changeFees`, `changeLockFeesAcc`, `platformRelease` | owner-only | not extraction (releases pay beneficiaries) |
| `DXLOCKERLP(address,uint256)` view getter on the v1 address | none — public mapping getter | callable by anyone, still live (used for enumeration); returns record data only, moves no funds |

**Access-control inventory (value-moving functions):**
- v1 `DxLockLPDep`: `createLocker` (public+payable, fee-gated), `unlockToken` (record owner only — caller-scoped mapping), `increaseLockTime`/`changeLogo` (own record only), `changeFees`/`transferOwnership`/`renounceOwnership` (owner). No sweep. No pause. No pendingOwner (legacy `Ownable` sets owner directly).
- fixed `DxLockLPDep`: same plus `platformRelease` (owner-only, pays the record's beneficiary) and `changeLockFeesAcc` (owner-only fee destination). No sweep.
- variants: `createLocker` (selector `0x129fa7e8`, payable), `unlockToken` (record owner only, single-use), `changeFees`/`changeLockFeesAcc`/`transferOwnership` (owner). No sweep.
- V3 escrows: `unlockTokensAfterTimestamp` (owner-only = beneficiary), Ownable `transferOwnership`; registry `unlockLocker(id)` is a bookkeeping flag call (no token movement).

### Owner-privileged (P) quantification
- **Attacker-held lockers (BSC ×5):** the owner can set the fee to 1 wei and create records, but on the **fixed/variant** code there is no replay and no owner sweep, so the owner cannot move locked user funds. On the **v1 buggy** code the owner can replay — but the only remaining v1 balances are dust (≈ $10 total incl. MSVP/SHARD). **P ≈ $0.**
- **Team-held lockers (all other chains):** same code properties; no owner sweep. **P ≈ $0** (owner can release early *to users*).
- The real owner capability is **fee/creation control** and **early release of a user's lock to that user** — a custody/DoS surface, not a theft surface.

---

## 4. PoC / fork verification

`poc/` — Foundry suite `test/DxSaleC24.t.sol` (vendored forge-std), fork = BSC via `BSC_RPC_URL` (fallback publicnode). **12/12 PASS** (local; 11/11 in CI run 1 — the 12th test was added after and passes locally; CI run 2 carries all 12). See `ci-log.txt`, `ci-artifacts/`, run URLs in §7.

| # | Test | Proves |
|---|---|---|
| 1 | `test_live_state_bsc_lockers` | all 5 BSC legacy lockers owner = drain wallet; fee gates 1e31–1e46; lock counts |
| 2 | `test_v1_current_fee_blocks_creation` | a normal user cannot create a record today (1e33 fee) |
| 3 | `test_v1_owner_rearm_replay_drains` | after the owner lowers the fee, a fresh user's still-locked record pays out **10×** its deposit from the locker's balance (`onUnlock` ×10; record stays `locked=true`) — the replay bug is live |
| 4 | `test_v1_historical_unprivileged_replay` | gated by `ARCHIVE_FORK_BLOCK`; reproduces the unprivileged replay at a pre-drain block when an archive RPC is available |
| 4b | `test_v1_real_record_replay_is_self_funds` | a **real** unprivileged still-locked record (wallet `0x862d7c…`, token `0x608D85…`, unlock 2100) pays out twice via replay; the locker balance equals that wallet's own two records exactly — replay returns self-funds only |
| 5–6 | `test_fixed_5b5e_future_lock_reverts`, `test_fixed_8655_future_lock_reverts` | fixed family reverts `"tokens are still locked"` — no early/replayed claim |
| 7 | `test_fixed_5b5e_expired_single_claim` | expired record pays exactly `lockedAmount` once, then reverts — no replay |
| 8–9 | `test_fixed_5b5e_platformRelease_nonowner_reverts` / `_pays_user_not_owner` | `platformRelease` is owner-only and pays the beneficiary; owner receives nothing |
| 10–11 | `test_variant_2d04_unlockable_record_replay`, `test_variant_81e0_…` | variants: first claim transfers once, second call reverts, third-party caller reverts; measured payout equals the recorded lock amount (verified against the original `onLock` event: 0x2D04 wallet `0x265f6d…` locked `4.46199903e26` on 2021-03-01 and received exactly that) |

Key replay traces (live fork):
```
test_v1_owner_rearm_replay_drains:
  unlockToken(0) → Transfer(locker → user, 1e15)   (×10 calls)
  gained 10,000,000,000,000,000 MSVP wei (deposited 1e15); record still locked

test_v1_real_record_replay_is_self_funds:
  real-record replay gained: 89442719099989586   (2 × 44721359549994793)
  locker balance before:     152203354178845283 (= record0 + record1, same wallet)
  record0 still locked after replay: true
```
The MSVP token enforces its own transfer schedule, which capped test 3 at 10 payouts; a plain LP token would drain to the floor remainder.

---

## 5. Remaining custody (H-O / S) — measured

All values from the CI enumeration + LP-unwrapped DefiLlama pricing at BSC block **125,414,390** (run 1) unless noted; `ci-out/valuation.json`, `ci-out/valuation_v3.json`, `ci-out/final_categories.json`.

### 5.1 Per-locker custody and category split

| Locker | Family | Custody (LP-unwrapped USD) | E-U theft | H-O (holders) | P (owner) | S (stuck/time-locked) |
|---|---|---|---|---|---|---|
| BSC `0xEb3a…` (v1) | buggy | $399,913.33 | **$0.00** (≤$0.001 dust) | $394,136.12 | **$745.27** | $5,777.21 |
| BSC `0x8655…` | fixed | $3,647,505.75 | $0 | $1,869,373.01 | $0 | $1,778,132.74 |
| BSC `0x5b5e…` | fixed | $3,098,941.95 | $0 | $2,123,755.30 | $0 | $975,186.65 |
| BSC `0x2D0454…` | variant | $754,084.21 (GoldRush quote¹) | $0 | $754,084.21 | $0 | — |
| BSC `0x81E0eF68…` | variant | $337,000.57 (GoldRush quote¹) | $0 | $337,000.57 | $0 | — |
| ETH `0x1Ba00C14` (v1) | buggy | $0.00 | $0 | $0 | $0 | $0 |
| ETH `0x916a…` | variant | n/a (getter absent) | $0 | — | $0 | — |
| ETH `0xc68C…`/`0xe740…` | fixed | $0.00 | $0 | $0 | $0 | $0 |
| Polygon `0xEb3a…` (v1) | buggy | $5,274.17 | $0 | $5,274.17 | $0 | $0 |
| Polygon `0x6FCC…`/`0x0360…` | fixed | $8,273.16 | $0 | $6,625.24 | $0 | $1,647.92 |
| Polygon `0xb556…` | variant | $0.00 | $0 | $0 | $0 | $0 |
| Arbitrum `0x51f4…` | fixed | $3,839.03 | $0 | $3,839.03 | $0 | $0 |
| Avalanche `0x77D0…` | fixed | $8,178.25 | $0 | $7,871.59 | $0 | $306.66 |
| Gnosis/Harmony/Celo/etc. | fixed/variant | $0.00 | $0 | $0 | $0 | $0 |
| **V3 escrow registry `0xFEE2…`** | V3 | **$4,317,453.16** | $0 | $3,351,283.83 | $0 | $966,169.33 |
| **Totals** | | **$12,580,463.58** | **$0.00** | **$8,853,243.07** | **$745.27** | **$3,727,220.51** |

¹ The variant lockers use a different record ABI (no `DXLOCKERLP(address,uint256)` getter), so the CI enumeration skipped their records; their holdings are direct ERC-20 balances summed by GoldRush (`no-spam=false`). The fork tests established single-claim, caller-scoped behavior and 832/988 (2D04) and 652/794 (81E0) sampled wallets have currently-claimable records.

### 5.2 What drives the v1 `$399,913.33`
1,707 recorded tokens still hold a balance; 117 tokens have a non-owner still-locked record that can replay. In **every** case the token balance is fully covered by that wallet's own records (balance == Σ its record amounts, or less), so the replay yields **no third-party surplus** (max $0.001). The May-2026 attacker already drained all shared-pool balances. The largest self-owned future-locked positions: $37,884.91 (`0xe859b6a3…`), $16,487.59 (`0x5179bf30…`), $9,585.81 (`0x1ced25e2…`). The one P-surplus token is `0x833ce423…`: attacker records (idx 400/1017) can replay-drain the remaining $745.27, which otherwise covers a non-owner's expired claim.

### 5.3 V3 escrow registry
2,558 records; 1,020 escrows with balance; 287 still future-locked. $3,351,283.83 is past its lock time (holder-releasable), $966,169.33 is still time-locked. Escrow owners == recorded beneficiaries in all 12 sampled.

### 5.4 Historical context
DefiLlama showed the family at **$19.75M** on 2026-10-02 (BSC $18.29M) — that figure is **not** live-extractable value; it is locked-user custody. The May-2026 drain removed ~$7.3M; the ~$12.58M measured here is what remains across the whole family.

---

## 6. Verdict & residual risk

- **E-U theft ≈ $0.00** — the permissionless replay primitive is real and still deployed on the v1 family (fork-proven with a real unprivileged record), but every still-locked record's token balance is fully covered by that same wallet's own records, so replay only accelerates self-withdrawal. No third-party surplus remains (max $0.001 dust). All other families are patched single-claim (fixed), caller-scoped single-claim (variant), or beneficiary-owned escrows (V3).
- **P = $745.27** — the attacker-owned v1 locker's records can replay-drain one contested token (`0x833ce423…`); the owner can also re-arm record creation with an in-transaction `changeFees` toggle. No owner sweep exists on the fixed/variant/V3 families.
- **H-O = $8,853,243.07** — recoverable by holders: $7.76M from CI (expired claims + early self-withdrawals + variant/v3), plus $1.09M variant ERC-20 holdings (GoldRush).
- **S = $3,727,220.51** — time-locked fixed-family positions, future V3 escrows, unclaimed/no-record dust.
- **Latent risks:** (a) if a previously unlisted v1-family deployment holds a **multi-wallet** funded token with a still-locked record, replay theft is immediately live there — the census covers the DefiLlama-listed deployments, their commented-out siblings, and verified-source/code-hash families, but not an exhaustive chain-by-chain `onLock` event scan; (b) the attacker (or a buyer of the owner keys) can re-arm fees and create records at will on all five BSC lockers; (c) `0x5b5e`/`0x8655` hold ~$6.7M of user TVL under an **attacker-controlled owner key** — no theft path was found, but `platformRelease` lets the owner release any lock early **to its beneficiary** (social-engineering/griefing surface).
- **Blockers to extraction:** fee gates at rest (1e31–1e46 wei, owner-toggleable), drained shared pools, time gates on fixed/variant code, beneficiary-only escrows, and the absence of any sweep function.

---

## 7. Methodology & sources

- **On-chain reads** at explicit BSC block **125,414,390** (enumeration) and fork tests at block **125,433,171** (run 1, 2026-10-03) and equivalents per chain; `eth_call`/`eth_getCode` via public RPCs + `BSC_RPC_URL` in CI; no state-changing mainnet calls.
- **Verified sources:** BscScan/Etherscan V2 (`getsourcecode`): `DxLockLPDep` at `0xEb3a…` (v1 buggy) and `0x5b5e…` (fixed), solc 0.6.12. Unverified variants decoded by runtime bytecode disassembly + fork behavior.
- **Incident data:** DarkNavy "DxSale Legacy Locker Repeat Unlock Drain" (on-chain artifacts: ownership tx `0x23e331a8…`, drain txs `0x16a932b7…`, `0x5d51d975…`, `0xdbd71d00…`, 667,465 events/1,362 txs), OAK worked example, The Defiant, Crypto Times, PeckShield/Coinsult.
- **Enumeration:** DefiLlama `dxsale` adapter config (all listed + commented sibling lockers), locker `LockerRecord`/`UserLockerCount`/`DXLOCKERLP` records, V3 `AllLockRecord` registry, GoldRush balances, DefiLlama prices.
- **PoC:** Foundry 1.7.1 on GitHub Actions (`ci/run.sh` + `forge test -vvv`), vendored forge-std.

### Caveats & limitations
1. Not an exhaustive chain-by-chain `onLock` event scan; coverage = listed deployments + commented siblings + family code-hash matches. A previously unknown v1 deployment with a funded multi-wallet still-locked record would change the E-U verdict locally.
2. USD figures for unpriced/dead tokens are approximate (DefiLlama price absence treated as $0; LP unwrapping uses `getReserves` × share, cross-checked with real pair balances where sampled). The two variant lockers are valued from GoldRush quotes, not LP-unwrapped.
3. `0x8655` and the variants are unverified; behavior was established by disassembly + fork tests, not source review.
4. The historical replay test is gated on an archive RPC; the current-state replay test uses the owner's `changeFees` to re-arm creation (clearly labeled), since the fee gate currently blocks new records.
5. E-U is reported as *theft* (third-party surplus); early self-withdrawal of a holder's own still-locked deposit is counted under H-O. If the campaign prefers the literal "value any unprivileged actor can pull today", add ~$100k of v1 self-withdrawals and ~$3.35M of V3 escrow releases (both beneficiary-initiated).

### Files
- `README.md` (this file), `summary.json`
- `analysis/` — raw probes, disassembly, verified sources, GoldRush extracts, local enumerations (`records_*.json`, `v3_registry_bsc.json`, `*_sweep.txt`, `sources/`, `probe_*`, `variant_onlock_decode.txt`)
- `poc/` — Foundry project (`test/DxSaleC24.t.sol`, 12 tests)
- `ci/run.sh`, `ci-out/` — heavy enumeration + valuation + post-processing outputs (`final_categories.json`)
- `ci-log.txt`, `ci-artifacts/` — CI logs/artifacts; run URLs below

**CI runs:**
- Run 1 (enumeration + valuation + 11 tests, green): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37094137505
- Run 2 (final: adds post-process + real-record replay test, 12 tests): URL appended when the run finishes.

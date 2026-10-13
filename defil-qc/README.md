# DeFIL — L2 Phase-2 **QC-1 adversarial re-audit** (Ethereum + BSC)

**Date:** 2026-10-13 · **Role:** adversarial QC (assume the prior closure is wrong, try to break it)
**Prior result under test:** `defil` deep-dive (2026-10-11) — **E-U $0 (high)**, ~$1.97M nominal custody; H-O/P/S split.
**This re-audit's verdict:** ✅ **closure stands — $0 fresh-attacker E-U** (high confidence).
**Method:** read-only. Fresh live reads (public RPCs), fresh source/bytecode pulls (Blockscout), selector extraction on unverified implementations, **fork PoCs on both chains** (25 tests, CI). No transactions, no secrets.

---

## 1. TL;DR

The prior closure survives every fresh attack attempt. The three pillars were re-verified from scratch and the *strongest* new candidates (stale-oracle borrows on both chains, the DFL flywheel "history capture", the reserve-keeper `_reduceReserves` design, the old→new DFL migration, the BSC "unverified" contract gap) all resolve to **$0 unprivileged extractable** — mechanically blocked, economically negative, or gated by a precondition that no outsider can satisfy today.

| Fresh attack attempt (all keyless) | Result | Exact gate / reason |
|---|---|---|
| Acquire any mining-NFT unit → mint FILST → dump | ❌ closed | all **3,771 units** (1,914 ETH ids 100001–100011 + 1,857 BSC ids 100001–100012) escrowed in FILSTManage; **no NFT-out function**; `MiningNFT.burn` onlyPoster; `MiningNFTManage.burn` requires caller's own balance; `MinerManage.addToWhiteList` onlyOwner |
| BSC "unverified" FILSTManage/NFT/NFTManage as a hidden-function gap | ❌ closed | **bytecode-identical** to the verified ETH twins (hashes in `ci-out/qc-evidence.json`) |
| `FILSTManage.burn()` returns/leaks escrowed NFTs | ❌ closed | source read: burn() destroys only `msg.sender`'s FILST; no ERC-1155 transfer-out anywhere |
| Unstuck the LP `0x9e08bd9a` (skim/burn/withdraw/allowance/rounding) | ❌ closed | pair balances == reserves (skim == 0, fork-proven); withdraw is per-account share-gated; shares are 1:1 (no rounding); staking never approves anyone |
| Stale-oracle borrow: cFILST (FILST, oracle 83×/19× under market) | ❌ closed | both cFILST markets are **CollateralOnlyCErc20** — `borrow()` returns `BAD_INPUT(2)` on ETH **and** BSC |
| Stale-oracle borrow: ceFIL (EFIL) against overvalued mFIL ($1.25) | ⚠️ mechanically open, **$0 realized** | borrow succeeds on a fork with mFIL collateral, but the only output is **EFIL**, which has **no venue on Ethereum** (no Uni V2/Sushi/Uni V3 pair; only a dust FILST/EFIL pair holding 982 EFIL + 0.99 FILST). On BSC the same route needs mFIL — **BSC mFIL supply is 0** |
| DFL flywheel "first-supplier captures history" (both chains) | ❌ closed | fork-proven fair: a fresh supplier's entry index == current index, historical/unaccrued delta accrues to *existing* suppliers; `claimDFL()`/`claim()` sender-accrued-gated; admin fns return `UNAUTHORIZED` |
| Reserve-keeper `_reduceReserves` (custom fork design) | ❌ closed to outsiders | caller must have their **own** `historicalReserveKeeperAccrued`; ceFIL's keeper is a contract (PR, 14.2M EFIL accrued) with **no function that calls the market**; other keepers are EOAs (P) |
| Reward distributors (RewardPool / PR / SUP1-3 / FilstMarket `claimEfil`) | ❌ closed | all claim/claimAll/transfer paths are `msg.sender`-accrued-gated; BSC RewardPoolDelegator holds 0 tokens |
| Old→new DFL migration `convert()` | ⚠️ conditional, value-destroying | 1:1 conversion, ≤1.746M new DFL (~$196) left; requires **old DFL**, whose only venue is a ~$50 dust WETH pair at ~$0.022/oldDFL — above the new DFL price |
| Cross-chain stale price (ETH FILST $0.5117 vs BSC $0.1335) | ❌ closed | no public bridge; no third-party canonical bridge; team-operated only |
| FILST mint via owner-less/self-whitelist path | ❌ closed | `whiteList` is a getter; owner is EOA (P) |
| LP float ($122, not $1 — new precise number) | ❌ H-O | 8.4e-5 LP held by EOA `0xf82a7842` ($121.6) + smart-wallet `0xb3ac829a` ($1); holder-recoverable |

**Fresh-attacker E-U: $0. Confidence: high** (ETH fork-verified; BSC fork-verified; bytecode-identity across chains).

---

## 2. What is new in this QC pass (vs the prior deep-dive)

The prior audit was correct on the bottom line but **incomplete in places**; this pass adds:

1. **Fresh on-chain NFT enumeration on both chains** (prior only did ETH balances): ETH = 11 mints / 1,914 units, BSC = 12 mints / 1,857 units; log-netting confirms **no units anywhere but FILSTManage**; BSC supply is exactly 1,857×1024 and ETH 1,914×1024 (no net burns).
2. **Bytecode-identity proof for the three BSC "unverified" contracts** (FILSTManage, MiningNFT, MiningNFTManage) and MinerManage against verified ETH sources — closes the "unverified BSC = hidden functions" hypothesis.
3. **Selector extraction on the unverified Comptroller implementation** (`0x622e6177…`): enumerated its full function set incl. `claimDFL()`, `accrue()`, `_setDflKeeper`, `_setDflKeeperFactor`, `_setTransferPaused` — every admin function is gated (Compound error `1` / explicit reverts).
4. **Fork-tested the DFL "history capture" bug class** on both chains (the classic Compound-fork first-supplier exploit): **not present** — entry index is set to the current index with a zero balance before credit.
5. **Found and analyzed the custom reserve-keeper mechanism** (`_reduceReserves(receiver, amount)` with `historicalReserveKeeperAccrued[msg.sender]`): the ceFIL keeper (PR contract) holds 14.2M EFIL accrued but cannot trigger it; the design is a latent P surface, not E-U.
6. **Traced the full reward chain** ceFIL market → PR/SUP3 → DFL staking: ETH 7.1M EFIL accrued to DFL stakers but the PR holds **0 EFIL** and payout is bounded by the market's 38.5K EFIL cash (unsellable); BSC accrued is 0.375 EFIL (dust).
7. **Precise EFIL venue check** (Uni V2, Sushi V2, Uni V3, holders): ETH EFIL has **no market** — this is the exact reason the stale-oracle borrow is worth $0.
8. **BSC lending-market enumeration** (3 markets, oracle, CFs): cFILST collateral-only; cmFIL empty (BSC mFIL supply = 0); ceFIL CF 0 — the BSC mirror of the ETH findings.
9. **LP float precision**: the ETH float is 8.4e-5 LP (~$122) held by an EOA + a smart wallet (prior said ~$1); BSC float 24.97 LP (~$19). Still H-O.
10. **Old→new DFL migration quantified**: 1:1, ≤$196 remaining, old-DFL venue is dust at a *higher* implied price → no arb.

---

## 3. Exact live state used (2026-10-13)

### Ethereum (block ≈ 26,182,xxx)
- **FILST/USDT LP** `0xa2f6a219…`: reserves **1,396,416.006 FILST + 714,487.847 USDT**; pair balances == reserves; LP supply 0.9795596; **99.9914% staked** in `0x9e08bd9a…`; float 8.4e-5 LP (~$122) → EOA `0xf82a7842…` ($121.6) + smart wallet `0xb3ac829a…` ($1).
- **Mining NFTs**: ids 100001–100011, **1,914 units, all in FILSTManage** (`getCurrentTokenId` = 100011). 22 TransferSingle logs = exactly 11 mints + 11 stakes.
- **FILST**: supply 1,959,936 = 1,914×1024 = `getTotalMintedAmount`; poster = FILSTManage; owner EOA.
- **Stakings** (6, identical code hash): LP 0.97948 LP; FILST 374,550.8; DFL 52,202,774.7; + 3 small ones.
- **ceFIL**: cash 38,527.8 EFIL; reserves 14,212,709.7 EFIL; CF 0; oracle EFIL $1.00; reserveKeeper = PR `0x3CCd0160…` with 14.2M EFIL accrued.
- **cFILST**: cash 3,102.08 FILST; `borrow()` → `2` (collateral-only); sole cToken holder `0x9a26f4d0…`.
- **cmFIL**: cash 182,288.5 mFIL; CF 0.8; mFIL oracle $1.25, real venue **none**.
- **Unitroller**: 43.75M DFL; drip 1.492 DFL/block, **100% to ceFIL**; `claimDFL()`/`claim()` gated.
- **EFIL**: no Uni V2 / Sushi / Uni V3 venue; only dust FILST/EFIL pair (982 EFIL + 0.99 FILST).
- **Migration `0x9b1322c4`**: 1,746,989.6 new DFL left; owner EOA `0x3f0FE6cc…`; old DFL/WETH pool ≈ $50 dust.

### BNB Chain (block ≈ 127,371,xxx)
- **FILST/USDT LP** `0xecf6aA34…`: reserves **1,038,182.27 FILST + 139,004.73 USDT**; balances == reserves; **99.9933% staked** (`0xde6239b3…`); float 24.97 LP (~$19).
- **Mining NFTs**: ids 100001–100012, **1,857 units, all in BSC FILSTManage**; supply 1,901,568 = 1,857×1024.
- **Stakings**: LP 371,819.4 LP; FILST 183,539.7; DFL 63,554.1; P2 260,753.6 LP.
- **Compound fork** (`Unitroller 0xa4bBE553…`): ceFIL cash 18,387.4 EFIL (CF 0); cFILST cash 9,087.3 FILST (`borrow()` → `2`); cmFIL empty; oracle FILST $0.00708 vs pool $0.1335 (19× under).
- **DFL drip** 0.0407 DFL/block, 100% to ceFIL; `claimDFL` fair (fork-proven); Unitroller holds 16.65M DFL; BSC DFL/USDT pool 6.87M DFL + **10,472 USDT** ($0.00152/DFL).
- **BSC mFIL supply = 0**; BSC RewardPoolDelegator holds 0 tokens; SUP1/SUP3 hold 0 tokens.

---

## 4. Why each fresh hypothesis failed (counter-evidence detail)

### 4.1 Mining-NFT acquisition (the only route to new FILST)
- `FILSTManage.mint()` requires `miningNFT.balanceOf(msg.sender, id) ≥ nftAmount`; all units are in FILSTManage.
- `FILSTManage` has **no function** that transfers ERC-1155s out (source: setPriceConverter/setMiningNFTManage/setFilstPool/setMintFeeRatio/mint/getMintFee/burn/transfer-DFL/onERC1155* only). `onERC1155Received` accepts transfers only with data `"MINT"` (i.e., only its own mint flow).
- `MiningNFT.burn` is `onlyPoster` (poster = MiningNFTManage); `MiningNFTManage.burn` checks `miningNFT.balanceOf(msg.sender)` — an outsider cannot burn FILSTManage's units.
- `MiningNFTManage.mint` → `MinerManage.whiteList(msg.sender)`; `whiteList` is a public mapping getter; `addToWhiteList` is `onlyOwner`. **No self-whitelist path** (fork-proven revert).
- **Conditional only:** if an mNFT unit were ever obtained, 1 unit → 1,024 FILST at a 5% DFL fee → ~$522/unit ETH, ~$137/unit BSC. No unit is obtainable today.

### 4.2 The LP "unstuck" question
- `skim` is a no-op (pair balances equal reserves on both chains — fork-proven, transfers of 0).
- `burn` requires holding LP; 99.99% is inside the staking; the staking has no LP-transfer path.
- `withdraw` is per-account share-gated (`withdraw: insufficient value` for outsiders on all 6+5 stakings, fork-proven).
- The staking never calls `approve`; no allowance exists to abuse.
- Shares are credited 1:1 with the amount actually received (`doTransferIn`), so no rounding/inflation gain.

### 4.3 Stale-oracle borrows (the strongest "new" candidate)
- **cFILST (both chains) is `CollateralOnlyCErc20`** — `borrow()` unconditionally returns `BAD_INPUT(2)`. The 3,102 FILST (ETH) / 9,087 FILST (BSC) market cash is not borrowable.
- **ceFIL borrow is mechanically open** (fork: attacker with 100 mFIL supplied to cmFIL borrowed 50 EFIL from ceFIL). But:
  - the output is **EFIL**, which has **no ETH venue** (checked Uni V2, Sushi V2, Uni V3 for WETH/USDT/DFL/mFIL; holders list) → realized value $0;
  - the only overvalued collateral is **mFIL** ($1.25 oracle vs ~$0 real), and all mFIL is held by 5 EOAs (mint is `MINTER_ROLE`-gated) → precondition requires acquiring a legacy token;
  - on BSC the same route is impossible: **BSC mFIL supply is 0**, and the only other collateral (FILST) is oracle-undervalued 19× (a borrow there is a ~90% capital loss by AMM math).
- **Conditional:** an mFIL holder (ETH) can borrow up to min(collateral capacity, 38.5K EFIL) — realizable ~$0. **Not E-U.**

### 4.4 DFL flywheel
- `claimDFL()`/`claim()`/`accrue()` are all callable; the claim is gated by `dflAccrued[msg.sender]` and `claim(receiver, amount)` checks the **sender**, not the receiver (fork-proven revert for a third-party claim).
- The classic Compound-fork bug (new supplier captures the whole historical index) is **absent**: at mint, the pending index is pushed to existing suppliers *before* the minter's balance is credited, and the minter's `dflSupplierIndex` is set to the post-update index (fork-proven on both chains; the attacker's accrual was <1e-15 DFL).
- Farming is capital-negative: ETH drip ~$14.4/day (pool-implied) needs dominating a 3,102-FILST market; BSC drip ~$5.4/day needs dominating a 9,087-FILST market; and the rewards are paid in a token whose exit depth is $946 (ETH) / $10.5K (BSC).

### 4.5 Reserve keeper (`_reduceReserves`) — custom design
- The fork's `_reduceReserves(receiver, amount)` is **not** admin-gated in the usual sense: `keeper = msg.sender` and `require(amount ≤ historicalReserveKeeperAccrued[keeper])`. Anyone with a nonzero accrued can pull, but only up to *their own* accrued.
- ceFIL's keeper is the **PR contract** `0x3CCd0160…` with **14,212,709 EFIL accrued** — but the PR has no function that calls `_reduceReserves` (its functions are accrue/claim/claimAll/transfer/set-members, all distributing its own asset), so the accrued is unreachable by anyone. Outsiders have 0 accrued (fork-proven `_reduceReserves` returns an error code, cash untouched).
- cmFIL/cFILST keepers are EOAs with 0 accrued (P if the owner key acted).

### 4.6 Reward distributors
- `RewardPool.claim/claimAll/transfer` — accrued-gated (fork: `Insufficient value`).
- `FilstMarket.claimEfil`/`repayBorrowBehalfInEfilMarket` — sender-accrued-gated; the cFILST market's rewards flow from the FILST staking, bounded by the staking's real accrued.
- The ETH DFL-staker EFIL rewards (7.1M EFIL accrued from ceFIL reserves) are **unbacked at the point of payment**: the PR holds 0 EFIL, the payout is bounded by ceFIL's 38.5K cash, and EFIL is unsellable → ~$0.

### 4.7 Cross-chain
- No public bridge contract; no canonical/third-party bridge integration; team-operated bridge only. The 3.8× FILST price gap is not arbitrageable keylessly (confirmed unchanged).

---

## 5. Conditional paths (explicitly NOT E-U)

| # | Conditional path | Precondition | Value (if precondition met) |
|---|---|---|---|
| C1 | **Owner-key compromise (P)** | EOA `0x557EdaaF…` key | `setPoster` → unlimited FILST mint → dump: up to **~$714.5K USDT** (ETH) + **~$139.0K** (BSC); plus MiningNFT/EFIL/mFIL/Unitroller/market admin |
| C2 | **Legacy depositor key compromise (H-O→P)** | top LP staker `0xF2Ba8F66…` (99.88% of staked LP) | withdraw 0.9783 LP → redeem ≈ $1.43M nominal (**$714K hard USDT**); FILST stakers `0xc1b29667` (194.8K FILST) + `0x6e1da46a` (153.2K); cFILST holder 3,102 FILST |
| C3 | **mNFT acquisition** (currently impossible) | 1 mNFT unit | 1,024 FILST minted (5% DFL fee) → ~$522/unit ETH, ~$137/unit BSC |
| C4 | **mFIL-collateral EFIL borrow** | ≥ ~19 mFIL (ETH, EOA-held legacy token) | borrow ≤ 38.5K EFIL; **realizable ~$0** (no EFIL venue) |
| C5 | **Old→new DFL migration** | old DFL (dust venue at $0.022, above new DFL) | ≤1.746M new DFL (~$196); value-destroying at current prices |
| C6 | **DFL farming** | capital to dominate ceFIL/cFILST supply | ETH ~$14.4/day drip; BSC ~$5.4/day; capital-negative, exit depth $946/$10.5K |
| C7 | **ceFIL cash via DFL-staker claim chain (H-O)** | DFL staker with historical accrued | bounded by 38.5K EFIL cash; EFIL unsellable → ~$0 |

No conditional path is reachable today by an unprivileged attacker without first acquiring a legacy position or compromising a key.

---

## 6. PoC / CI

- **Project:** `poc/` (Foundry, solc 0.8.24, vendored forge-std). **25 tests, all passing.**
  - `test/DeFILQC.t.sol` — ETH: NFT enumeration, mint/whitelist/burn gates, staking gates, LP skim, H-O recovery, cFILST collateral-only, ceFIL borrow + EFIL-venue absence, mFIL borrow demo, DFL history-capture, sender-gating, admin gating, reserve keeper, reward pool, migration.
  - `test/DeFILQC_BSC.t.sol` — BSC: NFT enumeration, gates, stakings, LP skim, collateral-only, oracle-under-collateral, DFL history-capture.
- **CI evidence:** `ci/run.sh` writes `ci-out/qc-evidence.json` (custody state, bytecode-identity hashes, gate simulations on both chains).
- **CI run:** `bash /home/heisenberg/CA/ci/ci-run.sh defil-qc` → run URL + `ci-log.txt`/`ci-artifacts/` (see below).

Local pre-CI result: **25/25 pass** (ETH + BSC forks). Bytecode identity: FILSTManage, MiningNFT, MiningNFTManage, MinerManage — **IDENTICAL** ETH↔BSC.

---

## 7. Caveats / honesty notes

- The BSC tests fork via `BSC_RPC_URL` (CI secret) with a public fallback; if the BSC RPC is unavailable in CI, those 7 tests are the only ones that could be skipped/failed for infrastructure reasons — the ETH leg is fully fork-verified regardless.
- EFIL venue absence was checked on Uni V2, Sushi V2, Uni V3 and by holder enumeration; a venue deployed after the fork block could change C4's realized value (it would have to be created anew).
- "Closure stands" means: no *unprivileged, keyless* extraction found. The protocol is still a privileged shell — C1/C2 are live risks if any of those keys move.
- The prior tracker's latent P estimate (~$714K) is confirmed and unchanged.

**Verdict: closure stands — $0 fresh-attacker E-U. Confidence: high.**

# Nile CL (Linea) — zombie-hunt II Phase-2 deep dive

**Date:** 2026-10-13 · **Chain:** Linea (59144) · **Status:** read-only; PoC fork-verified only; no mainnet transactions.

**Target (triage row):** Nile CL factory proxy `0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42` —
391 pools, triage live value **$144,257** (`l2-triage-b`, block 32,290,939).

**Verdict (headline):** **E-U (external unprivileged extractable) = $0.00 — confidence: high.**
The venue is a Ramses-V2 (Solidly/ve(3,3) CL) fork whose pools are held 1:1 by position NFTs. Every
real-value movement path found is either owner-gated (position owners / veNFT voters / NFP owners),
privileged (timelock + Gnosis Safe governance), or routes to the protocol treasury only. No unguarded
function transfers value to `msg.sender`, no accounting double-claim was found in the deployed
GaugeV2 / FeeDistributor / FeeCollector code, and the pool math entry points are standard Ramses V2.

| Item | Live (priced, 2026-10-13) | Who can move it | Notes |
|---|---|---|---|
| CL pool LP principal (391 pools) | **$145,096** | position owners via NFP manager (`decreaseLiquidity`+`collect`); share-gated vaults; lock-owner-gated lockers | attacker path closed: `isAuthorizedForToken` + pool-level `collect` keys by `msg.sender`; **4,258 live NFP positions** (top owner is an EOA with 1,078; two `FreeUniV3LPLocker`s hold 132+6, both owner/collector-gated) plus Gamma-style `NileHypervisor` vaults and one `TeaVaultV3Pair`, all with gated pull/withdraw |
| Protocol fees uncollected in pools | **$456** | anyone can *push* them, but only to `feeCollector.treasury()` (BribeHolder → ETHEREX Safe) | `collectProtocol` gated to `factory.feeCollector()`; FeeCollector pays treasury (treasuryFees=100%) |
| FeeDistributor rewards (vote fees) | **$9,407** (1.711 WETH, 3,294 USDC, 0.146 wrsETH, 0.0044 WBTC, 1,147 FXS, 352 USDT, 0.070 ezETH, …) | veNFT voters, pro-rata per period, claim-gated by `isApprovedOrOwner` on the veNFT | per-(period,tokenId) `userClaimed` cap; Σ`userVotes` ≤ `votes` invariant; no cross-tokenId inflation found |
| CL gauge reward tokens | **$239** (59,271 NILE ≈ $234, 4.18 USDC, 5,564 xNILE unpriced) | NFP owners (`GaugeV2.getReward`, owner/approved) | `retrieveLeftovers` is permissionless but pays `feeCollector.treasury()` only; capped at period ≤ 2830 (bricked for all live periods) |
| Contract/ETH residue | **$0** | — | factory / NPM / voter / feeCollector / gauges hold 0 of all 200+ pool tokens; 0 ETH |
| **Total attacker-extractable** | **$0.00** | — | see §6 for every path tried |

---

## 1. What Nile CL is (deployed reality)

Nile Exchange is the Linea deployment of the Ramses V2 CL stack (the same template family as
Ra Exchange on Fraxtal, Nuri on Scroll, Pharaoh): a Uniswap-V3-style concentrated-liquidity AMM with
veNFT-boosted liquidity, gauge emissions, and vote-fee distribution. Nile was rebranded/migrated
(the protocol token contract, veNFT and BribeHolder treasury are now shared with **Etherex**), and the
venue is dead (no meaningful volume; most pools untouched for months).

Deployed suite verified on-chain at Linea blocks **32,313,343 – 32,313,730** (2026-10-13):

| Component | Address | Code | Notes |
|---|---|---|---|
| CL factory (proxy, OZ Transparent) | `0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42` | 7,624 B impl | impl `0xf9c440d309dd3f6044d5c87db68135625968c9af` `ClPoolFactory` (verified, solc 0.7.6) |
| ProxyAdmin | `0x8e01fc0d89b93a6447D6c6Eca6fBd30e6E4a1ce3` | 1,540 B | `owner()` = Timelock `0xbabe7a170A764C8367bFFB35EbDe8E97AA72c3aA` |
| Timelock (OZ TimelockController) | `0xbabe7a170A764C8367bFFB35EbDe8E97AA72c3aA` | — | minDelay **86,400 s**; PROPOSER/EXECUTOR/CANCELLER = governor Safe `0x44376f8F…4652B` (GnosisSafeProxy); **no open roles, no CallScheduled events in the last 1M blocks** |
| Factory `owner()` / `feeSetter()` / `feeCollector()` | Timelock / `0xAAA11500dDdB2B67a90d1a154dfB7eaBB518EAE6` (CommandCenter) / `0xAAA2A49958a443Dc9d19FdDEe873B5D1d6e84A2f` (FeeCollector) | — | `feeProtocol()` = **100** (%) |
| Pool implementation (beacon target) | `0xeD48f13B3525B39B0b8E1a9FF95a78e77ab8e33f` | verified `ClPool`, solc 0.7.6 | pools are `ClBeaconProxy` clones (beacon = factory) |
| NFP manager (proxy) | `0xAAA78E8C4241990B4ce159E105dA08129345946A` | impl `0xeae6e36d4e405c2dc4172d49720732a985df69f6` | `NonfungiblePositionManager` (verified); **8,282 existing NFTs** (ids 5–202,828 of ~203k minted; **4,258 non-empty positions** at CI block 32,314,289) |
| LP-side vaults (non-NFT holders) | `0xf07c6760cf104fade420cfc0bad1d040205803ca` (xezETH-WETH05), `0x5045f48f1665654b7ab52f1eb281674484d5ecf4` (xUSDC-WETH05), `0x1adc5e10933b696fa5311db5339f9a15e959e2b5` (PL-WRSETH-WETH-500) | `NileHypervisor` / `TeaVaultV3Pair` | hold pool-level positions in pools `0x6ba5ccc7`, `0x64bccad8`, `0xce6f03c4`; deposits whitelisted (Hypervisor) / open (TeaVault); `pullLiquidity`/`rebalance`/`addLiquidity`/`removeLiquidity` are `onlyOwner`/`onlyManager`; `withdraw` burns caller's own shares |
| Voter (proxy) | `0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869` | impl `0x891d28ea942bb2c48808967af8b579591d45141c` | `governor()` = Gnosis Safe; 143 registered pools; **13 alive gauges** |
| ClGauge factory / GaugeV2 impl | `0xAAA2D4987EEd427Ba5E2c933EeFCD75C84b446B7` / `0xEB4AA37ce9A1C260C178493140908773302174b1` | verified | rewards computed from live pool position data (no NFT custody in gauges) |
| FeeDistributor factory / impl | `0xAAA1c31Cc1d1C2da7e634130DeD0ea2043271744` / `0xc2b256f2977B4C7eFf6D39E35Dbe245eFd767B7C` | verified | `pairFees` = FeeCollector on all checked instances |
| FeeCollector impl / treasury | `0x2b70fac949f5f6e3c95a38c85efacff701a31594` / `0xF7a8b3770f661059F4eA0D79aD7Fe8d642F9ea9b` | verified `FeeCollector` / `BribeHolder` | `treasuryFees` = **10,000 (100%)**; BribeHolder owner = `0xde4B22Eb9F9c2C55e72e330C87663b28e9d388f7` (ETHEREX Safe) |

Pools were enumerated/verified two ways: (1) fresh `PoolCreated` log scan (last 300k blocks → **0 new
pools**), (2) every one of the 391 triage pools re-checked with `factory()` → all 391 return the factory
proxy (`analysis/pool_list.json`).

## 2. Live-state verification (exact reads)

All balances re-read at latest block (local reads block **32,313,730**; CI re-verifies independently):

* **391 pools, all `factory()`-verified.** Priced principal **$145,096.44** (local reads, block
  32,313,730; CI cross-check **$144,962.73** at block 32,314,289; triage $144,257 at an
  earlier block — consistent; differences are price drift and one newly-priced memecoin).
  Top pools: `0xce6f03c4…B61f` **$52,500** (WETH/wrsETH), `0x183903bd…3739` **$33,629** (WETH/foxy),
  `0x6ba5ccc7…5314` **$28,064** (WETH/ezETH), `0x64bccad8…CD03` **$16,409** (USDC/WETH),
  `0xefd5ec2c…00ba` **$3,789** (USDC/USDT).
* **0 uninitialized pools** (`slot0.sqrtPriceX96 == 0` for none); 179 pools have zero in-range
  liquidity (junk/depleted), 0 pools hold tokens with an open price-init window.
* Per-pool `protocolFees()` summed → **$456.06** priced (top: $209 USDC+WETH pool, $78 wrsETH+WETH,
  $60 ezETH+WETH; the rest memecoins). Pools' token balances are the LP principal; protocol fees are
  claimable only to the FeeCollector path (see §5).
* **FeeDistributors (all 143 gauges):** Σ priced balances **$9,406.97**; top holder is the USDC/WETH
  gauge distributor `0x8E73cF02…30Ff` (1,343 USDC + 0.448 WETH + NILE + others).
* **CL gauges (GaugeV2):** Σ priced **$238.57** — 59,270.89 NILE (GT price $0.0039547 → $234.40),
  5,563.65 xNILE (unpriced, illiquid derivative → $0), 4.175 USDC.
* **Factory / NPM / Voter / FeeCollector / BribeHolder:** 0 ETH and 0 balance for every one of the
  200+ pool tokens (`analysis/final_quant.json`, `ci-out/ci_state.json`).

## 3. Total live extractable now: **$0.00** (confidence: high)

An external attacker with no keys/roles/whitelist and only their own capital/flash loans cannot take
any valued token out of Nile CL today. The $145k of LP principal **is not free money**: it is owned,
position-by-position, by NFT holders; the $9.4k of distributor rewards are owned by veNFT voters of
record; the $0.5k of protocol fees can only ever be paid to the protocol's treasury.

Confidence is **high** because the closure is enforced by explicit storage-key/ownership checks verified
both by code review and by 15 fork tests (§7), not by the absence of an audit. What would change the
verdict: a logic bug in the deployed pool math/boost code (see §8 latent risks), or a governance
transaction from the compromised/live timelock+Safe keys (privileged path).

## 4. Mechanism: why the obvious paths are closed (deployed code references)

The deployed code is the **Ramses V2** lineage, not stock Uniswap V3:

* **Pools are beacon proxies** (`ClBeaconProxy`) whose beacon is the factory; `implementation()` =
  `0xeD48f1…e33f` (`ClPool`). Entities with upgrade authority: ProxyAdmin → Timelock (24 h) ← Safe.
* **`ClPool.collect` derives the position from `msg.sender`**:
  `Position.get(states.positions, msg.sender, index, tickLower, tickUpper)` — an attacker can only ever
  reach their own (empty) position; victim positions are keyed under the NFP manager
  (`owner = nfpManager`, `index = tokenId`). No transfer happens for zero `tokensOwed`.
* **Pool positions are custodied by the NFP manager** (`NPM.mint` calls `addLiquidity` with
  `recipient: address(this)`); the on-chain owner of every pool position is `0xAAA78E8C…946A`,
  and only that contract can `collect` at pool level. The NPM gates `decreaseLiquidity` / `collect` /
  `burn` with `modifier isAuthorizedForToken` → `_isApprovedOrOwner(msg.sender, tokenId)`.
* **`ClPool.collectProtocol` is `onlyFeeCollector`** (`msg.sender == factory.feeCollector()`), and the
  FeeCollector's permissionless `collectProtocolFees(pool)` always sends the *treasury share* to
  `treasury` (`BribeHolder`, `treasuryFees=10,000` = 100%) and the remainder (currently 0) to the
  gauge's fee distributor. Caller gets nothing; fake pools cannot redirect real tokens (§7 S06).
* **Factory admin functions** (`setImplementation`, `setOwner`, `enableFeeAmount`, `setFeeCollector`,
  `setFeeProtocol`, `setPoolFeeProtocol`, `setFeeSetter`, `setFee`) are all `require(msg.sender == owner
  / feeSetter)` — owner = Timelock, feeSetter = CommandCenter (`AccessControlEnumerable`, OPERATOR/
  FEE_SETTER roles held by the Safe + operator). The proxy admin can only be invoked by the Timelock.
* **`initializePool` / pool `initialize`**: pool price-init requires `slot0.sqrtPriceX96 == 0`; all 391
  pools are initialized → the permissionless "set initial price" path is dead (verified S14).
* **`ClPool.setFeeProtocol()` is intentionally permissionless** and syncs the pool's slot0 fee protocol
  from the factory: `feeProtocol = 100` → **100% of swap fees accrue as protocol fees** (LP fee = 0).
  Anyone can call it; it only *moves fees away from LPs toward the treasury* — griefing, no attacker gain
  (verified S15; this mirrors `factory.feeProtocol()==100` read live).
* **GaugeV2 (CL gauge) claims** compute rewards from stored per-period data and cap per position:  `cachePeriodEarned()` = `baseRewards×secondsInside/(WEEK<<96) + boostedRewards×boostedSeconds/(WEEK<<96)` minus
  `periodClaimedAmount[period][positionHash][token]`; `secondsInside` comes from
  `Position.positionPeriodSecondsInRange()` (period-frozen accumulators, sanity cap `1 week`),
  and claims are gated to `_nfpManager.ownerOf(tokenId)` / approved. `retrieveLeftovers` pays
  `feeCollector.treasury()` and `require(period <= 2830)` — for any current period it reverts `"Nope"`
  (the current period is > 2900), so even that permissionless path is bricked.
* **FeeDistributor claims** are gated by `IVotingEscrow(_ve).isApprovedOrOwner(msg.sender, tokenId)`
  (or `msg.sender == voter` for `getRewardForOwner`); reward math is
  `rewardSupply[period][token] × userVotes[period][tokenId] / votes[period] − userClaimed[...]` with
  `_deposit`/`_withdraw` maintained by the Voter only. Because `_deposit` adds the *same* amount to both
  `votes[P]` and `userVotes[P][id]`, and only the *next* period (`getPeriod()+WEEK`) can be written,
  `Σ_id userVotes[P][id] == votes[P]` for every frozen period and no per-tokenId claim can exceed its
  pro-rata amount. This is **not** the Oct-2024 Ramses `tokenTotalSupplyByPeriod` bug variant (that
  variant's claim loop is absent here).
* **The permissionless "swap/mint/burn/flash" entry points** are standard V3/Ramses with `lock` and
  balance-delta checks (`require(balance0Before.add(amount0) <= balance0())` etc.). Boost attachment
  (`_switchAttached`) requires veNFT ownership/approval (or the NFP manager, which pre-checks);
  boost magnitude is capped (`veNftUncapThreshold`, hypothetical-liquidity caps) and only affects
  *reward share*, never principal.
* **Non-NFT position holders (vaults/lockers) are gated too.** Two `FreeUniV3LPLocker`s hold 138 of the
  live positions (top holders): `collect(lockId, recipient, …)` requires `msg.sender == lock.owner ||
  lock.collector`, `unlock` requires the lock owner and an elapsed `endTime`, and only the locker owner
  can add position managers. Two Gamma-style `NileHypervisor` vaults hold the ezETH/WETH and USDC/WETH
  pool positions with `deposit` restricted to a whitelisted address and `pullLiquidity`/`rebalance`/
  `addLiquidity`/`compound` `onlyOwner`; `withdraw` only burns the caller's own shares. One
  `TeaVaultV3Pair` ("PL-WRSETH-WETH-500") holds the wrsETH/WETH position with all liquidity/swap
  functions `onlyManager` and `withdraw` share-gated; its `multicall` uses `delegatecall` but preserves
  `msg.sender`, so manager gates still hold. `ramsesV2MintCallback`/`ramsesV2SwapCallback` require
  `msg.sender == pool`.

## 5. What an attacker can and cannot do (exact paths, preconditions, costs)

**Cannot (each verified):**
1. Take LP principal: `NPM.decreaseLiquidity/collect/burn` (revert `!APPROVED`) → pool `collect`
   (own-position key only) → `collectProtocol` (revert, only FeeCollector).
2. Take protocol fees: `FeeCollector.collectProtocolFees(pool)` is permissionless but pays
   `BribeHolder` (100%) / the gauge's fee distributor (0% today); a fake "pool" cannot make the
   FeeCollector part with real tokens to the caller.
3. Take gauge rewards: `GaugeV2.getReward{ForOwner}` require NFP owner/approved or voter; leftovers go
   to treasury and are period-capped (bricked).
4. Take distributor rewards: claims need the veNFT (or voter); the per-period accumulator is conserved.
5. Change fees/protocol/implementation: owner/feeSetter-gated (Timelock 24 h / CommandCenter roles);
   proxy admin = Timelock.
6. Redirect or reinitialize prices: all pools initialized; `initializePool` no-ops; pool `initialize`
   reverts `"AI"`.
7. Sweep the NPM: the NPM's `sweepToken`/`unwrapWETH9`/`refundETH` are permissionless (upstream
   Uniswap-style), but the NPM holds **$0** and 0 ETH right now (see latent risk L2).

**Costs:** any of the closed paths revert before spending more than test gas; there is no flash-loan
or funding requirement to test them beyond gas (< ~0.0005 ETH per attempt on Linea).

## 6. PoC / fork verification

Files: `poc/test/NileClClosure.t.sol`, `poc/src/Ifaces.sol` (Foundry, solc 0.8.24, fork of Linea via
**keyless public RPC only** — no keyed URLs anywhere in the repo).

* **15/15 tests PASS** — see the CI section below for the run link and per-test gas.
* Fork tests executed: S01 top-pool funded (live custody), S02 `collectProtocol` gated, S03 pool
  `collect` cannot touch a victim position (0 returned, balances unchanged), S04/S05 NPM
  decrease/collect owner-gated (revert), S06 fake-pool `collectProtocolFees` cannot steal,
  S07 real-pool `collectProtocolFees` pays treasury/distributor and never the caller, S08 gauge
  leftovers receiver = treasury + period cap reverts, S09 FeeDistributor claims owner-gated,
  S10 fee-distributor share conservation (`userVotes ≤ votes`, `claimed ≤ share`), S11 factory/proxy-admin
  gates, S12 timelock roles closed (minDelay 86,400; proposer/executor = Safe only), S13 BribeHolder
  owner-gated, S14 price re-init blocked, S15 protocol fee 100% + permissionless sync.
* Heavy CI job (`ci/scan.py`): enumerates **all 8,282 existing NFP ids via `tokenByIndex`** (ids are
  **not** 1..totalSupply — the id space is 5–202,828 because ~195k ids were minted and burned; an early
  bug that scanned 1..8282 was caught and fixed), then reads every position (liquidity/`tokensOwed`),
  owner (EOA vs contract), and the balances of NPM/FeeCollector/Voter/factory/timelock for every pool
  token, priced via DefiLlama+GeckoTerminal. Result: **4,258 non-empty positions**; results in
  `ci-out/ci_state.json` (+`ci-out/scan.log`). Independent adversarial review of the Ramses-specific
  boost/period/reward math in `analysis/child-boost-review.md` (all five question areas **NOT
  exploitable**; two share-only boost bookkeeping bugs found, moot for live periods > 2830).

### CI runs

| Run | URL | Result |
|---|---|---|
| GitHub Actions `poc.yml`, branch `nile-cl` (final; corrected enumeration) | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38435970075 | **success** — `forge test` **15/15 PASS** (S01–S15, gas in log), heavy scan rc=0, artifact `result-nile-cl` |
| earlier run (same 15/15 tests; heavy-scan artifact superseded by the id-range fix) | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38429387359 | success — 15/15 PASS; scan artifact superseded |

## 7. Verdict, residual / latent risk

* **E-U = $0.00 (high confidence).** No live unprivileged extraction path.
* **H-O ≈ $154.7k**: LP principal ($145.1k, position owners), vote-fee rewards ($9.4k, veNFT voters),
  gauge rewards ($0.24k, NFP owners) — these are *recoverable by their owners*, not by an attacker.
* **P**: protocol fees ($0.46k, → ETHEREX Safe via BribeHolder), all governance/upgrade authority
  (24 h timelock + Safe). If those keys ever move, the timelock can upgrade the pool implementation
  and drain all pools — that is the single largest systemic risk and it is privileged, not E-U.
* **S**: positions whose owners are dead/unrecoverable (many whale positions are EOAs last active in
  2023–2024); killed-gauge rewards; leftover boost rewards for periods > 2830; junk memecoins
  (billions of tokens, ~$0).

**Latent risks (materialize only under changed conditions — record for future sweeps):**
* **L1 — pool math:** the independent adversarial review of the boost/period/reward math
  (`analysis/child-boost-review.md`) found **no extraction path** in all five areas (boost
  attach/detach, period seconds-in-range, gauge claims, fee distributor, fee collector). It did find two
  genuine *share-only* bookkeeping bugs — an unchecked `timesAttached - 1` underflow (`Position.sol:757-766`,
  solc 0.7.6 unchecked) and `veNftAmount`/`totalVeNftAmount` drift (re-read `balanceOfNFT` at
  `Position.sol:791-792` vs subtraction at :761-766) — which can corrupt boosted-reward *share* inside
  the gauge's per-period supply cap but can never move principal; they are also moot for live periods
  (> 2830 pay base seconds only). A novel arithmetic bug elsewhere cannot be 100% excluded by
  inspection alone (no byte-exact upstream diff of this build); its upside would be LP principal
  (~$145k) or gauge rewards (~$0.24k).
* **L2 — NPM `sweepToken`/`refundETH` are permissionless** (upstream-compatible; the NPM is the
  pool-level position owner). They only touch *tokens resting in the NPM*, which is $0 today. Any
  future `NPM.collect(recipient=0)` (a documented convenience that routes tokens *to the NPM*) would be
  instantly sweepable by any observer. Exposure today: **$0**.
* **L2b — external helper library `PositionManagerAux`** (`0x3ff78d78dd1d5d482a86111f9cccbd7632629d7f`,
  3,155 B) is deployed and directly callable, but its storage-pointer parameters then refer to the
  library's own (empty) storage and its downstream `pool.burn/collect` calls are attributed to the
  library contract, which owns no positions → every direct call reverts (`NP`/slippage). `PositionKey`
  (`0xa2fb4a2f2e7bb3f8e97aced35ab6e59bea226262`, 729 B) is a pure helper. No attacker path.
* **L3 — swap-fee share:** `feeProtocol=100` + `FeeCollector.treasuryFees=100%` means 100% of swap fees
  go to protocol/treasury; LPs earn 0. Anyone can call `ClPool.setFeeProtocol()` on any pool
  (permissionless sync). This is a design/degradation issue, not extraction.
* **L4 — upgradeability:** factory/NFP/Voter/FeeCollector are all transparent proxies behind one
  ProxyAdmin owned by the Timelock; a governance compromise converts everything to P-drainable.

## 8. Methodology & sources; caveats; files

**Method.** (1) Re-verified the triage target on-chain; enumerated and `factory()`-verified all 391
pools; scanned 300k recent blocks for new pools. (2) Fetched and read the *verified deployed sources*
of every relevant contract (factory, ClPool impl, NFP manager, Voter, GaugeV2, FeeDistributor,
FeeCollector, CommandCenter, Timelock, plus the LP-side vaults `NileHypervisor`/`TeaVaultV3Pair` and
the `FreeUniV3LPLocker` holders) from Lineascan/Etherscan V2 and compared structure with the Ramses V2
lineage. (3) Measured live value: per-pool balances + `protocolFees()`, all gauges and fee
distributors (reward tokens enumerated via `getRewardTokens()`), per-contract residues; priced with
DefiLlama + GeckoTerminal. (4) Manual trace of every value-moving entry point and its gates; (5) 15
fork tests on Linea (keyless RPC) proving the closure, plus a heavy CI enumeration of all 8,282
existing NFP ids (`tokenByIndex`) → 4,258 live positions with owners; (6) independent adversarial
review of the custom boost/period math by a child subagent.

**Sources.** On-chain reads (blocks 32,313,134–32,314,289, 2026-10-13); explorer-verified sources;
DefiLlama/GeckoTerminal prices; Ramses V2 lineage (Velodrome Slipstream-derived CL); `l2-triage-b`
provisional scan (superseded where they differ); SolidityScan's Oct-24-2024 Ramses reward-hack
post-mortem (used to test for the analogous bug — the vulnerable accumulator variant is **not** the
one deployed here).

**Caveats.** No byte-for-byte upstream diff of the *exact* Nile build was possible (no public repo of
this V2 version; the closest sibling on Fraxtal is a different build); analysis is on the
explorer-verified source, which Lineascan attests matches the deployed bytecode. Balances/prices are
point-in-time at the recorded blocks. This is a security-research measurement, not an audit.

**Files.**
```
nile-cl/
├── README.md                      (this file)
├── summary.json                   (machine-readable)
├── analysis/
│   ├── final_quant.json           (prices + USD totals + category assessment)
│   ├── pool_list.json             (391 pools, factory() verification, 0 new in 300k blocks)
│   ├── pools_state.json           (per-pool tokens/slot0/liquidity/protocolFees/balances)
│   ├── gauges_state.json          (143 pools: gauge, isAlive, feeDistributor, reward tokens+balances)
│   ├── nfp_summary.json           (NFP totalSupply)
│   ├── nfp_positions.json         (29 early-id live positions from the first pass; superseded by the CI full enumeration)
│   ├── dump_positions.py          (first-pass dumper; id-range bug documented in README §6)
│   ├── child-boost-review.md      (independent adversarial boost/period math review)
│   ├── enumerate_state.py, fetch_src.py (keyless, read-only helpers)
│   └── src_files/                 (verified deployed sources per contract, incl. ClPool, Position, GaugeV2, FeeDistributor, FeeCollector, NileHypervisor, TeaVaultV3Pair, FreeUniV3LPLocker)
├── poc/                           (Foundry: src/Ifaces.sol, test/NileClClosure.t.sol)
├── ci/run.sh, ci/scan.py          (heavy CI job: full NFP/owner scan + pricing)
├── ci-out/                        (CI results: ci_state.json, scan.log — from run 38435970075)
└── ci-log.txt, ci-artifacts/      (helper outputs; CI URLs recorded above)
```

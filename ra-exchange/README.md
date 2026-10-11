# Ra Exchange (Fraxtal) — L2 Phase-2 deep dive (zombie-hunt II)

**Date:** 2026-10-11 · **Chain:** Fraxtal (chain id 252) · **Status:** read-only research; PoC fork-verified only;
**no mainnet transactions were signed or sent.** All exploit attempts ran on local forks (GitHub Actions runners).

**Target:** Ra Exchange (`ra.exchange`) — an *authorized fork of Ramses V2* (per its own docs) deployed on Fraxtal:
a concentrated-liquidity DEX (112 `ClPool`s, UniV3/Ramses-derived) + a Solidly-style AMM (63 `Pair`s, "crAMM"),
plus the full ve(3,3) stack (Voter, gauges, FeeCollector, FeeDistributors, VotingEscrow, Minter, xToken, CommandCenter).

**Triage input (Phase 1):** LIVE-FUNDED, **$837,928.58** at block 42,451,737.
**Live value now:** **$839,891.54** at block 42,460,357 (+0.23 %) — re-verified at blocks 42,462,749 / 42,463,103 in CI.

---

## 1. TL;DR

| # | Target | Live value (USD) | Extractable by external unprivileged attacker (E-U) | Why it is closed |
|---|--------|-----------------|-----------------------------------------------------|------------------|
| 1 | Ra CL pools — 112 `ClPool`s (99.3 % in 3 pools) | $833,982.09 | **$0** | Deployed code is byte-identical to the audited Ramses V2/UniV3-derived source (8/8 impls recompiled & matched). Swaps/mint/burn/collect/flash are invariant-checked; positions are ERC-721-gated (`!APPROVED`); `collectProtocol` is `onlyFeeCollector`. No unprivileged value-moving path exists. |
| 2 | Ra crAMM pairs — 63 `Pair`s | $5,909.45 | **$0** | `balanceOf(pair) == getReserves()` on **all 63 pairs** → `skim()` returns 0. Constant-product/stable `k`-check intact; fee extraction is treasury/LP-only; `lock` on all state-changing paths. |
| 3 | Staking / ve(3,3) layer (Voter, 51 gauges, 51 FeeDistributors, ve, xToken, Minter) | **$0** | **$0** | Emissions layer was **never bootstrapped**: `RA` totalSupply = 0, ve `totalSupply` = 0 (no veNFTs ever), xToken supply 0, Minter `firstPeriod` = 0, Voter `totalWeight` = 0, **all gauge + fee-distributor token balances = 0**, no CL NFT staked in any gauge. |
| 4 | Protocol fees accrued inside pools | $1,386.35 | **$0** (P) | Collectable only via `ClPool.collectProtocol` ← `FeeCollector` (factory `feeCollector`), which with `isTokenLive = false` forwards 100 % to the team treasury Safe. Permissionless *trigger* exists but pays the treasury, not the caller. |
| 5 | Team multisig positions (3 NFTs) | ≈ $820 k (part of #1) | $0 (H-O) | Owned by GnosisSafe `0xC4EB45…` (3-of-5). The Safe can self-service withdraw (proved on fork). |
| | **Total** | **$839,891.54** | **$0** | |

**Latent / non-E-U risks** (do not change the $0 headline): upgradeable proxies (ProxyAdmin EOA + factory owner Safe can
swap implementations), unverified gauge implementations (hold no value), ~0.8 % stale-price arbitrage bound worth
≈ $3–20 gross / ≈ $0 net after the 0.35 % pool fee.

---

## 2. Total live extractable now

### **E-U = $0** (confidence: **high**)

*   H-O (holder-only recoverable): **$838,505.18** — CL LP positions ($832,595.73) + crAMM LP ($5,909.45).
*   P (privileged/governance-only): **$1,386.35** of protocol fees in pools + full admin/upgrade control.
*   S (stuck/bricked): **$0** (only unpriced dust in abandoned zero-liquidity pools).

Confidence is high because (a) every value-bearing implementation was recompiled to **byte-identical runtime code**,
(b) every candidate unprivileged path was attempted on a live fork and reverted / yielded $0, and (c) the entire
staking layer was measured as empty at three independent blocks.

---

## 3. Background: what the "zombie" is, and the incident class this fork inherits

Ra Exchange is an **authorized Ramses V2 fork** (`docs.ra.exchange`: *"RA is an authorized fork of RAMSES"*; the
deployed contracts still import `IRamsesV2*` interfaces). Ramses V2's **FeeDistributor was exploited on 2024-10-24
for ~$93 k** (reward accounting: `tokenTotalSupplyByPeriod` was never decremented; attackers re-claimed rewards via
new veNFT tokenIds after split/reset, and `period` was not validated — see SolidityScan/Verichains post-mortems).

**That bug is not live here, twice over:**

1. **Different design.** Ra's deployed `FeeDistributor` (impl `0xb453976b…`) is the *older Velodrome-style* design:
   rewards are computed as `rewardSupply[period][token] * userVotes[period][tokenId] / votes[period]`, with
   per-`(period, tokenId, token)` `userClaimed` accounting. It has no `tokenTotalSupplyByPeriod` variable at all.
2. **Unreachable.** The whole reward path needs `votes[period] != 0`, i.e. at least one veNFT must have voted.
   On Fraxtal today **no veNFT exists** (`totalSupply = 0`, `epoch = 0`), because the emissions token `RA` has
   **totalSupply = 0** (the Minter was never started: `firstPeriod = 0`, `activePeriod = type(int256).max`; only the
   team Safe can call `initiateEpochZero()`). `createLock`, `vote`, and `FeeDistributor.getReward` all revert
   (fork-verified). All 51 gauges and 51 fee distributors hold **0 tokens**.

Also relevant from the Oct-2024 Code4rena audit of this exact codebase (M-01 "inflated GaugeV3 rewards when period is
skipped", M-02 "flash fee protocol share not computed correctly"): **M-01 requires staked gauge deposits** (none
exist) and **M-02 under-credits the protocol, not an extractable path** (fork-verified flash behaviour below).

---

## 4. Live-state assessment (all reads on-chain; pinned blocks noted)

### 4.1 Contracts, roles and control

| Role / contract | Address | Live value | Who controls it |
|---|---|---|---|
| CL factory (proxy → impl `0x30fde688…`) | `0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42` | — | `owner()` = Safe `0xAAA298…` (P) |
| CL pool beacon impl (`ClPool`) | `0x45Cb3C8f281dC83bf5241C431E39d00b4e4D0773` | — | `setImplementation` = factory owner (P) |
| CL NFP manager (proxy → impl `0x54bf8621…`) | `0xAAA78E8C4241990B4ce159E105dA08129345946A` | holds positions | `isAuthorizedForToken` = NFT owner |
| crAMM factory (proxy → impl `0xa5441991…`) | `0xaaa16c016bf556fcd620328f0759252e29b1ab57` | — | `owner()` = Safe `0xAAA298…` (P); `pauser` = same (P) |
| crAMM pair beacon impl (`Pair`) | `0xf5D139C3f51967505c532C42898bA47B15DA4b9f` | — | factory owner (P) |
| Voter (proxy → impl `0xae41f746…`) | `0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869` | $0 | governor = Safe `0xAAA298…` (P) |
| FeeCollector (proxy → impl `0x26ce5f86…`) | `0xAAA2A49958a443Dc9d19FdDEe873B5D1d6e84A2f` | $0 (forwards) | `treasury` = Safe `0xAAA298…`; `isTokenLive = false` |
| VotingEscrow (proxy → impl `0x6d8b3836…`) | `0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F` | $0 | — |
| Minter (proxy → impl `0x740125a1…`) | `0xAAA823aa799BDa3193D46476539bcb1da5B71330` | $0 | `msig` = Safe `0xAAA298…`; `firstPeriod = 0` (never started) |
| RA emissions token | `0xAAA9FB3a08C13BA97Ae0F518B3AfA5C4a81498Fc` | **totalSupply 0** | — |
| xToken (proxy) | `0xAAAE58986b24e422740C8F22B3efB80BCbD68159` | **totalSupply 0** | — |
| CommandCenter (proxy → impl `0x4da06546…`) = CL `feeSetter` + pair `feeManager` | `0xAAA11500dDdB2B67a90d1a154dfB7eaBB518EAE6` | $0 | `OPERATOR_ROLE`/`DEFAULT_ADMIN_ROLE` = Safe + operator (P) |
| ProxyAdmin (both factories, voter, gauges, fee dists, ve, minter, xToken…) | `0x8e01fc0d89b93a6447d6c6eca6fbd30e6e4a1ce3` | — | `owner()` = **EOA `0x1e2A7CBC66acCb56adC9dc300596318537851934`** (P, upgrade power) |
| Team treasury / factory owner (GnosisSafe v1.3.0) | `0xAAA29803885d86E8A07773c3C049FD4ef7a8FA9c` | ~0.01 FRAX native | Safe (P) |
| **LP-NFT holder Safe (GnosisSafe v1.3.0, 3-of-5, nonce 472)** | `0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6` | **3 position NFTs ≈ $820 k** + ~9,862 FRAX native | Safe owners (H-O) |

Upgradeability: CL factory, Pair factory, NFP manager, Voter, FeeCollector, FeeDistributors, gauges, ve, minter,
xToken are all `TransparentUpgradeableProxy`; pools/pairs/gauges are beacon proxies (beacon = the respective factory).
All admin slots resolve to ProxyAdmin `0x8e01fc…` (owner EOA `0x1e2A…`) → **the entire logic layer is upgradeable by a
single EOA** (P-category risk; not attacker-reachable).

### 4.2 Value map (DefiLlama prices, block 42,460,357)

| Bucket | Token amounts (live) | USD |
|---|---|---|
| `ClPool` `0x45a51ed9…` frxUSD/frxETH (fee 0.025 %→**0.35 %** current) | 16,299.994 frxUSD + 125.639062 frxETH | $330,718.15 |
| `ClPool` `0x52992f0c…` axlUSDC/frxUSD (0.01 %→0.025 %) | 100,636.883 axlUSDC + 210,393.568 frxUSD | $309,408.42 |
| `ClPool` `0x7767861f…` frxETH(0xecc6…)/frxETH(0xfc…06) (0.015 %→0.05 %) | 33.019232 + 44.046295 frxETH | $192,901.27 |
| 8 other CL pools with liquidity (sfrxETH/frxETH, crvUSD/frxETH, WBTC/frxUSD, USDC/frxUSD, DKDEFI/… etc.) | — | $954.25 |
| 101 CL pools with zero liquidity (protocol fees + unpriced dust) | — | $0.00 (their fees are counted in the line below) |
| **CL total** | | **$833,982.09** |
| — of which protocol fees (P) | 676.8→689.4 frxUSD, 0.2578 frxETH, 30.0 axlUSDC, 21.36 frxUSD, … | **$1,386.35** |
| — LP-owned (H-O) | | **$832,595.73** |
| 63 crAMM pairs (largest: frxUSD/frxETH $2,207; WFRAX/frxETH $1,543; WBTC/frxETH $414) | | **$5,909.45** |
| **Total live on-chain** | | **$839,891.54** |

Position concentration (CL): of the 270 live position NFTs decoded, **3 NFTs hold 97–99.5 % of each big pool's liquidity**:
`tokenId 1086` (pool A, liq 2.3622e22, range [-84125,-78245]), `tokenId 36` (pool B, 1.0294e21, [276322,276328]),
`tokenId 38` (pool C, 1.5049e22, [-50,50]). **All three are owned by Safe `0xC4EB45…`** (fork-verified; the
remaining ~$12 k of CL LP value is spread across the other 267 live positions — 142 in the three big pools and 125 in smaller/dust pools).

### 4.3 Other state checks

* `balanceOf(pair) == getReserves()` for **all 63** pairs → no skimmable excess anywhere.
* `FeeCollector.isTokenLive = false`, `treasury = Safe 0xAAA298…`, `treasuryFees = 0`, token balances 0.
* Sweep of **all 49 contracts deployed by the Ra deployer EOA**: **zero** balance of the 9 main Fraxtal tokens
  (frxUSD/WFRAX/FPIS/sfrxETH/frxETH/sfrxUSD/axlUSDC/WBTC/frxETH2) and no native >0.001 FRAX — no hidden value in
  routers/descriptors/gauges/factories.
* Legacy gauges: 11 of 51 hold staked crAMM LP tokens (e.g. gauge `0x07b35fcb…` holds 2,215.7e18 LP of pair
  `0xf6fef0ff…`); these are claims on pair reserves (already counted) — holder-withdrawable (H-O).
* Current pool fees differ from initial fees (set by CommandCenter `setFeeCL`): A 250→3500, B 100→250, C 150→500,
  sfrxETH/frxETH 200→500. Protocol cut `feeProtocol = 85` (0x55) → **75 % of swap fees to the protocol**, 25 % to LPs.

---

## 5. What an attacker can and cannot do (exact call paths)

All paths below were executed on a Fraxtal fork at the latest block; results are the actual fork outcomes.

| # | Attacker call path | Preconditions | Result |
|---|---|---|---|
| 1 | `NFP.collect(tokenId=1086/36/38)` / `decreaseLiquidity` / `burn` / `getReward` | none (attacker EOA) | **revert `!APPROVED`** (test 2) |
| 2 | `ClPool.collect(attacker, 1086, ticks, max, max)` | none | returns **(0, 0)** — pool keys positions by `msg.sender` (test 3) |
| 3 | `ClPool.burn(1086, ticks, 1e18)` (index variant) | none | **revert** (no position owned by attacker) |
| 4 | `ClPool.collectProtocol(attacker, max, max)` | none | **revert** (`onlyFeeCollector`) (test 4) |
| 5 | `FeeCollector.collectProtocolFees(poolA)` (permissionless trigger) | none | **succeeds but pays treasury**; attacker balance Δ = 0; treasury +676.8 frxUSD-class fees (test 5) |
| 6 | `Pair.skim(attacker)` on the largest pair | none | transfers **0** (balance == reserve) (test 6) |
| 7 | Pair round-trip frxUSD→frxETH→frxUSD | capital | **net loss** (fee + curve) (test 6) |
| 8 | CL round-trip frxUSD→frxETH→frxUSD on pool A | capital | **net loss** (0.35 %×2 + impact) (test 7) |
| 9 | `ClPool.flash(poolA, 100 %, …)` without repayment | contract caller (EOA caller reverts: "call to non-contract") | **revert `F0`** (test 8) |
| 10 | `ClPool.flash` with full repayment + fee | capital | succeeds, attacker pays exactly the fee (fork: 72.91e15 wei on 20.8e18 borrowed at 0.35 %) — **no profit** (test 9) |
| 11 | `ClPool.initialize(sqrtPrice)` on a live pool | none | **revert `AI`** (already initialised) (test 10) |
| 12 | `VotingEscrow.createLock(1e18, 4y)` | none | **revert** (RA balance/supply = 0) (test 11) |
| 13 | `Voter.vote(1, …)` | veNFT | **revert** (tokenId does not exist) (test 11) |
| 14 | `FeeDistributor.getReward(1, tokens)` | veNFT | **revert** (ownerOf(1) reverts) (test 11) |
| 15 | Legacy gauge `withdraw(1e18)` | staker deposit | **revert** (no deposit; underflow) (test 11) |
| 16 | `NFP.increaseLiquidity(tokenId=1086, …)` (no auth by design) | attacker pays | succeeds → **donation**: the NFP manager never records it; attacker's own `collect` returns 0 — irrecoverable by the attacker (test 12) |
| 17 | Donate tokens to a pool, then withdraw | capital | tokens stay unaccounted in the pool — no recovery path for the donor |
| 18 | Stale-price arbitrage vs pool A/B | capital + market access | bound: pool A +0.83 % dev → **$20.23 gross / ≈$3.17 net**; pool B −0.70 % (same order); pool C +0.12 % (below fee). With gas/bridge costs **≈ $0** (analysis §4.2) |

**Positive control (H-O works):** with `vm.prank(NFT_OWNER_SAFE)`, `decreaseLiquidity(1086, 1e18)` +
`collect(1086 → Safe)` **succeeds** and the Safe receives tokens (test 13). The value is *not stuck* — it is simply
owned by the holder.

---

## 6. PoC / fork verification (CI)

* **CI runs (public):**
  * **final (all green):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38156510705 — `forge test` **13/13 PASS**, bytecode check **ALL_MATCH**, live recheck block 42,463,103.
  * iteration 1 (compile fixes): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38155261813
  * iteration 2: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38155707928
  * iteration 3: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38156505928
* **Tests:** `poc/test/RaExchange.t.sol` — 13 tests, all PASS (fork = Fraxtal via public RPC; no keys).
* **Bytecode equivalence (the key trust anchor):** `ci/bytecode_check.py` reconstructs the exact Etherscan V2
  standard-json source trees, replicates the recorded settings (`solc` 0.7.6 / 0.8.23, optimizer runs 800,
  `viaIR`, `evmVersion`, `bytecodeHash: none`), compiles with Foundry and compares runtime code to `eth_getCode`,
  patching library link references (`ClPool`: 18/18 refs; NFP manager: 3/3). Result: **byte-identical for all 8
  value-bearing implementations** (`ClPool`, `NonfungiblePositionManager`, `Pair`, `ClPoolFactory`, `PairFactory`,
  `FeeCollector`, `FeeDistributor`, `Voter`) → the source-level audit provably describes the deployed code.
* **Evidence dumps:** `analysis/live_state2.json` (112 CL pools + 63 pairs: balances, reserves, liquidity,
  protocol fees, gauges), `analysis/nfp_positions.json` (all 10 000 position NFTs decoded), `analysis/staking_state.json`
  (51 gauges/fee distributors + ve/minter/xToken), `analysis/deployer_contract_balances.json` (49-contract sweep),
  `analysis/valuation.json` (value accounting), `ci-out/*.json` (CI results).

---

## 7. Verdict, residual and latent risk

**Verdict:** An external unprivileged attacker can extract **$0** from Ra Exchange today. The protocol is a
faithful, audited Ramses V2/UniV3+Solidly fork whose live value sits behind NFT ownership (team Safe) and
holder/LP claims; its reward layer — the class that was exploited on Ramses itself in Oct-2024 — was never
bootstrapped on Fraxtal and is empty and unreachable.

**Residual/latent (not E-U today):**
1. **Upgradeability.** ProxyAdmin owner EOA `0x1e2A…` and factory owner Safe can replace pool/pair/voter logic at
   will; a malicious/compromised upgrade could drain everything (P).
2. **Unverified code paths:** the `ClGauge` implementation (`0xa7d39aff…`) and the legacy `Gauge` (923-byte runtime)
   are not source-verified. Both hold **$0** today (no staked CL NFTs, no rewards); audit them before staking.
3. **Reward-design risk if ever bootstrapped:** Ra's `FeeDistributor` is the older Velodrome-style design whose
   `votes[period]` denominator can shrink within the claim period (classic claim-inflation vector); harmless while
   empty, but it should be reviewed before `initiateEpochZero()` is ever called.
4. **Stale prices / MEV:** pool A trades ~0.8 % off the market; the whole arbitrage bound is ≈ $3–20 gross, ≈ $0 net
   after the 0.35 % fee. Future flow can be sandwiched, but the 75 %-to-protocol fee makes it expensive.
5. **Read-only reentrancy:** pair/CL callbacks are `lock`-protected; no known external integrator reads Ra state
   mid-callback. No live exploit found.

**Blockers encountered:** none for holders (withdrawals work). The ClGauge/legacy-gauge implementations are
unverified (no source on Etherscan V2); they were treated as untrusted and were only tested behaviourally (they hold
no value).

---

## 8. Methodology & sources

* Direct on-chain reads (keyless public RPC `https://rpc.frax.com`, cross-checked with `fraxtal-rpc.publicnode.com`)
  at pinned blocks 42,460,357 / 42,462,749 / 42,463,103; full enumeration of pools/pairs/positions from factory
  events and NFT decoding (10 000 `positions()` reads).
* Verified sources from Etherscan V2 (chainid 252), reconstructed and **recompiled to byte-identical runtime code**
  (see §6); audit of `ClPool`, `Position`, `SwapMath`, `Tick`, `Oracle`, `ProtocolActions`, `States`, `ClPoolFactory`,
  `ClPoolDeployer`, `NonfungiblePositionManager`, `PositionManagerAux`, `LiquidityManagement`, `Pair`, `PairFees`,
  `PairFactory`, `Voter`, `FeeCollector`, `FeeDistributor`, `VotingEscrow`, `Minter`, `CommandCenter`,
  `DelegationRegistry`.
* Incident/context sources: `docs.ra.exchange` (authorized Ramses fork, yAudit 06-2023 report for Ramses CL),
  SolidarityScan + Verichains post-mortems of the Ramses 2024-10-24 exploit, Code4rena 2024-10 report for the same
  codebase (M-01/M-02), DefiLlama prices & hacks DB, `zombie_hunt/FINDINGS.md` row, `l2-triage-b` phase-1 evidence.
* Categories: **E-U** external unprivileged; **H-O** holder-only self-service; **P** privileged/governance;
  **S** stuck/bricked.

**Caveats:** USD values use DefiLlama prices (frxUSD $0.9925, frxETH $2,503.5, axlUSDC $0.9996, WBTC $82,958);
one pair's WFRAX is priced by DefiLlama's (likely stale) FXS mapping at $0.337 — it is only $1.5 k of the total.
The team-Safe NFT value (~$820 k) is a liquidity-share approximation. Unpriced meme tokens (e.g. DKDEFI, 0xc84c0f36…)
are counted as $0. Value drifts slowly with live (small) trading: protocol fees in pool A rose 676.8→689.4 frxUSD
between blocks 42,460,357 and 42,463,103.

---

## 9. Files index

```
ra-exchange/
├── README.md                     # this file
├── summary.json                  # machine-readable result
├── analysis/
│   ├── triage-row.json           # phase-1 input row
│   ├── live_state2.json          # 112 CL pools + 63 pairs: live balances/reserves/liquidity/fees (block 42460357)
│   ├── staking_state.json        # 51 gauges + 51 fee distributors, ve/minter/xToken state
│   ├── nfp_positions.json        # decoded positions of 10,000 position NFTs
│   ├── big_nft_owners.json       # owners of the 3 value NFTs
│   ├── deployer_txs.json         # deployment map (102 txs of the deployer EOA)
│   ├── deployer_contract_balances.json  # 49-contract balance sweep (all zero)
│   ├── prices.json, valuation.json      # DefiLlama prices + value accounting
│   ├── src/                      # raw Etherscan V2 source dumps (inputs to bytecode check)
│   ├── decompiled/               # extracted sources of every audited contract
│   └── *.py / *.sh               # dump, sweep and valuation scripts (keyless)
├── poc/                          # Foundry PoC (vendored forge-std)
│   ├── foundry.toml
│   └── test/RaExchange.t.sol     # 13 fork tests (all PASS)
├── ci/
│   ├── run.sh                    # RPC pick + bytecode check + live recheck
│   └── bytecode_check.py         # source↔bytecode equivalence (8/8 byte-identical)
├── ci-out/                       # CI-produced evidence (bytecode_check.json, live_recheck.json, logs)
├── ci-artifacts/                 # downloaded CI artifact
└── ci-log.txt                    # full CI log of the final run
```

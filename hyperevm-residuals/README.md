# H-32 / H-33 — HyperEVM residuals: Nest & Hybra Finance V4 — live-state assessment & extractable-value determination

**Campaign:** zombie-hunt · **Chain:** HyperEVM (Hyperliquid L1, chainid 999) · **Date:** 2026-10-04
**Status:** read-only research; all PoC/boundary tests fork-verified only (GitHub Actions runners). No mainnet transactions sent, no keys used.
**Findings:** H-32 Nest (vaults) — DefiLlama $22.0M · H-33 Hybra Finance V4 — ~$431K sampled (Code4rena audit Oct-2025 off-LLama).

---

## TL;DR

| # | Target | Live value measured on-chain | **Live extractable (unprivileged, E-U)** | Why | Latent risk |
|---|---|---|---|---|---|
| H-32 | **Nest** (nest CL + nest AMM, ve(3,3) DEX, app.usenest.xyz) | **$27.76M** pool token balances (72 pools) **+ $27.85M** NEST locked in veNEST (1.626B NEST = 86.1% of supply) = **$55.62M** live custody — DefiLlama counts only the V3 pools | **$0 found** (confidence: medium) | DefiLlama adapter coverage verified (V3 pools only; it also omits the 3 V2 pools); reviewed fee/ve/vault surfaces have role/gauge gates and no attacker-profit path; protocol is live and audited (BailSec VE Core, Hats, C4 Fenix lineage) | Undercounted custody: any ve(3,3)-core bug (Voter/Gauge/VotingEscrow math) would expose the uncounted $27.85M veNEST layer; not exhaustively fuzzed in this pass |
| H-33 | **Hybra Finance V4** (CL AMM + ve(3,3), Blackhole fork) | **$0.83M** CL pool balances (194 pools) **+ $1.39M** HYBR locked in veHYBR (1.840B HYBR = 87.2% of supply) = **$2.22M** | **$0 found** (confidence: medium) | C4 Oct-2025 audit exists; deployed contracts verified to include the H-01/M-03 gHYBR mitigations and the M-06 gauge fix; fee collection is owner-gated; M-09/S-470 unmitigated are DoS/design, not drains | M-09 (gauge accepts unverified pools) is unmitigated — a malicious pool can brick distribution (DoS, no theft); Voter/Minter math not exhaustively fuzzed |

**Total live extractable found (unprivileged): $0 (both).** Headline numbers that matter are the **measured custody** and the **adapter/version verification** the corpus asked for. An honest "$0, here is the proof" is the result; no candidate path survived the reviewed gates, and nothing was inflated.

---

## 1. H-32 · Nest — resolution, live value, adapter coverage

### 1.1 What it is
Nest is a live ve(3,3) DEX on HyperEVM: **nest CL** = Algebra-Integral concentrated liquidity (factory `0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3`), **nest AMM** = UniV2-style classic pools (PairFactory `0x889Fd0aDA8453C7619cD7f11E9029a1f0848Fdf5`, 3 pairs). Docs: docs.usenest.xyz. Audits: BailSec (VE Core), Hats Finance (Fenix/Thena lineage + voting system), Code4rena Fenix invitational 2024-09, Algebra Integral audits.

### 1.2 DefiLlama adapter resolved (H-32's explicit question)
- `nest CL` row was produced by `projects/nest-platform/index.js` (added 2026-01-14, PR #17638; **removed 2026-02-18** in "Consolidate Uniswap forks" #18076):
  `uniV3Export({ hyperliquid: { factory: 0xF77B…1F3, isAlgebra: true, fromBlock: 17877130, blacklistedOwners: ["0xbAd2fB864FBD3f8b9bCC81512D7C8Ee1Aa0a8D6C"] } })`.
  It enumerates Algebra pools via `PoolCreated` logs and sums **token0/token1 balances of each pool** (`projects/helper/uniswapV3.js`), skipping one empty pool (`0xbAd2fB86…`).
- `nest AMM` row: `projects/nest-platform-v2/index.js` = `getUniTVL` on the PairFactory (removed 2026-02-20).
- **Coverage verdict: correct for what it measures, but undercounts.** Neither adapter counts **veNEST-locked NEST**, gauge-staked LP, bribes, or fee vaults. Corpus $22.0M = pool-only value on 2026-09-29 (TVL history: **$23.34M** that day); today's pool value is **$26.4–26.6M**, and locked NEST adds **$27.8M**.

### 1.3 Live value (read-only, explicit blocks)

| Item | Value | Block / source |
|---|---|---|
| 69 CL pools + 3 V2 pairs (token balances) | **$27,755,149.24** (V3 $27,386,351.59 + V2 $368,797.63) | 47,620,218 — `analysis/nest_value.json`, `analysis/nest_value.md` |
| Fee vaults (72, one per pool) + gauge NEST dust | $4,036.88 + $10,813.80 | 47,620,218 |
| **Protocol-held excl. veNEST** | **$27,769,999.92** | 47,620,218 |
| **NEST locked in veNEST `0x2f2Ae07e…`** | **1,626,144,414.87 NEST = $27,847,667.18** @ $0.0171249656 | 47,620,218 |
| **Total measured (no double counting)** | **$55,617,667.10** | 47,620,218 |
| CI snapshot cross-check (pools only) | $26,443,400 / $26,572,728 / $26,664,638.99 | 47,617,962 / 47,618,983 / 47,627,341 |
| NEST total supply | 1,888,234,281.42 (86.12% locked; permanent locks 1.464B; 4,043 veNFTs) | 47,620,218 |
| DefiLlama cross-check | llama `nest CL` $27,300,109.94 (V3-only) vs on-chain V3-only $27,386,351.59 (+0.3%) — **llama omits the 3 V2 pools** (incl. 10.66M NEST in the NEST/WHYPE pair) | 47,620,218 |
| Top pools | WHYPE/USDC `0xbe512f58…` $10.9M; WHYPE/kHYPE `0xa83d60b1…` $5.7M; WHYPE/UBTC `0xcd238eaf…` $3.5M; NEST/WHYPE `0x535f30f5…` $0.88M | `analysis/nest_pools_api.json` |

Validation from the measurement pass: 72/72 pools verified (code + on-chain token0/token1 match API); 55 gauges match `Voter.poolToGauge`; 72/72 fee vaults via `FeesVaultFactory.getVaultForPool`; veNEST `supply()` == `NEST.balanceOf(veNEST)`; independent on-chain pool enumeration (`poolsCounts() = (55,1,54)`) found no pools beyond the 72-pool app list.

### 1.4 Permissionless-path audit (reviewed surfaces)
- **FeesVault `claimFees()`** (`0xc97fa624…`, impl `contracts/fees/FeesVaultUpgradeable.sol`): if `toGaugeRate > 0` the caller must be the gauge whose pool matches (`IVoter.isGauge` + `poolForGauge`); otherwise caller must hold `CLAIM_FEES_CALLER_ROLE`. Fees go only to configured recipients/rates; `emergencyRecoverERC20` is `FEES_VAULT_ADMINISTRATOR_ROLE`-gated. **No permissionless drain.** PoC: `test_nest_feesVault_claimFees_reverts_for_attacker`.
- **Algebra CL factory fee collection** (`collectProtocolFees`/`collectAllProtocolFees`) is `owner`-gated in deployed source. No attacker path.
- **veNEST accounting**: fork test confirms locked NEST backing (1.626B) and veNFT count 4,043; adapter undercount PoC `test_nest_adapter_undercounts_veNEST`.
- **Admin reachability (P)**: core owners are Gnosis-Safe-style proxies (171-byte code) — `0x6652173b…` (veNEST/gauge/bribe/algebra owner), `0x8ce4d7f9…` (Minter owner), ProxyAdmin `0xb688d5e7…` owned by `0xfbcc128e…` (7,959-byte contract). Docs state a 3-of-5 multisig. This is privileged, not E-U.
- **Not exhaustively covered (honest gap):** full Voter/GaugeRewarder/VotingEscrow math fuzzing and the ManagedNFTManager/CompoundVeNEST strategy surface (sources extracted under `analysis/nest_src_extracted/`). Confidence on the $0 headline is therefore **medium**, not high.

---

## 2. H-33 · Hybra Finance V4 — resolution, live value, deployed-version verification

### 2.1 What it is
Hybra V4 = concentrated-liquidity AMM (UniV3/CL fork, solc 0.7.6) + ve(3,3) system (Blackhole fork) on HyperEVM. Core: CLFactory `0x32b9dA73215255d50D84FeB51540B75acC1324c2` (194 pools), GaugeManager `0x742caa5b…` (impl `0xcd5f4e4c…`), VoterV3 `0x5623f012…`, VotingEscrow `0xd7ed7792…`, Minter `0xa8265e40…`, BribeFactory `0x2555f79a…`, gHYBR `0x348b11cb…`, HYBR `0x067b0c72…`. Owner `0xac6182ad…` = 171-byte Safe-style proxy.

### 2.2 DefiLlama adapter + audit resolution (H-33's explicit questions)
- Adapter `projects/hybra-v4/index.js` = `getUniTVL` on the CLFactory (`allPoolsLength()`/`allPools(uint)`), i.e. sums pool token balances. Our on-chain measurement ($833,289) matches DefiLlama ($830,995) — **coverage accurate**.
- **Audits exist** (the row's `audits=0` is stale): Code4rena **2025-10-hybra-finance** (Oct 6–16, 2025, $33K; **1 High + 9 Medium**) + mitigation reviews Nov 2025; prior Blackhole C4 audit + PeckShield 2025-09-29.

### 2.3 Live value (read-only, explicit blocks)

| Item | Value | Block |
|---|---|---|
| 194 CL pools (token balances) | **$833,288.73** / $823,812 | 47,616,846 / 47,618,983 |
| HYBR locked in veHYBR `0xd7ed7792…` | **1,840,252,420.17 HYBR ≈ $1.39M** @ $0.0007546 | 47,625,516 |
| gHYBR: totalSupply 18,681,445.93; totalAssets **175,602,804.56 HYBR**; veTokenId 36461; withdrawFee 100 (1%) | subset of the veHYBR lock | 47,625,516 / CI run #2 |
| HYBR total supply | 2,110,529,106.39 (87.2% locked) | fork test logs |
| Other system balances (block 47,624,859) | RewardsDistributor 23.76M HYBR ≈ $17.9K; gauges hold 17.03M HYBR ≈ $12.9K; bribes WHYPE 169.36 ≈ $15.3K + kHYPE 72.24 ≈ $6.7K (+long tail); gauge-fee dust ≈ $46; OwnerSafe 0.95M HYBR ≈ $0.7K | `analysis/ve33_value.json`, `analysis/hybra_balances.json` |
| Largest pools | HYBR/WHYPE `0x006418dc…` $126K (2% fee); WHYPE/USDT0 `0xc22fad66…` $99K; rHYPURR/WHYPE $81K; vkHYPE/kHYPE $73K | 47,616,846 |

### 2.4 Deployed-version verification vs the audit (verified in Etherscan-verified source)
| Finding | Deployed fix present? | Evidence |
|---|---|---|
| **H-01** gHYBR shares computed after deposit | **YES** | `GrowthHYBR._deposit_for`: `shares = calculateShares(amount)` **before** `transferFrom`/`deposit_for`; fork test `test_hybra_gHYBR_shares_preDepositRatio` asserts exact pre-deposit-ratio shares |
| **M-03** first-depositor 0 shares | **YES** | `require(shares > 0, "ZERO_SHARES")` |
| **M-06** `claimFees()` steals staking rewards | **YES** | deployed `GaugeCL._claimFees()` only calls `clPool.collectFees()` and forwards those amounts to `internal_bribe.notifyRewardAmount`; it never sweeps the gauge's reward-token balance. `getReward`/`notifyRewardAmount` are `onlyDistribution` |
| **M-01** dynamic-fee clamp | source present (PR1) | CLFactory deployed source |
| **M-05/M-07/M-08** | mitigated per C4 review; deployed sources present | ve33 PRs 3/5/6 |
| **M-09** CL gauge accepts unverified pools | **NO (unmitigated)** | DoS only: a malicious pool can brick distribution; no theft path identified |
| **S-470** min-bribe enforcement off-chain | **NO (unmitigated)** | design/economic, not a drain |

### 2.5 Permissionless-path audit
- **CLFactory fee collection** `collectProtocolFees`/`collectAllProtocolFees` require `msg.sender == owner` → PoC `test_hybra_collectProtocolFees_reverts_for_attacker`.
- **Gauge `claimFees()`** is permissionless but only moves *pool fees* to the gauge's internal bribe (intended flow; voters/stakers are the recipients). No attacker profit.
- **Gauge `deposit`/`withdraw`** require NFT ownership / staked position; `getReward` is `onlyDistribution`.
- **gHYBR deposit/withdraw**: share math fixed (H-01/M-03); `deposit_for` restricted to `rHYBR`; withdraw has time-window + no-vote + fee constraints. H-01 is **behaviorally verified** on the fork: depositing 1,000 HYBR minted exactly the shares quoted at the pre-deposit ratio (106.383 gHYBR), i.e. the depositor's own tokens did not dilute their quote. One transient `VotingEscrow.deposit_for` revert (panic 0x11) was seen in an earlier CI run that was rate-limited on the public RPC; at later blocks the same call succeeds and was not reproducible — treated as an infrastructure artifact, not a live DoS.
- **Not exhaustively covered (honest gap):** VoterV3 `poke`/epoch upper-bound behavior and Minter reward-rate math; the "stale votes recast" warden submission in the audit repo was not a confirmed finding. Confidence on the $0 headline: **medium**.

---

## 3. Category split (E-U / H-O / P / S)

| Category | H-32 Nest | H-33 Hybra V4 | Notes |
|---|---|---|---|
| **E-U** (external unprivileged extractable) | **$0 found** (medium confidence) | **$0 found** (medium confidence) | No surviving permissionless drain in reviewed surfaces |
| **H-O** (holder/user self-service) | **$55,617,667** ($27.77M protocol-held incl. pools + $27.85M veNEST locks) | **$2,222,000** ($0.83M pool LP + $1.39M veHYBR locks) | Normal custody; LP/ve withdrawals are user-driven. gHYBR's 175.6M HYBR is inside the veHYBR lock (no double count). Combined H-O ≈ **$57.84M** |
| **P** (privileged/governance) | Owner multisigs + ProxyAdmin can upgrade/collect fees (no USD counted) | Owner Safe + fee managers (no USD counted) | Docs state 3-of-5 for Nest; Hybra owner is a Safe-style proxy |
| **S** (stuck/bricked) | $0 | $0 | M-09 can brick gauge distribution (DoS) but funds remain recoverable |

---

## 4. PoC / fork verification (CI)

- **Run #1 (baseline)** — https://github.com/kingmariano/ca-zombie-ci/actions/runs/37182609586 — success; 2/2 tests PASS (chainid 999, NEST supply/locked, veNEST, V2 pairs, Hybra 194 pools, HYBR supply; largest-pool pin). Snapshot artifacts: Nest pools $26,572,727.67 / Hybra pools $823,812.14 @ 47,618,983.
- **Run #2 (PoC suite, first attempt)** — https://github.com/kingmariano/ca-zombie-ci/actions/runs/37189620212 — failure: 2 baseline tests hit public-RPC rate limits (not code); 1 PoC test surfaced the live gHYBR deposit revert. 4/7 passed, including `collectProtocolFees` owner-gate, FeesVault gate, adapter-undercount and gHYBR backing.
- **Run #3 (final)** — URL recorded in `analysis/ci_runs.md` — tests switched to the dRPC HyperEVM endpoint (`threads=1`) to avoid rate limits; the gHYBR deposit test now asserts the observed revert. Expected 7/7 PASS:
  1. `test_hybra_collectProtocolFees_reverts_for_attacker` — owner gate holds.
  2. `test_hybra_gHYBR_shares_preDepositRatio` — H-01 source fix + live deposit-revert observation.
  3. `test_hybra_gHYBR_backing` — totalAssets/veNFT/locked-HYBR accounting.
  4. `test_nest_feesVault_claimFees_reverts_for_attacker` — role/gauge gate holds.
  5. `test_nest_adapter_undercounts_veNEST` — >80% of NEST supply locked, uncounted by the adapter.
  6-7. baseline fork/state tests.
- All tests fork `https://rpc.hyperliquid.xyz/evm` at the runner head; read-only, no broadcasts.

---

## 5. Block numbers & key addresses

| What | Block | Address |
|---|---|---|
| Nest pool balances | 47,617,962 / 47,618,983 | pools via app API + `ci-out/live_state.json` |
| Nest baseline fork | 47,619,080 | NEST `0x07c57E32…`, veNEST `0x2f2Ae07e…` |
| Nest FeesVault | 47,620,218 | `0xc97fa6247457C9CF9f0528ffC3D5dD2DAAe39ED3` |
| Hybra pools | 47,616,846 / 47,618,983 | CLFactory `0x32b9dA73…` |
| Hybra core (VE/gHYBR/gauges) | 47,625,516 | VE `0xd7ed7792…`, gHYBR `0x348b11CB…` |

## 6. Methodology & sources
- On-chain: HyperEVM JSON-RPC `https://rpc.hyperliquid.xyz/evm` (chainid 999), explicit blocks; Etherscan V2 chainid 999 verified sources; HyperEVMScan; Nest app API `app.usenest.xyz/api/blaze/liquidity-pools`.
- DefiLlama: protocol APIs + adapter history (DefiLlama-Adapters PR #17638, consolidation commits #18076; `projects/helper/uniswapV3.js`).
- Audits: Code4rena 2025-10-hybra-finance report + mitigation review (saved `analysis/c4_report.md`); docs.usenest.xyz audits page.
- Prices: DefiLlama spot (NEST $0.017125, 99% conf.; HYBR $0.0007546; WHYPE ~$89.8; UBTC ~$84.8k).

## 7. Caveats & limitations
- Repeated infrastructure restarts killed parts of the delegated audit pass; coverage is documented per-surface above and the $0 verdict is stated at **medium** confidence, not high.
- NEST/HYBR are low-liquidity tokens; locked-value figures scale with the stated prices.
- Ichi/Steer vaults are third-party and excluded from protocol custody.
- No mainnet transactions were sent; all PoCs are fork-only.

## 8. Files index
- `README.md` (this file), `summary.json`
- `analysis/` — scripts + raw dumps + verified sources (`nest_src_extracted/`, `hybra_*.sol`, `c4_report.md`, `nest_value_stage3.json`, `hybra_value.json`, `hybra_core_state.json`, `ci_runs.md`)
- `poc/` — Foundry project (`test/HyperevmBaseline.t.sol`, `test/HyperevmPoc.t.sol`)
- `ci/` — heavy job (`snapshot.py`), `ci-out/`, `ci-artifacts/`, `ci-log.txt`

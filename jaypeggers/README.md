# Jaypeggers (Ethereum) — L2 Phase-2 deep dive: live-state assessment & extractable-value determination

**Campaign:** zombie-hunt II · L2 watchlist Phase 2 (triage row `jaypeggers`, $189,996 flagged) · **Chain:** Ethereum
**Date of work:** 2026-10-12 · **State pinned at block 26,178,136** (independently re-read at blocks 26,178,448 and 26,178,543 — bit-identical reserves/supplies) · ETH $2,508.98, JAY $6.9976 (DefiLlama, same time)
**Status:** read-only research; PoC/boundary tests verified on local mainnet forks only. No mainnet transactions sent, no keys used.

**Scope (all confirmed live, non-upgradeable, no proxies — Etherscan `Proxy: 0`, implementation == deployed code):**

| Suite | Contracts | Adapter coverage |
|---|---|---|
| v1 **JAY** | `JAY` `0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E` (ETH-reserve bonding curve) · `JayLiquidityStaking` `0x112E9FdAd728aDFBb1CE407a9CFa9339E1C6E130` · `JayFeeSplitter` `0x4826B4DE107623e0A42e85C2649CaeF736cBCaE9` · UNI-V2 JAY/USDC pair `0xEb7b5294c79b0369315Ed7fE76b52d3108B0A62D` | DefiLlama `jaypeggers` adapter tracks native ETH in the two starred contracts only |
| v2 **jUSDC** | `JayERC20Deriv` "Jaypeggers USDC" `0xca9f9671765F8D1A7e19ae2639E01FFF730f0D9B` (USDC-reserve bonding curve) · `JayDerivLiquidityStaking` `0xF70C2657C4135C2cE81977C32F7bC1E012A7226d` · `JayDerivFeeSplitter` `0x0b4E01AB9938E554f4d02B579C3474B3B673A08F` · UNI-V2 jUSDC/WETH pair `0x893Be9aca9bE32a9bCE005D034E4C1facd4709Ac` · `TheSplitoooor` team splitters `0x985b6b9064212091b4b325f68746b77262801bcb` (v1) and `0xEDe8e7D9659ae7FA69DE57DAF1F75D6729628320` (v2) · `JayMart` `0x927739b7542007f5d4b2e06efc801c380aecd728` (empty) | **not tracked** — the triage missed ≈ $36k of the live custody |
| markets | canonical Uniswap V2 factory/router; no other JAY/jUSDC venue exists (checked UniV2 + Sushi factories) | — |

## TL;DR — external unprivileged attacker can extract **$0** live (confidence: high)

| Target | Live custody | Extractable by unprivileged attacker | Why closed today | Latent risk |
|---|---|---|---|---|
| v1 JAY ETH reserve | **74.3137 ETH = $186,451** | **$0** | Outflow is only `sell()` by JAY holders (90% + fee split). JAY's only market prices it *above* net redemption ($7.000 pool vs $6.409 net payout; curve mint implies $7.457). Fuzz-verified: both arb directions lose at every size | market price < $6.41 would open a bounded reserve-arb for anyone with capital (not a code bug) |
| v1 JayLiquidityStaking | 1.8567 ETH rewards = $4,658 + 40.66% of the JAY/USDC pool = $20,814 LP principal | **$0** | Rewards are indexed to staker shares; a fresh `deposit()` calls `claim()→splitFees()` **before** the new shares are added → nets exactly 0 (probe-verified). Census: 107 stakers own all pending (≈1.94 ETH) | JIT-staking can capture a pro-rata slice of *future* fee inflows only — bounded by the fee stream (0.127 ETH over the last ~5 months) |
| v2 jUSDC USDC reserve | **34,390.35 USDC = $34,390** | **$0** | Same curve design with USDC. Pool $1.412 vs net redemption $1.249; curve mint implies $1.542. No arb either way | same market-price dependency as v1 |
| v2 JayDeriv staking | 71.55 USDC rewards + 100% of jUSDC/WETH LP ($1,020) | **$0** | Identical reward ledger; 5 stakers own 100.0000% of shares; Σ pending (147.84 USDC) == balance + 2/4 splitter | same JIT note, tinier flow |
| fee sinks / team | $11.04 (v1) + $176.49 (v2) + residual pending team cuts | **$0** | Permissionless `splitFees()` pays only fixed wallets; owner-settable | owner EOA can re-point future flows (P) |
| admin/init/upgrade surfaces | — | **$0** | No proxies; no withdraw/drain function exists on any contract; every privileged setter reverts `Ownable: caller is not the owner` for an attacker (probe-verified); `initalize` already consumed | single-EOA owner can redirect future fee addresses (v1 3%, v2 4%) and raise `SELL_FEE` (only *increases* seller payout) |

**Total live extractable now: $0** (external, unprivileged, net of gas/flash costs). Total live *custody* ≈ **$248,026**, recoverable only by the token holders/stakers themselves (H-O) except tiny team balances (P). The triage's $189,996 counted only v1 native ETH; the v2 jUSDC suite (+$35.7k) and the two staked LP principals (+$21.8k) were not in the adapter.

---

## 1. The mechanism, in exact terms

### 1.1 Bonding-curve "reserve" tokens (v1 `JAY`, v2 `JayERC20Deriv`)

Both are `ERC20Burnable + Ownable + ReentrancyGuard` linear bonding curves against a reserve asset (`JAY.sol`, `JayDeriv.sol` — verified sources in `analysis/JAY_src/`, `analysis/v2_jUSDC_src/`).

- v1 `JAY` (`0xDA7C…CA6E`): `JAYtoETH(v) = v * address(this).balance / totalSupply()`; `sell(jay)` burns from `msg.sender` and pays the seller `eth * SELL_FEE / 1000` (=900 → 90%) plus `eth / FEES` (=/33 → 3.03%) to `FEE_ADDRESS`; the residual 6.97% stays in the reserve (raises NAV per JAY). `buy(receiver)` mints `jay * BUY_FEE / 1000` (=955 → 95.5%) for `msg.value`. Both paths `nonReentrant`. `deposit()`/`receive()`/`fallback()` only accept ETH.
- v2 `JayERC20Deriv` ("jUSDC", `0xca9f…0D9B`): identical shape with the immutable `backingToken` = USDC: `JAYtoETH(v) = v * usdc.balanceOf(this) / totalSupply()`; `sell` pays `eth * SELL_FEE / 10000` (=9000 → 90%) + `eth / 25` (=4%) to `FEE_ADDRESS`; `buy(receiver, amount)` mints `ETHtoJAY(amount) * BUY_FEE / 10000` where `ETHtoJAY(value) = value * totalSupply / usdc.balanceOf(this)` computed **before** the buyer's USDC arrives (this makes the *buy* price constant `NAV/0.90` at any size — still ≥ NAV, so it cannot be exploited to mint below value; round-trips tested below).
- NFT-discount paths (`sellNftDiscount` / `buyNftDiscount`) scale the fee by `JAYNFT.balanceOf(msg.sender)*3bps` capped at 300bps. Live `JAYNFT == address(0)` → those two functions revert; even if set, the max discount (93% out) still cannot beat the pool ($1.412 vs $1.291). Owner-only → latent/P.
- **No function on either contract moves the reserve except `sell()`/`sellNftDiscount` against tokens the caller actually burns.** There is no `withdraw`, no sweep, no rescue, no upgrade (no proxy, no EIP-1967 slots). Owner setters (fees/max/start/feeAddress/JAYNFT) cannot reach the reserve.

### 1.2 LP-staking reward ledgers (`JayLiquidityStaking`, `JayDerivLiquidityStaking`)

Both mirror one design: users stake the curve's DEX LP (`liquidityToken`) and receive reward-token (ETH / USDC) pro-rata, funded by the fee splitter.

- `deposit(amount)`: if `totalAmountStaked>0` → `claim()` **first**, then `shares += amount`, `_setUserEntry()` (entry := current `rewardPerTokenStored`), `T += amount`, `transferFrom` LP. Else resets RPT/prev to 0.
- `claim()` (private; called by both deposit and withdraw): calls `FEE_ADDRESS.splitFees()` (which routes the splitter's balance to fixed wallets, incl. 2/3 (v1) / 2/4 (v2) into this staking contract), then `RPT += (balance − previusRewardTotal)*1e18/T`; pending = `shares*(RPT−entry)/1e18`; `previusRewardTotal = balance − pending`; pending is paid to the caller.
- Because the splitter transfer and the RPT increase both happen **inside the caller's `claim()` before their new shares are added**, a fresh staker can never capture value that accrued before their deposit — the PoC measures exactly 0 for a deposit/withdraw probe with a stake as large as the largest existing staker.
- `withdraw(amount)` requires `start` (true) and pays pending too. No lockups, no fees on stake/unstake.
- Owner setters: `setFeeAddress`, `setStart`, `initalize` (already done: v1 seeded 99 addresses / 1.7747e15 LP; v2 seeded 5). No admin withdrawal. No proxy.
- Splitter wallets (live reads): v1 `TEAM=0x985b…01bcb` (a TheSplitoooor pass-through, $11), `LP=NFT=staking` (so 2/3 of standings go to stakers); v2 `TEAM=0xEDe8…8320` (TheSplitoooor, $138), `LP=NFT=staking` (2/4), `JAY=0x5F2f…B41a` (team EOA, 1/4).

### 1.3 Historical note (different code, already exploited)

The Dec-29-2022 Jaypeggers incident (15.32 ETH, Hypernative write-up) hit the **legacy NFT tax-loss-harvesting contract** — `buyJay` accepted a caller-supplied ERC-721 whose `transferFrom` callback re-entered `sell`, minting JAY at a mis-accounted price. That contract family is not the one holding today's value: the live curve's `buy(address)` takes no token callbacks and both entry points are `nonReentrant` (reentrancy probe in §6 test `test_reentrancyBlocked`).

## 2. Live-state assessment (block 26,178,136, verified via 2 independent RPCs)

| Check | v1 JAY | v1 staking | v1 splitter | v1 pair | v2 jUSDC | v2 staking | v2 splitter | v2 pair |
|---|---|---|---|---|---|---|---|---|
| Address | `0xDA7C…CA6E` | `0x112E…E130` | `0x4826…CaE9` | `0xEb7b…A62D` | `0xca9f…0D9B` | `0xF70C…226d` | `0x0b4E…A08F` | `0x893B…09Ac` |
| Code | live, verified | live, verified | live, verified | live (canonical UniV2) | live, verified | live, verified | live, verified | live (canonical UniV2) |
| Proxy | none | none | none | — | none | none | none | — |
| Native/token balance | **74.313654328551356199 ETH** | **1.856708285987792344 ETH** | 0.126846335259042726 ETH | 25,593.012140 USDC + 3,656.240934886 JAY | **34,390.346614 USDC** | 71.553751 USDC | 152.621202 USDC | 0.203187617163 WETH + 361.027550679 jUSDC |
| Supply / LP | 26,182.1672998788 JAY | T=3.550813032927453e15 LP staked; LP bal 3.550813e15 (40.66% of LP) | — | LP supply 8.732148972e15 | 24,784.6863675160 jUSDC | T=8.186277669829084e18 = 100.0000% of LP (minus 1000 wei) | — | LP supply 8.186277669829086e18 |
| Owner (slot-verified) | `0xD5d1EE…782b` (single EOA, no code) | same | same | — | same | same | same | — |
| Fee address (storage slot) | slot7 `0x4826…CaE9` | slot2 `0x4826…CaE9` | wallets: TEAM `0x985b…`, LP=NFT=`0x112E…` | — | slot8 `0x0b4E…A08F` | `FEE_ADDRESS()` = `0x0b4E…` | TEAM `0xEDe8…`, LP=NFT=`0xF70C…`, JAY `0x5F2f…` | — |
| `start` | **true** | **true** | — | — | **true** | **true** | — | — |
| Ledger (`previusRewardTotal`) | — | 1.721486390460785356 ETH (= bal − pending seen by last claim) | — | — | — | 71.553751 USDC == balance (delta 0) | — | — |
| Census (Multicall3, 957/51 candidates) | — | **107 stakers**; Σshares 3,533,415,011,269,452 = 99.51% of T; Σ`getReward` = **1.9816 ETH** (view counts the whole splitter; net team 1/3 → ≈1.9397 ETH) vs payable 1.8567+2/3·0.1268 = **1.9413 ETH** ✔ | — | — | — | **5 stakers**; Σshares = 8,186,277,669,829,084,430 = **100.0000%** of T; Σ`getReward` = **147.840182 USDC** = 71.5538 + 2/4·152.6212 ✔ | — | — |
| Other tokens | dust airdrops only (HEX/WETH 1e-7/etc., ~$0.001) | LP + dust | — | — | dust airdrops | USDC + LP | — | — |

Raw dumps: `analysis/live-state-block-26178136.txt`, `analysis/lp-splitter-state-26178136.txt`, `analysis/v2-params-26178136.txt`, `analysis/v2-state-26178136.txt`, `analysis/ci-out-v1-census.json`, `analysis/v2-census.json`. CI re-collects all of this read-only into `ci-out/` (`live-state.json`, `census-v1.json`, `census-v2.json`).

**Activity context** (why this is not a "dead" protocol): JAY/USDC pool touched 2026-10-11 (block 26,171,366), ~105 curve `Price` events since May-2026 (last 2026-10-06), staking withdrawals as recent as 2026-03-30; a small MM keeps the pool at NAV parity.

## 3. What an attacker can / cannot do

**Cannot (all probe-verified, `poc/test/Jaypeggers.t.sol`):**

1. **Touch either reserve without holding the token.** `sell(≤1000)` with no JAY reverts `ERC20: burn amount exceeds balance` (v1/v2 tested).
2. **Arb the pool against the curve.** v1: net redemption 90%·NAV = $6.4092/JAY, curve-mint-implied $7.457/JAY, market $6.99982 — inside the no-arb band; fuzzed up to 95% of the pool: buying JAY with up to 24.3k USDC and redeeming loses ≥ 8% (observed at max size), curve-buying up to 20 ETH and dumping loses ≥… sample: 20 ETH → 6.57 WETH back. v2: bands $1.2488 / $1.5418, market $1.4120; fuzz loses too.
3. **Capture pre-existing staking rewards with a fresh stake.** `deposit(L)` runs `claim()→splitFees()` with the OLD denominator before adding `L`; `_setUserEntry()` then sets the entry to the post-inflow index. Probe with L ≈ largest staker: ETH/USDC gained == **0**; existing stakers keep their pending; the LP principal is returned 1:1.
4. **Call any privileged path.** `setStart/setMax/setSellFee/setBuyFee/setFeeAddress` (both curves), `setStart/setFeeAddress/initalize` (both stakings), `setTEAMWallet/setLPWallet/...` (both splitters) all revert `Ownable: caller is not the owner` for an attacker.
5. **Reenter `sell`/`buy`.** Malicious receiver re-entering `sell` reverts the outer call (`ETH Transfer failed.` — the nonReentrant inner revert bubbles) — kills the 2022 exploit class in this codebase.

**Can (H-O self-service only) / latent:**

- Every JAY holder can `sell()` today: 90% of pro-rata reserve + 3.03% fee to the splitter (2/3 of which accrues to stakers). Same for jUSDC holders (90% + 4% fee).
- Every staker can `withdraw()` LP + `getReward()`. Census ties ≈100% of the pending to actual stakers.
- **Latent JIT-fee capture (bounded, not against principal):** an attacker who already holds (or mints — cost-free round trip) a large LP position can capture `L/(L+T)` of *new* fee inflows that arrive while staked, by calling `splitFees()` themselves then claiming. The current standing inflow can never be captured this way (the depositor's own `claim()` drains the splitter before their shares exist). The historical inflow rate is ≈0.1268 ETH / ~5 months (v1) and ≈152.6 USDC / 5 months (v2), and private-party capture requires staking ≥T — i.e., up to ~2/3 of a $318 (v1) / $153 (v2) pool per period, minus capital costs. Net: no meaningful extraction against the $248k custody; document as a design smell (rewards are touch-triggered and instantly claimable by JIT stakes).

Costs (all real, from the fork): router swaps pay 0.3% per leg + price impact; a flash loan adds 0.09% (Aave) — every candidate path starts already ~17% (v1) / ~22% (v2) underwater from the fee stack alone (v1: 4.5% buy haircut + 10% sell haircut + 3.03% fee; v2: 10% + 10% + 4%) before impact.

## 4. Total live extractable now

| Category | USD | Notes |
|---|---|---|
| **E-U (external unprivileged)** | **$0** (high confidence) | all paths above close or lose money; probes + fuzz on live fork |
| H-O (holders/stakers self-service) | **$225,609.76** | v1 sellers' 90% ($167,806.26) + v2 sellers' 90% ($30,951.31) + v1 staker rewards incl. standing splitter 2/3 ($4,870.61) + v2 staker rewards incl. 2/4 ($147.86) + v1 staked-LP principal ($20,814.12) + v2 staked-LP principal ($1,019.59) |
| P (team-controlled) | **$331.77** | TheSplitoooor balances ($11.04 + $138.02) + pending team cuts in both splitters (v1 1/3·0.1268 ETH = $106.06; v2 2·1/4·152.62 USDC = $76.31) |
| S (stuck) | ~$0 | rounding dust only |
| *Residual ledger inside custody* | ~$22.1k | the 6.97%/6% retained by the curves (accrues to remaining holders) + 2/3·v1-fee, 2/4·v2-fee that will flow to stakers on the next split |
| **Total live custody** | **≈$248,026** | vs triage $189,996 (v1 ETH only) |

Note on realizability: 90% figures assume holders redeem through `sell()`; holders may instead sell JAY on the pool (market is currently *better* than redemption), in which case the reserve is not touched at all. The $20.8k/$1.0k LP principals are pool-value estimates at current reserves.

## 5. PoC / fork verification

`poc/test/Jaypeggers.t.sol` (Foundry, fork-only; vendored forge-std) — **11 tests (4 fuzz × 256 runs in CI), 11/11 PASS** on the final CI run below; runs pinned to block 26,178,136 (fallback latest).

| Test | Proves | Result |
|---|---|---|
| `test_v1_reserve_onlyRedeemableByHolders` | reserve live; no-token `sell` reverts; holder payout = 90% exact, fee = eth/33 exact, reserve drops exactly by payouts | PASS; 0.2554 ETH redeemed in the probe |
| `testFuzz_v1_poolToCurve_noProfit` | 256 runs, sizes up to 95% of pool: buy JAY → redeem → USDC back always < in | PASS |
| `testFuzz_v1_curveToPool_noProfit` | 256 runs: curve buy → pool dump → WETH back always < ETH in | PASS (20 ETH in → 6.57 WETH back at max) |
| `test_v2_reserve_onlyRedeemableByHolders` | jUSDC reserve $34.4k; no-token `sell` reverts; 90% + 4% payout math exact | PASS; 124.88 USDC redeemed in the probe |
| `testFuzz_v2_poolToCurve_noProfit` | 256 runs, same for jUSDC/WETH (2 ETH in → 0.163 WETH back at max) | PASS |
| `testFuzz_v2_curveToPool_noProfit` | 256 runs: jUSDC curve buy → pool dump → USDC back always < in | PASS (15.2k USDC in → 0.49k back at max) |
| `test_v1_staking_freshStakeCapturesNothing` | deposit/withdraw probe captures 0; splitter drained by the depositor's own claim; witness staker's pending moves exactly by −team-third·share; pool keeps/grows balance | PASS |
| `test_v1_staking_newInflowOnlyProRata` | simulated +1 ETH fee inflow: attacker with L≈T captures exactly L/(L+T)·2/3 = 0.3333 (pro-rata only, no over-capture); existing stakers keep 0.3334 | PASS |
| `test_v2_staking_freshStakeCapturesNothing` | same for USDC rewards; 5-staker set keeps 100% of pending | PASS |
| `test_adminFunctionsRevertForAttacker` | 19 privileged calls across all six owner-bearing contracts (JAY, v1 staking, v1 splitter, jUSDC, v2 staking, v2 splitter) revert Ownable for an attacker | PASS |
| `test_reentrancyBlocked` | 2022-class reentrancy in `sell` reverts | PASS |

CI: GitHub Actions `poc.yml` on `kingmariano/ca-zombie-ci`, branch/finding `jaypeggers` — **final run 11/11 PASS**: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38299094798 (earlier runs: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38297853988 — full pass; https://github.com/kingmariano/ca-zombie-ci/actions/runs/38298600770 — census fixed). The CI job independently reproduced the live state at block 26,178,543 (bit-identical reserves) and the staker census (107 / 5 stakers; Σshares 3,533,415,011,269,452 / 8,186,277,669,829,084,430; Σrewards 1.981636 ETH / 147.840182 USDC). Key CI gas: admin-reverts 509,495; reentrancy 460,865; v1 reserve 356,980; v1 staking-fresh 576,273; v1 inflow-pro-rata 591,948; v2 reserve 478,167; v2 staking-fresh 707,737. Raw evidence: `ci-log.txt`, `ci-artifacts/result-jaypeggers/ci-out/{live-state,census-v1,census-v2}.json`.

## 6. Verdict, residual risk, blockers

**Verdict: E-U = $0.** The two bonding-curve reserves ($220,842 combined) are structurally one-way: only `sell()` by actual token holders can move them, both DEX venues price the tokens above net redemption, and no admin/drain/upgrade path exists (verified source + probes). The two staking reward pools are indexed per-share with the deposit-triggered claim ordering that makes pre-existing value uncapturable. No allowance, role, oracle, or callback surface adds a path.

**Residual/latent risk (all P or market-contingent, none E-U today):**
1. **Owner is a single EOA** (`0xD5d1EE6CB2d70264ffC5307CA456a2BEd796782b`): can re-point `FEE_ADDRESS` on both curves (diverting *future* 3%/4% fees, not reserves), raise `SELL_FEE` (v1 cap 969 — only increases seller payout; v2 cap 9290), set `MAX`/buy fees, `setStart` (already true). Cannot touch reserves, staked LP, or rewards already ledgered.
2. **Market-contingent reserve arb:** if JAY ever trades below $6.41 (or jUSDC below $1.249) on the pool, buying-and-redeeming becomes profitable until the reserve revalues — this is how a reserve is *supposed* to work; today the band is closed and an active MM keeps parity.
3. **JIT fee capture** (see §3): bounded by future inflows; worth documenting to the team because it dilutes long-term stakers whenever fees resume.
4. **v1 `getReward` view overstates pending by the team third** of the splitter balance (cosmetic, affects integrations/dashboards).
5. v2 `getAPY()` contains `factor = 1*1**4` (=1, not 1e4) — cosmetic view bug only.

**Blockers for an attacker (i.e., why H-O value stays H-O):** none of the holders' self-service paths are paused (`start=true` everywhere); there are no frozen tokens/blacklists; the staking LPs are withdrawable; the only friction is that both staking contracts' one-way (deposit pays you only new-money pro-rata) reward design.

## 7. Methodology & sources; caveats; files

**Method.** (1) Corpus/triage lead → adapter read (`l2-triage-a/analysis/adapters/jaypeggers.js`); (2) Etherscan V2 verified sources for all contracts, diffed v1↔v2; (3) live reads at pinned block on two independent public RPCs (`cast`, including raw storage-slot reads for private fields: JAY slot7 fee address, staking slot2/slot5, etc.); (4) enumeration of the deployer's full tx history → complete contract-family map (v1 + v2 + TheSplidooors + JayMart) with every CREATE receipt resolved; (5) event scans (Deposit/Withdraw/Price/Swap/Sync) for activity context; (6) Multicall3 census of all stakers (θ957 + θ51 candidates) vs. `totalAmountStaked` and balances; (7) fork PoC: boundary tests + fuzz for both curves and both staking ledgers; (8) fee-split tracing through both splitters and the team TheSplidooors. Values: DefiLlama prices at the same timestamp (ETH $2,508.98, JAY $6.9976).

**Key citations.** Balances/supplies/reserves: §2 table (all `cast call/balance` at block 26,178,136, dumps in `analysis/`). Storage slots: JAY slot5=owner, slot7=`0x4826…CaE9`; staking slot0=1 (guard), slot1=owner, slot2=`0x4826…CaE9`, slot5=previusRewardTotal; jUSDC slot5=owner, slot8=`0x0b4E…A08F`; v2 staking layout verified via getters. Census summations in `analysis/ci-out-v1-census.json`, `analysis/v2-census.json`.

**Caveats/limitations.**
- The census covers 957/51 candidate addresses recovered from `initalize` calldata + Deposit/Withdraw logs; v1 Σshares = 99.51% of T (missing 0.49% of shares from stakers whose events were not captured) — pending sums are complete to that rounding; v2 is exactly 100.0000%.
- Holder-level attribution for JAY/jUSDC (who could redeem) was not enumerable (GoldRush holder endpoint rejected requests); the verdict does not depend on it — redemption requires holding the token in any case.
- Fork tests pin block 26,178,136 when the CI RPC can serve it (fallback: latest). Invariant assertions hold at any recent block; exact-amount claims reference the pinned block.
- USD values move with ETH/JAY; all figures are point-in-time at 2026-10-12.
- JayMart (`0x9277…`) audited only to the level of "holds $0 and does not touch the reserves" — it is an ERC-1155 marketplace with a Chainlink feed and no funds.

**Files index.** `README.md` (this) · `summary.json` · `analysis/` (verified sources for all 7 contracts, live-state dumps at 26,178,136/26,178,448, census JSONs + scripts, initalize decodes, activity logs) · `poc/` (foundry project, 11 tests incl. 4 fuzz) · `ci/run.sh` (reproducible read-only state + census job) · `ci-out/`, `ci-log.txt`, `ci-artifacts/` (CI evidence).

# Iron Finance (IRON / IronSwap) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chains:** Polygon (137), Fantom (250), Avalanche (43114) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions**.

**Mission:** how much can an external, unprivileged attacker extract **live, right now** from the remains of Iron Finance (the 2021 IRON/TITAN algorithmic-stable protocol and its 2021-22 successor stack: IronSwap pools, IronChef farms, IronLend).

**Headline: E-U $0.00 (high confidence).** The triage's $315,345 is real value, but it sits as **LP-token custody** (redeemable pro-rata by the LP holders themselves, H-O), plus ~$278 of admin fees that only the owner/feeController can claim (P). All permissionless entry points are either fairly priced, gated, or (one) bricked. The one live-looking extraction idea — dumping "junk" stables (xUSD/IRON/PUSD) into the IronSwap meta-pools — is **unprofitable at market prices** (verified on-chain, per-size, both directions).

---

## 1. TL;DR

| Target | Live value (USD) | E-U (unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|---|
| **IronSwap IS3USD pool** (Polygon) `0x8375…Cb57` | **$316,023.73** (71,981.44 USDC.e + 170,783.02 USDT + 73,259.27 DAI) | **$0.00** | Fair Curve-style stableswap (0.02% fee); all mutations `nonReentrant`; admin/init gated; `removeLiquidityImbalance` **bricked** (missing `/FEE_DENOMINATOR`) | Owner can pause/setFee; $271.73 admin fees P-gated |
| ↳ LP custody `0xb4d0…8f17` (312,360.12 IS3USD) | (claim on above) | $0 | 85.06% IronChef farmers, ~10.4% EOAs, Beefy vault, small third-party contracts — all self-withdraw (H-O) | Lost keys = S; Adamant ERCFund2 2.37% = owner-only |
| IronSwap meta-pools (Polygon): ispusd / isxusd / isiron | $397.39 external (1,059.61 PUSD + 87.31 xUSD + 2,250,092 IRON) | **$0.00** | Dump extraction: measured **negative PnL** vs market ask (xUSD $1.0514, IRON $0.0000738, PUSD $0.13167). Theoretical cap if junks were free: ≤ $524 (= 518.7 IS3USD LP) | Market prices of junks are thin; if xUSD/IRON ever < ~$0.98/‑$0.00002, small extraction appears |
| **IronChef** farm (Polygon) `0x1fD1…DFaD` | holds 265,700 IS3USD LP + ~$2.9k external-pair LPs | **$0.00** | Sushi MiniChef v2 fork; only staker withdraws own stake (proven); rewards=ICE (worthless); fund requester-gated | Owner can change allocPoint; ICE emissions meaningless |
| **IronLend** Compound fork (Polygon `0xF20f…d10c`, Fantom `0xDc4C…0764`) | Polygon cash $23.74 (12.32M ICE + dust); Fantom cash $859.17 (0.0098 WBTC + 0.0112 WETH + 5.11 DAI + dust) | **$0.00** | Cash belongs to cToken holders (H-O); reserves admin-only (P); no permissionless borrow/liquidate value | Stale oracle; bad debt on 9.32 WETH（borrowers' side) |
| **IS3USD pools** Avalanche `0x952B…d523` / Fantom same | $29.85 / $1,029.31 | **$0.00** | Same code family; not paused; holders-only LP paths | Tiny; farm LP on each chain |
| **Admin fees** (all pools) | $278.21 | $0.00 | `withdrawAdminFee()` = feeController-or-owner only | feeController is an upgradeable proxy (0x66c8…e2fc) |
| **Adamant ERCFund2** `0x43c0…f6b4` (holds 7,405.24 IS3USD LP) | $7,485.24 | **$0.00** | `notifyFeeDistribution(IS3USD)` **reverts** (IS3USD not an MFD reward); only fund owner can `recover()` → third-party P/S | Adamant-side; same contract also holds ~$50k other tokens (WETH/QUICK…) |

**Total live extractable now (E-U): $0.00 · confidence: high.** Total live protocol value measured: **≈ $318,370** = is3usd actual $316,023.73 (incl. $271.73 admin) + meta-pool externals $397.39 + Fantom pool $1,029.31 (+$6.40 admin) + Fantom lending cash $859.17 + Avax pool $29.85 (+$0.08) + Polygon lending $23.74; excludes ~$2.9k of external-pair LP staked inside IronChef (price-soft). Triage value ($315,345) ≈ confirmed, essentially unchanged since Phase 1.

---

## 2. What Iron Finance is today (mechanism, exact terms)

- **IS3USD pool** — `IronSwap` is a Solidity port of Curve/Saddle-style StableSwap (`contract IronSwap is OwnerPausable, ReentrancyGuard, Initializable`), with an extra per-user "withdraw fee" mechanism (decays over 4 weeks, max 1%; here `defaultWithdrawFee = 5e6` = 0.05%). Pool of USDC.e/USDT/DAI, `A = 1200`, `fee = 2e6` (0.02%), `adminFee = 100% of fee`. Math library `IronSwapLib` is external and called via DELEGATECALL (linked library at `0x7e81…7Ee9`).
- **Deployed code = verified source, byte-for-byte.** Compiled the Etherscan-verified flattened source with solc 0.8.4, optimizer 200, EVM istanbul, substituted the library address, and diffed runtime code vs `eth_getCode` at Polygon block 95,383,464: **18,483 bytes of executable code are byte-identical** (only the CBOR metadata/IPFS hashes differ, as expected). Sibling pools are a later build (interface + `MAX_A` + `stopRampA` deltas, same math/quirk).
- **The one code defect found:** in `removeLiquidityImbalance` the burn is scaled by `(FEE_DENOMINATOR − withdrawFee)` **without dividing by `FEE_DENOMINATOR` (1e10)** (line 1472). Effect: burn ≈ 1e10× too large → the function reverts for any non-dust withdrawal. This is a **usability brick, not a drain** (it can only over-charge). All sibling pools share it.
- **Historical context (verified, corrections to corpus):** the "2022-05-11 Re-entrancy Exploit" hallmark in DefiLlama's adapter is **unsubstantiated** — no hacks-DB entry, no post-mortem, and the only on-chain event that day was a $7.7k pro-rata exit of one Avalanche LP (research record: `analysis/research-history.md`). All IronSwap value-moving entry points carry `nonReentrant`; the only hook (LP token → `updateUserWithdrawFee`) is `msg.sender == lpToken`-gated and only writes fee bookkeeping. The famous 2021 incident was the TITAN bank run (market dynamics), not a contract bug; the only documented exploit is the 2021-03 BSC $170k share-accounting incident.

---

## 3. Live-state assessment (addresses, balances, roles — all reads read-only)

### 3.1 Polygon — block **95,383,464** (pinned dump in `analysis/final-state-dump.txt`)

**IS3USD pool `0x837503e8A8753ae17fB8C8151B8e6f586defCb57`**

| Item | Value |
|---|---|
| paused / owner | false / `0xCe7C13ea272Ab43b3107A3192B779Ca71E510f35` (contract) |
| feeController / feeDistributor | `0x66C8096Fa2F5fD21062a27C202a330e64E0ae2fc` (UUPS proxy) / `0x62cA555de2D65f8e9D45a9B3d5C1b92aC1a64ecc` (EOA) |
| tracked balances | 71,872.959097 USDC.e · 170,671.880494 USDT · 73,207.160534086163911729 DAI = **$315,751.00** |
| actual balances | 71,981.438679 · 170,783.015630 · 73,259.273763069883489268 = **$316,023.73** |
| admin fees (`getAdminBalances`) | 108.479582 · 111.135136 · 52.113228983719577539 = **$271.73** (claimable only by feeController/owner) |
| LP token / supply / NAV | `0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17` "IRON Stableswap 3USD" / 312,360.122887798606432247 / virtual price 1.010775188744550901 |
| A / fee / adminFee / withdrawFee | 1200 / 0.02% / 100% / 0.05% |

**LP holders — 806 live addresses (full CSV: `analysis/is3usd-holders.csv`), sum == total supply exactly:**

| Holder | LP | % | Class |
|---|---|---|---|
| IronChef farm `0x1fD1259Fa8CdC60c6E8C86cfA592CA1b8403DFaD` | 265,700.351129 | 85.06% | H-O (farmers) |
| EOAs + smart-wallet proxies (~750 addrs, top: `0x39d5…cAdc` 14,950.7; `0xde8a…0BFb` 3,432.8; `0x4c48…4C36` 3,399.0) | ~32,455 | 10.39% | H-O |
| Adamant `ERCFund2 0x43c085b5aba4e83a7dd1a478b7458d1d472ff6b4` | 7,405.238184 | 2.37% | P/S (owner-only `recover()`; notify path reverts) |
| Beefy strategy `0x6195187d06948fb14b20fd3c639f8cb8a335c29c` → vault `0x0C4705EBd2BF69660b72f9E9B684714c9e341942` ("Moo IronSwap 3USD") | 5,401.718372 | 1.73% | H-O (vault depositors) |
| Gnosis Safe `0xeae55893cc8637c16cf93d43b38aa022d689fa62` | 808.040400 | 0.26% | P |
| Meta-pools as liquidity (isxusd 449.05 + isiron 60.77 + ispusd 8.85) + 6 small IronSwap pools | ~525 | 0.17% | H-O (meta-pool LPs) |
| feeController `0x66c8…e2fc` | 48.612074 | 0.016% | P |
| IronChef#2 `0x4a8a59540763f3564bbd0f4dce2858306b041f3b` | 17.566 | 0.006% | H-O |

**IronChef farm `0x1fD1259Fa8CdC60c6E8C86cfA592CA1b8403DFaD`** (block 95,383,464): Sushi MiniChef v2 fork; `reward = ICE 0x4A81f8796e0c6Ad4877A51C86693B0dE8093F2ef` (no market ≈ $1.9e-6), `fund = FundDistributor 0xB627DC38bCBC9D2B71564EC2db93fF8Cc267420E` (requester-gated, chef approved), `rewardPerSecond = 9.26e18`, owner `0x5AeBdE597752d689132Dc64D093ff4b09067e9e6` (EOA), all rewarders = 0. Pools: IS3USD LP 265,700.35; FLP(ICE/WETH) 8.593e32 (60.9% of supply); DFYNLP(USDC/ICE) `0x34832D9A…` 0.664170577468840008 (92.4%) = ~$2.60k; IRON‑IS3USD LP 857,619.105 (96.4%); DFYNLP(ICE/IRON) `0x7e2cc09d…` 7.451e24 (94.8%) = ~$202; FLP ≈ $110.

**Meta-pools (all not paused; same code family):**

| Pool | coins @pin | LP supply | vp | owner |
|---|---|---|---|---|
| ispusd `0x4A783cD1b4543559eCe45dB47e07E0Cb59e55c09` | 8.845 IS3USD LP + 1,059.6106 PUSD | 1,004.5485 | 1.0101 | `0x18bF0306…` |
| isxusd `0xe440CCc13e6f273c110Cf3cF4087C23a66B8e872` | 449.0525 IS3USD LP + 87.3142 xUSD | 428.0768 | 1.2479 | `0x18bF0306…` |
| isiron `0xCaEb732167aF742032D13A9e76881026f91Cd087` | 60.7692 IS3USD LP + 2,250,092.124 IRON | 889,623.3747 | 1.0154 | `0x5AeBdE59…` |

Additional IronSwap-family pools exist beyond DefiLlama's list (e.g. PUSD-IS3USD `0xbcd3442be2c2636b789c4bf3abc7b199c5da7d0a` **paused**, `0x90f85617…`; IS3USD+other `0x2fdae82f…`; all dust).

**IronLend (Compound fork)** comptroller `0xF20fcd005AFDd3AD48C85d0222210fe168DDd10c`, 8 markets; cash: rWETH 3.4e-9, rUSDC 0, rMATIC 2.1e-6, rWBTC 0, rUSDT 0.000078, **rICE 12,324,711.999** ICE (≈$23.73), rIRON 0, rDFYN 72.533. ≈ **$23.74** total, H-O for cToken holders.

### 3.2 Fantom — block **123,651,628**
Pool `0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523`: not paused; tracked 15.499543 USDC + 35.802980 USDT + 978.004572 DAI = **$1,029.31**; admin fees **$6.40**; LP `0xc143a1500ca4a471eE9cc70B9AC0C739576F84bb` supply 888.263. IronController `0xDc4C597E36Fc80876801df0309Cc11A7C12E0764` markets cash: rWETH 0.011211 WETH ($28.77) + rFTM 0.001767 + rDAI 5.108782 + rWBTC 0.009809 WBTC ($825.29) + rUSDC 1 wei ≈ **$859.17**. (prices: ETH $2,565.76 / BTC $84,142.49 / FTM $0.03463, DefiLlama 2026‑10‑12).

### 3.3 Avalanche — block 97,334,248
Pool `0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523`: not paused; tracked 9.727664 USDC.e + 11.995754 USDT.e + 8.125649663824159558 DAI.e = **$29.85**; admin $0.082; LP supply 24.0659, farm `0x073667be2bc3efc8c03caf6c35632eb8ad6dfc47` holds 12.623 (52.5%).

---

## 4. What an attacker can and cannot do (exact paths, measured)

All quotes/behaviour below are **live on a fork** at Polygon block ≈95,384,1xx (CI) / 95,383,464 (pinned dump); files `analysis/swap-quotes*.txt` and the PoC (11/11 tests pass).

**A. Non-LP attacker, IS3USD pool.**
- `swap` — 0.02% fee, curve-fair: 100,000 USDC.e → 99,976.84 USDT; 100,000 USDT → 71,680.79 USDC.e (pool USDC.e-short); round-trip always loses. **No profit.**
- `addLiquidity` + `removeLiquidity` immediate round trip (1,000 each): deposit $3,000, receive ~$2,997.4 back (imbalance fee + 0.05% withdraw fee). **Loss.**
- `removeLiquidityOneToken` / `removeLiquidityImbalance` / `removeLiquidity` — all require the attacker's own LP (burned via `burnFrom`, needs an LP→pool allowance). Not accessible without LP. **No entry.**
- `withdrawAdminFee` → `!feeControllerOrOwner`; `setFee`/`rampA`/`stopRampA`/`setFeeController`/`setFeeDistributor`/`pause`/`transferOwnership`/`renounceOwnership` → onlyOwner revert; `updateUserWithdrawFee` → `!lpToken`; `initialize` → already-initialized revert. **All gated (test_06).**
- **`removeLiquidityImbalance` is bricked**: live fork trace for a $3 withdrawal by a holder with 2,968.33 LP:
  `burnFrom(attacker, 29,670,463,700,850,025,730,375,000,000)` (2.97e28 LP) → `ERC20: burn amount exceeds balance`. The missing `/FEE_DENOMINATOR` makes the burn ~1e10× fair; only ~1e‑15 USD dust withdrawals can execute. **No drain possible; function unusable.**

**B. Attacker who acquires LP (or a small LP holder).** `removeLiquidity` returns pro-rata mix minus ≤0.05% withdraw fee; NAV-fair (test_04: $3,000 in → $2,997‑2,999 back; works even when paused). No bonus, no rounding edge. `removeLiquidityImbalance` bricked as above.

**C. Junk-token dump into meta-pools (the only live-looking E-U idea).** Measured per-size PnL (dump junk → receive IS3USD LP → redeem via `removeLiquidity`):
- **isxusd**: 200 xUSD → 202.1329 LP → redeem $204.23 vs cost $210.28 (xUSD ask $1.0514) → **‑$6.05**; view path identical ($204.33). Even at xUSD=$1.00 the edge is ≤ +$4 for ≤200 size; at the DMM pool's actual ask (116,314 USDC vs 8,896.88 xUSD, mid $1.0514) it is negative. Reverse (LP→xUSD) = 0.957/1.0 xUSD per LP — also a loss.
- **isiron**: 500,000 IRON → 24.4978 LP → $24.76 vs $36.90 (IRON $0.0000738) → **‑$12.14**; 100k IRON → 6.603 LP ($6.67) vs $7.38 → still negative. Reverse: 13,696 IRON per LP = exactly par, no edge.
- **ispusd**: 500 PUSD → 8.2318 LP → $8.32 vs $65.84 (PUSD $0.13167) → **‑$57.52**.
- Theoretical cap if the junk tokens were obtainable free: 518.67 IS3USD LP held by the three pools ≈ **$524.2** — but market acquisition costs exceed every pool payout.
- Sanity: pre-execution checks, no tokens needed: test_08 (views), test_08b (real swaps with `deal`ed tokens) — same numbers.

**D. IronChef.** `withdraw(pid, amount, to)` decrements `userInfo[pid][msg.sender]` (Solidity 0.8 underflow revert) — mallory cannot withdraw the attacker's stake (`expectRevert`); `emergencyWithdraw` with zero stake moves nothing (chef balance unchanged). The attacker's own stake returns 1:1 (test_07). `deposit`/`harvest` paths are standard MiniChef v2; ICE rewards are worthless. **No theft.**

**E. ERCFund2 (Adamant) — 7,405.24 IS3USD LP + ~$50k other tokens.** `notifyFeeDistribution(IS3USD)` and `(WETH)` **revert** in live simulation (token not a registered `MultiFeeDistribution` reward / distributor not approved); `(QUICK)` succeeds but pays Adamant's own ADDY stakers (by design). `recover()` is onlyOwner (owner = unverified contract `0x73D6860e9b3801C001F00B19812208d5bc2BEb27`). **No unprivileged path to the IS3USD LP → classified P/S (third party).**

**F. Admin fees.** $271.73 (Polygon IS3USD) + $6.40 (Fantom) + $0.08 (Avax) = **$278.21**, claimable only via `withdrawAdminFee()` by `feeController = 0x66C8096Fa2F5fD21062a27C202a330e64E0ae2fc` (UUPS proxy, owner-controlled) or the pool owner. **P.**

---

## 5. PoC / fork verification

Foundry project: `poc/` (solc 0.8.24; fork tests against live Polygon/Fantom/Avalanche). CI run: `forge test -vvv` (GitHub Actions, public repo `kingmariano/ca-zombie-ci`) + `ci/run.sh` dumps live state to `ci-out/state.json`.

**Suites: 11/11 PASS** (local + CI; see `ci-log.txt` / `ci-artifacts/`):

| Test | Proves |
|---|---|
| `test_01_live_state` | pool live, coins/roles/balances/VP as reported; admin fees > $200 |
| `test_02_swap_roundtrip_loses` | 10k USDC→USDT→USDC strictly loses |
| `test_03_add_remove_roundtrip_loses` | deposit $3k, immediate proportional exit < $3k |
| `test_04_removeLiquidity_works_for_holder` | H-O path works (even when owner pauses); exit ≈ NAV |
| `test_05_removeLiquidityImbalance_bricked` | burn 2.967e28 LP for $3 → revert; dust (~1e‑15 USD) is the only workable size |
| `test_06_admin_paths_gated` | 11 privileged/init/hook calls revert for attacker |
| `test_07_ironchef_stakes_holder_only` | mallory cannot withdraw/steal another staker's LP; own stake returns |
| `test_08_meta_pool_extraction_negative_views` | dump PnL < 0 for xUSD/IRON/PUSD at market asks |
| `test_08b_meta_pool_real_roundtrips` | real token round trips: xUSD $204.23 vs $210.28; IRON $24.76 vs $36.90 |
| `test_09_lending_markets_dust` | rICE cash only meaningful lending asset (~$24); rest dust |
| `test_10_crosschain_readonly` | Fantom/Avax pool + controller state |

**CI runs:** [run 38207527350](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38207527350) and [run 38207761421](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38207761421) — **11/11 PASS each** (`ci-log.txt`, `ci-artifacts/`). An earlier attempt (run 38207168886) hit an RPC tip quirk (`header for hash not found` when forking at the exact tip); fixed with a fork-viability probe (`ci/pick_rpc.py`, writes only "ENV" or keyless URLs) + try/catch RPC fallbacks in the tests. Custom job `ci/run.sh` produced `ci-out/state.json` (fresh live dump: Polygon block 95,384,919, IS3USD actual $316,032.47; Fantom/Avax complete — addresses/numbers only, no secrets).

Bytecode provenance tooling: `analysis/bytecode_diff.py` + `analysis/verify_all_pools.py` + saved on-chain code hex; result: **Polygon IS3USD deployed code == verified source** (executable bytes identical; linked library `0x7e812CA56574ed578640dAeDFE2Cb3EF93937Ee9`).

---

## 6. Verdict, residual & latent risk

- **E-U = $0.00 (high confidence).** No unprivileged path extracts value: fairness of swaps/deposits, all mutations `nonReentrant`, all admin/init gated, the only candidate bug (`removeLiquidityImbalance`) can only over-charge (bricked), farm accounting standard, third-party fee contracts owner-gated.
- **H-O ≈ $307.4k** (LP holders' redeemable share of IS3USD, including IronChef farmers 85.06% and Beefy vault depositors 1.73%; exit = `approve` LP → `removeLiquidity`, pro-rata, ≤0.05% fee first 4 weeks) + $1,029.31 (Fantom) + $29.85 (Avax) + $23.74 (Polygon lending cToken holders) + $859.17 (Fantom lending cToken holders) + $397.39 (meta-pool external tokens) + ~$2.9k external-pair LPs staked in IronChef. Practical caveat: 4-week withdraw-fee decay only matters for fresh transfers; long-idle holders pay 0.
- **P ≈ $8,629 + $278 admin fees**: ERCFund2 LP $7,485.24 (Adamant owner-only), GnosisSafe $816.84, feeController LP $49.14, admin fees $278.21; owner can pause and set fees (owner contracts `0xCe7C…`, `0x18bF…`, `0x5AeB…`; feeController UUPS proxy). Owner contracts unverified/EOA-check: `0x5AeB…` is an EOA (key-risk if compromised).
- **S: none material.** Bricked `removeLiquidityImbalance` (function-level only); ERCFund2's notify path dead (owner can still recover).
- **Latent E-U (~$524 cap, currently unreachable):** if xUSD/IRON/PUSD ever become obtainable below pool payout (xUSD <≈ $0.98 for slow sizes, IRON <≈ $0.000066, PUSD <≈ $0.085), a dump-extraction against the meta-pools appears (max 518.67 IS3USD LP ≈ $524). Also note the dust-only ≤25 xUSD edge (≈ +$0.05) — below gas.
- **Blockers encountered:** public RPC archive limits (Ankr used locally for the pinned block; CI dumps at latest); xUSD/IRON/PUSD prices are from thin pools (single $78-$4.9k venues) — treated conservatively (attacker buys at ask); ICE price (single $217 pool) makes ~$2.6k of IronChef's DFYNLP valuation soft; Avalanche leg lacks a dedicated CI RPC env (public fallback used).

---

## 7. Methodology & sources

- **Read-only** on-chain reads via public/keyless RPCs (Polygon: polygon-bor-rpc.publicnode.com + rpc.ankr.com for pinned block; Fantom: rpcapi.fantom.network; Avalanche: avalanche-c-chain-rpc.publicnode.com). No keyed URL or secret is stored in this folder or the CI repo.
- **Source verification:** Etherscan V2 (`chainid=137`) sources/ABIs for IronSwap, LPToken, Dollar(IRON), IronChef, FundDistributor, ERCFund/ERCFund2, MultiFeeDistribution, StrategyIronStableLP; hardhat-flattened IronSwap recompiled (solc 0.8.4, runs 200, istanbul) and byte-diffed vs `eth_getCode`.
- **Holders:** GoldRush `token_holders_v2` + on-chain `balanceOf` verification for all 806 live holders, `eth_getCode` to classify contracts (CSV in `analysis/`).
- **Prices:** DefiLlama `coins.llama.fi` (stables = $1.00; ETH $2,565.76; BTC $84,142.49; FTM $0.03463); GeckoTerminal (xUSD $1.0514 mid on DMM pool w/ 116,314 USDC; IRON $0.0000738; PUSD $0.13167; ICE $1.9255e-6) — 2026-10-12.
- **History:** `analysis/research-history.md` (DefiLlama adapter commit 3cb226ad/PR 4428 hallmark provenance, on-chain May-2022 events, no exploit found).
- **PoC:** Foundry fork tests (`poc/test/IronFinance.t.sol`), all verified on the public CI (GitHub Actions), plus `ci/dump_state.py` → `ci-out/state.json`.

### Caveats & limitations
1. Cross-chain legs (Fantom/Avalanche) read at latest (blocks 123,651,628 / 97,334,248) — pinned only for Fantom.
2. The "junk dump" analysis assumes the attacker buys junk at the quoted mid+spread; if an OTC/off-market transfer of xUSD/IRON below those levels exists, up to $524 surfaces (documented cap).
3. IronChef's external-pair LPs (DFYNLP/FLP) are valued at reserves × pro-rata; ICE leg soft (thin market).
4. Lending-market liquidation/borrower side (9.32 WETH borrow etc.) not assessed as protocol extraction (against borrowers; oracle staleness noted).
5. No exhaustive event scan for 2023-26 withdrawals (LP supply invariants + sampled holder balances used).

### Files index
- `README.md` (this file), `summary.json`
- `analysis/final-state-dump.txt` — pinned-block dump (Polygon 95,383,464; Fantom 123,651,628; Avax 97,334,248)
- `analysis/is3usd-holders.csv` / `.log` — all 806 live LP holders + contract classification
- `analysis/swap-quotes.txt`, `analysis/swap-quotes-reverse.txt`, `analysis/quotes*.py` — meta-pool trade curves / dump PnL
- `analysis/sources/` — verified sources/ABIs (IronSwap, LPToken, Dollar, IronChef, ERCFund, ERCFund2, FundDistributor, MultiFeeDistribution, Strategy, xUSD/PUSD, feeController impl)
- `analysis/research-history.md` — history/hallmark/forensics record (by child agent)
- `analysis/bytecode_diff.py`, `analysis/verify_all_pools.py`, `analysis/onchain-is3usd-code.hex` — provenance proof
- `poc/` — Foundry PoC (11 tests), `poc/reference/IronSwap.sol` (verified flattened source)
- `ci/run.sh`, `ci/dump_state.py`, `ci-out/state.json` — CI custom job + live dump; `ci-log.txt`, `ci-artifacts/`

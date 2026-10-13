# AuroraSwap (Aurora) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Aurora (chain id 1313161554) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions**.
**Triage row:** L-2 Phase-1 Triage-B rank 13 (`l2-triage-b`), live $160,077.30 at block 219,514,157.
**Scope of this report:** how much an *external, unprivileged* attacker can extract live (no owner/admin keys, no protocol privileges).

---

## 1. TL;DR

| Target | Live value now | Extractable by unprivileged attacker | Why closed / open | Latent risk |
|---|---|---|---|---|
| AuroraSwap factory + 125 UniV2 pairs | **$159,744.84** priced TVL (block 219,722,582) | **$0** | Standard UniV2Pair template (single codehash `0x24150c11…`); no excess balances (skim = 0 on all 125 pairs); k-invariant enforced ("Aurora: K", fork-verified); LP mint/burn roundtrip yields no profit; feeTo/admin paths gated | Token donation to a pair would temporarily allow a k-bypass drain of the *other* side until `skim()` is called (currently 0 excess anywhere; skim is permissionless) |
| BRLMasterChef farm `0x35CC…9DDE` (36 pools) | 144,513.19 BRL + $128,996.56 of staked LP | **$0** | Standard Goose MasterChef; gaps/rewards accrue only to the addresses that already hold `userInfo.amount`; a fresh staker cannot capture past accrual (fork-verified: `deposit()` calls `updatePool()` first, gained = 0) | Pool 35 (99% of emissions) is staked by the MC **owner** with the AZFD token (owner-only mint); owner can also raise `BRLPerBlock` at will |
| Stale reward gap in pool 35 | **3,404,496.88 BRL** mintable on next `updatePool(35)` | **$0** | Claimable only by the MC owner `0xFdf4…8251` (privileged, **P**), not by a fresh address (fork-verified: attacker pending = 0 after triggering the mint) | Owner-only |
| Protocol fees accrued in pairs (feeTo) | ~$4.0k already minted to feeTo + ~$1,091 unminted (priced pairs) | **$0** | `mint()`/`burn()` are permissionless but the fee LP always goes to `feeTo = 0x9F67…bcAE` | — |
| Stale-price arbitrage | — | **$8.43** theoretical on the main pair (vs *global* price); **$0** realizable | All Aurora venues price wNEAR/BNB/MATIC consistently — the deviation vs DefiLlama is a chain-wide discount, not a local mispricing; main pairs are actively arbitraged by bots (627 swaps / 200k blocks) | If wNEAR's Aurora discount ever widens beyond fees and the Rainbow Bridge is usable, arb becomes realizable |

**Total live extractable now: $0.00** (external unprivileged) — **confidence: high**.

Live value has **not** materially changed since triage: $160,077.30 (block 219,514,157) → **$159,744.84** (block 219,722,582), i.e. −0.21% (price/reserve drift only).

---

## 2. What the protocol is (deployed reality)

DefiLlama's `registries/uniswapV2.js` defines the whole protocol as:

```js
'auroraswap': {
  aurora: { factory: '0xC5E1DaeC2ad401eBEBdd3E32516d90Ab251A3aA3',
            staking: ['0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE', '0x12c87331f086c3C926248f964f8702C0842Fd77F'] },
},
```

There are exactly two custody contracts:

1. **`0xC5E1DaeC2ad401eBEBdd3E32516d90Ab251A3aA3`** — a UniV2 factory (`allPairsLength() = 125`), constructor `(feeToSetter, bool)`; extra admin functions `locked()` / `setLocked(bool)` (selector `cf309012` / `211e28b6`). `feeTo = feeToSetter = 0x9F678909C735001Ac6482fCCFc928e11B703bcAE` (EOA, code size 0). `locked = false`.
   - All 125 pairs are deployed from one template: identical runtime codehash `0x24150c1125088e4c13dca8affe96771ae82e103a64542f1e085cb7d68460dfde` (fork-verified).
   - Template = **UniswapV2Pair fork** with rebranded strings: `"Aurora LPs"` (EIP-712 name), `"Aurora: K"`, `"Aurora: INSUFFICIENT_*"`, `"Aurora: TRANSFER_FAILED"`, plus the original `ds-math-*` SafeMath strings. The k-invariant check is present and enforced (fork PoC).
   - Pairs are **unverified** on the explorer; behavior was verified on a fork instead (§7).
2. **`0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE`** — **`BRLMasterChef`** (verified source, solc 0.6.6, Goose/Pancake-style MasterChef). The "staking token" in the registry is `BRL` (`0x12c87331…d77F`), the farm's own mintable reward token.
   - `BRL` (`BEP20('BRL Token','BRL')`, 18 dp) is `Ownable` with `owner() = BRLMasterChef` → the only mint path is `updatePool()` emission.
   - Farm: 36 pools, `BRLPerBlock = 0.025e18`, `totalAllocPoint = 101,000`, `startBlock = 56,347,461`, `devaddr = feeAddress = 0x9F67…bcAE`.
   - `MC.owner() = 0xFdf4aF84764E67333985af2Db9b1fE57dFEc8251` (EOA, code size 0).
   - Quirk: `updatePool()` mints `BRLReward` to the MC **plus an extra 10%** to `devaddr` (110% nominal inflation — an inflation bug, not an attacker path).

---

## 3. Live state (all reads read-only at stated blocks)

**Block used for the pair scan:** 219,722,582 · **farm reads:** 219,725,362 · **PoC fork block:** 219,723,846.

### 3.1 Pairs / TVL (priced with DefiLlama, 2026-10-12)

| Pair | Reserves (human) | Value |
|---|---|---|
| USDT.e/NEAR `0xf3de…cefc` | 62,241.46 USDT.e · 11,605.41 NEAR | $126,185 |
| NEAR/WETH `0xc57ecc…e067` | 1,861.26 NEAR · 3.9927 WETH | $20,335 |
| USDC.e/NEAR `0x480a68…9f27` | 3,504.35 USDC.e · 654.15 NEAR | $7,111 |
| USDT.e/USDC.e `0xec538f…68cd` | 1,594.29 USDT.e · 1,596.78 USDC.e | $3,189 |
| NEAR/APE, AURORA/NEAR, WETH/WBTC, NEAR/WBTC, MATIC/NEAR … (121 more) | — | ~$2,924 |
| **Total (all 125 pairs, priced tokens)** | | **$159,744.84** |

- 4 pairs hold 98% of the value; 121 pairs are dust (<$1k each).
- **No pair has token balances above its own reserves** (`balanceOf(pair) == reserve` for 125/125 pairs, fork-verified) → nothing to `skim()`.
- **No pair has `totalSupply == 0` with non-zero reserves** → no first-minter/burn capture.
- The main pairs are **actively traded by arbitrage bots**: 627 `Swap` events on USDT.e/NEAR in the last 200,000 blocks (~2.3 days), last swap at block 219,723,810 (within a minute of the scan).

### 3.2 Farm

- `MC` holds **144,513.19 BRL** (`BRL.balanceOf(MC)`), `BRL.totalSupply = 791,551.17`, `devaddr` holds 22,994.60 BRL.
- Corrected pool supplies (`lpToken.balanceOf(MC)`, 36 pools) — note the earlier triage-style read of `balanceOf(lpToken)` is wrong; the MC's staked positions are material:
  - pid 4 (USDT.e/NEAR LP): **18.4226 LP staked = 96.69% of that pair's LP supply ≈ $121,995**;
  - pid 2 (USDT.e/USDC.e LP): 89.26% ($2,847); pid 3 (USDC.e/NEAR): 28.81% ($2,049); pid 6 (WETH/WBTC): 87.83% ($623); pid 16 (AURORA/NEAR): 84.79% ($610); pid 1 (NEAR/WETH): 1.58% ($320); pid 13 (BRL/NEAR): 1,859,519 LP.
  - **≈$128,996.56 of the DEX liquidity is staked in the farm** and is withdrawable by its stakers (H-O).
- **Pool 35** (`lpToken = AZFD 0x19185181…603ee`, `allocPoint = 100,000` = 99.01% of emissions):
  - AZFD: `totalSupply = 1e18` (exactly 1 token), sole holder = the MC, `owner() = 0xFdf4…8251` (the MC owner), `mint()` is `onlyOwner`.
  - `userInfo(35, 0xFdf4…8251) = (amount 1e18, rewardDebt 248,202.69 BRL)`; `accBRLPerShare = 2.482e17`.
  - `lastRewardBlock = 82,182,172` → **gap 137,543,190 blocks → 3,404,496.88 BRL** mintable by anyone calling `updatePool(35)` — credited **only** to the existing staker (fork-verified).
  - Other pools' gaps: 22,931.84 BRL total (largest: pid 13 4,015 BRL, pid 14 3,132 BRL, pid 3 2,487 BRL, pid 4 2,289 BRL, pid 33 2,236 BRL) — credited only to those pools' existing stakers.
- Pending accounting invariant: the MC's BRL balance = Σ pool-0 stakes + Σ unclaimed pendings, so all current pendings (≤ 144,513.19 BRL) are covered — no first-come-first-served race at current state.

### 3.3 Protocol fees

- `feeTo` is set and `kLast != 0` on traded pairs → the 0.05% protocol fee accrues.
- feeTo already holds **0.6103 LP of USDT.e/NEAR** (≈$4.0k); unminted fee ≈ $1,091 across priced pairs (USDT.e/NEAR $705.76, NEAR/WETH $347.27, others small).
- `mint(feeTo)` is permissionless but always mints to `feeTo` (fork-verified: attacker LP gain = 0).

### 3.4 Roles / ownership (all EOAs, code size 0)

| Role | Address | Notes |
|---|---|---|
| factory `feeTo` / `feeToSetter` | `0x9F678909C735001Ac6482fCCFc928e11B703bcAE` | also farm `devaddr`/`feeAddress` |
| `BRLMasterChef` owner | `0xFdf4aF84764E67333985af2Db9b1fE57dFEc8251` | staked the 1 AZFD in pool 35 |
| `BRL` owner | the MasterChef itself | mint only via `updatePool` |
| `AZFD` owner | `0xFdf4…8251` | mint only by owner |

---

## 4. What an attacker can and cannot do (exact paths)

All paths below were attempted on a pinned fork (see §7). **Every path is closed.**

| # | Candidate path | Preconditions checked live | Result |
|---|---|---|---|
| 1 | `pair.skim(attacker)` — take balances above reserves | excess = 0 on 125/125 pairs | reverts/no-op; $0 (fork: `test_no_excess_all_pairs`, `test_skim_returns_zero`) |
| 2 | Unfair `swap()` — take > k allows | tiny input (1 unit), request 90% of output reserve | reverts `"Aurora: K"` on all 6 funded pairs; reserves unchanged (fork) |
| 3 | LP mint/burn round-trip (inflation/rounding) | add 100 USDT + 18.6458 NEAR, mint, burn | returns 99.999999 USDT + 18.645793926578135107 NEAR — **no profit** (fork) |
| 4 | Trigger protocol fee mint to self | `pair.mint(x)` permissionless | LP always to `feeTo`; attacker gain = 0 (fork) |
| 5 | Capture farm gap rewards with a fresh stake | deposit into stale pool (4 and 35) | `deposit()` runs `updatePool()` first; attacker pending = 0, gained = 0 BRL; the gap is minted to the *existing* staker (fork) |
| 6 | Steal another staker's pending | MasterChef `withdraw` pays `msg.sender`'s `userInfo` only | no cross-user path; `safeBRLTransfer` caps at MC balance |
| 7 | Mint BRL / AZFD | `BRL.mint` owner = MC; `AZFD.mint` owner = `0xFdf4…` | reverts (`Ownable: caller is not the owner`) |
| 8 | Admin takeover | factory `setFeeTo`/`setFeeToSetter`/`setLocked`; farm `updateEmissionRate`/`set`/`add`/`dev`/`setFeeAddress` | all revert for unprivileged caller (fork `test_privileged_gates_revert`) |
| 9 | Stale-price arbitrage vs external venues | cross-checked Trisolaris ($312k USDT/NEAR, $500k NEAR/WETH, $194k USDC/NEAR), WannaSwap ($13.8k USDC/NEAR), NearPad | all venues price wNEAR within ~2–3% of each other; the "deviation" vs DefiLlama is an **Aurora-wide discount** (BNB −86%, MATIC +97% consistent across all three venues too) → no cross-venue edge |
| 10 | APE arb ($555 theoretical) | no other Aurora venue has an APE pool | not realizable without bridging APE in (dead Wormhole-era asset); pool is $723 |
| 11 | Zero-supply pair capture | 0 pairs with `totalSupply == 0` and reserves | $0 |

**Costs** if any of these had worked: gas on Aurora (~cheap) + optional flash-loan fee (Aave not needed — all paths were self-funded). Net = $0.

**Theoretical arb bound** (if one insists on the DefiLlama *global* price as the exit): optimal one-shot on USDT.e/NEAR = 725.32 USDT in → 133.29 NEAR out → value $733.74 → **profit $8.43**; sum across all priced pairs $628.52, dominated by non-realizable dead assets (NEAR/APE $555, BNB/NEAR $34, MATIC/NEAR $14, atUST $8.7).

---

## 5. Verdict

- **E-U (external unprivileged): $0.00** — high confidence. No live drain, skim, mint, arb, or accounting path was found; all candidate paths revert or yield nothing on a fork of the current state.
- **H-O (holder/user recoverable):** ~$128,996.56 of staked LP (withdrawable by stakers) + pending BRL ≤ 144,513.19 BRL (nominal ≈ $1,507 at the pool-implied price $0.010428; realizable only against BRL pools' exit liquidity, $1,606.54 total).
- **P (privileged):** 3,404,496.88 BRL gap + ~312 BRL pendings to the MC owner (nominal ≈ $35,503; realizable ≤ the same $1,606.54 exit liquidity); protocol fees ~$5.1k to `feeTo`; 22,994.60 BRL dev fees. The owner can also inflate `BRLPerBlock` arbitrarily (rug capability, P).
- **S (stuck):** $0. (Gaps in pools with `lpSupply == 0` simply never mint — dead, but nothing was ever deposited there.)

**Blockers/frictions for any extraction:** BRL is an illiquid farm token with ~$1.6k of total exit liquidity; AZFD (the 99% emission pool) is owner-minted with a supply of 1; the DEX's real value ($159.7k) is LP property in a live, bot-arbitraged market, not protocol-owned funds.

---

## 6. Residual / latent risk

1. **Donation → k-bypass window.** The UniV2 k-check is balance-based, so a large donation of one token to a pair lets anyone drain the other side until `skim()` is called. This is *not live* (excess = 0 on all 125 pairs) and `skim()` is permissionless (anyone can take the excess), but the window exists. Proven synthetically on a fork: a 1e12 USDT donation allowed draining 5,802.71 NEAR (50% of the reserve) with 1 USDT in; `skim()` then recovered the donation.
2. **The MC owner holds a 99%-emission position** funded by an owner-minted 1-token asset; if the owner ever unstakes, the position can only be re-created by the owner (AZFD is not tradeable and not mintable by others).
3. **BRL emission continues** at 0.025 BRL/block (≈2,160 BRL/day), 99% to pool 35 (owner) — nominal ~$22/day to the owner, realizable only against ~$1.6k of BRL exit liquidity.
4. **The farm's 10%-extra dev mint** (`R + R/10`) is an inflation bug; it benefits `devaddr` (0x9F67…) only.

---

## 7. Fork verification (PoC)

- Project: `poc/` (Foundry, solc 0.8.24, `via_ir`), tests in `poc/test/AuroraSwap.t.sol`, interfaces in `poc/src/Interfaces.sol`.
- Fork: Aurora mainnet, **pinned block 219,723,846**, keyless public RPC (`https://mainnet.aurora.dev`, fallbacks drpc/aurora).
- CI: GitHub Actions, public repo `kingmariano/ca-zombie-ci`, workflow `poc.yml`.
  - Run #1 (12/13 passed — 1 failed due to a units bug in my own arb-math test): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38313468417
  - Run #2 (all-green, after fixing the test): see `summary.json` → `poc.ci_run_urls` / `ci-log.txt`.

Test evidence (run #1 log):

| Test | Result | Key numbers |
|---|---|---|
| `test_all_pairs_same_template` | PASS | 125 pairs, codehash `0x24150c11…60dfde` |
| `test_no_excess_all_pairs` | PASS | 125/125 fully checked, 0 skipped → excess = 0 |
| `test_unfair_swap_reverts` | PASS | 6 pairs, revert data decodes to `"Aurora: K"`, reserves unchanged |
| `test_k_revert_reason_exact` | PASS | exact revert `Error("Aurora: K")` |
| `test_fair_swap_matches_formula` | PASS | 100 USDT.e → 18.560126446671284332071946 NEAR = 0.3%-fee formula exactly |
| `test_lp_roundtrip_no_profit` | PASS | 100 USDT in → 99.999999 out; 18.645793926578135116 NEAR in → 18.645793926578135107 out |
| `test_feeto_fee_mint_only_to_feeto` | PASS | feeTo LP 0.610333567068153028 → 0.681250280438805321 (attacker 0) |
| `test_skim_returns_zero` | PASS | attacker balance unchanged after `skim()` |
| `test_farm_pool35_gap_goes_to_owner` | PASS | gap 137,541,674 blocks → R = 3,404,496.88 BRL; minted 3,744,946.57 BRL (R + 10% dev); owner pending = R; **attacker pending = 0** |
| `test_farm_fresh_stake_cannot_capture_gap` | PASS | pool 4 gap 87,257,425 blocks → 2,289.43 BRL minted; MC BRL 144,513.19 → 146,802.62; **fresh staker gained 0 BRL** |
| `test_privileged_gates_revert` | PASS | 9 privileged calls revert; owners/feeTo verified |
| `test_donation_k_bypass_synthetic` | PASS | synthetic donation → 5,802.71 NEAR drained with 1 USDT in; `skim()` recovered the donation |
| `test_arb_upper_bound_main_pair` | fixed in run #2 | optimal 725.32 USDT in → 133.29 NEAR out → profit **$8.43** vs global price; ~$0 vs Aurora-local price |

The CI job also re-runs `analysis/scan_pairs.py` (independent on-chain re-scan) and uploads `ci-out/pairs_scan.json`.

---

## 8. Methodology, sources, caveats, files

**Method.** DefiLlama registry → custody set (factory + farm). On-chain: factory enumeration (125 pairs), per-pair `token0/token1/getReserves/totalSupply/kLast/balanceOf`, farm `poolInfo/userInfo/pendingBRL`, token identities, admin roles, EOA-vs-contract checks, Swap-event history. Prices: DefiLlama `coins.llama.fi`. Cross-venue check: Trisolaris/WannaSwap/NearPad/Amaterasu factories. PoC: fork tests on CI. Staker census: Blockscout `Deposit` logs (script provided).

**Corrections to the corpus/triage.** The Phase-1 triage valued the farm's `BRL` at $0 (no DefiLlama price); the pool-implied price is ~$0.0105 (pool-implied), but realizable exit liquidity is only $1,606.54. The triage also read the farm via `sum_tokens` (BRL balance) — correct — but the MC's *staked LP positions* ($128,996.56) are the bigger farm custody item.

**Caveats / limitations.**
- BRL has no market price feed; all BRL USD figures are pool-implied and only realizable up to the pools' combined $1,606.54 exit liquidity.
- The exact per-staker census (to split H-O precisely) was not completed (explorer API DNS flakiness); `analysis/stakers.py` reproduces it. The bound used: Σ pendings ≤ MC balance = 144,513.19 BRL.
- Arb figures depend on the assumed exit price; DefiLlama's global price is **not** the Aurora-local price (see §4 row 9).
- The pair template is unverified source; verification here is behavioral (fork) + bytecode-string analysis, not a source audit.
- Fork tests pin block 219,723,846; later state (new swaps) can shift reserves/deviations slightly.

**Files.**
```
auroraswap/
├── README.md                     (this file)
├── summary.json                  (machine-readable headline)
├── analysis/
│   ├── scan_pairs.py             factory + all-pairs scan (reserves vs balances)
│   ├── prices_arb.py             token identities, DefiLlama prices, deviations
│   ├── mc_pool_detail.py         farm pools (poolInfo + correct lpSupply)
│   ├── mc_pools.py               earlier farm read (superseded; see note)
│   ├── quantify.py               arb bound, farm gap totals, BRL exit liquidity
│   ├── venues.py                 cross-venue price check (Trisolaris/WannaSwap/…)
│   ├── check_balances.py         balanceOf cross-check (multi-word return tokens)
│   ├── verify_batch.py           batch-vs-individual eth_call verification
│   ├── stakers.py                staker census from Deposit logs
│   ├── BRLMasterChef.sol         verified farm/token source (explorer)
│   ├── pairs_scan.json / pairs_priced.json / tokens_meta.json / prices.json
│   ├── mc_pool_detail.json / stakers.json
│   └── factory-explorer.json / pair-f3de-explorer.json / staking-explorer.json
├── poc/                          Foundry fork PoC (13 tests)
├── ci/run.sh                     CI re-scan job
├── ci-out/                       CI artifacts
└── ci-log.txt                    full CI log
```

**Negative results (do not re-investigate).** No skim excess on any pair; no zero-supply pair; no unfair-swap path; no LP math bug; no feeTo capture; no farm-gap capture by fresh stakers; no unprivileged admin path; no cross-venue arb on Aurora; no public mint for BRL/AZFD. The earlier "4 pairs with excess" signal from a first-pass script was a **decoding bug** (some tokens return 96-byte `balanceOf` payloads; decoding the whole payload inflates the value) — corrected in `scan_pairs.py` and confirmed by fork tests.

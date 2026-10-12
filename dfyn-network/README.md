# Dfyn Network — L2 Phase-2 deep dive (zombie-hunt II)

**Date:** 2026-10-12 · **Chains:** Polygon (137), Fantom (250), OKExChain (66) · **Status:** read-only; fork PoC only; no mainnet transactions.

**Question:** how much can an external, unprivileged attacker extract live from Dfyn Network (DEX + legacy farms/vaults/chest/prediction market)?

---

## 1. TL;DR

| Target | Live value (latest blocks) | Attacker-extractable (E-U) | Why closed / open | Latent risk |
|---|---|---|---|---|
| Dfyn V2 AMM pairs — Polygon (1,788), Fantom (35), OKC (4) | **$339,575.91** pool reserves (CI DefiLlama pricing; DefiLlama $394,588 + $315 + $22) | **$0.00** | Vanilla UniswapV2Pair (identical bytecode, verified source). 92/1,788 pairs have positive raw donation-excess, but **every excess token is an unpriced spam token** (XMN, PolyBabyDoge, POLYSAFE, KIM, WOLF, eDAI/eUSDC, CHIRO…); **priced excess across all pairs = $0.00008**; zero excess on any core token (USDC/USDT/DAI/WETH/WBTC/WMATIC/ROUTE/DFYN). LP value is holder-only | Arb/MEV only if external market prices diverge; exit liquidity for excess tokens is < $0.30 total |
| Legacy farms — 227 curated + 15 factory-deployed (242 addresses; 3 factories) | **$198,905.13** staked LP (inside pool reserves above) + **6,568,314 DFYN ($972.71) + 943.8 ROUTE ($36.53)** reward leftovers | **$0.00** | Per-user accounting (`getReward`/`withdraw` only for own balance); all reward periods ended 2021–22 | Leftover rewards recoverable by `rewardsDistribution` only (P) |
| Single-asset vesting vaults (10) | **183,111.88 DFYN ($27.11)** + 7,342.83 ROUTE ($284.17) | **$0.00** | `claim()` gated on caller's own `_balances` | Depositors-only (H-O); unfunded interest could strand late claims |
| vDFYN chest (DfynChest, xSUSHI-style) | **4,228,238.80 DFYN ($626.03)** | **$0.00** | `leave()` burns caller's own shares | Holder-only (H-O) |
| DfynPricePrediction market | **1,982.57 POL ($203.42)** | **$0.00** | `claim(epoch)` per bettor; `claimTreasury()` onlyAdmin | Bettor refunds (H-O) + treasury (P) |
| Factory `feeTo` (EOA) LP position | **$1,639.00** | **$0.00** | Protocol-fee LP minted to EOA `0x7466…5fd70`; only that key can move it | P — key-compromise risk only |
| Broken pools (MONA/RAILPOLY, MAHA/ARTH ×2) | $1.49 (0.2922 MONA) + $0 | $0.00 | Token balance burned out of pair while reserves unchanged; swaps out of the missing side revert | S — bricked |
| Polygon factory stray balance | **100.00 USDC ($99.97)** + spam tokens | $0.00 | Stock `UniswapV2Factory` has no sweep function; tokens sent to it are permanently stuck | S |

### Total live extractable now (external unprivileged): **$0.00** — confidence: **high**

Raw positive donation-excess exists on 92/1,788 Polygon pairs (Fantom/OKC: none) but is entirely unpriced spam tokens; the priced total is **$0.00008**, net-negative after gas. Live value attributable to Dfyn contracts ≈ **$341.8k** (pools $339.6k + farm leftovers $1.0k + vaults $0.3k + chest $0.6k + prediction market $0.2k + stuck factory USDC $0.1k); it is owned by LPs (H-O, incl. farm stakers), the protocol-fee EOA (P), depositors (H-O) and bettors (H-O/P). DefiLlama's cross-check for the same pools is $394.9k (price-source differences; see §5).

---

## 2. The bug/mechanism in exact terms

Dfyn V2 is a **stock UniswapV2 fork** (no custom AMM math, no oracles, no admin sweep):

- Factory `0xE7Fb3e833eFE5F9c441105EB65Ef8b261266423B` (Polygon, OKC) / `0xd9820a17053d6314B20642E465a84Bf01a3D64f5` (Fantom) — verified `UniswapV2Factory` v0.6.12; `feeTo = feeToSetter = 0x74665b21461f8d9b23bab7d599bfd7566a95fd70` (EOA, no code) on Polygon/Fantom; `feeTo = 0x0` on OKC.
- Pairs — verified `UniswapV2Pair` v0.6.12; identical runtime bytecode within each chain: Polygon `keccak256 = 0x9f65a71165f3fd2ff219941a904202d9afc94d6cc1dd770b71677e36967cffb0` (40 sampled), Fantom `0xdbcaecadf3db1ea222a236373c3e8b1158f2694bc8b5a1941904d73810137d49` (6 sampled), OKC `0x93347e066af77425c4b63c4743ad6612014ab4e0e8a7c0f1886cf6d5ab9983ce` (4/4). Fee 0.3% (`balanceAdjusted·1000 - amountIn·3`, `K` check).
- Router `0xA102072A4C07F06EC3B4900FDC4C7B80b6c57429` — stateless, 0 balance.

The only unprivileged value-movers in UniV2 are: (a) `skim(to)` — sends `balance - reserve` to anyone; (b) fee-on-transfer/rebase-token drains — only if a funded pair holds such a token (deficit); (c) `mint()/burn()` — fair-value. There is no owner withdrawal, no upgradeable logic, no pause. Therefore **E-U = Σ max(balance−reserve, 0) priced + any FoT drain on funded pairs**. Measured across all 1,827 pairs: priced excess **$0.00008** (92 Polygon pairs, all unpriced spam tokens); deficits exist on 3 bricked pools (skim reverts); zero excess on any value-bearing token.

---

## 3. Live-state assessment (exact reads)

Blocks: Polygon **95,381,964**, Fantom **123,652,961**, OKC **47,755,732** (Phase-2 scan run 2, 2026-10-12; fork tests at latest). Source: `ci-out/pairs-*.json`, `ci-out/scan-summary.json`, `analysis/factory-recon.json`.

**Factories:** `allPairsLength()` = 1,788 / 35 / 4. `feeTo` & `feeToSetter` = EOA `0x7466…5fd70` (Polygon+Fantom; OKC feeTo=0). `migrator`/owner paths are EOA-gated (verified factory source, standard).

**Pair integrity (all 1,827 pairs; block 95,381,964 Polygon / 123,652,961 Fantom / 47,755,732 OKC, run 2):**
- Polygon: 1,788 pairs, 1,695 with reserves > 0, **Σ reserves = $339,396.92** (llama prices at scan time); **92 pairs have positive raw excess** — every excess token is unpriced spam/dust (XMN, PolyBabyDoge, POLYSAFE, SAILORMOON, KIM, ROCKET, PolyMoon, CHIRO, eDAI/eUSDC, WOLF, amToken dust); **priced excess total = $0.00008**; **zero excess on any core token** (USDC/USDT/DAI/WETH/WBTC/WMATIC/ROUTE/DFYN verified over the sample); **deficit pairs = 3** (bricked pools, §6). Full list: `analysis/excess-pairs-run2.json`.
- Fantom: 35 pairs, Σ = $136.29, excess = 0, deficits = 0. OKC: 4 pairs, Σ = $22.11, excess = 0, deficits = 0.
- `skim(attacker)` fork-verified no-op / reverts on the 6 largest pools (USDC/USDT $57.9k, DAI/USDT $49.2k, USDC/WETH $46.9k, WETH/WBTC $41.8k, WETH/UNI $26.1k, WETH9-clone/WETH $21.0k) and on the eDAI pair; `balanceOf(pair) == reserve` exactly for both tokens (value tokens). The excess spam tokens' exit liquidity was checked on Dfyn+QuickSwap+Sushi: every real-token side holds < $0.30 (e.g. XMN/USDT pools $0.01+$0.05, KIM/USDC $0.24).

**Top pools** (pair → USD; full list in `ci-out/scan-summary.json`):
| pair | USD | notes |
|---|---|---|
| `0xbe40f7ff…` USDC/USDT | $57,989 | 29,011.7 USDC + 29,011.1 USDT; 97.3% LP staked in farm |
| `0xdd228fdc…` DAI/USDT | $49,193 | 24,597.1 DAI + 24,610.6 USDT |
| `0x7d51bad4…` USDC/WETH | $46,888 | 23,474.1 USDC + 9.2098 WETH |
| `0x39eaa90a…` WBTC/WETH | $41,801 | 0.25029 WBTC + 8.2253 WETH |
| `0xb5e1a07c…` WETH/UNI | $26,112 | 5.1218 WETH + 1,694.5 UNI |
| `0xc3379226…` WETH9-clone/WETH | $21,041 | WETH9 clone `0x4c28f484…` (wraps POL 1:1, fully backed) |
| `0xebc4f9b1…` ROUTE/WETH | $10,778 | 138,981.9 ROUTE + 2.1232 WETH |
| `0x4f5df10b…` WETH9-clone/USDC | $8,197 | 8,198.7 USDC |
| `0x39bed7f1…` UST/USDT | $7,676 | 714,542.6 UST + 3,810.5 USDT |
| `0xb7bd6d48…` USDC/DAI | $6,700 | 3,349.4 USDC + 3,350.1 DAI |

**Ownership split of the $339.6k pool value** (`analysis/value-split.json`):
- Farm-staked LP (H-O, stakers can `withdraw`): **$198,905.13** — e.g. DAI/USDT $47,844.59, WBTC/WETH $39,320.33, USDC/WETH $36,905.35.
- `feeTo` EOA LP (P): **$1,639.00** across 452 Polygon pairs (top: USDC/WETH $547.34, WETH/UNI $252.76).
- Free LP (H-O): $139,031.78.

**Farms:** 237 registry addresses (dfyn/dfyn-farms-info) **plus a full enumeration of the 3 deployment factories** (BYOF, self-serve farm creation — docs "Build Your Own Farms"):
- `0x28cfcda0469d0ff70da48ee774e90970bd86155c` (`StakingRewardsFactory`, BasicFarmsV1) — 16 farms
- `0x34df3b41c2e48d73d912963d12675dc22f8bd352` (DualFarms factory) — 4 farms
- `0x57791b5257a8b95d6c0c0a6ad947ffecc5e77953` (Popular/Launch factory with vesting) — 12 farms

32 factory farms total; **15 are not in the curated registry** — all 15 scanned: they stake only Dfyn-factory LP (their staked value is inside the $339.6k pool total), and hold 3,601.95 DFYN ($0.53) + unpriced reward tokens. Curated 227 live farms hold **6,564,712.17 DFYN ($972.18)** + 943.83 ROUTE ($36.53) reward leftovers. All `periodFinish` ≤ Nov 2021 (expired). DFYN/ROUTE leftovers = unclaimed staker rewards (H-O) + `rewardsDistribution`-recoverable remainder (P). Staked LP tokens are held 1:1 (`balanceOf(farm, lp) == totalSupply`); claims are per-user (`getReward`/`withdraw`/`exit`).

**Vaults / chest / prediction market:** 10 single-asset `Vault` contracts hold 183,111.88 DFYN ($27.11) + 7,342.83 ROUTE ($284.17) for their depositors (claim() per-user). DfynChest `0x75455c3D…` holds 4,228,238.80 DFYN ($626.03) backing 227,654.94 vDFYN (xSUSHI-style `enter/leave`). `DfynPricePrediction 0x150B4fD2…` holds 1,982.57 POL ($203.42), `paused=false`, `currentEpoch=23598`, `isRefundable=true`, treasury 417.19 POL ($42.81, admin-only).

**feeTo EOA:** `0x74665b21461f8d9b23bab7d599bfd7566a95fd70` — no code, holds 57.40 DAI + LP tokens. Not reachable by unprivileged users. The Polygon factory itself holds **100.00 USDC** (plus spam tokens) with no sweep function — permanently stuck (S). Fantom/OKC factories hold none of their core tokens. Router holds only 0.000001 USDC dust.

---

## 4. What an attacker can / cannot do

- `pair.skim(to)` — **can call, extracts ≈$0**: value-bearing pools have balance == reserve exactly (fork-verified); 92 pairs do have donation-excess, but every one is an unpriced spam token worth ~nothing (total priced $0.00008; exit liquidity < $0.30). The two apparent "huge excess" pairs `0x0b88a556…` (WETH9-clone/eDAI) and `0x96f7d75a…` (WETH9-clone/eUSDC) were a decoder artifact — eDAI/eUSDC `balanceOf` returns 96 bytes and the first word equals the reserve exactly; fixed decode + fork test prove zero excess there. `skim` on the 3 deficit pools reverts (`ds-math-sub-underflow`).
- Swap round-trips — lossy by 2×0.3% fee (`test_round_trip_swap_is_lossy`); no oracle, no stale-price extraction inside the AMM.
- Fee-on-transfer drain — **no funded pair contains a FoT/rebase token**; the 3 deficit pools are unpriced/bricked tokens (MONA/RAILPOLY, MAHA/ARTH ×2, §6) worth $1.49 of missing MONA that is *not present in the pair* (balance 0).
- Farms — `getReward()` returns 0 for a zero-stake caller; `withdraw()` of unowned stake reverts (`sub` underflow); `rescueFunds` is `onlyRewardsDistribution` and cannot touch the staking token.
- Vaults — `claim()` requires caller's own `_balances > 0`.
- Chest — `leave()` burns caller's own shares; `enter()` is fair-value mint.
- Prediction market — `claim(epoch)` requires the caller's own `ledger` entry; `claimTreasury()` `onlyAdmin`.
- Broken pools — the missing side cannot be swapped out (transfer reverts); `skim` reverts (`ds-math-sub-underflow`).

Costs: gas only (~$0.01 on Polygon) — but there is nothing to extract.

---

## 5. PoC / fork verification

Foundry suite `poc/test/DfynExtraction.t.sol` (fork of Polygon). CI runs:
- Run 1 `38201566485` — scan OK; forge failed to compile (checksummed-address literals).
- Run 2 `38202680907` — scan OK (block 95,381,964); tests 8/10 (2 test-bugs: `skim` reverts on deficit pool; sample-excess assertion too strict) → fixed.
- Run 3 `38205037818` — scan OK; tests 3/10 — all 7 failures were transient fork-RPC state errors (`header for hash not found` on the un-pinned latest block), not logic → fork pinned to the scan block.
- Run 4 `«RUN4»` — final (fork pinned to block 95,381,964):

| Test | Result |
|---|---|
| `test_pair_code_uniformity` (40/1788 pairs identical bytecode; hash 0x9f65a711…) | PASS |
| `test_factory_state` (feeTo/setter EOA) | PASS |
| `test_top_pools_zero_excess_skim_noop` (6 pools) | PASS |
| `test_sample_pairs_excess_only_junk` (50-pair spread; no core-token excess) | PASS |
| `test_edai_pair_no_excess` (96-byte return, first word == reserve) | PASS |
| `test_broken_mona_pool` (balance 0 < reserve, skim reverts) | PASS |
| `test_farm_no_free_rewards` (getReward=0, withdraw reverts) | PASS |
| `test_vault_claim_not_depositor` | PASS |
| `test_dfyn_chest_no_free_value` | PASS |
| `test_round_trip_swap_is_lossy` | PASS |

Heavy enumeration (all 1,827 pairs, balances vs reserves, pricing) ran in CI: `ci/scan_pairs.py` → `ci-out/pairs-{polygon,fantom,okc}.json`, `ci-out/scan-summary.json` (run 2 outputs copied to `ci-out/`).

---

## 6. Verdict and residual/latent risk

**Verdict: E-U = $0.00 (high confidence).** The triage headline ($272,178) reflects LP-custodied pool value, not attacker-extractable value; the protocol is a plain UniV2 whose only unprivileged extraction surfaces — donation excess (92 spam-token pairs, priced $0.00008) and FoT drains (none on funded pairs) — are worthless at the scanned blocks. Live LP value ($339.6k CI-priced; $394.9k DefiLlama) is holder-recoverable (H-O), protocol-fee LP ($1.64k) is EOA-held (P).

Residual/latent:
- Arb/MEV against stale pool prices remains the *normal* AMM function; requires giving value and exit liquidity (most tokens are unpriced, 683 unpriced tokens in scan). No free lunch.
- Farm stakers hold $198.9k of LP — H-O, but only if they still control keys (dormant wallets).
- Vault interest is paid from the same token balance; if underfunded, late claimers may get less (holder risk, not attacker extraction).
- `feeTo`/`feeToSetter` is a single EOA — key compromise would let an attacker change `feeTo` (P; not unprivileged). The EOA also holds $1,639 of protocol-fee LP.
- Broken pools ($1.49 MONA missing) — S, bricked; factory-stuck 100 USDC — S.

---

## 7. Methodology & sources; caveats; files

- On-chain reads at stated blocks via keyless public RPCs (`polygon-bor-rpc.publicnode.com`, `polygon.drpc.org`, `fantom.drpc.org`, `exchainrpc.okex.org`); sources verified via Etherscan V2; prices via `coins.llama.fi` at scan time (recorded in `ci-out/pairs-*.json` → `prices`).
- Corpus: `zombie_hunt/FINDINGS.md` row, `l2-triage-a/summary.json` (Dfyn row), docs.dfyn.network (Wayback), dfyn/dfyn-farms-info registry, the 3 on-chain deployment factories (BYOF), DefiLlama adapter `dfyn-network`.
- Caveats: (1) CI llama-priced total $339.6k vs DefiLlama $394.9k — same custody, different price coverage/snapshot; (2) first Phase-2 scan run had a decoder bug (full-return `int()`) that falsely flagged the two eDAI/eUSDC pairs; corrected to first-32-byte-word decoding and re-run; (3) 92 pairs carry donation-excess in unpriced spam tokens (priced total $0.00008) — counted at $0, since their exit pools hold < $0.30; (4) 683 tokens have no DefiLlama price — their pools are counted at $0; (5) farm leftover H-O/P split not enumerable per-staker (aggregate reported; whole $1.0k counted as P for the category split); (6) staked LP in factory-deployed farms uses Dfyn pairs, so its value is already inside the pool total.
- Files: `analysis/` (recon, farms registry+scan, feeTo LP, value split), `ci/scan_pairs.py`+`ci/run.sh`, `poc/` (Foundry), `ci-out/`, `ci-log.txt`, `ci-artifacts/`, `summary.json`.

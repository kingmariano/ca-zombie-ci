# BurgerSwap (BSC) — L2 Phase-2 deep dive

**Date:** 2026-10-13 · **Chain:** BSC (56) · **Status:** read-only; PoC fork-verified only; no mainnet transactions
**Triage source:** `l2-triage-a/summary.json` row `burgerswap` — $152,595 live (medium confidence), factory `0x8a1E9d3a…1256` (922 pairs), staking `0x9154c268…81ec`.

---

## 1. TL;DR

| Target | Live value (on-chain, 2026-10-13) | Extractable by external unprivileged attacker | Why closed / open | Latent risk |
|---|---|---|---|---|
| 922 DemaxPair AMM pools (LP reserves) | **$132,992.90** priced side only (block 127,360,678); DefiLlama live **$190,805.45** | $0 (arbitrage-only, see below) | Reserves belong to LP holders; `removeLiquidity`/`burn` live and unpaused → **H-O** | LP keys lost → becomes S |
| Stray balances in pairs (`balance − reserve`) | **$11.69–$15.44** total (2 pairs; USDT/UNI 11.7 USDT + WBNB/KOGE 0.0591 KOGE) | **$11.14 gross / ≈$9.9 net** — fork-proven dilution capture of the USDT/UNI surplus; the KOGE surplus is **not profitably capturable** (0.1% of pair size vs 0.09% flash fee) | Pair has no `skim()`; a fresh LP captures the surplus pro-rata via `addLiquidity` → `removeLiquidity`; profit(k) = S·k/(1+k) − f·k·P → only surpluses that are large relative to the pair are profitable | Stray transfers recur; watch for new large-relative surpluses |
| Stale-price dump (PancakeSwap → dead pair) | 11 pairs, gross **$27.49** | **$6.55 net** after `swapPrecondition` gate cost (model + CI PoC) | Dead pairs still quote 2021 prices; attacker buys the stale side on PancakeSwap and dumps it at the pair's implied price | Price moves / Pancake liquidity drains |
| Free-mint balance-inflation drain (mintable token + sync/swap) | 296 tokens flagged with mint-like selectors; **$0 live** | **$0** — every mint entry point is access-controlled; top-12 fork-probed | Mechanism is **live** (proven with a mock token, `test_08`) but no live BurgerSwap token is freely mintable | A future listing with a public mint would open up its pair's full counter-side |
| LP DGAS rewards (`remainReward` in pairs) | 28,263 BURGER ≈ **$18.53** | $0 | `mintReward()` requires pair productivity (LP-only) → **H-O** | — |
| DGAS token-level pending (pullable by pairs via `_mintDGAS`) | 116,964 BURGER ≈ **$76.69** | $0 | 90% flows to pair `remainReward` (LP-owned), 10% to dev → **H-O / P** | — |
| BurgerShack staking (DemaxGovernance) | 92,637 BURGER + 16.5 USDT ≈ **$77.3** | $0 | `withdraw()` after `lockTime` (stakers) + governance reward accounting (voters) → **H-O**; USDT has no transfer path → **S** | — |
| DemaxPool LP rewards | 4,407 BURGER ≈ **$2.89** | $0 | `claimReward()` requires LP balance → **H-O** | — |

**Total live extractable by an external unprivileged attacker now: ≈ $16 (net) — medium-high confidence.**
Components: $9.9 (fork-proven excess dilution, 11.14 USDT gross) + $6.55 (stale-price dump model, CI PoC). The triage's $152,595 was almost entirely **LP-owned** value (H-O), not attacker-extractable. No live value changed materially since triage (reserves $132.99k priced vs $152.6k/$164.4k/$190.5k DefiLlama — differences are unpriced-token valuation, not withdrawals).

---

## 2. Architecture (deployed reality)

BurgerSwap is **not** a stock Uniswap-V2 fork. The verified deployed code is a "Demax" system:

| Contract | Address | Role |
|---|---|---|
| DemaxFactory | `0x8a1E9d3aEbBBd5bA2A64d3355A48dD5E9b511256` | 922 pairs, `contractCodeHash 0x9e2f28eb…`, owner `0xbc554d0FA1745AeB52acBA8343106CF8ACa038Ca` |
| DemaxPair (impl for all pairs) | e.g. `0xA5E6519E1623547B7C6b1eC8f0f4F918bBAcE5dd` (WBNB/BUSD) | LP token + reserves + internal DGAS reward accounting |
| DemaxConfig | `0xE7F6824706aEee33542088eb2fdd2D69e37455B6` | governor = DemaxGovernance, platform = DemaxPlatform, all 922 pairs point here |
| DemaxPlatform (router+swap) | `0xB099D7dbC415bf5491B0ca6fdCcFddF8b7EDCE12` | **isPause = false**; owner `0x88ef62c81Ceabb8F611e10127b6d7b29C9b1dAa6`; holds the k-check patch |
| DemaxGovernance (BurgerShack staking) | `0x9154c2684aeF8d106babcB19Aa81d4FabF7581ec` | BURGER staking (lockTime 17,280 blocks), governance ballots |
| DemaxPool | `0x86A327715d707BCa24983b1145D1F6c40C5d4A74` | LP fee/reward pool, 4,407 BURGER |
| BURGER (Dgas, ERC2917) | `0xAe9269f27437f0fcBC232d39Ec814844a51d6b8f` | `amountPerBlock = 0` (no new emissions); impl = governor = `0x54a1Ca2ED74F0ac04E21E2154022b330104F2E7A` (TransparentUpgradeableProxy) |
| DemaxTransferListener | `0x3BecD05231bBBa6F7AdDa92F3c79fb3AA96d943b` | productivity bookkeeping (platform-only) |

**All 922 pairs were checked to point at the same config/platform** (`analysis/config_distribution.json`, full `CONFIG()` scan) — there is **no old/unpatched platform** reachable through any pair.

### Historical exploit (May 2021)
~$7.2M was stolen (fake token + reentrancy; Halborn/SlowMist). The deployed platform carries the post-exploit patch:
`_swap()` performs a per-hop `kBefore <= kAfter` reserve-product check ("Burger K") and `addLiquidity`/`removeLiquidity`/`_swap` are `nonReentrant` (`analysis/sources/platform.sol`). The pair itself has no k-check — it is `onlyPlatform` (`IDemaxConfig(CONFIG).platform()`), so the platform is the only entry point.

### The two live mechanism-level weaknesses

**(a) Stale-reserve pricing + no `skim()` (E-U, bounded).** `DemaxPlatform._swap` prices with `pair.getReserves()` and the k-check compares the product of **stored reserves** before vs the product of **balances** after (`_update` sets reserves = balances). The pair has **no `skim()`**, and `sync()`/`swap()` are the only balance-reserve reconciliation paths. Consequences:
- Any `balance − reserve` surplus is capturable by a fresh LP: `addLiquidity` prices entry at the **reserve ratio** (`quote()`), `burn` pays out pro-rata at the **balance ratio** (`amount = amount·balance/totalSupply`). A new LP therefore captures `k/(1+k)` of the surplus; the rest stays with existing LPs.
- A token whose balance can be inflated arbitrarily (public mint) can drain the counter-side: transfer a large amount to the pair (**no sync needed** — pricing uses the stale small reserve), then `swapExactTokensForTokens(mal → real)`; the k-check is trivially satisfied by the inflated balance. Proof: `test_08_mechanism_positive_control` (mock mintable token + third-party victim LP).

**(b) Stale prices vs live markets (E-U, small).** Pairs haven't traded in years, so their implied prices differ from current PancakeSwap markets. An unprivileged attacker can buy the stale side on PancakeSwap and dump it into the dead pair at the implied price. Quantified per pair in `ci/pancake_arb.py`.

### Gates an attacker must satisfy
- `_swap` requires `swapPrecondition(output)` and per-hop `swapPrecondition(input)`. For token ≠ BURGER/WBNB it requires `existPair(BURGER, token)` **and** `dgasValue ≥ 0.2004%·(dgasValue + wbnbValue)` where `dgasValue` = the token's BURGER-pair value. Most scam tokens fail this; it is bypassable by funding a `token/BURGER` pair with ≥0.2004% of the token's WBNB-pair value in BURGER (cost ≈ 0.2% of the pair's WBNB side — this cost is included in the net numbers).
- `noneTokenCall` blocks callers registered as tokens; `isPause=false`; `SWAP_FEE_PERCENT=0` (only the 0.3% AMM fee applies); `REMOVE_LIQUIDITY_DURATION=1` block.

---

## 3. Live state (explicit blocks)

Enumeration at **block 127,360,678** (`ci-out/summary.json`, run `38361196543`), re-verified locally at **block 127,365,811**:

| Metric | Value |
|---|---|
| Pairs | 922 (all pairs enumerated, not sampled) |
| Priced reserve value | **$132,992.90** (49 of 573 tokens priced by DefiLlama; unpriced tokens valued 0) |
| DefiLlama protocol TVL | **$190,805.45** (+ $60.76 staking) — consistent, higher because it prices more tokens |
| Pairs ≥ $1 / ≥ $100 / ≥ $1,000 | 177 / 47 / 12 |
| Total surplus (`balance − reserve`) | **$11.69** (block 127,360,678) → **$15.44** (block 127,367,307): USDT/UNI `0x03b89d517fe95478d9DE3aF60E4332Fd3BDDED8b` 11.7 USDT (live at 127,365,811: reserves 24.716 USDT / 5.988 UNI, balances 36.416 USDT / 5.988 UNI, LP 12.166e18) + WBNB/KOGE `0x41b521b4f59d581a07a789689ccb3590053ffb2a` 0.0591 KOGE ($3.75) that appeared mid-campaign. Only the USDT/UNI surplus is profitably capturable (surplus is 10.5% of pair size vs 0.1% for KOGE) |
| `remainReward` (pair DGAS pools) | 28,263.04 BURGER ≈ **$18.53** (BURGER $0.0006557) |
| DGAS token-level pending (`takeWithAddress` over all 922 pairs) | 116,964.04 BURGER ≈ **$76.69**; BURGER token contract holds 143,480 BURGER |
| Tokens with mint-like selectors in bytecode | 296 / 573 (all access-controlled — see §5) |
| Top pairs | ETH/WBNB $30,716.90 · JNTR/b/WBNB $26,354.50 · BCH/WBNB $15,494.86 · USDT/WBNB $8,794.83 · WBNB/BUSD $7,709.49 · dou/WBNB $7,444.07 · SHLIAPA/WBNB $5,472.15 |

Governance (`0x9154c268…`): totalSupply = balance = 92,637.02 BURGER; stakingSupply 77,373.88 (withdrawable by stakers); lockTime 17,280 blocks; USDT 16.5 (no transfer path → S); `rewardOf[pool]` = 0. Pool (`0x86A327…`): 4,407.20 BURGER, `totalReward` = 0.

---

## 4. What an attacker can / cannot do (exact paths)

**CAN (E-U, live):**
1. **Surplus dilution** (USDT/UNI, `0x03b89d51…`): `addLiquidity(USDT, UNI, ~20×reserves, 0, 0, deadline)` → `vm.roll(+1)` → `removeLiquidity(...)`. Fork-measured: deposited 494.32 USDT + 119.76 UNI → withdrew 505.46 USDT + 119.76 UNI → **profit 11.14 USDT** (95% of the 11.7 surplus). Flash-loan cost (0.09% on ~$1.4k) ≈ $1.2 → **net ≈ $9.9**; gas < $0.1 on BSC.
2. **Stale-price dumps** (net after gate): QAA/WBNB **$4.30**, XRP/WBNB **$0.98**, CHEF/WBNB **$0.85**, WBNB/MXC **$0.32**, WBNB/CREAM $0.04, DEGO/WBNB $0.03, WBNB/ANKR $0.02, BFI/WBNB $0.01 → **$6.55 total**. Path: buy the stale token on PancakeSwap V2 (`getAmountsIn`/`swapTokensForExactTokens`), optionally fund a `token/BURGER` pair to pass `swapPrecondition`, then `DemaxPlatform.swapExactTokensForTokens(token → WBNB)`. PoC: `test_10_stale_price_dump_live` (targets from `ci/pancake_arb.py`).
   - Gross was $27.49; BCH/WBNB (−$4.21) and ETH/WBNB (−$29.31) go **net negative** once the 0.2004% gate cost is paid, so they are excluded.

**CANNOT:**
- Drain a normal pair: `swap()` is platform-only; the k-check and the 0.3% fee make fair-capital round-trips lose money (`test_05`, and `test_08` positive control proves only *inflatable* tokens break it).
- Free-mint anything: **all 296 flagged tokens rejected an unprivileged `mint`** — 309 simulated `eth_call`s from `0x1111…` (variants `mint(address,uint256)`, `mint(uint256)`, `mint()`, `mint(address)`, `mintTo`, `print`, `issue`, `generate`, `airdrop`) returned 0 hits; fork probe of the top-12 candidates from a fresh address: all "not freely mintable" (JNTR/b "Caller is not the gateway", SHLIAPA/MXC/BONUM/LUNAR/UnionPay "Ownable", bBPAL/bWHF/bCHBS/bIMTY "FORBIDDEN", USDX "ONLY_OWNER", RICK "minting is finished"). USDT/BUSD/ETH/BCH/DOT/XRP/BTCB mints are owner-gated (owner = Binance pegging contracts).
- Claim LP rewards without LP productivity: `pair.mintReward()` reverts `NOTHING TO MINT`; `DemaxPool.claimReward()` reverts `NOTHING TO MINT` (`test_02`, `test_03`).
- Pull third-party tokens via `DemaxGovernance.receiveReward(victim, amount)`: requires the victim's BURGER allowance to the governance contract (`test_04`); the value at stake is ≤ $77 and no evidence of live allowances was found.
- Use `migrateLiquidity`, `pause`, config changes, `upgradeImpl`/`upgradeGovernance` — all privileged (owner/governor/impl).

---

## 5. PoC / fork verification

Foundry project `poc/` (solc 0.8.24, via_ir, forge-std vendored). All tests run against a throwaway BSC fork (`vm.createSelectFork(BSC_RPC_URL)`); nothing is broadcast.

| Test | Purpose | Result |
|---|---|---|
| `test_00_state_sanity` | fork block, pairs, pause, balances | PASS (run 38361196543) |
| `test_01_gates_pair_swap_is_platform_only` | direct `pair.swap` reverts | PASS |
| `test_02_gates_mintReward_needs_productivity` | `NOTHING TO MINT` | PASS |
| `test_03_gates_pool_claim_needs_lp` | `NOTHING TO MINT` | PASS |
| `test_04_gates_governance_receiveReward_needs_allowance` | allowance-gated | PASS |
| `test_05_bluechip_roundtrip_loses_fees` | WBNB→BUSD→WBNB loses fees | PASS |
| `test_06_excess_dilution` | **live surplus capture: profit 11.14 USDT** | PASS |
| `test_07_drain_candidates` | top-12 mint candidates from fresh attacker: all closed | PASS |
| `test_08_mechanism_positive_control` | mock mintable token drains victim's WBNB side | PASS (run 3) |
| `test_09_lp_redeem_path_live` | fresh LP add+burn on WBNB/BUSD | PASS (run 3) |
| `test_10_stale_price_dump_live` | live PancakeSwap→BurgerSwap dumps | PASS (run 3) |

CI runs (public repo `kingmariano/ca-zombie-ci`):
- run 1 `38313990650` — enumeration OK; tests failed (missing `fs_permissions`, fixed).
- run 2 `38361196543` — enumeration + 8/9 tests PASS; `test_08` failed on the (then) missing gate-bypass; **this exposed a real measurement trap**: the Foundry default test address `0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496` holds 26.5 USDT on BSC, so an early "USDT drain" was the test contract spending its own tokens, not an extraction. All drain tests now use a fresh attacker address.
- run 3 `38366535667` — full suite + `pancake_arb.py` + fixed control/dump PoCs: **see `ci-log.txt` / run URL**.

Gas: surplus capture ≈ 1.4M gas (two platform calls + roll); dump tests ≈ 0.5–1.5M gas each; BSC gas < 1 gwei → < $0.10/tx.

---

## 6. Verdict & residual risk

- **E-U ≈ $16 net** (≈$38.6 gross before costs): $9.9 fork-proven surplus capture + $6.55 stale-price dump. Confidence **medium-high**: the surplus is exact and fork-proven; the dump figures are AMM-exact model outputs whose top cases are re-executed in CI (`test_10`); the free-mint drain is **$0 live** (296 tokens checked, mechanism proven).
- **H-O ≈ $133.0k** priced LP reserves (DefiLlama-consistent ≈ $190.8k) + $18.5 LP reward pools + $76.7 DGAS pending (90% LP) + $60.8 governance staking + $2.9 pool rewards.
- **P**: dev cut on DGAS pulls (10% ≈ $7.7 to `0xAAD9f762…`); owner/governor/impl powers (pause, migrate, config, token upgrade).
- **S**: 16.5 USDT stranded in DemaxGovernance (no transfer path); unknown share of BURGER token-contract balance (143,480 − 116,964 ≈ 26.5k BURGER ≈ $17) held for productivity addresses that no longer claim.
- **Blockers/frictions**: `swapPrecondition` gate (bypassable at ~0.2% of the pair's WBNB value); PancakeSwap liquidity for the stale side; LP private keys (much of the H-O value may be in lost wallets → effectively S); USDT/UNI surplus capture is capital-intensive (flash-loanable).
- **Latent risk (watchlist)**: the platform's stale-reserve pricing + absence of `skim()` means any future token with a public `mint`/inflation vector that gets paired with real value can be drained by an unprivileged attacker (mechanism proven). Also the BURGER token is upgradeable (impl `0x54a1Ca2…` proxy) — a compromised/rogue impl could mint/redirect.

## 7. Methodology, caveats, files

Method: verified deployed sources from BscScan (Etherscan V2, chainid 56); full 922-pair enumeration (reserves, balances, LP supply, DGAS adjustments, mint-selector bytecode scan) at an explicit block; DefiLlama pricing; PancakeSwap venue modelling for stale-price extraction; fork PoCs on GitHub Actions. Read-only; no keys, no transactions, no secrets in the folder.

Caveats: (1) 524 of 573 tokens are unpriced by DefiLlama → $132,993 is a **lower bound** (DefiLlama's $190,805 includes their internal pricing); (2) stale-dump net figures assume the gate bypass can be funded at model cost and PancakeSwap pairs are real (PoC re-executes the top ones); (3) some LP/reward claims may be unreachable in practice (lost keys) — classification stays H-O; (4) the exact value of `remainReward` accrued while no LP was staked is not separable (small).

Files: `analysis/sources/` (verified sources: factory, pair, platform, config, governance, pool, listener, token) · `analysis/config_distribution.json` (922/922 → one platform) · `analysis/local_top_pairs.json`, `analysis/token_probe.json`, `analysis/mint_scan.json` · `ci/enumerate.py`, `ci/pancake_arb.py`, `ci/run.sh` · `ci-out/{pairs,summary,candidates,stale_dump}.json` · `poc/` (Foundry, 11 tests) · `ci-artifacts/`.

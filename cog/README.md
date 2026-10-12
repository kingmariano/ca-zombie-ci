# Cog (Scroll) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Scroll (chain id 534352) · **Blocks:** on-chain reads at scroll `#35,349,539` (scan) / `#35,350,572` (CI recheck) / `#35,350,731` (fork PoC)
**Status:** read-only; PoC **fork-verified only**; no mainnet transactions, no keys, no changes to live state.

**Targets:** Cog Finance isolated lending markets — factory `0xbabd55549c266c6755b99173fe7604238d04117d` (f1, from block 85,518) and
factory `0xCd44fecb08bb28405992358131Fd5081A0F550D0` (f2, from block 3,147,376). 109 pairs, 98 unique oracle adapters,
9 tokens (WETH, USDC, USDT, wstETH, rETH, wrsETH, DAI, CRV, AAVE). Source: `github.com/CogFinance/Cog-Isolated-Lending`
@`4402cd5` (Vyper 0.3.10) + Sourcify-verified deployed `CogPair.vy` for f2.

---

## 1. TL;DR

| Surface | Live value | External unprivileged attacker? | Why |
|---|---|---|---|
| Pair `0x0C502351…` WETH/CRV (f1, **unpaused**) | $23.91 WETH borrowable | **YES — $17.10 net** | oracle still prices CRV at ≈$1.687 (stale feed); borrow capacity 3.51× collateral value; borrow-all-and-default |
| Pair `0xDeFeBD03…` rETH/USDC (f1, **unpaused**) | $5.23 rETH borrowable | **YES — $4.46 net** | oracle prices rETH at ≈$326 (9.1× under market); capacity 6.82× collateral |
| 13 paused pairs (incl. `0xA5832adC` = 56.12 WETH / $142k) | $189,241 | No | `deposit`/`mint`/`borrow` revert `"Pair Paused"`; `withdraw`/`redeem`/`repay`/`remove_collateral`/`liquidate` still work |
| Dust liquidations on paused `0xA5832adC` | gross $0.13 (12 positions, max $0.03) | Not net-positive | below gas; rate slightly stale (g=1.17) so dust positions at LTV>64% are liquidatable |
| Pairs with reverting oracles (`0xAA230793`, `0x8B606e4a`, `0x43187a60`, `0xBAF9cc20`, `0x8999a01f`) | $818 | No | `oracle.get()` reverts `"Stale Price Feed"`; `borrow`/`liquidate` revert on rate refresh; stored-rate-only paths (`remove_collateral`) remain |
| LP-side recoverable (8,865 addresses in the big pair alone) | **$189,410.52** | Holder-only (H-O) | LP `withdraw`/`redeem` work on paused pairs, first-come-first-served; claim lengths include bad debt |
| Unbacked LP claims (bad debt) | **$35,974.82** | Stuck (S) | assets were borrowed out; `0x20b3a538` (−$23.8k) and `0xd3b2affe` (−$9.4k) are unrecoverable unless borrowers repay |

### **Total live extractable by an external unprivileged attacker: $21.56 (USD, confidence: high)**

Sources: fork-verified `borrow-and-default` on two unpaused f1 pairs (`$17.10` + `$4.46`); dust liquidations
(`$0.13` gross) are **below gas and excluded**. The `$6.84`-sized `0xAA230793` opportunity identified from stored state
is **closed** because that pair's oracle has since begun reverting `"Stale Price Feed"` (fork-verified negative).

---

## 2. Architecture (deployed, re-verified)

Cog is a Vyper isolated-lending market (Kashi-style elastic/base rebase accounting, Curve-inspired):

- **CogPair** (`cog_pair.vy`): one market per (asset, collateral, oracle). Lenders deposit `asset` → get rebasing LP
  shares (`total_asset.elastic`/`.base`); borrowers `add_collateral` and `borrow`. Interest accrues per-second with a
  surge breaker → protocol-owned-liquidity fee switch. `pause()` gates `deposit`/`mint`/`borrow` **only**.
- **Factory** (`cog_factory.vy`): deployer of pairs from a blueprint; holds `priv_users` that can `pause`/`unpause`;
  owner may `update_borrow_fee`, `update_default_protocol_fee`, `change_fee_to`. 2-step ownership; no upgrades.
- **Oracles**: 98 adapters — Chainlink-style aggregator wrappers, LayerZero "xF33d" push feeds, PoolSharks/Bunni TWAP
  adapters, `fuse_box` aggregator. `CogPair._update_exchange_rate()` (`cog_pair.vy` L962) refreshes the stored
  `exchange_rate` from `IOracle(oracle).get()` on every `borrow`/`liquidate`/`get_exchange_rate()`.

**Deployed ≠ repo (important).** Sourcify-verified deployed source for f2 pair `0x63FdAFA5` shows
`COLLATERIZATION_RATE = 85000` (**85% LTV**) while the repo has `75000`; it also fixes the repo's
`liquidate()` credit line (`total_asset.elastic += borrow_amount`) and changes `repay(payment)`.
f1 pairs use the 75% constant (no verified source; **empirically probed** — see PoC `LtvProbe.t.sol`: borrowing at
`0.99×need(75%)`, `0.99×need(80%)`, `0.99×need(85%)` all revert while `1.02×need(75%)` succeeds ⇒ LTV ∈ [74.96%, 75.76%)).

### The live flaw mechanism (exact)

`_borrow()` refreshes the rate from the oracle, then solvency requires (deployed f1):
`collateral_share × 7.5e17 ≥ user_debt_elastic × exchange_rate` (`_is_solvent`, L1052).
`exchange_rate = 1e18 × (P_asset/P_collateral) × 10^(dec_c − dec_a)` — i.e. the *ratio the oracle reports*.
For both attack pairs the oracle still reports a long-stale ratio:

| Pair | asset/coll | oracle rate (live) | implied price | market | g = rate/rate_mkt | capacity = LTV/g |
|---|---|---|---|---|---|---|
| `0x0C502351…` | WETH/CRV | `1500348270781273398636` | CRV ≈ **$1.687** | CRV ≈ $0.3604 | 0.2136 | **3.51×** |
| `0xDeFeBD03…` | rETH/USDC | `326293683` | rETH ≈ **$326.29** | rETH $2,964.61 | 0.1100 | **6.82×** |

An attacker deposits collateral (valued *by the oracle*), borrows the pair's entire asset balance at that inflated
value, and never repays. The extracted value is LP principal → becomes bad debt.

---

## 3. Live-state assessment (every claim: address + block + call)

**Factories / roles** (block 35,349,539):

| Contract | owner() / fee_to() / pending | priv |
|---|---|---|
| f1 `0xbabd55549c266c6755b99173fe7604238d04117d` | `0x54a4c29196aad6fa77f9b4e35288e5234ac4f31a` (both), no pending | `pause`/`unpause` gated by `priv_users` (mutated by owner) |
| f2 `0xCd44fecb08bb28405992358131Fd5081A0F550D0` | `0x54a4c29196aad6fa77f9b4e35288e5234ac4f31a` (both), no pending | same |

**Pair census** (109 pairs read end-to-end, `ci-out/state_latest.json`):

- 13 **paused** pairs hold $189,241.61 of asset tokens (incl. `0xA5832adC` 56.1204 WETH = $142,080; `0x63FdAFA5`
  29,310.15 USDC; `0x4ac126e5` 5,031.62 USDT; `0x04bb9bca` 4,993.18 wstETH-equiv; `0xB31d07F7` 2,353.73 USDC; …).
- 96 **unpaused** pairs hold $168.91 of asset tokens; of those, only the two f1 pairs above have oracle-alive +
  exploitable stale rates.
- **Collateral** held across pairs: $5,969.36; **debt** (elastic): $38,167.32; **LP claims**: $225,385.97 nominal.
- Oracle health: 93 alive; **5 pairs' oracles now revert `Stale Price Feed`** (borrow/liquidate bricked):
  `0xAA230793` ($29.65 rETH), `0x8B606e4a` ($29.65 rETH), `0x43187a60` ($724.93 DAI), `0xBAF9cc20` ($31.84 wstETH),
  `0x8999a01f` ($20.13 collateral).
- Bad debt (LP claim − on-chain asset): `0x20b3a538` −$23,770; `0xd3b2affe` −$9,387; `0x63FdAFA5` −$1,146;
  `0x4ac126e5` −$784; `0xa5832adc` −$489; others small ⇒ **$35,974.82 unbacked**.
- The big WETH/USDC pair `0xA5832adC` has **0.2183 WETH of debt** ($553) backed by $2,469.72 USDC collateral of a
  single healthy borrower (LTV 22%) and **8,865 LP share holders** (top: `0xeeDa897D…` 48.9965e18 of 56.2839e18 shares = 87.05%).
- Protocol fee accrual (`fees_earned_fraction`, e.g. 0.1424 shares in the big pair) is mintable **only** to `fee_to`
  via the permissionless `roll_over_pol()` — value goes to the protocol, not to the caller.

**Token prices** (DefiLlama, 2026-10-12): WETH $2,531.70; wstETH $3,152.38; rETH $2,964.61 (GeckoTerminal: $3,014.79);
wrsETH $2,633.66; USDC ≈ $0.9997; USDT ≈ $0.9992; DAI $1.0002; CRV $0.3604 (Ethereum price; **no Scroll DEX market
listed for CRV** — bridged parity assumed); AAVE $163.20 (Ethereum; Scroll AAVE pairs are all oracle-dead/paused).

---

## 4. What an attacker can and cannot do

### CAN (E-U, fork-proven)

1. **`0x0C502351…` (WETH/CRV, f1, unpaused, oracle alive+stale)**
   - acquire 18.9027 CRV (cost $6.81 @ $0.3604; via canonical bridge — no Scroll DEX market),
   - `CRV.approve(pair, need)`; `pair.add_collateral(attacker, 18902721158209842520)`,
   - `pair.borrow(9444444444444444, attacker, attacker)` → receives the pair's **entire** WETH balance.
   - net **+$17.10** (gas on Scroll ≈ $0.01–0.05; borrow opening fee 0.05% already in the math; remaining CRV
     collateral stays locked and the debt becomes bad debt).
2. **`0xDeFeBD03…` (rETH/USDC, f1, unpaused)**
   - acquire 0.768135 USDC; approve; `add_collateral`; `borrow(1764705882352950, attacker, attacker)`.
   - net **+$4.46**.
3. (Gross, not net-positive) dust liquidations on paused `0xA5832adC`: 12 positions, total gross +$0.132,
   largest +$0.0286 — each is a separate tx, below gas.

### CANNOT (verified negative results)

- **Paused pairs**: `deposit`/`mint`/`borrow` revert `"Pair Paused"` (incl. the $142k WETH pair). `unpause` is
  factory-only + `priv_users` (`P`). Third-party `withdraw` of LP shares reverts `"Insufficient Allowance"`.
- **Oracle-dead pairs**: `borrow` … `liquidate` … revert `"Stale Price Feed"` (rate refresh is mandatory in both).
- **Broken-scale pairs** (rate ≈ 1e21–1e23, e.g. `0x8B606e4a`): even $100k collateral buys < 1e-10 rETH of capacity
  (mathematically dead); their oracles also revert.
- **No share-inflation / donation attack**: direct token donations don't enter `total_asset.elastic`; the ≥1000-share
  floor reverts tiny first deposits without taking funds.
- **No reentrancy prize**: state is written before external transfers; token set is fixed at pair creation.
- **No free `roll_over_pol()`**: mints fee shares to `fee_to` only.

---

## 5. PoC / fork verification

Foundry project `poc/` (solc 0.8.24, via_ir), fork of Scroll mainnet via keyless public RPC
(`SCROLL_FORK_RPC`, default `https://rpc.scroll.io`), **fork-only, read-only** (no broadcasts).

- `poc/test/CogZombie.t.sol` — 6 tests, **6/6 PASS** (local run at fork block 35,350,731, and CI run below):

| Test | Result | Key numbers |
|---|---|---|
| `test_A_borrowAndDefault_WETH_CRV` | PASS | borrowed 0.009444444444444444 WETH ($23.91); cost 18.9027 CRV ($6.81); **net +$17.10** |
| `test_A_borrowAndDefault_RETH_USDC` | PASS | borrowed 0.001764705882352950 rETH ($5.23); cost 0.768135 USDC; **net +$4.46** |
| `test_A_deadOracleBlocksBorrow` | PASS (negative) | `get_exchange_rate()` reverts; borrow reverts; 0.01 rETH unreachable |
| `test_B_liquidations` | PASS | f2 user reverts `"CogPair: User is solvent"` (85% LTV); f1 dust liq pays 36,640,619,499,636 wei WETH (~$0.093), receives 0.121568 USDC (gross +$0.03) |
| `test_C_pausedPairBlocksUnprivilegedDepositAndBorrow` | PASS (negative) | 56.120437851985516050 WETH still custodied; deposit/borrow revert; victim-withdraw reverts |
| `test_D_brokenPairHasNoBorrowCapacity` | PASS (negative) | rate 1.71076927e21; $100k collateral ⇒ 43,839,927 wei capacity (4.4e-11 rETH) |

- `poc/test/LtvProbe.t.sol` — 2 tests, **2/2 PASS**: empirical LTV probe (f1 = 75%, rules out 80%/85%; positive
  control passes), resolving the repo-vs-deployed LTV discrepancy.
- CI (GitHub Actions): **run [`38295962803`](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38295962803) — 8/8 tests PASS** (plus early failed compile-only run `38292594537`);
  artifacts in `ci-artifacts/`; `ci-out/live_recheck.json` re-reads all live numbers from the CI runner.

Gas: each attack path is 2–3 txs (approve+add_collateral+borrow, or bundled via a helper), ~640k gas total →
≈ $0.01–0.05 on Scroll. No flash loan required (working capital $6.81 / $0.77); flash loans would only reduce capital.

---

## 6. Verdict & residual risk

- **E-U now: $21.56** (confidence **high**: fork-proven twice, independent of CI; all gating values read live).
- **H-O now: $189,410.52** LP redeemable FCFS + **$5,873.15** collateral removable by solvent/no-debt owners.
  Anyone holding LP shares can withdraw against the pairs' real balances; first movers win — remaining LP claims
  include $35,974.82 of bad debt that cannot be realized.
- **S: $35,974.82** unbacked LP claims + **$96.20** collateral locked behind insolvency + borrow/liquidate paths
  bricked wherever the oracle reverts.
- **P**: owner `0x54a4c291…` can unpause pairs (opening a fresh $142k+ borrow surface against stale oracles if the
  team ever unpauses without updating feeds) and redirect fees.
- **Latent risk (what would change the verdict upward)**: (a) any oracle price update would *close* the two paths;
  (b) any *pause lift* on the 13 paused pairs while their oracles stay stale would re-open borrow-and-default on
  up to $189k (e.g. `0xA5832adC`'s rate is already 17% stale → capacity 0.75/1.17 < 1 → currently unprofitable even
  unpaused, but `0x63FdAFA5`/`0x4ac126e5`/`0x43187a60` would need re-measuring); (c) oracle feeds resuming could
  change g on all alive pairs — the campaign should re-run `analysis/econ_analysis2.py` to re-check.

**Blockers/limits of the attacker view**: extracting the two paths requires holding CRV/USDC — trivial amounts;
Scroll gas is negligible. The $142k WETH is gated behind the pause (P) and the LP claims are holder-only (H-O),
so it is *not* attacker-extractable today.

---

## 7. Methodology & sources

1. Defined the target set from DefiLlama's `cog-finance` adapter (both factories, all `*PairCreated` events) — 109 pairs.
2. Read every pair's live state (`analysis/state_scan.py`, Multicall3-batched positions `analysis/positions_scan3.py`),
   decoded all 98 oracles (`analysis/oracle_decode.py`), enumerated 3,642 live borrower positions across 14,511
   distinct addresses and 8,865+ LP holders.
3. Verified deployed source vs repo: found f2 `COLLATERIZATION_RATE=85000` via Sourcify; probed f1 LTV empirically on
   a fork (`poc/test/LtvProbe.t.sol`).
4. Computed per-pair economics with the deployed formulas and oracle-liveness gate (`analysis/econ_analysis2.py`) —
   results in `ci-out/econ_summary.json`.
5. Fork-proved the surviving paths and all material negatives (`poc/test/CogZombie.t.sol`) on CI.
6. Repo pinned: CogFinance/Cog-Isolated-Lending @ `4402cd55cec2373ec463b79ddf5f621c62d298fe` (2023-12-29);
   snapshot in `analysis/cog-src-snapshot/`.

**Caveats**: USD values use DefiLlama prices at 2026-10-12 with CRV priced off Ethereum parity (Scroll CRV has no
listed DEX market); illiquid tokens (AAVE/CRV on Scroll) may realize less. All state is as of the recorded blocks;
re-run the scripts to refresh. No mainnet transactions were ever sent. Oracle count/health can change silently.

**Files index**: `summary.json` (machine summary) · `analysis/` (scanners + econ analysis + repo snapshot) ·
`poc/` (Foundry project, 8 passing tests) · `ci/run.sh` (Scroll RPC probe + live recheck for CI) ·
`ci-out/` (state, oracles, positions, LP holders, econ summary, live recheck from CI) · `ci-log.txt`, `ci-artifacts/`.

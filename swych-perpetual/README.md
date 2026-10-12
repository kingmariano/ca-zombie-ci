# Swych Perpetual (BSC) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** BSC (chain id 56) · **Status:** read-only; PoC fork-verified only; no mainnet transactions.
**Target (triage):** Swych Perpetual — BSC pool `0xF86f70fb4959a9FCF1e7dD67A05dC0AC95c3802d`; triage live $182,959 (block 126,994,409).
**Re-verified live:** block **127,267,326** — pool custody **$182,863.81** (USDT 65,233.02 + WBNB 37.1509 + WETH 20.8424 + SOL 255.1747 + BTCB 0.12610).

---

## 1. TL;DR

| Target | Live extractable (external unprivileged) | Why closed/open | Latent risk |
|---|---:|---|---|
| Pool `0xF86f…802d` (custody $182.9k) | **$0** | every mutative path is gated: `isLiquidityProvider` (LP/swap), `onlyOrderManager` (positions), `feeDistributor` (fees/surplus), `authorizedLiquidators` (liquidation), `onlyOwner` = Gnosis Safe 5-of-7 (admin/upgrade) | low; oracle/fee routing depend on Chainlink + a single reporter-owner EOA |
| OrderManager `0x092D…2DCe` | **$0** | `executeOrder` is `onlyExecutor` = PriceReporter `0x1CB9…0dC5`; the PriceReporter exposes **no** unprivileged function (dispatcher-verified); only 3 whitelisted reporter EOAs can post prices/execute | medium only if a reporter key returns or is compromised (privileged) |
| PriceReporter `0x1CB9…0dC5` (+ sibling `0x161B…143d`) | **$0** | `postPriceAndExecuteOrders` / `executeSwapOrders` / `checkForExecutableOrders(0x93a91e33)` all `require(isReporter[msg.sender])`; `executeOrder`/`executeSwapOrder`/`postPrices` are *not even exposed* (call-constants only) | PR1 owner is a single EOA (can add reporters); PR2 owner = Safe — privileged |
| FeeDistributor `0x7c57…D6b1` + `0x9baE…d3F5` | **$0** to attacker | `withdrawFee()`/`distribute()` are permissionless **triggers**, but 100% of the output goes to fixed storage recipients (protocol addresses, owner = Safe) — fork-proved attacker delta = 0 | $30.0k fee reserves move Pool→FD→recipient only when poked; recipient contract could brick (S-latent) |
| LP token `0x03F9…b28A` ("Tranche One") | **$0** (H-O: $153.97k) | 100% of supply (95,914.52 TR1) is held by **one whitelisted EOA** `0x9A6A…a59a`; only that EOA can `removeLiquidity` | key loss would strand the LP value; EOA identity not verifiable on-chain |

## 2. Total live extractable by an external unprivileged attacker

**$0 (zero) — confidence: high.**

Supporting decomposition of the $182.9k:

| Category | USD (2026-10-12) | Who can move it |
|---|---:|---|
| **H-O** — LP redemption value + pending-order execution fees | **$153,972.72** (LP $153,922.50 fork-measured at block 127,273,590; range $152.8k–$153.9k across blocks; + 8×0.0025 ETH escrowed fees ≈ $50) | only `0x9A6A5Aed7e4F4454AA89517AFdbBaE9EAD0FA59a` (holder of 100% of TR1, whitelisted) / the 8 order owners (cancel) |
| **P** — booked fee reserves | **$30,037.05** | only via FeeDistributor chain (recipients fixed by Safe-owned contracts) |
| **E-U** | **$0** | no unprivileged path pays out |
| **S** | $0 (pool custody) | — |

## 3. Architecture & mechanism (what this protocol is)

Swych Perpetual is a **GMX/Level-Finance-style perp DEX on BSC** ("Swych Finance" perps product; code lineage: RWAX fork of Level Finance v1 — LPToken author string "RwaxFinance", `Pool`/`OrderManager`/`PriceOracle`/`PoolHook`/`FeeDistributor` layout, `version()="1.0.1"`). Core:

- **Pool (proxy)** `0xF86f…802d` → impl `0x81026C573A618B104E2a511e1AEF2854524AA196` (verified, `contract Pool`, solc 0.8.15). Holds all trader collateral + LP assets. 5 assets: BTCB, WBNB, USDT, WETH, SOL. Single tranche (`allTranches` empty; `trancheAssets[lpToken]` used).
- **OrderManager (proxy)** `0x092D…2DCe` → impl `0xC8bA…7e10`. `placeOrder` is permissionless (self-funded), but **`executeOrder` is `onlyExecutor`** — the executor is the PriceReporter contract.
- **PriceReporter PR1** `0x1CB9…0dC5` (unverified, 4,647 B; the OrderManager's executor). Posts prices to the oracle and executes orders, **reporter-gated**. Owner = EOA `0x9958e5A78F53e58233fB175f1A6F45F22d3d4C48`; reporters = `0x2E7B39eF…`, `0x75cE0c34…`, `0x6f369f5d…` (all EOAs). Sibling **PR2** `0x161B…143d` (4,102 B, **owner = the Gnosis Safe**) exposes the same 11-selector table (independently re-derived; not byte-identical).
- **PriceOracle** `0xe446…6BF5` (verified). Reporter-posted prices guarded by **Chainlink** bounds (deviation + timeout). Reporter prices last posted **2025-01-01** (ts 1,735,760,442); since then prices fall back to Chainlink reference ±1% (live for all 5 assets). No unprivileged `postPrices` (revert `PriceFeed:unauthorized`).
- **FeeDistributor #1** `0x7c57…D6b1` (unverified, decompiled) and **#2** `0x9baE…d3F5` (recipient; contract, owner = Safe). Permissionless `withdrawFee()`/`distribute()` move pool fee reserves along a fixed recipient graph.
- **PoolHook** `0x91d0…0c06` (owner = Safe) — reward hook (post* callbacks `onlyPool`); holds $0 of all pool assets.
- **LP token** `0x03F9…b28A` "Tranche One" (TR1); minter = Pool only; 95,914.52 supply, **100% held by EOA `0x9A6A…a59a`**, which is the only address verified `isLiquidityProvider == true`.
- **Owner/upgrade authority:** Gnosis Safe 1.3.0 `0x719A…2e50`, **threshold 5 of 7** (owners incl. `0x51CeD530…`, `0x1eE25525…`, `0xC227DF6b…`, `0x573b93ea…`, `0x3fcCEA2a…`, `0x78A53c9b…`, `0x6d3f984e…`). ProxyAdmin `0x1078…c35a` owner = same Safe.

## 4. Live-state assessment (block 127,267,326, 2026-10-12)

Balances of the Pool (exact `balanceOf` reads):

| Token | Amount | USD |
|---|---:|---:|
| USDT | 65,233.020593781079845094 | $65,180.25 |
| WBNB | 37.150871497710826464 | $27,555.26 |
| WETH | 20.842379618035697515 | $52,332.83 |
| SOL (Binance-Peg) | 255.174744469221813216 | $27,386.73 |
| BTCB | 0.126101726965759641 | $10,408.74 |
| **Total** | | **$182,863.81** |

- Booked fee reserves (withdrawable only via FeeDistributor): BTCB 0.117772 ($9,721), WBNB 15.1596 ($11,244), USDT 7,439.73 ($7,434), WETH 0.61194 ($1,537), SOL 0.94673 ($102) = **$30,037.05**.
- Pool value via oracle: max $154,831.91 / min $151,766.47 / mid **$153,299.19**; TR1 supply 95,914.523 → LP ≈ **$1.5983/TR1**.
- Roles: `owner()` = Safe (5/7); `orderManager()` = OM; `oracle()` = PriceOracle; `poolHook()` = 0x91d0; `feeDistributor()` = FD1; `maxLiquidationGasPrice()` = **0** (liquidation requires `authorizedLiquidators[msg.sender]`); `maxLeverage` = 100; fees: positionFee 0.1%, liquidationFee $5, swap 0.25% (+tax), daoFee 50%.
- Activity: protocol last interacted with in 2023-12…2025-01; keepers stopped 2024-03-01; oracle posts stopped 2025-01-01. **Dormant.**
- Pending orders (full 4,316-id CI scan): exactly **8** pending limit DECREASE orders (ids 429, 3073, 3198, 3233, 3394, 3423, 3633, 4071) — **every one of the 8 owners currently has a zero-size position**, so executing any of them reverts/no-ops and **no execution fee is claimable**; each order escrows only its 0.0025 ETH execution fee (owner-cancellable → H-O, ≈$50 total); `nextSwapOrderId = 1` → zero swap orders.
- Open positions: two longs remain per `trancheAssets` (`guaranteedValue` BTCB ≈ $23.7k, SOL ≈ $3.4k). Owners not enumerated (CI RPC lacks `eth_getLogs`; public RPCs cap/block wide ranges — see `analysis/ci-results.md` §E); irrelevant to E-U because no unprivileged path can touch positions.

## 5. What an attacker can/cannot do (exact paths)

Verified reverts (fork, see §6): `pool.addLiquidity/removeLiquidity/swap` → `NOT_AUTHORIZED`; `pool.increasePosition/decreasePosition` → `OrderManagerOnly`; `pool.withdrawFee/distributeSurplus` → `FeeDistributorOnly`; `pool.liquidatePosition` (1 gwei) → `Gas price too high`; `oracle.postPrices` → `PriceFeed:unauthorized`; `oracle.addReporter` → `Ownable`; `om.executeOrder` → `OrderManager:onlyExecutor`; `om.cancelOrder(429)` → `unauthorizedCancellation`; `PR.postPriceAndExecuteOrders` → `PriceReporter:unauthorized`; `PR.executeOrder/executeSwapOrder/postPrices` → fallback revert (selector not exposed); `PR.addReporter` → `Ownable`.

Permissionless functions that do exist and their (non-)payout:
1. `om.placeOrder` — attacker can escrow their own collateral + ≥0.0025 ETH fee, but **no execution is possible** (executor is reporter-gated), so it is a self-funding lockup; `cancelOrder` refunds only the order owner. No profit.
2. `pool.refreshVirtualPoolValue` — recomputes a cached number; no transfers.
3. `FD1.withdrawFee()` / `FD1.distribute()` — permissionless triggers, but **payouts are hard-coded to the recipients stored in FD storage** (FD1 slots 8/9/10 = `0x9baE…d3F5`; weights 50/35/10/5). Fork-measured: `FD1.withdrawFee()` moved the full WETH fee reserve (0.611937748191841578) Pool → recipient `0x9baE…d3F5`; **attacker deltas = 0** (WETH/WBNB/ETH). FD2 (`0x9baE…d3F5`, owner = Safe) has **no recipients configured** (`getRecipients()` = (0,[])) and all its setters are `onlyOwner` — fees dead-end at a Safe-controlled contract. This is a public "poke", not a drain.
4. `liquidatePosition` — requires `tx.gasprice <= 0` **or** `authorizedLiquidators[msg.sender]`; `maxLiquidationGasPrice` is 0 today. `tx.gasprice == 0` is constructible in principle (eth_call defaults to 0) but not practically includable on BSC (validator min-gas-price policy); even then the caller could collect only the flat $5 liquidation fee per liquidatable position (theoretical residual ≤ ~$10, see §7). Effectively closed.

Costs for the (nonexistent) profitable paths: n/a; the only reachable state-changing calls cost gas and pay nothing.

## 6. PoC / fork verification

- Project: `poc/` (Foundry, fork of BSC mainnet via `BSC_RPC_URL`, fallback `https://bsc-rpc.publicnode.com`). Tests in `poc/test/SwychFork.t.sol`; heavy scans in `ci/scan.py` (order scan, position-event scan, state snapshot).
- CI: `bash ci/ci-run.sh swych-perpetual` → GitHub Actions on `kingmariano/ca-zombie-ci` (public), branch `swych-perpetual`.
  - Final run (6/6 passed): **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38305216964** — fork block 127,273,590; log `ci-log.txt`; artifacts `ci-artifacts/result-swych-perpetual/ci-out/` (copied to `ci-out/`: `state_snapshot.json`, `pending_orders.json`, `position_events.json`, `open_positions.json`, `scan-console.log`).
  - First run (same 6/6): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38303057285.
- **Independent verification (child session, full report `analysis/verify-child/VERIFY.md`)**: all three headline claims re-derived from chain and **CONFIRMED** (dispatcher table of both PriceReporters; `executeOrder`/`executeSwapOrder`/`postPrices` empty-data reverts even for the owner and whitelisted reporters; `om.executor()==PR1` probed both directions; all 8 orders' position keys chain-cross-checked to zero; TR1 balance == totalSupply == 95,914.5229 with `isLiquidityProvider` true/false). Falsification sweep over Pool, OM, Oracle, FD1/FD2, LP token, PoolHook and the SwychLY rewards token (`0xd6624102503252Cb06C1fBb4d3b1AA6eE9A072ca`; `startNewEpoch()` permissionless but caller payout 0) found **no unprivileged payout**. Corrections applied to this report: PR2 not byte-identical (4,102 B, Safe-owned); `0x93a91e33` = `checkForExecutableOrders`; 0-gasprice `liquidatePosition` residual (≤$5/position, practically un-includable).
- Key fork-measured numbers:
  - All attacker gate probes revert (see `analysis/ci-results.md` §A for the exact revert strings).
  - `FD1.withdrawFee()` from attacker succeeds but pays only the stored recipient: recipient `0x9baE…d3F5` WETH **+0.611937748191841578**, **attacker delta 0**; `FD1.distribute()` attacker ETH delta 0.
  - LP holder EOA `0x9A6A…a59a` removed 10% of TR1 → received **15,411.448 USDT**; implied full-LP redeemable **$153,922.50** (fork block).
  - Full order scan: **8 pending orders, all owners positionless** (no claimable execution fees); 0 pending swap orders.

## 7. Verdict & residual risk

- **E-U now: $0 (high confidence).** Every value-moving path requires owner (Safe 5/7), the whitelisted LP EOA, the fee-distributor recipient graph, an authorized liquidator, or the reporter-gated PriceReporter. The single largest holder-claim ($153.9k) is redeemable only by the whitelisted LP EOA (H-O).
- **Residual/latent:** (a) PriceReporter owner is a single EOA `0x9958…4C48` — it can add reporters (privileged path; key compromise would let an attacker post Chainlink-bounded prices and execute orders, extracting at most small price-bounded amounts through the pool's risk engine); (b) fee-reserve triggers are permissionless — if FD recipients are bricked, funds could become stuck at the recipient (S-latent); (c) the oracle's reporter prices are stale (>1 year) so all pricing depends on Chainlink feeds (DoS if a feed breaks); (d) theoretical residual: a `tx.gasprice == 0` transaction could pass the liquidation auth gate and collect the flat $5 liquidation fee per liquidatable position (≤ ~$10) — not practically includable on BSC; does not change the $0 verdict.
- **Blockers:** none of the attacker paths is blocked by blacklists; they are blocked by access control (and by the protocol being dormant).

## 8. Methodology & sources

On-chain reads (`cast`, raw `eth_call`) at explicit blocks; Etherscan V2 (BSC) for verified sources/ABIs (Pool, OrderManager, PriceOracle, ProxyAdmin); GoldRush for tx history; heimdall-rs decompilation of unverified contracts (PriceReporter, FeeDistributor, recipient); bytecode dispatcher analysis; Foundry fork PoC on CI; source-lineage from `dhiraj0911/trading-contract` + Level Finance v1/v2 + Sypher forks (cross-checked against deployed selectors).

**Caveats:** the LP-holder EOA's identity (team vs external) is not verifiable on-chain — classified H-O strictly by holding/whitelist status; USD values use DefiLlama 2026-10-12 spot (oracle-side pricing is Chainlink ±1%); all 8 pending orders' owners hold no positions today, so no fee is claimable by executing them; open-position owners were not enumerable (log-index limitations, see `analysis/ci-results.md` §E).

## 9. Files

- `README.md` (this file) · `summary.json` (machine-readable)
- `analysis/live-state.json` — block-pinned state, roles, gates, USD table
- `analysis/pricing.json` — per-token USD computation
- `analysis/pricereporter-dispatcher.md` — dispatcher proof that no unprivileged entry exists on the executor
- `analysis/ci-results.md` — CI run results (gates, FD routing, LP exit, order scan)
- `analysis/verify-child/` — independent verification: full `VERIFY.md` (all claims CONFIRMED + corrections), `raw/` evidence index, `ref-parent/` snapshot
- `analysis/raw/` — raw probes
- `poc/` — Foundry fork tests (`test/SwychFork.t.sol`)
- `ci/scan.py`, `ci/run.sh` — CI heavy scans; `ci-out/` — CI artifacts; `ci-log.txt` — CI log

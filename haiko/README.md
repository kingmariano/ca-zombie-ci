# C2-49 — Haiko (Starknet): live cross-market `collect_order` drain + $53.5k holder-recoverable vault

**Date:** 2026-10-10 · **Chain:** Starknet mainnet (chain id `SN_MAIN`) · **Status:** read-only research; no transactions signed or sent; all proofs are `starknet_call` / `starknet_simulateTransactions` (query version 3 + `SKIP_VALIDATE`) and historical trace replays at explicit blocks.

**Finding (wave-1):** Haiko — $62.7k (strategy 14.53 ETH + 17,298 USDC; manager 97.8k STRK); sunset; "44 unnamed externals".

**Result:** the wave-1 balances were accurate at read time, but **92.9k STRK left the MarketManager on 2026-10-06** (4 days after wave-1) via a live MarketManager flaw: **`collect_order(market_id, order_id)` pays out in the *passed* market's tokens without validating that the order belongs to that market.** The same flaw drained the strategy's wstETH backing on 2026-03-29. The MarketManager class hash is unchanged across both drains and today (`0x337f32bd…`), so the path remains callable. Remaining unprivileged extraction is bounded by MarketManager's residual balances: **≈$348.54** (4,911.40 STRK). Separately, the ETH/USDC strategy vault still pays its shareholders pro-rata — **≈$53.5k holder-recoverable** — while the position-backed markets are bricked (unbacked positions).

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|
| MarketManager `0x38925b0b…` (4,911.40 STRK ≈ **$348.54**) | **E-U ≈ $348.54** (upper bound; net of order-collateral cost) | **Open** — cross-market `collect_order` pays the caller in the passed market's tokens; class hash unchanged since 2024 and used for payouts on 2026-03-29 (1.959 wstETH) and 2026-10-06 (92,936.06 STRK) | If anyone re-funds MM, the same path drains the new balance |
| ReplicatingStrategy M1 (ETH/USDC): 14.5296 ETH + 17,297.74 USDC ≈ **$53,513.81** | **H-O** (shareholder-only, proven by simulation) | **Open to holders** — `withdraw` pays pro-rata from the strategy wallet; admin paths gated | First-come pro-rata; 0.5% withdraw fee |
| ReplicatingSolver (V2): 9,870.09 STRK + 0.00693 ETH + 0.538 USDC + 0.01539 WBTC ≈ **$1,989.68** | **H-O** (vault-token holders, proven by simulation) | **Open to holders**, but under-backed (virtual reserves ≈ $6.2k vs $2.0k wallet) → first-come depletion | Late withdrawers unpaid (S) |
| ReplicatingStrategy M2–M6 positions (recorded claims ≈ **$60,212.58**) | **S** (stuck) | Positions unbacked: MM holds 284,444,837 wei wstETH, 3 raw USDC, 4 raw USDT, 0 WBTC. M2 `withdraw` simulation reverts `ModifyPosBaseReserves` | None for an attacker; loss for holders |
| Admin surface (owner multisig `0x43777a54…`) | **P** ($0) | `OnlyOwner` / `OnlyStrategyOwner` / `OnlyMarketManager` on every state-changing admin fn (caller-0 probes) | Owner key compromise = MM sweep + vault admin |
| Strategy wallet dust (4.254 STRK + 2.92 USDT + 0.000648 wstETH ≈ $5.23); Distributor 0.001 ETH ($2.49) | **S** | Withdraw paths revert on position collection; distributor roots unknown | — |

## 2. Total live extractable now

- **E-U (external unprivileged): $348.54** (upper bound — MarketManager's remaining 4,911.398717456573909641 STRK; pattern proven live on 2026-10-06; net of creating an order could be lower). Confidence: **medium-high** on the mechanism, **medium** on the exact net.
- **H-O: $55,503.49** (M1 vault $53,513.81 + Solver vault $1,989.68; both proven withdrawable by simulation).
- **P: $0** unprivileged (all admin gated).
- **S: $60,220.31** (M2–M6 unpayable recorded claims $60,212.58 + strategy dust $5.23 + Distributor $2.49). Plus ≈$4.2k of Solver virtual reserves that the wallet cannot cover (first-come depletion, counted qualitatively).
- Prices 2026-10-10 (CoinGecko/DefiLlama): ETH $2,492.93 · STRK $0.070966 · USDC $0.999692 · USDT $0.999161 · wstETH $3,106.22 · WBTC $82,624.

## 3. The bug / mechanism (exact terms)

Haiko's `MarketManager` (a singleton AMM, ERC-721 position manager) stores orders globally. `collect_order(market_id, order_id)`:
1. reads the order by `order_id`,
2. computes the payout using the **passed `market_id`'s** base/quote tokens and price context,
3. transfers the payout to the **caller**.

There is no check that `order.market_id == market_id`. An unprivileged caller can therefore create a cheap order on one market and collect it under a **different, valuable market**, receiving that market's token out of MarketManager's pooled balances. Evidence (historical traces, exact calls):

- **2026-03-29** (block 8,252,395, tx `0x294992a8…`): order created on market `0x52b74512…` (F1-token pair) → `collect_order(0x5f6edcd8… [wstETH/F1], <order>)` → MarketManager paid **1.959030093873659156 wstETH** (its entire wstETH reserves minus 284,444,837 wei) to `0x334b7e06…` → forwarded to `0x435ae912…`. This is the strategy's wstETH/ETH position backing (recorded claim 1.9467 wstETH) — now unbacked.
- **2026-10-06** (blocks 15,980,923 → 15,980,930, txs `0x63f5e591…` → `0x7718f335…`): order created on market `0x3c39aafa…` (base `0x2ef55818…`) → `collect_order(0x5959b98f… [STRK/0x7491d0c9], <order>)` → MarketManager paid **92,936.06 STRK** (its entire STRK reserves minus 4,911.40) to `0x381d0d27…`.
- MarketManager class hash at the March drain, the October drain and today is identical: `0x337f32bd5fccef2b67d2c620a8d31abccd5960c37f0c0b58d5e5327fac7e6b7` (verified at blocks 8,252,395 / 15,980,930 / 16,170,720). The code path is live; only the balance limits the extraction.

The wave-1 "manager 97.8k STRK" was correct when read; 92.9k of it was taken on 2026-10-06, after the wave-1 measurement.

### Historical context — audit findings (Trail of Bits, Feb 2024, `haiko-xyz/audits`)
The audited pre-deployment code had TOB-SPH-1 (collect_order caller not validated → order theft), TOB-SPH-2 (flash-loan reentrancy), TOB-SPH-6 (`amounts_inside_position` arg validation), TOB-SPH-19/20 (deposit overwrite / partial-withdraw share zeroing). The deployed contracts were upgraded twice (strategy: blocks ~531,900 → ~600k → 700k; MM: ~600k → 700k) and the current classes handle share accounting correctly for the top holders we checked (M1: on-chain `user_deposits` == deposits − withdrawals for the largest holders, including multi-deposit accounts). The cross-market `collect_order` behavior is **not** covered by the audit and is present in the deployed class.

## 4. Live-state assessment (blocks cited)

All reads via keyless public Starknet RPC (publicnode/onfinality), cross-checked on Infura.

| Item | Value | Block |
|---|---|---|
| ReplicatingStrategy `0x2ffce9d4…` class | `0x7fe6c3f1…` (unchanged since ~700k) | 16,150,223 / 16,170,720 |
| — balances | 14.529646992026151633 ETH · 17,297.743432 USDC · 4.254437 STRK · 2.921509 USDT · 0.000648 wstETH | 16,150,223 |
| MarketManager `0x38925b0b…` class | `0x337f32bd…` (unchanged since ~700k) | 8,252,395 / 15,980,930 / 16,170,720 |
| — balances | 4,911.398717456573909641 STRK · 1.76e-9 ETH · 284,444,837 wei wstETH · 3 raw USDC · 4 raw USDT · 0 WBTC | 16,150,223 |
| ReplicatingSolver `0x073cc79b…` balances | 9,870.090695 STRK · 0.006932 ETH · 0.538068 USDC · 0.015388 WBTC | 16,150,223 |
| Owner (strategy + MM + solver) | `0x43777a54d5e36179709060698118f1f6f5553ca1918d1004b07640dfc425000` (contract, class `0x6e150953…`, nonce 0x182; signers/threshold not exercised) | 16,170,720 |
| Oracle | Pragma `0x2a85bd61…`; summary `0x54563a05…` | 16,150,223 |
| Strategy markets (6) | M1 ETH/USDC (paused), M2 wstETH/ETH, M3 USDC/USDT, M4 STRK/USDC, M5 STRK/ETH, M6 ETH/WBTC | — |
| M1 total_deposits / get_balances | 12,344,124,832,367,179 shares / (14.5296 ETH, 17,297.74 USDC) — pays from wallet | 16,169,599 |
| M2 recorded claim | 1.9467 wstETH + 0.000101 ETH (MM holds dust) | 16,150,223 |

**Historical balance trail (MM):** wstETH 2.1069 (block 6M) → 1.9590 (8,252,394) → dust (8,252,395); USDC 28,710 (6M) → 3 raw; ETH 11.25 (6M) → dust; STRK 97,847.97 (block 15,000,000) → 4,911.40 (15,980,930).

## 5. What an attacker can / cannot do

**Can (E-U):** call `create_order` on a low-value market, then `collect_order` under a valuable market (e.g. `0x5959b98f…` STRK pair) and receive the target market's token from MM's pooled balance. Preconditions: pay the order's collateral (attacker-chosen, can be cheap) and gas. Payout bounded by MM's balance → **≤ $348.54 today**.
**Cannot:** reach the strategy's M1 wallet (14.53 ETH + 17,297 USDC — different contract, only `withdraw` by shareholders); mint vault shares for free (`deposit` is pro-rata, requires tokens; paused on M1); withdraw others' shares (`InsuffShares`); call any admin fn (`OnlyOwner`/`OnlyStrategyOwner`/`OnlyMarketManager` — probe results below); sweep MM (`OnlyOwner`); drain the Solver contract (separate custody; MM bug does not touch it).

**Gate probes (caller = 0, block 16,153,020):** `pause`, `unpause`, `collect_and_pause`, `trigger_update_positions`, `set_params`, `transfer_strategy_owner` → `OnlyStrategyOwner`; `set_whitelist`, `set_withdraw_fee`, `change_oracle`, `transfer_owner`, `upgrade`, `collect_withdraw_fees`, `add_market` → `OnlyOwner`; `update_positions` → `OnlyMarketManager`; `withdraw` → `InsuffShares`; MM `sweep`/`whitelist_markets`/`set_flash_loan_fee_rate`/`transfer_owner`/`upgrade` → `OnlyOwner`. (`accept_owner`/`accept_strategy_owner` execute only when caller == queued owner; queued = 0x0, unreachable by a real account.)

**Simulations (query v3 + SKIP_VALIDATE):**
- **M1 withdraw (H-O proven)** — user `0x170499c0…` (1,131,787,790,826,304 shares of 12,344,124,832,367,179): `EXECUTION OK`; Withdraw event gross 1.3346748303865894 ETH + 1,585.621161 USDC, net transfers **1.3280014562346565 ETH + 1,577.693055 USDC** (0.5% fee) to the user (block 16,169,599).
- **M2 withdraw (S proven)** — user `0x4304a18f…` (653,427,347,566,037,304 shares): **REVERT `ModifyPosBaseReserves`** from MarketManager while collecting the unbacked position (block 16,169,723).
- **Solver withdraw (H-O proven)** — vault-token holder `0x7fe401f6…`, 1e18 STRK/ETH shares: `EXECUTION OK`; burned 1e18 shares, received 3.1398383702667516 STRK + 0.000388328140879945 ETH principal **plus** 6.193833504085256 STRK + 0.0001660319836171 ETH accrued fees (block ~16,170,700).

**Flash-loan leg (TOB-SPH-2):** not proven live and bounded by MM's balance (≤$348.54) even if live; no receiver contract was deployed (out of scope of read-only work). Documented as residual, not claimed.

## 6. The "44 unnamed externals"

The exact wave-1 artifact could not be reproduced from the corpus (no wave-1 Starknet report exists in the repo; the session referenced in the tracker is not readable). Exhaustive enumeration instead:
- Strategy external entry points: **50** (21 state-changing; all named in the class ABI; every state-changing fn gated as above).
- Strategy's external call targets: MarketManager, Pragma oracle `0x2a85bd61…`, Pragma summary `0x54563a05…`, and 6 ERC-20s (ETH, USDC, USDT, STRK, wstETH, WBTC). None is callable by an outsider to redirect strategy funds or mint claims.
- MM markets ever created: ~31 `CreateMarket` events (scan may undercount slightly); strategy markets: 6.
- Depositors (unique): M1 5,590 · M2 123 · M4 927 (M3/M5/M6 not fully scanned).
None of these counts is 44; the only live unprivileged surface found is the MM cross-market `collect_order` above.

## 7. PoC / verification (CI)

- Repo: `github.com/kingmariano/ca-zombie-ci`, branch `haiko`, workflow `poc.yml` → `haiko/ci/run.sh`.
- CI jobs (keyless public RPC, read-only):
  1. `analysis/ci_starknet_proofs.py` — P1 state dump, P2 M1 withdraw sim (OK), P3 M2 withdraw sim (revert), P4 solver withdraw sim (OK), P5 gate probes, P6 historical cross-market collect traces, P7 external-surface counts → `ci-out/proofs.json`.
  2. `analysis/ci_scan_events.py` — full Deposit/Withdraw scans per market + MM CreateMarket/Sweep/mints → `ci-out/events_*.json`.
  3. `analysis/ci_share_check.py` — on-chain `user_deposits` vs event-derived net shares (TOB-SPH-19/20 detection) → `ci-out/share_check.json`.
- **CI run URLs:** see `ci-log.txt` / `ci-artifacts/` in this folder (recorded after the run; local runs at blocks 16,153,020–16,170,720 are cited above).
- Local analysis artifacts: `analysis/state_initial.json`, `deep_state.json`, `markets_state.json`, `gate_probe.json`, `external_map.json`, `sim_withdraw_M1_top.json`, `sim_withdraw_M2_last.json`, `events_*.json`.

## 8. Verdict, residual & blockers

- **E-U ≈ $348.54 today** (MM's remaining STRK; cross-market `collect_order`). The large historical drains (1.959 wstETH ≈ $6.0k on 2026-03-29; 92,936 STRK ≈ $6.6k on 2026-10-06) are already realized and explain why the strategy's M2–M6 positions are unbacked.
- **H-O ≈ $55,503.49** (M1 vault $53,513.81 + Solver $1,989.68), proven payable by simulation.
- **S ≈ $60,220.31** (M2–M6 recorded claims + dust), plus ≈$4.2k solver virtual-reserve shortfall.
- **Latent risk:** any STRK/token re-funding of MarketManager is instantly drainable via the same path; the owner multisig (P) can still `sweep` MM and administer vaults; M1's remaining value stays holder-recoverable until withdrawn.
- **Blockers/limits:** no direct 2-step live exploit simulation (order ids are only known at execution time and simulations don't persist state); `starknet_call` cannot impersonate the order owner; flash-loan reentrancy not tested (no receiver deployment allowed).
- **Remediation:** add `assert(order.market_id == market_id)` to `collect_order` (and validate the caller owns the order); pause/zero MM balances; migrate M1/Solver holders.

## 9. Methodology & sources

- Starknet JSON-RPC (`starknet_call`, `starknet_getClass(At)`, `starknet_getStorageAt`-free views, `starknet_getEvents`, `starknet_traceTransaction`, `starknet_simulateTransactions` with query v3 + `SKIP_VALIDATE`) on keyless endpoints (`starknet-rpc.publicnode.com`, `starknet.api.onfinality.io/public`), cross-checked on Infura. Explicit blocks recorded for every read.
- Haiko docs (GitBook `developers/deployments`, vault/AMM pages) for the canonical address set; DefiLlama `haiko` adapter for the strategy/MM addresses; Trail of Bits Feb-2024 audit PDF (`haiko-xyz/audits`) for the finding set; DefiLlama/CoinGecko for prices.
- All simulations are read-only (`SKIP_VALIDATE`, query transactions); **no transaction was signed or sent**. No keys are stored in this folder; CI uses keyless public endpoints.

**Caveats:** point-in-time reads; prices at 2026-10-10; the E-U figure is an upper bound that assumes a near-zero-cost order collateral; the Solver shortfall is approximate (virtual reserves decode); M3/M5/M6 withdrawals were not individually simulated (M2 proven; same unbacked-position structure); "44 unnamed externals" could not be reproduced exactly.

**Files:** `README.md` · `summary.json` · `analysis/` (scripts + raw state + traces + proofs) · `ci/run.sh` · `ci-out/` (CI artifacts) · `ci-log.txt` (CI log) · `ci-artifacts/` (CI downloads).

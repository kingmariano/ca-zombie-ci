# C2-03 analysis notes — reconciliation with the wave-2 finding

## Wave-2 claim vs this deep-dive

| Item | Wave-2 (block 26,122,625) | This work (pinned 26,127,193) |
|---|---|---|
| Underwater victims | 17 (<150% CR) | 17 (18 at later blocks with lower price) |
| Single-shot best victim | +1.0594 stETH ($2,882) | +1.0557 stETH ($2,851) — same victim 0x2cc0…, price drift |
| All-17 one-shot | +$3,455 | +$3,420 |
| Multi-round all | +$6,283 | +$6,122 |
| "eUSD must be sourced… mintable at 160% CR, still net-positive" | treated bonus as net extractable | **net cash ≈ $0**: bonus is real in oracle terms but trapped as locked equity; market eUSD ask ≥ $1.10; unwind needs 61,218 eUSD vs 1.66k market depth |

The wave-2 *gross* numbers reproduce (within price drift). The correction is to **net extractability for a fresh unprivileged attacker**: the 10% bonus is the equilibrium value of eUSD (the Curve ask sits at/above $1.10; the observed bot trades pay $1.065–$1.081 only in transient windows), so a fresh attacker has no cash edge.

## Where the bonus actually goes (on-chain evidence)

- 330 all-time liquidations; 7 distinct provider contracts in 90d; last 2026-10-05 05:39 UTC.
- Providers hold max allowance, ~0 eUSD between trades → they source eUSD per-tx.
- Block 26,124,098 (MEV bot 0x00000f9110…): flash-borrow USDC (Uniswap V3 USDC/WETH pool) → buy eUSD on Curve at $1.0653/$1.0716/$1.0806 → `liquidation` → sell stETH → repay. ~$1.5 gross per tx.
- Block 26,124,132 (router 0xa0f1c3ad…): 49.80 USDC → 45.54 eUSD ($1.0936) → liquidate → WETH. Part of a user swap route.

## Capital model (pinned block, price $2,700.50)

- Multi-round: deploy 61,218.20 eUSD; seize 24.9361 stETH; gross bonus 2.2669 stETH ($6,122).
- Capital: 36.2707 stETH ($97,949) no-recycle; 11.3346 stETH ($30,609) minimum with full recycling.
- Cash after (no-recycle): 24.9361 stETH ($67,340) → −$30,609 vs capital; bonus locked as equity.
- Unwind: 61,218 eUSD needed; Curve holds 1,542 eUSD (ask $1.1085 @ 50 USDC; $2.61 avg for the pool's USDC); Uniswap V2 118 eUSD; V4 ~$1.7k @ ~$1.077.
- Flash loan: cannot close (T3: zero withdrawable at 160% CR).

## Tripwires to monitor

1. Any eUSD holder setting an allowance to Lybra (new passive provider) — immediately re-opens the 10% bonus for them (and keeper fees for others).
2. Global CR < 150% (ETH ≈ −21%, or ≥12.2 stETH withdrawn by healthy positions) → `superLiquidation` opens.
3. New eUSD liquidity/pool with ask < $1.09 at size → the $6.1k gross becomes cash-extractable (until arbed).

## CI verification (run 37342453507, 2026-10-05)

- 7/7 tests PASS in 12.75s; `conclusion: success`.
- Live tip 26,127,414: price $2,684.58, 18 underwater (the 149%-CR dust position re-entered as price fell), global CR 186.15%, multi-round gross 2.26845 stETH ($6,089.84), Curve ask $1.1085 (50 USDC) — closed-for-fresh-attacker condition holds live.
- Pinned fork exact: T2 seized 11.612289196317842379 stETH for 10.556626542107129436 ETH repaid; net worth +1.055662654210712944 stETH on 16.8916 stETH capital; T4 409 rounds, 61,218.199291 eUSD deployed, 24.936130057465970931 stETH seized, net worth +2.266920914315087882 stETH, gas 206.84M (test ctx).
- T3: `withdraw(1 wei)` reverts at ~160% CR (flash loan cannot close). T6: 80.116357532959440271 stETH par sink.

## Files

- `analysis/positions_all.csv` — all 399 debtors at pinned block (dep, bor, CR, eUSD balance).
- `analysis/victims_table.csv` — per-victim max extraction model.
- `analysis/extraction_model_pinned.json` — exact model output.
- `analysis/capital_model.json` — capital/unwind model.
- `analysis/liquidations_all.csv` — all 330 liquidation events.
- `analysis/logs_*.json` — raw event logs; `analysis/src/` — verified source dump.
- `poc/test/LybraC203.t.sol` — 7 fork tests.
- `ci/fetch_live_state.py` — live-state refresh at CI tip.

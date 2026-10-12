# Jaypeggers — reconciliation & reasoning trail (support for README.md)

## Live custody ledger (block 26,178,136; ETH $2,508.98; JAY $6.9976)

| Leg | Raw | USD | Who can move it |
|---|---|---|---|
| v1 JAY reserve | 74.313654328551356199 ETH | 186,451.40 | JAY holders via `sell()`: 90% to seller now; 3.03% fee to splitter (2/3→stakers, 1/3→team); 6.97% retained for remaining holders |
| v1 staking rewards | 1.856708285987792344 ETH (+2/3 of v1 splitter 0.126846335259042726 ETH) | 4,870.61 | 107 stakers pro-rata (census ≈1.94 ETH pending vs 1.9413 payable) |
| v1 staked LP | 3.550813032927453e15 of 8.732148971641902e15 LP (40.66%) | 20,814.12 | those stakers via `withdraw()` |
| v1 team splitter (TheSplitoooor) | 0.0044 ETH | 11.04 | team (pass-through splitter) |
| v2 jUSDC reserve | 34,390.346614 USDC | 34,390.35 | jUSDC holders via `sell()`: 90% now, 4% fee, 6% retained |
| v2 staking rewards | 71.553751 USDC (+2/4 of 152.621202 splitter) | 147.86 | 5 stakers (100.0000% of shares; Σview pending 147.840182 == balance + 2/4 splitter) |
| v2 staked LP | 8.186277669829084e18 of 8.186277669829086e18 LP (~100%) | 1,019.59 | those stakers |
| v2 team splitters | 138.333191 USDC (0xEDe8…) | 138.33 | team |
| **Total** | | **248,025.70** | |

Residual ~$22.1k = fee legs/retention that accrue to remaining holders (H-O) and team cuts (P) over time — see README §4.

## E-U candidate list (all closed)

1. **Reserve drain without token** — impossible; only `sell()` moves reserve; burns caller's tokens; probes revert without balance.
2. **Pool↔curve arb** — v1 band [6.4092, 7.457]/JAY vs market 6.99982; v2 band [1.2488, 1.5418] vs 1.4120. Fuzz with real router on fork: both directions lose at every size (≤95% of pool).
3. **Fresh-stake reward capture** — deposit() runs claim()→splitFees() *before* `shares +=`; `_setUserEntry()` post-inflow. Probe L≈largest staker ⇒ gain exactly 0; witness staker's pending moves only by −team-third·share.
4. **JIT capture of standing balances** — impossible: depositor's own claim drains the splitter first. Only post-stake inflows are capturable, strictly pro-rata; historical inflow ~0.127 ETH/5mo (v1), ~152.6 USDC/5mo (v2).
5. **Admin/init/upgrade** — no proxies; no withdraw/sweep/rescue anywhere; 19 privileged calls across 6 contracts revert Ownable; `initalize` consumed; JAYNFT unset.
6. **Reentrancy (2022 class)** — buy() takes no callbacks; sell/buy/deposit/withdraw/splitFees nonReentrant; reentrant-sell probe reverts.
7. **Other venues** — only canonical UniV2 pairs exist (JAY/USDC, jUSDC/WETH); Sushi/other pair lookups all zero.
8. **Fee-on-transfer / permit / gas-token tricks** — none in either token (verified source).

## Activity (concentration/correlation context)

- Curve `Price` events: ~105 since May-2026, last 2026-10-06 (buys/sells by small set of addresses).
- Pool Sync/Swap: continuous through 2026-09/10, last 2026-10-11 19:40 UTC (block 26,171,366).
- v1 staking withdrawals through 2026-03-30; v2 last activity in 2023-2026 small set (5 stakers).
- The 2022 incident (15.32 ETH, Dec-29-2022) was the legacy NFT-harvest contract — not this code.

## Repro commands (no secrets)

- Live state: `RPC_URL=<public> python3 analysis/collect_state.py out.json`
- Census: `RPC_URL=<public> python3 analysis/staker_census.py <staking> <addrs.txt> out.json "" 0x399080ec 0xc00007b0`
- PoC: `cd poc && FORK_RPC_URL=<public> forge test -vvv` (pins 26,178,136 when available, else latest)

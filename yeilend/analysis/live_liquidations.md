# YeiLend — live liquidatable positions (E-U surface), scan block ~236.52M

Source: `ci-out/user_scan.jsonl.gz` (CI runs 1-3; 70,948 of 101,398 borrowers classified) + per-user reserve probes.
All HF<1 positions are listed; those with zero collateral (below) are unrecoverable bad debt (no liquidation profit).

| user | collateral | debt | HF | close factor | est. net profit | composition / notes |
|---|---|---|---|---|---|---|
| `0x11611a3c9ffae8418edf7b305f4ad34a77405c6c` | $1,184.83 | $972.62 | 0.9745 | 50% | **+$31.69 (fork-executed)** | 1,185.16 aUSDC vs 983.06 frxUSD (frozen, not forced). Repay 491.53 frxUSD → seize 519.43 USDC (6.5% bonus, 0% protocol fee) |
| `0xc718a19b7cd185c7c498b57549f6eeab7b01f4b1` | $79.56 | $61.62 | 0.8207 | 100% | **+$4.62 (fork-executed)** | 983.28 aWSEI + 14.18 aUSDC vs 53.52 sfrxUSD. Seize WSEI (8.5% bonus, 10% protocol fee on bonus) |
| `0x722ba61d2901692fc7f4d770effcfa56a95c501e` | $60.95 | $50.06 | 0.9740 | 50% | ≈ +$1.63 (calc) | frxUSD/frxUSD; an existing bot (`0xa93043e8…`) has been halving it since Aug-2026 |
| `0x72f8ba772d05b90d9a0d78d82fb398b1c6ceb81e` | $19.98 | $17.99 | 0.8884 | 100% | ≈ +$1.2 (calc) | found in CI run 3 |
| `0xc1041b37c1c19e918916b6a0a74b7b78cfc6284d` | $4.46 | $3.93 | 0.9062 | 100% | ≈ +$0.26 (calc) | small |
| `0x884d763dc778c62682b0c79e982ef1adb1bd6d59` | $1.96 | $1.51 | 0.7769 | 100% | **+$0.12 (fork-executed)** | 29.40 aWSEI vs 0.000522 sfrxETH |
| `0x7ad846ad333469284b981c5d780580c1337677d2` | $2.15 | $2.29 | 0.5657 | 100% | ≈ $0.15 | a iSEI vs frxETH debt (bad-debt-ish, collateral > debt by oracle) |
| `0x63f057cec5b492c3f8bb9b79af16ec08484003e3` | $1.63 | $1.09 | 0.8935 | 100% | ≈ $0.02 | USDC.n + WSEI debt |
| `0x31469a057d87f86f305c894675e42326a1d79bbd` | $1.52 | $0.95 | 0.9640 | 50% | ≈ $0.03 | dust |
| `0x4f3110cf9e9ce7df20cfce1551c06eb5ac49e1c4` | $1.07 | $0.81 | 0.7860 | 100% | ≈ $0.05 | dust |
| `0xf2e9fec0f136c9e8992257855554c221856f769f` | $0.87 | $0.82 | 0.6390 | 100% | ≈ $0.05 | dust |
| `0x6035158ea3dda7309259b3f8af368bebb62d8c52` | $0.86 | $0.71 | 0.9707 | 50% | ≈ $0.02 | dust |
| 9 more | ≤$0.6 each | | | | ≈ $0.1 total | dust |

**Total gross E-U ≈ $39.9; fork-executed subset $36.43.**

## Zero-collateral HF<1 accounts (bad debt, no liquidation profit)
9,970 accounts with HF=0 or near-0, total debt ≈$11.6k (oracle), no collateral: mostly USDT.kava ($11,528) + USDC.n ($370) + iSEI ($10) — legacy positions already stripped by the Dec-2025 forced-liquidation campaign. Real value ≈$2.5k, unrecoverable by liquidators; accrues against suppliers (S).

## Path preconditions
- Debt asset must not be forced-enabled (forge reverts `'128'` for non-whitelisted callers on USDC.n/USDT/iSEI).
- Attacker needs the debt asset: frxUSD (candidate 1) is flash-loanable from the pool itself (974.2 available; `validateFlashloanSimple` ignores `frozen`), but the flash loan must be repaid in frxUSD → thin Sei market (Balancer V2 vault `0xfb43069f…` holds 1,812.8 frxUSD; a small V3 pool `0x60248bec…` 150.8). sfrxUSD (candidate 2) pool liquidity is only 15.4 for a 53.5 need → external sourcing.
- Gas on Sei is sub-cent; flash-loan premium 5 bp.

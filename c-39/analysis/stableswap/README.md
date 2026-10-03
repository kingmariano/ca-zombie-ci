# C-39 — PulseX StableSwap (3pool) live-state & extraction audit

Contract: `0xe3acfa6c40d53c3faf2aa62d0a715c737071511c` (`PulseXStableSwapThreePool`, verified, solc 0.8.10)
Coins: USDT `0x0cb6f5a34ad42ec934882a05265a7d5f59b51a2f` (6d), USDC `0x15d38573d2feeb82e7ad5187ab8c1d52810b1f07` (6d),
DAI `0xefd766ccb38eaf1dfd701853bfce31359239f305` (18d)
Fork of Curve/Saddle 3pool (StableSwap invariant D, A=1000, fee=0.04%, admin_fee=50%).

## Live state (block 27,702,157)
| Field | Value |
|---|---|
| owner() | `0x73a08E51a509Ca063D9C159f16DA4bd9B2be398B` (EOA, code size 0) |
| isInitialized | true (initialize() is POOL_DEPLOYER-gated + one-shot) |
| A / fee / admin_fee | 1000 / 4,000,000 (0.04%) / 5,000,000,000 (50%) |
| USDT balance | 336,063.00 |
| USDC balance | 276,453.47 |
| DAI balance | 323,911.12 |
| Pool total ≈ | **$936.4k** (all three near parity; stablecoins on PulseChain) |
| LP token | `0xC607606C0DC9B084D4e4458449963a975a762093` |
| get_dy(1→0, 10,000 USDC) | ~9,996 USDT (fee only) |

## Findings
- All admin functions are `onlyOwner`: `ramp_A`, `stop_rampget_A`, `commit_new_fee`, `apply_new_fee`,
  `withdraw_admin_fees`, `donate_admin_fees`, `kill_me`, `unkill_me`, `set_pls_gas`.
- `initialize()` cannot be re-run (`isInitialized` + `POOL_DEPLOYER`).
- No permissionless value-moving path found: `exchange`, `add_liquidity`, `remove_liquidity*` all use the
  standard invariant and transfer only the caller's own proceeds.
- The pool is near-balanced (max deviation ≈ 10%); no donation/empty-pool manipulation is available
  (invariant uses internal balances, not `balanceOf`).
- Depeg arbitrage (buying a discounted bridged stable externally and dumping at $1) is a generic stable-pool
  market risk, not a contract bug; on-chain prices of the three coins are ≈ parity (GT: DAI-from-Ethereum $1.0038).
- One stableswap pair exists in the subgraph (`pairs` query returns only `0xe3acfa…`).

## Verdict
**E-U = $0** (high confidence). The pool is a faithful Curve 3pool fork with a live, EOA owner (P class).
Latent: an owner key compromise would allow `withdraw_admin_fees` (accumulated admin fees) and A/fee
manipulation, but that is privileged (P), not external-unprivileged.

## Files
- Source dump: `../src_0xe3acfa6c40d53c3faf2aa62d0a715c737071511c_PulseXStableSwapThreePool.sol`
- Live state: `../live_state.json` (`stableswap` section)
- Fork tests: `../../poc/test/PulseXC39.t.sol` (`test_stableswap_state_and_pricing`, `test_stableswap_exchange_is_not_profitable`)

# CI results — Swych Perpetual fork verification

**Run:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38303057285 (workflow `poc.yml`, branch `swych-perpetual`, 2026-10-12)
**Fork block:** 127,273,590 (BSC) · **Tests:** 6 passed / 0 failed / 0 skipped (7.98 s)
**Log:** `ci-log.txt` · **Artifacts:** `ci-artifacts/result-swych-perpetual/ci-out/` (copied to `ci-out/`)

## A. Gate probes (all reverted — no unprivileged entry)

| Call (from random EOA 0x…dEaD) | Result |
|---|---|
| `pool.addLiquidity` | revert `NOT_AUTHORIZED` |
| `pool.removeLiquidity` | revert `NOT_AUTHORIZED` |
| `pool.swap` | revert `NOT_AUTHORIZED` |
| `pool.withdrawFee` | revert (custom `FeeDistributorOnly`) |
| `pool.distributeSurplus` | revert (custom `FeeDistributorOnly`) |
| `pool.increasePosition` / `decreasePosition` | revert (custom `OrderManagerOnly`) |
| `pool.liquidatePosition` (tx.gasprice=1 gwei) | revert `Gas price too high` |
| `oracle.postPrices` | revert `PriceFeed:unauthorized` |
| `oracle.addReporter` | revert `Ownable: caller is not the owner` |
| `om.executeOrder(429)` | revert `OrderManager:onlyExecutor` |
| `om.cancelOrder(429)` (someone else's order) | revert `OrderManager:unauthorizedCancellation` |
| `om.setOracle` | revert `Ownable` |
| `PR.postPriceAndExecuteOrders` | revert `PriceReporter:unauthorized` |
| `PR.executeSwapOrders([])` | revert `PriceReporter:unauthorized` |
| `PR.postPrices` / `PR.executeOrder(429)` / `PR.executeSwapOrder(1)` (ATT **and** whitelisted keeper) | revert empty (fallback — selector not exposed in dispatcher) |
| `PR.addReporter` | revert `Ownable` |

## B. FeeDistributor (permissionless triggers, protocol-only payout)

- `FD1.withdrawFee()` from ATT: **succeeds**; pool `feeReserves(WETH)` 0.611937748191841578 → 0; recipient `0x9baE…d3F5` WETH **+0.611937748191841578**; **ATT WETH delta 0, ATT WBNB delta 0**.
- `FD1.distribute()` (0xb069bec2) from ATT: succeeds; **ATT ETH delta 0**.
- `FD1.pause()/setFeeTokens` from ATT: revert `Ownable`.
- FD2 (`0x9baE…d3F5`): `distributeTreasury/setRecipient/removeRecipient/pause` all revert `Ownable`; `getRecipients()` = (0, []) — no recipients configured; funds routed there are Safe-controlled.

## C. LP holder exit (H-O)

- Attacker `removeLiquidity`: revert `NOT_AUTHORIZED`.
- LP holder EOA `0x9A6A…a59a` (100% of TR1, whitelisted): `removeLiquidity` 10% → **succeeded**, received **15,411.448265272852363994 USDT**.
- Implied full-LP redeemable (mid poolValue): **$153,922.50** (1.539225e35 at fork block).
- Full-exit equivalents computed per token: BTCB 1.8552 · WBNB 206.0353 · USDT 154,114.48 · WETH 61.0189 · SOL 1,418.4193.

## D. Order scan (full, all 4,316 ids)

- **8 pending orders** (ids 429, 3073, 3198, 3233, 3394, 3423, 3633, 4071), all limit **DECREASE** orders, execution fee 0.0025 ETH each.
- **Every one of the 8 owners currently has a zero-size position** → executing them would revert/no-op; no execution fee is claimable. `nextSwapOrderId = 1` → zero swap orders.

## E. Known CI limitations

- The CI RPC rejects `eth_getLogs` (range-restricted/unsupported), so the position-event scan returned 0 events (see `ci-out/position_events.json`, `requests_used: 0`). Open positions are therefore proven only via `trancheAssets` reads (BTCB long guaranteedValue ≈ $23.7k, SOL long ≈ $3.4k), and their owners were not enumerated (public RPCs cap/block wide log ranges; GoldRush has no log index for this pool). This does not affect the E-U verdict: no unprivileged function can touch those positions.

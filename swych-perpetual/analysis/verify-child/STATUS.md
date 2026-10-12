# Independent-verification status (verification child ses_ece306cddffeSyHoLXfvBs4nsP)

At finalization time (2026-10-12, ~20:35 UTC) the verification child had produced **partial raw
artifacts but no final VERIFY.md**. Status: **in progress — not a blocker**; the headline was
independently re-derived in part (see below). Any later VERIFY.md written by the child lands in this
folder and supersedes this note.

## Partial independent evidence already on disk (child's raw/)

- `raw/PR1_dispatcher.txt` / `raw/PR1_push4.txt` / `raw/parse_dispatch.py` — the child **independently
  re-parsed the deployed PriceReporter 0x1CB9…0dC5 dispatcher** from `eth_getCode` and got the same
  table as the parent: 11 dispatched selectors — `isReporter(0x044ad7be)`, `executeSwapOrders(0x07b99f37)`,
  `postPriceAndExecuteOrders(0x5bf9ac5b)`, `removeReporter(0x5de5c212)`, `reporters(0x5e02cb7d)`,
  `getReporterCount(0x5efa519d)`, `renounceOwnership(0x715018a6)`, `owner(0x8da5cb5b)`,
  `0x93a91e33` (reporter-gated), `addReporter(0xdd8755f2)`, `transferOwnership(0xf2fde38b)`.
  `executeOrder(0x7e498c81)`, `executeSwapOrder(0x04358662)` and `postPrices(0x5cdb595c)` appear only as
  PUSH4 call-constants, never as dispatcher entries — **confirming claim 1**.
- `raw/PR2_dispatcher.txt`, `raw/PR2_push4.txt` — same for the twin 0x161B…143d.
- `raw/roles_raw.txt`, `raw/block.txt`, `raw/block-meta.json`, `raw/ethcall.sh` — live role/state probes.

## Still to be independently confirmed by the child (parent's evidence stands)

- Claim 2: OrderManager `executeOrder` onlyExecutor; the 8 pending orders' owners have zero-size positions.
- Claim 3: TR1 100% held by 0x9A6A…a59a and that address's `isLiquidityProvider == true`.
- Falsification sweep for any other permissionless payout.

Parent's own evidence for all three (with exact calls/blocks) is in `analysis/live-state.json`,
`analysis/ci-results.md` and `ci-out/`.

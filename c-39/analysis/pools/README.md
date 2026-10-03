# C-39 — PulseX V1/V2 pair-level skim/excess scan

Method: for each pair, compare on-chain `balanceOf(pair)` for both tokens against stored `getReserves()`
at a **pinned block** (cross-block reads produce false excess/deficit — see 9inch note in `../dormant/README.md`).
`balance > reserve` on both sides (one side may be 0 excess) ⇒ `skim(to)` is callable by anyone and pays the
excess to `to`. `balance < reserve` ⇒ FOT/rebasing candidate (skim reverts).

## Top-2000-by-subgraph-TVL scan (block 27,701,971)
- Scanned 2,000 pairs (top 1,000 per factory by subgraph `reserveUSD`), 18 pairs with any excess.
- **All excess was in scam/meme tokens** (pTGC, PEPEJOHN, COCK&BALLS, Cavalo, bPlsWPLS, "1", MAGIC, fake-LINK…);
  DefiLlama/GeckoTerminal prices ≈ $0. Largest real-token excess ≈ dust.
- `skim()` simulation from an unprivileged EOA succeeded (empty return = success) but returned only those tokens.
- 0 pairs with deficit (no FOT/rebasing mispricing among top pairs).
- Raw: `excess_scan.json`, `excess_detail.json`.

## Pinned-block subset scan (600 pairs, block 27,702,0xx)
- 12 skim-able pairs, all raw-unit dust; 0 deficits. `../ci-out/skim_scan_full.json` (subset, overwritten by CI full run).

## Full-population scan (CI job)
`ci/full_skim_scan.py` enumerates **every** pair from both factories (65,403 V1 + 189,582 V2) via Multicall3
(`aggregate3`, allowFailure), reads reserves/tokens at one pinned block, then balances + feeTo LP for all pairs,
and flags excess/deficit. Results: `ci-out/skim_scan_full.json`, priced summary `ci-out/flagged_excess_priced.json`.
Run: see `../ci-log.txt` / CI URL in main README.

## Verdict
No material skim-able excess found. Any value obtainable through `skim()` on the live pair population is
dust/scam-token-only. **E-U from skim ≈ $0.**

## Notes
- PulseX pairs have no `migrator()` (unlike Uniswap V2) — `cast call migrator()` reverts on every sampled pair.
- Pair swap fee = 0.29% (`balance*10000 - amountIn*29`), consistent in all three routers (`9971` in getAmountOut/In).
- `skim`/`sync`/`swap`/`mint`/`burn` all carry the `lock` reentrancy modifier.
- `permit` uses the EIP-712 domain with `chainid` (no cross-chain replay).

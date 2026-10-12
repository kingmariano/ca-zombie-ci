# childA-verify — independent recomputation of savmSwap (Prom chain, id 227)

Independent, from-scratch verification of the parent analysis for factory
`0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9`. All reads are **read-only**
`eth_chainId` / `eth_blockNumber` / `eth_getBlockByNumber` / `eth_getCode` /
`eth_call` against the public RPC `https://rpc.prom.io`, using `verify.py`
(python3 stdlib only, JSON-RPC batches of ≤10 calls per HTTP request). No
transactions, no keys. Raw numbers in `verify-results.json`.

**Block pinned for all state reads: 10073736** (`0x99b688`, hash
`0x8fb919b942f2d6af6e8968ce356f177a78959068d6caf02d007624d83fc6e999`,
2026-10-12 10:49:10 UTC). A follow-up spot check at block 10073771 returned
identical reserves/LP balances.

## 1. Factory / pairs

- `allPairsLength()` = **90**; all 90 `allPairs(i)` returned valid addresses (0 failures).
- WPROM appears as a token in **85** pairs; the task's USDT in **2** (main pair + one small `USDT/USDC` pair). The 5 pairs without WPROM: `EZMODE/PUMP`, `NKT/USDC`, `BRAT/CHG`, `USDT/USDC` (×2, one of which uses a *different* contract that also goes by the symbol "USDT", `0x6064c902…fcab`, 18 dec — excluded from the totals).

## 2. Totals (sum of `balanceOf(pair)` across all 90 pairs)

| | raw | human |
|---|---|---|
| WPROM (`0x04a2…b0c0`, 18 dec) | 30213118074586335223614 | **30,213.118074586335223614** |
| USDT (`0x7e94…a7ed`, 6 dec) | 76138447675 | **76,138.447675** |

Sum of `getReserves()` for the same tokens is **identical** to the `balanceOf`
sums (no tokens held outside a pair's listed tokens).

- DefiLlama price at verification time (`coins.llama.fi/prices/current/coingecko:prometeus`): **$5.20110910518123**
- **Total USD = $233,280.17** with USDT at $1.00 ($233,226.33 with USDT at DefiLlama $0.99929).
- Parent's $234,906 was computed at PROM = **$5.2549**. Recomputing my totals at
  that exact price gives **$234,905.36** → **−$0.64 (−0.0003%)**, i.e. the parent's
  number reproduces exactly. At the currently slightly lower PROM price the total
  is **−0.69%** vs $234,906 — within the ~3% tolerance; the only difference is
  PROM price drift between runs.

## 3. Excess check (skim-ability)

- Pairs where `balanceOf(pair) != getReserves()` for either token: **0 of 90**.
- No skim-able excess anywhere; `balance > reserve` in 0 pairs, `balance < reserve` in 0 pairs. **Parent claim holds.**

## 4. Main pair `0x1ddbf7113e3711ae9918f2dc14efb6b302b1e0d2` (WPROM/USDT)

- Reserves = balances: **14,630.805686554919139917 WPROM / 76,134.728318 USDT**
  (parent: ~14,630.8 / ~76,134.7 — match).
- LP `totalSupply()` = 27,833,321,770,539,427 (raw wei); shares:

| holder | LP balance (raw) | share |
|---|---|---|
| `0x2bA8968C1AE5984f049F28085f50D7Df4aD1a01e` | 27791868835529666 | **99.851067%** (parent: ~99.85% — match) |
| `0x55594E57F80b2deCd63608A4F2802F8003633aD2` | 32678960679361 | 0.117409% |
| `0x000000000000000000000000000000000000dEaD` | 0 | 0.000000% |
| `0x0000000000000000000000000000000000000000` | 1000 | ~0.000000% (Uniswap-V2 `MINIMUM_LIQUIDITY` mint) |

The main pair holds 48.43% of all WPROM in the factory; the top 10 pairs hold 99.00%.

## 5. Top 10 pairs by WPROM held (human units, from `getReserves`; equal to balances)

| # | pair | tokens | WPROM reserve | other-token reserve |
|---|---|---|---|---|
| 1 | `0x1ddbf7113e3711ae9918f2dc14efb6b302b1e0d2` | WPROM/USDT | 14,630.805686554919139917 | 76,134.728318 |
| 2 | `0x679e6f7240a807327d63c12e7214833be5555c9c` | WPROM/gyro | 8,673.631223725290257935 | 459,379,362.692288163770514259 |
| 3 | `0x59f90cb51493d04f96fe5ae22833cbdc7f676d77` | WPROM/FKS | 3,276.134256526213090008 | 486,804,859.663911867230179549 |
| 4 | `0x6a2a261829a98edc6da8621b2b01cece6c821608` | WPROM/Rkt | 849.060749158002592734 | 357,817,005.843250609999756884 |
| 5 | `0x91751d831f201ee8f982cd0fb2925b8244cb77cf` | WPROM/BRUV | 602.272321251552323545 | 1,035,167.140295817487515037 |
| 6 | `0x5a47a049ae3a223420953dffa6064c53bc59c7da` | WPROM/USTC | 455.584428132389626222 | 148,198,051.913439841601123282 |
| 7 | `0xe89c03037db0748324c3937aa5275de71c3d6f6c` | WPROM/BEEBEE | 413.890234729061246186 | 121,978,584.784720844524618860 |
| 8 | `0x5961f67dbf852343ab73bceeb4b1be573d44b431` | WPROM/Rkt | 361.790598712169670218 | 839,976,619.319263409771872346 |
| 9 | `0x68d1424c4dfaca05f4712132fe587e4fa9ee8a31` | WPROM/BAAI | 355.764395191307595430 | 16,841,117.398675287311498794 |
| 10 | `0x3afdb011df2227d22fb6ef8d742af5cbebc0c027` | WPROM/CAT | 290.713594509636633346 | 103,940,259.732454232207913883 |

## Verdict on the parent's claims

| claim | result |
|---|---|
| 90 factory pairs | ✅ 90 |
| total ≈ $234,906 @ PROM $5.2549 | ✅ reproduces to $234,905.36 (−0.0003%); −0.69% at current price (price drift only) |
| main pair ≈ 14,630.8 WPROM + 76,134.7 USDT | ✅ 14,630.805686554919139917 / 76,134.728318 |
| no skim-able excess on any pair | ✅ 0 mismatches (both directions) |
| first LP holder ≈ 99.85% | ✅ 99.851067% |

No discrepancies found beyond PROM price movement between the parent's run and this run.

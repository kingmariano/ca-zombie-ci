# SaucerSwap V1 (Hedera) — independent full-factory excess sweep

**Question:** corpus H2-09 claims "$314.6k USDC (800 pairs)" skim excess and says it is a
measurement artifact. Resolve definitively: is any `skim(to)`-extractable excess real today?

**Answer (2026-10-10, Hedera EVM block ~100,953,291):** **No. Total real excess across all
2,798 V1 pairs ≈ $0.008** (sub-cent). E-U = $0.00. The corpus figure is confirmed as a
measurement artifact (most plausibly a token0/token1 index mix-up — see below).

## Method (independent of any other agent's path)
- Factory: SaucerSwapV1Factory `0.0.1062784` = `0x0000000000000000000000000000000000103780`
  (`allPairsLength() = 2798`).
- Batched `eth_call` against public Hedera relay `https://mainnet.hashio.io/api`; every pair:
  `token0()`, `token1()`, `getReserves()`, `balanceOf(pair)` for both tokens.
- 2,798/2,798 pairs scanned; reserves read for all; balances read for 2,797 (1 pair unreadable).
- Pair bytecode check: standard Uniswap V2 pair (16,542 bytes) with `skim()` (selector `bc25cf77`)
  present — so any real excess would be permissionlessly extractable.
- Script: `ci/steps/hedera-saucerswap-independent.py`; raw output `ci-out/hedera-saucerswap-independent.json`
  (artifact of CI run 38048907250 + local run).

## Results
- `correct_positive_excess_count = 8` pairs; **2 pairs** with balance < reserve (not extractable);
  all other 2,788 pairs have balance == reserve exactly (healthy V2 invariant).
- The 8 real excesses and their full USD value:

| Pair | Token | Excess (raw) | Excess (token units) | Price (DefiLlama) | USD |
|---|---|---|---|---|---|
| 0xbe7e31e5… | SMACKM (0.0.8041571, 8 dec) | 532,624,999 | 5.32625 | $0.0000897 | $0.000478 |
| 0x9e7d13ee… | HBARbarian (0.0.4816828, 0 dec) | 1,751 | 1,751 | $0.00000426 | $0.007451 |
| 0xd1a2bc18… | SAUCE (0.0.731861, 6 dec) | 777 | 0.000777 | $0.012242 | $0.0000095 |
| 0x91e35385… | LIZ (0.0.3473599, 0 dec) | 50,000,000 | 50,000,000 | no price | ~$0 |
| 0x148be77d… | PEP (0.0.2309394, 4 dec) | 269 | 0.0269 | no price | ~$0 |
| 0x61db03b9… | UNLUCKY (0.0.3957917, 0 dec) | 624 | 624 | no price | ~$0 |
| 0x5a170777… | FROGRE (0.0.4366258, 2 dec) | 200 | 2.00 | no price | ~$0 |
| 0xad521aa9… | stickbug (0.0.4352885, 4 dec) | 3 | 0.0003 | no price | ~$0 |
| **Total** | | | | | **≈ $0.008** |

- **Zero USDC excess anywhere in the factory** — no pair's USDC (native 0.0.456858 or any other
  variant) balance exceeds its reserve. The corpus's "$314.6k USDC" cannot be reproduced from
  correct per-pair accounting.

## Artifact mechanism (diagnostic)
On the same pairs, the *index-mixed* sums are huge:
`Σ max(0, bal0 − reserve1) = 1.185e18 raw`, `Σ max(0, bal1 − reserve0) = 7.867e19 raw` across
the factory — a token0/token1 mismatch on pairs with asymmetric reserves produces large positive
"excess" in both directions. This (or an equivalent wrong-reserve source) is the likely origin of
the $314.6k figure. The correct-index sweep shows the true excess is dust.

## Verdict
- **E-U = $0.00** (high confidence). Latent: none material — the pools remain standard V2; LP funds
  are holder-scoped (H-O ≈ $9.8M TVL per DefiLlama 2026-10-10), no admin drain path found.
- Evidence: `ci-out/hedera-saucerswap-independent.json`, this file, run 38048907250 artifacts.

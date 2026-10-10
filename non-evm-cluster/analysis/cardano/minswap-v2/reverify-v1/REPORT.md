# Minswap V1 — independent re-verification of parent's numbers (child-cardano-2)

**Scope:** pick the top 3 V1 pools by USD from the parent's census and confirm balances via a second source
(Koios vs Minswap API vs on-chain UTxO values). Read-only, keyless. Tip 14,049,880 / slot 200,061,476
(address_info) and 14,049,765 (pool parse). ADA $0.254365 (llama ts 1791627832).

## Method

1. Independent Minswap market-API pull: `POST /v1/pools/metrics {"protocols":["Minswap"],"currency":"usd"}`
   3 pages × 100 (`minswap_v1_usd_top300.json`) — not a copy of the parent's file.
2. Independent on-chain pull: Koios `address_info` for the V1 pool address
   `addr1z8snz7c4974vzdpxu65ruphl3zjdvtxw8strf2c2tmqnxz2j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq0xmsha`
   → 6,998 UTxOs with asset lists (`v1_pool_address_info.json`, 7.4 MB).
3. Locate the top-3 pools' pool UTxOs on-chain by matching the LP asset / pool NFT / reserves, compare
   exact token amounts and ADA to the API's `liquidity_a`/`liquidity_b`.

## Top 3 by USD — on-chain vs API

| # | Pool (API USD) | On-chain pool UTxO | On-chain value | API `liquidity_a`/`b` | Verdict |
|---|---|---|---|---|---|
| 1 | TrustCoin/BullyDoggy **$666,759.01** (both assets unverified) | `a33defcf15f1185d26b5f9784d91c7747fb97d3df68ab93309d7959e9d40c113#0`, bh **9,999,870** (2024-04) | **1,978,290 lovelace (1.98 ADA)** + 3,658,332,194 Trust + 94,280,995,784 BD + pool NFT + factory token | liqA **3,658,332,194** / liqB **94,280,995,784** | **exact match**; the $666.8k "TVL" is nominal — the pool holds 1.98 ADA and two dead memecoins (0 volume, 0 pending orders) |
| 2 | d037aa7c…/ed36c305… **$302,768.74** (both unverified) | `bcd04c1584d43b69a69cf57dca644fc3526386b104732115bd4bd0d9007d6300#0`, bh **8,226,184** (2023) | **2,379,258 lovelace (2.38 ADA)** + 127,469,055 + 2,003,005 + pool NFT + factory token | liqA **127,469,055** / liqB **2,003,005** | **exact match**; nominal only (no activity) |
| 3 | ADA/MIN **$251,258.16** (both verified; $12,951 24h vol; 71 pending orders) | `826b0dc49ed4eee212e2acea28ecd5e74d880ffe1788da831552a40d52d3443a#0`, bh **14,049,847** (fresh, ~30 blocks before tip) | **492,139.323171 ADA** + 31,828,810,061,216 raw MIN (=31,828,810.06) + 270,120,921 LP + pool NFT + factory token | liqA 491,506.581726 ADA / liqB 31,869,661.984253 MIN | **match within trading drift**: ADA +632.74 (+0.13%), MIN −40,851.92 (−0.13%) — direction-consistent with ~15 min of buys at the pool's measured volume (~$9/min) |

Notes: the #1/#2 pools are token/token pairs, so their "ADA" is only min-UTxO; the API's USD for them comes
from token prices that are themselves pool-derived (circular for dead memecoins). The parent's assessment
("fake-pair pools ~$1.0M nominal, $0 real") is confirmed for these two.

## Aggregate re-checks

- **Pool-address ADA:** my Koios `address_info` (6,998 UTxOs — Koios truncation) = **2,720,955.332415 ADA**
  ($692,110). Parent's figure: ≥2,717,373.13 ADA — mine is **+3,582.20 ADA higher** (both are lower bounds
  because Koios caps the UTxO list; the address has >6,998 UTxOs). **No contradiction.**
- **USD census:** my independent top-300-by-LP pull: nominal **$2,838,178.43**, both-verified
  **$1,335,014.30** vs parent's 7,000-pool census $2.89M / $1.33M — within ~2%. **Reproduced.**
- **Discrepancies found: none material.** The only deltas are (a) time drift on the actively-traded ADA/MIN
  pool (±0.13%, explained), (b) the parent's aggregate ADA is a slightly staler lower bound.

## Caveats

- `address_utxos` for this address repeatedly timed out/504'd; `address_info` worked and returns the same
  first 6,998 UTxOs (hard Koios cap). Page-0-style partial sets cannot exclude a few extra UTxOs beyond the cap.
- API vs chain snapshots are not simultaneous; comparisons on zero-volume pools are exact, on active pools
  drift with trading.

## Files

- `minswap_v1_usd_top300.json` — my USD API pull.
- `v1_pool_address_info.json` — Koios address_info (6,998 UTxOs, 7.4 MB).
- `fetch_v1_address_info.py` — fetch script (keyless).
- `v1_pool_utxos_all.json` — secondary minimal UTxO pull (used for cross-checks).

# Sources & raw evidence index — Minswap V1

All read-only. No keyed URLs stored anywhere.

## On-chain reads (Koios, keyless https://api.koios.rest/api/v1)

- `minswap_v1_pool_script.cbor` — deployed pool validator (script hash
  `e1317b152faac13426e6a83e06ff88a4d62cce3c1634ab0a5ec13309`), fetched with `script_info`; creation tx
  `2a12ef3acb648d51c4a46d7b9db20ff72dc8d22976eb3434671dffd3c5066815` (block 7,039,882, 2022-03-25).
- `minswap_v1_factory_script.cbor`, `minswap_v1_lp_script.cbor`, `minswap_v1_poolnft_script.cbor` — creation
  tx `b1a42db8246e2c091d6a5de3644bef23b6702f7d4bec7123c748c901527d392c` (block 7,036,104, 2022-03-24).
- `creation_txs.json` — Koios `tx_info` of both creation txs.
- `order_address_info.json` — Koios `address_info` for the V1 order address
  `addr1zxn9efv2f6w82hagxqtn62ju4m293tqvw0uhmdl64ch8uw6j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq6s3z70`:
  balance 72,960.121342 ADA, 5,785 UTxOs, 1,385 distinct assets (mostly spam).
- `pool_page0.json` — 1,000 UTxOs at the V1 pool address
  `addr1z8snz7c4974vzdpxu65ruphl3zjdvtxw8strf2c2tmqnxz2j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq0xmsha`.
- `pool_datums_decoded.json` — 400 decoded pool datums (asset pair, totalLiquidity, profit-sharing flag).
- `minswap_v1_all_pools.json` — Minswap market-data census (`POST /v1/pools/metrics`, protocols=["Minswap"]),
  7,000 pools: TVL, volumes, pending-order counts.

## Third-party sources

- Tweag audit **MinSwap-Jan31.pdf** (Jan 2022; three CRITICAL findings) and **MinSwap-assignment-Mar-03.pdf**
  (follow-up test-suite update; all attack tests OK). Text extractions alongside.
- Open-sourced fixed contracts (public mirror `github.com/myway7/contracts`, commit `162c455`, 2022-03-18):
  selected sources in `source/` (pool/liquidity/batchorder/factory/poolnft + Utils/OnChainUtils + the
  Tweag `DatumHijacking.hs` attack test). Compiled `.plutus` artifacts hash to the *other* deployed version
  `57c8e718…` (see `../scripts/uplc/pool_A.uplc`).
- `dcSpark/carp` `indexer/tasks/src/multiera/dex/minswap_v1.rs` — Minswap's own indexer lists both pool
  script hashes (`e1317b15…`, `57c8e718…`) and both order addresses (`addr1wyx22z2s…`, `addr1wxn9efv2f…`).
- UPLC tooling: `uplc` python package (decompilation, AST) and aiken v1.1.24 (`uplc decode/eval`).

## Method notes

- Script-hash convention verified empirically: `blake2b_224(0x01 || CBOR(flat))` reproduces the Koios
  `script_hash` and the address payment credentials.
- `after h (Interval _ t) = upperBound h > t` (Plutus V1 `Interval.hs`) — batcher licences must be used
  *before* their deadline; the deployed check is correct.

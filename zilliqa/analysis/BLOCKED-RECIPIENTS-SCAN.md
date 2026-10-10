# C2-58 — blocked-recipients sweep lists: scan result

`zq2/blocked_recipients/blocked_recipients_{001,002,003}.bin` are the protocol-level
account sweep lists (Ledger-incident response / exchange migration). Format (from
`zilliqa/src/blocked_recipients.rs`): `region_count u32`, `address_count u64`, then
regions (`first_index u64` + `destination 20 bytes`), then `address_count × 20 bytes`.
From the activation height, 100 accounts per block are swept: balance → region
destination, nonce → `u64::MAX` (permanent freeze).

Parsed locally (read-only) at download time:

| File | Regions | Addresses | Sweep start (block → UTC) |
|---|---|---|---|
| 001 | 14 | 1,460,781 | 34,844,968 → 2026-09-02 15:43 |
| 002 | 16 | 508,861 | 36,383,378 → 2026-09-22 08:15 |
| 003 | 4 | 100,831 | 37,410,000 → 2026-10-05 13:12 |
| **total** | | **2,070,473** | |

All three sweeps are complete at current head (each needs ≤ count/100 blocks).

**Search result** (exact 20-byte, aligned match against the address body):

| Address | Role | In list? |
|---|---|---|
| `0x62a9d5d611cdcae8d78005f31635898330e06b93` | SSNListProxy v1.1 | no |
| `0xa7c67d49c82c7dc1b73d231640b2e4d0661d37c1` | SSNList v1.1 impl (holds 1.388 B ZIL) | no |
| `0x38c986f6252a32b1c0fa732784c1a94e9f42a394` | 2-of-5 admin multisig | no |
| `0x412b55a0ebc1001f930aba8dc107022a3a2ba484` | verifier EOA | no |
| `0x00000000005a494c4445504f53495450524f5859` | Z2 deposit proxy | no |
| `0x00000000005a494c31455343524f5750524f5859` | escrow proxy | no |

Consistent with the live balances: none of the C2-58 contracts were swept or frozen by
the incident response. The lists consist of exposed/stolen accounts and exchange-held
legacy accounts (region destinations include known exchange deposit addresses).

Reproduce: parse with the format above; raw binaries are not kept in this folder (size),
but are public at `github.com/Zilliqa/zq2/blocked_recipients/`.

# H-22 · Serum DEX v3 (Solana) — live market state & extractability

**Status:** read-only (no transactions sent, no keys used). **Chain:** Solana mainnet-beta.
**Program:** `9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin` (deprecated; last deploy slot `146,728,883` = 2022-08-19T20:08:20Z).
**Data slot:** `453,205,442` (epoch 1049, 2026-10-04). Spot checks re-run at slot `453,212,002`.
**Layout:** 388-byte accounts = 5-byte `"serum"` head + MarketState (376 B) + 7-byte tail; field offsets identical to OpenBook v1 (`state.rs` of `project-serum/serum-dex` @ 0.5.6, commit `92992b3`).
**Enumeration scripts & raw data:** `analysis/serum_v3_markets.json|csv`, `analysis/serum_v3_markets_raw.json`, `analysis/serum_v3_final.json`, `analysis/serum_v3_rent.json`, `analysis/serum_v3_spotcheck.json`. Dead ends: `analysis/serum_v3_methods.md`.

---

## 1. Working enumeration route

`getProgramAccounts` for this program is disabled on every reachable public endpoint (exact errors in `serum_v3_methods.md`). Working route = **registry union + on-chain account reads**:

| Source | Markets | Notes |
|---|---|---|
| npm `@project-serum/serum` `markets.json` (`programId == 9xQe…`) | 168 | curated 2020–2021 list |
| solana-labs `token-list` extensions `serumV3Usdc` / `serumV3Usdt` | 365 refs → **234 new** | archived list; includes post-2021 permissionless listings |
| Bitquery realtime `CloseOpenOrders` stream (2026-10-04) | 13 candidates → **2 new** | live rent-reclamation calls reveal markets |
| **Union** | **402 addresses → 398 initialized markets** | 4 closed/non-market; 0 disabled (`flags & 128 == 0`) |

Each union address was fetched with `getMultipleAccounts` (base64, 388 B parse) and each of the 796 vault token accounts re-read with `jsonParsed` to get mint/decimals/balance. `mainnet-beta` non-gPA methods (`getMultipleAccounts`, `getAccountInfo`, `getTokenAccountBalance`) work fine.

## 2. Aggregate value (slot 453,205,442)

**Total vault value: $14,145,833.59** (DefiLlama prices, 2026-10-04; SOL $120.98).

| Component | USD | Basis |
|---|---|---|
| Deposits (`coin/pc_deposits_total`) | $11,281,757.02 | accounting fields |
| Accrued fees (`*_fees_accrued`) | $2,587,491.80 | accounting fields |
| PC referrer rebates (`referrer_rebates_accrued`) | $276,313.45 | accounting fields |
| **Vault token balances (measured)** | **$14,145,833.59** | 796 vault accounts |
| Unpriced/dust difference | ≈ $271 | rounding + unpriced spam mints |

**Accounting identity:** `vault = deposits + fees` (coin side) and `vault = deposits + fees + referrer_rebates` (pc side) holds **exactly for 742 of 796 market-sides**; the other 54 sides hold a small positive excess (donations/dust; e.g. SOL/USDC coin +0.1002 SOL, SOL/USDT coin +1.70 SOL). **No side is short** — every reported liability is fully backed in the vaults.

**Top mints held in vaults (raw base units):**

| Mint | Symbol | Raw vault | Decimals | USD |
|---|---|---:|---:|---:|
| `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v` | USDC | 8,029,422,228,517 | 6 | $8,029,383.67 |
| `So11111111111111111111111111111111111111112` | wSOL | 22,493,358,084,285 | 9 | $2,718,355.43 |
| `7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs` | WETH | 82,269,410,327 | 8 | $2,221,200.87 |
| `Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB` | USDT | 657,583,282,930 | 6 | $657,515.43 |
| `RLBxxFkseAZ4RgJH3Sqn8jXxhmGoz9jWxDNJMh8pL7a` | RLB | 391,956,770 | 2 | $315,812.09 |
| `4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R` | RAY | 32,755,424,105 | 6 | $70,020.56 |
| `orcaEKTdK7LKz57vaAYr9QeNsVEPfiu6QeMU1kektZE` | ORCA | 21,653,000,000 | 6 | $39,906.07 |
| `mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So` | mSOL | 117,343,000,000 | 9 | $19,895.11 |
| `BQcdHdAQW1hczDbBi9hiegXAR7A98Q9jx3X3iBBBDiq4` | soUSDT | 14,437,221,677 | 6 | $14,435.73 |
| `7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU` | SAMO | 31,635,849,000,010,218 | 9 | $10,743.52 |

**Top markets by vault USD:** SOL/USDC `9wFFyRfZ…` $4,998,763 · ETH/USDC `8Gmi2HhZ…` $2,365,019 · SBR/USDC $542,261 · SOL/USDT $496,893 · RAY/USDC $382,699 · RLB/USDC $349,107 · IN/USDC $343,515 · BTC/USDC $334,509 · SUNNY/USDC $278,993 · MSOL/USDC $210,837.

**Independent spot checks (`serum_v3_spotcheck.json`, 8/8 PASS):** top-4 markets' coin+pc vault balances re-read with `getTokenAccountBalance` match the dataset exactly; SOL/USDC market `9wFFyRfZ…` vaults hold 20,290.112 wSOL + 2,546,687.00 USDC (spot-verified). Sub-accounts of SOL/USDC: req_q 36,609,600 lamports / 5,132 B, event_q 1,825,496,648 / 262,156 B, bids & asks 457,104,968 each / 65,548 B.

## 3. DefiLlama cross-check ("$17.15M")

DefiLlama `api.llama.fi/protocol/serum` = **$17,131,473.29** at 2026-10-04 (not $17.15M). Its adapter `DefiLlama/DefiLlama-Adapters/projects/serum.js` runs **its own `getProgramAccounts(dataSize=388)`** and sums `deposits + fees` for every market, priced by its oracle. Our measured `deposits + fees` = **$13,869,248.82**; residual gap **$3,262,224.47**, concentrated in: USDC $1.90M, SOL $1.06M, RAY $174.9K, STNK $65.1K, mSOL $13.0K, SOPAXG $6.0K, others <$4K.

**Cause:** markets outside both frozen registries. DefiLlama's series first shows `STNK` on **2024-11-27** (token created after the token-list was archived; no STNK market exists in either registry), and its RLB entry appears 2023-04 — permissionless Serum v3 market creation continued after 2021/2023. Our $14.15M is therefore a **floor (398 markets)**; DefiLlama's $17.13M is the **full-gPA accounting estimate (superset)**, not a vault read. The largest vaults were directly verified to physically hold the assets, so the DL figure is plausible but not independently corroborated as custody for its extra markets.

## 4. Live activity (2026)

Bitquery realtime retention for this program starts `2026-10-04T04:21:52Z`. In 04:21–07:47 UTC there were **15 Serum v3 instructions — all `CloseOpenOrders`** (discriminator 14, data `00 0e000000`, 4 accounts `[open_orders, owner, destination, market]`), spanning 13 markets and 5 owner PDAs, CPI-invoked via programs `72K97smKVfVtf1fam4s5w2D2msLTeHwoKsjQn9uqVg17` → `22Y43yTVxuUkoRKdm9thyRhQ3SdgQS7c7kB6UNCiaczD`. Interpretation: automated **rent reclamation** from OpenOrders accounts owned by those programs — not trading, not fee sweeps. No settle_funds / sweep_fees / new-order activity observed.

## 5. Extractable / stuck value

| Category | USD | Detail |
|---|---:|---|
| **E-U** (external unprivileged) | **$0** | every vault outflow is owner- or key-gated (§6); no `CloseMarket`; 0 disabled markets would only block trading anyway |
| **H-O** (owner-recoverable) | **$11,558,070.47** | $11,281,757.02 deposits + $276,313.45 referrer rebates; only each OpenOrders owner can `settle_funds` |
| **P** (key/privileged) | **$2,587,491.80** | accrued fees; only signer `DeqYsmBd9BnrbgUwQjVH4sQWK71dEgE6eoZFw3Rp4ftE` can `sweep_fees`; plus program upgrade via `6XvcBmET…` |
| **S** (stuck) | **~$225.6K** + extras | true rent **1,864.70 SOL** (market base 1.43 + req_q 10.40 + event_q 1,487.37 + bids/asks 363.86 + vault token accounts 1.64) + **49.43 SOL** of extra lamports sitting in market accounts; plus fees if the fee-sweeper key is lost |

Rent is locked: both programs lack a `CloseMarket` instruction (discriminators 0–20 only); bids/asks/event_q/req_q/market/vault accounts are program-owned with no lamport-out path. (SOL/USDC's coin vault holds 20,290 SOL of **wrapped SOL** — an asset, not rent; it was excluded from the rent figure.)

## 6. Drain-path verification (Serum v3 vs OpenBook v1)

| Instruction (disc) | Gate in Serum v3 (`serum-dex` state.rs) | OpenBook v1 (`openbook-dex/program` state.rs) |
|---|---|---|
| `SettleFunds` (5) | `process_settle_funds` @2918; `load_orders_mut(open_orders, Some(owner))` @159–196 enforces `open_orders.owner == owner.key` and `open_orders.market == market`; `owner` is a required signer in `SettleFundsArgs`; payout only of `native_*_free`; CPI signed by `gen_vault_signer_seeds(nonce, market_pubkey)` (runtime enforces the PDA) | identical: settle @2795, vault seeds @2845 |
| `SweepFees` (8) | `SigningFeeSweeper` requires `account.key == fee_sweeper::ID` **and** `is_signer` (@1524/1566); ID `DeqYsmBd9…` | same pattern @1566 (ID `GTgd6NaobHDLSFAh2kG5DTNsL4SBJH42Qq11jpjWCfXA`) |
| `DisableMarket` (7) | `SigningDisableAuthority` @1530/1572; ID `5ZVJgwWxMsqXxRMYHXqMwH2hd4myX5Ef4Au2iUsuNQ7V` | same @1572 |
| `CloseOpenOrders` (14) | owner signer + zero balances; rent to destination | same @2773 |
| `InitOpenOrders` (15) | permissionless for V1 markets (`open_orders_authority` = None) but only initializes an account; no value transfer | same |
| `Prune` (16) | requires `market.prune_authority()`; None for all V1 markets | same |

On-chain authority checks (slot 453,212,002): fee_sweeper `DeqYsmBd9…` **does not exist** (0 lamports; key status unknown → fees P/S); disable authority `5ZVJgw…` exists as a system EOA with 194,422,050 lamports, no data; upgrade authority `6XvcBmETaz5ZNRhwiz1ochXitHG771d6rmK4Ug3NVr1g` is a system EOA (2,500,000 lamports) and is **still active** on programdata `DTxcpNApaMLNfYgwQ99PmpCm8rjS7o1q2YdfzYsrYohB` (494,866 B). No attacker-controlled PDA or signer exists in any vault path: vault payouts can only be signed by the per-market PDA derived from `sha256(market_pubkey || nonce_le)`.

**Verdict: live external-unprivileged extraction = $0 (confidence high).** The $14.15M in vaults is H-O/P; the ~$2.9M accounting gap to DefiLlama sits in 2023–2026 permissionless markets outside the registries; the remaining zombie value is ~1,900 SOL of permanently locked rent.

## 7. Caveats

- Union registry (402) may still miss markets; the DL-vs-measured gap shows ~$3.0M of value in such markets. A working gPA endpoint (paid RPC) would close this.
- OpenOrders accounts were **not** enumerated (gPA blocked). Owner-only rent recovery from them is H-O, not E-U; claimed-zeroed-shell theft was not re-checked for Serum v3 (parent's OpenBook census found 0 shells; Serum v3 status unproven).
- USD values move with prices; measurement prices are DefiLlama 2026-10-04 (SOL $120.98).
- Some mints are unpriced/spam; their vault value is ~$0.

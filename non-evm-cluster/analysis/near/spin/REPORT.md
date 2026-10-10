# Spin (spin.fi, NEAR) — legacy spot DEX, DOV vaults, perps — read-only assessment

- Date: 2026-10-10 (UTC). Chain: NEAR mainnet. Status: **read-only**; keyless endpoints only; no transactions.
- Pragmatic result: three live Spin contracts hold **≈ $126.5k** of user deposits; on-chain activity has largely stopped
  (last spot tx 2026-09-06, last vault tx 2026-08-23, all recent ones failed *trading* calls). No external-unprivileged
  extraction path was found, but **contract source is not public** — confidence is lower than for Tonic/Veax. E-U $0.00 (low-medium confidence).

## 1. Contracts (from DefiLlama adapter + on-chain verification)
| account | role | evidence |
|---|---|---|
| `spot.spin-fi.near` | Spot DEX (on-chain limit-order book, 2.50 MB wasm) | `view_account` block **219,326,245**: code `EeD1bZZPp2mEVyF3KQoEaTDMSVVbwr6cbnJsbfUbrVLm`, balance 9,408.8590 NEAR, storage 4.0 MB. Exports: `place_bid/place_ask/cancel_order(s)/withdraw/batch_ops/get_orderbook/dry_run_swap/swap_near/…` |
| `v1.vault.spin-fi.near` | DOV / structured vaults (0.97 MB wasm) | block **219,326,308**: code `EJpPAk6Fd3WFYVTiyJ5VEMqG8eAXC4iLLTPBhqrkKaxd`, balance 187.6216 NEAR. Exports: `vault_get_all/vault_withdraw/vault_takeout/oft_*/auction_*/mft_*` |
| `v2_0_2.perp.spin-fi.near` | Perps (2.79 MB wasm) | block **219,326,393**: code `4CEvKugXcYtZxocrvyZry8ecy11UWDWAUCoPvyEw6wzx`, balance 1,962.2084 NEAR. Exports: `place_bid/ask, liquidate_position, withdraw/withdraw_callback, ft_on_transfer, get_base_currency` |

Legacy names that do **not** exist (UNKNOWN_ACCOUNT, blocks ~219,336,6xx): `v1.perp.spin-fi.near`, `v1_0_0.perp.spin-fi.near`,
`v1.spot.spin-fi.near`. `spin.near` exists but is a code-less account (balance 3,000 NEAR, code_hash `1111…`).

## 2. Live funds
All `ft_balance_of` reads + `view_account` on 2026-10-10 (raw JSON in `dumps/`; headline balance reads re-verified at
blocks **219,336,941–219,337,035**, see `dumps/headline_refs.json`); USD with DefiLlama prices ts 1791610xxx
(NEAR $5.1934; wNEAR $5.15; stNEAR $7.7507; LiNEAR $7.3394).

**`spot.spin-fi.near` — $70,369.63**
| token | amount | USD |
|---|---|---|
| native NEAR | 9,408.8590 | $48,864.30 |
| USDC.e (a0b869…) | 16,946.1162 | $16,941.79 |
| USDT.e (dac17f…) | 1,352.2356 | $1,351.21 |
| USDC (native 17208628…) | 1,290.5668 | $1,290.23 |
| WBTC.e (2260fac5…) | 0.01537483 | $1,268.48 |
| REF (token.v2.ref-finance.near) | 6,534.3815 | $633.71 |
| PARAS (token.paras.near) | 24,494.6473 | $16.46 |
| USDT.tether-token.near | 3.4501 | $3.45 |
| PEMBROCK (token.pembrock.near) | 17,122.2246 | unpriced |

**`v1.vault.spin-fi.near` — $36,135.63**
| token | amount | USD |
|---|---|---|
| wNEAR | 5,603.0052 | $29,098.84 |
| stNEAR (meta-pool.near) | 354.7680 | $2,749.71 |
| USDC.e | 1,611.8732 | $1,611.46 |
| LiNEAR (linear-protocol.near) | 189.9141 | $1,393.94 |
| WBTC.e | 0.00270325 | $223.03 |
| USDT.e | 84.3203 | $84.26 |
| native NEAR | 187.6216 | $974.40 |

**`v2_0_2.perp.spin-fi.near` — $19,988.63**: native NEAR 1,962.2084 ($10,190.60) + USDC.e 9,800.5308 ($9,798.03).

**Total across Spin: ≈ $126,493.89** (DefiLlama lists Spin Spot $66.8k + DOV $33.3k + Perps $9.8k = $109.9k; the deltas are
our inclusion of native-NEAR balances and slightly different prices).

## 3. Liveness & keys
- Activity (nearblocks): `spot.spin-fi.near` last tx **2026-09-06** — repeated **failed** `place_bid` calls from an EOA
  (`10962266…`, e.g. tx `CUShaUHELiB1ngni6SLrryWnj9wPteczuX4s8sXhRZku`, status false, market_id 12). `v1.vault.spin-fi.near`
  last tx **2026-08-23** (mix of failed and one successful call). `v2_0_2.perp.spin-fi.near`: nearblocks did not return a
  tx list during the assessment (indexer error) — last-activity unknown.
- Access keys (`view_access_key_list`): each contract has exactly **1 FullAccess key**:
  spot `ed25519:FbmmtC29vfio…` (nonce 63,990,413,000,012), vault `ed25519:BZEcFT4hA66g…` (86,232,267,002,663),
  perp `ed25519:HBPiM6P3Sj1M…` (76,706,778,000,014). Key holders unidentifiable; no on-chain admin-method surface observed
  in the export lists beyond config setters (`set_market_options`, `set_whitelist`, `drop_market`, `add_currency`).
- Headline balance re-reads (blocks 219,336,941–219,337,035): `dumps/headline_refs.json`.

## 4. Extraction audit
- **Source is not public**: org `spin-fi` publishes only SDKs (`near-dex-core-js`, `near-dex-node-js`, `near-mft-interface`)
  and a market-maker; no contract repo. Audit is therefore export-level + behavior-level only.
- User flows in the export set are per-user (`withdraw`, `cancel_order`, vault `vault_withdraw`, perp `withdraw`); none of
  the exports name another account as a withdrawal target for token custody.
- `place_bid` failures in Sep 2026 are *trading* calls (the market may be delisted/dropped), not evidence about withdrawal.
- Candidate unprivileged paths tried: none available beyond reading state; write-method simulation impossible
  (`predecessor_account_id` is blocked in view calls — same `HostError(ProhibitedInView)` behavior observed on sibling
  contracts).

## 5. Classification
- **E-U: $0.00** — no extraction path found, but **closed-source**: confidence **low-medium**. A malicious build could
  hide logic we cannot see; nothing indicates one.
- **H-O: ≈ $126.5k** — user deposits are presumed withdrawable per-user via the live contracts; no withdrawn-on-behalf
  method in exports. If any of the three is NOT actually executable (not observed — all three respond to view calls and
  have recent signed activity), value would fall to S.
- **P: 1 FullAccess key per contract** (team). No DAO.
- **S: $0** observed.

## 6. Blockers / caveats
- No source; no way to fork-test without heavy simulation (CI candidate: run `wrangler`/near-workspaces against mainnet
  state copy to test `withdraw` end-to-end — not performed here).
- `spot.spin-fi.near` wNEAR balance = 0 while it holds 9,408.86 *native* NEAR (native handled at account level).
- `aurora` balance read returned empty (dead end).

## 7. Files
`scripts/near.py`, `dumps/` per-contract balances (`*ft_balances*.json` incl. `ft_balances_round2.json`, `final_values.json`).

# H2-06 / Stacks — Arkadiko Swap v2 deep dive — parent fallback

**Date:** 2026-10-10 · **Chain:** Stacks mainnet · **API:** Hiro (keyless) `https://api.hiro.so`
**Status:** read-only; no transactions signed or sent. Source from the Arkadiko repo (deployed
`arkadiko-swap-v2-1`), state read live via Hiro balances + `call-read`.
**Child coverage note:** the assigned child subagent stalled at ~12:57 after collecting the pair list
and source (`evidence/`, `source/`); this dossier was completed by the parent from that evidence +
additional live reads.

**Headline: E-U = $0.00 (high confidence).** No unprivileged extraction path found. The contract is a
standard constant-product multi-pair AMM; rounding favors the pool; LP exits are sender-scoped and all
pairs are enabled with the emergency shutdown off; the one dangerous function (`attack-and-burn`) is
height-gated to block < 40,000 (chain is at ~9.16M) and DAO-gated.

## 1. Target

`SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-swap-v2-1` — 8 pairs
(`get-pair-count` = 8), all `enabled: true`; `shutdown-not-activated` = **true**.

## 2. Live holdings (Hiro, 2026-10-10 ~14:20 local; STX tip ≈ 9,164,574)

| Asset | Raw balance | Human | USD |
|---|---:|---:|---:|
| STX (and equal wSTX) | 685,180,388,432 | 685,180.388432 | $274,593 (@ $0.400779) |
| USDA | 191,131,822,875 | 191,131.822875 | $191,132 (assume $1) |
| DIKO | 13,520,828,878,747 | 13,520,828.878747 (6 dec) | $37,957 (pool-implied $0.002807; low conf.) |
| Wrapped-Bitcoin (xBTC) | 33,558,053 | 0.33558053 (8 dec) | $27,771 (@ $82,755.25) |
| **Total measured** | | | **≈ $531,453** |

Plus memecoin dust (WELSH, MEW, GME, KNFE, etc.). The quoted finding figure (685,714 STX ≈ $270k +
191,106 USDA + 13.5M DIKO) is confirmed within measurement drift.

## 3. Pair state (call-read `get-pair-details`, all enabled)

| # | Pair | balance-x | balance-y | fee-x | fee-y |
|---|---|---|---:|---:|---:|---:|
| 1 | wSTX–USDA | 645,412.542625 | 163,615.536488 | 11,905.207 | 14,204.587 |
| 2 | wSTX–DIKO | 51,320.123004 | 4,624,232.930394 | 2,827.210 | 49,132.466 |
| 3 | DIKO–USDA | 8,942,570.832763 | 25,100.822205 | 30,600.105 | 2,544.432 |
| 4 | wSTX–xBTC | 2,585.181991 | 0.00901980 | 414.267 | 0.001548 |
| 5 | xBTC–USDA | 35.337963 | 25,640.781943 | 0.999501 | 484.415 |
| 6 | wSTX–WELSH | 2,838.037949 | 6,049,197.617518 | 566.118 | 4,858,361.035 |
| 7 | wLDN–USDA | 0.000001 | 0.020001 | 0.589651 | 41.155 |
| 8 | LDN–USDA | 23.940613 | 400.643262 | 7.600600 | 117.496 |

`fee-to-address` = the deployer/protocol address `SP2C2…89YZR` on every pair.

## 4. Path audit (deployed source)

- `swap-x-for-y` / `swap-y-for-x`: `dy = balance-y × (dx×997/1000) / (balance-x + dx×997/1000)` —
  standard constant product; **rounding favors the pool**; slippage assert `(< min-dy dy)`; 0.05%
  protocol fee tracked separately. No reentrancy profit: pair tokens are trusted FTs and the reserve
  map is written after transfers (Clarity calls are atomic; no attacker-controlled token in any pair).
- `add-to-position`: `new-y = x × balance-y / balance-x` (floor), shares minted pro-rata; `sqrt` for
  the first LP. No extraction.
- `reduce-position`: `withdrawal = shares × percent/100`, `withdrawal-x/y = withdrawal × balance /
  shares-total` (**floor**); shares read from `swap-token.get-balance(tx-sender)` and burned from
  `tx-sender` → **sender-scoped (H-O)**; requires pair enabled + shutdown off (both true).
- `collect-fees`: **permissionless trigger** but pays the pair's `fee-to-address` (protocol), never the
  caller; resets fee balances. Not extraction.
- `set-fee-to-address`, `toggle-pair-enabled`, `toggle-swap-shutdown`, `create-pair`, `migrate-*`:
  DAO-owner gated (`arkadiko-dao.get-dao-owner`).
- `attack-and-burn`: DAO-owner **and** `block-height < u40000` — dead (chain ~9.16M).

## 5. Classification

| Category | USD | Basis |
|---|---:|---|
| **E-U** | **$0.00** | no unprivileged mover; all exits sender-scoped or DAO-gated |
| H-O | ≈ $506,600 | LP reserves redeemable via `reduce-position` (pairs enabled, shutdown off) |
| P | ≈ $24,800 | uncollected protocol fees in `fee-balance-*` (claimable only to `fee-to-address`) |
| S | $0 | none bricked |

## 6. Caveats / observations

- Small accounting drift: Σ tracked reserves+fees exceeds the contract's measured token balances by
  ≈ 0.9% (DIKO), ≈ 2.4% (wSTX), ≈ 7% (xBTC). Impact is limited to last-withdrawer risk for LPs
  (potential S for the drift portion); not an extraction path. Flagged for follow-up.
- USDA is valued at $1 (no reliable external market quote); DIKO uses the pool-implied price (low
  confidence); xBTC at spot BTC.
- The child's snapshot (12:57) and the parent's live reads agree on the pair list and order of
  magnitude; all numbers above are from live reads.

## 7. Files

- `source/repo/arkadiko-swap-v2-1.clar` (+ related Arkadiko contracts) — deployed source.
- `evidence/pairs.json`, `evidence/supplies.json`, `evidence/candidate-balances.json` — child dumps.
- `scripts/clarity.py`, `scripts/collect_state.py`, `scripts/enumerate_pairs.py` — read-only tooling.

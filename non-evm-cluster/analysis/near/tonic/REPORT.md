# Tonic (tonicdex, NEAR) — spot order-book DEX + perps v1 — read-only assessment

- Date: 2026-10-10 (UTC). Chain: NEAR mainnet. Status: **read-only**; keyless endpoints only; no transactions.
- Pragmatic result: two live contracts hold **≈ $38.8k** of user funds (DefiLlama: $37.87k). Spot is `Active`, perps is
  `Running`, but the perps venue has seen no successful transaction since **2024-04-10** and the spot book's last calls
  (2026-04-30) were failing. Open-source (tonic-foundation) — user withdrawals are sender-scoped and the order-book
  contract's owner is the contract itself (admin externally frozen). E-U $0.00 (medium-high confidence).

## 1. Contracts (on-chain verified + DefiLlama adapter + public source)
| account | role | evidence |
|---|---|---|
| `v1.orderbook.near` | Tonic spot CLOB (owner per DefiLlama adapter) | `view_account` block **219,326,421**: code `2HL5pnkfUhyeAjmjAK9XPjNxH3WaGxSnbwaYVn6kNiY9`, balance 1,883.8838 NEAR, storage 637 KB. State `Active` (block **219,336,523**); `get_owner` → **`v1.orderbook.near` itself** (block 219,336,534); `get_number_of_markets` = 40 (block 219,336,545) |
| `v1.tonic-perps.near` | Tonic perps v1 (LP + margin) | block **219,326,555**: code `56i44yAoBEARN9XBxaftKXizq75R8JWpJaYV3Nnj735F`, balance 1,678.2499 NEAR. `get_contract_state` = **Running** (block 219,336,556); `version` = `tonic-perps:0.1.0` (219,336,566); `get_total_aum` = `50220756048` = **$50,220.76** @6-dec dollar units (219,336,576) |
| source | `tonic-foundation/tonic-core` (`tonic-dex`), `tonic-foundation/tonic-perps-v1` | deployed export lists match the repos' entry points |

## 2. Live funds
`ft_balance_of` + `view_account` reads on 2026-10-10 (blocks recorded in `dumps/balances_round2.json` / `balances_tonic.log`);
USD with DefiLlama prices ts 1791610xxx (NEAR $5.1934).

**`v1.orderbook.near` — $26,593.45**
| token | amount | USD |
|---|---|---|
| native NEAR | 1,883.8838 | $9,783.83 |
| USDC.e (a0b869…) | 10,473.6371 | $10,470.96 |
| stNEAR (meta-pool.near) | 524.0911 | $4,062.08 (@$7.75) |
| USDT.e (dac17f…) | 1,166.0196 | $1,165.14 |
| USDT.tether-token.near | 1,111.5510 | $1,110.70 |
| META (meta-token.near) | 0 | $0 |
| WBTC.e (2260fac5…) | 0.00000903 | $0.75 |

**`v1.tonic-perps.near` — $12,196.48**: native NEAR 1,678.2499 ($8,715.88) + USDT.tether-token.near 3,483.2640 ($3,480.60).
(LP/position accounting `total_aum` = $50.22k is a book number on top of the tokens actually held; open positions/leverage
explain the gap.)

**Total Tonic ≈ $38,789.93** (matches DefiLlama `tonic` $37,873.53 within snapshot/prices).

## 3. Liveness & keys
- Activity (nearblocks): `v1.orderbook.near` last txs **2026-04-30** — calls from `yellowbrickroad.near`/`sunnysideup.near`
  that **failed**, plus a successful self-call (`v1.orderbook.near` → itself at block 196,307,526). `v1.tonic-perps.near`:
  last **successful** tx **2024-04-10** (`ytb-01.near`, block 116,567,515); failures in Dec 2023.
- Access keys: `v1.orderbook.near` = 2 FullAccess + 1 FunctionCall(self); `v1.tonic-perps.near` = 2 FullAccess.
- The spot order book's owner is set to the contract itself → **no external account can pause/delist it** (admin self-calls only).

## 4. Extraction audit (source-verified)
`tonic-core/tonic-dex`:
- `balances.rs:38/47/57` `withdraw_near` / `withdraw_ft` / `withdraw_mt`: `assert_active()`, `assert_one_yocto()`,
  `account_id = env::predecessor_account_id()` → `internal_withdraw(account_id, …)`. **Sender-scoped**, cannot touch others.
- `lib.rs:111` `assert_is_owner` (predecessor == `owner_id`) gates all `admin.rs` setters (`set_owner`, `set_market_state`,
  `set_market_*_window`, `admin_cancel_order(s)`, `admin_clear_orderbook`, `admin_delete_market`) and rate settings.
- `exchange_callback_post_withdraw` is `#[private]` with revert-on-fail semantics.
- Spot contract state = `Active`; gate `assert_active()` is satisfied, so withdrawals execute.

`tonic-perps-v1`:
- `lp_token/mint.rs:169` `burn_lp_token` → `assert_running()` and
  `let account_id = env::predecessor_account_id(); contract.burn_lp_token(&account_id, …)` → **sender-scoped**.
- `admin.rs` uses `require_predecessor!(self.owner_id, "caller must be owner")` / `assert_admin` role checks for
  `set_state`, asset params, fees, `upgrade`, etc. `withdraw_fees` is admin-only.
- Deployed state = `Running` (per `assert_running()` gate satisfied).

Candidate unprivileged paths tried: static analysis only (write-method view simulation blocked by
`HostError(ProhibitedInView)`); no permissionless path found that moves another account's balance.

## 5. Classification
- **E-U: $0.00** — no drain path found in open source. Confidence: **medium-high** (source matches deployed export list;
  perps repo version vs deployed 0.1.0 assumed 1:1 on the relevant paths).
- **H-O: ≈ $38.8k** — users withdraw their own balances while contracts are Active/Running (both gates currently satisfied).
- **P: owner(s)** — perps has an external owner (admin/upgrade); spot order book's owner = itself (no external admin).
  Neither has a method to take user balances.
- **S: $0** observed — note the perps venue is dormant (no successful activity since Apr 2024); if the team ever set the
  perps state away from Running, `assert_running` would freeze user burns/withdrawals (watch item, not current).

## 6. Blockers / caveats
- `aurora` token balance read returned empty (dead end).
- `get_total_aum` is a book metric; only token balances were counted as live value.
- v1.tonic-perps.near nearblocks last-success evidence predates the RPC retention window, so it was taken from nearblocks
  index (block 116,567,515, 2024-04-10) — no on-chain re-verification possible.

## 7. Files
`scripts/balances_tonic.py`, `scripts/near.py`, `dumps/balances_round2.json`, `dumps/balances_tonic.log`,
`dumps/v1.orderbook.near.ft_balances.json`, `dumps/v1.tonic-perps.near.ft_balances.json`, `dumps/final_values.json`.

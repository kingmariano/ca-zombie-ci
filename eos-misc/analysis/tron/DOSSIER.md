# JustLend V2 (TRON) — "Moolah" Morpho-Blue fork — extractability dossier

- Date: 2026-10-10 · chain: TRON · status: **read-only; no transactions signed/sent**
- Latest block at close: **86,991,223** (15:34 UTC). State reads executed between blocks 86,991,072–86,991,223.
- Target: the "$1.69M AccessControl-gated" H2-05 lead. Re-checked from scratch; corpus lead treated as a hypothesis.

## TL;DR

| Target | Live extractable (unprivileged) | Class | Why closed/open |
|---|---|---|---|
| MoolahProxy `TDH4dhmVQQNc1ZNudJwWzBcs2h6ahhWrpp` (+impl `TKEiKtSaqUboeBmZxcSp8Z2CJUDGk4BT3a`) | **$0 proven-by-gate** (medium confidence) | **E-U $0** | `liquidate()` is whitelist-gated to 2 addresses (LiquidatorProxy, PublicLiquidatorProxy). User flows are standard Morpho accounting; no empty-market asymmetry; not paused; no unguarded rescue/fee path in the 105-entry ABI. |
| Same system, user self-service | **$1,699,173.53** claimable by depositors/borrowers | **H-O** | `withdraw`/`repay`/`withdrawCollateral` unpaused; proxy holds the value. |
| Same system, admin control | roles: ADMIN 1, MANAGER/OPERATOR 2, PAUSER 1, feeRecipient 1 | **P** | `setFee`, `setFeeRecipient`, `enableIrm/Lltv`, `add/removeProvider`, whitelists, `pause()`. |
| Stuck value found | none | **S $0** | — |

Cross-checks: proxy token value measured **$1,699,173.53** ≈ DefiLlama JustLend-V2 TVL **$1,698,609.42** (Δ0.03%); market loan-side borrow totals **$515,216** ≈ DefiLlama borrowed **$515,329.63**. The $1.69M figure is real and located.

## 1. What the contracts are

- `TDH4dhmVQQNc1ZNudJwWzBcs2h6ahhWrpp` — **MoolahProxy** (TronScan blueTag "JustLend DAO", is_proxy=true), created 2026-04-07. **Source not verified** on TronScan (`verify_status: 0`).
- Impl `TKEiKtSaqUboeBmZxcSp8Z2CJUDGk4BT3a` — contract name **Moolah** (105 ABI entries) — a **Morpho Blue fork**, not a Compound fork. The DefiLlama adapter `projects/justlend-v2/index.js` confirms: `morphoBlue = TDH4dhm…`, markets discovered from `CreateMarket` logs.
- Single oracle for all markets: `TUDXEUA6hNiWPm54cMifoxCZU28zRu6bPc`. IRM for all markets: `TSsuwbvUKAVgRmSghXT7i38PgHWpW12wQ1` ("IrmProxy"). All 9 markets have LLTV **80%**.
- AccessControl present: `DEFAULT_ADMIN_ROLE`, `MANAGER`, `OPERATOR`, `PAUSER`, `grantRole/revokeRole/renounceRole`, `getRoleMembers`.

## 2. Live role / gate state (block ~86,991,100)

| Role | Members |
|---|---|
| DEFAULT_ADMIN_ROLE (1) | `TZJVQuU3CJqBScwoxhRtkxQ7JjsNNrpEag` (EOA) |
| MANAGER (2) | `TTY7rV1BpKXNnZCuRTqpM19tyZJW5ExXMa` (EOA), `TKKX9qYdRvnTmAaxEYv8VfFpzXzt3PEe2w` (UpgradableProxy) |
| OPERATOR (2) | same two |
| PAUSER (1) | `TTY7rV1BpKXNnZCuRTqpM19tyZJW5ExXMa` |
| feeRecipient | `TMzGb5Ma85oYMcnmVFjhvS1HYr6MRSspmE` ("LendingFeeRecipientProxy") |
| paused() | **false** (all user flows open) |
| defaultMarketFee() | 0.1e18 (10%) |

**Liquidation whitelist (identical for every market read):**
`TKX8nUY8otA4d9qV1tDuN5BLSrxkr9pWa6` ("LiquidatorProxy"), `TGDuQaHtvadVL5z9PMM874CaehQnwf3qJi` ("PublicLiquidatorProxy") — both contracts.
`addLiquidationWhitelist`/`removeLiquidationWhitelist`/`batchToggle…` exist and have been used 18+ times in the last 771 txs. `liquidate()` is therefore **whitelist-gated**; an unprivileged address cannot seize collateral directly.

## 3. Markets (all recovered from calldata of the 771 most recent proxy txs)

All share oracle `TUDXEUA6…`, IRM `TSsuwbvU…`, LLTV 80%. USD at DefiLlama prices ts≈1791645775–1791646378.

| market id (prefix) | loan | coll | supply USD | borrow USD |
|---|---|---|---|---|
| 55e29973d468bf8d | WTRX | sTRX | 44,097.89 | 19,693.46 |
| 7903ec42a7e2e156 | USDT | BTC | 122,412.74 | 110,545.52 |
| 6f0d54e852416494 | USDT | WTRX | 133,742.08 | 116,952.57 |
| 646a4772e629c9a6 | USDT | sTRX | 131,473.71 | 123,571.98 |
| 92355a00c4958500 | USDD | sTRX | 108,677.43 | 97,468.89 |
| 7ad8b9c73e6b4eaf | WTRX | USDT | 33,166.22 | 26,371.88 |
| 0a9b9d2d1b4c6985 | USDD | WTRX | 92,227.66 | 20,378.67 |
| 5f06384a9e0878b5 | WTRX | USDD | 28,934.51 | 233.48 |
| (9th tuple WTRX/USDD seen; active) | WTRX | USDD | — | — |

No empty/insolvent-market asymmetry: no market has borrows with ~zero supply; smallest supply is $28.9k; totals balanced.

## 4. Value composition held by the proxy (on-chain `balanceOf`, block ~86,991,100)

| token | amount | price | USD |
|---|---|---|---|
| sTRX `TU3kjFuhtEo42tsCBtfYUAZxoqQ4yuSLQ5` | 1,663,286.1989769859 | 0.441902057 | 735,009.59 |
| BTC `TN3W4H6rK2ce4vX9YnFQHwKENnHjoxb3m9` | 5.16925034 | 82,364.9378 | 425,764.98 |
| WTRX `TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR` | 985,447.205022 | 0.33100229 | 326,185.28 |
| USDT `TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t` | 128,651.114117 | 0.99916544 | 128,543.75 |
| USDD `TXDk8mbtRbXeYuMNS83CfKPaYYT8XWv9Hz` | 83,889.448613 | 0.99738317 | 83,669.92 |
| **Total** | | | **$1,699,173.53** |

## 5. Verdict

- **E-U = $0** (medium confidence). The only path that transfers other users' principal to an attacker is liquidation, and it is restricted to two whitelisted liquidator contracts. Remaining user entry points (`supply`, `borrow`, `repay`, `withdraw`, `withdrawCollateral`, `accrueInterest*`) move only the caller's own position under standard Morpho accounting. No unguarded `_reduceReserves`/`rescue`/`seize`-style function is in the live ABI; no Compound-style empty-market exploit applies (not a Compound fork; all 9 markets funded; single oracle).
- **H-O = $1,699,173.53**: depositors' self-service claims (unpaused).
- **P**: roles above can pause the system, set fees/whitelists/markets.
- **S = $0** found.

What would change the verdict: verified source showing `liquidate()`/`withdraw()` checks bypassable; a manipulable oracle `TUDXEUA6…` (not reviewed here); a permissionless path through `PublicLiquidatorProxy` that pays the caller outside standard liquidation economics (not reviewed).

## 6. Evidence commands (all keyless, read-only)

```bash
# block
curl -s -X POST https://api.trongrid.io/wallet/getnowblock -d '{}'
# proxy + impl code/ABI
curl -s -X POST https://api.trongrid.io/wallet/getcontract \
  -H 'Content-Type: application/json' \
  -d '{"value":"TDH4dhmVQQNc1ZNudJwWzBcs2h6ahhWrpp","visible":true}'
# live reads (example: paused / liquidation whitelist / market id)
curl -s -X POST https://api.trongrid.io/wallet/triggerconstantcontract -d '{
 "owner_address":"TFm8zsJWupMKbeXhFFAWKwc41igiFJ9nHb",
 "contract_address":"TDH4dhmVQQNc1ZNudJwWzBcs2h6ahhWrpp",
 "function_selector":"paused()","parameter":"","visible":true}'
curl -s -X POST https://api.trongrid.io/wallet/triggerconstantcontract -d '{
 "owner_address":"TFm8zsJWupMKbeXhFFAWKwc41igiFJ9nHb",
 "contract_address":"TDH4dhmVQQNc1ZNudJwWzBcs2h6ahhWrpp",
 "function_selector":"getLiquidationWhitelist(bytes32)",
 "parameter":"55e29973d468bf8d5122bf3121eccf691e1db40751c9866551d32294ec73c1a4","visible":true}'
# token balances + prices
curl -s -X POST https://api.trongrid.io/wallet/triggerconstantcontract -d '{... "contract_address":"TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t","function_selector":"balanceOf(address)","parameter":"0000000000000000000000002448e1164835739dbace1c227f51cb6c8791e990","visible":true}'
curl -s "https://coins.llama.fi/prices/current/tron:TU3kjFuhtEo42tsCBtfYUAZxoqQ4yuSLQ5,tron:TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
```

Raw JSON dumps saved in this folder: `getcontract_proxy.json`, `getcontract_impl.json`, `market_reads.json`, `markets_decoded.json`, `state_raw.json`, `state_raw2.json`, `all_market_params.json`, `llama_prices.json`, `getnowblock*.json`, `ts_txs_proxy.json`, `tronscan_contract_{proxy,impl}.json`, `tronscan_methodMap_*.json`.

## 7. Blockers / uncertainties

1. **Unverified source** (TronScan `verify_status: 0` for proxy+impl; `getcontract` ABI is 105 entries and does not even decode the 4 hottest selectors seen in calldata, so the ABI is partial). All gate claims are from live ABI + live role/whitelist reads, not source review.
2. **Oracle contract `TUDXEUA6…` not reviewed** — a single oracle feeds all 9 markets; oracle-manipulation extraction cannot be excluded (unquantified residual risk).
3. `PublicLiquidatorProxy` name suggests a permissionless liquidation-execution lane; whether it pays non-whitelisted callers and how is unreviewed. Even if so, it is standard liquidation economics on genuinely unhealthy positions (bonus ≤ ~5%/12.5%), not principal extraction.
4. Per-position health was not enumerated; per-market liquidation capacity not simulated (no state-changing calls were made).

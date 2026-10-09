> **NOTE:** Partial, superseded supplementary scan — see README §8/§9 for the authoritative files (`analysis/main-obligation-stats.json`, `analysis/main-liquidation-eval.json`, `analysis/tail-liquidation-now.json`).

# Solend v1 obligations scan -- liquidatable / near-liquidation

- Program: `So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo`
- Scan window: slot **454779371** .. **454779385** (2026-10-09T06:00:13Z .. 2026-10-09T06:00:18Z UTC), public RPC only, sequential calls (~1.0s spacing)
- Targets: **1** markets (stored value >= $1,000 + main)
- Totals: **6** obligations scanned, **2** with debt, **1** liquidatable now, **0** near (>=95% of unhealthy threshold)
- Total debt in liquidatable positions: **$0** (per each obligation's stored values)
- Classification uses each obligation's own stored (last-updated) values; `stale=1` marks obligations not recently refreshed. Deposits are the collateral side; the liquidation path test is `borrowed_value >= unhealthy_borrow_value` with `unhealthy > 0`.

## Per-market counts

| market | name | storedUsd | nObligations | nWithDebt | nLiquidatableNow | nNear95 | liqBorrowedUsd | notes/errors |
|---|---|---|---|---|---|---|---|---|
| `CX1GCNCgkyPu45tqiiCqjqiaukzzEizMHHvqQNNqyk5g` | FUMoney | 3,410 | 6 | 2 | 1 | 0 | 0 | stale=6 |

## Top 30 largest liquidatable obligations (by stored borrowed value)

| # | market (name) | owner | borrowedUsd | unhealthyUsd | ratio | collateral deposits |
|---|---|---|---|---|---|---|
| 1 | `CX1GCN..` FUMoney | `FqRXiaGCPTknwME5xJDfKvTDctkMraBDqsVRcK7yG1kA` | 0.000000 | 0.000000 | 1.0000 | FUM 2e-09 |

## Method notes / caveats

- Full 1300-byte accounts were fetched for every liquidatable/near95 obligation (1 records; 1 accounts decoded).
- Validation: reserve-membership anomalies=0, deposit value mismatches=0, borrow value mismatches=0, malformed=0, vanished accounts=0, fetch failures=0.
- Slots differ slightly per market (each market has its own `slotAtScan` in obligations-counts.json); the scan is a point-in-time sequence, not an atomic snapshot.
- Obligation values are as of each obligation's last update slot; many positions have not been touched for months/years (see `stale` and `lastUpdateSlot` in the JSON). Liquidatability under *current* prices may differ from these stored values.
- Only reads: getSlot / getProgramAccounts / getMultipleAccounts against public, keyless endpoints; no transactions, no signing, no keyed RPC.

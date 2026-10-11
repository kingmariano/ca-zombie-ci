# Powercity Flex Protocol — oracle mechanics (from bytecode, verified on-chain)

PriceFeed address: `0x5f2529BC80bB9C0Bd7C417EA78CE2Cd6114B112C` (chain 369)
Status: **unverified on PulseScan** → mechanics established by (a) selector extraction,
(b) disassembly, (c) `debug_traceCall` (g4mm4 public RPC, callTracer), (d) storage reads,
(e) on-chain behaviour. All read-only.

## Selectors found in the runtime code

| selector | name | notes |
|---|---|---|
| 0x0fdb11cf | `fetchPrice()` | **state-changing, permissionless** — computes + SSTOREs slot 4 |
| 0x0490be83 | `lastGoodPrice()` | SLOAD slot 4 (237,809 at first read) |
| 0x8da5cb5b / 0x8f32d59b | `owner()` / `isOwner()` | owner = `0x751029C76DC1841fd8E9EF658eDD6d2dCDb1e07B` (EOA) |
| 0xd33219b4 | `timelock()` | `0x16986F263b9AcC844Ae3bB903155352F415CD9DC` (OZ TimelockController, minDelay=10s) |
| 0xac90534a | admin-only fn | reverts `"Only the admin can call this function"` for outsiders |
| 0xe2f273bd | `updateAdmin(address)` | nonpayable (owner) |
| 0x24105209 / 0x92b84357 | `upperBoundAnchorRatio` / `lowerBoundAnchorRatio` | 2.5e18 / 1 wei (anchor bounds, effectively vestigial) |
| 0x985bc65b | constant getter | **3600** (anchorPeriod, seconds) |
| 0xe9206d78 | constant getter | **420** — observation update interval used in `fetchPrice` |
| 0x8e499bcf / 0xe8315742 | `numTokens` / `maxTokens` | 4 / 30 |
| 0xd1b353b4 / 0x69aa3ac6 | `ethBaseUnit` / `expScale` | 1e18 |
| 0x276c2cba, 0x1a125204, 0x4da21942, 0x8a003888 | `getTokenConfigBySymbol/BySymbolHash/ByUnderlying/…` | Compound-style token configs |

Storage: slot0 owner, slot1 `oldObservations` map, slot2 `newObservations` map,
slot3 timestamp (0x69e9ac19 = 2026-04-23), slot4 `lastGoodPrice`, slot5 timelock, slot6 admin.

## What `fetchPrice()` does (traced + disassembled)

1. For each of 4 symbols — `WPLS_DAI`, `WPLS_USDC`, `HEX_WPLS`, `HEX_WPLS_V2` — it reads
   `price0CumulativeLast()`, `price1CumulativeLast()`, `getReserves()` from the configured pair
   and computes the current cumulative price (Uniswap-V2 oracle-library style extrapolation:
   `cum = cumLast + spot * (now - pair.blockTimestampLast)`).
2. Observation roll (function at 0x40c8): if `now - newObservations[symbol].timestamp >= 420`:
   `oldObservations = newObservations`; `newObservations = (now, cumulativeNow)`.
   **Anyone can trigger this** (it happens inside every `fetchPrice` call, incl. via TroveManager).
3. TWAP per symbol = `(newObs.acc - oldObs.acc) / (newObs.timestamp - oldObs.timestamp)`.
   → The window is **at least 420 s** and starts at the last roll; an attacker can roll it
   themselves at will, then only needs to hold a price move for ~421 s for it to be fully
   reflected in the TWAP. Flash-loan same-block manipulation is defeated by the 420 s window.
4. Final price blend (constants in code):
   `HEX_USD = (0.65 * HEX_WPLS + 0.35 * HEX_WPLS_V2) * WPLS_USD`,
   `WPLS_USD = (0.60 * WPLS_DAI + 0.40 * WPLS_USDC)` (60/40 over the two stable pairs).
   Prices are 1e8-scaled (8-decimal collateral scale).
5. `require(price > 0, "oracle: zero price")`; stores to slot 4; returns.

Pairs used (all PulseX V2):
- HEX/WPLS V1 `0xf1F4ee610b2bAbB05C635F726eF8B0C568c8dc65`
- HEX/WPLS V2 `0x19BB45a7270177e303DEe6eAA6F5Ad700812bA98`
- WPLS/DAI `0xe56043671df55dE5CDf8459710433C10324DE0aE`
- USDC/WPLS `0x6753560538ECA67617A9CE605178F788BE7E524e`

## Observed update history (explorer txlist on the PriceFeed)

- Apr–Aug 2026: 21 direct `fetchPrice()` pokes from `0x16923b…` (30–120 s cadence, bot),
  3 from `0x407bb6…`, 1 from `0x3b176f…` — **all unprivileged EOAs**, confirming the function
  is permissionless in practice.
- Last direct poke: 2026-08-06 (block 27,229,077). Trove operations since (e.g. 2026-10-10/11)
  also call `fetchPrice()` internally, keeping observations fresh.

## Admin/timelock surface (P — privileged, not attacker-reachable)

- TroveManager/BorrowerOperations `setAddresses` is `onlyOwner` **and immediately calls
  `_renounceOwnership()`**; `owner()` = 0x0. No re-init path.
- `TroveManager.updatePriceFeed(address)` is `onlyTimelock`; timelock is an OZ
  TimelockController (minDelay 10 s). None of the observed EOAs hold PROPOSER/EXECUTOR roles
  (checked `hasRole` for the 4 relevant addresses).
- PriceFeed owner/admin = `0x751029C76DC1841fd8E9EF658eDD6d2dCDb1e07B` (EOA, no code).

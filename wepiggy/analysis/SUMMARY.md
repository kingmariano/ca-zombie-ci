# WePiggy (C2-15) — consolidated class audit & negative results

Read-only on-chain research. No transactions were signed or sent to any real network.
All exploit attempts were run on local forks (GitHub Actions, `wepiggy/poc`).

## 1. Deployments audited

| Chain | Comptroller (Unitroller) | Block | Markets | Cash (USD) | Code |
|---|---|---|---|---|---|
| Ethereum | `0x0C8c1ab017c3C0c8A48dD9F1DB2F59022D190f0b` | 26,150,020 | 10 | $508,039 | `PERC20` impl `0x465461657b4175c1676ecea1fb0e8d0174d8d7f6`; `Comptroller` impl `0x81ed5efd9477106f898733e47e9ec7738fa3e00c` (both verified, solc 0.6.12) |
| Arbitrum | `0xaa87715E858b482931eB2f6f92E504571588390b` | 512,965,180 | 6 | $83,147 | same fork lineage (verified) |
| Optimism | `0x896aecb9E73Bf21C50855B7874729596d0e511CB` | 157,942,842 | 7 | $72,001 | same fork lineage (verified) |
| BSC | `0x8c925623708A94c7DE98a8e83e8200259fF716E0` | 126,492,407 | 16 | $52,754 | same fork lineage (verified) |

Per-market tables: `eth.md`, `arb.md`, `op.md`, `bsc.md` (children's raw dumps in `*-markets.json`).

Value classification (DefiLlama prices at query time):

| Chain | Cash | Supplier claims (H-O) | Reserves (P, owner-only) | Borrows |
|---|---|---|---|---|
| Ethereum | $508,039 | $155,329 | $358,549 | $5,839 |
| Arbitrum | $83,147 | $45,317 | $43,109 | $5,279 |
| Optimism | $72,001 | $81,917 | $7,013 | $16,929 |
| BSC | $52,754 | $53,148 | $9 | $403 |
| **Total** | **$715,941** | **$335,711** | **$408,680** | **$28,450** |

`cash = claims + reserves − borrows` (per chain). **Reserves are withdrawable only via
`_reduceReserves` (`onlyOwner`)** — the owner is a Gnosis Safe **4-of-7** at
`0x8114b3854d1e7b7f5f14896537c321e9062284ce` (Ethereum; per-chain owners differ, see chain files).
That is the P category; an unprivileged attacker cannot touch it.

## 2. Hundred-Finance-class empty-market / donation attack — CLOSED (all chains)

**Mechanism present in the code** (verified against the deployed sources):
- `getCashPrior()` = `IERC20(underlying).balanceOf(this)` → `exchangeRateStoredInternal()` uses the
  live token balance, so a direct token transfer (donation) inflates the exchange rate
  (`PERC20` impl line ~3254, same as Compound).
- `redeemFresh()` computes `redeemTokens = divScalarByExpTruncate(redeemAmountIn, exchangeRate)`
  (floor) and the Comptroller checks only `redeemTokens`
  (`getHypotheticalAccountLiquidityInternal` adds `tokensToDenom × redeemTokens`), so a redeemer can
  withdraw up to one extra share of value — the exact Hundred/Agave/Midas precision-loss primitive.
- `Comptroller.redeemAllowedInternal` uses the pre-redeem exchange rate from `getAccountSnapshot`.

**Why it is not exploitable live:** the primitive only yields a *material* gain when the victim market
is effectively empty (totalSupply ≈ 1–2 raw wei) so the attacker can burn `totalSupply−1` shares while
owning ~100 % of supply. No WePiggy market on any chain is near-empty:

- Ethereum: smallest `totalSupply` = pRAI 2,285,683 raw wei (and CF=0); smallest CF>0 market = pWBTC
  2,807,075,675 raw. Arbitrum/OP: smallest CF>0 = pWBTC 885,584,317 / 444,117,503 raw.
- BSC: all 16 markets CF=0 **and** `borrowAllowed` reverts `"borrow is paused"` for every market —
  the borrow leg that the attack needs is disabled at the comptroller level.
- Fork-proof (CI): `test_eth_no_empty_market`, `test_arb_no_empty_market`, `test_op_no_empty_market`,
  `test_bsc_no_empty_market_and_cf_zero` all assert `totalSupply > 1e6` per market (PASS).
- Fork-proof (CI): the concrete best-case attack on the largest-cash market (ETH pWBTC: mint 100 WBTC,
  donate 1,500 WBTC, borrow **all** cash from every other market) is run end-to-end:
  the full-cash drain `redeemUnderlying(cash−1)` and the full-share `redeem` both return non-zero
  error codes (`INSUFFICIENT_LIQUIDITY`) because the attacker cannot burn enough shares —
  other holders exist. `shares needed to drain > attacker shares` is asserted (PASS).
- Exact upper-bound search over (D, X) grids (CI, `hundredUpperBound`) is **negative for every config
  on every chain**. ETH pWBTC best config: net ≤ **−$62,544** (D=100 WBTC, X=0); with donation
  X=100 WBTC: −$118,206; with X=1,500 WBTC (the concrete PoC): −$115,389,752. ARB/OP similar
  (ARB concrete: −$7,497,956). BSC: infeasible (no borrows).
- The donation itself is proven live but harmless: `test_eth_donation_inflates_but_is_fair` (a 100 WBTC
  donation raises `exchangeRateStored`; a fresh depositor redeems back ≤ their deposit) — PASS.

**Negative result:** the Tectonic/Hundred recipe does **not** yield any positive net on WePiggy today.
No empty market exists to seed it.

## 3. Other Compound-fork classes checked

| Class | Result |
|---|---|
| Redeem/mint/repay rounding | Standard Compound floor-rounding; only exploitable via the empty-market gate above → closed. |
| Stale / dead oracles | CF>0 markets use live Chainlink feeds (freshness checked; ETH: pETH 39 min, pDAI 26 min, pUSDT 4.7 h, pUSDC 3.7 h, pWBTC 22 h (24 h-heartbeat feed), pUNI 17 min). CF=0 markets (ETH pYFII/pLRC/pxLON/pRAI) use owner-set `WePiggyPriceOracleV1` with stale prices (YFII $417.99 vs $26.31, LRC $0.0312 vs $0.0096, RAI $3.33 vs $3.00) — inert (CF=0, borrow paused). `setPrice` is `onlyOwner`. |
| Oracle manipulation | Closed: Chainlink for CF>0 markets; `setPrice`/`setTokenConfig` `onlyOwner`; no permissionless path. |
| Liquidation of stale positions | ETH: 16 shortfall accounts; max single-shot liquidation bonus ≈ **$1.97** (oracle-valued; ≈$0.3–1 real, mostly pxLON whose real value is unproven) — below gas. ARB: 239 shortfall accounts, ≈**$0.40** total. OP: 95 debtors, **0** shortfall (pLINK/pOP borrower logs not enumerated — 12% of OP borrows unverified). BSC: 268 debtors, ≈**$7.30** total windfall (dust debts protect the $23.7k collateral). |
| `seize()` authorization | `seizeAllowed` lacks `msg.sender == pTokenCollateral`, but the seizer must be a **listed** market (`markets[seizerToken].isListed`), and no listed cToken exposes a user-callable `seize` with attacker-chosen params → no direct theft. |
| `mintForMigrate` bypass | `mintInternalForMigrate` skips `mintAllowed` (pause/cap) and accepts a caller-supplied `mintTokens`, but is gated by `require(msg.sender == migrator)`; every migrator (`CEthMigrator`/`CErc20Migrator`) requires `msg.sender == breeder`, and the breeder (`PiggyBreeder`) exposes `migrate`/`replaceMigrate` only via `onlyOwner` → P, not E-U. |
| `minInterestAccumulated` (custom clamp) | All ETH markets read **0** → no phantom-interest path. |
| Custom borrow accounting (`principal`/`interestIndex`) | Equivalent to Compound; repay subtracts exactly the transferred amount. |
| Admin reachability | All setters (`_setPriceOracle`, `_setCollateralFactor`, `_reduceReserves`, `_setMintPaused`, …) are `owner`/`pauseGuardian`-gated; owner = 4-of-7 Safe. P. |
| BSC shutdown state | CF=0 + borrow paused on all 16 markets; mint open only on pUNI; redeem open. Depositors can still redeem (H-O). The pMASK market shows a 46.8× inflated exchange rate (donation remnant) but CF=0 + paused → inert. |

## 4. Verdict

- **E-U ≈ $0** (only ~$10 of oracle-valued liquidation dust across four chains, below gas; nothing for the
  donation/rounding class). High confidence.
- **H-O ≈ $335.7k** supplier claims (self-service `redeem`, open on all chains).
- **P ≈ $408.7k** reserves (owner Safe 4-of-7 via `_reduceReserves`).
- **S:** none identified.

## 5. Files

- `rpc.py` — batch state enumerator; `scan_attack2.py` — per-chain Hundred-class scan;
  `exploit_sim.py` — exact-integer model; `value_breakdown.py` — value classification.
- `eth-markets.json`, `arb-markets.json`, `op-markets.json`, `bsc-markets.json` — raw state.
- `eth-borrow-events.json`, `bsc-borrow-events.json`, `op-borrow-events.json` — borrow logs.
- `eth-liquidations.json`, `eth-liquidation-quant.json`, `arb-liquidation-bonus.json`,
  `op-liquidations.json`, `bsc-debtor-values.json` — liquidation enumeration.
- `src/` — verified contract sources (cToken, comptroller, oracle, migrators, breeder).

# C2-15 — WePiggy (Compound-v2 fork): live extractability deep-dive

**Date:** 2026-10-08 · **Chains:** Ethereum, Arbitrum, Optimism, BSC · **Status:** read-only; PoC fork-verified only; no mainnet transactions.

## TL;DR

| Target | Live extractable (unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|
| WePiggy Ethereum — Comptroller `0x0C8c1ab017c3C0c8A48dD9F1DB2F59022D190f0b`, 10 markets, **$508,039 cash** | **$0** (donation/rounding class); ~$1 liquidation dust | Hundred-class code path is live (`getCashPrior`=balanceOf, floor-rounded `redeemUnderlying` + comptroller check on burned tokens only) but **no market is empty**: full-cash drain needs the attacker to burn `totalSupply−1` shares; the smallest CF>0 market (pWBTC) has `totalSupply = 2.81e9` raw. Fork-proven: best-case attack returns `INSUFFICIENT_LIQUIDITY`, net upper bound ≤ **−$62.5k** | If any market's supply were ever burned down to ~1–2 wei (or the owner zeroes CFs/opens borrows after emptying), the recipe re-arms — monitor `totalSupply` of pWBTC/pETH/pDAI/pUSDT/pUSDC/pUNI |
| WePiggy Arbitrum — `0xaa87715E…`, 6 markets, $83,147 cash | **$0** (donation/rounding); $0.40 liquidation dust | No empty market (min CF>0 supply 8.86e8 raw); fork-proven net ≤ negative; 239 shortfall accounts are dust | same as above |
| WePiggy Optimism — `0x896aecb9…`, 7 markets, $72,001 cash | **$0** (donation/rounding); $0 liquidation (95 debtors, none underwater) | No empty market; fork-proven; oracles live | same |
| WePiggy BSC — `0x8c925623…`, 16 markets, $52,754 cash | **$0** | All 16 markets **CF=0** and `borrowAllowed` reverts `"borrow is paused"` — the borrow leg the attack needs is disabled; fork-proven | If owner re-enables CF/borrows while pMASK keeps its 46.8× inflated exchange rate, re-check immediately |
| Reserves on all four chains (owner-only) | **$0 E-U** (P: $408,680) | `_reduceReserves` is `onlyOwner`; owner = Gnosis Safe 4-of-7 | Key compromise of the Safe |
| Supplier claims | **$0 E-U** (H-O: $335,711) | Self-service `redeem` is open | — |

## Total live extractable now: **$0** (high confidence)

The only unprivileged value movement found is **liquidation dust ≈ $10 oracle-valued across all four chains** (ETH $1.97, ARB $0.40, BSC $7.30, OP $0) — each below gas cost. The donation/rounding (Hundred/Agave/Tectonic) class yields a strictly negative net on every market of every chain.

## The mechanism, in exact terms

WePiggy is a Compound-v2 fork (`PERC20` cTokens behind EIP-1967 TransparentUpgradeableProxy; `Comptroller` impl `0x81ed5efd9477106f898733e47e9ec7738fa3e00c`). The Hundred-class preconditions are all present in the deployed code:

1. **Donation-sensitive exchange rate** — `PERC20.getCashPrior()` (`0x465461657b4175c1676ecea1fb0e8d0174d8d7f6`) returns `IERC20(underlying).balanceOf(address(this))`; `exchangeRateStoredInternal()` computes `(getCashPrior()+totalBorrows−totalReserves)*1e18/totalSupply`. A direct token transfer inflates the rate with no `mint`.
2. **Floor-rounded redeem against a token-count check** — `redeemFresh()` computes `redeemTokens = divScalarByExpTruncate(redeemAmountIn, exchangeRate)` (floor), then `comptroller.redeemAllowed(this, redeemer, redeemTokens)`. The Comptroller's `getHypotheticalAccountLiquidityInternal` (impl line 3732) only subtracts `tokensToDenom × redeemTokens` from liquidity — it never sees `redeemAmountIn`. A redeemer can therefore withdraw up to **one extra share's value** beyond the collateral the check accounts for.
3. **Live, unpaused borrow leg on ETH/ARB/OP** — borrow caps are 0 (unlimited), `pTokenBorrowGuardianPaused=false` on all CF>0 markets; close factor 0.5, liquidation incentive 1.08.

The Hundred recipe requires the victim market to be **effectively empty** (the attacker must own ~100% of supply so `floor((cash−1)/rate) ≤ balance`). No WePiggy market is: the smallest `totalSupply` on any chain is 2,285,683 raw wei (ETH pRAI, CF=0); the smallest CF>0 market is ETH pWBTC at 2,807,075,675 raw. The exact upper bound on an attacker's net is:

`Net ≤ rate₂/1e18 − (1/cf − 1)·B − X·C₁/(C₁+D)` — i.e. a **cost** of 43% of any borrowed amount plus donation dilution, with only a one-share rounding gain. It is negative unless the pre-attack exchange rate per raw share is enormous (near-empty market).

## Live-state assessment (blocks and addresses)

- **Ethereum** (block 26,150,020): 10 markets; cash $508,039 = claims $155,329 + reserves $358,549 − borrows $5,839. pWBTC alone holds $362k (of which $302.9k is reserves). Oracle `0xa1e683f0d956351106e6f45bdd3da5bce1db7f5a` (`WePiggyPriceProviderV1`, Chainlink sources); CF=0 markets use owner-set `WePiggyPriceOracleV1` `0xe4a1e73157eb4b58b1347e2be2df7ac83467b288`. `pTokenMintGuardianPaused`/`pTokenBorrowGuardianPaused`: pYFII/pLRC/pxLON mint+borrow paused; pRAI borrow paused; all CF>0 markets open. `minInterestAccumulated=0` on all markets. cToken owner + comptroller owner = 4-of-7 Safe `0x8114b3854d1e7b7f5f14896537c321e9062284ce`.
- **Arbitrum** (block 512,965,180): 6 markets, all CF 0.6–0.9, all unpaused, borrow caps 0; cash $83,147; reserves $43,109; claims $45,317.
- **Optimism** (block 157,942,842): 7 markets, all unpaused, borrow caps 0; cash $72,001; reserves $7,013; claims $81,917 (borrows $16,929).
- **BSC** (block 126,492,407): 16 markets, **CF=0 everywhere**, borrow paused everywhere, mint paused on 15/16 (pUNI open); cash $52,754; reserves ≈ $9; claims $53,148. pMASK shows a 46.8× exchange-rate remnant of a past donation — inert.
- **Admin reachability:** all value-moving admin functions (`_reduceReserves`, `_setReserveFactor`, `_setPriceOracle`, `_setCollateralFactor`, `_setMintPaused`, `_setMarketBorrowCaps`, `_setPiggyDistribution`, `_transferToken`, `_setMigrator`, `_setMinInterestAccumulated`) are `owner`/`pauseGuardian`-gated. `mintForMigrate` (which skips `mintAllowed` and accepts a caller-supplied `mintTokens`) is reachable only via `migrator` contracts whose entry points require the `PiggyBreeder` (`onlyOwner`).

## What an attacker can and cannot do

- **Cannot** profit from donation/rounding: no empty market; the drain call fails; the net upper bound is negative for all tested (D, X) on all chains (fork-verified).
- **Cannot** steal reserves: excluded from the exchange rate; `_reduceReserves` owner-only.
- **Cannot** manipulate oracles: CF>0 markets use live Chainlink; the settable oracle is `onlyOwner`.
- **Can** (technically) liquidate 16 dust positions on ETH, 239 on ARB, 268 on BSC for ≈$10 total oracle-valued bonus — unprofitable after gas; all seized collateral is real but the repayable debt is dust.
- **Can** redeem own supply (H-O) on all chains.

## PoC / fork verification

Foundry project `poc/` (CI: GitHub Actions `poc.yml`, workflow runs `forge test -vvv`). Test suite: `test/WepiggyEth.t.sol`, `WepiggyArb.t.sol`, `WepiggyOp.t.sol`, `WepiggyBsc.t.sol`; shared helpers in `test/Common.t.sol` (exact-integer `hundredUpperBound`).

CI runs (all URLs recorded; the suite asserts the same negative results throughout — later runs only harden funding/fork selection against flaky public RPCs):

| # | URL | Result |
|---|---|---|
| 1 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37838446700 | 7/13 (pre-fix: missing `enterMarkets`, oracle-vs-comptroller call) |
| 2 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37840221693 | **13/13 green** |
| 3 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37840973736 | 12/13 (transient RPC error in `deal`) |
| 4 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37841494706 | **13/13 green** |
| 5 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37841769506 | 12/13 (RPC "block not found" flake) |
| 6 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37842312197 | 12/13 (RPC flake on whale account) |
| 7 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37842849353 | 12/13 (OP pinned block pruned) |
| 8 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37843188869 | 12/13 (RPC 504 flake) |
| 9 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37843636422 | 12/13 (RPC 504 flake) |
| 10 | (final run — see `ci-log.txt`) | — |

The negative-result assertions passed in every run that reached them; only transient fork-RPC failures (HTTP 504 / block-hash races on public endpoints) caused the non-green runs. The final suite adds a multi-RPC fallback at fork selection.

Key fork results (final suite, 13/13 PASS):
- Flash-loan fees (~0.05–0.09 % of the flash size) only worsen the net; the computed upper bounds are already negative by ≥ $62k per chain.
- `test_eth_no_empty_market` — 10/10 markets `totalSupply > 1e6` (smallest CF>0: pWBTC 2,807,075,675).
- `test_eth_concrete_attack_fails` — mint 5 WBTC + donate 10 WBTC + borrow all other markets ($145,936 borrowed) → `redeemUnderlying(cash−1)` and `redeem(all)` both fail (`INSUFFICIENT_LIQUIDITY`); `net_ub ≈ −$682k`. (The larger 100/1,500 WBTC configuration was also run in runs 2/4: net_ub = −$115,389,752.)
- `test_eth_hundred_upper_bound_negative` — best of 30 (D, X) configs: **−$62,544**.
- `test_eth_donation_inflates_but_is_fair` — donation raises the rate; fresh redeemer recovers ≤ deposit.
- `test_arb_concrete_attack_fails` / `test_arb_hundred_upper_bound_negative` — borrowed $55,965, concrete net_ub ≈ −$7.49M; no profitable config.
- `test_op_concrete_attack_fails` / `test_op_hundred_upper_bound_negative` — borrowed $63,759, concrete net_ub ≈ −$7.50M; no profitable config.
- `test_bsc_*` — all CF=0; `borrowAllowed` reverts `"borrow is paused"`; donation+mint attempt cannot borrow.

## Verdict and residual/latent risk

**E-U = $0** (high confidence). The finding's "donation + rounding class" is real in the code but not exploitable: the empty-market gate is closed on all four chains, and the BSC deployment is additionally borrow-paused with CF=0. Remaining value is **H-O $335.7k** (supplier claims) and **P $408.7k** (reserves, 4-of-7 Safe). Latent risk: (a) if a WePiggy market's supply is ever burned to ~1–2 wei while cash remains, the recipe re-arms; (b) BSC: if borrows/CFs are re-enabled while pMASK (or any market) has an inflated rate, re-check; (c) owner-Safe key compromise (P).

**Blockers:** none needed for the negative result; for the (hypothetical) attack, the missing empty market is the sole blocker on ETH/ARB/OP; BSC has two independent blockers (CF=0 + borrow pause).

## Methodology & sources

- State read via `eth_call`/`getCode`/`getStorageAt` on Ethereum (BlockPi/NodeReal), Arbitrum, Optimism, BSC (NodeReal/Ankr), at the blocks above; verified sources from Etherscan V2 (cToken `PERC20`, `Comptroller`, `WePiggyPriceProviderV1`, `WePiggyPriceOracleV1`, migrators, `PiggyBreeder`).
- Market/oracle/pause/cap enumeration: `analysis/rpc.py`, `analysis/scan_attack2.py` (30-config grid per market), `analysis/exploit_sim.py`; values: `analysis/value_breakdown.py` + DefiLlama.
- Liquidation enumeration: Borrow logs via Etherscan V2 (ETH), Ankr full-range `eth_getLogs` (ARB/BSC), Blockscout v1 (OP), then `borrowBalanceStored` + `getAccountLiquidity` per account; windfall computed with oracle ratios and real prices.
- Prior art consulted: BlockSec Hundred Finance post-mortem, MixBytes empty-pool attack analysis, DeFiLlama.

## Caveats & limitations

- Cash totals here ($508k/$83k/$72k/$53k) differ from the corpus figures ($484k/$58k/$47.8k/$32.9k) because of different prices and blocks; raw per-market amounts and blocks are in `analysis/*-markets.json`.
- **Secret-hygiene note:** the auto-generated `analysis/eth-markets.json` initially embedded the full BlockPi RPC URL (which contains an API key); it was pushed to the public CI repo by CI runs 1–2. It has been sanitized (`"url": "<redacted-rpc-url>"`) and the branch re-pushed (run 3+). The BlockPi API key should be rotated as a precaution.
- OP borrower logs for pLINK/pOP (≈12% of OP borrows) were not enumerated (Blockscout 429); all 95 covered debtors are healthy.
- USD values use DefiLlama at query time; xLON has no price feed (treated as ~$0 for liquidation value).
- Fork tests simulate flash capital with `deal`; the real constraint (flash availability) is not a blocker for the negative result.
- CI run 2 status/log: `ci-log.txt`, artifacts in `ci-artifacts/`.

## Files index

- `README.md` (this), `summary.json`, `ci-log.txt`
- `analysis/SUMMARY.md`, `analysis/eth.md`, `analysis/arb.md`, `analysis/op.md`, `analysis/bsc.md`
- `analysis/*-markets.json`, `analysis/*-borrow-events.json`, `analysis/*-liquidation*.json`, `analysis/value-breakdown.json`
- `analysis/{rpc.py, scan_attack2.py, exploit_sim.py, value_breakdown.py, op_enum*.py}`
- `analysis/src/` — verified sources
- `poc/` — Foundry project (tests above)

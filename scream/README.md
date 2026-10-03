# H-08 · Scream (Fantom) — deep-dive: unprivileged extractability & frozen-holder analysis

**Date:** 2026-10-03 · **Chain:** Fantom Opera (chainid 250) · **Status:** read-only; PoC fork-verified only;
**no mainnet transactions** · **Live block:** 123,539,101 (CI scan) / 123,538,481 (local state dump)

**Headline: external unprivileged extractable = $0 (high confidence).**
Scream's entire live value is held in Compound-v2.8 cToken markets whose `mint`/`borrow` are globally
paused; every account with valuable collateral is blocked from liquidation by **dead Chainlink price
feeds**, and the one liquidatable account in the whole protocol has collateral in a market holding
0.0000012 FUSD. The real story is the reverse of "free money": **98.6% of the $1.16M scLINK cash is
frozen for its holders** because the dead feed makes the account-liquidity check revert, which blocks
`redeem`, `transfer` and even `exitMarket`. Only 1.4% of scLINK (≈1,209 LINK, ≈$16.7k) is held by
non-members who can still redeem.

---

## 1. TL;DR table

| Target | Live value (block 123,539,101) | E-U extractable by outsider | Why | Latent risk |
|---|---|---|---|---|
| scLINK market `0x2359012ebe36cca231203d78b914284947b58aa3` | 84,119.318 LINK = **$1,163,048** cash; 1,960.97 LINK borrows | **$0** | mint/borrow paused; all 14 debtors blocked from liquidation (scLINK feed dead); non-members can only redeem their own cTokens | feed repair (Chainlink/Scream admin) unlocks 84,872 LINK; else frozen |
| scLINK holder split | 181 holders, 100% of supply enumerated | — | 20 non-members (58,760.90 ct = 1.4%) **can** redeem → 1,209.45 LINK ≈ $16,722 (H-O). 161 members (4,123,510.86 ct = 98.6%) **frozen** → 84,872.18 LINK ≈ $1,173,457 (P/S) | top holder `0x91a88dd9…` = 97.07% of supply, frozen |
| scBOO a25f market `0xa25f9ffd7855fc350a103d91ab7c906d6bf1977d` | 26,842.97 BOO = $509 | **$0** | feed dead; 99.96% of cTokens held by non-members who can redeem the market's own cash (H-O), no outsider path | — |
| scDEI market `0x68c102aba11f5e086c999d99620c78f5bc30ecd8` | 11,004,489 DEI (≈$57k nominal at $0.0052; realizable ≪) | **$0** | feed dead; 99.9997% of cTokens held by members → frozen (P/S) | admin/Chainlink repair only |
| scFUSD market `0x83fad9bce24b605fe149b433d62c8011070239b8` | 0.0000012 FUSD cash; 127,488 FUSD borrows | **$0** | the only liquidatable account (`0x539654af…`, shortfall 32.45 FUSD) has scFUSD-only collateral; seizing it yields unredeemable cTokens | — |
| scDOLA / scWETH / scFRAX-B / scYFI / dust | ≈$201 combined | **$0** | feeds dead for DOLA/WETH; borrow paused; redeem holder-only | — |
| Empty markets (8) | 1 wei total | **$0** | C-33 donation/first-minter attack needs `mint`, which is paused | — |
| Comptroller SCREAM rewards | 2,092.87 SCREAM held; compAccrued dust (≤0.00087 SCREAM/holder) | **$0** | `claimComp` pays the holder only | — |
| Admin surfaces (delegator impl, oracle feeds, reserves) | — | **$0** | all revert/return UNAUTHORIZED for EOA; admin = Gnosis Safe 4-of-N, guardian Safe 2-of-N | Safe key compromise (not unprivileged) |

**Total live extractable by an external unprivileged attacker right now: $0.00 (high confidence).**
**Total holder-redeemable now (H-O): ≈$17,433.** **Admin-fixable frozen value (P): ≈$1,230,680 nominal.**
**Practically stuck (S) if no privileged actor ever acts: the same ≈$1.23M.**

---

## 2. The mechanism in exact terms

Scream is a Compound v2.8-lineage fork (Unitroller `0x260e596d…` → impl `0x37517c5d…`, verified by
selector analysis: `supplyCaps`, `_setMarketSupplyCaps`, `compSpeeds`, batch `claimComp(address[],address[],bool,bool)`,
5-arg `liquidateBorrowAllowed`). Markets are `CErc20Delegator` proxies (e.g. scLINK → delegate
`0xed4ab736…`). Two deployed-reality facts dominate:

1. **Pause wall.** `mintGuardianPaused` and `borrowGuardianPaused` are `true` for **all 27 markets**
   (guardian Safe `0x52bad153…`, 2-of-N). In this Compound version the checks are `require`s, so
   `mintAllowed` reverts `"mint is paused"` and `borrowAllowed` reverts `"borrow is paused"`.
   `transferGuardianPaused`/`seizeGuardianPaused` are false — but seize can only be reached through
   `liquidateBorrow`, and transfers still run the account-liquidity check (see 2).
2. **Dead-feed wall.** The oracle `0x0b24e942…` resolves each market's price either from a per-market
   Chainlink `AggregatorProxy` (`aggregators(market)`) or, when that mapping is zero, from Band Protocol's
   `ref()` (`0x56e2898e…`). All 17 aggregator-backed markets now revert: the proxies' `aggregator()`
   returns `address(0)` (current phase removed — Chainlink wound down Fantom feeds). Example: scLINK's
   proxy `0x221C773d…`, `phaseId=2`, `aggregator()=0` → `latestRoundData()` reverts. The shared stable
   proxy `0x2553f4ee…` (scUSDC/scDOLA/scTUSD/scDEI) is also `aggregator()=0`. Band fallback prices still
   answer but are stale (LINK $24.06 vs real $13.83; FUSD $0.76).

The combination produces the freeze: Compound's `getHypotheticalAccountLiquidityInternal` calls
`oracle.getUnderlyingPrice(asset)` for **every market in the account's asset list**, with no try/catch.
Any account that ever entered a dead-feed market therefore has a reverting liquidity check. That single
revert propagates into:

* `getAccountLiquidity()` → **reverts** ⇒ `liquidateBorrowAllowed`/`liquidateBorrow` **revert**
  (verified on-chain for every scLINK debtor and every scFRAX-A debtor),
* `redeemAllowed()` → **reverts** when the redeemer is a member of that market ⇒ `redeem` **reverts**,
* `transferAllowed()` → **reverts** ⇒ cToken `transfer`/`transferFrom` **revert**,
* `exitMarket()` → **reverts** ⇒ members cannot even leave the market to become non-members.

Members are thus **fully locked**: no redeem, no transfer, no exit. Non-members bypass the liquidity
check entirely (`if (!accountMembership[redeemer]) return NO_ERROR`) and can still redeem — this is the
only value that moves today.

**No empty-market/donation path:** the C-33 first-minter donation attack requires `mint` (paused) and an
empty market holding value; 8 markets have `totalSupply==0` and their combined cash is **1 wei**.
**No oracle manipulation path:** the oracle's setters (`_setAggregators`, `_setAdmin`, `_setMaxPriceDiff`)
revert `"only the admin may …"`; Band's ref is validator-updated; and even a manipulated price would only
feed paused borrows / reverting liquidations.

---

## 3. Live-state assessment (all read-only, explicit blocks)

| Item | Value | Source |
|---|---|---|
| Chain | Fantom Opera, block advancing (123,537,949 → 123,539,101 across the session), ~1 tx/block | `eth_blockNumber` ×3 RPCs |
| Comptroller / impl | `0x260E596DAbE3AFc463e75B6CC05d8c46aCAcFB09` → `0x37517C5D880c5c282437a3Da4d627B4457C10BEB` | `comptrollerImplementation()` |
| Markets | **27** (`getAllMarkets()`), not 26 as in the corpus | on-chain |
| Mint/borrow pause | all 27 markets paused; guardian `0x52bad153…` (Gnosis Safe 1.3.0, threshold 2) | `mintGuardianPaused`/`borrowGuardianPaused` |
| Oracle | `0x0B24E9420c125242A5ec438Bc65e48Af1e866ddd`; `ref()` = Band `0x56e2898e…`; `v1PriceOracle` `0x5036cc1e…` (dead) | selector extraction + calls |
| Dead feeds | **17/27 markets revert**: scUSDC, scDAI, scWFTM, scWBTC, scWETH, scFUSDT, scYFI, scCRV, **scLINK**, scFRAX-A, scDOLA, scMIM, scBIFI, scTUSD, scSPELL, scBOO-a25f, scDEI | `getUnderlyingPrice` |
| Admin | `0x63A03871141D88cB5417f18DD5b782F9C2118b5B` = Gnosis Safe 1.3.0, **threshold 4**, 346.7 FTM; pendingAdmin/pendingImpl = 0 | `admin()`, `getThreshold()` |
| Risk params | closeFactor 50%, liquidationIncentive 1.08, reserveFactor 20% (scLINK) | Comptroller reads |
| scLINK cash | **84,119.31805425331 LINK** (LINK $13.826 ⇒ $1,163,048) | `getCash()` / `balanceOf` |
| scLINK supply / rate | 4,182,271.765 ct; `exchangeRateStored` 2.0581e26; current rate 2.05825e26 (1 ct = 0.0205825 LINK, PoC-measured) | on-chain + test_07 |
| scLINK last accrual | block 109,425,975 = **2025-05-09** (512 days stale); accrual factor 0.0034 → no overflow | `accrualBlockNumber`, rate model |
| scLINK holders | 181 current holders covering **100%** of supply; top = `0x91a88dd9…` 4,059,588.63 ct (**97.07%**) | Mint/Redeem logs + `balanceOf` |
| Redeemable now | 20 non-member holders, 58,760.9042 ct ⇒ **1,209.45 LINK ≈ $16,722** | redeem simulation per holder |
| Frozen | 161 member holders, 4,123,510.8608 ct ⇒ **84,872.18 LINK ≈ $1,173,457** | redeem/transfer/exit simulations |
| scBOO a25f | cash 26,842.97 BOO ($509); 1,374,205.03/1,374,755.23 ct held by non-members (can redeem) | Mint/Redeem + simulation |
| scDEI | cash 11,004,489 DEI; non-member ct 1,462.89 (redeemable ≈292.6 DEI); 550,368,858.99 ct frozen | Mint/Redeem + simulation |
| Only liquidatable account | `0x539654afe0c85df7db6176258f6dce567d2f8c13`: shortfall **32.45 FUSD**, assets = [scFUSD], scFUSD cash 0.0000012 FUSD | `getAccountLiquidity` |
| Debtor counts checked | scLINK 14/14 revert; scFRAX-A 16/16 revert; scFUSD 29 debtors — all revert except the one above | `getAccountLiquidity` per debtor |
| Rewards | compRate 1e12; Comptroller holds 2,092.87 SCREAM; top holder compAccrued ≈0.00087 SCREAM | `compAccrued`, `balanceOf` |

Full machine-readable dumps: `analysis/market_table.txt` (CI scan), `analysis/oracle_table.txt`,
`analysis/state.json`, `analysis/sclink_redeemability.json` (per-holder membership + redeem simulation),
`analysis/sclink_balances.json`, `analysis/sclink_borrowers.json`, `analysis/other_markets_holders.json`.

---

## 4. What an attacker can / cannot do (exact call paths)

| Path | Preconditions checked live | Result |
|---|---|---|
| `scLINK.mint(x)` | `mintGuardianPaused[scLINK]=true` | reverts `"mint is paused"` — **closed** |
| `scLINK.borrow(x)` | `borrowGuardianPaused[scLINK]=true` | reverts `"borrow is paused"` — **closed** |
| `scLINK.liquidateBorrow(borrower, x, scLINK)` | borrower `0xf1f75b…` debt 1,522.8 LINK; `getAccountLiquidity` reverts (scLINK feed dead) | reverts — **closed** (same for all 14 debtors) |
| Donation + `redeem` round-trip | needs `mint` to capture rate | **closed** (mint paused; no empty market holds cash) |
| Oracle manipulation → liquidate | setters admin-only; feeds dead; liquidations revert anyway | **closed** |
| `scFUSD.liquidateBorrow(0x539654af…, 100e18, scFUSD)` | shortfall 32.45 FUSD; borrower holds 8,530.26 scFUSD ct | **executes** (PoC: seized 313,765.35 ct) but market cash = 0.0000012 FUSD ⇒ `redeemUnderlying` reverts ⇒ **net $0** |
| `claimComp` | pays `compAccrued[holder]` to the holder | no caller gain — **closed** |
| cToken `transfer`/`exitMarket` by member | liquidity check reverts | **closed** (also blocks holders) |
| Admin (`_setImplementation`, `_setPriceOracle`, `_reduceReserves`, `_setAggregators`, …) | EOA → revert or return `1` (UNAUTHORIZED) | **closed** |
| Non-member `redeem` | `accountMembership[scLINK][holder]=false` | **works** — holder-only (H-O) |

Gas/capital: irrelevant for E-U because no unprivileged path completes; the one executing liquidation
costs ~610k gas and returns ~$0 of redeemable value.

---

## 5. PoC / fork verification

* Project: `poc/` (Foundry, vendored forge-std). Tests: `poc/test/ScreamH08.t.sol`.
* **CI run (success):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37140618279 — **12/12 PASS**
  (compile-iteration runs: 37139009977, 37139420865, 37139746238, 37140142309).
* Fork: latest Fantom block at run time 123,539,101; `rpc.txt` chosen by `ci/run.sh` (env `FANTOM_RPC_URL`
  probed first, then public RPCs).
* Tests and key numbers:

| Test | Proves | Key output |
|---|---|---|
| `test_01` | chain alive, chainid 250, 27 markets | block 123,539,101 |
| `test_02` | mint+borrow paused on all 27; transfer/seize not paused | closeFactor 0.5, liqIncentive 1.08 |
| `test_03` | `mint`/`borrow` calls revert | — |
| `test_04` | oracle reverts for scLINK/scUSDC/scFRAX-A/scDEI; scFUSD Band price 0.76e18 | — |
| `test_05` | scLINK debtor has 1,522.8 LINK debt; `getAccountLiquidity` and `liquidateBorrow` revert | — |
| `test_06` | only liquidatable account: shortfall 32.45 FUSD, scFUSD cash 1,206,216,773,046 wei | cash dust |
| `test_06b` | actual liquidation executes; seized 313,765.3464 scFUSD ct nominal 108 FUSD — unredeemable | 610k gas, $0 yield |
| `test_07` | non-member holder redeems 1 ct → 20,582,504,969,574,879 wei LINK | H-O works |
| `test_07b` | member (4,059,588.63 ct) redeem/transfer/exitMarket all revert | frozen |
| `test_08` | 8 empty markets, 1 wei total cash | C-33 closed |
| `test_09` | donation raises rate but mint stays paused; attacker ct balance 0 | no profit |
| `test_10` | all 9 admin entry points blocked for EOA; admin Safe threshold 4 | P only |

* CI scan job (`ci/run.sh` + `ci/scan.py`) re-dumps the full 27-market table, oracle table and chain
  liveness into `ci-out/` on every run (artifact `result-scream`).

---

## 6. Verdict & residual/latent risk

* **E-U = $0.00 (high confidence).** Every unprivileged value-moving path is closed by either the global
  mint/borrow pause or the dead-feed revert that blocks liquidations; the sole liquidatable account yields
  unredeemable dust-collateral cTokens.
* **H-O = ≈$17,433 now.** Non-member holders can redeem: scLINK 1,209.45 LINK ($16,722), scBOO 26,842.97
  BOO ($509), scDOLA ≤$141, scWETH ≤$48, scFRAX-B $5, scYFI $7, scDEI ≈$1.5 (only scLINK/scBOO/scDEI were
  individually simulated; the rest ≤$201 combined).
* **P = ≈$1,230,680 nominal.** 84,872.18 LINK ($1,173,457) + 11,004,489 DEI (≈$57k at the deepest-pool
  price $0.0052) are recoverable **only** if a privileged actor repairs the feeds: Scream admin Safe
  (4-of-N) `_setAggregators`/`_setPriceOracle`, or Chainlink's proxy owner `0x9ba4c515…` re-registering a
  phase aggregator. No self-service holder path exists.
* **S (if no privileged actor ever acts): the same ≈$1.23M is permanently bricked.** The admin Safe has
  346.7 FTM and no observed activity; the protocol has been dead since 2022-05-15.
* Latent risks worth re-checking: (i) a Chainlink phase re-registration would instantly restore
  liquidations and holder exits (positive for holders, still no E-U because mint/borrow stay paused);
  (ii) if the pause guardian ever unpauses borrow, the stale Band prices (LINK $24.06) plus the dead
  Chainlink feeds would create a real liquidation/bad-debt surface; (iii) DEI exit liquidity is <$25k,
  so even the P number for DEI is optimistic.

**Blockers encountered:** public Fantom RPCs (publicnode/ftm.tools/1rpc) now require keys or are rate-limited
— used `rpcapi.fantom.network`, `fantom.drpc.org`, `fantom.api.onfinality.io`; the public RPCs return
96-byte padded results for some cToken getters (decode first word only); Fantom explorer APIs are gone
(Etherscan V2 doesn't support chainid 250, Sourcify has no matches), so ABI was recovered by PUSH4
extraction + 4byte/OpenChain resolution; DEI has no DefiLlama price (used GeckoTerminal pools).

---

## 7. Methodology & sources

1. Corpus leads (`zombie_hunt/verification_live_funds.md` §3, `FINDINGS.md` H-08) re-verified on-chain.
2. Full market enumeration via `getAllMarkets()` (27), per-market reads (cash, supply, borrows, rate,
   pause flags, collateral factors, borrow/supply caps, oracle price, aggregator).
3. Event-history mining: chunked `eth_getLogs` for all scLINK topics (87,745 events) → 262 borrowers,
   641 minters; balance enumeration covers 100% of scLINK supply.
4. Per-holder/per-debtor simulation: `eth_call` with `from`/state overrides (`redeem(1)`,
   `getAccountLiquidity`, `liquidateBorrow`) → H-O vs frozen split.
5. ABI recovery: runtime-bytecode PUSH4 extraction + OpenChain/4byte signature resolution for the
   Comptroller impl, cToken delegate, oracle, and aggregators.
6. Fork PoC in CI (Foundry 1.7.x, solc 0.8.24) — 12 tests, all passing.
7. Prices: DefiLlama `coins.llama.fi` (LINK $13.826, BOO $0.01896, DOLA $0.9974, YFI $2,666.82,
   FETH $2,681.31), GeckoTerminal (Fantom DEI ≈ $0.0052 across liquid pools; deepest pool reserves ≤$21k).

## 8. Caveats & limitations

* H-O for scDOLA/scWETH/scFRAX-B/scYFI/dust is an upper bound (holder membership not individually
  simulated); combined ≤$201.
* scDEI's nominal $57k uses the deepest-pool marginal price; total DEI pool depth is ~$25k and 24h volume
  ≈0, so realizable value is likely $10–25k at best.
* The frozen/frozen-vs-redeemable split is a snapshot at block ~123,539,000; a Chainlink feed repair or an
  admin oracle swap changes it instantly.
* The Scream admin Safe owners are not identifiable on-chain; the 4-of-N threshold is verified but
  whether the keys are live is unknown (practical-S risk).
* No attempt was made to audit the cToken math line-by-line against upstream Compound v2.8; the PoC
  exercises the live paths directly.

## 9. Files index

```
scream/
├── README.md                     # this report
├── summary.json                  # machine-readable summary
├── analysis/
│   ├── market_table.txt          # CI full 27-market dump (block 123,539,101)
│   ├── oracle_table.txt          # CI oracle vs real-price table
│   ├── state.json                # local full state dump (block 123,538,481)
│   ├── sclink_redeemability.json # per-holder membership + redeem simulation (181 holders)
│   ├── sclink_balances.json      # current cToken balances (covers 100% of supply)
│   ├── sclink_borrowers.json     # 14 scLINK debtors, debt/balance/assets/liquidity
│   ├── other_markets_holders.json# scDEI/scBOO holder redeemability
│   ├── cash_usd.json             # cash × DefiLlama price per market
│   ├── selectors.json            # recovered ABIs (impl/delegate/oracle/aggregator)
│   ├── sclink_logs.jsonl         # 87,745 raw events (chunked fetch)
│   ├── logs_scFRAX-A.jsonl / logs_scFUSD2.jsonl  # debtor event histories
│   └── *.py                      # fetchers/simulators (fetch_state2, redeemability, …)
├── poc/                          # Foundry fork tests (12/12 pass)
│   ├── foundry.toml, rpc.txt
│   ├── lib/forge-std/            # vendored
│   └── test/ScreamH08.t.sol
├── ci/run.sh, ci/scan.py         # custom CI job: chain liveness + market/oracle scan
├── ci-out/                       # CI scan results (also uploaded as artifact)
├── ci-log.txt                    # full CI log
└── ci-artifacts/result-scream/   # downloaded CI artifacts
```

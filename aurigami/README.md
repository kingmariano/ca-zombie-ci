# C2-18 · Aurigami (Aurora) — live extractability deep-dive

**Date:** 2026-10-09 · **Chain:** Aurora (chain id 1313161554) · **Status:** read-only research; fork tests only;
**no mainnet transactions signed or sent.**
**Target:** Unitroller `0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb` (+ 14 auToken markets), Aurora mainnet.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| Aurigami Unitroller + 14 auToken markets | **$0.00 now** (ceiling ≈ **$0.84** of dust-liquidation bonus) | **New borrowing is disabled** (`borrowCaps == 1` wei on every market → `borrow(1)` reverts `market borrow cap reached`). Oracle is keeper-gated and accurate. Liquidation surface is 140 dust accounts ($11.18 total shortfall). Reward indices cannot be captured retroactively. All admin paths gated (2-of-6 Gnosis Safe; oracle owner EOA). | Oracle owner is a **single EOA**; if leaked, prices become attacker-controlled — but with borrowing off, impact is limited to liquidations/mark-to-market until caps are raised. Redeeming cash below `reserves − borrows` can brick a market (griefing, no profit) until a donation un-bricks it. |

**Total live extractable by an external unprivileged attacker: `$0.00` — confidence: high.**
Largest theoretical residual: liquidating **all 140** underwater accounts, each capped by the 50% close
factor and by its collateral, yields a gross bonus ceiling of **$0.84** (max repayable $15.37 × 6.7% net
incentive); Aurora gas is 0.07 gwei, so a ~300k-gas liquidation costs ≈$0.05 — even the single best position
(repay $0.916 → seize $0.977, +$0.061) nets ≈ **+$0.01 after gas**. The book is economically nil.

## 2. What the finding claimed vs what is actually live

The campaign line (C2-18) reported “≈$630k (109.3 ETH, 48.8k stNEAR, 13.2k WNEAR, 44.4k AURORA), live,
unpaused, custom Compound fork; keeper-gated oracle; 40% CF blunts stNEAR overvaluation; custom 24-dec `Exp`
math unaudited”. Re-verified at **block 219,162,280** and via fork tests at blocks ~219,165–219,168k:

- The four-quoted-asset figure understates the protocol: **cash = $980,843** across 14 markets
  (adds auUSDT $116.2k, auWBTC $97.5k, auUSDC $80.8k, native USDC/USDT $8.4k, auPLY $11.5k, auNEARX $1.5k, …).
- **All of that cash belongs to cToken holders** (supplier claims = cash + borrows − reserves = **$1,120,401**).
  It is **H-O** (holders can redeem), not attacker-extractable.
- The two structural attack classes that the campaign flagged are **closed on-chain**:
  1. donation/borrow (Tectonic-class): impossible — no new borrowing on any market;
  2. oracle manipulation: impossible — `setPrices` reverts `not price setter` for everyone but the keeper.
- The custom 24-decimal `Exp` math is **internally consistent** — verified numerically on-chain for
  6/8/18/24-decimal markets (see `analysis/math-review.md`); no scale, rounding or truncation bug found.
- **Deployed code was byte-verified against the reviewed sources**: an independent child agent recompiled
  `Comptroller.sol` (solc 0.8.11, runs=3000) and the Unitroller and byte-compared them to the on-chain
  bytecode — **0 differing bytes** (cTokens differ only in immutable slots), so all source-level
  conclusions below are on-chain facts (`analysis/child-math-review.md`).

## 3. Live-state assessment (Aurora, block 219,162,280 unless stated)

### 3.1 Contracts & roles

| Role | Address | Type | Notes |
|---|---|---|---|
| Unitroller (Comptroller proxy) | `0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb` | verified | impl `0xa200b567579a577f582d292f7a1b5c4ecce195f8` |
| Comptroller admin / pauseGuardian / cToken admin | `0x2D05FfFE70CE64c5954710D4C308dB31C8dBd8dE` | **Gnosis Safe 2-of-6, v1.3.0** | no pending admin/implementation |
| Oracle | `0x5A7B8E3CDc6ee2E0E6Ad0d4fab8dCD70990157EE` | **unverified**, 4,474 B | `owner()` = EOA `0xeBD8251539A66d25202263D59a573A9DD3425f45` |
| Price keeper | `0xf9D72FED253bF10924cb501f254eFf112B6Fa203` | EOA | pushes 11 prices via `0xec3115f9` every ~30–90 min (fresh) |
| PLY token / Pulp lock | `0x09C9D464…3A4f` / `0x04Ac4871…095e` | verified | reward pool + user locks |
| Reserves (admin-only) | across cTokens | — | **$117,853** |

Key live flags: `transferGuardianPaused=false`, `seizeGuardianPaused=false`, per-market
`mintGuardianPaused=false` and `borrowGuardianPaused=false` (borrow guard unused — the **borrow cap** is what
blocks borrowing). `closeFactor=0.50`, `liquidationIncentive=1.10`, `protocolSeizeShare=3%`.

### 3.2 Markets (full table in `analysis/market-table.md`)

| market | addr | cash | borrows | reserves | CF | oracle px | cash USD | claim USD |
|---|---|---|---|---|---|---|---|---|
| auUSDC | `0x4f0d864b…` | 80,846.4793 | 29,011.5570 | 37,830.9272 | 0.80 | $0.99961 | $80,815 | $71,999 |
| auETH | `0xca9511B6…` | 109.3176 | 72.0308 | 4.6364 | 0.70 | $2,483.43 | $271,482 | $438,852 |
| auWBTC | `0xCFb6b049…` | 1.1880 | 0.0187 | 0.0775 | 0.60 | $82,039.09 | $97,464 | $92,635 |
| auUSDT | `0xaD5A2437…` | 116,328.1908 | 10,507.8728 | 10,692.9133 | 0.75 | $0.99929 | $116,246 | $116,061 |
| auDAI | `0xCE416636…` | 34.0131 | 0.1013 | 0.0136 | 0.00 | $0.99977 | $34 | $34 |
| auWNEAR | `0xaE4fac24…` | 13,235.5604 | 7,847.2915 | 3,133.6542 | 0.60 | $4.69569 | $62,150 | $84,284 |
| auSTNEAR | `0x3195949f…` | 48,820.5806 | 2.0748 | 5,339.2642 | 0.40 | $6.73006 | $328,565 | $292,646 |
| auAURORA | `0x8888682E…` | 44,408.4633 | 0 | 1,500.3334 | 0.40 | $0.058863 | $2,614 | $2,526 |
| auTRI | `0x6Ea6C030…` | 436,476.1086 | 0 | 0 | 0.00 | (no price) | $55 | $55 |
| auPLY | `0xC9011e62…` | 310,749,151.06 | 0 | 0 | 0.00 | (no price) | $11,467 | $11,467 |
| auUSN | `0x5cCAD065…` | 335.3375 | 0 | 0 | 0.00 | (no price) | $29 | $29 |
| auNEARX | `0xC7ea819e…` | 293.8958 | 78.5851 | 131.7769 | 0.40 | $5.24332 | $1,541 | $1,262 |
| auUSDCNative | `0x10D56d6E…` | 4,171.6402 | 62.5488 | 18.5132 | 0.70 | $0.99961 | $4,170 | $4,214 |
| auUSDTNative | `0xdDfd0407…` | 4,213.7462 | 156.8530 | 28.8489 | 0.70 | $0.99929 | $4,211 | $4,339 |
| **TOTAL** | | | | | | | **$980,843** | **$1,120,401** |

All 14 markets have `totalSupply > 0` (no empty-market capture surface). Borrow caps are 1 wei on all 14.
`mintCaps` leave headroom (e.g. auUSDC ≈ $373k more mints allowed).

### 3.3 Liquidation surface (exhaustive)

Every address that ever emitted `Borrow` was enumerated from explorer logs (40,250 events total,
5,480 unique addresses) and its `getAccountLiquidity` read at the latest block:
**140 accounts have shortfall; the entire shortfall is $11.18; total debt of those accounts $30.73**
(largest single account: $2.49 debt / $0 collateral; largest with collateral: $1.78 debt vs $2.94 collateral
→ best-case liquidation profit **$0.061**). Fork test executes one such liquidation live (test_07).

### 3.4 Reward system

Unitroller holds **167,372,294.98 PLY** (≈$6.2k) + 0.1 AURORA; Pulp holds 672.1M locked PLY (≈$24.8k).
`mintAllowed`/`redeemAllowed`/`transferAllowed`/`seizeAllowed` call the flywheel with the **pre-action
balance**, so a fresh minter cannot capture the historical index (auUSDC supply index 9.30e46 vs 1e36 start).
Fork-proven: fresh mint + `claimReward` = **0 wei PLY**. Claims are holder-only (`isAllowedToClaimReward`).

## 4. What an external unprivileged attacker can / cannot do

**Cannot:**
- borrow (any market, any amount) → reverts `market borrow cap reached` (cap = 1 wei). **This kills the
  donation→inflate-exchange-rate→borrow class.**
- push oracle prices → `setPrices` reverts `not price setter`; `setPriceSetter` is `Ownable`.
- seize() directly without a listing/repay → caller must be a listed auToken (reverts `MarketNotListed`).
- capture any market's cash without holding its cTokens: all markets are supplied; exchange-rate math is
  share-proportional with protocol-favouring rounding; donations only raise everyone's rate.
- claim rewards for another holder, or inflate reward accrual retroactively.
- profit from a utilisation/interest spike: max auETH rate at 100%+ utilisation is ~39.5%/yr (fork-measured);
  stale windows add <1% — cannot force liquidations.

**Can (legitimate, not extraction):**
- mint/redeem freely in any ERC20 market (fork test_05: 50,000 USDC round-trip returns ≤ input);
- redeem dust positions in the orphan markets auTRI/auPLY/auUSN (oracle price missing, but redeems don't
  need it for non-members — simulated successful for the top auPLY holder);
- liquidate the 140 dust accounts for a total gross bonus **ceiling of $0.84** (each repay capped at 50% of
  debt and by collateral; best single account +$0.061 gross ≈ +$0.01 after gas; fork-verified $0.916 repay → $0.977 seized);
- add reserves (`_addReserves`, permissionless but pays nothing out);
- **call `AuErc20.sweepToken` (upstream's `msg.sender == admin` check is missing — independent child agent,
  fork-proved).** The recipient is hard-coded to the admin Safe and all 14 markets hold zero stray tokens,
  so this is grief-only/forced-forwarding with **$0** impact today (latent low-severity access-control defect).

## 5. PoC / fork verification

Foundry project `poc/` (vendored forge-std). 10 tests, all against a **live Aurora fork** (no pinning so the
suite stays meaningful as state drifts; fork block logged per test). **No mainnet tx is sent.**

| test | claim proven | result |
|---|---|---|
| test_01 | 14 markets, supply>0, mint open, borrow caps=1, pauses off | PASS |
| test_02 | `borrow(1)` reverts `market borrow cap reached` on all 7 debt markets | PASS |
| test_03 | oracle `setPrices` unauthorised → `not price setter` | PASS |
| test_04 | `seize()` from non-market caller reverts | PASS |
| test_05 | 50k USDC mint/redeem round-trip, value preserved | PASS |
| test_06 | fresh minter + claimReward gains **0 wei PLY**; pool not drained | PASS |
| test_07 | top-30 shortfall sum $10.36; real liquidation: repay $0.916, seize $0.977 (dust) | PASS |
| test_08 | largest auUSDC holder redeems 463,014.71 shares → 10,684.73 USDC | PASS |
| test_09 | auETH rate at drained cash = 1.2525e10/s ≈ 39.5%/yr (<200%/yr assertion) | PASS |
| test_10 | donate-5k-then-redeem round trip returns less than contributed | PASS |

CI (public repo `kingmariano/ca-zombie-ci`, workflow `poc.yml`):
- **Run 1:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37872704801 — 9/10: test_07 hit a
  transient public-RPC `connection reset` during the 140-account scan (infrastructure, not logic); the live
  scan was reduced to the top-30 accounts (full 140-account scan preserved in `analysis/health_scan.json`,
  `analysis/shortfall_positions.json`).
- **Run 2 (final):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37873265852 — **10/10 PASS**,
  fork block 219,167,386; PLY gain by fresh minter+claim = 0 wei; top-30 shortfall $10.36; real liquidation
  repay $0.916 → seize $0.977.

Reproduce locally: `cd poc && AURORA_RPC_URL=https://mainnet.aurora.dev forge test -vv`.

## 6. Verdict & residual/latent risk

**Verdict: E-U = $0.00 (high confidence).** The protocol is a fully functional but *deposit/redeem-only*
Compound fork: borrow caps of 1 wei and a keeper-gated, accurate oracle remove the entire extraction surface
the class is known for. The ~$1.12M of user claims is holder-recoverable (H-O); $117.9k of reserves is
admin-only (P). Nothing is meaningfully stuck (S).

Residual/latent risks worth monitoring (none attacker-profitable today):
1. **Borrow caps are one admin tx away from being raised.** If a future admin sets them back to 0/unlimited,
   the standard Tectonic-class surface (donation + thin markets + oracle) returns immediately. Watch
   `_setMarketBorrowCaps`.
2. **Oracle owner is a single EOA.** A leaked key controls all prices; with borrowing off, impact is limited
   to liquidations of the $30 dust book and mark-to-market (no borrow/farm leg).
3. **Market bricking (griefing, no profit):** if cash is redeemed below `reserves − borrows`, the IRM
   underflows in checked math and every `accrueInterest()` reverts; anyone can un-brick by donating
   underlying. Only reachable today in auUSDC after ≈$72k of redemptions.
4. Orphan markets auTRI/auPLY/auUSN have no oracle price (CF=0, non-borrowable) — holders can still redeem
   (H-O); only accounts foolish enough to have *entered* them would face revert-loops on liquidity checks,
   and entering those CF=0 markets is itself impossible (`enterMarkets` reverts).
5. Largest auETH borrower concentration: the $178.9k ETH debt is held by over-collateralized accounts
   (none appear in the shortfall scan); a price/interest shock large enough to move them is not reachable
   with the current 1-wei caps.
6. **`sweepToken` missing admin gate (grief-only, $0 today):** any EOA can forward an auToken's non-underlying
   stray balances to the admin Safe; all stray balances are verified zero across all 14 markets, and the
   recipient cannot be redirected. Fix by restoring upstream's `require(msg.sender == admin)`.

## 7. Methodology & sources

- Sources: explorer.aurora.dev verified sources (`Comptroller.sol`, `AuErc20.sol`, `AuETH.sol`,
  `Unitroller.sol`, `JumpRateModel.sol`, `PULP.sol`); live `eth_call`/`eth_getStorageAt`/`eth_getLogs`
  via `https://mainnet.aurora.dev`; DefiLlama/CoinGecko prices at 2026-10-09; explorer token-holder and
  log APIs; GoldRush (Aurora sunset — unused).
- Evidence: `analysis/health_scan.json` (5,480 borrowers), `analysis/shortfall_detail.json`,
  `analysis/shortfall_positions.json`, `analysis/markets_raw.json`, `analysis/market_table.json`,
  `analysis/borrows_*.json` (per-market Borrow logs), `analysis/src/*` (verified sources),
  `analysis/math-review.md` (full math audit), `analysis/child-math-review.md` (independent review).
- Limitations: point-in-time reads (block 219,162,280; fork blocks ~219,165–219,168k); bridged-asset marks
  (USDC.e/USDT.e/WBTC.e at par) may overstate H-O exit value if bridge redemptions are discounted —
  that affects holder value, not attacker extraction. The oracle is unverified; its non-keeper functions
  were probed live, not source-reviewed.

## 8. Files

```
aurigami/
├── README.md                      # this file (deliverable)
├── summary.json                   # machine-readable verdict
├── analysis/
│   ├── market-table.md            # full 14-market table (generated)
│   ├── market_table.json          # same, machine readable
│   ├── math-review.md             # Exp/Double math + path audit
│   ├── child-math-review.md       # independent adversarial review
│   ├── markets_raw.json           # raw calls, block 219,162,280
│   ├── health_scan.json           # 5,480 borrower health scan
│   ├── shortfall_detail.json      # per-market snapshots of shortfall accounts
│   ├── shortfall_positions.json   # 140 dust positions, USD
│   ├── borrows_*.json             # Borrow event logs per market
│   ├── borrowers_*.json           # unique borrower sets per market
│   ├── enumerate_markets.py …     # reproducible scripts
│   └── src/                       # downloaded verified sources
├── poc/                           # Foundry fork tests (10/10 PASS)
└── ci-log.txt, ci-artifacts/      # CI evidence
```

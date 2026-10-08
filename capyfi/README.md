# C2-13 — CapyFi (Compound v2 fork): live extractable-value assessment

**Date:** 2026-10-08 · **Chains:** Ethereum (1), Base (8453), World Chain (480), LaChain (274)
**Status:** read-only; fork-verified PoCs only; **no mainnet transactions signed or sent**.
**Comptroller (Ethereum):** `0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA` (Unitroller proxy → impl `0x00dc4965916e03A734190fA382633657c71f867E`)
**Primary evidence block:** Ethereum 26,149,473–26,149,795 · World Chain 36,074,434 · LaChain 23,472,941

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| Ethereum lending markets (13 caTokens, $6.9M real cash, $7.55M borrows) | **$0** | Donation/inflation is net-negative in stock Compound (PoC: −$85.9k on a $100k donation); caLAC/caRPC mint is whitelist-gated (live revert); oracles are real Chainlink (ETH/USDT/USDC/WBTC) or team-pushed aggregators 1.4–21% *below* spot (LAC/RPC); no profitable liquidations (only $2.0k bad debt backed by $0.46) | Oracle-updater key (1-of-1 Safe) can misprice LAC/RPC; admin can upgrade/pause |
| **stBTC vault (Ethereum, adjacent product)** | **≈ $2–3 per report cycle** (≈ **$105/day** flow) — permissionless yield-sniping, zero-fee flash loan, currently harvested hourly by a third-party MEV searcher | `YieldOracle.reportYield()` is **permissionless**; reported yield lands on all current holders pro-rata, so a same-tx depositor captures it | If operator raises `apyBps` from 10 bps to e.g. 500 bps, the leak scales to ~$57k/day |
| World Chain (7 markets, $44.8k cash) | **$0.02** (dust) | 19 shortfalls, total $0.0229; caLAC mint whitelist active (0 members) | Admin Safe can drain $44.8k; deployer EOA can upgrade caWBRL ($24.2k) |
| Base (see §5.3) | **$0** | 32 borrowers, zero shortfalls; no whitelist; oracles canonical Chainlink or bounded team feeds | Token-role EOA key risk |
| Base (7 markets, $83.1k cash) | **$0** | 32 borrowers, zero shortfalls; no whitelist needed — nothing extractable; oracles canonical Chainlink or bounded team feeds reading high | Token roles on an EOA (key risk only) |
| LaChain (274, 7 markets) | **$0** | Only CF>0 collateral is cLAC (native LAC); oracle is a 4-of-7-multisig SimplePriceOracle 1.4% below spot; borrowable stable liquidity ≈ $44k; buying enough LAC to borrow it is economically impossible (only live venue is an $8.5k Uniswap v4 pool) | 4-of-7 multisig oracle/admin; cUXD market insolvent on paper (~$5k bad debt) |

**Total live extractable now (E-U): ≈ $2–3 one-shot / ≈ $105 per day ongoing (stBTC yield-sniping); lending protocol E-U = $0; plus a latent $17.1k residual draw on the under-margined caLAC whale position (§3.5).**
**Confidence: high** for the lending closures (code diff + live reads + fork PoCs), **high** for the sniping mechanism (CI PoC), **medium** for the exact ongoing rate (depends on the operator's `apyBps`, currently 10 bps).

---

## 2. What CapyFi is, and the class under test

CapyFi is a Compound v2 fork. The deployed Comptroller/CToken code is **byte-for-byte stock Compound v2 (master)** except:
1. `mintInternal` is wrapped in `_checkWhitelist(msg.sender)` — when a market has a whitelist contract set and `isActive()==true`, only whitelisted accounts can mint (supply) that market. Nothing else (redeem/borrow/repay/liquidate/transfer) is whitelist-gated.
2. `Comptroller.getCompAddress()` returns `address(0)` (no COMP token).
3. `ErrorReporter` gains `SetWhitelistAdminOwnerCheck()`.

Diff evidence: `analysis/sources/impl_comptroller_files/Comptroller.sol` vs upstream `compound-finance/compound-protocol@master` differs by 2 lines; `CToken.sol` differs only by the whitelist additions; `CErc20.sol`/`CErc20Delegate.sol` diff empty.

The finding's class is "donation / exchange-rate inflation". In stock Compound, donating underlying to a cToken raises `exchangeRate = (cash + borrows − reserves)/totalSupply` for **all** holders pro-rata, so the donor's own claim only recovers `m·D/(S+m) < D` of the donation. There is no path to profit without a modified fork (e.g., Onyx/Sonne-style). Our fork PoC confirms a **net loss** (§6).

---

## 3. Live-state assessment — Ethereum

### 3.1 Protocol parameters (block 26,149,473)

| Parameter | Value |
|---|---|
| Comptroller impl | `0x00dc4965916e03A734190fA382633657c71f867E` (verified, stock Compound) |
| `admin()` / pendingAdmin | `0x6C15e4Bc44CC5674b1d7956D0e9596d2E509eD24` / `0x0` |
| `pauseGuardian` | `0x0` (unset) |
| closeFactor / liquidationIncentive | 0.50 / 1.08 |
| protocolSeizeShare (cToken const) | 2.8% (net liquidator bonus ≈ 4.98% of repay) |
| `transferGuardianPaused` / `seizeGuardianPaused` | false / false |
| Oracle | `0xfbA2712d3bbcf32c6E0178a21955b61FE1FF424A` (`ChainlinkPriceOracle`, owner = admin) |
| Whitelist contract | `0x302a893B1AC44fed29Cdf3e3a0a083d1Df3ce54E` (ERC1967Proxy → `0x6b787016c8aea6e929fba643178e453eaad0f750`), `isActive()==true` |

### 3.2 Market table (block 26,149,474; USD at oracle prices)

Full machine-readable table: `analysis/ethereum_market_table.md` / `analysis/markets_ethereum.json`.

| market | underlying | CF | cash USD | supply USD | borrows USD | whitelist |
|---|---|---|---|---|---|---|
| caUXD | UXD | 0 (paused) | $11.94 | $25.39 | $14.81 | – |
| caETH (legacy) | ETH | 0 (paused) | $90.86 | $114.96 | $24.71 | – |
| caLAC | LAC | 0.60 | **$1,175,086** | $1,177,158 | $2,076 | **active** |
| caWBTC | WBTC | 0.80 | $471,520 | $571,070 | $99,551 | – |
| caUSDT | USDT | 0.85 | **$1,212,777** | $3,252,298 | $2,041,334 | – |
| caUSDC | USDC | 0.85 | $363,594 | $1,215,040 | $852,265 | – |
| caETH | ETH | 0.80 | **$3,024,312** | $7,265,697 | $4,256,281 | – |
| caRPC | RPC | 0.50 | **$43,346,082 (nominal)** | $43,346,083 | $1.24 | **active** |
| caWARS | wARS | 0 | $220,706 | $504,597 | $284,844 | – |
| caWBRL | wBRL | 0 | $423,810 | $440,527 | $16,727 | – |
| caWMXN/wCOP/USDar | — | 0 | $36.12 | $36.12 | $0 | – |

Notes:
- **caRPC nominal cash is 4.09B RPC** valued at the team-set $0.010598. The only real RPC venue is a Uniswap v4 RPC/USDC pool with ~$19.6k liquidity; a $100k RPC sale nets ~$8.9k (child measurement). The RPC market's realizable cash is ~$2k, not $43M. It is excluded from "real cash".
- **Real cash (ex-RPC)** ≈ **$6.89M**; supplier claims (ex-RPC) ≈ $14.4M; borrows ≈ $7.55M. This matches DefiLlama TVL ≈ $6.96M.

### 3.3 Oracles / feeds

| market | feed | source | live price | reference spot | note |
|---|---|---|---|---|---|
| ETH, USDT, USDC | Chainlink canonical | `0x5f4eC3Df…b8419`, `0x3E7d1eAB…e32D`, `0x8fFfFfd4…18f6` | $2,432.46 / $0.99929 / $0.99986 | same | real feeds |
| WBTC | `WBTCPriceFeed` `0x45939657…e581` (Compound canonical WBTC/BTC × BTC/USD) | two Chainlink feeds | $81,354.96 | ~$81.5k | not manipulable beyond Chainlink |
| LAC | `CapyfiAggregatorV3` `0xF3585f9D…e6D4` | owner/authorized push | $0.010015 | $0.010158 (v4 spot) | **1.4% below spot**; bounds $0.0085–$0.0115 |
| RPC | `CapyfiAggregatorV3` `0x5da9a0bc…5437` | owner/authorized push | $0.01059766 | $0.010620 | **0.2% below spot**; bounds $0.01–$0.02 |
| wARS/wBRL | Chainlink `EACAggregatorProxy` | canonical | $0.000659 / $0.19939 | — | CF=0 (non-collateral) |
| wMXN/wCOP/USDar | CapyfiAggregatorV3 | push | — | — | CF=0 |

The `ChainlinkPriceOracle` (`0xfbA2712d…`) performs **no staleness check** and returns 0 on `answer<=0`. The LAC/RPC feeds are updatable by the owner (admin Safe `0x6C15e4Bc…`) and by authorized addresses — per the LaChain child's tracing: on Ethereum the LAC/RPC feeds are pushed by a **1-of-1 Safe** (`0xBf41C0DC…`, owner EOA `0xaCDC3EBA…`). That is a **key risk (P)**, not a permissionless path.

### 3.4 Whitelist gate (live proof)

- `whitelist.isActive() == true`; `isWhitelisted(a) == hasRole(WHITELISTED_ROLE, a)`; only the `DEFAULT_ADMIN_ROLE` (the 4-of-7 team Safe `0x6C15e4Bc…`) can grant it. Exactly **3 whitelisted EOAs** (`0xBac110FF…`, `0x9FB13A7d…`, `0xB6E17577…`), zero revocations, no self-registration/batchAdd, UUPS admin-gated.
- `cast call caLAC.mint(...) --from 0x1111…` → `execution reverted: WhitelistAccess: not whitelisted`; same for caRPC (live, read-only simulation).
- Fork test `test_lac_rpc_mint_whitelist_blocks_attacker` reproduces both reverts; control `test_usdt_mint_open_control` shows caUSDT mint succeeds for a funded attacker.
- **Historical caveats** (why cLAC exists in third-party hands): caLAC had **no whitelist at all until block 23,235,190** (mint permissionless before); caRPC ran a temp whitelist that was **inactive** between blocks 23,248,204–23,284,148 (check skipped; the admin minted 100k RPC then). Today the gate is hard.
- Consequence: a fresh unprivileged attacker **cannot mint caLAC/caRPC**. cToken **transfers are not gated**, so cLAC bought on a secondary market could still be used as collateral (CF 60%) — but no new supply can be created, and no secondary market exists.

### 3.5 Borrower health (all 13 markets, block 26,149,795)

Full data: `analysis/big_markets_borrower_health.json`, `analysis/small_markets_borrower_health.json`, `analysis/liquidatable_positions.json`.

- 25 borrowers in the big markets; aggregate account liquidity **$15.14M** vs $7.55M debt — the book is heavily over-collateralized.
- Only **2 accounts with shortfall > 0**:
  - `0x7CcA9233…8D51`: shortfall **$2,015.80** (debt 201,314.7 LAC), collateral 904,997 cETH-wei ($0.45) + 0.138 cUSDC ($0.003) → **uncollectible bad debt**; a liquidator can recover at most ~$0.45 of collateral for ~$0.42 of repaid LAC (gross ≈ $0.02, below gas).
  - `0x54C32309…125f`: shortfall **$0.20** (dust; collateral exists but markets not entered).
- Small markets: 3 further dust shortfalls ($1.42, $1.90, $13.08), all with <$0.5 collateral → dust.

**No profitable liquidation exists on Ethereum today.**

### 3.6 The under-margined caLAC whale (latent, $17.1k residual draw)

`analysis/whitelist_and_suppliers.md`: **98.33% of caLAC supply** is one non-whitelisted EOA `0x677f699053987fA3F6C52506b4C9317bBF63aF47`, minted **pre-whitelist** (blocks 22,224,811 / 22,520,679 / 22,618,144; LAC released via the team ChainBridge `0x450cbb88…` + 1:1 `migrate()`), which has borrowed **588,292.15 USDT + 107,249.70 USDC ≈ $695.5k** at ~98% LTV.

Live position (block 26,149,795): collateral 115.58M LAC ($1,157,530) + 9.017 ETH ($22,159); debt $695,107; **liquidity +$17,138**. A **−2.47% LAC oracle move** (to ≈$0.00977, inside the feed's $0.0085–$0.0115 bounds) makes it liquidatable, and the incumbent can draw the remaining **$17.1k** to max LTV at any time. Realizable liquidation profit is however bounded by LAC exit liquidity: the only live LAC venue is a Uniswap v4 LAC/USDC pool with ~$8.5k (a $100k LAC sale nets ~$4.1k), so seizing cLAC (nominal value) does not convert to cash. The $695.5k of stables is the concrete value already out of the protocol; the residual protocol risk is supplier loss if the position defaults (S/H-O), not an attacker path.

**caRPC cash is 100% team-supplied (P):** whitelisted EOAs `0xb6e175…` (75.5%) and `0x9fb13a…` (24.5%) + admin Safe, all funded by the team RPC treasury Safe `0xf0b223f5…` immediately before minting. RPC = "Ripio Coin" (2018); 53.4% of supply sits in the same team Safe. The RPC oracle ($0.01059766) is team-set, ~0.2% *below* the only live v4 pool ($19.6k).

---

## 4. The stBTC vault (adjacent CapyFi product, $45.9M nominal)

The docs list a second product on Ethereum: an "OffchainBtcVault" (stBTC). It is in scope for "what can an unprivileged attacker extract from CapyFi".

### 4.1 Stack (all verified, block 26,149,795)

| Contract | Address | Roles |
|---|---|---|
| Vault `OffchainBtcVault` (proxy → `0x243eadfc…e9ea`) | `0x6cbe98Eb2CdF0bc2E52A9b3ed014cd1740A4B30C` | DEFAULT_ADMIN, OPERATOR, REPORTER |
| stBTC shares (proxy → `0x59f1430a…f87d`) | `0xb40dC920dfc7BD7d68322a0E1b8A05557AdbeC54` | admin + COMPLIANCE; **whitelistEnabled == false**; not paused; no deposit caps |
| YieldOracle (proxy → `0x84332955…ce96`) | `0x331e42aE8678A0c1BEB4cfC80FfF5A884d0877b2` | OPERATIONS; **reportYield(strategy) is permissionless** |
| Strategy (registered identity) | `0xbAD529586bBDb37D975184fa57805809bb205c70` | EOA (operator-controlled) |

### 4.2 Live accounting

- `availableBalance()` = **93.63831410 WBTC** on-chain ($7.64M)
- `offchainBalance()` = **470.64873626 WBTC** (operator bookkeeping claim)
- `totalManagedAssets()` = **564.28705036 WBTC** ($46.0M)
- stBTC `totalSupply` = **563.68798591** shares → NAV ≈ 1.00106 WBTC/share
- `strategyPrincipal` = 470.001 WBTC; the strategy EOA actually holds **317.03928303 WBTC**; the rest sits at other operator addresses / was swapped (70 WBTC went through the Uniswap v4 PoolManager) — **custody risk, operator-controlled (P)**
- `minLiquidityBps` = 500 → instant withdrawal cap = 93.638 − 5%×564.287 = **65.424 WBTC ≈ $5.34M** (H-O)
- `maxWindowYieldBps` = 100 (1%/window), `yieldReportWindow` = 1 day; oracle `strategyApyBps` = **10 bps**, `minReportInterval` = 1 h
- stBTC holders: 3 (348.58 / 199.54 / 15.56 shares)

### 4.3 The open path — permissionless yield sniping (E-U)

`YieldOracle.reportYield(strategy)` has **no access control**; it computes `yield = strategyPrincipal × apyBps × elapsed / (10000 × 365d)` and calls `vault.reportYield()`, which **increases `offchainBalance`** and therefore the stBTC share price for all holders. An attacker can, in one atomic transaction with a **zero-fee Morpho flash loan** (observed incumbent) or any capital:
1. deposit WBTC into stBTC at the pre-report price,
2. call `reportYield(strategy)` (permissionless),
3. redeem at the post-report price,
4. repay the flash loan.
The attacker captures `deposit/(supply+deposit)` of the yield accrued since the last report — value diluted from existing holders, without having provided principal during the accrual.

**Observed live exploitation:** address `0xa0F1C3aD83E07d97B5e7030e177718bE175275ea` (EIP-7702-delegated EOA) does exactly this **every ~1 hour**: flash-borrows ~1,305 WBTC from Morpho `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`, deposits → `reportYield` → redeems → repays (tx `0xd3b720e8…9847`, block 26,149,411), capturing ~3,745 sats ($3.05) per cycle; the leftover is routed to the Uniswap v4 PoolManager (`0x…4444…`).

**Live magnitude:** at `apyBps = 10` (0.1%), accrual = 470 WBTC × 0.001 / 365 ≈ **0.00129 WBTC/day ≈ $105/day**; current pending yield ≈ **1,591 sats ($1.30)** per report window (incumbent keeps it drained hourly). If reports were to stop, accrual accumulates (window cap 1%/day) and a single permissionless call can capture it — the PoC proves **0.0247 WBTC ($2,010)** captured after a 30-day gap.

---

## 5. Other chains

### 5.1 World Chain (480) — E-U ≈ $0.02
- Unitroller `0x589d63300976759a0fc74ea6fA7D951f581252D7` (impl `0xD103A8…`), oracle `0x9E60d50407520eD4b6d47906B6c74Bc5D99aD282`, admin Safe `0x6C15e4…` (4-of-7).
- 7 markets (docs list 6; extra **caWBRL** `0x90208d…`, $24.2k cash, admin still a deployer EOA — handover pending). Total cash $44,836; borrows $11,853.
- caLAC mint whitelist active with **0 members** (frozen supply). 527 debtors scanned → 19 dust shortfalls (total $0.0229). Liquidations already bot-run.
- Feeds: CapyFi aggregators pushed by a 1-of-1 Safe; no staleness checks; 4 feeds unbounded. wARS +5.8%, LAC −20% vs reference. Tail risk is privileged (admin can drain, deployer can upgrade caWBRL).
- Detail: `analysis/worldchain_findings.md`, `analysis/worldchain_markets.json`.

### 5.2 LaChain (274) — E-U ≈ $0
- Unitroller `0x123Abe3A273FDBCeC7fc0EBedc05AaeF4eE63060`; oracle `0x4E07BDEe…` = SimplePriceOracle, admin/owner = 4-of-7 multisig `0x8D3bdc2E…`; 7 markets; no whitelist.
- Only borrowable collateral with CF>0 is cLAC (native LAC, CF 75%, cash 71.8M LAC ≈ $718k at the admin price $0.009995 — **1.4% below** the only real spot $0.010158). Borrowable stable liquidity ≈ $43k USDC + $1.1k USDT + dust.
- Buying enough LAC to borrow that is economically impossible (only live venue: Uniswap v4 LAC/USDC with ~$8.5k; a $100k LAC sale nets ~$4.1k). DEX pumps do not feed the multisig oracle.
- cUXD market is insolvent on paper (~$5k gap); cWETH/cWBTC/cUSDC are 83–100% utilized.
- Detail: `analysis/lachain_findings.md`, `analysis/lachain_markets.json`, `analysis/lac_rpc_liquidity.md`.

### 5.3 Base (8453) — E-U ≈ $0
- Unitroller `0x00dc4965916e03A734190fA382633657c71f867E` (impl `0xD31F102994eD0b01E5d5D25CBA0a4bFBCA9c5076`, Comptroller source byte-identical to Ethereum; the docs' address collision with the Ethereum impl is CREATE-order reuse by deployer `0x6a138b…`, benign), oracle `0x03c1cF154d621E0Fd7e2b88be3aE60CCf07Aca31` (ChainlinkPriceOracle), admin Safe 4-of-7.
- 7 markets (docs list 5; two undocumented: caWMXN, caWCOP). Total real cash ≈ **$83.1k** (ETH $5.9k, cbBTC $6.1k, USDC $15.0k, wARS $27.6k, wBRL $28.5k, wMXN/wCOP $27); borrows $4,591; every market exactly backed.
- 32 unique borrowers scanned; **zero shortfalls**; nothing liquidatable. No whitelist; nothing paused.
- Oracles: canonical Chainlink proxies (ETH/cbBTC/USDC/BRL/MXN) or bounded team-pushed feeds updated ~2h by Safe `0x35ede363…`, reading 0.3–5.8% *high* (no borrow arb). Sole trust note: token roles (wARS/wBRL/wMXN/wCOP) on EOA `0x5CA3F8EE…` — key-compromise risk only.
- Detail: `analysis/base_findings.md`, `analysis/base_markets.json` (block 52,349,895).

---

## 6. PoC / fork verification (CI)

Foundry project: `poc/` (vendored `forge-std`; pinned fork via `FORK_RPC_URL`; no mainnet transactions).

**CI runs (GitHub Actions):**
- **Final: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37834120235 — 6/6 tests PASS**
- Earlier: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37830202881 — 5/5 PASS (log: `ci-log.txt`)
- One intermediate run (37833852966) flaked on a transient RPC "block not found" in `test_usdt_mint_open_control`; it passed on both other runs and locally.

| Test | Result | Key numbers |
|---|---|---|
| `test_state_snapshot` | PASS | captures live market/vault state at fork block |
| `test_donation_inflation_does_not_profit` | PASS | deposit 200k USDC + donate 100k USDC → redeem $214,132; **net loss $85,868** (proves the donation class is closed in stock Compound) |
| `test_lac_rpc_mint_whitelist_blocks_attacker` | PASS | caLAC & caRPC mint revert `WhitelistAccess: not whitelisted` for an unprivileged address |
| `test_usdt_mint_open_control` | PASS | control: caUSDT mint succeeds (4.74e12 cTokens) |
| `test_liquidatable_dust_is_unprofitable` | PASS | repaying 10 LAC ($0.10) seizes $0.105 of cETH; entire account's seizable collateral < $0.50 vs $2,015.80 shortfall |
| `test_stbtc_yield_sniping_permissionless` | PASS | after 30-day accrual: pending 0.03868 WBTC → sniper captures **0.02472 WBTC ($2,017)** atomically via Morpho zero-fee flash loan |

Gas: each test ≤ 1.36M gas; suite runtime ~3 s in CI.

---

## 7. Verdict, residual/latent risk, blockers

**Verdict.** The C2-13 lending protocol is **not extractable by an external unprivileged attacker** today: the donation/inflation class is closed by stock Compound math (fork-proven loss), the only team-priced collateral (LAC/RPC) is mint-gated by an active whitelist, real oracles are Chainlink, and the loan book is over-collateralized with only uncollectible dust shortfalls. The one genuinely open, permissionless extraction is the **stBTC vault's yield-sniping leak (~$2–3 per report, ~$105/day at the current 0.1% APY), which a third-party MEV searcher is already harvesting hourly**; an external attacker can compete for it (zero-fee flash loans make it capital-free).

**Latent risk (not E-U):**
- If the operator raises `strategyApyBps` (max 5,000 bps = 50%), the sniping leak scales linearly (e.g., 500 bps → ~$52k/month).
- The under-margined caLAC whale (§3.6): $695.5k stables already borrowed against LAC at ~98% LTV; +$17.1k residual draw available to that account; a −2.47% LAC oracle move makes it liquidatable, and a default would leave supplier losses (S/H-O).
- LAC/RPC `CapyfiAggregatorV3` feeds: owner = admin Safe; updater = a **1-of-1 Safe** (owner EOA `0xaCDC3EBA…`, EIP-7702) with bounds — key compromise enables mispricing LAC/RPC collateral and liquidations (P).
- Comptroller admin `0x6C15e4Bc…` (Safe v1.4.1, 4-of-7) can pause markets, change oracles/collateral factors, reduce reserves (~$2.9k), and upgrade the Unitroller implementation (P).
- stBTC vault: OPERATOR/REPORTER roles and the off-chain 470.6 WBTC claim are operator-custodied; the strategy EOA currently holds 317.0 WBTC (P). Instant withdrawals are capped at 65.42 WBTC by the 5% reserve (H-O); the remaining on-chain 28.2 WBTC needs operator returns or admin action.
- World Chain caWBRL's admin is still a deployer EOA (`0x3ee4af…`) — upgrade/param risk over $24.2k (P).
- LaChain cUXD bad debt ≈ $5k (S); Base token roles on EOA `0x5CA3F8EE…` (key risk).

**Blockers / caveats:** RPC token has no liquid market (DefiLlama has no price; only a $19.6k v4 pool) — the $43.3M "cash" in caRPC is nominal; LaChain/Blockscout APIs unavailable (read via RPC); the vault's off-chain claim cannot be verified on-chain.

---

## 8. Methodology & sources

- Addresses/roles/balances read live via public RPCs (`ethereum-rpc.publicnode.com`, `mainnet.base.org`, `worldchain…`, `rpc1.mainnet.lachain.network`) at recorded blocks; Etherscan V2 for sources/logs.
- Sources verified: Comptroller impl, CToken impl, Oracle, feeds, whitelist impl, vault/stBTC/YieldOracle (files in `analysis/sources/`).
- Upstream diff: `compound-finance/compound-protocol@master` (Comptroller differs 2 lines; CToken only whitelist additions).
- Prices: oracle reads + DefiLlama (`coins.llama.fi`) + Uniswap v4 pool reserves (child).
- Fork PoCs in `poc/` executed on GitHub Actions only.

**Files index:** `README.md`, `summary.json`, `analysis/` (market scans, feeds, whitelist, holders, borrower health, per-chain findings, sources), `poc/` (Foundry), `ci-log.txt`, `ci-artifacts/`.

*All four chains covered (Ethereum, Base, World Chain, LaChain); all children's raw findings are in `analysis/`.*

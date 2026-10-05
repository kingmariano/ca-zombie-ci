# C2-03 — Lybra V1 (Ethereum): permissionless liquidation bonus — deep-dive & net-extractability

**Campaign:** zombie-hunt II · **Chain:** Ethereum mainnet · **Date of work:** 2026-10-05
**Status:** read-only research; PoC fork-verified only (pinned block 26,127,193 + live fork). No mainnet transactions were signed or sent.
**Target:** Lybra V1 vault + eUSD token `0x97de57eC338AB5d51557DA3434828C5DbFaDA371` (non-proxy, verified `Lybra.sol`), Liquity PriceFeed `0x4c517D4e2C851CA76d7eC94B805269Df0f2201De`.

---

## 1. TL;DR

| Item | Result |
|---|---|
| Live path | `liquidation(provider, victim, etherAmount)` — permissionless; victim must be <150% CR; liquidator pays eUSD and receives **110%** of the repaid value in stETH |
| Underwater positions (pinned 26,127,193) | **17** of 399 debtors (0x2cc0…: 21.113 stETH / 55,244.96 eUSD @ CR 103.2%; 0x1309…: 3.925 stETH / 9,191.17 eUSD @ CR 115.3%) |
| Gross protocol bonus available | **2.2669 stETH = $6,122** (multi-round, all 17, 61,218 eUSD deployed); **1.2664 stETH = $3,420** one-shot; largest single-shot **1.0557 stETH = $2,851** |
| **Fresh unprivileged attacker — net cash** | **≈ $0 (high confidence)** — the bonus is fully capitalized into eUSD's market price; the mint path locks 1.6× capital and traps the gain as position equity |
| Capital requirement | mint path: **36.27 stETH ($97,949)** no-recycle; **11.33 stETH ($30,609)** absolute minimum with full recycling — **not flash-loanable** (fork-proven) |
| Why net is $0 | (a) Curve eUSD/USDC already asks **$1.1085/eUSD at 50 USDC** (vs $1.10 liquidation yield) and $1.27–$2.61 for size; (b) unwinding needs 61,218 eUSD while the entire live market is ~1.66k eUSD; (c) the flash-loan loop cannot close; (d) transient sub-$1.10 windows are sniped by MEV bundles in the same block |
| Who actually captures it | incumbent eUSD holders (legacy minters, LBR-staking eUSD rewards) and MEV/aggregator bundles — observed buying eUSD at $1.065–$1.081 and liquidating atomically (~$1.5 gross per ~$50 trade, gas-level net) |
| `superLiquidation` | blocked: global CR 187.25% > 150% (fork-proven revert) |
| Latent risk | any large eUSD holder setting allowance to Lybra re-opens the full $6.1k gross immediately; ETH −21% (or 12.2 stETH of collateral withdrawn) would flip global CR below 150% and open `superLiquidation` |

**Bottom line:** the wave-2 claim (+$2,882–$6,283 net) is correct as a **gross protocol bonus at oracle prices** but is **not extractable net by a fresh unprivileged attacker**. It is a *conditional* capture: profitable only for an actor who already holds eUSD at ≤ ~$1.09 cost basis (e.g., earned as LBR staking rewards) or who wins the same-block MEV race when Curve dips below $1.10. For a fresh attacker with only stETH/ETH capital, every viable path nets ≈ $0 after sourcing/unwind costs (and is negative after gas on the multi-round route).

---

## 2. The mechanism in exact terms

Verified source: Etherscan `Lybra.sol` (solc 0.8.17), `contracts/Lybra.sol`, function `liquidation` (lines 302–348):

```solidity
function liquidation(address provider, address onBehalfOf, uint256 etherAmount) external {
    uint256 etherPrice = _etherPrice();                    // Liquity PriceFeed.fetchPrice()
    uint256 onBehalfOfCollateralRate = (depositedEther[onBehalfOf] * etherPrice * 100) / borrowed[onBehalfOf];
    require(onBehalfOfCollateralRate < badCollateralRate, "Borrowers collateral rate should below badCollateralRate"); // 150e18
    require(etherAmount * 2 <= depositedEther[onBehalfOf], "a max of 50% collateral can be liquidated");
    uint256 eusdAmount = (etherAmount * etherPrice) / 1e18;
    require(allowance(provider, address(this)) >= eusdAmount, "provider should authorize to provide liquidation EUSD");
    _repay(provider, onBehalfOf, eusdAmount);              // burns eUSD shares FROM THE PROVIDER
    uint256 reducedEther = (etherAmount * 11) / 10;        // 110% of repaid value
    ...
    if (provider == msg.sender) { lido.transfer(msg.sender, reducedEther); }
    else { reward2keeper = (reducedEther * keeperRate) / 110; lido.transfer(provider, reducedEther - reward2keeper);
           lido.transfer(msg.sender, reward2keeper); }
}
```

Key properties (all fork-verified):

1. **Permissionless** — no role/pause gate; anyone can call, for any underwater victim.
2. **The eUSD is burned from the provider** (`_repay` → `_burnShares`). It is *not* transferred to the victim; it is destroyed. Therefore the eUSD used must exist in the caller's/provider's account at call time, and the market must be re-entered to get it back.
3. **Payout = 110% of the ETH-denominated repayment**, i.e. a 10% bonus; if caller ≠ provider, the keeper takes 1% of the payout (`keeperRate = 1`) and the provider keeps 109%.
4. **`superLiquidation`** (a different, full-liquidation regime) is gated by `globalCR < 150%`. Live global CR = **187.25%** → always reverts `overallCollateralRate should below 150%` (T1).
5. **eUSD is the Lybra contract itself** — a rebasing share token. Mint requires CR ≥ 160% (`safeCollateralRate`); deposits require ≥1 ETH/stETH per call. Debt is nominal $1; the ETH price comes from Liquity's oracle (chainlink/tellor composite, not flash-manipulable; $2,700.50 at pinned block, matching DefiLlama stETH $2,700.57).
6. **80.117 stETH of "excess income"** sits in the vault (`lido.balanceOf(vault) − totalDepositedEther`), redeemable 1:1 by eUSD holders via `excessIncomeDistribution`. This is the par ($1.00) floor for eUSD and caps the liquidation-bonus arbitrage near $1.10.

---

## 3. Live-state assessment (pinned block 26,127,193, 2026-10-05)

All values read via `eth_call` at block 26,127,193; source dump in `analysis/src/`.

| Check | Value |
|---|---|
| `fetchPrice()` (ETH/USD) | **$2,700.50** |
| `totalDepositedEther` | 61.570470569434976880 stETH |
| `totalEUSDCirculation` | 88,794.473385114144857812 eUSD |
| `getTotalShares` | 85,239.140226168927372476 |
| Global CR | **187.25%** (blocks `superLiquidation`) |
| `safeCollateralRate` / `keeperRate` / `redemptionFee` | 160% / 1 / 0.50% |
| `gov` | 0x078dc81e05cEb1E1743b9b5215b3bc83aFd9F8C0 (no relevant powers over liquidation) |
| Lido balance of vault | 141.686828102394417151 stETH |
| Excess income (par sink) | **80.116 stETH** |
| Borrowers enumerated | **880** (from 2,370 `DepositEther` events); 399 with debt > 0 |
| Underwater (<150%) | **17** — table below |
| `feeStored` | 48,785.57 eUSD |

### 3.1 Underwater positions and per-victim extraction model (exact contract integer math)

| Victim | CR | Collateral (stETH) | Debt (eUSD) | Max repayable (ETH) | Gross bonus (stETH) | eUSD deployed | Rounds |
|---|---|---|---|---|---|---|---|
| 0x2cc05782… | 103.21% | 21.113253 | 55,244.96 | 19.193869 | **1.919387** | 51,833.04 | 57 |
| 0x1309c007… | 115.34% | 3.925435 | 9,191.17 | 3.243386 | 0.324339 | 8,758.78 | 3 |
| 0x9874f9b0… | 84.26% | 0.046462 | 148.91 | 0.042238 | 0.004224 | 114.06 | 49 |
| 0x3528942b… | 98.39% | 0.033600 | 92.22 | 0.030545 | 0.003055 | 82.49 | 49 |
| 0xec7d08f5… | 89.12% | 0.033000 | 100.00 | 0.030000 | 0.003000 | 81.02 | 49 |
| 0x84eca34e… | 37.60% | 0.028126 | 201.99 | 0.025569 | 0.002557 | 69.05 | 49 |
| 0x5789a38a… | 50.40% | 0.025827 | 138.38 | 0.023479 | 0.002348 | 63.41 | 48 |
| 0xf71d161f… | 79.78% | 0.023925 | 80.98 | 0.021750 | 0.002175 | 58.73 | 48 |
| 0xae9db1ff… | 130.67% | 0.028524 | 58.95 | 0.014262 | 0.001426 | 38.51 | 1 |
| 0x508d090e… | 22.90% | 0.015355 | 181.03 | 0.013959 | 0.001396 | 37.70 | 48 |
| 0x16fa6b8f… | 130.06% | 0.024300 | 50.46 | 0.012150 | 0.001215 | 32.81 | 1 |
| 0x8c42a956… | 121.63% | 0.013800 | 30.64 | 0.010005 | 0.001000 | 27.02 | 2 |
| 0x34c49e4b… | 138.51% | 0.009500 | 18.52 | 0.004750 | 0.000475 | 12.83 | 1 |
| 0x6f471ecb… | 137.73% | 0.005100 | 10.00 | 0.002550 | 0.000255 | 6.89 | 1 |
| 0x4acf1f34… | 135.03% | 0.000500 | 1.00 | 0.000250 | 0.000025 | 0.68 | 1 |
| 0x9c57027b… | 135.03% | 0.000500 | 1.00 | 0.000250 | 0.000025 | 0.68 | 1 |
| 0x971740ed… | 134.16% | 0.000390 | 0.79 | 0.000195 | 0.000020 | 0.53 | 1 |
| **TOTAL** | | **25.355** | **65,604** | **22.669** | **2.266921 ($6,122)** | **61,218.20** | **409** |

Full data: `analysis/positions_all.csv`, `analysis/victims_table.csv`, `analysis/extraction_model_pinned.json`.
Note: at later blocks (price $2,684.58 on the CI run) the set becomes 18 as 0xa8e09d93… (149.16%) re-enters; totals are stable at ~2.27 stETH gross.

### 3.2 eUSD market depth — the decisive constraint

| Venue | Address | Live depth | Effective price |
|---|---|---|---|
| Curve eUSD/USDC (stableswap) | 0x880F2fB3704f1875361DE6ee59629c6c6497a5E3 | **1,542.32 eUSD / 2,809.43 USDC** | buy: $1.1085 @ 50 USDC → $1.2654 @ 500 → $2.61 to take the pool's entire USDC; sell: ~$1.082 @ 100 eUSD |
| Uniswap V2 eUSD/USDC | 0xd7C2b595e3348eA7913d81dDEB26313ce20861c2 | 118.14 eUSD / 129.24 USDC | ~$1.094 |
| Uniswap V4 eUSD/USDT 0.3% (pool id 0x32789be3…a2fb) | PoolManager 0x000000000004444c5dc75cB358380D2e3dE08A90 | ~$1.72k reserve, 0 tx/24h | ~$1.077 |
| Other V2/V3/V4/Curve pools | — | dead / liquidity 0 / dust | — |

Total eUSD purchasable across every live venue ≈ **3.3k eUSD (~$3.5k)**, and the *ask* exceeds the $1.10 liquidation yield for any size that matters. Unwinding the multi-round play requires **61,218 eUSD — 18× the entire market**.

---

## 4. What an attacker can and cannot do

### Path A — buy eUSD on market, liquidate, sell stETH (cash path)
- At the pinned block: 50 USDC → 45.106 eUSD = **$1.1085/eUSD**; 100 USDC → $1.1195; 500 USDC → $1.2654; entire pool USDC (2,809) → $2.6103. Liquidation yields exactly **$1.10/eUSD**. Every size is negative before gas (T5 fork-proves the quotes).
- Historically the pool dips below $1.10 when users sell eUSD into it. At block 26,124,098 three MEV-bundle liquidations bought eUSD at **$1.0653 / $1.0716 / $1.0806** and liquidated in the same tx (~$1.5 gross each, gas-level net). Those windows are same-block MEV territory.

### Path B — mint eUSD (1.6× collateral), liquidate
- Mechanics: deposit 1.6X stETH → mint X eUSD → `liquidation` → receive 1.1X stETH. Net worth **+0.1X**, exactly 10% of deployed eUSD (T2: 1.0557 stETH on the biggest victim; T4: 2.2669 stETH across all 17, 409 rounds).
- **Capital:** 36.27 stETH ($97,949) if minted in one go; 11.33 stETH ($30,609) absolute minimum with full recycling of seized stETH (final CR must stay ≥160%: C₀ ≥ 0.5·X_eth). T4 uses 37 stETH for the full run.
- **Cash flow is negative:** after the full run the wallet holds 24.94 stETH of seized collateral vs 36.27 stETH posted (−$30,609); the +$6,122 is **locked position equity at 160% CR** (liquidation threshold −6.25% ETH, and the position earns no stETH yield — the yield is socialized to eUSD holders).
- **Realization:** requires buying back 61,218 eUSD. The whole live market is ~1.66k eUSD and its ask is >$1.10 → realization cost ≥ the bonus. Net cash ≤ 0.
- **Risk:** the 36.27 stETH collateral is liquidatable by other bots if ETH drops >6.25% during the operation; at 160% CR the attacker is the next victim.

### Path C — flash loans
- **stETH flash loan → mint → liquidate → repay:** impossible. The liquidation burns the minted eUSD, the position stays at 160% CR with **zero withdrawable collateral**, and the seized 1.1X < 1.6X principal. Fork-proven: `withdraw(1 wei)` reverts `collateralRate is Below safeCollateralRate` (T3).
- **USDC flash loan → buy eUSD → liquidate → sell stETH → repay:** mechanically possible (this is exactly what the observed MEV/aggregator txs do) but bounded by Path A's pricing: negative at current quotes, ~$1.5 gross in transient sub-$1.10 windows, gas/MEV-negative standalone.

### Path D — keeper-only (caller ≠ provider, 1% fee)
- Requires a third party to have eUSD **and** an allowance to Lybra. Only one address ever approved Lybra (`0x9316b862…`, unlimited allowance, **0 eUSD balance**). All recent providers are self-executing bot/aggregator contracts with max allowance and near-zero balances. No passive-provider keeper income exists.

---

## 5. Bot competition (evidence)

- **330** `LiquidationRecord` events all-time; **36** in the last 180 days; **7 distinct providers** in the last 90 days; last liquidation **2026-10-05 05:39:23 UTC** (block 26,124,132) — the path is actively harvested.
- Providers are **contracts**, not EOAs: `0x7fd3519f…`, `0x0000000000be22…`, `0xa0f1c3ad…` (router), `0x00000f9110…` (MEV arb bot), `0x4545e978…`, `0x69947080…`, `0x00e2e97e…` — all hold max eUSD allowance to Lybra and ~0 eUSD between trades.
- Tx-level reconstruction (Etherscan internal txs + token transfers, `analysis/tx_*.json`):
  - block 26,124,098, `0x00000f9110…`: flash-borrows USDC from a Uniswap V3 USDC/WETH pool → buys eUSD on Curve (45.45 / 45.19 / 44.81 eUSD for 48.42 USDC each) → `liquidation` → sells stETH on the Curve stETH/ETH pool → repays; ~$1.5 gross per tx, bundled with other arb legs.
  - block 26,124,132, `0xa0f1c3ad…`: 49.80 USDC → 45.54 eUSD ($1.0936) → liquidate → stETH → WETH; part of a user swap route.
- The victim `0x2cc0…` was nibbled **9 times** on Oct 4–5 for ~1.3k eUSD total against a 55k eUSD debt — consistent with bots being limited by available eUSD, not by permission.

---

## 6. PoC / fork verification

`poc/` — Foundry project (vendored forge-std), tests in `poc/test/LybraC203.t.sol`; pinned archive fork block **26,127,193** (drpc.org archive RPC) plus a live fork for T7.

| Test | Proves |
|---|---|
| T1 `pinned_state_and_victims` | Exact pinned state: price $2,700.50, totals, all 17 victim positions exact, global CR 187.25%, `superLiquidation` reverts |
| T2 `single_shot_bonus_biggest_victim` | Liquidation of 10.5566 ETH repays 28,507 eUSD and returns exactly 11.6123 stETH (1.1×); net-worth delta +1.0557 stETH; cash after < capital posted |
| T3 `flashloan_cannot_close` | At max mint (~160% CR) `withdraw(1 wei)` reverts — flash loan of the 1.6× principal cannot be repaid |
| T4 `full_multiround_extraction` | 409 rounds, 61,218 eUSD deployed, 24.936 stETH seized, net worth +2.267 stETH (locked equity), gas measured |
| T5 `market_buy_path_unprofitable` | Curve ask > $1.10 for every size 50→2,809 USDC; eUSD bid < $1.09 |
| T6 `excess_income_par_sink` | 80.1 stETH excess income backing the $1 par redemption sink |
| T7 `live_state_still_open` | Live fork: >10 victims still <150%, global CR >150%, Curve still prices eUSD ≥ bonus |

**CI runs (GitHub Actions, `kingmariano/ca-zombie-ci`):**
- **Run 1: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37342453507 — `conclusion: success`, 7/7 tests PASS (12.75 s)**; artifact `result-lybra-v1` (`ci-out/live_state_latest.json`, `live_state_summary.txt`).
- The custom job `ci/run.sh` refreshed the full live state at CI block **26,127,414** (price $2,684.58, 18 underwater, global CR 186.15%, multi-round gross 2.26845 stETH = $6,089.84) and confirmed Curve's ask at $1.1085 (50 USDC) — the closed-for-fresh-attacker condition still holds live.

Exact CI fork numbers (pinned block 26,127,193):

```
T1: global CR 187.253833976376157593; superLiquidation reverts; 17/17 victims exact
T2: liquidated 10.556626542107129436 ETH; seized 11.612289196317842379 stETH (=1.1x);
    eUSD deployed 28,508.169976960303041919; net worth +1.055662654210712944 stETH;
    capital posted 16.891602467371407096 stETH; cash after 11.6123 stETH (< capital)
T3: withdraw(1 wei) reverts at ~160% CR -> flash loan cannot close
T4: 409 rounds; eUSD deployed 61,218.199291078959673725; stETH seized 24.936130057465970931;
    capital posted 37.0 stETH; net worth delta +2.266920914315087882 stETH (locked equity);
    cash after 24.9361 stETH (short $30,609 vs capital); gas 206,841,412 (test ctx,
    ~0.29 ETH ~= $777 at 1.39 gwei; ~$11.2k at 20 gwei - erases the bonus)
T6: excess income 80.116357532959440271 stETH (par sink)
T7 live: price $2,684.58; 17/17 committed victims still <150%; global CR 186.15%;
    Curve eUSD buy price $1.108498 > $1.10
```

---

## 7. Verdict and residual risk

**Classification:**

| Category | Amount | Confidence |
|---|---|---|
| **E-U (fresh external unprivileged, net cash)** | **$0** | **high** |
| E-U (conditional: incumbent eUSD holder at ≤$1.09 basis, or same-block MEV) | gross **$6,122** multi-round / $3,420 one-shot | medium-high on amount, high that it is conditional |
| H-O (borrower self-service) | remaining collateral belongs to borrowers; 5,003.68 eUSD held by victim 0x2cc0… | n/a |
| P (privileged) | none relevant (gov can change fees/rates only) | high |
| S (stuck) | none identified | high |

**Residual / latent risk:**
1. **Any eUSD holder with a standing allowance to Lybra is a live harvester.** If a legacy holder (or the LBR service-fee distribution) accumulates ≥ a few hundred eUSD and approves, the 10% bonus is immediately available to them (and to any keeper).
2. **`superLiquidation` tripwire:** if global CR falls below 150% (ETH ≈ −21% from here, or ~12.2 stETH of collateral withdrawn by healthy whales), the regime changes and full liquidations of <125% positions open (different, potentially larger bonus).
3. **eUSD liquidity return:** a new eUSD pool/market would immediately be arbed against the liquidation sink; any depth above ~$1.1/eUSD would re-open a cash path at up to the $6.1k gross.

**Blockers (why not today):** eUSD sourcing, not permissions. The only market is 1.66k eUSD and already priced at/above the 10% bonus; the mint path locks 1.6× with the gain trapped as illiquid equity; flash loans cannot close.

---

## 8. Methodology & sources

- **Enumeration:** all 2,370 `DepositEther`, 2,569 `Mint`, 2,987 `Burn`, 1,987 `WithdrawEther`, 330 `LiquidationRecord`, 401 `RigidRedemption` logs via Etherscan V2 (`analysis/fetch_logs.py`); 880 unique depositors; positions read for all 880 at pinned block and at the CI tip via batched `eth_call` (`analysis/read_positions.py`, `ci/fetch_live_state.py`).
- **State verification:** verified source (`analysis/src/`), `eth_call` reads of every parameter, exact integer-math simulation of the liquidation loop (`analysis/compute_positions.py`), live `lido.submit`/deposit/mint/liquidate fork execution.
- **Market depth:** on-chain `get_dy` quotes on the Curve pool, Uniswap V2/V3 factory lookups, Uniswap V4 pool list via GeckoTerminal, DexScreener; on-chain balances of all pools.
- **Bot forensics:** Etherscan `txlistinternal` + token transfers for the recent liquidation txs; provider/keeper decode from raw logs.
- **Prices:** Liquity `fetchPrice()` (on-chain), DefiLlama (`stETH $2,700.57` at query time), GeckoTerminal.
- **PoC:** Foundry 1.7.1, fork tests only, CI `kingmariano/ca-zombie-ci`.

**Caveats / limitations:**
- The +$6,122 gross is an *oracle-price* figure; selling 24.9 stETH on the Curve stETH/ETH pool would cost ~0.03–0.5% (the observed MEV txs paid ~0.03%), further reducing any net.
- Gas (CI-measured): the 409-round multi-round route used **206.84M gas in test context ≈ 0.288 ETH ≈ $777 at 1.39 gwei**; at 20 gwei the same route costs ≈ $11.2k and erases the $6,122 gross even in equity terms. The one-shot route (17–18 liquidations, ~2M gas) costs ≈ $8 at 1.39 gwei.
- Selling 24.94 seized stETH on the Curve stETH/ETH pool costs ~0.03–0.5% ($20–$340) depending on size/fee.
- Point-in-time reads; the victim set and eUSD price move with ETH. Re-verify before acting (CI job refreshes the state).
- The exact eUSD cost basis of incumbent harvesters (LBR rewards vs purchases) is inferred from on-chain flows, not from their books.
- No mainnet transactions were sent; all execution evidence is from local forks (CI).

**Files index:** `analysis/` (logs, position tables, extraction model, capital model, source dump), `poc/` (Foundry tests + interfaces), `ci/` (live-state refresh job), `ci-out/` (CI artifacts), `summary.json`.

# CapyFi on World Chain (chain id 480) — Zombie Hunt II deep-dive

**Scope:** read-only enumeration of the CapyFi Compound-v2 fork on World Chain, verification of the
documented deployment, USD valuation, liquidatable-borrower scan, and unprivileged-extraction analysis.

**Pinned block:** 36,074,434 (head at scan: 36,075,903) · RPCs: Alchemy public (primary),
thirdweb, dRPC (fallbacks) · Data: Etherscan V2 `chainid=480`, DefiLlama coins API.

**Artifacts:** `worldchain_markets.json` (full machine-readable dump), raw scan/evidence under
`c-13/analysis/worldchain/` (scan scripts, Borrow logs, per-account snapshots, verified sources).

---

## TL;DR

- The documented Unitroller **0x589d6330…** is the real CapyFi comptroller on World Chain; oracle, lens and
  Maximillion are also present and verified. **There are 7 markets on-chain, not 6** — docs omit **caWBRL**.
- **caLAC is a genuine World Chain market** (underlying LAC). Its address coincidentally equals the Ethereum
  ETH interest-rate-model address (cross-chain CREATE reuse); the docs note is a false alarm — verified on-chain.
- Total **cash ≈ $44.8k** (oracle prices) / **$44.2k** (DefiLlama reference); borrows ≈ $11.9k;
  supplier claims ≈ $56.6k.
- **19 accounts are currently liquidatable — all dust.** Total gross liquidation profit if every account were
  liquidated once ≈ **$0.019**, versus ~$0.001 gas per tx. There is **no material unprivileged extraction path**.
- The extractable value sits behind **privileged keys** (CapyFi admin Safe, deployer EOA, 1-of-1 price-updater
  Safe) and in oracle-design weaknesses (no staleness check; unbounded feeds on 4 assets). Details in §6.

---

## 1. Deployment verification (eth_getCode @ block 36,074,434)

| Docs address | Verdict | On-chain identity |
|---|---|---|
| Unitroller `0x589d63300976759a0fc74ea6fA7D951f581252D7` | ✅ verified | `Unitroller` proxy → impl `0xD103A8B88eC16B8279B9dCf83F11BA2b209a3ce6`; admin Safe `0x6C15e4…`; 7 markets |
| Price Oracle `0x9E60d50407520eD4b6d47906B6c74Bc5D99aD282` | ✅ verified | `ChainlinkPriceOracle` (non-proxy), owner Safe `0x6C15e4…` |
| CompoundLens `0xA386F452…C5658` | ✅ code present | view helper |
| Maximillion `0x511E89CA…b11a7` | ✅ code present | 400-byte contract |
| caETH `0xaAd91a…23ed` | ✅ | `Capyfi Ether` (CEther, non-delegator) |
| caWBTC `0xCdA6e3…796D` | ✅ | CErc20Delegator → `0xAcAa9b2c…` |
| caUSDC `0x05350F…D1Df` | ✅ | CErc20Delegator → `0x0C1f5c1C…` |
| caWARS `0xF36749…5FfA` | ✅ | CErc20Delegator → `0x629A7AF6…` |
| caWLD `0x57Dd24…Fc95` | ✅ | CErc20Delegator → `0x1483AC09…` |
| caLAC `0x03c1cF154d621E0Fd7e2b88be3aE60CCf07Aca31` | ✅ **real market** | CErc20Delegator → `0xf5FA0EA9…`; underlying LAC `0x0Fe75CAe…`; deployed by EOA `0x6a138b…` |
| **caWBRL `0x90208d4Be7F539bd46E0e0847085E672E23b3d9A`** | ⚠️ **undocumented market** | CErc20Delegator → `0x592a734B…`; underlying wBRL `0xD76f5Faf…`; deployed block 33,220,818 |
| Underlyings WBTC/USDC/wARS/WLD/LAC | ✅ | all code present, symbols match |

- Unitroller `getAllMarkets()` = `[caETH, caUSDC, caWBTC, caLAC, caWARS, caWLD, caWBRL]`.
- Docs' "caLAC = ETH IRM address" note is resolved: **address reuse across chains**, not a copy/paste error.
- Deployer of 6/7 markets: EOA `0x3ee4af9184f968558046cdCCa74F89B064eCD6Ce` (nonce 122). caLAC deployed by
  EOA `0x6a138bd6…` (nonce 22). All market admins were handed to the CapyFi Safe `0x6C15e4…`, **except
  caWBRL**, whose admin is still the deployer EOA with `pendingAdmin = 0x6C15e4…` (handover not accepted).
- Comptroller params: closeFactor 0.5, liquidationIncentive 1.08, pauseGuardian 0, all global pauses false,
  `compRate = 0` (no COMP), `maxAssets = 0` (unlimited; `enterMarkets` simulation returns 0), no deprecations.

## 2. Markets (block 36,074,434)

| Market | Underlying | Cash | Total borrows (current) | ExRate stored | CF | Oracle price | Cash USD (oracle / ref) | Mint/Borrow paused | Whitelist | Borrow cap |
|---|---|---|---|---|---|---|---|---|---|---|
| caETH | ETH (native) | 0.029 ETH | 0 | 2.0e26 | 80% | $2,436.21 | $70.65 / $70.85 | false/false | none | 0.3 ETH |
| caUSDC | USDC.e 6d | 14,694.02 | 10,813.87 | 1.0282e16 | 85% | $0.99986 | $14,691.97 / $14,688.62 | false/false | none | 20,000 USDC |
| caWBTC | WBTC 8d | 0.00494161 | 0.00000027 | 2.0e16 | 80% | $81,301.85 | $401.76 / $399.31 | false/false | none | 0.32 WBTC |
| caLAC | LAC 18d | 100.0 | 0 | 2.0e26 | 50% | **$0.008 (fixed)** | $0.80 / $1.00 | false/false | **active, 0 members** | 1,000 LAC |
| caWARS | wARS 18d | 8,283,174.5 | 49,385.84 | 2.0778e26 | 0% | $0.00065898 | $5,458.45 / $5,161.67 | false/false | none | 500,000 wARS |
| caWLD | WLD 18d | 22.31 | 0.48166 | 2.0002e26 | 0% | $0.47165 | $10.52 / $10.53 | false/false | none | 5 WLD |
| caWBRL | wBRL 18d | 121,237.06 | 5,045.66 | 2.0007e26 | 0% | $0.19963 | $24,202.15 / $23,835.40 | false/false | none | 20,000 wBRL |

- All reserve factors 10–50%; protocolSeizeShare 2.8%; all interest-rate models are separate contracts.
- caETH accrual is stale (block 21,774,982) but borrows = 0 and rate = 0 — no impact.
- Only caLAC has a whitelist. Its `mintInternal` applies `_checkWhitelist(msg.sender)`, but the whitelist
  (UUPS proxy `0xafBBC7Fc…`, impl `0x1897cae3…`) has **isActive = true with 0 members in WHITELISTED_ROLE** →
  **caLAC minting is effectively frozen for everyone**. Borrow/redeem are not whitelist-gated.
- Interest: borrowRatePerBlock (1e18): caUSDC 2.69e9, caWARS 3.41e9, caWLD 1.57e9, caWBRL 3.67e9,
  caWBTC 4.3e4, caLAC 1.27e9, caETH 0 (all below the 5e12 cap; modest APRs).

## 3. Oracle & feeds

- `ChainlinkPriceOracle.getUnderlyingPrice` returns `fixedPrice` for caLAC (8e15 → $0.008) and for the other
  markets reads `latestRoundData()` from a **CapyfiAggregatorV3** (Etherscan-verified, v0.8.10, custom
  Chainlink-compatible aggregator deployed by CapyFi).
- **The oracle ignores `updatedAt`/`answeredInRound`** — no staleness protection; a frozen feed keeps
  pricing indefinitely. It returns 0 for `answer <= 0` (collateral value → 0).
- Feed update path: `updateAnswer()` is `onlyAuthorized` (owner or `authorizedAddresses`). All feeds' owner is
  the CapyFi Safe `0x6C15e4…` **except the wBRL feed**, owned by deployer EOA `0x3ee4af…`
  (pendingOwner = CapyFi Safe, not accepted).
- One updater is authorized on **all six feeds**: `0x5c2c3e2ad9f9b19bb24f2b5183b9cf4eedd094a1` —
  a **Gnosis Safe v1.4.1 with threshold 1** (single owner EOA `0xaCDC3EBA…`).
- Bounds (`minAnswer/maxAnswer` in feed units): enabled only for wARS (0.0005–0.00077) and wBRL (0.10–0.30);
  **ETH, USDC, WBTC, WLD feeds have bounds disabled** → the authorized updater can set them to any positive value.
- Feeds are fresh at the pinned block (`updatedAt` ≈ block time). Oracle vs DefiLlama deviation:
  wARS **+5.8%**, wBRL **+1.5%**, LAC **−20.1%**, WBTC +0.6%, ETH −0.3%, WLD −0.1%, USDC +0.02%.
  The wARS overpricing is the main cross-check discrepancy; LAC is hard-coded below market.

## 4. Borrowers & liquidations

- Borrow event history: caUSDC 2,562 logs / 457 unique borrowers; caWARS 1,622 / 354; caWLD 133 / 61;
  caWBTC 97 / 40; caETH 1 / 1; caWBRL 1 / 1; caLAC 0.
- Current debtors (borrowBalanceStored > 0): caUSDC 307 ($10,813.89), caWARS 313 (49,388.58 wARS),
  caWLD 52 (0.4817), caWBTC 9 (27 sats), caWBRL 1 (5,045.66), caETH 0 — sums match `totalBorrowsCurrent`.
- `getAccountLiquidity` over all 527 current debtors → **19 accounts with shortfall > 0** (all other 508 healthy).
  Manual recomputation from snapshots + oracle prices matched on-chain liquidity **19/19** (max diff 3e-5 USD).
- Shortfalls are dust: largest $0.0107, total $0.0229. Using closeFactor 0.5 / incentive 1.08, max single-tx
  liquidation profit per account = `0.08 × min(50% debt, collateral/1.08)`; **grand total ≈ $0.0186**.
  Largest single opportunity: $0.0132 (account `0x16f1923b…`, repay ~$0.166 of wARS, seize cUSDC).
  Gas on World Chain ≈ 1.5e6 wei → a ~250k-gas liquidation costs ~$0.001, so at most a few cents are
  theoretically recoverable; several accounts net below zero. Liquidations are already actively bot-run
  (32 LiquidateBorrow events on caUSDC, 24 on caWLD, 1 on caWARS), confirming no larger opportunities persist.
- No non-dust shortfall exists under the *current* oracle prices; a feed move would be required to change that.

## 5. Donations, mintability, pauses

- Every market is mintable and borrowable (per-market and global pauses false); no deprecated markets.
- Donations to a cToken increase `exchangeRate` pro-rata for existing holders — they cannot be extracted by the
  donor. Historical example: at block **19,790,112** someone (0x63789f76…) transferred **10 USDC directly** to
  caUSDC while `totalSupply` was only 50 cTokens, spiking the exchange rate ~11× (2.0e14 → 2.2e15). No market
  is empty (min totalSupply = 50 cTokens caUSDC, 5,000 cLAC), so first-minter inflation is not applicable.
- caLAC mint is frozen by an active-but-empty whitelist; its $0.80 of cash is unreachable by minting (redeem
  by existing holders still works).

## 6. Extractable value today — assessment

**Unprivileged external attacker: ≈ $0.02 (dust liquidations), economically de minimis.** No other path found:
- Borrowing requires collateral (`getAccountLiquidity` enforced); oracle feeds are permissioned; no COMP;
  reserves are admin-only; `enterMarkets` works; exchange-rate math is standard Compound with no empty markets.
- The 1-of-1 updater Safe and feed owner EOAs are privileged, not attacker-accessible.

**Privileged / key-compromise paths (not unprivileged, but the real tail risk):**
1. CapyFi admin Safe `0x6C15e4…` (4-of-7) can upgrade comptroller/cToken implementations, swap the oracle,
   list markets and sweep reserves — i.e., can drain up to the full ~$44.8k cash.
2. Deployer EOA `0x3ee4af…` is still admin of **caWBRL** (can `_setImplementation` and drain its $24.2k cash)
   and owner of the wBRL feed (bounded 0.10–0.30).
3. Price-updater Safe `0x5c2c3e…` is **1-of-1** (single EOA). It can update all feeds; the ETH/USDC/WBTC/WLD
   feeds are unbounded, so a compromised updater key could mis-price collateral → borrow against inflated
   collateral (up to available cash) and/or trigger mass liquidations.
4. No staleness check in the oracle: if the updater stops, prices freeze; combined with volatile markets this
   creates bad-debt/liquidation risk.

## 7. Method & caveats

- Code/identity checks with `eth_getCode` and Etherscan V2 `getsourcecode` (chainid=480); market scan pinned at
  block 36,074,434; Borrow logs via Etherscan V2 `getLogs` (topic0 `0x13ed6866…`), paginated 1000/page.
- USD via oracle price (`base × price / 1e36`) and independently via DefiLlama `coins.llama.fi` (2026-10-08).
- Liquidation profit is an upper bound using stored snapshots/exchange rates and oracle prices at the pinned
  block; actual realization depends on DEX liquidity for the tiny debt tokens (wARS/wBRL) and gas.
- Shortfall accounts were measured at the pinned block; interest accrual may marginally add/remove dust accounts
  over time, but the order of magnitude is unchanged.

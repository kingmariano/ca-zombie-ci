# Moonlander — H2-02 deep dive (Cronos + Cronos zkEVM)

**Status: read-only; PoC fork-verified only; no mainnet transactions.** All live reads were performed with
`eth_call`/`eth_getCode` at explicit blocks. All state-changing experiments run on local forks inside GitHub
Actions (see §5). Addresses and amounts were re-verified at block **99,057,951** (Cronos) and **2,671,544**
(Cronos zkEVM) on **2026-10-10**.

---

## 1. Target

Moonlander = perpetual DEX + MLP liquidity pool + staking on Cronos EVM (25) and Cronos zkEVM (388).
The implementation is an evolved fork of the **ApolloX / Aster** GMX-v1-style perp codebase
(`apollox-finance/apollox-perp-contracts`, `asterdexcom/asterdex-perpetual-contracts`): same role names
(`ADMIN_ROLE`, `TOKEN_OPERATOR_ROLE`, `PAIR_OPERATOR_ROLE`, `KEEPER_ROLE`, `PRICE_FEEDER_ROLE`, `MONITOR_ROLE`,
`DEPLOYER_ROLE`, `WITHDRAW_MINT_ALP_ROLE`), same libraries (`LibVault`, `LibPriceFacade`,
`LibAccessControlEnumerable` with storage slot `keccak256("apollox.access.control.storage")`), same
facet family. Moonlander adds: EIP-712 `TradingPortalFacet` (`batchExecuteOpenMarketOrders`/`batchExecuteCloseMarketOrders`
with caller-supplied `PriceData`), `PythPriceFacet`, partner/hook manager, limit orders, and renamed
ALP→MLP. Public sources for the *exact* live revision were not found (no keyless verified source on Cronos);
selectors were mapped to the family sources and every conclusion below was **tested behaviourally against
live bytecode on a fork**, not assumed from source.

Main prize: `0xE6F6351fb66f3a35313fEEFF9116698665FBEeC9` (23-facet EIP-2535 diamond), holding
**15,935,653.166386 USDC**.

---

## 2. Live state (Cronos block 99,057,951; zkEVM block 2,671,544)

### 2.1 Contracts and balances

| Address | What | Code | Balance at block |
|---|---|---|---|
| `0xE6F6351fb66f3a35313fEEFF9116698665FBEeC9` | Moonlander diamond (23 facets) | diamond proxy, 231 B runtime + 23 facets | **15,935,653.166386 USDC** (6d) |
| `0xb4c70008528227e0545Db5BA4836d1466727DF13` | MLP token (EIP-1967 UUPS, impl `0x66615337…d07e`) | yes | totalSupply 16,513,957.320440105252093991 MLP |
| `0x071788084370497ED1Ac19C6711bd1d4Af0E9034` | StakedMlpTracker "sMLP" (UUPS, impl `0x8724f28f…902c`) | yes | **16,512,353.945970029022841589 MLP** + 127,603,199 CM |
| `0x8Dbebe40e6bE35cF1bE07b22Aa5fa11f4768917E` | StakedMlpDistributor (UUPS, impl `0xd833a316…1257`) | yes | 227,867,121 CM |
| `0x7eC427359d3470128f2A6C3d4c141AF158ed3A04` | StakedFmTracker "sFM" | yes | 281,690,077 FM + 172,730,603 CM |
| `0xB7Fe13C40D9E4cD4b549fD1766e4ef74ef06330d` | StakedFmDistributor | yes | 105,169,441 CM |
| `0xbF438c48Eff2b47F4e77Ea72dbC6588aB4f849CC` / `0x6F27c8aCeD67424D3E7c7F42997489586b21F2f6` | FeeFmTracker / FeeFmDistributor | yes | 0 |
| `0x37888159581ac2CdeA5Fb9C3ed50265a19EDe8Dd` | FM "Full Moon" token | yes | 2,400.000000 USDC |
| `0x5449239f7F6992D7d13fc4E02829aC90B2bEa6D1` | CM "Crescent Moon" (UUPS impl `0xeb495190…66aa`) | yes | totalSupply 749,167,654.57 CM |
| `0xfaa85B6A55AF5623F5cE63Db2c7048B088b44B15` | RewardRouter (UUPS, impl `0x74f7d74d…13a7`) | yes | 0 USDC/MLP |
| `0xe570522cb76bb1a85EF7c5b802800d340FBFD599` | FmVester | yes | 97,491,406 FM + 6,151,042 CM |
| `0xEb9884D5Ad7C0D5c0a39A8ed5f75BaE7635024A9` | MlpVester | yes | 180,460,501 FM + 85,706 CM |
| `0xe978246A8E92bd202Af2Fef7DCb41feB2D405248` | revenueAddress | EOA | 370,961.239499 USDC |
| `0x02ae2e56bfDF1ee4667405eE7e959CD3fE717A05` | zkEVM Moonlander diamond (23 facets) | yes | 5,610.612 VNO (Veno USD) ≈ $5.4k |

Diamond USDC vs vault accounting: vault `treasury[USDC]` = 15,887,831.623770; diamond actual balance is
47,821.542616 USDC higher (accrued protocol revenue + broker commission legs; `revenues([USDC])` reports
total 371,072.698120 USDC of which 111.458621 pending).

### 2.2 Roles (diamond, block 99,057,951)

| Role | Members |
|---|---|
| `DEFAULT_ADMIN_ROLE`, `ADMIN_ROLE`, `DEPLOYER_ROLE`, `TOKEN_OPERATOR_ROLE` | `0x7F404D40c9F5Bf8aE559900e8f4Dd99CD130E7e1` (msig-shaped; also owner of all trackers/distributors/vesters/MLP token) |
| `PRICE_FEED_OPERATOR_ROLE`, `PAIR_OPERATOR_ROLE` | msig + `0x06CE42F87f6318dee0F07bf72C8296122d1b0274` |
| `KEEPER_ROLE` | msig + `0xA54FE51dF94fb4D82d2ea8d42404b72F2ff3a054` + `0xaD78b23B9Af1FBA662Ef107b77fb96e1722fA13D` |
| `PRICE_FEEDER_ROLE` | msig + `0x82BE040D9f3C3d8eA709d1E967f92e72875DcbB2` + `0x1dd99d65D84b7682601C8190772599d4Fb83c7c7` + `0x555ebBe1067368252B60aAa43F89f8Ce449c159e` |
| `MONITOR_ROLE` | msig + `0x93418b60A7eed97a56252a3f7AFD1b890fe8aDF6` + `0x32e06051a11cbA561aA280e329B251083079B882` + `0xf6b03dE29217503e6f79145EA1e2a02E6751320E` |
| `STAKE_OPERATOR_ROLE`, `PREDICTION_KEEPER_ROLE`, `PYTH_PRICE_FEEDER_ROLE`, `WITHDRAW_MINT_ALP_ROLE` | empty |

`MLP` token: `MINTER_ROLE` = diamond only; `UPGRADER_ROLE` + `DEFAULT_ADMIN_ROLE` = msig; `burnFrom` requires
`isHandler` (diamond = true). Trackers/distributors/vesters: `Ownable`, owner = msig.

### 2.3 Protocol accounting / config (block 99,057,951)

- `mlpPrice()` = 0.962650337166964825 (18d) ≈ (getTotalValueUsd + lpUnrealizedPnlUsd) / MLP supply
- `getTotalValueUsd()` = $15,886,405.849760082880; `lpUnrealizedPnlUsd()` = +$10,760.732722; `maxWithdrawAbleUsd()` = $15,897,166.582483
- `lpNotionalUsd()` = $156,433.99 — the trading book is tiny relative to the pool
- vault item USDC: weight 10000, `feeBasisPoints` 25 (0.25%), `taxBasisPoints` 5 (0.05%), dynamicFee
- `paused()` = false; `coolingDuration()` = 86,400 s; `getSigner()` = `0x06feafDB2F337067EBB3458408AF3611c4Ec213e`
- `getTradingConfig()`: executionFeeUsd 0.1, minNotionalUsd 200, maxTakeProfitP 5.5x; switches all true
- **all 20 api-listed pairs are `REDUCE_ONLY`** (api.moonlander.trade; Pyth price source); `totalPairs()` = 116
- `getPriceFromCacheOrOracle`-style read (0x4b456f46) reverts **"LibPriceFacade: The price is too old"** for all tested tokens → the volatile-price cache is stale

---

## 3. Mechanism (bytecode-verified mapping)

The diamond is a standard EIP-2535 proxy (fallback → `ds.selectorToFacetAndPosition`), no `owner()`.
Full facet dump: `facets_dump.json`, `evmole_selectors.json`, `selectors_resolved.json`,
`facet_strings.json` (revert strings extracted from live bytecode), `selector_sweep.txt` (live
behaviour of all 225 selectors).

Selected segment map (live facet → role, from revert strings + family sources + EIP-712 type strings in bytecode):

- `0xB4A38fb7…` diamondCut → role-gated (fork: `missing DEPLOYER_ROLE 0xfc425f22…`); no external `owner()`
- `0x7C9Ef1AD…` loupe (5) · `0xB475B74a…` AccessControlEnumerable (7)
- `0xa5d7699a…` **MlpManagerFacet** (20): `mintMlp`, `burnMlp`, `mintMlpETH`, `burnMlpETH`,
  `mintMlpWithSignature`, `burnMlpWithSignature`, `unstakeAndBurnMlp`, `mlpPrice`, `getSigner`, `getRewardRouter`,
  `setSigner`/`setRewardRouter`/`setCoolingDuration` (ADMIN), `initMlpManagerFacet` (DEPLOYER). Strings:
  `LibMlpManager: Already initialized`, `ReentrancyGuard`, SafeERC20 → matches the renamed ApolloX/Aster `AlpManagerFacet`.
- `0x066D6D40…` BrokerManager (10) · `0xDa423e72…` ChainlinkPrice (4) · `0x62edD1EE…` **PythPriceFacet**
  (`setPythOracle`, `addPythConfig(address,bytes32)`, `removePythConfig`, `getPythConfig`; all PRICE_FEED_OPERATOR)
- `0x16c7FAB0…` FeeManager (15, incl. `withdrawRevenue(address[])` — no role check, but pays only to `revenueAddress`)
- `0xD01f3c82…` LimitOrder (15, incl. `executeLimitOrder`/`executeLimitOrderV2` — KEEPER_ROLE)
- `0xCe2B9Aad…` HookManager/partner (9, incl. `addPartner`, `getPartnerByAddress`, `afterMarketRefund`)
- `0x31377308…` TradingCore (12, incl. `addMarginPoolBalance`) · `0x2164A948…` Pausable (3)
- `0xD2E42cF8…` PriceFacade (8): `getPrice`, `requestPrice` (onlySelf), `batchRequestPriceCallback` variants
  (PRICE_FEEDER_ROLE), `confirmTriggerPrice` (onlySelf)
- `0xa6c7CBcC…` SlippageManager (5) · `0xC143C117…` TimeLock (3: queue/execute/cancel — queue needs role)
- `0xb5Fa6320…` **TradingChecker** (13 views: `checkSl`, `checkOpenTrade…`)
- `0x6bB52c52…` **TradingClose** (3: `closeTradeCallback` onlySelf + two payable batch close executors)
- `0x51986A3b…` PairsManager (31) · `0x716030d0…` TradingConfig (15) · `0xDD39A9d1…` **TradingOpen** (3:
  `marketTradeCallback` onlySelf + 2 signed-order executors)
- `0x8b594613…` **TradingPortalFacet** (14): `closeTrade`, `batchCloseTrade`, `addMargin`, `settleLpFundingFee`,
  `cancelLimitOrder`-family, **`batchExecuteOpenMarketOrders(SignedOpenOrder[],PriceData)`** and
  **`batchExecuteCloseMarketOrders(SignedCloseOrder[],PriceData)`**, `setTradingDelegator`/`getTradingDelegator`.
  EIP-712 strings in the live bytecode: `EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)`,
  `OpenOrderParams(address user,address tokenIn,uint96 amountIn,uint128 price,uint128 qty,uint128 stopLoss,uint128 takeProfit,address pairBase,uint24 broker,bool isLong,uint32 timestamp,bytes32 tradeHash,uint96 extraFee)`,
  `CloseTradeParams(bytes32 tradeHash,address user)`; domain name `"Moonlander"`, version `"1"` (frontend `lf()` builder).
- `0x6e65C0ab…` TradingReader (9) · `0x7e733672…` **VaultFacet** (16): `increase`/`decrease`/`decreaseByCloseTrade`
  are `onlySelf`; `addToken`/`updateToken`/`changeWeight` are TOKEN_OPERATOR.

### 3.1 MLP mint/burn mechanics (live numbers)

`mintMlp(tokenIn, amountIn, minMlp, stake)` and `burnMlp(tokenOut, mlpAmount, minOut, receiver)` price shares at
`mlpPrice ≈ (vaultTotalValueUsd + lpUnrealizedPnlUsd)/supply` with a dynamic fee (`feeBasisPoints` 25 /
`taxBasisPoints` 5 for USDC). `burnMlp` enforces `lastMintedTimestamp[user] + coolingDuration (86,400 s)`
unless the user is on the free-burn whitelist. `unstakeAndBurnMlp(tokenOut, amount, minOut, receiver)` first
unstakes from the StakedMlpTracker (which requires the caller's tracked stake) and then burns.

### 3.2 Async execution (the interesting surface)

Trades never execute synchronously: `openMarketTrade`/`closeTrade` create pending items and `requestPrice` (onlySelf);
execution happens either through (a) `marketTradeCallback`/`closeTradeCallback` — **onlySelf**, invoked internally
by `requestPriceCallback` which requires PRICE_FEEDER_ROLE, or (b) the new EIP-712 `batchExecute*MarketOrders`,
which accept user-signed orders **plus a caller-supplied `PriceData{bytes[] pythPrice, CachePrice[] cachePrice}`**
where `CachePrice = (address token, uint128 price, uint32 timestamp)`. An empty-input call to (b) reverts with
"TradingPortalFacet: No orders" (no access error), which originally suggested the executor might be permissionless;
however the fork PoC proves that with a **real self-signed order the executor reverts with
`missing PRICE_FEEDER_ROLE 0x7d867aa9…`** on every variant (both signature types, with and without cache price).
So the caller-supplied price data is irrelevant for an external attacker — execution is reserved to the four
PRICE_FEEDER addresses. The stale price cache (`0x4b456f46`-style reads revert "LibPriceFacade: The price is too
old") and the REDUCE_ONLY pair regime close the remaining trading surface.

---

## 4. Attacker model — candidate paths, gates, results

External unprivileged attacker = fresh EOA, no roles, own capital / flash loans. Cost basis: Cronos gas is
negligible (< $0.01). Tested paths (see §5 for the fork evidence):

| # | Path | Gate (live value) | Result |
|---|---|---|---|
| 1 | `diamondCut` → replace VaultFacet → sweep USDC | role-gated (fork: `missing DEPLOYER_ROLE 0xfc425f22…`; `onlySelf` relatives) | **closed** |
| 2 | Facet `initialize`/`init*` takeover (`initMlpManagerFacet`, `initBrokerManagerFacet`, `initFeeManagerFacet`, `initTradingConfigFacet`) | fork: `missing DEPLOYER_ROLE` for all four | **closed** |
| 3 | `grantRole`/`revokeRole`/`renounceRole` | ADMIN_ROLE; DEFAULT_ADMIN holder = msig | **closed** |
| 4 | `setSigner` / `setRewardRouter` / `setCoolingDuration` / `setDaoRepurchase` / `setRevenueAddress` | fork: `missing ADMIN_ROLE 0xa4980720…` | **closed** |
| 5 | `setPythOracle` / `addPythConfig` / `removePythConfig` (fake Pyth feed) | fork: `missing PRICE_FEED_OPERATOR_ROLE 0xc24d2c87…` | **closed** |
| 6 | `batchRequestPriceCallback` (fabricated oracle price → execute pending trades) | fork: `missing PRICE_FEEDER_ROLE 0x7d867aa9…` (both live variants) | **closed** |
| 7 | `marketTradeCallback` / `closeTradeCallback` direct | fork: `only self call` | **closed** |
| 8 | `requestPrice` / `confirmTriggerPrice` / `updatePairPositionInfo(pairBase,…)` | fork: `only self call` | **closed** |
| 9 | Admin pair/token/config mutation (`addPair` 0xdf81676d and duplicate 0x14aa8323, `removePair`, `updateToken`, `updateTokenFeature`, `updatePair*` family incl. funding/OI/status/fee/slippage/holding-fee, `setExecutionFeeUsd`, `setMinBetUsd`, `setMinNotionalUsd`, `setMaxTakeProfitP`, `setExecutionFeeReceiver`, `setTradingSwitches`, `withdrawToken`-style) | fork (valid arity, nonzero values): `missing PAIR_OPERATOR 0x04fcf77d…` / `TOKEN_OPERATOR 0x62150a51…` / `MONITOR 0x8227712e…` / `ADMIN` | **closed** |
| 10 | `executeLimitOrder` / `executeLimitOrderV2` (keeper-priced execution) | fork: `missing KEEPER_ROLE 0xfc8737ab…` | **closed** |
| 11 | EIP-712 `batchExecuteOpenMarketOrders` with fabricated `cachePrice` (open long at $100 ETH), both signature types, with/without cache | fork: `missing PRICE_FEEDER_ROLE` on every attempt; `positionsCount` stayed 0. Empty-input call reverts earlier with "TradingPortalFacet: No orders" (hence the live sweep's classification) | **closed** |
| 12 | EIP-712 `batchExecuteCloseMarketOrders` on foreign/nonexistent trade | fork: `missing PRICE_FEEDER_ROLE` | **closed** |
| 13 | `openMarketTrade` / `openLimitOrder` (open a position) | API-listed pair address is not the legacy on-chain registry key; pair lookup / price-feed checks revert ("The pair doesn't exist" / "LibChainlinkPrice: Price feed does not exist"); all 20 API pairs are REDUCE_ONLY | **closed** |
| 14 | `withdrawRevenue([USDC])` | **no role check** — fork: moved 113.369800 USDC to `revenueAddress`; attacker delta **0** | **no attacker gain** |
| 15 | `withdrawCommission(1)` | **no role check** — but fork-verified to push only to the broker's registered receiver (broker 1 = "Moonlander", receiver = msig `0x7F404D40…`); attacker delta **0** | **no attacker gain** |
| 16 | `setTradingDelegator(delegate)` | callable; self-scoped. `getTradingDelegator(user) → address` returns that user's delegate; fork: attacker→`0xBEEF` registered, `0xBEEF` itself has no delegate, no cross-account leakage; a delegate cannot `unstakeAndBurnMlp`/`burnMlp` the delegator's assets (fork: "RewardTracker: _amount exceeds stakedAmount", "ERC20: burn amount exceeds balance") | **closed** |
| 17 | `mintMlp`→`burnMlp` round trip (share-price bug / fee inversion / rounding) | fork executes: 10,000 USDC → 10,361.146885922409994549 MLP; full burn after cooldown → 9,950.078136 USDC (**−0.499%**, exactly the 0.25%/0.05% fee structure); burn inside cooling → custom error 0x4605d5e8 | **closed (no profit)** |
| 18 | `unstakeAndBurnMlp` without stake (burn tracker's 16.5M MLP) | fork: "RewardTracker: _amount exceeds stakedAmount"; honest path: 5,000 USDC staked → 5,180.573442961204997274 sMLP; half unstake+burn → 2,487.517580 USDC (≈ 0.96025/share vs 0.96261 price) | **closed (no profit)** |
| 19 | `mintMlpWithSignature` / `burnMlpWithSignature` with forged signature | fork: custom error `0x8baa579f` = `InvalidSignature()`; signer fixed at `0x06feafDB…`. Replay of a hypothetically obtainable valid signature is discussed in §6 | **closed (no forged path)** |
| 20 | Direct MLP token mint | fork: `missing MINTER_ROLE 0x9f2df0fe…` (role held only by the diamond) | **closed** |
| 21 | Direct MLP burnFrom / UUPS upgrade | fork: `MLP: only handler` / `missing UPGRADER_ROLE 0x189ab7a9…` (msig) | **closed** |
| 22 | Tracker/Distributor/RewardRouter admin (`stakeForAccount`, `claimForAccount`, `initialize`, `upgradeTo`, `setDistributor`) | fork: `RewardTracker: forbidden`, `Initializable: contract is already initialized`, `Ownable: caller is not the owner` | **closed** |
| 23 | Timelock `queueTransaction` → `executeTransaction` (arbitrary diamond call) | queue requires role ("TimeLockFacet: missing role."); execute needs a queued tx | **closed** |
| 24 | Quoted trade against stale oracle cache | cache stale ⇒ "LibPriceFacade: The price is too old"; execution callbacks role-gated anyway | **closed** |
| 25 | zkEVM side (same codebase, 23 facets, roles) | funds only $5.4k VNO; same gates; not fully swept (screened) | **no material value** |

**Costs:** everything above is reachable by a fresh EOA paying only gas (Cronos gas is negligible). The only two "open" mutating functions are pushes to protocol-controlled recipients (`withdrawRevenue`, `withdrawCommission`) plus the self-scoped `setTradingDelegator`; none credit the caller.

---

## 5. PoC (fork tests)

`poc-moonlander/` (Foundry, solc 0.8.24). Fork source: `$CRONOS_RPC_URL` (CI secret) with keyless fallback
`https://evm.cronos.org`; `FORK_BLOCK` env optional (default: latest). Tests never touch mainnet.

- `test/MoonlanderLive.t.sol` — live-state assertions; admin/init gates (tests 1/1b); MLP round-trip economics (2);
  `unstakeAndBurnMlp` no-stake attack + honest path (3); callbacks onlySelf (4); `withdrawRevenue` recipient check (5);
  `setTradingDelegator` semantics (6); tracker/router/token gates (7); zero-balance burn/forged-signature/nonexistent-trade
  attempts (8).
- `test/MoonlanderExec.t.sol` — EIP-712 self-signed close order with fabricated `cachePrice` (10); self-signed open order
  with fabricated `cachePrice`, both signature-type values, with and without cache (11); `REDUCE_ONLY` open/limit-order
  attempts (12); delegate cross-account abuse (13).
- `test/MoonlanderSweep.t.sol` — all **225** diamond selectors called from a fresh EOA with zero-value arguments,
  each isolated in an external self-call with `try/catch` so that panics inside the diamond cannot escape. The test
  logs successes/reverts and any mutating selector that succeeds (informational screen; view drift between the audit
  block and the CI block is expected). The hard closure assertions live in the targeted tests above.

**CI**: GitHub Actions `poc.yml`, repo `kingmariano/ca-zombie-ci` (lock-serialized).
- Run 1 — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38055624360 — sweep generator emitted `,` separators (`poc-moonlander exit=1`, compile).
- Run 2 — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38056012661 — lowercase address literals rejected by solc (`invalid checksummed address`), fixed.
- Run 3 — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38056210630 — **12/14 tests pass**; two test-side
  issues found: `withdrawCommission(1)` is an open push (not a revert), and the sweep's size math overflowed
  (test bug, `uint8` multiplication), which masked the rest of the sweep.
- Run 4 — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38056702036 — sweep isolated through an external
  helper; revealed a `vm.prank` placement bug (calls came from the test contract) and a second sweep overflow,
  plus the delegator getter's return shape. Fixed.
- Run 5 — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38057029486 — 13/15; the delegator getter returns an
  `address` (not `bool`) and the sweep still asserted on harness artefacts. Fixed (sweep downgraded to an
  informational screen; delegator decoded as an address with self-scoping assertions).
- **Run 6 (authoritative) — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38057370504 — `poc-moonlander exit=0`:
  15/15 tests pass** (Exec 4/4, Live 10/10, Sweep informational: 225 selectors → 26 callable, 199 revert, 0 unexpected
  mutating successes). Log: `ci-out/poc-moonlander.log` (artifact `result-high-cluster`), local copy in
  `high-cluster/ci-log.txt`.

Key fork measurements (runs 3–6; figures vary slightly with the fork block because pool PnL moves):

| Measurement | Value |
|---|---|
| MLP mint 10,000 USDC → MLP | 10,361.09–10,361.15 MLP (mint price ≈0.9651) |
| Burn of all minted MLP → USDC | 9,950.078136 USDC (burn price ≈0.9603; `mlpPrice` ≈0.9626) |
| Round-trip P/L | **−49.921864 USDC (−0.499%) = exactly the fee structure; no profit** |
| Burn inside 24h cooling | custom error `0x4605d5e8` (CoolingOff) |
| `unstakeAndBurnMlp` with no stake | `RewardTracker: _amount exceeds stakedAmount` |
| `unstakeAndBurnMlp` honest (½ of 5,180.573442961204997274 sMLP) | 2,487.517580 USDC (≈0.9603/sMLP; no profit) |
| `withdrawRevenue([USDC])` from fresh EOA | attacker +0, revenueAddress +113.37…113.94 USDC (block-dependent pending) |
| `withdrawCommission(1)` from fresh EOA | executes; pays broker 1's receiver (= msig 0x7F404D40…); attacker +0 |
| EIP-712 batch execute (self-signed, fabricated cachePrice, both signature types) | `missing PRICE_FEEDER_ROLE 0x7d867aa9…` on all 4 attempts; positions stayed 0 |
| Forged `mintMlpWithSignature`/`burnMlpWithSignature` | custom error `0x8baa579f` (`InvalidSignature`) |
| `closeTrade`/`addMargin` on nonexistent trade | custom error `0x7f426257` (`NonexistentTrade`) |
| Tracker `stakeForAccount`/`claimForAccount` from EOA | `RewardTracker: forbidden` |
| Tracker/MLP `upgradeTo` from EOA | `Ownable: caller is not the owner` / missing `UPGRADER_ROLE 0x189ab7a9…` |
| Direct `MLP.mint` | missing `MINTER_ROLE 0x9f2df0fe…` |
| `MLP.burnFrom` | `MLP: only handler` |
| `getTradingDelegator(user)` | returns the user's delegate address; fork: attacker→0xBEEF only, 0xBEEF itself none, third-party sees none |
| All 225 selectors from a fresh EOA (informational screen) | 0 unexpected mutating successes; only the audited pushes/no-ops (`withdrawRevenue`, `withdrawCommission`, `batchCancelLimitOrders([])`, `batchCloseTrade([])`) and self-scoped `setTradingDelegator` succeed |

**Run 6 result (authoritative)** — `poc-moonlander exit=0`, **15/15 tests pass**:
- `MoonlanderExec`: test_10 (self-signed close, PRICE_FEEDER gate), test_11 (self-signed open ×2 signature types ×with/without fabricated cachePrice, PRICE_FEEDER gate, 0 positions), test_12 (open/limit-order/deal reverts), test_13 (delegate cannot touch victim funds) — all PASS.
- `MoonlanderLive`: test_00 live state; test_01 + test_01b admin/init gates incl. valid-arity admin setters; test_02 MLP round-trip (loss 0.499%); test_03 `unstakeAndBurnMlp` no-stake + honest; test_04 callbacks onlySelf; test_05 `withdrawRevenue` recipient; test_06 delegator self-scoping; test_07 tracker/token gates; test_08 zero-balance burn / forged signature / nonexistent trade — all PASS.
- `MoonlanderSweep` (informational): 225/225 selectors screened from a fresh EOA — 26 callable (views + audited pushes), 199 revert, **0 unexpected mutating successes**.

**Net effect for the attacker model: nothing in the deployed system hands an unprivileged EOA value.**

---

## 6. Verdict

**E-U (external unprivileged, live today): $0** — no extraction path found.
Every value-moving entry point is role-gated (`ADMIN`/`PAIR_OPERATOR`/`TOKEN_OPERATOR`/`MONITOR`/`KEEPER`/
`PRICE_FEEDER`/`PRICE_FEED_OPERATOR`/`DEPLOYER`), `onlySelf`, or protected by position ownership + a
REDUCE_ONLY pair regime and a stale-price cache that blocks the async executors. The only unprotected mutating
functions are two protocol-side "pushes" (`withdrawRevenue`, `withdrawCommission`) that pay only
protocol/broker-controlled recipients, plus the self-scoped `setTradingDelegator`. **Confidence: high** for the USDC pool:
all 225 selectors were enumerated and behaviourally classified (198 resolved to a name via signature databases,
public family ABIs, the Moonlander frontend bundles, or manual EIP-712/selector reconstruction; the remaining
27 are unnamed but classified — all views, `onlySelf`s, role-gated or unconditional reverts, see
`selector_sweep.txt`), all 25 candidate paths tested, and the whole-surface sweep reproduces live behaviour on
a fork. Medium/low residuals are listed below.

**Value split (Cronos, block 99,057,951; USDC at $0.999735 = DefiLlama 2026-10-10):**

| Category | What | Amount | USD |
|---|---|---|---|
| **E-U** | nothing found | **0 USDC** | **$0** |
| **H-O** | MLP holders' redemption claim on the vault (16,513,957.320 MLP; incl. the 16,512,353.95 MLP held by StakedMlpTracker, redeemable via `unstakeAndBurnMlp`/`burnMlp` after cooldown + fees) | 15,887,831.623770 USDC in treasury (≈$15.884M at the live USDC price) + $10,760.73 unrealized PnL; ≈ $15.85M net of the 0.25% exit fee if everyone redeems | ≈ **$15.89M gross** |
| **H-O** | FM/CM rewards parked in trackers/distributors/vesters (281.69M FM + 172.73M CM in sFM tracker; 127.6M CM in sMLP tracker; 333M CM in distributors; 97.5M FM + 6.2M CM in FmVester; 180.5M FM + 0.09M CM in MlpVester) | FM ≈ $0.002119 → FM legs ≈ $1.19M; CM unpriced (CoinGecko/DefiLlama blank) | ≈ $1.19M FM + CM unpriced |
| **P** | the same vault + token supply controllable by msig `0x7F404D40…` (ADMIN/DEPLOYER/UPGRADER/owner of everything; can upgrade the diamond facets via TimeLock, upgrade MLP token, mint MLP as MINTER, pause) | 15,935,653.166386 USDC balance | ≈ **$15.93M** |
| **P** | accrued protocol revenue already pushed to revenueAddress | 370,961.239499 USDC | ≈ $370.9k |
| **S** | 2,400.000000 USDC sitting inside the FM token contract — the FM ERC20 has no withdraw/sweep function (bytecode-enumerated), so these funds are unrecoverable | 2,400 USDC | ≈ $2.4k |
| **S** | zkEVM diamond VNO backing zkEVM MLP (2,842.57 MLP) — not stuck, but tiny; same gates (screened) | 5,610.612 VNO | ≈ $5.4k |

Note: H-O and P overlap by construction (the vault backs MLP; the same msig could redirect it). The MLP holders'
claim is *satisfiable today* (mint/burn math verified on fork with live state; no pause; cooling 24h).

**What would change the verdict (residuals):**
1. **Signed-pnl timing on `mintMlpWithSignature`/`burnMlpWithSignature`** (off-chain signer `0x06feafDB…`): the
   signed message is `(chainId, deadline, token, lpUnPnlUsd, lpTokenUnPnlUsd)` — it excludes amounts and users, so
   any valid unexpired signature is usable by anyone. Without the signer key no signature can be forged
   (fork: `InvalidSignature` for empty/forged sigs). If Moonlander's backend ever signs a *favourable pnl* value with
   a long deadline, the extraction is bounded by the signed-vs-actual pnl delta; the trading book notional is only
   $156k, so this is ≤ ~$10k-scale even in the best case. Not testable without a signature; flagged **low**.
2. **Live-revision drift on unnamed selectors** — 27 of 225 selectors have no recovered name (mostly
   `TradingChecker` view maths, partner-hook callbacks, and a few role-gated admin setters). All 27 were
   behaviourally classified: views return data or revert on zero inputs; `0x5a43d9b8`/`0xca3792aa` are
   `onlySelf`; `0xf435f476` PRICE_FEED_OPERATOR; `0xdc9fb03b` ADMIN; `0x47055e1c`/`0xc5c90efc` PRICE_FEEDER;
   `0x83b830b5` reverts unconditionally for every input incl. from the msig; `0x0fdab0f4`/`0xaae5bf72` are the
   TradingClose batch executors (role-gated like their neighbours). None succeeded from a fresh EOA in the
   225-selector sweep.
3. **Unverified off-chain components**: keeper bots, the signing service (fixed signer EOA), the API, Pyth update
   relaying. If the signer/keeper keys leak, the attacker inherits that role's powers (PRICE_FEEDER can execute
   trades; KEEPER can execute limit orders; neither can move the vault directly — no `WITHDRAW` role member exists).
4. **zkEVM not exhaustively swept** (facet list, balances, roles read only; no per-selector sweep).

One observed mechanical note: calling `unstakeAndBurnMlp` with `amount = 0` from an account with no stake panics
inside the tracker (`arithmetic underflow 0x11`) on the current block, whereas the same call reverted cleanly
(`RewardTracker: invalid _amount`) at the earlier read block — the tracker's reward-state math is sensitive to
inter-block state. Both outcomes revert the transaction; neither moves funds. Worth flagging to the protocol but
not an extraction path.

**Coverage statement: fully audited** (for the USDC pool and the diamond's value-moving surface: every selector
enumerated from the loupe and classified — 198 of 225 resolved to a name via signature databases, public family
ABIs, the Moonlander frontend bundles or manual EIP-712/selector reconstruction, the remaining 27 classified
behaviourally; all candidate paths fork-tested) — with the exceptions listed in the residuals above. **Screened**:
FM/CM tokens, vesters, distributors, zkEVM deployment, historical activity.

---

## 7. Files, methodology, caveats

Evidence (this directory):
- `facets_dump.json` / `facets_raw.txt` — 23 facets + 225 selectors (loupe at block 99,057,951)
- `evmole_selectors.json` — argument shapes + mutability per selector (from live bytecode)
- `selectors_resolved.json` — openchain/sourcify-4byte name resolution (155/225)
- `facet_strings.json` — revert strings per facet bytecode (used to identify roles/versions)
- `selector_sweep.txt` — live eth_call result of every selector from a fresh EOA
- `roles_live.txt` — AccessControl membership for 13 role hashes
- `live_state.json` — consolidated balances/config at the pinned blocks
- `mlp_bytecode.txt`, `tracker_impl_bytecode.txt`, `distributor_impl_bytecode.txt` — raw bytecode
- `frontend_abi_functions.json`, `moonlander_index.html` — function names/ABIs recovered from the moonlander.trade bundles
- `pairs_api_cronos.json` — live pair list + REDUCE_ONLY status from api.moonlander.trade
- `ci.txt` — CI run URLs
- upstream reference clones were used read-only in `/tmp` (apollox-perp-contracts, asterdex-perpetual-contracts,
  xdoge futures-contract, gmx-contracts RewardTracker/RewardDistributor)

Method: keyless live reads → selector/loupe enumeration → selector mapping to the ApolloX/Aster family
(sources + artifact ABIs + frontend ABIs from `moonlander.trade` bundles, incl. the EIP-712 signer code) →
per-selector live eth_call classification → fork tests for every candidate path → CI.

Caveats: (1) the live revision is a modified fork, not byte-identical to any public repo, so every gate claim
rests on live behaviour, with names inferred; (2) `eth_call`-only probing means state changes were reproduced on
forks, not mainnet; (3) amounts move with trading PnL; all figures are pinned to the stated blocks; (4) no
secrets were used or stored; all RPCs in saved files are keyless.

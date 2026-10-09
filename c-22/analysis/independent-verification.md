# Independent Verification — C2-22 claim: Fulcrom (Cronos) GMX-V1 order-execution reentrancy

- **Chain:** Cronos (chain 25), public RPC `https://evm.cronos.org` only. **No keyed endpoints, no secrets, no transactions sent** — read-only `eth_call` / `eth_getCode` / `eth_getStorageAt` / `eth_getLogs` + local verified-source review + web post-mortem review.
- **State blocks:** all reads pinned at the blocks shown (range 98,802,625 – 98,806,817). Activity scan: blocks 98,797,634 – 98,806,634 (≈1.5 h of chain time).
- **Test caller:** `0x000000000000000000000000000000000000dEaD` (unprivileged EOA, no roles — checked against every role mapping below).
- **Claim under test:** *"On Cronos, the Fulcrom GMX-V1 order-execution reentrancy (July-2025 GMX recipe) is NOT exploitable by an external unprivileged attacker today; extractable-by-attacker = $0. Primary reasons: (1) `Vault.isLeverageEnabled()==false` so all position increases revert; (2) the leverage switch is not permissionless (Timelock.enableLeverage admin/handler-gated); (3) the ShortsTracker average-price manipulation is disabled (isGlobalShortDataReady=false, weight=0, no updateGlobalShortData callers); (4) OrderBook blocks contract accounts for decrease orders."*

---

## Check 1 — Live state re-read (all raw values)

**Vault** `0x8C7Ef34aa54210c76D6d5E475f43e0c11f876098` (impl slot → `0xA66a0FEA27FB0a6f115be2B6FEcA472635594672`, block 98,802,687 / 98,805,116):

| Call | Result |
|---|---|
| `isLeverageEnabled()` | **false** |
| `isSwapEnabled()` | true |
| `maxGasPrice()` | 0 (no gas-price gate) |
| `gov()` | `0x880a34751D8452df466ae27Ac341F987f0dAf3AE` (Timelock) |
| `router()` | `0xcC46b79eBEaA1D834B707624977Ec261592E0C9a` |
| `usdg()` / `priceFeed()` | `0xB09BD2bAf03e19550473a5DC1D5023805E04a4f5` / `0xa8bEA47BCFc17Bb95f9510516B648833E3Cd0446` |
| `inManagerMode()` / `inPrivateLiquidationMode()` | **true** / **true** |
| `errors(28)` | **`"Vault: leverage not enabled"`** |
| `marginFeeBasisPoints()` | 500 (5 % at rest) |
| `maxLeverage()` | 2,500,000 (250×) |
| fee params | tax=50, stableTax=5, mintBurn=25, swap=30, stableSwap=1, hasDynamicFees=1, minProfitTime=900, fixedLiqFeeUsd=5e30 |
| `fundingRateFactor` / `fundingInterval` | 100 / 3600 s |

**ShortsTracker** `0xd996bE6DBdEaa8429Ff9E2D86725197Eb663148a` @ 98,802,764:

| Call | Result |
|---|---|
| `isGlobalShortDataReady()` | **false** |
| `gov()` | `0x04Fc879C9068Dc265424949128851Ca19D96eC02` |
| `isHandler(OrderBook)` / `(PositionRouter)` / `(PositionManager)` | false / **true** / **true** |
| `globalShortAveragePrices(WBTC)` | 0 |

**FlpManager** `0x6148107BcAC794d3fC94239B88fA77634983891F` (impl slot → `0x743194b11b0d705b425bfc36d4aae1e0bffa3021`) @ 98,802,764 / 98,805,116:

| Call | Result |
|---|---|
| `shortsTracker()` | `0xd996…148a` |
| `shortsTrackerAveragePriceWeight()` | **0** |
| `cooldownDuration()` | 0 |
| `inPrivateMode()` | **true** |
| `aumAddition` / `aumDeduction` | 0 / 0 |
| `getAum(true)` | 13236229384679514096743765686602974256 (≈$13.236 M) |
| `getPrice(true/false)` | 1.126e30 (≈$1.126 / FLP) |
| `isHandler(RewardRouter 0x133B7f9570b3be8e51CCd5DA4654C3DDe7657Ae1)` | **true** |
| `getGlobalShortAveragePrice(WBTC)` | 81741844055145264879070574438214595 = **Vault's mapping** (ShortsTracker's is 0) |

**Timelock** `0x880a34751D8452df466ae27Ac341F987f0dAf3AE` @ 98,803,083 / 98,805,238:

| Call | Result |
|---|---|
| `admin()` | `0x04Fc879C9068Dc265424949128851Ca19D96eC02` |
| `shouldToggleIsLeverageEnabled()` | **TRUE** |
| `buffer()` | 86400 |
| `isHandler(PositionRouter)` / `(PositionManager)` | **true** / **true** |
| `marginFeeBasisPoints()` / `maxMarginFeeBasisPoints()` | **5** / 500 |

**PositionRouter** `0x27fb69422c457452D8b6FDcb18899D9B53C3f940` (impl → `0x8b4d2dd548114d77a98400176325e853c5174e5e`) @ 98,803,296:

| Call | Result |
|---|---|
| **`isLeverageEnabled()`** | **TRUE** ← its own public-execution switch, not the Vault's |
| `minTimeDelayPublic` / `minBlockDelayKeeper` / `maxTimeDelay` | 180 / 0 / 1800 |
| `minExecutionFee` / `depositFee` / `ethTransferGasLimit` / `increasePositionBufferBps` | 0.6 CRO / 30 / 20,000 / 100 |
| `maxGlobalShortSizes(WBTC)` | 9.3086881829377933403584e36 = **$9.31 M** |
| `maxGlobalShortSizes(WETH/WCRO/PAXG)` | $1.85 M / $12.3 K / $18.8 K |
| `isPositionKeeper(FastPriceFeed 0x54a16…)` | **true** |

**Other role checks:** `Vault.isManager(FlpManager)=true`; `isManager(Timelock/PositionManager/Router/PositionRouter)=false`; `Vault.isLiquidator(dEaD)=false`; `PR.isPositionKeeper(dEaD)=false`; `PM.isOrderKeeper(dEaD)=false`; `Vault.approvedRouters(dEaD, Router)=false`, `(dEaD,dEaD)=false`; `PM.isOrderKeeper(FastPriceFeed)=true`.

---

## Check 2 — Every external path to `increase/decreasePosition` + live probes

Paths found in the verified sources (all funnel through `Vault._increasePositionInternal`, whose **first statement is `_validate(isLeverageEnabled, 28)`, or `Vault._decreasePosition`, which has **no leverage gate**):

| Entry point | Reachability | Hits gate 28? |
|---|---|---|
| `Vault.increasePosition` / `increasePositionV2` | `_validateRouter`: `msg.sender==account` allowed, or `router`, or self-approved router | yes (first check) |
| `Router.pluginIncreasePosition(V2)` | Router plugins only (`plugins[msg.sender]`), called by PR | yes |
| `Router.increasePosition*` | public, self-account | yes |
| `OrderBook.executeIncreaseOrder` | **public / no ACL** (order.account must be non-contract) | yes (reverts unless inside a PM window) |
| `PositionRouter.executeIncreasePosition` | **public, own request after 180 s** (`isLeverageEnabled=true` bypasses the non-keeper restriction); internals: `enableLeverage → pluginIncreasePositionV2 → disableLeverage` | gate **passes inside the window** |
| `PositionRouter.executeIncreasePositions` (batch) | `_onlyPositionKeeper` (FastPriceFeed is keeper) | passes inside window |
| `PositionManager.executeIncreaseOrder` | `onlyOrderKeeper` (FastPriceFeed is keeper) | passes inside window |
| `Vault.decreasePosition` | **permissionless as account** (no leverage gate, passes `_validateRouter` when `msg.sender==account`) | no gate |
| `OrderBook.executeDecreaseOrder` | **public / no ACL**; order.account non-contract; full-gas ETH refund to caller-chosen `_feeReceiver` | no gate |
| `Vault.liquidatePosition` / `PositionManager.liquidatePosition` | private-liquidation mode → `isLiquidator` / `onlyLiquidator` | n/a |

Live probes from `0x…dEaD` (raw revert data, `0x08c379a0`+string decoded):

| Probe | Result |
|---|---|
| `Vault.increasePosition(dEaD, WCRO, WCRO, 1e18, true)` | revert **`Vault: leverage not enabled`** (error 28) |
| `Vault.increasePositionV2((dEaD,…))` | revert **`Vault: leverage not enabled`** |
| `Router.pluginIncreasePosition(…)` | revert `Router: invalid plugin` |
| `PositionManager.executeIncreaseOrder(dEaD,0,dEaD)` | revert **`PositionManager: forbidden`** |
| `PositionRouter.executeIncreasePosition(0x…01, dEaD)` | **returns `true`** (no gate — no-op on missing request; entry is permissionless) |
| `Vault.decreasePosition(dEaD,…)` | revert `Vault: empty position` (router check passed as self) |
| `OrderBook.executeDecreaseOrder(dEaD,0,dEaD)` | revert `OrderBook: non-existent order` (no ACL gate) |

**Answer to the key question:** no *direct* increase path avoids the gate, but **position increases do execute today** via transient enabling inside PositionRouter/PositionManager (proof: see activity scan below). Reason (1) is therefore false as a blanket statement.

### Live proof that increases execute now (falsifies reason 1 literally)
`eth_getLogs` on the Vault for the verified `IncreasePosition(bytes32,address,address,address,uint256,uint256,bool,uint256,uint256)` topic `0x2fe685…5022` over blocks **98,797,634–98,806,634** (≈1.5 h):

- **42 × `IncreasePosition`** events across 6 pages (e.g. blocks 98,797,752, 98,804,831, 98,805,168, 98,806,459…)
- **28 × `DecreasePosition`** events (topic `0x93d75d…6d30`) in the same range
- Mechanism confirmed: tx `0x62e57db7…`, from EOA `0x15d1…865b` **to FastPriceFeed `0x54a1…4e6e`**, emits FastPriceFeed price logs **and Vault `IncreasePosition`/`CollectMarginFees`/`IncreaseReservedAmount` logs**. `FastPriceFeed` (impl source `fast_price_feed/impl/contracts/oracle/FastPriceFeed.sol:606-643`) updates prices then calls `PositionRouter.executeIncreasePositions` / `PositionManager.executeIncreaseOrder`; `PR.isPositionKeeper(FastPriceFeed)=true` and `PM.isOrderKeeper(FastPriceFeed)=true`. This is the live leveraged-trading path.

---

## Check 3 — Leverage-switch gating, attacked from the unprivileged side

- Source: `Vault.setIsLeverageEnabled` → `_onlyGov()` (error 53); `Vault.gov == Timelock`. `Timelock.enableLeverage/setIsLeverageEnabled` → `onlyHandlerAndAbove`; and `enableLeverage` only calls `setIsLeverageEnabled(true)` **if `shouldToggleIsLeverageEnabled`**.
- Probes from dEaD: `Timelock.enableLeverage(Vault)` → revert **`Timelock: forbidden`**; `Timelock.setIsLeverageEnabled(Vault,true)` → **`Timelock: forbidden`**; `Vault.setIsLeverageEnabled(true)` → **`Vault: forbidden`**.
- **But the gate is bypassed structurally:** `Timelock.shouldToggleIsLeverageEnabled=TRUE`, `isHandler(PositionRouter proxy)=true`, `isHandler(PositionManager proxy)=true`. Any execution through PR/PM calls `enableLeverage → Vault.setIsLeverageEnabled(true) → … → disableLeverage`, and `PositionRouter.isLeverageEnabled=TRUE` lets a **non-keeper execute their own request after 180 s** (`_validateCallerAndTiming` allows `msg.sender==account` when `isLeverageEnabled`). So the leverage switch is *not* admin-only in effect: any user can transiently turn leverage on by trading through the router. `approvedRouters` is self-service only (`setRouter` writes `approvedRouters[msg.sender][…]`), so no third-party approvals exist (dEaD pairs false).
- Verdict: reason (2) is false as a load-bearing safety claim. The effective safety switch is `shouldToggleIsLeverageEnabled` — currently **on**.

---

## Check 4 — ShortsTracker path and the AUM fallback (the critical finding)

1. **No deployed contract calls `updateGlobalShortData`.** `updateGlobalShortData(address,address,address,bool,uint256,uint256,bool)` selector = `0xf3238cec`. Bytecode scan of all impls: **ABSENT** in PositionRouter `0x8b4d…`, PositionManager `0xbb8a…`, OrderBook `0x1b0e…`, Vault `0xA66a…`, FlpManager `0x7431…`.
2. Probe: `ShortsTracker.updateGlobalShortData(…)` from dEaD → **`ShortsTracker: forbidden`**; from the PositionRouter proxy (registered handler) → **returns `0x`, no state change** (early return because `isGlobalShortDataReady==false`).
3. **AUM does not use the ShortsTracker at all.** `FlpManager.getGlobalShortAveragePrice()` (source lines 187-205; deployed selector present) first checks `!shortsTracker.isGlobalShortDataReady()` → returns **`vault.globalShortAveragePrices`**. Live-confirmed: FM returns `8.17418e34` (= Vault's value) while ShortsTracker's is `0`.
4. **The Vault's own pair is non-atomic.** `Vault.globalShortAveragePrices` is written **only on short increases** (`Vault.sol:680-682`, deployed via `VaultUtils.getNextGlobalShortAveragePrice`, selector `0x9d7432ca` present, live-verified formula). `Vault._decreasePosition` **does not update the average** — only `globalShortSizes` (source lines 693-764). This is exactly the non-atomic (size, average) state that GMX's 2022 fix moved into `updateGlobalShortData`, and which the July-2025 reentrancy re-armed. Here the fixed component is present but **disconnected**, and the vulnerability is reachable **without any reentrancy**.
5. Live formula verification: `VaultUtils.getNextGlobalShortAveragePrice(WBTC, 8.24410e34, 1e33)` → `8.1760610036780129239682844941121019e34`; hand-computed from the source formula with live (S₀, A₀) matches. `VaultUtils.validateIncreasePosition(...)` is a no-op (returns `0x` live). `Vault.maxLeverage` = 250×.

**Conclusion:** reason (3) is false in substance. The ShortsTracker being dead does **not** disable the FLP-AUM manipulation; it *enables* the vault-side fallback path, which is never corrected.

---

## Check 5 — Other deployments

From `https://docs.fulcrom.finance/.../smart-contracts`: exactly one Fulcrom Vault on Cronos (the one analysed). Cross-chain spot checks (read-only): **zkSync Era** Vault `0x7d5b…5a1E` → `isLeverageEnabled=false`, PositionRouter `0x9981…43d6` → `isLeverageEnabled=true`; **Cronos zkEVM** (chain 388, `https://cronos-zkevm.drpc.org`) Vault `0xdDDf…2075` → `false`, PR `0x770b…65ef` → `true`. Same structural pattern; no deployment found with `Vault.isLeverageEnabled==true` at rest. (Scope: the claim concerns Cronos; the Cronos deployment is uniquely affected by the live-trading + fallback combination.)

---

## Check 6 — OrderBook deployed bytecode + executeDecreaseOrder ACL

Impl `0x1b0e19329f1d895372bdb16c0229172aa10cd32a` runtime contains:
- the 32-byte chunk `4f72646572426f6f6b3a206163636f756e742063616e6e6f7420626520612063` ("OrderBook: account cannot be a c") and the 7-byte tail `6f6e7472616374` ("ontract") → **`"OrderBook: account cannot be a contract"` is present** (Solidity long-string split, both fragments found);
- `"OrderBook: only position router"`, `"OrderBook: non-existent order"`, `"OrderBook: invalid price for execution"` etc.
- The check is applied on both create and execute paths for decrease/increase orders (`OrderBook.sol:661, 830, 979, 1012`).
- **No keeper gate on `executeDecreaseOrder`** — probe from dEaD only reverts at `OrderBook: non-existent order`. Anyone can execute a valid decrease order and choose `_feeReceiver`.

---

## Check 7 — Residual callback surface and profit construction

**Callback facts:** `OrderBook._transferOutETH` uses OZ `AddressUpgradeable.sendValue` (full-gas `call{value:}`) and `_feeReceiver` is caller-chosen in `executeDecreaseOrder`; order.account is contract-blocked. `PositionRouter._transferOutETHWithGasLimitFallbackToWeth` caps the refund at **20,000 gas** and runs **after** `disableLeverage`. PositionManager wraps `OrderBook.executeDecreaseOrder` with enableLeverage, but only `onlyOrderKeeper` (FastPriceFeed, honest keeper) can enter and the keeper chooses `_feeReceiver`.

**Attempted reentrancy uses of the permissionless full-gas callback (leverage OFF at that instant):**
1. `Vault.increasePosition` from callback → reverts error 28 (live probe).
2. `ShortsTracker.updateGlobalShortData` → forbidden / no-op (live probes).
3. `FlpManager.addLiquidity/removeLiquidity` directly → private-mode revert; `…ForAccount` → forbidden; via RewardRouter → **allowed** but at unmanipulated AUM at rest — no gain.
4. `Vault.decreasePosition` from callback → works, but closes positions normally; the outer OrderBook frame has no state reads after the refund, so nothing is corrupted.
5. Timing the callback inside a keeper's leverage window → impossible (different transaction; receiver keeper-chosen).
**Result: the July-2025 GMX recipe itself (malicious contract as order.account inside the leverage window) is blocked on this deployment.** Reason (4) holds and the "no attacker callback in an ON window" argument holds.

### However — a permissionless, **non-reentrant** variant of the same bug is live (attempt to falsify "$0 extractable")

Because (i) increases execute with transiently-enabled leverage via PR, (ii) decreases never update `vault.globalShortAveragePrices`, (iii) FLP AUM reads exactly that pair, and (iv) FLP mint/redeem is permissionlessly reachable via the **RewardRouter** (`0x133B…7Ae1`; `isHandler=true`; `mintAndStakeFlp(USDC,…)` from dEaD dies only at `ds-token-insufficient-approval`, i.e. past all access control), an attacker can do:

1. Open short leg 1 (size D₁) via `PR.createIncreasePosition` (short, stable collateral), wait 180 s, execute own request. Cost: 0.05 % margin fee (Timelock fee is swapped in during the window) + 0.3 % deposit fee on collateral + funding.
2. Wait for the market to move (|r−1| = |Δp/p|); open leg 2 (size D₂) at the new price, execute via PR.
3. Close one leg via `PR.executeDecreasePosition` (0.05 % fee). `globalShortSizes` drops but the average stays: the AUM short term is now mis-stated by **U = D₁·D₂·|r−1|/(D₁+D₂)** (either over- or under-statement, depending on which leg is closed and the move's direction).
4. Flash-mint FLP via `RewardRouter.mintAndStakeFlp` (captures the under-statement; `inPrivateMode=true` is bypassed by the handler-only `…ForAccount` path) — or redeem pre-held FLP in the over-statement case.
5. Close the remaining leg (PnL≈0) to normalise AUM, redeem via `unstakeAndRedeemFlp`, repay flash loan.

**Worked numbers with live inputs** (WBTC, block 98,805,374; AUM=$13.236 M; note current shorts are dust so start state is ≈ clean): p₁=$82,440.96; 10 % drop to p₂=$74,196.86; D₁=D₂=$2.8 M (bounded by stablecoin mint headroom below and well inside the $9.31 M PR WBTC cap).
- After leg 2: avg = p₂·(D₁+D₂)/((D₁+D₂)−D₁|r−1|) ≈ $78,102; believed short loss = $280 K = true loss ✓ (formula preserves PnL continuity).
- Close leg 1: believed remaining loss = 2.8 M×(78,102−74,197)/78,102 ≈ **U = $140 K**; true remaining loss = 0 → AUM understated by ≈$140 K.
- Mint M=$5.26 M of FLP at the understated AUM: share fraction f = M/(A₀+M) ≈ 0.286; capture ≈ f·U ≈ **+$40 K**; mint/redeem fees ≈0.5–0.6 %·M ≈ $29 K; margin fees 0.05 %×~$11 M ≈ $5.6 K; funding while held ≈ (reserved/pool)×0.01 %/h × $5.6 M ≈ $1.6 K/day.
- Net ≈ **+$5–10 K for a 10 % move**; U scales linearly with the move (20 % → U≈$280 K, net ≈ +$45–50 K). The binding cap is not PR but **stablecoin USDG mint headroom**: USDC `(maxUsdg − usdg)` = $4.776 M + USDT $0.487 M ≈ **$5.26 M**, which (via the reserve check `reservedAmounts[stable] ≤ poolAmounts[stable]`) also caps total short size to the same order of magnitude.

This is an arithmetic/state model built from live-verified formulas and live parameters, not an executed transaction (read-only mandate). It requires an actual adverse price move between the legs; the trade itself is funded by the move, and the extraction is bounded to tens of thousands of USD per event under current caps — but it is strictly > $0, permissionless, and does not use reentrancy. It also means reason (3)'s premise (“AUM manipulation disabled”) is not just irrelevant, it is the *mechanism* of an available extraction path.

---

## Falsification attempts — log

| # | Attempt | Outcome |
|---|---|---|
| 1 | Direct `Vault.increasePosition/V2` from unprivileged caller | Blocked: error 28 |
| 2 | Find an increase path skipping `_validate(isLeverageEnabled,28)` | None; but PR/PM internally enable the flag — reason (1) false |
| 3 | Direct leverage toggle via Timelock/Vault | Blocked: `Timelock: forbidden` / `Vault: forbidden`; but handler proxies can toggle → reason (2) false |
| 4 | Manipulate ShortsTracker | Dead: no callers (bytecode-verified), not ready, forbidden outside handlers |
| 5 | Check vault-average fallback for AUM | **Confirmed live: AUM uses `vault.globalShortAveragePrices`** |
| 6 | Find an update of the average on decrease | None — size-only; non-atomic pair confirmed |
| 7 | GMX-recipe reentrancy: contract account as order.account | Blocked in deployed bytecode (string + source + create/execute checks) |
| 8 | Full-gas callback during leverage-ON window | None reachable: PR refunds 20 k gas & post-disable; PM windows keeper-only, receiver keeper-chosen |
| 9 | Reenter Vault/FlpManager/ShortsTracker from the permissionless OrderBook callback | Each either reverts (28/forbidden/private) or is a null operation |
| 10 | Permissionless extraction via FLP despite `inPrivateMode` | **Found: RewardRouter is a FlpManager handler; `mintAndStakeFlp`/`unstakeAndRedeemFlp` reach the pipeline (probe fails only at token approval)** |
| 11 | Same end-state without reentrancy (short-pair skew + FLP mint/redeem) | **Positive net PnL under a ≥~10 % adverse move (worked numbers above); bounded by ~$5.26 M stable mint headroom** |
| 12 | Other Fulcrom vaults with leverage enabled | None found (Cronos / zkSync Era / Cronos zkEVM all `Vault.isLeverageEnabled=false`, PR toggle true) |

---

## Verdict

**CLAIM FALSIFIED (as stated)** — confidence: medium-high (high on the state/reason falsification; medium on the net-PnL magnitude of the alternative path).

- The specific July-2025 **order-execution reentrancy** vector is genuinely blocked (deployed contract-account check, no attacker-controlled callback inside a leverage-ON window, 20 k-gas post-disable refunds).
- But the claim's primary reasons (1)–(3) are contradicted by live state: increases execute continuously (42 `IncreasePosition` events in ~1.5 h via transient `enableLeverage`), the toggle is reachable by unprivileged users through handler contracts with `shouldToggleIsLeverageEnabled=true`, and the AUM reads the never-corrected **vault** short-average pair (tracker disconnected) while FLP mint/redeem remains permissionlessly reachable via the RewardRouter despite `inPrivateMode=true`.
- A permissionless, non-reentrant skew path therefore yields **> $0 extractable** under realistic adverse price moves; "$0" does not hold as a general statement.

**Evidence that would change this verdict:** (a) a fork-executed PoC showing the AUM step does not move as derived (or that `getAum` reconciles decreases some other way); (b) gov neutering: `shouldToggleIsLeverageEnabled=false`, remove PR/PM Timelock handler status, remove RewardRouter handler status or set `maxUsdgAmounts` headroom to zero; (c) proof that reserve/mint caps (<$5.3 M) make capture net-negative for all realistic move sizes; (d) a demonstration that the RewardRouter mint path is admin-gated beyond what its selectors, handler registration and live probe show.

*No transactions were signed or sent; no keyed endpoints or secrets were used. All evidence is reproducible read-only against `https://evm.cronos.org` at the cited blocks.*

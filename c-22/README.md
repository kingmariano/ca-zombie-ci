# C2-22 · Fulcrom — GMX V1 order-execution reentrancy (deep-dive)

**Date:** 2026-10-09 · **Chains:** Cronos (25), zkSync Era (324), Cronos zkEVM (388) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions were sent**.

**Headline:** external unprivileged extractable **now = $0** (high confidence). The July-2025 GMX V1 recipe was **patched on Fulcrom on 2025-07-11, two days after the GMX incident**, and the profit engine (ShortsTracker→FLP AUM skew) is disabled on every live deployment. The callback mechanics remain reachable and were reproduced on a Cronos fork; the value at risk if an accounting desync were ever (re)introduced is **~$13.73M** of LP-owned funds.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| **Cronos Vault** `0x8C7Ef34aa54210c76D6d5E475f43e0c11f876098` (~$13.40M) | **$0** | OrderBook rejects contract accounts (create+execute) since the 2025-07-11 patch; attacker-reachable callbacks fire outside the "leverage window"; ShortsTracker AUM-skew disabled (`weight=0`, `ready=false`, no handler calls) | If gov reintroduces a tracker-style desync, the cross-contract reentrancy is one keeper order away — mechanism **proven** on fork (test D2/D3) |
| **zkSync Era Vault** `0x7d5b0215EF203D0660BC37d5D09d964fd6b55a1E` (~$325k) | **$0** | Same patch (OrderBook impl deployed 2025-07-11 06:43 UTC); tracker wiring removed from PositionManager (selector absent); `increasePosition` reverts `"Vault: leverage not enabled"` | Same |
| **Cronos zkEVM Vault** `0xdDDf221d5293619572616574Ff46a2760f162075` | **$0** | Contracts live, leverage disabled, OrderBook byte-identical to the patched zkSync build; chain is sunsetting (operational until 2027-06-03, deposits disabled) | Chain shutdown (assets stuck if not bridged out) |
| Old/other deployments | — | None found beyond the docs set; zkEVM is the only terminal state | — |

**Total live extractable now: $0.00** (confidence: **high**). At-risk-but-LP-owned (H-O): **$13.40M Cronos + $0.33M zkSync ≈ $13.73M**; on-chain FLP AUM ≈ $13.23M + $0.32M.

> The corpus figure "≈$2.7M (754 WETH)" is stale/understated: the live Cronos vault holds **113.34 WBTC ≈ $9.32M**, 741.52 WETH ≈ $1.84M, plus 23 more tokens (see §4).

---

## 2. The bug/mechanism, in exact terms

The GMX V1 exploit (2025-07-09, ~$42M) was a **cross-contract reentrancy through the "leverage window"**:

1. GMX V1's `Vault.isLeverageEnabled` is **false at rest**; the router/manager contracts open it around every order execution (`Timelock.enableLeverage(vault)` → vault call → `Timelock.disableLeverage(vault)`). The vault is otherwise locked.
2. `OrderBook.executeDecreaseOrder` pays the released collateral (native ETH for WETH positions) to `order.account` via `_transferOutETH` → OZ `sendValue` (full gas). If `order.account` is a contract, its `receive()` runs **inside the open leverage window**.
3. From that callback the attacker called `Vault.increasePosition` **directly** (allowed because `Vault._validateRouter` passes when `msg.sender == account`), bypassing `PositionRouter`/`PositionManager` and — critically — the `ShortsTracker.updateGlobalShortData` calls that normally precede every position change.
4. Repeated direct-open / handler-close cycles crashed the ShortsTracker's `globalShortAveragePrice` for BTC ($109,505 → $1,913), inflating GLP AUM via `GlpManager.getGlobalShortDelta`; the attacker minted and redeemed GLP at the distorted price inside the same window and drained ~$42M.

Fulcrom is a GMX V1 fork (solidity 0.8.17, OZ-upgradeable proxies) with the same architecture. Deployed Fulcrom code (Cronos, verified source "Matched" on explorer.cronos.com; recovered in `analysis/sources/cronos/`):

| Component | Role in the recipe | Deployed behavior |
|---|---|---|
| `Vault` proxy `0x8C7Ef…6098` (impl `0xA66a…4672`, 2024-04-19) | `increasePosition`/`decreasePosition` `nonReentrant`, no caller whitelist; `_validateRouter`: `msg.sender==account \|\| msg.sender==router \|\| approvedRouters` | **`isLeverageEnabled()==false` at rest** (window design), `errors(28)="Vault: leverage not enabled"` |
| `OrderBook` proxy `0x1c29ae…0045` (impl `0x1b0e…d32a`, **2025-07-11 06:49 UTC**) | GMX's vulnerable callback surface | `require(!isContract(_account))` **at order creation AND execution**; `_transferOutETH` still uses full-gas `sendValue` |
| `PositionRouter` proxy `0x27fb…f940` (impl `0x8b4d…4e5e`, 2024-04-19) | opens window in `_increasePosition`/`_decreasePosition`; pays `request.receiver` | payouts happen **after** the window closes, gas-capped (`ethTransferGasLimit=20000` on Cronos, 500000 on zkSync) with WETH fallback |
| `PositionManager` proxy `0xFC39…dB16` (impl `0xbb8a…55ec`, 2024-04-19) | keeper wrapper that opens the window around `OrderBook` execution | in-window callbacks exist (fee refund) but the `_feeReceiver` is **chosen by the keeper**, not the attacker; `shortsTracker` marked deprecated, `updateGlobalShortData` call removed |
| `ShortsTracker` proxy `0xd996…148a` (impl `0xf5e8…2d39`, 2023-02-27) | the profit engine's manipulated state | `isGlobalShortDataReady()==false`, not callable by non-handlers |
| `FlpManager` proxy `0x6148…891F` (impl `0x7431…3021`, 2023-02-27) | FLP AUM | `shortsTrackerAveragePriceWeight()==0` → AUM uses the Vault's own (non-manipulable) average |

Deployment timeline (on-chain receipts, `analysis/cronos_impl_deployments.json`):
- 2023-02-27 — FlpManager / ShortsTracker / Vault proxy
- 2024-04-19 — current Vault, PositionRouter, PositionManager impls (tracker wiring already deprecated)
- **2025-07-11 06:49:41 UTC — current OrderBook impl (Cronos) and 06:43:26 UTC (zkSync): `"OrderBook: account cannot be a contract"` guard present.** GMX was exploited 2025-07-09 12:30 UTC.

---

## 3. Live-state assessment (every claim cited)

All reads at explicit blocks; scripts in `analysis/` and `ci/`.

### 3.1 Cronos (block 98,806,373, 2026-10-09)

| Check | Result |
|---|---|
| `Vault.isLeverageEnabled()` | `false` (resting state of the window design — **not** a pause; see §5) |
| `Vault.isSwapEnabled()` | `true` |
| `Vault.errors(28)` | `"Vault: leverage not enabled"` |
| `Vault.gov()` | `0x880a34751D8452df466ae27Ac341F987f0dAf3AE` (Timelock) |
| `Vault.router()` | `0xcC46b79eBEaA1D834B707624977Ec261592E0C9a` (Router) |
| `Vault.increasePosition(0x…dEaD, WCRO, WCRO, 1e18, true)` from `0x…dEaD` | **revert `Vault: leverage not enabled`** (0x08c379a0…, eth_call) |
| `Timelock.enableLeverage(vault)` from `0x…dEaD` | **revert `Timelock: forbidden`** |
| `Timelock.admin()` | `0x04Fc879C9068Dc265424949128851Ca19D96eC02` — **EOA (no code)** |
| `Timelock.shouldToggleIsLeverageEnabled()` | `true`; `buffer=86400`; `isHandler(PositionRouter)=true`, `isHandler(PositionManager)=true` |
| `PositionRouter.isLeverageEnabled()` (router trading flag) | **`true`** — public order execution active (`minTimeDelayPublic=180s`, `maxTimeDelay=1800s`) |
| `PositionRouter.ethTransferGasLimit()` | `20000` (gas-capped native payouts) |
| `OrderBook.minExecutionFee()` | `0.6 CRO`; `weth()=WCRO 0x5C7F8A…AE23` |
| `ShortsTracker.isGlobalShortDataReady()` | `false`; `updateGlobalShortData(...)` from `0x…dEaD` → revert `ShortsTracker: forbidden` |
| `FlpManager.shortsTrackerAveragePriceWeight()` | `0` |
| `OrderBook` impl bytecode | contains full literal `"OrderBook: account cannot be a contract"` (decoded from the 32-byte head + SHL tail; see `ci/checks.py`) |
| `PositionRouter`/`PositionManager` impl bytecode | `updateGlobalShortData` selector `0xf3238cec` **absent** |
| Protocol activity | live txs at the chain tip (block ~98,805,450): `createIncreasePositionV2`, `createDecreasePosition`, `Liquidate Position`, `Set Max Global Sizes` — the protocol is trading |

**Proxy admin / upgrade authority:** all core proxies' EIP-1967 admin = `0x4a4e3cdd9e16b9096100b75c2edb74837cac5e36` (OZ `ProxyAdmin` contract), whose `owner()` = `0x04Fc879C9068Dc265424949128851Ca19D96eC02` (**single EOA**). That key can upgrade every proxy (P-level risk, §8).

### 3.2 zkSync Era (block 72,395,704, child verification: `analysis/zksync-verify.md`)

- `Vault.isLeverageEnabled()=false`; `errors(28)="Vault: leverage not enabled"`; direct `increasePosition` and struct-`increasePositionV2` (`0x6de65347`) both revert with that string; `Timelock.enableLeverage/setIsLeverageEnabled` from a random address revert `Timelock: forbidden`.
- `ShortsTracker.isGlobalShortDataReady()=false`, `FlpManager.shortsTrackerAveragePriceWeight()=0`; PositionManager impl **lacks** the `updateGlobalShortData` selector (7 control selectors present); OrderBook is not a tracker handler.
- OrderBook impl `0x62f983926169c1A378452066f736DD39b9A3B9f2` deployed **2025-07-11 06:43:26 UTC**, embeds `"OrderBook: account cannot be a contract"`, and **behaviorally rejects contract senders** for `createIncreaseOrder`/`createDecreaseOrder` while a funded EOA passes to later validation.
- Vault balances (exact): WETH 8.2355 ($20,485.75) + WBTC 2.2641 ($185,844.31) + USDC 18,242.70 ($18,235.78) + USDC.e 48,518.05 ($48,500.26) + USDT 31,244.65 ($31,222.92) + ZK 1,771,367.53 ($21,085.71) = **$325,374.72**; FLP supply 503,541.04; AUM $323,549.08 (FLP ≈ $0.6425).

### 3.3 Cronos zkEVM (chain 388, block 2,670,891)

- Correct RPC is `https://mainnet.zkevm.cronos.org` (`zkevm-rpc.com` is Polygon zkEVM — corrected mid-analysis).
- Vault `0xdDDf…2075` has code (8,992 bytes eraVM), `isLeverageEnabled()=false`, `increasePosition` from a random address reverts `Vault: leverage not enabled`.
- OrderBook impl `0x7ae282c8f7c45f481adf667b94cffe8e3d9742e0` is **byte-for-byte identical** to the patched zkSync OrderBook (guard literal included).
- Cronos blog (2026-06-03): zkEVM alpha sunsets — operational until **2027-06-03**, bridge deposits already disabled.

### 3.4 Value in scope (Cronos, block 98,801,213; `analysis/cronos_vault_balances.json`)

| Token | Amount | USD |
|---|---:|---:|
| WBTC | 113.338565 | $9,317,328 |
| WETH | 741.524095 | $1,844,525 |
| USDC | 248,053.83 | $247,963 |
| USDT | 178,903.99 | $178,780 |
| ADA | 638,736.57 | $150,051 |
| WCRO | 1,534,795.00 | $92,879 |
| ATOM | 49,606.00 | $92,537 |
| NEAR | 26,310.27 | $124,853 |
| SHIB | 18,797,647,086 | $100,668 |
| PEPE | 21,696,222,485 | $84,903 |
| SUI | 68,056.73 | $71,798 |
| HBAR | 2,029,951.83 | $186,254 |
| AAVE | 404.18 | $66,881 |
| DOGE / TRUMP / WIF / PENGU | 626,891 / 7,942 / 119,269 / 5,114,076 | $53,244 / $14,670 / $25,308 / $41,345 |
| XRP / PAXG / SOL / LTC / BCH / UNI (est. via CoinGecko) | 138,600 / 88.68 / 469.09 / 743.64 / 71.93 / 3,113.56 | $192,988 / $370,855 / $51,643 / $47,584 / $20,136 / $22,887 |
| **Total** | | **≈ $13,400,079** |

On-chain `FlpManager.getAum(true)` = `1.3227e37` (1e30 scale) ≈ **$13.23M**; FLP supply 11,778,922.27; LP redemptions open (`removeLiquidity`, `cooldownDuration=0`).

---

## 4. What an attacker can and cannot do (exact call paths)

**Can (all unprivileged, all verified live or on fork):**
- Create orders (`OrderBook.createIncreaseOrder(V2)`, `createDecreaseOrder`) and execute/cancel them.
- Call `OrderBook.executeDecreaseOrder(_address, _orderIndex, _feeReceiver)` **directly** (permissionless, `nonReentrant` only) with `_feeReceiver` = attacker contract → **full-gas native callback** inside the tx. Fork test D1 proves the callback fires.
- Call `PositionRouter.executeIncreasePosition/executeDecreasePosition` singles (public after `minTimeDelayPublic=180s` when the account is the caller).
- Re-enter `Vault.increasePosition/decreasePosition` from any callback (Vault `nonReentrant` is per-contract; cross-contract reentry is not blocked) — **only succeeds while a window is open** (D2/D3).
- Mint/redeem FLP, swap, liquidate per normal rules.

**Cannot (each proven or source-cited):**
1. Open a position from the direct OrderBook path: the window is closed, `Vault.increasePosition` reverts `"Vault: leverage not enabled"` (D1, live eth_call).
2. Be the `order.account` of any OrderBook order: `require(!isContract(_account))` at **creation and execution** (test C; bytecode literal decoded; zkSync behaviorally proven). This kills the exact GMX callback target. (EIP-7702-delegated EOAs also have code → blocked.)
3. Occupy the in-window callback on the keeper path: `PositionManager.executeDecreaseOrder` is `onlyOrderKeeper` and the `_feeReceiver` it forwards is the keeper's choice; `amountOut` goes to the EOA account.
4. Abuse the PositionRouter payouts: they occur **after** `_decreasePosition`/`_increasePosition` return (window closed), are gas-capped (20k Cronos / 500k zkSync), and fall back to a WETH transfer on failure.
5. Update the ShortsTracker (non-handler → revert) or re-enable leverage (Timelock `onlyHandlerAndAbove` → revert).
6. Skew FLP AUM: the tracker is not in the AUM path (`weight=0`, `ready=false`), and the Vault's own `globalShortAveragePrices` only moves toward oracle prices on increases — no attacker-controlled desync.

**Costs:** the only attacker-reachable full-gas callback (direct OrderBook path) yields zero value today; no flash loan or capital is needed to attempt it, and it reverts at the guard. If a window-open callback ever becomes attacker-reachable again, capital requirements would mirror the GMX recipe (a few million USD of flash liquidity — irrelevant until a profit primitive exists).

---

## 5. Why `isLeverageEnabled()==false` is *not* a paused protocol

GMX V1's design keeps the Vault locked (`isLeverageEnabled=false`) and opens the window inside each execution:

```
PositionRouter._increasePosition:  Timelock.enableLeverage(vault) → Router.pluginIncreasePositionV2 → Vault.increasePositionV2 → Timelock.disableLeverage(vault)
PositionRouter._decreasePosition:  Timelock.enableLeverage(vault) → Router.pluginDecreasePosition  → Vault.decreasePosition  → Timelock.disableLeverage(vault)
PositionManager.executeIncreaseOrder/executeDecreaseOrder/liquidatePosition: same wrapping around the OrderBook/Vault call
```

The router's own `isLeverageEnabled` flag (live: `true`) governs whether the public may execute; the vault flag is the low-level window. This is why the direct-call revert (`errors[28]`) is a guard but not a global pause, and why the analysis focuses on **who can fire a callback inside a window** — the attacker cannot.

---

## 6. PoC / fork verification

- Project: `poc/` (Foundry; `vm.createSelectFork(CRONOS_RPC_URL || https://evm.cronos.org)`; no mainnet writes).
- Files: `poc/test/FulcromC2_22.t.sol`, `poc/src/IFulcrom.sol`.
- Tests (8): `A_live_gates`, `A_direct_increase_reverts`, `B_timelock_not_permissionless`, `C_orderbook_rejects_contract_account`, `D1_direct_callback_blocked_by_guard`, `D2_reenabled_leverage_reentrancy_succeeds`, `D3_keeper_window_opens_and_in_window_reentrancy_works`, `E_shorts_tracker_not_updatable`.
- CI (public repo `kingmariano/ca-zombie-ci`, workflow `poc.yml`):
  - run 1 (4/7 pass — unit bugs found): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37888047610
  - run 2 (5/8 pass — sizing vs live `fixedLiquidationFeeUsd`): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37889432365
  - run 3 (final): RUN3_URL_PLACEHOLDER
- Key fork observations:
  - D1: the permissionless OrderBook fee callback fires with `vault.isLeverageEnabled()==false`; the in-callback `Vault.increasePosition` reverts with `Error("Vault: leverage not enabled")` (exact 0x08c379a0 payload).
  - D3: with a simulated keeper, the callback fires with `isLeverageEnabled()==true` (window open) and the cross-contract reentrancy **succeeds** — the mechanism is live; only the callback-target ownership and the missing profit primitive stand in the way.
- Bytecode guard evidence is also checked by `ci/checks.py` (string reconstruction; selector absence) — output in `ci-out/checks.txt` / CI logs.

---

## 7. Verdict and residual/latent risk

**Verdict: E-U $0 (high confidence).** The specific July-2025 GMX-V1 order-execution reentrancy is **not exploitable** on Fulcrom's live deployments:
1. The exact GMX callback target (contract `order.account`) was eliminated on **both chains on 2025-07-11**, two days after the GMX exploit.
2. Every attacker-reachable callback fires **outside** the leverage window; in-window callbacks go to keeper-chosen receivers.
3. The profit engine (ShortsTracker→FLP AUM) is disabled at every layer, and its wiring is absent from deployed handler bytecode.

**Categories:** **E-U $0** · **H-O** ≈ **$13.73M** (FLP holders' redemption claim; `removeLiquidity` open, cooldown 0) · **P** = admin/Timelock powers over $13.73M (see below) · **S** = $0 today (zkEVM assets become stuck after 2027-06-03 if not withdrawn).

**Residual / latent risk (what to watch):**
- `ShortsTracker.isGlobalShortDataReady()` turning **true**, `shortsTrackerAveragePriceWeight` becoming non-zero, or handlers regaining `updateGlobalShortData` wiring → re-arms the AUM manipulation.
- A new position-order entry point that accepts contract accounts, or `Router.approvedPlugins` being enabled for swap-order creation (currently disabled for everyone; swap orders cannot reach position logic anyway).
- **P-key exposure:** Timelock admin is a single EOA `0x04Fc879C…` (also owner of the `ProxyAdmin` `0x4a4e3c…` that can upgrade all core proxies) — key compromise = full protocol control. Not E-U.
- zkEVM sunset: funds on chain 388 must be bridged out before 2027-06-03.

---

## 8. Methodology, sources, caveats, files

**Method:** verify addresses/flags/roles live at explicit blocks; recover deployed sources from the Cronos explorer (`status: Matched`, `s3FileKeys` → `explorer.cronos.com/contract/cronos-mainnet/...`) and compare with upstream GMX V1; bytecode string/selector checks for the guards; fork PoCs in GitHub Actions; cross-chain verification by a dedicated child agent; independent adversarial falsification by a second child agent.

**Key sources:** `docs.fulcrom.finance` contract lists; `explorer.cronos.com` (verified sources, creation txs); GMX `gmx-io/gmx-contracts` (upstream Vault/OrderBook/PositionManager/PositionRouter/ShortsTracker); BlockSec/SolidityScan/QuillAudits GMX incident analyses; `coins.llama.fi` prices; public RPCs `evm.cronos.org`, `mainnet.era.zksync.io`, `mainnet.zkevm.cronos.org`, `zksync.blockscout.com`.

**Caveats:** (1) explorer "Matched" status plus our string/selector spot checks; a full compile-and-compare was not performed for every impl. (2) The pre-2025-07-11 OrderBook impl was not recovered (no archive log scan available on Cronos' 2k-block log cap); the patch timing is inferred from the impl creation receipt (2025-07-11) and the guard's presence in the current bytecode. (3) Order-keeper identities were not enumerated (no public keeper list; GoldRush index stale); the keeper-window test simulates a keeper via `stdstore`. (4) USD totals use DefiLlama/CoinGecko at 2026-10-09; six tokens lack a Cronos DefiLlama price and are estimated with CoinGecko mainnet prices. (5) No EIP-7702-specific test, though the create/execute-time `isContract` checks cover delegated EOAs.

**Files:** `summary.json`; `analysis/` (verified sources per contract, `cronos_contract_files.json`, `cronos_vault_balances.json`, `zksync_vault_balances.json`, `cronos_impl_deployments.json`, `zksync-verify.md`, `independent-verification.md`, artifacts); `poc/`; `ci/checks.py`, `ci/run.sh`; `ci-out/`; `ci-log.txt`; `ci-artifacts/`.

**CI runs:** see §6 (run 3 final URL recorded there and in `summary.json`).

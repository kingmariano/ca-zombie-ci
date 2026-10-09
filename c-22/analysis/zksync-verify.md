# C2-22 — zkSync Era leg verification (Fulcrom, GMX V1 fork)

**Subagent:** C2-22 zkSync leg · **Date:** 2026-10-09 · **Mode:** read-only (eth_call / eth_getCode / eth_getStorageAt only; no tx sent)
**Endpoints used (public only):** `https://mainnet.era.zksync.io` (RPC), `https://zksync.blockscout.com`, `https://sourcify.dev`, `https://block-explorer-api.mainnet.zksync.io`, `https://coins.llama.fi`, `https://mainnet.zkevm.cronos.org`, `https://blog.cronos.com`
**zkSync pin block:** `0x450abb8` = **72,395,704** (all `cast call`/`cast code` reads below unless stated)

Addresses (Fulcrom docs / parent context, all re-validated):
Vault `0x7d5b0215EF203D0660BC37d5D09d964fd6b55a1E` · Router `0x850Fe8be964cC5Feb3dd00CfE1364590B45e3926` · OrderBook `0xc1088d3DD3E997aAe11F0fACb328843bAA698464` · PositionRouter `0x99819F0e0927718f5FbC73d3327FF7691D0243d6` · PositionManager `0xf2220Ae74866FF181B5922613F94d92E84f2491f` · Timelock `0x88CA1fB542A8c45cCcb0ee43042bAC616319761b` · ShortsTracker `0xBca6063d860dc9c58aE495e10634EE50bEDc71Ec` · FlpManager `0x84DD021B2FCA11ef1bcCADF4231c75989516308b` · FLP `0xD939BAE19dD60634E70c8A866C1b11477fC72954`

Proxy → impl slots (EIP-1967 `0x3608…382bbc`, all confirmed at pin block, match parent):
Vault → `0x442DbDE560FaD77fF197dD719777F840392a48b3` · OrderBook → `0x62f983926169c1A378452066f736DD39b9A3B9f2` · PositionRouter → `0xe464d7f0E98f1754968bFbE24f19f666B101F86e` · PositionManager → `0x1BFe8EB67c76DFb4b13174d45eDED218C7dE4e64` · FlpManager → `0x6dc481db1819278e6BbC3edE39DaA778cEb68CC0` · ShortsTracker → `0x2e07D8caF6c539705EdfA362D56EB5C69AFa6E4d` · VaultUtils → `0xc7C7b5925aE74530EaAF8314e46e556AEb42b246`.
Proxy/impl creation (native explorer): Vault impl created block 32,460,077 = **2024-04-26 09:15:50 UTC**; PositionRouter impl block 32,460,635 = 2024-04-26; **OrderBook impl block 62,713,531 = 2025-07-11 06:43:26 UTC (2 days after the 2025-07-09 GMX V1 exploit)** — i.e. the live OrderBook is a post-incident (re)deployment.

---

## Check 1 — Vault reads (0x7d5b…5a1E @ 72,395,704)

| call | raw result |
|---|---|
| `isLeverageEnabled()` | **false** |
| `isSwapEnabled()` | true |
| `maxGasPrice()` | 0 |
| `gov()` | 0x88CA1fB542A8c45cCcb0ee43042bAC616319761b (Timelock) |
| `router()` | 0x850Fe8be964cC5Feb3dd00CfE1364590B45e3926 ✓ docs |
| `usdg()` | 0x790E4a97FFA927987Ee0f50512C22031bB5533f0 |
| `priceFeed()` | 0x27eBC5c0Ed31c8f74a7526617426BDBEB9124fEC — **≠ docs VaultPriceFeed 0x93140f8d…**; both are proxies: 0x27eBC5 → impl 0x0d664992dae88203320d392cec9feedce368ca9e; 0x93140f → impl 0x42429f93e42d638fc63548910d3f5d5c2efca6c6 (docs address appears stale; vault uses 0x27eBC5) |
| `inManagerMode()` | true |
| `inPrivateLiquidationMode()` | true |
| `errors(28)` | `"Vault: leverage not enabled"` |
| `errors(41)` | `"Vault: invalid msg.sender"` |
| `maxLeverage()` | 1500000 (150x) |
| `marginFeeBasisPoints()` | 500 |
| EIP-1967 impl slot | 0x442DbDE560FaD77fF197dD719777F840392a48b3 ✓ |

## Check 2 — ShortsTracker / FlpManager (@ 72,395,704)

| call | raw result |
|---|---|
| ShortsTracker `isGlobalShortDataReady()` | **false** |
| ShortsTracker `vault()` | 0x7d5b…5a1E ✓ |
| ShortsTracker `isHandler(OrderBook)` | **false** |
| ShortsTracker `isHandler(PositionRouter)` | true |
| ShortsTracker `isHandler(PositionManager)` | true |
| ShortsTracker `gov()` | 0x04Fc879C9068Dc265424949128851Ca19D96eC02 |
| FlpManager `shortsTracker()` | 0xBca6063d860dc9c58aE495e10634EE50bEDc71Ec ✓ |
| FlpManager `shortsTrackerAveragePriceWeight()` | **0** |
| FlpManager `cooldownDuration()` | 0 |
| FlpManager `getAum(true)` | 323549076039123291922033198334681743 (= $323,549.08 @ 1e30) |
| FlpManager `vault()` | 0x7d5b…5a1E ✓ |

## Check 3 — Timelock (0x88CA…761b @ 72,395,704) + unprivileged attempt

| call | raw result |
|---|---|
| `admin()` | 0x04Fc879C9068Dc265424949128851Ca19D96eC02 — **EOA (code = 0x)**, holds ~0.59 ETH (centralization note) |
| `shouldToggleIsLeverageEnabled()` | 1 (plain uint256 getter; keyed `(address)` getter reverts `0x` → not a mapping) |
| `isHandler(PositionRouter)` | true |
| `isHandler(PositionManager)` | true |
| `buffer()` | 86400 |
| `enableLeverage(vault)` **from 0x…dEaD** | revert `Timelock: forbidden`, data `0x08c379a0…0013 54696d656c6f636b3a20666f7262696464656e` |
| `setIsLeverageEnabled(vault,true)` **from 0x…dEaD** | same revert `Timelock: forbidden` |

⇒ an unprivileged address cannot re-enable leverage; only Timelock handlers (PositionRouter/PositionManager, both true) during keeper execution, or the admin EOA via Timelock.

## Check 4 — direct position entry-point probes (from 0x…dEaD @ 72,395,704)

| call | raw result |
|---|---|
| `Vault.increasePosition(dEaD, WETH, WETH, 1e18, true)` | revert **`Vault: leverage not enabled`** (= errors[28]); data `0x08c379a0…001b 5661756c743a206c65766572616765206e6f7420656e61626c6564…` |
| `Vault.increasePositionV2` flat 7-arg `(address,address,address,uint256,bool,address,uint256)` | revert `0x` (empty) — that selector (`0x9d8bdd6f`) is **not in the code** |
| `Vault.increasePositionV2((address,address,address,uint256,bool,address,uint256))` — **struct tuple; selector `0x6de65347` IS in impl code** | revert **`Vault: leverage not enabled`** (same data) |

Controls on same Vault from dEaD: `swap(...)` → `Vault: invalid tokens` (isSwapEnabled true, public swap path); `decreasePosition(...)` → `Vault: empty position` (self-account path). The leverage gate is the first gate hit by `increasePosition`/`increasePositionV2`.

## Check 5 — bytecode evidence (zkSync Era / eraVM, `isEvmLike:false`, code prefix `0x0004…`)

a) **`OrderBook: account cannot be a c`** — found in OrderBook impl `0x62f98392…` (1 hit; head word at code offset 67520, zero-padded tail word `ontract` exactly 32 bytes earlier at 67488 ⇒ full literal **"OrderBook: account cannot be a contract"** embedded).
b) Controls: `OrderBook: non-existent order` present; `OrderBook: insufficient execution fee` present as split head+tail words (and observed behaviorally as a live revert string).
c) `updateGlobalShortData(address,address,address,bool,uint256,uint256,bool)` selector **`0xf3238cec`**:
   - ShortsTracker impl: **present** (scan method valid);
   - PositionRouter impl: **absent** (upstream GMX PositionRouter never calls it — expected, not evidence of hardening);
   - PositionManager impl: **absent**, while PM control call-constants are present: `enableLeverage(address)`=1, `disableLeverage(address)`=1, `getPosition(…)`=1, `getIncreaseOrder(…)`=1, `executeIncreaseOrder(…)`=2, `orderBook()`=1, `isOrderKeeper(address)`=1. Upstream GMX PM calls `updateGlobalShortData` 3× (liquidate/executeIncrease/executeDecrease) ⇒ the zkSync PM is a variant with the ShortsTracker wiring removed. Consistent with tracker state (`isGlobalShortDataReady=false`, weight 0).
d) Scannability: code is eraVM form (not EVM), printable-ASCII runs ≥8 chars cover only 0.17–1.23% of each blob. Working method: short strings (≤32 B) contiguous; longer strings split as 32-byte head + zero-padded tail word; function selectors stored as zero-padded right-aligned 32-byte words (bare 4-byte grep works). Selector-matrix vs upstream GMX sources: Vault 45/59 external/public selectors found, OrderBook 13/17, PositionManager 7/15, PositionRouter 12/20 (misses include admin-only functions such as `addRouter`/`initialize`/`upgradeVault`, so some misses are real code divergence, some are admin surface).

**Behavioral guard proof (strongest evidence), @ 72,395,704** — same calldata, different sender, on OrderBook proxy `0xc1088d…8464`:
| call | sender | result |
|---|---|---|
| `createIncreaseOrder([WETH],1,WETH,0,1e18,WETH,true,1,false,1e14,true)` value 1e14+1 | WETH contract `0x5aea…` | revert **`OrderBook: account cannot be a contract`** (full 39-char string in revert data) |
| same | EOA `0x04Fc879C…` (funded) | revert `OrderBook: insufficient collateral` ⇒ **passes the guard** |
| `createDecreaseOrder(WETH,1,WETH,0,true,1,false)` value 1e14 | WETH contract | revert **`OrderBook: account cannot be a contract`** |
| same | EOA `0x04Fc879C…` | revert `0x` (bare; does not affect guard conclusion) |
| `createSwapOrder([WETH,USDC],…)` | WETH contract **and** EOA | both reach `Router: plugin not approved` ⇒ no account guard on swap-order creation; `Router.approvedPlugins(WETH,OrderBook)=false`, `(USDC,OrderBook)=false` ⇒ non-wrap swap-order creation is currently disabled for everyone |

⇒ **Guard is present and active for position orders (increase + decrease), both proven on-chain. Swap-order creation lacks the guard but cannot reach position/vault logic (plugin path disabled) and is not part of the July-2025 recipe.**

## Check 6 — FLP + vault token USD (@ 72,395,704; prices from coins.llama.fi fetched 2026-10-09)

| token | vault balance | price USD | USD |
|---|---|---|---|
| WETH (18) | 8.2355464057529404 | 2487.4786 | $20,485.75 |
| WBTC (8) | 2.26411649 | 82082.4861 | $185,844.31 |
| USDC (6) | 18,242.701154 | 0.999621 | $18,235.78 |
| USDC.e (6) | 48,518.045323 | 0.999633 | $48,500.26 |
| USDT (6) | 31,244.650551 | 0.999304 | $31,222.92 |
| ZK (18) | 1,771,367.5318708753 | 0.0119036 | $21,085.71 |
| **TOTAL** | | | **$325,374.72** |

Parent's ≈$325.4k **confirmed**. FLP: totalSupply 503,541.0377 (18 dec); AUM(true) $323,549.08; **FLP price ≈ $0.6425**. (AUM excludes ~$1.8k of price-timestamp/valuation differences vs the raw token sum.)

## Check 7 — Cronos zkEVM (chain 388) — **parent context correction**

`https://zkevm-rpc.com` is **Polygon zkEVM (chain 1101)**, not Cronos. Correct Cronos zkEVM RPC: **`https://mainnet.zkevm.cronos.org`** (chainId **388** verified; latest block 2,670,891, ts 2026-10-09 05:16:21 UTC; block 1 ts 2024-07-31 = genesis). On the correct chain:

| address | code | identity / state (@ 2,670,891) |
|---|---|---|
| `0xdDDf221d5293619572616574Ff46a2760f162075` | present (17,986 hex; same proxy codehash `0xebb945ab…` as others) | **Vault** (gov=0x02aB5dB5888cCbA5c9C9c32b55B3393a15ca4B8A; router=0x925C…; `isLeverageEnabled()=false`; errors(28)="Vault: leverage not enabled"; `increasePosition` from dEaD → `Vault: leverage not enabled`); impl 0xb7f4af6ea66fc781c31b86c2eae2b37e01108edf |
| `0x925C9a84Cc47A0fC43eFfFBE1d8Bb381D61f0333` | present | **PositionRouter** (vault=0xdDDf…; gov=0x04Fc87…); impl 0x5be7e1cb54850d68725e1d0438d6da46e5191b87 |
| `0x1F1650cc835F28dE73dC425Ffb372A0eFD2Ec572` | present | **OrderBook** (vault=0xdDDf…; router=0x925C…; gov=0x04Fc87…); impl **0x7ae282c8f7c45f481adf667b94cffe8e3d9742e0** |

**zkEVM OrderBook impl code is byte-for-byte identical to the zkSync OrderBook impl (direct full-hex compare; same 137,923 hex length), and it contains the same `OrderBook: account cannot be a c…` guard literal and `createIncreaseOrder` selector.** zkEVM Vault impl (193,347 hex) is a different/older build than zkSync's (271,299 hex) but is leverage-disabled.

Chain status: Cronos blog "Sunsetting the Cronos zkEVM Alpha in 2027" (**2026-06-03**): chain remains operational until **2027-06-03 03:00 UTC**, then permanently shut down; **bridge deposits already disabled, withdrawals only**; dApps expected to wind down. ⇒ zkEVM leg = live contracts, leverage disabled, patched OrderBook, but chain in terminal wind-down (assets not recoverable after shutdown per blog).

## Check 8 — source/ABI availability probes (zkSync)

- `zksync.blockscout.com/api/v2/smart-contracts/<addr>`: returns creation/proxy fields only — **no `abi`, no `is_verified`** (vault, vault impl, orderbook impl, positionrouter impl, positionmanager impl).
- Sourcify v2 (`/server/v2/contract/324/0x7d5b…`): `{"match":null,"creationMatch":null,"runtimeMatch":null}` ⇒ **not verified**.
- Native explorer `block-explorer-api.mainnet.zksync.io`: `/contracts/<addr>` → 404; **`/address/<addr>` works** — returns eraVM bytecode, createdInBlockNumber, creatorAddress, `isEvmLike:false`, token balances; **no ABI/source**.
- Conclusion: **no verified source or ABI on zkSync Era** for any Fulcrom contract; all conclusions from bytecode pattern scans + behavioral `eth_call`, cross-checked against upstream GMX V1 sources (fetched to artifacts).

---

## Explicit verdicts

- **(a) Leverage-disabled: YES (zkSync + Cronos zkEVM).** `isLeverageEnabled()=false`; `increasePosition` and struct-`increasePositionV2` both revert `errors[28] "Vault: leverage not enabled"`; unprivileged cannot flip leverage (`Timelock: forbidden`). Caveat: the keeper flow briefly calls `Timelock.enableLeverage` (handlers = PositionRouter/PositionManager) around order execution — that window is the recipe's precondition, and it is neutralized by (b)+(c).
- **(b) Tracker-disabled: YES.** `isGlobalShortDataReady()=false`, `shortsTrackerAveragePriceWeight()=0`, `cooldownDuration=0`, OrderBook not a ShortsTracker handler, and the zkSync PositionManager impl omits the `updateGlobalShortData` call entirely (controls confirm scan validity). The global-short-price manipulation that gave the July-2025 attack its profit is inert.
- **(c) OrderBook account-check: PRESENT.** Literal `"OrderBook: account cannot be a contract"` embedded in the OrderBook impl (deployed **2025-07-11**, 2 days after the GMX exploit; identical code on Cronos zkEVM), and behaviorally proven: `createIncreaseOrder` and `createDecreaseOrder` from a contract sender revert with that exact string while a funded EOA sender passes to later validation.
- **zkSync total:** **$325,374.72** across the 6 tracked vault tokens (FLP price ≈ $0.6425).
- **zkEVM (chain 388) status:** contracts deployed and responding; Vault leverage disabled; OrderBook byte-identical to the patched zkSync build; chain announced sunset 2026-06-03, operational until 2027-06-03, deposits disabled. **Note the RPC correction: `zkevm-rpc.com` is Polygon zkEVM, not Cronos.**

**Confidence: HIGH** for (a)/(b)/(c) on zkSync and for the zkEVM code-presence result (behavioral + bytecode + cross-chain identical-code evidence; no source needed). **Medium-high** on the exact reason the zkSync PositionManager lacks `updateGlobalShortData` (single-selector absence, though backed by 7 present control selectors and matching tracker state).

**What would change the verdict:** (1) a Vault impl upgrade to a build without the `errors[28]` gate, or any path that leaves leverage enabled outside keeper execution; (2) Timelock admin key compromise — admin is a single EOA `0x04Fc879C…` (no code, holds gas ETH), and handlers can call `enableLeverage`; (3) a new/alternative position-order entry point accepting contract accounts, or `Router.approvedPlugins` being enabled again (swap-order creation currently lacks the guard but cannot reach vault logic); (4) ShortsTracker `isGlobalShortDataReady` becoming true / weight changing / OrderBook becoming a handler; (5) discovery that the frontend trades on different vault/impl addresses than those verified here (unlikely — all docs addresses respond consistently with a live Fulcrom deployment).

**Artifacts:** `/home/heisenberg/CA/c-22/analysis/artifacts/` — `orderbook_impl.hex`, `positionrouter_impl.hex`, `positionmanager_impl.hex`, `vault_impl.hex`, `timelock.hex`, `shortstracker_impl.hex`, `zkevm_orderbook_impl.hex`, `zkevm_vault_impl.hex`, `gmx_{Vault,OrderBook,PositionRouter,PositionManager,ShortsTracker}.sol`, `blockscout_*.json`, `zksync_explorer_vault.json`. No keys/secrets used or stored.

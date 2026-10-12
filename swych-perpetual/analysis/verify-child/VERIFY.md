# VERIFY.md — independent verification of the Swych Perpetual (BSC) headline claims

**Verification child session:** `ses_ece306cddffeSyHoLXfvBs4nsP` (supersedes `STATUS.md` in this folder).
**Date:** 2026-10-12 (UTC) · **Chain:** BSC (56) · **Mode:** READ-ONLY — `cast call` / raw `eth_call` /
`cast code` / storage reads + local anvil fork simulations only. No mainnet transactions, no keys used in any
saved artifact, all RPCs are public & keyless (`bsc-rpc.publicnode.com`, `bsc.blockrazor.xyz`, `bsc.drpc.org`).
**Block anchors:** bytecode read at **127,275,294**; role probes at **127,275,884–127,275,936**; claim-2/3
reads on `latest` ≈ **127,276,3xx** (20:43–20:47Z) and re-anchored at **127,279,563–571** (cross-RPC);
Pool balance anchor **127,278,786**; final head 127,279,919.

> **Workspace anomaly (recorded for the parent):** at ~21:40 local the parent folder
> `/home/heisenberg/CA/swych-perpetual/` was deleted by an external process while this session was running
> (this child had already written `analysis/verify-child/raw/*`). Evidence was recovered verbatim from the
> CI-sync copy at `/tmp/opencode/ca-zombie-ci-swych-perpetual/swych-perpetual/`; the deliverable path
> `analysis/verify-child/` was recreated and the work continued. A copy of the parent's files as of 21:35 is
> preserved under `verify-child/ref-parent/` (leads only, not trusted as evidence). No parent file was
> modified.

---

## 0. Verdict summary

| # | Claim | Verdict |
|---|---|---|
| 1 | Deployed PriceReporter `0x1CB9…0dC5` exposes **no unprivileged state-changing function**; `executeOrder`/`executeSwapOrder`/`postPrices` are call-constants only; twin `0x161B…143d` same | **CONFIRMED** (with a correction: the "identical twin" is **not byte-identical** and has a different owner — see §5.1) |
| 2 | OrderManager `0x092D…2DCe`: `executeOrder` onlyExecutor = the PriceReporter; `placeOrder` permissionless but self-funded; all 8 pending orders (429, 3073, 3198, 3233, 3394, 3423, 3633, 4071) owned by zero-size-position holders | **CONFIRMED** (all 8 verified, not only 4) |
| 3 | TR1 `0x03F9…b28A`: 100% of supply held by EOA `0x9A6A…a59a`, which is `isLiquidityProvider==true`; random address false | **CONFIRMED** (balance == totalSupply exactly; whitelist true/false) |
| 4 | Falsification attempt: "external unprivileged attacker can extract $0" | **NO COUNTER-EXAMPLE FOUND** — every permissionless function located either pays fixed, storage-bound recipients (FD1), is a pure state crank (pool.refreshVirtualPoolValue, SwychLY.startNewEpoch), or is self-funded; see §4. One theoretical residual (0-gasprice liquidation, bounded, practically un-includable) is described in §4.7. |

---

## 1. Claim 1 — PriceReporter dispatcher (independent re-derivation)

### 1.1 Code & hashes (block 127,275,294, publicnode)

| Contract | Size | keccak(code) |
|---|---:|---|
| PR1 `0x1CB9992c13Ac8de4d14661e7d05b3DB178b70dC5` | 4,647 B | `0xc5a3f78126abf1d48c05c002eacab39082f68d092e60a1c25c3af23a5226d40a` |
| PR2 `0x161BddB95C079AE14F6EE85A246E106D1a00143d` | 4,102 B | `0xa2e10ca539edd25f824abb0da67a62224385554735b2b3baea969853ea3afdea` |

### 1.2 Dispatcher table (own parser `raw/parse_dispatch.py`, decoding EVM PUSH payloads)

Both contracts expose the **same 11 selectors** (binary-search dispatcher, `GT` pivot at 0x5efa519d):

| selector | jumpdest | resolved name | gate (probed, §1.4) |
|---|---|---|---|
| 0x044ad7be | 0xae | `isReporter(address)` | view |
| 0x07b99f37 | 0xe6→0x1af | `executeSwapOrders(uint256[])` | `require(isReporter[msg.sender])` |
| 0x5bf9ac5b | 0xfb→0x2a2 | `postPriceAndExecuteOrders(address[],uint256[],uint256[])` | `require(isReporter[msg.sender])` |
| 0x5de5c212 | 0x10e→0x403 | `removeReporter(address)` | `onlyOwner` |
| 0x5e02cb7d | 0x121 | `reporters(uint256)` | view |
| 0x5efa519d | 0x14c | `getReporterCount()` | view |
| 0x715018a6 | 0x15d | `renounceOwnership()` | `onlyOwner` |
| 0x8da5cb5b | 0x165 | `owner()` | view |
| 0x93a91e33 | 0x176→0x5db | **`checkForExecutableOrders(address[],uint256[],uint256[])`** (resolved via 4byte; parent: "unknown batch fn") | `require(isReporter[msg.sender])` |
| 0xdd8755f2 | 0x189→0xa11 | `addReporter(address)` | `onlyOwner` |
| 0xf2fde38b | 0x19c→0xb47 | `transferOwnership(address)` | `onlyOwner` |

Gate bytecode at e.g. 0x5db (checkForExecutableOrders) and 0x1af (executeSwapOrders), identical in both
contracts: `CALLER → (slot 0, slot 1) keccak256 → SLOAD → 0xff AND → JUMPI`, else revert with
`Error(string)` 0x08c379a0 + "PriceReporter:unauthorized".

*Fallback* at 0xa9: `JUMPDEST; PUSH1 0x00; DUP1; REVERT` — a **bare empty revert**; no delegatecall, no
receive/fallback logic. Prologue has the standard `CALLVALUE==0` guard → every entry is nonpayable.

### 1.3 Call-constant scan (whole runtime, `raw/scan_push4.py`)

`0x7e498c81` (`executeOrder`), `0x04358662` (`executeSwapOrder`), `0x5cdb595c` (`postPrices`) appear only as
inline PUSH4 constants (e.g. `16 63 04358662 84 84`, `90 63 5cdb595c 90 …`) used to build *outgoing* calls
(0xa85c38ef = `orders(uint256)` on the OrderManager is another such constant). They are **not** dispatcher
entries in either contract.

### 1.4 eth_call probe matrix (raw: `claim1_probes_PR1.txt`, `claim1_probes_PR2.txt`)

Callers: random `0x1111…1111`, PR1 owner EOA `0x9958e5A78F53e58233fB175f1A6F45F22d3d4C48`, whitelisted
reporter `0x2E7B39eF3ea1A2023f21FA6c1D314e2111bD597F`.

| probe | from RANDOM | from OWNER | from REPORTER |
|---|---|---|---|
| `postPriceAndExecuteOrders([],[],[])` | revert `PriceReporter:unauthorized` | — | **returns `0x` (succeeds)** |
| `executeSwapOrders([])` | revert `PriceReporter:unauthorized` | — | **returns `0x`** |
| `checkForExecutableOrders([],[],[])` | revert `PriceReporter:unauthorized` | — | revert custom error `ExecutableOrders([],[])` (normal logic reached) |
| `executeOrder(1,rand)` (0x7e498c81) | revert **empty data** | revert **empty data** | revert **empty data** (blockrazor: `data:"0x"`) |
| `executeSwapOrder(1,rand)` (0x04358662) | revert empty | revert empty | revert empty |
| `postPrices([],[])` (0x5cdb595c) | revert empty | revert empty | revert empty |
| random selector `0xdeadbeef` | revert empty | — | — |
| `addReporter(rand)` | `Ownable: caller is not the owner` | — | — |

The empty-data reverts are byte-identical to the unknown-selector control ⇒ those three selectors are not
dispatched **for any caller, including the owner and whitelisted reporters**. The reporter "positive
controls" prove the three real entries execute once the whitelist gate passes. Cross-replicated on
blockrazor (`raw/cross_rpc_check.txt`).

### 1.5 Live roles (latest at 20:35Z / re-checked on blockrazor)

- PR1: `owner()` = `0x9958e5a78f53e58233fb175f1a6f45f22d3d4c48` (EOA); `getReporterCount()` = 3;
  `reporters(0..2)` = `0x2E7B39eF3ea1A2023f21FA6c1D314e2111bD597F`, `0x75cE0c34DB3B81c661ce9E4b77533E09245A0497`,
  `0x6f369f5d140ab49c587090069F03D8002D8D96a4`; `isReporter(0x1111…1111)` = false.
- PR2: `owner()` = **`0x719A28638aa1326aD8848DA222c665e387e12E50` = the Gnosis Safe**; same 3 reporters.

---

## 2. Claim 2 — OrderManager & the 8 pending orders

### 2.1 Executor

- OM `0x092D00a4965A6336c9C52BDf522b012C2DD42DCe` is a 2112-B minimal proxy (same codehash as the Pool
  proxy); EIP-1967 slot → impl **`0xC8BA536029bA07B8422E6FC555A5ab8a4ECe7e10`** (verified source),
  admin slot → `0x1078…c35a`.
- `executor()` = **`0x1CB9992c13Ac8de4d14661e7d05b3DB178b70dC5` (PR1)** (publicnode + blockrazor).
- Verified source: `executeOrder(uint256,address)` is `external nonReentrant onlyExecutor`;
  `_validateExecutor` ⇒ `require(_sender == executor, "OrderManager:onlyExecutor")`.
- Probes: from RANDOM → revert `OrderManager:onlyExecutor`; from PR1 → past the modifier → revert
  `OrderManager:orderNotExists` (order 1 gone). Exact revert data captured in `raw/claim3_lp.txt`.
- `placeOrder` / `placeTpslOrder`: `external payable nonReentrant`, **no access modifier**; funds the order
  only from the caller (`safeTransferFrom(msg.sender,…)` for tokens, `msg.value` for ETH/WETH, min fee
  0.0025 BNB observed as `minPerpetualExecutionFee() = 2500000000000000`). `cancelOrder`/`_cancelOrder`
  refund only `order.owner` (`require(order.owner == msg.sender || isCancelingTpsl)`), `cancelTpslOrders`
  is `msg.sender == pool`, `receive()` is `msg.sender == weth`. `nextSwapOrderId()` = 1 ⇒ zero swap orders.

### 2.2 The 8 pending orders (`orders(uint256)` + `requests(uint256)`, raw `claim2_orders.txt`)

`Order` struct = (pool, owner, indexToken, collateralToken, payToken, expiresAt, submissionBlock, price,
executionFee, triggerAboveThreshold); `requests` = (side, sizeChange, collateral, updateType).

| id | owner | indexToken | collateral/payToken | side | updateType | expiresAt | executionFee |
|---|---|---|---|---|---|---|---|
| 429 | 0xa6D6783E521513c829EE60eeD3Df33236f4A573f | WBNB | WBNB | 0 LONG | 1 DECREASE | 0 (limit) | 2.5e15 |
| 3073 | 0x6Dc5709032591085423638d6FAa0778414204EE2 | WBNB | WBNB | 0 LONG | 1 DECREASE | 0 | 2.5e15 |
| 3198 | 0x1DCb7879c4D213CB57042C9eE20E6D27ED098ba0 | WETH | WETH | 0 LONG | 1 DECREASE | 0 | 2.5e15 |
| 3233 | 0x710F1e6C7d1186F18B2A65C5636a19c3D16519Cc | SOL | USDT | 1 SHORT | 1 DECREASE | 0 | 2.5e15 |
| 3394 | 0xd5CD3a7e913c7453860aDAe68B7ab7a53Aba2650 | WETH | WETH | 0 LONG | 1 DECREASE | 0 | 2.5e15 |
| 3423 | 0x4DA48596773EE4C78C12B9D0aF130634731AA902 | WBNB | USDT | 1 SHORT | 1 DECREASE | 0 | 2.5e15 |
| 3633 | 0x360C4ddbdFDB4b6c72E907099F87156ab9dee706 | BTCB | BTCB | 0 LONG | 1 DECREASE | 0 | 2.5e15 |
| 4071 | 0x20441aF9ef92365EfbC2fC793f16eE14D8B8FC2A | WBNB | WBNB | 0 LONG | 1 DECREASE | 0 | 2.5e15 |

All 8 are pending (`orders(id).owner != 0`) limit DECREASE orders; each escrows only its 2.5e15 BNB fee.
Spent ids are deleted: neighbours 428/430, 3072/3074, 3232/3234, 4070/4072 and samples 1000/2000/3000/4000/4316
all have owner = 0 (`raw/claim2_neighbors.txt`). `nextOrderId()` = 4317, `nextSwapOrderId()` = 1.
OM native balance = **0.02 BNB = exactly 8 × 0.0025** — the 8 escrowed fees (owner-refundable only).

### 2.3 Position keys & zero-size check (`raw/claim2_positions.txt`)

Position key = `keccak256(abi.encode(owner, indexToken, collateralToken, uint8(side)))` — confirmed from the
verified Pool source (`getPositionKey` uses `abi.encode(_owner,_indexToken,_collateralToken,_side)`,
`enum Side {LONG, SHORT}`) and cross-checked **on-chain**: for every one of the 8 orders my local
`cast keccak(abi-encode…)` equals `pool.getPositionKey(...)` (TRUE × 8).

`pool.positions(key)` (6-field struct (size, collateralValue, reserveAmount, entryPrice, borrowIndex,
lastIncreasedTime)): **(0,0,0,0,0,0) for all 8** owners. ⇒ No position exists, no decrease can execute,
and no execution fee is claimable by executing any of these orders. (Initial probe with a bool-encoded key
was wrong and returned zeros for an unrelated slot — the correct uint8 encoding was derived and
chain-cross-checked; see raw file history.)

---

## 3. Claim 3 — LP token TR1

Raw: `claim3_lp.txt`; cross-RPC: `cross_rpc_check.txt`.

| read | value |
|---|---|
| TR1 `name()/symbol()/decimals()` | `"Tranche One"` / `"TR1"` / 18 |
| `totalSupply()` | `95914522923439084299355` (95,914.522923439084299355) |
| `balanceOf(0x9A6A5Aed7e4F4454AA89517AFdbBaE9EAD0FA59a)` | `95914522923439084299355` — **equals totalSupply exactly** |
| `balanceOf(0x1111…1111)` / `balanceOf(0x0)` / `balanceOf(pool)` | 0 / 0 / 0 |
| `pool.lpToken()` | `0x03F9B914f605d732dd7d5B57e6B494be8d44b28A` |
| `pool.isLiquidityProvider(0x9A6A…a59a)` | **true** |
| `pool.isLiquidityProvider(0x1111…1111)` | **false** (also false for PR1) |
| LPT `minter()` | the Pool `0xF86f…802d`; `mint(rand,1e18)` from random → `LPToken: !minter` |

All values re-confirmed on blockrazor. 100% supply concentration is proven by balance == totalSupply
(any other holder ⇒ supply > balance).

---

## 4. Falsification sweep — "can ANYTHING pay an unprivileged attacker?"

### 4.1 Pool `0xF86f…802d` (verified source + probes, raw `pool_probes.txt`, `pool_roles.txt`)

| function | gate | probe from RANDOM |
|---|---|---|
| `addLiquidity` / `removeLiquidity` | `isLiquidityProvider[msg.sender]` | `NOT_AUTHORIZED` |
| `swap` | `msg.sender == orderManager \|\| isLiquidityProvider` | `NOT_AUTHORIZED` |
| `increasePosition` / `decreasePosition` | `onlyOrderManager` | `OrderManagerOnly` |
| `withdrawFee(address,address)` / `distributeSurplus()` | `msg.sender == feeDistributor` | `FeeDistributorOnly` |
| `liquidatePosition` | `tx.gasprice <= maxLiquidationGasPrice(==0) \|\| authorizedLiquidators[msg.sender]` | `PositionNotLiquidated(key)` (passes gas gate under eth_call default gasprice 0; see §4.7) |
| `refreshVirtualPoolValue()` | **none** | returns `0x` — writes cached `virtualPoolValue` only; source read: no transfers |
| `initialize` | `initializer` | `Initializable: contract is already initialized` |
| all `set*` (liquidityProvider/lpToken/oracle/orderManager/feeDistributor/…), `addToken`, `delistToken`, `setTargetWeight` | `onlyOwner` | `Ownable: caller is not the owner` (spot-checked) |

### 4.2 OrderManager — see §2. Only self-funded `placeOrder`/`placeTpslOrder`; everything else gated.
`receive()` reverts for non-WETH senders.

### 4.3 Oracle `0xe4460109425EbC1CE34cAd59Ab7ce60535956BF5` (verified ABI + probes, raw `lpt_hook_oracle_probes.txt`)

`postPrices` from random → `PriceFeed:unauthorized`; `addReporter` / `configToken` /
`setPriceFeedErrorSpread` from random → `Ownable`; remaining functions are views. `owner()` = Safe.
No function transfers value to the caller. (`getReporterCount()` = 2, `isReporter(rand)` = false.)

### 4.4 FeeDistributor #1 `0x7c57c2F579175570E23CCc8C3C26723beD50D6b1` (unverified; own dispatcher parse)

- Dispatched: `owner`, `paused`, `pool`, `totalWeight`, `feeTokens(uint256)`, `setFeeTokens(address[])`,
  `setSplits(uint256×4)`, `setAddresses(address,address,address)`, `pause`, `unpause`, `withdrawFee()`,
  **unresolved `0xb069bec2()` (= the parent's `distribute()`)**, `transferOwnership`, `renounceOwnership`.
- **Permissionless triggers:** `withdrawFee()` and `0xb069bec2()` both return `0x` from a random caller.
  Neither takes an address argument; recipients/weights are **fixed storage** (slots 8/9/10 =
  `0x9bae46b159f0ce7ef40b6f3a932dff3d5b01d3f5`, slots 4–7 = 50/35/10/5, `raw/fd_storage.txt`).
- Local anvil fork measurement (`raw/fd_trigger_anvil.txt`): `FD1.withdrawFee()` from RAND moved exactly
  **0.611937748191841578 WETH Pool → FD2**; **RAND WETH delta 0**, BNB only − gas. Same recipient routing
  as the parent's CI fork test.
- `setSplits` / `setFeeTokens` from random → `Ownable`. FD1 token balances = 0 (nothing parked).
- ⇒ Public "poke" that performs housekeeping to protocol addresses; zero attacker payout.

### 4.5 FeeDistributor #2 `0x9bae46b159f0ce7ef40b6f3a932dff3d5b01d3f5`

`getRecipients()` = `(0, [])` (no recipients); **`distributeTreasury(uint256)` from random → `Ownable`**
(not permissionless); `setRecipient`/`removeRecipient` → `Ownable`; balances 0. Fees routed here from
FD1 dead-end at a Safe-owned contract (P/S, no attacker payout).

### 4.6 LP token, PoolHook, SwychLY

- LPT: standard ERC20 dispatcher + `mint` (Pool-only, verified), `burn`/`burnFrom` (own balance only).
- `PoolHook 0x91d09810f1f03cEb4Eb343c46741D7CD58eE0c06`: callbacks `postIncreasePosition`,
  `postDecreasePosition`, `postSwap`, `postLiquidatePosition` all revert `PoolHook:!pool` from random;
  hook holds 0 of the 5 pool tokens and 0 BNB; owner = Safe.
- `slToken()` = `0xd6624102503252Cb06C1fBb4d3b1AA6eE9A072ca` ("SwychLY", ERC-1155-style rewards token via
  ERC-1967 proxy, impl `0xeab7eaca…d59a`, admin = ProxyAdmin, owner = EOA `0x9958…`):
  `mint`/`mintBatch` from random → `NOT_AUTHORIZED_OPERATOR`; `transfer` → `TRANSFER_NOT_ALLOWED`;
  `setAuthorizedOperator` → `Ownable`; **`startNewEpoch()` is permissionless** (returns `0x`).
  Anvil fork simulation from a funded random EOA (`raw/slt_startepoch_anvil.txt`): epoch 249 → 250,
  caller's SwychLY balances ids 0–5 stayed 0, caller paid gas only. ⇒ state crank, not a payout.

### 4.7 Theoretical residual found (recorded, not an exploit in practice)

`Pool.liquidatePosition`'s first check is `require(tx.gasprice <= maxLiquidationGasPrice || authorizedLiquidators[msg.sender])`
with `maxLiquidationGasPrice = 0`. A transaction with **`tx.gasprice == 0`** therefore passes the auth gate
(eth_call defaults gasprice to 0, which is how this was observed). If (a) such a tx were includable on BSC
(validators' min-gas-price policy makes this practically impossible), and (b) a liquidatable position
existed, the caller could set `_feeTo` to itself and collect only the flat **liquidationFee ($5)** —
bounded by the pool config and by the number of liquidatable positions (2 open longs remain per
`trancheAssets`). This is a ≤ ~$10 theoretical residual with infeasible inclusion requirements; it does not
change the E-U verdict. (Parent wording says "impossible" for `tx.gasprice <= 0`; precisely, it is
*constructible* but not practically includable.)

### 4.8 Value confirmation (block 127,278,786) — still funded

Pool balances match the parent exactly: WETH 20.842379618035697515 (feeReserve 0.611937748191841578),
WBNB 37.150871497710826464 (15.159579304772341462), BTCB 0.126101726965759641 (0.117771851974191369),
USDT 65,233.020593781079845094 (7,439.730564749984644274), SOL 255.174744469221813216
(0.946732894963395550). Nothing was drained since the parent's snapshot; all paths remain gated.

---

## 5. Discrepancies / corrections vs the parent

1. **"Identical twin" is inaccurate (Claim 1 scope).** PR2 `0x161B…143d` is **4,102 bytes** vs PR1 4,647
   (codehash differs) and its `owner()` is the **Gnosis Safe `0x719A…2e50`**, not the EOA
   `0x9958e5A7…`. The exposed selector table (11 entries), call-constants, fallback and gating behaviour
   are identical in both; the difference does not weaken the $0 conclusion (PR2 is, if anything, more
   privileged).
2. **0x93a91e33 resolved**: it is `checkForExecutableOrders(address[],uint256[],uint256[])` (reporter-gated;
   positive control reverts with custom error `ExecutableOrders([],[])`), not merely an "unknown batch
   function".
3. **`liquidatePosition` wording**: parent says the gasprice path is "impossible"; precisely it is
   `tx.gasprice <= 0`, i.e. exactly-0 passes the require and is constructible but practically
   un-includable. Bounded theoretical residual in §4.7.
4. `FD1.totalWeight()` currently reads 0 while the stored split weights are 50/35/10/5 (slots 4–7) —
   cosmetic, no impact; the two permissionless FD1 triggers are confirmed.
5. Everything else re-derived matched the parent's numbers exactly (pool balances/allowances, fee reserves,
   TR1 supply/holder, order ids/owners/escrow, reporter/owner/executor addresses, `nextOrderId` 4317,
   `nextSwapOrderId` 1).

---

## 6. Bottom line

An independent bytecode-level and live-state re-derivation confirms all three headline claims, with one
descriptive correction ("identical twin" PR2 differs in code size and owner — it is owned by the 5-of-7
Gnosis Safe). The PriceReporters expose exactly 11 selectors, only three of which are state-changing and
all three are `isReporter`-gated; the three execution selectors (`executeOrder`, `executeSwapOrder`,
`postPrices`) are provably not dispatched — they revert with empty data even for the owner and for
whitelisted reporters. The OrderManager accepts `executeOrder` only from PR1 (probed both directions) and
all eight pending orders belong to owners whose positions are provably zero-size (position keys
chain-cross-checked; OM holds exactly the 8×0.0025 BNB escrow). TR1 supply is 100% held by the whitelisted
EOA. A falsification sweep over Pool, OM, Oracle, both FeeDistributors, LP token, PoolHook and the SwychLY
rewards token found no permissionless function that transfers value to `msg.sender` or an
attacker-chosen address: the only permissionless calls are fixed-recipient fee pokes (FD1, fork-measured
attacker delta 0), pure state cranks (pool.refreshVirtualPoolValue; SwychLY.startNewEpoch — fork-measured
caller payout 0), and self-funded order placement. The parent's overall conclusion
**"external unprivileged attacker can extract $0" stands** (confidence: high), with one bounded
theoretical residual: a 0-gasprice `liquidatePosition` tx (practically un-includable on BSC) could at most
collect ~$5/liquidatable position, far from the $182.9k of pool custody.

---

## 7. Evidence index (all under `raw/`)

| file | contents |
|---|---|
| `parse_dispatch.py`, `scan_push4.py` | parsers used (own code) |
| `PR1_code.hex`, `PR1_disasm.txt`, `PR1_dispatcher.txt`, `PR1_push4.txt` | PR1 bytecode + dispatcher + constant scan |
| `PR2_code.hex`, `PR2_disasm.txt`, `PR2_dispatcher.txt`, `PR2_push4.txt` | PR2 same |
| `codes.txt`, `block.txt`, `block-meta.json` | code sizes/hashes; pinned block 127,275,294 |
| `selectors_4byte.txt`, `LPT_selectors.txt`, `HOOK_selectors.txt`, `SLT_selectors.txt`, `SLT_impl_selectors.txt`, `fd_selectors_4byte.txt` | selector → signature resolutions |
| `claim1_roles.txt`, `roles_raw.txt`, `claim1_probes_PR1.txt`, `claim1_probes_PR2.txt`, `cross_rpc_check.txt` | PR roles + full probe matrices (publicnode & blockrazor) |
| `om_roles.txt`, `claim2_orders.txt`, `claim2_positions.txt`, `claim2_neighbors.txt` | OM getters; 8 orders + requests; position keys ↔ chain keys ↔ positions; spent-id neighbours |
| `claim3_lp.txt`, `lpt_hook_oracle_probes.txt` | TR1/LPT/mint gate; hook callback gate; oracle gates |
| `pool_roles.txt`, `pool_probes.txt`, `pool_balances_now.txt`, `native_balances_now.txt` | Pool roles/gates/balances at block 127,278,786 |
| `fd_probes.txt`, `fd_storage.txt`, `fd_balances.txt`, `fd_trigger_anvil.txt` | FD1/FD2 gates, storage recipients, fork-measured WETH routing (attacker delta 0) |
| `slt_probes.txt`, `slt_hook_balances.txt`, `slt_startepoch_anvil.txt`, `slt_startepoch_calltrace.json` | SwychLY token gates + startNewEpoch fork measurement |
| `OM_impl_abi.json`, `POOL_impl_abi.json`, `ORACLE_abi.json`, `OM_impl_sourcecode.json`, `POOL_impl_sourcecode.json`, `OM_src/`, `POOL_src/` | verified ABIs/sources (Etherscan V2, chain 56) |
| `ethcall.sh` | raw eth_call helper |
| `output/56/0xeab7…/abi.json` | heimdall partial output (auxiliary) |
| `../ref-parent/` | verbatim copy of parent's analysis/README/summary as of 21:35 (leads only) |

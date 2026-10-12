# SheepDex (BSC) — L2 Phase-2 deep-dive: live extraction assessment

**Date:** 2026-10-12 · **Chain:** BNB Smart Chain (56) · **Status:** read-only; PoC fork-verified only; no mainnet transactions; no secrets.

**Triage row:** `l2-triage-a` → SheepDex, LIVE-FUNDED, $426,469 (medium confidence, "v3 pool set not independently verified").
**Phase-2 answer:** the triage figure is confirmed on-chain (**$428,442** at block 127,099,664 across 81 pools), but **essentially none of it is extractable by an external unprivileged attacker today** (measured: ≈ **$0.002** total in dust arbitrage). The value splits into **holder-recoverable LP positions ($379,110)** and **operator-only protocol fees ($48,500)**.

---

## 1. TL;DR table

| Target | Live value | Extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|---|
| 81 SpePool UniV3-fork pools (`SpeFactory` 0x571521f8…cbdf) | **$428,442** | **$0.002** (dust) | Pool math is logic-identical to canonical Uniswap v3-core; the only non-standard swap input (`swapFee(recipient)`) is an operator-set fee **discount** (never set); the good-token balances are dominated by protocol fees + LP accrued fees, so swaps can only reach a razor-thin tradeable layer | If a custom `swapFee` were set for an attacker-reachable recipient, swaps would be cheaper for that recipient only — no extraction |
| LP positions (34,591 NFTs at `NFTPositionManager` 0x754ca67e…6628) | $379,110 (H-O) | $0 | Standard UniV3 periphery; `decreaseLiquidity`/`collect`/`burn` gated by `isApprovedOrOwner`; only NFT holders can claim | NFT holders may stay dormant → value remains claimable indefinitely (no deadline) |
| Protocol fees inside pools | $48,500 (P) | $0 | `collectProtocol` gated by `onlyFactoryOperator` = EOA `0x1efd11d3…E1ED` (last tx 2024-07-30); director setters revert for attackers (fork-verified) | If the operator key is lost, fees become stuck (S) |
| Zero-liquidity pools' excess balances | $832 (S) | $0 | Pools with `liquidity()==0`: no positions to burn; excess over `protocolFees` is donations (unclaimable) | — |

**Total live extractable now (external unprivileged): ≈ $0.002 — confidence: high.**
(All figures net of swap fees; not net of gas — the measured dust profits would not cover gas.)

---

## 2. The target in exact terms

- **Factory:** `SpeFactory` at `0x571521f8c16f3c4ed5f2490f19187ba7a5a3cbdf` (BSC), deployed at block 11,641,289; Solidity 0.7.6; verified source recovered (Etherscan V2 + Sourcify). A UniV3-core fork branded "SheepDex" (`@sheepdex/core`, NFT collection "Sheep Dex Positions NFT" / "SPC-POS").
- **Director:** `SwapDirector` at `0x82c0C5c2722D511205D1A290490ebAf9940941E5` (owner EOA `0xAc80034e…CA3E`, operator EOA `0x1efd11d3…E1ED`). `factory.operator()` delegates to `swapDirector.operator()`.
- **Periphery:** `NFTPositionManager` at `0x754ca67efd5951960c43dd78063277ec50a86628` (Sourcify full match) — canonical UniV3 NonfungiblePositionManager port (WBNB instead of WETH).
- **Pools:** **81** enumerated exhaustively via full `PoolCreated` log scan (blocks 11,641,289 → 15,824,303; all created in 2021; fee tiers 0.1 %/0.2 %/0.5 % with tickSpacing 20/40/100). No pools created since block 15,824,303.

### Non-standard code vs canonical v3-core (normalized diff, all libraries)

1. **`swapFee(address recipient, uint24 fee)`** — in `SpePool.swap`, the fee used by `SwapMath.computeSwapStep` is looked up **by the swap's `recipient` parameter** from `SpeFactory._addressFees`, falling back to the pool's immutable fee. `SpeFactory.setFee` is `msg.sender == swapDirector.operator()` gated, `_fee ∈ (0, 3000]`. No custom fee has ever been set (`setFee` selector `0xba364c3d` absent from the factory's full tx history; `swapFee(addr, 2000) == 2000` for sampled addresses). Even if set, it is a per-recipient **fee discount/override**, not an accounting break: `computeSwapStep` remains self-consistent and the pool's IIA balance check always collects the charged input.
2. **`collectProtocol(address token)`** — non-standard signature. When `token != token0 && token != token1`, it transfers the **entire balance of that arbitrary token** held by the pool to `msg.sender`. Gated by `onlyFactoryOperator` (no `lock` modifier needed). This can only sweep third-party tokens accidentally held by a pool, by the operator.
3. **Initial `feeProtocol = 34`** (2/2) in the pool constructor (canonical: 0), and `setFeeProtocol` allows `>= 2` (canonical: `>= 4`). Live pools show `feeProtocol` 34 (2/2) or 85 (5/5): the protocol takes 1/2 or 1/5 of swap fees.
4. **`flash()` fee is flat 0.15 %** (`1.5e3/1e6`) instead of the pool fee.
5. Everything else — `SwapMath` (incl. merged `SqrtPriceMath`), `Tick`, `TickBitmap`, `Position`, `Oracle`, `SafeCast`, `TransferHelper` — is logic-identical to Uniswap v3-core `v1.0.0` (verified by token-level normalized diff; only renames `SwapMath.*`/`Const.Q128` and file organization differ).

**No exploitable math or accounting deviation was found in the pool, factory, or periphery.**

---

## 3. Live-state assessment (block 127,099,664 for balances/pricing; fork tests at 127,111,557)

| Item | Value |
|---|---|
| Total value in 81 pools | **$428,442** (DefiLlama live $426,469–$427,015; difference = price source/block) |
| Protocol fees (`protocolFees` summed, priced) | **$48,499.82** (11.3 % of all value) |
| LP-claimable (pools with `liquidity>0`) | **$379,109.94** |
| Stuck excess in `liquidity==0` pools | **$832.28** |
| Pools with `liquidity>0` | 51 of 81 |
| Position NFTs outstanding (`totalSupply`) | **34,591**, held by **1,934 distinct addresses** (full ERC721 Transfer reconstruction: 118,443 events) |
| Manager contract holdings | $0.000002 (one dust token; `sweepToken` is permissionless) |
| Largest pools | BTCB/BUSD $219,652 · ETH/BUSD $93,931 · USDT/WBNB $33,335 · WBNB/BUSD $26,845 · USDC/WBNB $20,592 · ETH/WBNB $19,893 |
| Live activity | 4,993 swaps in the last ~5M blocks (bots, mostly $20–160 trades); major pairs track market within fees |
| Roles | factory: no owner; `operator()` = EOA `0x1efd11d3…E1ED` (nonce 523, last tx **2024-07-30**, block 40,923,865, interacts with PancakeSwap/CAKE/USDT) · director owner = EOA `0xAc80034e…CA3E` (nonce 12) · deployer EOA `0x2e42401b…433e` |
| Custom fees | none (`setFee` never called; `swapFee` returns defaults) |
| Third-party tokens in pools | not material; any such sweep is operator-only |

### Where the value actually sits

- **Protocol fees dominate the good-token side of several pools** — e.g. ETH/WBNB: $19,527 of $19,893 is protocol fees; ETERNAL pool: 0.11229 of 0.11363 WBNB; CAKE pool: 0.00500 of 0.02248 WBNB. The remaining balances are LP principal + LP accrued fees (claimable only by the NFT holders).
- This is exactly why arbitrage extraction is dust: a swapper can only take the **principal** of positions whose ranges are crossed; accrued LP fees and protocol fees are not reachable by swapping.

---

## 4. What an attacker can / cannot do (exact call paths)

**Can (permissionless, no privileges):**
- `SpePool.swap(...)` — pays input, receives output at the pool's price. Measured: all non-trivial routes lose money (see §5).
- `SpePool.flash(...)` — borrows for 0.15 %, must repay; no value.
- `SpePool.mint/burn/collect` — only for positions you own/pay for.
- `NFTPositionManager.sweepToken/unwrapWBNB/refundETH` — permissionless, but the manager holds no material balance.
- `SpeFactory.createPool(tokenA, tokenB, fee)` — permissionless pool creation (no value).
- Minting a pool position for any `recipient` (you pay; gifting only).

**Cannot (verified reverting for an unprivileged caller, `eth_call` + fork PoC `test_access_gates`):**
- `SpePool.collectProtocol(token)` — `onlyFactoryOperator` (reverts for attacker).
- `SpePool.setFeeProtocol(a,b)` — `onlyFactoryOperator`.
- `SpeFactory.setFee(addr,fee)` — operator only.
- `SwapDirector.setOperator/transferOwnership/setFeeAmountTickSpacing` — owner only.
- `NFTPositionManager.decreaseLiquidity/collect/burn` on someone else's NFT — `isApprovedOrOwner`.

**Costs:** gas only for the dust routes; no flash-loan dependence (the dust paths are self-funded trivially).

---

## 5. PoC / fork-verification

Foundry project: `poc/` (vendored forge-std). CI runs on `kingmariano/ca-zombie-ci` with a **local anvil fork** of BSC (pinned ~100 blocks back; `ci/run.sh` starts it and exports `LOCAL_FORK_URL`) — this fixed load-balanced-RPC replica lag seen in the first run.

| Test | Result (block 127,111,557) |
|---|---|
| `test_internal_eth_triangle` (BUSD→ETH→WBNB→BUSD) | **negative at every size**: −26 % at 1 BUSD → −99.999 % at 10,000 BUSD (price impact: the ETH/BUSD pool moves +42 % on a 1 BUSD buy) |
| `test_external_eth_vs_pancake` (buy ETH on SheepDex, sell on PancakeSwap) | negative at every size (−20 % at 100 BUSD → −30 % at 16,000) |
| `test_external_btcb` (sell BTCB into SheepDex, buy back on PancakeSwap) | negative at every size (−7.5 % at 0.001 BTCB) |
| `test_external_xvs` (buy XVS on PancakeSwap, sell into SheepDex) | negative at every size (−47 % at 0.001 WBNB) |
| `test_internal_alpaca` (cross-pool) | **best +33,798,119,328 wei = +$0.000025** at 1e-6 WBNB; negative at all larger sizes |
| `test_internal_spc` (cross-pool) | **best +1,906,072,886,533,123 wei = +$0.0019** at 0.01 BUSD; negative at ≥ 0.1 BUSD |
| `test_external_cake` (buy CAKE on PancakeSwap, sell into SheepDex) | positive only at micro sizes: **+216,973,004 wei = $0.00000016 best** (at 1e8 wei input); negative/reverts at ≥ 1e12 wei (price crashes to the tick floor) |
| `test_external_eternal` | positive only at micro sizes: **+243,109,025,831 wei = $0.00000018 best** (at 1e10 wei input); reverts at ≥ 1e12 wei (price crashes to the ceiling) |
| `test_flash_selfcontained` (flash-borrow BUSD from a pool, run ETH triangle) | all reverts — repay not covered (route loses money) |
| `test_access_gates` | `collectProtocol`, `setFee`, `setOperator`, `setFeeProtocol` **all revert for an unprivileged caller** (4/4) |
| `test_swap_fee_default` | `swapFee(bot, 2000) == 2000` — no custom fee |
| `test_negative_woo` (control) | −0.0015 WBNB (as expected, no edge) |

**Total measured positive E-U across all routes: $0.0020.**

**CI runs (12/12 PASS, block 127,113,332):**
- final green suite: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38187176117
- anvil-fix run (8/10): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38186340859
- first run (RPC replica lag, superseded): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38184917146

Artifacts in `ci-artifacts/`, logs in `ci-log.txt`.

---

## 6. Verdict and residual / latent risk

- **E-U = $0.002 (dust)** — confidence **high**. The pools' tradeable liquidity is thin and their good-token balances are overwhelmingly protocol fees + LP accrued fees; no permissionless path reaches them.
- **H-O = $379,110** — 34,591 position NFTs across 1,934 holders can `decreaseLiquidity`+`collect` (or `burn`) at any time; no deadlines. Value is claimable indefinitely.
- **P = $48,500** — protocol fees collectible only by operator EOA `0x1efd11d3…E1ED`. The EOA was active until 2024-07-30; **if the key is inaccessible this becomes S**.
- **S = $832** — excess balances in `liquidity==0` pools (donations), plus wei dust.
- **Latent risks worth noting (not live E-U):**
  - If the operator ever calls `setFee(addr, f)` for a recipient reachable by an attacker, that recipient's swaps get a fee override (max 0.3 %) — a discount, still no extraction.
  - If the operator key is used, `collectProtocol(token)` can also sweep *any third-party token* accidentally held by a pool (arbitrary-token sweep). Today no pool holds material third-party tokens.
  - Live bots keep the major pools near market; the pools' price oracle (`observe`) remains functional but is unused by any live integrator we could find.

**Blockers / caveats:** operator key liveness is unknowable; LP-claimability assumes holders can transact (many positions are dust); USD figures are DefiLlama-priced at the stated block; dust profits do not cover gas.

---

## 7. Methodology & sources

- **Enumeration:** full-range `eth_getLogs` `PoolCreated` scan on the factory (keyed Ankr RPC; range-splitting for public nodes) → 81 pools; `pools.json`.
- **State:** direct `eth_call`/`balanceOf` reads of all 81 pools at block 127,099,664 (balances, `liquidity`, `slot0`, `protocolFees`, `feeProtocol`) → `pools-state.json`, `pool-values.json` (DefiLlama prices).
- **Activity / ownership:** adaptive log scans (Swap/Mint/Burn/Collect, 118,443 ERC721 Transfer events) → `events-*.json`, `nft-holders.json`.
- **Source verification:** Etherscan V2 `getsourcecode` (SpeFactory, 89 KB flattened source incl. SpePool + all libs), Sourcify v2 (NFTPositionManager full match), token-level normalized diff vs Uniswap v3-core `v1.0.0`.
- **Privilege checks:** `eth_call` simulations with `from = attacker` for all setters; fork PoC `test_access_gates`.
- **External markets:** PancakeSwap V2 factory `getPair` + `getReserves` for every token (`token-markets.json`).
- **PoC:** Foundry fork tests at `poc/` run on GitHub Actions with a local anvil snapshot; artifacts in `ci-out/`, `ci-artifacts/`.

### Files index

```
sheepdex/
├── README.md                  # this file
├── summary.json               # machine-readable summary
├── analysis/
│   ├── pools.json             # 81 pools (PoolCreated scan)
│   ├── pools-state.json       # live state (balances, liquidity, slot0, protocolFees)
│   ├── pool-values.json       # + DefiLlama prices + per-pool USD
│   ├── token-markets.json     # PancakeSwap pair/reserves per token
│   ├── nft-holders.json       # current position-NFT holders (1,934)
│   ├── arb-candidates.json    # price-deviation screen
│   ├── events-swap-recent.json, events-mint-top.json, events-burn-top.json
│   ├── src-SpeFactory-raw.sol # verified factory+pool source (Sourcify/Etherscan)
│   ├── pm-src/NFTPositionManager.sol, pm-abi.json
│   ├── enumerate_pools.py, pool_state.py, value_pools.py, price_compare.py,
│   │   scan_events2.py, nft_holders.py, token_markets.py
├── poc/                       # Foundry project (src/ArbBot.sol, test/SheepDex.t.sol)
├── ci/run.sh                  # anvil snapshot setup for CI
├── ci-out/, ci-artifacts/, ci-log.txt
```

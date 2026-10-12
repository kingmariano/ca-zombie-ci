# Mobius Money (Celo) — junk-token depeg-arbitrage analysis

**Question:** can an unprivileged attacker acquire each pool's "junk" token cheaply on any live market and swap it into the Mobius pool for the good token at a net profit?

**Answer (headline):** A total of **≈ $0.10 of positive gross arbitrage** exists across all 12 pools today; **only pool `0x9f4adbd0…` (atUST/USDm) remains net-positive after gas at ≈ +$0.077 one-shot**, plus pool `0x02db089f…` (pUSD v1) at ≈ +$0.002. Every other pool is at or below zero and/or gas-negative because the junk markets are either drained to dust, absent, fairly priced, or already harvested continuously by arbitrage bots (some of which were active on these very pools on 2026-10-12).

- chain/network: Celo, chain-id 42220
- final state snapshot: **block 79,926,039** (~2026-10-12)
- keyless RPC used: `https://forno.celo.org` (cross-checked `https://celo-rpc.publicnode.com`)
- pool quotes: exact `calculateSwap(uint8,uint8,uint256)` calls on each pool (pools are verified `Mobius_*_Swap`, solc 0.6.12; `paused() == false` on all 12)
- market costs: exact UniV2 (`getAmountIn/getAmountOut`, 0.30% fee) on live reserves; Uniswap-V3 factory `getPool()` checked for every junk/base/fee combination
- gas: base fee **200 gwei**, observed effective gas price **202.5 gwei**; observed Mobius swap = **149,203 gas** (tx `0x3ea8ca81…`, block 66,122,045). Full attack (1–2 pair swaps + 1 approve + 1 pool swap) ≈ 300–400k gas ≈ **$0.006–0.008** at CELO $0.0942.
- valuation: USDm ≈ $1.0001, CELO $0.09416, EURm $1.1152, mcUSD $1.0001, mCUSD taken as $1.00 (conservative), Poof/MOBI per their shallow AMM markets.

**Market universe scanned on-chain (complete for these venues):** Ubeswap V2 factory `0x62d5b84be28a183abb507e125b384122d2c25fae` (882 pairs, all token0/token1 fetched), SushiSwap V2 factory `0xc35dadb65012ec5796536bd9864ed8773abc74c4` (257 pairs), Uniswap V3 factory `0xafe208a311b21f13ef87e33a90049fc17a7acdec` (`getPool` for every junk token × {USDm, CELO, EURm, USDCet} × {500, 3000, 10000}). Note: the parent-supplied Ubeswap factory `0x62d5b84e22fc28fe…` **has no code**; the real factory was taken from the router `0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121`'s `factory()`.

---

## Results table

| # | Pool | Junk side (idx1) | Good side (idx0) | Pool marginal (junk→good) | Market cost of junk | Max profitable size (gross optimum) | Gross $ | Net after gas $ | Confidence | Circular? |
|---|------|------|------|------|------|------|------|------|------|------|
| 1 | `0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae` | atUST | 39.42 USDm | **0.01461 USDm/atUST** | Ubeswap pair spot 0.00300 (reserve 0.0581 USDm) | **10.900 atUST** (cost 0.0750 → out 0.1588) | **+0.0837** | **+0.0775** | high | no |
| 2 | `0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c` | pUSD v1 | 330.41 USDm | **0.97611 USDm/pUSD** | Ubeswap pair spot 0.5623 (reserve 0.0782 USDm) | 0.03406 pUSD (cost 0.0254 → out 0.0333) | +0.0078 | +0.0016 | high | no |
| 3 | `0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735` | pUSD v2 | 0.96 USDm | 0.000158 USDm/pUSD | only via MOBI pair (pUSD side 0.0504; buying costs ≫ payout) | none profitable | ≈0 | negative | high | no |
| 4 | `0x382ed834c6b7dbd10e4798b08889eaed1455e820` | pEUR v1 | 26.78 EURm | 0.03722 EURm/pEUR | Ubeswap EURm pair reserves **1000/1003 wei** (dead) | none | n/a | n/a | high | no |
| 5 | `0x23c95678862a229fac088bd9705622d78130bc3e` | pEUR v2 | 10.33 EURm | 0.002923 EURm/pEUR | **no market anywhere** (Ubeswap/Sushi/V3) | none | n/a | n/a | high | no |
| 6 | `0x413ffcc28e6cdde7e93625ef4742810fe9738578` | pCELO v1 | 73.36 CELO | 0.16635 CELO/pCELO | POOF route (buy POOF with CELO → pCELO) | 2.9326 pCELO (cost $0.0414 → out $0.0457) | +0.0043 | −0.0019 | high | no |
| 7 | `0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a` | pCELO v2 | 1,367.01 CELO | 0.88638 CELO/pCELO | POOF pair (buy cost ≈ 0.99 CELO/unit) | 0.2499 pCELO | +0.00015 | −0.0060 | high | no |
| 8 | `0xcce0d62ce14fb3e4363eb92db37ff3630836c252` | USDC (Optics V2) | 3,741.08 USDm | **1.03663 USDm per USDC-old** (premium) | Ubeswap CELO pair: 0.1581 USDC / 1.4268 CELO | none profitable (best grid point −$0.0007) | −0.0007 | negative | high | no |
| 9 | `0xa5037661989789d0310ac2b796fa78f1b01f195d` | USDCet (Optics V1) | 24,427.11 USDm | 0.97727 USDm/USDCet | Ubeswap USDm pair spot 0.9892 (buy cost ≥1.03 with impact) | none profitable (best −$0.106) | −0.106 | negative | high | no |
| 10 | `0x0986b42f5f9c42feeef66fc23eba9ea1164c916d` | aaUSDC (Allbridge) | 280.15 USDm | 0.99193 USDm/aaUSDC | **no market anywhere**; Allbridge protocol paused in 2026 | none | n/a | n/a | high | no |
| 11 | `0xaefc4e8cf655a182e8346b24c8abce45616ee0d2` | WBTC baab (Optics V2) | 0.44484 d629-BTC | 1.7332 d629 per baab | mcUSD pair: 0.05039 baab locked against 3,896.4 mcUSD | route B only: 5.31e-5 d629 ($2.3) | +0.0021 | −0.0041 | medium | partially* |
| 12 | `0x19260b9b573569ddb105780176547875fe9feda3` | WBTC be50 (Optics V1) | 0.96578 d629-BTC | 1.6269 d629 per be50 | mcUSD pair 0.01552 be50; CELO pair 0.01336 be50 | none profitable | −0.00025 | negative | medium | partially* |

\* Pools 11/12 are part of the live price-discovery loop for the d629/baab/be50 "BTC triangle"; bots 0x3f5305C955…, 0xae6D7D47…, 0xD87D4843… were cycling these tokens through the pools and their pairs on 2026-10-07/08/12.

**Sum of positive gross across all pools ≈ $0.098. Sum net-positive after gas ≈ $0.079 (pool 1 + pool 2).**

---

## Pool-by-pool detail

### 1. `0x9f4adbd0…` — atUST / USDm (the only real finding)

- tokens: idx0 USDm `0x765de816845861e75a25fca122bb6898b8b1282a` (39.419555078526763194), idx1 atUST `0xed193c4e69f591e42398ef54dea65aa1bb02835c` (14,513.849359837163404344) — Wormhole-bridged UST ("UST Terra", verified `WrappedToken`, creator 0x83f53C07…, creation tx `0x3ece80ce…`, block 10,550,567).
- **pool marginal (exact `calculateSwap(1,0,1e18)`): 14,607,891,734,439,477 wei = 0.01460789 USDm/atUST**; at dx=10.9 → 0.1587357 USDm out.
- market: Ubeswap V2 `0x752875e07e20bf03908d9f5d5c5e7dc330c801a1`, tokens (USDm, atUST), reserves (58,148,344,416,670,166 ; 19,372,189,665,143,572,807) = 0.058148 USDm vs 19.372 atUST → **spot 0.003002 USDm/atUST** (DefiLlama 0.00527). This is the **only atUST market**. **Last touched 2025-11-18** (flash-loan arb, txs at blocks 51,593,007 and 51,593,124 — the second bought 17.26 atUST from the Mobius pool for 0.256 USDm and sold them into the pair).
- **max profitable size: L = 10.90025099851221 atUST**
  - cost: 0.075048 USDm (Ubeswap in; cross-checked with router `getAmountsOut(0.07503 USDm) = 10.89958 atUST`)
  - revenue: 0.158752 USDm (pool out; cross-checked `calculateSwap(1,0,10.9e18) = 158,732,073,604,759,318`)
  - **gross +0.083704 USDm; gas ≈ 0.006 ⇒ net ≈ +0.0775**
- confidence: **high**. Pool not paused; swaps verified by recent history; both quotes exact; gas known.
- not circular (Ubeswap pair is an independent market), but the pair is bot-abandoned: the residual $0.084 has sat there since Nov 2025.
- if the pool's USDm side is drained by this arb, the pool becomes almost entirely atUST (its atUST side has essentially no value — atUST is a dead Terra claim; 15,963 atUST are already burned to 0xdead and 20,771 sit in the Wormhole TokenBridge `0x796Dff6D…`).

### 2. `0x02db089f…` — pUSD v1 / USDm
- idx1 pUSD `0xb4aa2986622249b1f45eb93f28cfca2b2606d809` ("Poof USD", verified `PoofMintableLendable` — a **zk-shielded** token): 614.029653824799441101 held; pool marginal **0.97611 USDm/pUSD**.
- market: Ubeswap `0xec3741fb…` USDm/pUSD reserves (0.078205 ; 0.139079) → spot **0.5623 USDm/pUSD**; last trade 2025-08-12.
- **max L = 0.034062295885251456 pUSD** → cost 0.025445, revenue 0.033252, **gross +0.007807, net ≈ +0.0016** — technically positive but sub-cent after gas. One-shot.
- confidence: high (mechanics), medium (worth executing).

### 3. `0xa2f0e57d…` — pUSD v2 / USDm
- idx1 pUSD `0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226` ("Poof cUSD", `PToken`): 14,308.44 held; pool marginal only **0.000158 USDm/pUSD** (pUSD is 15,000x the USDm side).
- markets: USDm pair `0x79769896…` is dead (2 wei USDm); MOBI pair `0x7aef68d7…` has only 0.050426 pUSD against 100.53 MOBI, so buying pUSD costs ≫ the pool's payout. Best route profit ≈ −1e-17 (zero at best).
- **no profitable acquisition arb.** ⚠️ note: the PToken's privileged supply manager `0x14874877865e659F09D9CE7c943C89aEB20F2BB5` minted 10,000 pUSD v2 and interacted with this exact pool on 2026-06-18 (txs `0xc12a06…` mint, `0x521599dc…` swap into pool, `0xf7c1d848…` burn 10,000 FROM the pool). Privileged capability, not unprivileged arbitrage.

### 4. `0x382ed834…` — pEUR v1 / EURm
- idx1 pEUR `0x56072d48…` (`PoofMintableLendable`): 4,081.69 held; pool marginal **0.037221 EURm/pEUR**; full dump of 4,081.69 pEUR would yield 24.259 EURm.
- market: Ubeswap `0x9b4ebb6f…` EURm/pEUR has reserves **1000 wei / 1003 wei** — dead. No other market. **No arb.**

### 5. `0x23c95678…` — pEUR v2 / EURm
- idx1 pEUR `0xd8761dd6…` (`PToken`): 11,171.25 held; pool marginal **0.002923 EURm/pEUR**.
- **no market anywhere** (0 Ubeswap pairs, 0 Sushi pairs, no V3 pool). **No arb.**

### 6. `0x413ffcc2…` — pCELO v1 / CELO
- idx1 pCELO `0xe74abf23…` (`PoofMintableLendable`): 3,904.86 held; pool marginal **0.16635 CELO/pCELO**.
- markets: POOF/pCELO `0x993b0d1a…` (116,762.0 POOF / 175.647 pCELO); POOF/CELO `0x0931738d…` (30,896.0 POOF / 6.4209 CELO); tiny CELO pair `0x3ea1e47f…`. POOF ≈ $0.0000208.
- best route (buy POOF with CELO → buy pCELO v1 with POOF → swap to pool): **L=2.93264 pCELO, cost $0.0414, revenue $0.0457, gross +$0.0043, net ≈ −$0.0019**. Gas-killed.

### 7. `0xfc9e2c63…` — pCELO v2 / CELO
- idx1 pCELO `0x301a61d0…` (`PToken`): 8,366.47 held; pool marginal **0.88638 CELO/pCELO**; full dump ≈ 1,335 CELO.
- market: POOF/pCELO v2 `0xbdfc2268…` (772,794 POOF / 188.784 pCELO); best route gross **+$0.000154** at L=0.2499 pCELO — net negative after gas.
- **evidence of active harvesting:** bot `0xf9e41C21F27A…` cycled pCELO v2 between the POOF pair and this pool on 2026-09-12/19/29 (e.g. blk 78,787,897: 6.902 pCELO 0xbdfc2268→bot→pool `0xfc9e2c63`). The rate is pinned to the market; nothing meaningful left.

### 8. `0xcce0d62c…` — USDC (Optics V2) / USDm
- idx1 `0x1bfc26ce…` ("USD Coin (PoS)", verified `UpgradeBeaconProxy`, Optics-V2 beacon 0x1548cf5c…): 1,041.516716 (6dp) held; **pool pays a premium: 1.03663 USDm per USDC-old at the margin**.
- market: Ubeswap CELO pair `0xff4aa942…` (0.158067 USDC-old / 1.4268 CELO) + CELO/USDm conversion; Sushi USDm pair dead (171 wei). Cost curve rises from ~$0.86/unit for a sliver to >$1.7/unit at half the reserve.
- optimum over exact math: **negative (−$0.0007 gross)**. No arb, despite the pool premium, because the market is too thin. (Last real activity 2025-09-11.)

### 9. `0xa5037661…` — USDCet (Optics V1) / USDm
- idx1 `0x2a3684e9…` ("USD Coin", `UpgradeBeaconProxy`, Optics-V1 beacon 0xf244eA81…): 61,908.857 (6dp) held; pool marginal **0.97727 USDm per USDCet**.
- market: Ubeswap USDm pair `0xcd1d049a…` (45.15 USDCet / 44.66 USDm, spot 0.9892) — buying costs ≥1.0146/unit ⇒ **negative (−$0.106 at best)**. Bots instead use the CELO triangle (`0x684da045…` USDCet/CELO + CELO/USDm, ~0.2% spread) and were **feeding this pool on 2026-10-12** (the pool's USDCet balance grew +5.83 units while we watched). No OP for us.
- USDCet is the legacy Optics-V1 bridged USDC; it still has real depth and is fair-priced — the pool itself is the "seller" at a 2.3% discount, but you must be able to *buy cheaper than 0.977* to profit, and nothing on Celo is.

### 10. `0x0986b42f…` — aaUSDC / USDm
- idx1 `0xb70e0a78…` ("Avalanche USDC.e via Allbridge", eip-1167 proxy): 253.82 held; pool marginal **0.99193 USDm/aaUSDC**.
- **no market anywhere** (no Ubeswap/Sushi pair; no V3 pool). The Allbridge protocol was paused after a 2026 flash-loan attack, and even a reopened bridge returns 1:1 AVAX USDC.e — strictly above the pool's rate. **No arb; the 280 USDm side is unreachable.**

### 11–12. BTC triangle — d629 "Bridged WBTC" vs Optics WBTCs
- Pool 11 `0xaefc4e8c…`: 0.444837 d629-BTC / 0.02509122 WBTC baab; pool sells baab at **1.7332 d629/baab** and buys baab at **0.5621 d629 per 1 baab** (1.779 d629/baab).
- Pool 12 `0x19260b9b…`: 0.965776 d629-BTC / 0.04215999 WBTC be50; marginals **1.6269** and **0.6006** (buy side 1.665).
- token identities: d629 `0xd629eb00…` = "Bridged WBTC" implemented as **TokenSoftTokenV2** (Blacklistable/RevocableToAddress/role-gated Mint-Burn-Pause ERC1404 stack; sourcify metadata for the implementation references the `/dev/cETH/contracts/…` source tree — i.e. the same developer as the old cETH `0x2def4285…`), 18dp, supply 2.4455, deployed by EOA `0xF15d39D2…` 2021-05-07. **No on-chain bridge custody or permissionless minter exists** (mint/burn are role-gated); it is a custodial/hobby "bridged" token, and its four live markets consistently price it at ~**$44–45k** (mCUSD 43.4k, EURm 40.0k€, CELO 471.7k, cETH 28.4 — and cETH itself trades at ~62% of ETH). baab `0xbaab46e2…` / be50 `0xbe50a301…` are the **Optics V2 / V1 "Wrapped BTC"** beacons (8dp), priced by their pairs at ~**$77.3k** and ~**$70.4k**. (The current canonical Celo WBTC, Superbridge-era `0x8aC2901D…`, is a *different* token not held by these pools.)
- ⚠️ **valuation caveat / reconciliation:** DefiLlama (and any tool pricing d629 by its "BTC" symbol, e.g. $82,740) overvalues d629 by ~1.86x versus its actual live-market price (~$44.5k). Any "profit" on these pools obtained by valuing received d629 at full BTC parity (e.g. a paint of +$122 for 0.00476 d629) **disappears if d629 is monetized at its real market price** — that route nets ≈ −$40 vs acquiring via CELO/mcUSD, and −$58 vs mCUSD. It only becomes real if the d629 issuer redeems at par off-chain, which no on-chain evidence supports.
- best exact routes: buy baab→pool→d629 (−$0.002), buy d629→pool→baab (**+$0.0021, L=5.31e-5 d629 ≈ $2.4**), buy be50→pool→d629 (−$0.00025), buy d629→pool→be50 (−$0.0387). All net-negative after gas.
- **these pools are actively arbed**: buyers `0x3f5305C955…` (Oct 8), `0xae6D7D47…` (Oct 7), and transfers of both WBTCs through the pools continued on 2026-10-12. The three "BTC" tokens trade at persistently different prices; the pools encode the cross-rates (pool 11: 1.733 ≈ mkt 77.3/44.7 = 1.73 ✓), so no residual edge beyond the bots' clips.
- partially circular: the d629/baab pair `0x3b41526e…` and the pools are mutually consistent; the only non-circular anchors are the mCUSD/mcUSD and CELO pairs.

---

## Poof token identification (summary; full data in `poof-tokens.json`)

Poof was a Celo **privacy/zk lending protocol** (2021), with two generations plus a governance token; it is dead:

- **v1 (2021-10-19)**: `PoofMintableLendable` — shielded "debt" tokens pUSD `0xb4aa2986…`, pEUR `0x56072d48…`, pCELO `0xe74abf23…`. `mint`/`burn` require `bytes[3] proofs` + account-tree/verifier data (**zk-proof gated**). `underlyingBalanceOf(pool)` reports 1:1 underlying, but the `debtToken` contracts (e.g. `0x5b46A202…` for pUSD) report `totalSupply() == 0` and have no `underlying()` — reserves are gone/unverifiable. A `V1Migration` contract (whitelist-gated) converts v1→v2 1:1. **Not redeemable by an unprivileged outsider.**
- **v2 (2021-12-03)**: `PToken` — pUSD `0xeadf4a71…`, pEUR `0xd8761dd6…`, pCELO `0x301a61d0…`. `mint(address,uint256)`/`burn(address,uint256)` are `onlySupplyManager`; a known active supply manager `0x14874877865e…` minted/burned as recently as 2026-06-18 (including burning pUSD **out of** Mobius pool 3). **Not mintable/redeemable by outsiders.**
- **POOF / PoofCash `0x00400fcb…`**: 100M ERC20 deployed 2021-07-03 via SingletonFactory; trades at ~$0.00002 (POOF/CELO `0x0931738d…`, POOF/USDm `0xcc90d7b4…`); vesting/release contracts still move it (Oct 2026). No redeem function.
- **Markets:** only assets of any size (and they are small) are pUSD v1 (0.078 USDm), pCELO v1/v2 vs POOF, pUSD v2 vs MOBI. pEUR v1/v2 have **no usable market at all**.

**Conclusion:** the "good" sides of the Poof pools (330 USDm, 26.8 EURm, 10.3 EURm, 73+1367 CELO, 0.96 USDm) are **not extractable by an unprivileged attacker via token purchase** — the junk tokens have no cheap acquisition channel. They are, however, partially reachable by privileged supply managers (v2) or by zk-proof holders (v1), which is a governance/insider risk rather than a market arbitrage.

---

## Cross-cutting observations

1. **Why is total profit only ~$0.10?** Every large "good" balance sits behind a junk token whose external market is tiny or missing (atUST 0.058 USDm; pUSD v1 0.078; pEUR v1 ~0; pEUR v2 none; aaUSDC none; USDCold 0.158). The largest pool prizes (330 USDm, 3,741 USDm, 24,427 USDm, 280 USDm) are protected by dead/zk-gated/fair-priced counterpart tokens.
2. **Bots are already on the efficient pools.** Pools 7, 9, 11, 12 show TokenSwap events and cross-market token cycling within the last week (and on 2026-10-12), keeping spreads ~0–0.2%. The un-harvested $0.08 is precisely on the pools/deprecated-pairs no bot tracks (pool 1 last swap Nov 2025; pool 2's pair last trade Aug 2025).
3. **Swap liveness verified.** All 12 `paused() == false`; verified `Mobius_*_Swap` sources with `whenNotPaused`; recent swap history on pools 1, 2, 3, 6, 7, 9, 11, 12 (evidence links in `markets.json` notes).
4. **What would increase the ceiling:** (a) a live bridge/burn path for atUST (Wormhole TokenBridge still holds 20,771 atUST; acquiring UST on Terra Classic and bridging in — speculative, and the pool USDm side caps extraction at ≈35 USDm anyway); (b) depreciating the aUSD/Terra collateral further; (c) any new DEX listings for Poof tokens. None are present on-chain today.
5. **Blocker/uncertainty note:** the d629-branch valuation uses mCUSD≈$1.00 and mcUSD≈$1.0001 (no deeper USDm venue exists for those Moola receipts); switching mCUSD to e.g. $1.02 flips pool 11's +$0.002 route negative — immaterial either way.

## Deliverable provenance

- `analysis/markets.json` — machine-readable per-pool numbers: token addresses/balances (block 79,926,039), full `calculateSwap` quote grids, market pairs with raw reserves, exact route optima (size/cost/revenue/gross/net), marginal prices, gas and price assumptions.
- `analysis/poof-tokens.json` — Poof token identification: creator, creation tx hash, verified-source links, supply, redeemability mechanics/evidence, all DEX markets with raw reserves.
- Scripts (read-only, keyless RPC): `analysis/arb_01_scan.py` … `arb_07_markets_json.py`, raw dumps `_pairs_scan.json`, `_markets_raw.json`, `_quotes.json`, `_profit.json`, `_externals.json`, `_poof_bridge.json`.

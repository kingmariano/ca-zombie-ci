# LAC & RPC real-market price and liquidity vs CapyFi oracle

*Read-only. Pool state read directly from Uniswap v4 `StateView` (`0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227`) on Ethereum mainnet (block 26,149,6xx); cross-checked with DexScreener and GeckoTerminal. USD figures use the pool's own spot price.*

## 1. Token addresses

| Token | Chain | Address | Notes |
|---|---|---|---|
| LAC (LaCoin) | Ethereum | `0x0Df3a853e4B604fC2ac0881E9Dc92db27fF7f51b` | 10B supply; top holder = EOA `0xb6e17577…` with ~8.75B (87.5%) |
| LAC | **LaChain** | **native coin** (no ERC-20; CLac market uses `0xEeee…EEeE`) | CapyFi `HelperConfig.getLaChainConfig()` sets `lac: address(0)` |
| LAC | World Chain | `0x0Fe75CAe44E409AF8c9E631985D6b3De8E1138dE` | verified token, but total supply only **1,000 LAC** and only ~5 lifetime txs; **no DEX pools** (DexScreener/GeckoTerminal/GoldRush all empty) |
| LAC | Base | — | **not found** (no pools on DexScreener/GeckoTerminal; CapyFi Base markets exclude LAC) |
| RPC (Ripio Coin) | Ethereum | `0xEd025A9Fe4b30bcd68460BCA42583090c2266468` | CapyFi `caRPC` underlying |

Symbol collisions ruled out: "LAC" on BSC is *LaCucina Token* (`0xe6f079E7…`), on Solana *LAC Coin* — different projects.

## 2. Every LAC / RPC trading pair found

| Chain | DEX | Pair / pool | Type | Reserves (live) | Spot | 24h vol | Status |
|---|---|---|---|---|---|---|---|
| Ethereum | Uniswap v4 | `0xa8f7d3148be7c6e66462f7d5da7843c94d974e0697e1768fb9c8b695f986a45b` (LAC/USDC, 1%, tickSpacing 200, **no hook**) | live | **419,363.74 LAC / 4,259.97 USDC** (~$8,520) | **$0.01015818** | $82 | only live LAC market |
| Ethereum | Uniswap v4 | `0x1047f84bc973cee6e784ac3e60438354b52f8eb0f13011a48c6fa8f8720e5844` (LAC/ETH, 0.3%) | dead | active liquidity **L = 0** | stale $0.00767 | $0 | initialized only |
| Ethereum | Uniswap v4 | `0xd8442c1d563ba9b7dc1bba16430f6f999c0f8dd26914ca757d43ce88d416ebc7` (RPC/USDC, 0.3%, tickSpacing 60, **no hook**) | live | **9,810.75 USDC / 923,771.35 RPC** (~$19,622) | **$0.01062032** | $1,448 | only live RPC market |
| Ethereum | Uniswap v4 | `0x06d8bb83012a55c023fded213c879171f897fe29677c42aaa5a435f1b970ced3` (RPC/USDT, 5.9%) | dead | L = 0 | — | $0 | initialized only |
| Ethereum | Uniswap v4 | `0x68473b6d89b8b2fbdb90da870c15805f13dcb0202b70cfc7f2f6d602a88c3bd1` (RPC/ETH, 0.3%) | dead | L = 0 | — | $0 | initialized only |
| Ethereum | Uniswap v2 | `0x01f82214691b4ac9a0a88c2d84690b231f2f0623` (RPC/WETH) | dead | ~$9.5 | — | $0 | legacy |
| Ethereum | Uniswap v2 | `0xdfc9b1115b07c01c47ab6f84a59da85afd007297` (RPC/USDC) | dead | ~$5.7 | — | $0 | legacy |
| Ethereum | Uniswap v2 | `0x166b5fd1d06c65689f0867807962e0059598db9f` (RPC/WETH) | dead | ~$2.7 | — | $0 | legacy |
| LaChain | (Ladex, deprecated) | no addresses obtainable | — | DefiLlama stale TVL $16.6k | — | — | no live market found |
| World Chain | — | — | — | — | — | — | no pools |

## 3. Depth / slippage (constant-product within the active range; 1% LP fee LAC, 0.3% RPC not included in the figures below)

### LAC/USDC pool — X = 419,363.74 LAC, Y = 4,259.97 USDC, spot $0.01015818, TVL ≈ $8,520

| Trade | Nominal @ spot | USDC received / paid | Loss / premium |
|---|---|---|---|
| Sell 1,000 LAC | $10.16 | $10.13 | −0.24% |
| Sell 10,000 LAC | $101.58 | $99.22 | −2.33% |
| Sell 100,000 LAC | $1,015.82 | $820.23 | **−19.25%** |
| Sell 400,000 LAC | $4,063.27 | $2,079.65 | **−48.82%** |
| Sell 1,000,000 LAC | $10,158.18 | $3,001.33 | −70.45% |
| Sell 9,840,000 LAC ("$100k of LAC") | $99,956.50 | **$4,085.84** | −95.91% |
| Buy 10,000 LAC | $101.58 | $104.06 | +2.44% |
| Buy 100,000 LAC | $1,015.82 | $1,333.89 | +31.31% |
| Buy 300,000 LAC | $3,047.45 | $10,706.70 | +251% |
| Buy 377,000 LAC (90% of pool) | $3,829.63 | $37,910.01 | +890% |

**"$100k / $1M of LAC" cannot be bought or sold at any sensible price.** The pool only holds ~$4.3k of USDC and ~$4.3k-worth of LAC. Selling LAC worth $100k ($1M) yields ≈ **$4.09k (95.9% loss)** — the USDC side is exhausted. Buying LAC worth $100k is impossible: the pool contains only 419k LAC in total; buying it all costs unbounded USDC (≈$4.9M for 99.9% of it). Realistic max extractable USD from the entire LAC market ≈ **$4.3k**.

### RPC/USDC pool — X = 923,771.35 RPC, Y = 9,810.75 USDC, spot $0.01062032, TVL ≈ $19,622

| Trade | Nominal @ spot | USDC received / paid | Loss / premium |
|---|---|---|---|
| Sell 100,000 RPC | $1,062.03 | $958.30 | −9.77% |
| Sell 923,000 RPC | $9,802.56 | $4,903.33 | −49.98% |
| Sell 9,230,000 RPC ("$100k of RPC") | $98,025.59 | $8,918.19 | −90.90% |
| Buy 100,000 RPC | $1,062.03 | $1,190.96 | +12.14% |
| Buy 800,000 RPC (87% of pool) | $8,496.26 | $63,412.10 | +646% |

Realistic max extractable USD from the entire RPC market ≈ **$9.8k** (selling ~infinite RPC asymptotically yields $9,810.75).

## 4. Cost to move the observable (spot) price — permissionless

Both live pools have **no hook** (pool IDs reconstructed from PoolKey with `hooks = 0x0`), so anyone can swap permissionlessly.

| Target price move | LAC/USDC cost | RPC/USDC cost |
|---|---|---|
| +10% | **~$208** | ~$479 |
| +25% | ~$503 | ~$1,158 |
| +50% | ~$957 | ~$2,205 |
| **2×** | **~$1,765** | ~$4,064 |
| 5× | ~$5,266 | ~$12,127 |
| **10×** | **~$9,211** | ~$21,214 |
| 100× | ~$38,340 | ~$88,297 |

(plus the 1%/0.3% LP fee on the swap). The observable LAC price is therefore **trivially movable by a single retail-sized wallet**: <$2k doubles it, <$10k makes it 10×.

## 5. Oracle vs real market

| Asset | CapyFi oracle | Observable market spot | Oracle vs market |
|---|---|---|---|
| LAC (Ethereum feed `0xF3585f9D…`) | **$0.010015** | $0.01015818 (LAC/USDC v4) | **−1.41% (oracle below market)** |
| LAC (LaChain SimplePriceOracle) | **$0.009995** | $0.01015818 (Ethereum pool) | −1.61% (oracle below market) |
| RPC (feed `0x5da9a0bc…`) | **$0.01059766** | $0.01062032 (RPC/USDC v4) | **−0.21% (oracle below market)** |

Third reference: Binance's LaCoin info page showed $0.0099509 — *below* both the oracle and the pool spot (no real Binance LAC market exists; that page is informational).

**Answer: the oracle is (slightly) BELOW the only observable market spot** — by 1.4% (LAC, ETH), 1.6% (LAC, LaChain vs ETH market) and 0.2% (RPC). It is not an upward mispricing at spot. The real problem is **depth, not spot**: the protocol marks **117.3M LAC (~$1.18M)** in `caLAC` (Ethereum) and **4.09B RPC (~$43.4M)** in `caRPC` (Ethereum) — plus 71.8M LAC (~$718k) in LaChain `cLAC` — against pools that can absorb only ~$4k and ~$10k respectively. Any liquidation at scale would realize a small fraction of the marked value.

## 6. Can the observable price move the oracle? (permissionless?)

**No — the CapyFi oracles are permissioned price feeds, not DEX oracles:**

- **Ethereum**: `getConfig()` shows `caLAC`/`caRPC` read `CapyfiAggregatorV3` feeds (`0xF3585f9D…` LAC, `0x5da9a0bc…` RPC). Updates are `updateAnswer()` restricted to `authorizedAddresses`. On-chain, the updater is a **1-of-1 Safe `0xBf41C0DC65ea4879D8A74E0a69737AF7B3e0Fa13`** whose only owner is EOA `0xaCDC3EBA833Ec6Edb048C109956440Fcf0985314`; it pushes both feeds via MultiSend (LAC ~every 4 h — last update 2026-10-08 17:14:23 UTC; RPC several times a day). Feed bounds: LAC `$0.0085–$0.0115`, RPC `$0.01–$0.02` — the single updater key can move the oracle ±15% (LAC) / ±50% (RPC) within those bounds.
- **LaChain**: `SimplePriceOracle` (`0x4E07BDEe…`) — `setUnderlyingPrice` is callable by `owner` or `authorizedAddresses`; owner is the **4-of-7 multisig `0x8D3bdc2E…`**, and there are **no bounds**. LAC price there ($0.009995) is purely admin-set.
- Because the oracle does not read the pools, spending $1.8k to double the LAC/USDC spot price does **not** directly change the oracle. It would only matter if the off-chain updater bot derives its price from that thin pool (its logic is not observable on-chain) — in which case the manipulation cost would be ~$208 (+10%) to ~$1.8k (2×) per update cycle.

## 7. Confidence & caveats

- **High confidence**: pool reserves, spot prices, pool IDs/hooks, oracle feed addresses/bounds, updater Safe identity, LaChain oracle type — all read directly from chain state.
- **Medium confidence**: "real market price" as a concept — there is effectively **no market**: one $8.5k pool for LAC and one $19.6k pool for RPC; all other pairs are dead (active liquidity 0). The spot price is an artifact of a nearly empty pool.
- **Unverified**: the off-chain updater bot's pricing methodology; whether any Ladex LAC pairs still exist on LaChain (explorer API unreachable); a possible ERC-20 wLAC on LaChain (no evidence found).
- **Blockers**: LaChain explorer API 404s and Blockscout MCP does not index LaChain; Blockscout PRO credits exhausted mid-session; public RPCs refuse wide-range `eth_getLogs` (pool keys verified by local keccak reconstruction instead).

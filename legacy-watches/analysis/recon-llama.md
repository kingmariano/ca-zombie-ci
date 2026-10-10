# H2-09 cluster — external recon snapshot (2026-10-10 ~11:30 UTC)

Source: DefiLlama API (`api.llama.fi/protocol/<slug>`, saved in `analysis/llama/`), DefiLlama coins prices,
chain RPCs. Purpose: reconcile corpus figures with live TVL and pin chain liveness + prices used across
the dossier. USD prices at fetch time (see `prices-snapshot.json`, `prices-snapshot2.json`):
ETH $2,492.75 | stETH $2,492.44 | USDC $0.99972 | USDT $0.99920 | STX $0.39836 | HBAR $0.09213 |
WAN $0.05722 | ASTR $0.006977 | GLMR $0.01081 | FLOW $0.032158 | USDE $0.99935 | PYUSD $0.99970 |
SAUCE $0.012205 | BAKE $0.0002604 | BABY $0.0002096 | FLR $0.007031 | USDA $0.99565 | USDB $0.98814.

## Chain liveness (eth_blockNumber / Hiro tip), `analysis/chain-liveness.json`
- Ethereum 26,161,723 | BSC 126,819,488 | Hedera 100,952,655 | Wanchain 46,766,639 | Astar 15,020,121
- Flow EVM 81,304,566 | Flare 71,772,023 | Blast 41,410,875 | Arbitrum 513,498,875 | Stacks 9,164,656
- Polygon 95,281,675 (bor rpc) | **Moonbeam FROZEN at 16,796,699 (2026-08-10T11:36:12Z)** — same halt date as Moonriver (H2-04). Confirmed on drpc + onfinality. Any Moonbeam target is S while halted.

## DefiLlama TVL vs corpus figure (key reconciliations)
| Protocol | DL slug | DL TVL now | Corpus figure | Note |
|---|---|---|---|---|
| SaucerSwap V1 | saucerswap-v1 | $9.80M (Hedera) | $314.6k USDC "excess" | DL token snapshot: USDC 347,156 + USDC[HTS] ~37k + USDT ~10k + DAI 87 + WBTC 2.7 + WETH 84 in V1 pools |
| WanSwap | wanswap-dex | $1.03M (Wanchain) | $168k wanUSDT | composition: WWAN 15.96M (~$0.9M), WANUSDC 120.4k, rest dust |
| ArthSwap V2 | arthswap-v2 | $524.8k (Astar) | $117.9k | composition: WASTR 16.34M, OUSD 188.8k, JPYC 111.3k, stables ~$130k |
| Beamswap (Classic/Stable/V3) | beamswap-* | $0 | $96.5k | Moonbeam halted 2026-08-10 |
| FstSwap | fstswap | $9.99M (BSC) | $3.54M USDT | DL snapshot: USDT 3.92M, FIST 28.6M, CHEESE 41.8M, PAYU 22.06B, BABYDOGE 26.2M |
| BakerySwap | bakeryswap | $3.89M (BSC) | $3.77M | BAKE now $0.00026 (collapsed); composition includes BABYDOGE etc. |
| BSCSwap | bscswap | $5.70M (BSC) | $3.08M | DL token last entry only ~$100k — TVL composition unclear; verify live |
| BabySwap | babyswap | $1.53M (BSC) | $1.42M | USDT 830k + BUSD 85.6k + meme tokens |
| EmpireDEX | empiredex | $2.86M (9 chains) | $1.25M | BSC $2.36M + Cronos $328k + ETH $82k + xDai $46k + Avax $29k + Fantom $13k + Polygon $6.5k |
| KaoyaSwap | kaoyaswap | $1.63M (BSC) | $908k | token snapshot: BUSD 196k + WBNB 1.9k |
| Universe XYZ | universe-xyz | $3.24M (Ethereum) | $3.33M | index-basket tokens: AAVE 18,428 + SUSHI 3,635 + BOND 2,480 + SNX 1,881 + LINK 1,271 + COMP 46 + ILV 24; pool2 USDC 7,089 |
| Unslashed | unslashed | $3.70M (Ethereum) | $4.03M | STETH 1,483.75 + WETH 1.09 |
| JPEG'd | jpegd | $566,986 (Ethereum) | $572k | WETH 212.16 + APE 181.81 + 3CRV 76.29 + NFT collateral (PUDGY 3, BAYC 1, ⊕ 1) |
| Mangrove | mangrove | $4.28M (**Blast $4.24M** + Arbitrum $38.7k) | $4.19M | Blast: USDB 2,096,294 + USDE 2,091,000 + WETH 18.86 + BLAST 17.5M; Arbitrum: USDT0 38,729. **Not Polygon** — corpus chain label was wrong |
| Sceptre Liquid | sceptre-liquid | $15.25M (Flare) | $15.6M | FLR 2,165,600,711 @ $0.007031 |
| MORE Markets | more-markets | Flow supply $4.09M + borrowed $4.22M | ≈$5M aTokens | ANKRFLOWEVM 107.8M + PYUSD 645.8k + USDC.E 315k + PYUSD0 124.9k + WETH 66.96; borrows WFLOW 78.65M etc. |
| Arkadiko | arkadiko | $1.53M (Stacks) | $270k STX + USDA + DIKO | STSTX 2.07M + STX 685,292 + WSTX 347,190 + sBTC 1.65 |

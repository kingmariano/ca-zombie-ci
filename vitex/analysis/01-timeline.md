# H-05 ViteX — evidence timeline (compiled 2026-10-03)

All times UTC. Sources are listed inline. Nothing here required a transaction;
every chain-side number is either from a public cached API, DefiLlama, or the
go-vite source tree.

## Chain / protocol timeline

| Date | Event | Source |
|---|---|---|
| 2019-04 | ViteX DEX launched on Vite (built-in DexFund/DexTrade contracts) | vite.org, docs.vite.org |
| 2022-11-26 | DefiLlama ViteX adapter starts recording daily TVL (100% USDT) | api.llama.fi/protocol/vitex |
| 2023-05-13 | Last snapshot height in community API: 122,615,899; ViteX fund = 4,944,710.11 USDT | vite-info-api.xvite.workers.dev (still serving this frozen JSON) |
| 2023-08-23 | Last (tiny) change in DefiLlama TVL series; series flat afterwards | api.llama.fi/protocol/vitex |
| 2024-09-26 | Last commit to go-vite (node software) | github.com/vitelabs/go-vite |
| 2025-02-16 | Last Wayback capture of vitescan.io (SPA shell only); no later captures | web.archive.org |
| 2025-02-17/24 | Binance announces/delists VITE | CryptoRank, Bitget |
| 2025-03-10 | Vite Labs closes its gateway (ViteX deposits/withdrawals) earlier than planned; roadmap canceled; network to be maintained "only for as long as it can" | CryptoRank news |
| 2025-03-01 | DefiLlama marks ViteX dead (`deadFrom: 2025-03-01`) | deadAdapters.json |
| 2025-04-13/16 | Last pushes to vite-web-wallet / explorer repos; no infrastructure updates after | GitHub |
| 2025-05-21 | VITE → JEETS (Solana) migration announced: "ongoing technical and security concerns affecting the native chain"; 100 VITE = 1 JEETS | x.com/vitelabs/status/1925499301314097170; coincarp; cryptocompare PDF |
| 2025-07 | r/vitelabs: "Vite is dead… nowhere to send it" | reddit post 1lriuq8 |
| 2025-10 | "Jeets airdrop for vite holders" announcement | x.com/vitelabs/status/1974080261454536967 via t.me/s/Jeets_Token |
| 2026-04-15 | Last push to vite-connect-server repo (no infrastructure change) | GitHub |
| 2026-10-03 | This audit: all official Vite endpoints dead (DNS/HTTP); no community node found; vitescan.io times out from 9+ countries; live wallet bundle still points at dead endpoints | this folder, CI run 37132690689 |

## Frozen on-chain snapshot (community API, still up 2026-10-03)

`GET https://vite-info-api.xvite.workers.dev/` (Cloudflare Worker, same JSON on
every path; `updateTimestamp: 1683968462` = 2023-05-13T12:21:02Z):

```json
{"initial":1000000000,"rewards":111490435.04,"burned":45621934.25,
 "totalSupply":1065868500.79,"totalStaked":298784276.63,
 "staked":[{"name":"VX","amount":22938591.45},{"name":"SBP","amount":33000000},
           {"name":"Quota","amount":19978919.87},{"name":"Fullnode","amount":7083873},
           {"name":"SVIP/VIP","amount":1630000},{"name":"Viva","amount":4228414.71},
           {"name":"Voting","amount":209924477.59}],
 "multiChain":[{"name":"Vite","amount":973765384.64},{"name":"BSC","amount":69393742.68},
               {"name":"ERC20","amount":5473334.69},{"name":"ERC20(original)","amount":17236038.79}],
 "tvl":5025440.58,
 "tvlRankings":[{"name":"ViteX","amount":4944710.11},{"name":"Viva","amount":80730.46}],
 "snapshotHeight":122615899,"updateTimestamp":1683968462}
```

## ViteX deployment facts

- ViteX = **native built-in contracts** in go-vite, not Solidity++:
  - DexFund `vite_0000000000000000000000000000000000000006e82b8ba657` (escrow, mining, dividends, staking)
  - DexTrade `vite_00000000000000000000000000000000000000079710f19dc7` (order book / matching)
  - Quota `vite_0000000000000000000000000000000000000003f6af7459b9`, ConsensusGroup `...04d28108e76b`, Asset `...0595292d996d`
- VX token id `tti_564954455820434f494e69b5`; VITE token id `tti_5649544520544f4b454e6e40`.
- Vite-chain USDT (the 4.94M) is gateway-minted: token `tti_80f3751485e4e83456059473`
  mapped to ETH-USDT `0xdac17f958d2ee523a2206206994597c13d831ec7` and BSC-USDT
  `0x55d398326f99059ff775485246999027b3197955` (crypto-info `gateways/vite-labs/vite-labs.json`).
  Redemption required the gateway.
- Gateway operators: Vite Gateway (crosschain.vite.net, closed 2025-03-10);
  VGATE (vgate.io → now redirects to a Vietnamese gambling site); XGate, Kivigate,
  ViNo, ExperimentDAO (sites dead). No operator remains → no redemption route for
  Vite-chain gateway tokens even if the chain were reachable.
- VITE and VX are delisted from CoinGecko (`/coins/vite` and `/coins/vitex` →
  "coin not found"); CoinMarketCap shows VITE as rebranded/migrated to JEETS on Solana.

## Key addresses (for future re-verification if a node ever appears)

```
DexFund   vite_0000000000000000000000000000000000000006e82b8ba657
DexTrade  vite_00000000000000000000000000000000000000079710f19dc7
Quota     vite_0000000000000000000000000000000000000003f6af7459b9
ConsGrp   vite_0000000000000000000000000000000000000004d28108e76b
Asset     vite_000000000000000000000000000000000000000595292d996d
VX        tti_564954455820434f494e69b5
VITE      tti_5649544520544f4b454e6e40
USDT(gw)  tti_80f3751485e4e83456059473
```

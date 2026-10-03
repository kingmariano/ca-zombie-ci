# H-05 ViteX — Vite chain endpoint evidence (collected 2026-10-03, UTC)

Read-only checks. All results below were collected on 2026-10-03 from this host
and (where noted) from independent vantage points / GitHub runners.

## A. Official Vite infrastructure — DNS status (Google DoH, 2026-10-03)

| Host | DNS result | Meaning |
|---|---|---|
| node.vite.net | CNAME `vitenode-837259984.us-east-1.elb.amazonaws.com.` — target **NXDOMAIN (no A)** | official public node: ELB deleted |
| biforst.vite.net (ViteConnect) | CNAME `viteconnectlb-1888616360.us-east-1.elb.amazonaws.com.` — target **NXDOMAIN** | deleted ELB |
| api.vite.net | CNAME `d-583y2v6j0e.execute-api.us-east-1.amazonaws.com.` — target **NXDOMAIN** | API Gateway deployment deleted |
| config.vite.net | CNAME `d-28npzmg7sk.execute-api.us-east-1.amazonaws.com.` — target **NXDOMAIN** | deleted |
| vitex.vite.net | NXDOMAIN | removed |
| gateway.vite.net | NXDOMAIN | removed |
| crosschain.vite.net | NXDOMAIN | removed |
| buidl.vite.net (testnet) | NXDOMAIN | removed |
| explorer.vite.net | GitHub Pages (vitelabs.github.io) | static redirect page |
| wallet.vite.net | 301 → https://vite.net/ (GitHub Pages) | static wallet SPA only |
| app.vite.net, node1/2/3, snapshot, supernode, testnet, premainnet, rpc, ws, scan, vitescan, market, mining, dex, growth, eth, btc, data, assets, cdn, mail, m | NXDOMAIN | not present |
| vitex.net | Cloudflare nameservers return **REFUSED** (zone removed) | ViteX site gone |
| api.vitex.net | delegation REFUSED | gone |
| forum.vite.net, wiki.vite.net, blog.vite.net, community.vite.net | NXDOMAIN | gone |
| bootnodes.vite.net (P2P seed list) | CNAME → deleted API Gateway `d-5j0jymw5ua` | gone |
| stats.vite.net, reward.vite.net, static.vite.net | NXDOMAIN | gone |
| api.vitewallet.com, vitewallet.com | DNS SERVFAIL/refused | gone |
| x.vite.net | A=3.33.251.168 / 15.197.225.128 (same parking IPs as wallet.vite.net) | parked/redirect |
| vite.wiki | resolves, now an unrelated Vietnamese site (domain repurposed) | gone |

## B. HTTP/WS reachability

| Endpoint | Result |
|---|---|
| https://node.vite.net/gvite | DNS fail (NXDOMAIN) |
| wss://node.vite.net/gvite/ws | DNS fail |
| https://vitex.vite.net | connect fail |
| https://config.vite.net, https://api.vite.net | connect fail |
| https://gateway.vite.net, https://crosschain.vite.net, https://biforst.vite.net | connect fail |
| https://buidl.vite.net/gvite | DNS fail |
| https://vitescan.io (official explorer) | TCP timeout from this host AND from 6 check-host.net nodes (DE, ES, FI, IR, SE, US) |
| https://vitcscan.com | HTTP 502 (Cloudflare, origin down) |
| vitetxs.de, viteexplorer.eu | NXDOMAIN |
| https://vite.net (wallet SPA, GitHub Pages) | 200 — loads, but its configured `VITE_SERVER=wss://node.vite.net/gvite/ws`, `VITE_DEX_SERVER=https://vitex.vite.net` are dead → wallet cannot function |
| https://mainnet.viteview.xyz / https://viteview.xyz (3rd-party explorer, static SPA) | 200 — but JS config `DEFAULT_NODE=https://node.vite.net/gvite` → dead node, no backend API (POST rejected) |

Web wallet repo config (vitelabs/vite-web-wallet master, .env.production, pushed 2025-04-13):
```
VITE_SERVER=wss://node.vite.net/gvite/ws
VITE_DEX_SERVER=https://vitex.vite.net
VITE_GATEWAY=https://gateway.vite.net
VITE_CROSSCHAIN_SERVER=https://crosschain.vite.net
VITE_VIEW=https://mainnet.viteview.xyz
```
Every one of these is dead today.

## C. Third-party / community node search

- All community repos found (`viterium/vite_dart`, `viterium/viterium_wallet`,
  `niklr/vite-staking`, `niklr/vite-quota-bank`, `ViNo-community/Vitelink`,
  `vitelabs/explorer`, `vitelabs/vite-express`, `sarmatdev/vite-extension`,
  `viteshan/vite_tools`, `azbuky/rosetta-vite`) hardcode only `node.vite.net` (mainnet) or
  `buidl.vite.net` (testnet) — both dead. No alternative mainnet RPC found in code.
- GitHub code search for `node.vite.net`, `gvite`, `gvite/ws`: only the above.
- Mobile/desktop app configs (vite-wallet-android `NetConfig.kt`, vite-business-ios
  `ViteConst.swift`, vite-wallet, vite-passport) also use only the dead official hosts:
  `node.vite.net/gvite`, `vitescan.io`, `growth.vite.net`, `api.vitex.net`,
  `gateway.vite.net`, `static.vite.net`, `reward.vite.net`, `x.vite.net`. Test envs point
  to `http://148.70.30.139:48132` (times out) and `https://api.vitewallet.com/ws` (DNS dead).
- The Android app supports a user-set `customViteUrl`, i.e. a user with their own node could
  still use the wallet — but no public node exists for them to point at.
- P2P bootstrap: `conf/node_config.json` in go-vite uses
  `https://bootnodes.vite.net/bootmainnet.json` → CNAME to deleted AWS API Gateway
  (`d-5j0jymw5ua.execute-api.us-east-1.amazonaws.com`, NXDOMAIN); no Wayback capture.
  Without a seed list there is no way to join the network.

## D. Project/chain status evidence

- Binance delisted VITE 2025-02-24. Vite Labs closed the (ViteX) gateway
  2025-03-10 (earlier than the planned April date), canceled all roadmap plans,
  said it would maintain the network "only for as long as it can" (CryptoRank/Bitget
  reporting, Feb–Mar 2025).
- 2025-05-21 announcement (x.com/vitelabs/status/1925499301314097170): VITE → JEETS
  migration to Solana, "due to ongoing technical and security concerns affecting the
  native chain"; swap 100 VITE = 1 JEETS. JEETS mint:
  `7D87YFU86HJcHwc3izRp27eAH6G9MYY8WeoE1R5xpump` (Solana, pump.fun/pumpswap).
- JEETS Telegram (t.me/s/Jeets_Token) post referencing x.com/vitelabs/status/1974080261454536967:
  "Jeets airdrop for vite holders" (~2025-10).
- Reddit r/vitelabs (post 1lriuq8, ~2025-07): "Vite is dead. I wouldn't expect much.
  Money gone. My wallet says 15 cents now but there's nowhere to send it anyway
  because Vite is dead."
- CoinGecko: `GET /api/v3/coins/vite` → `{"error":"coin not found"}` (delisted).
- DefiLlama `api.llama.fi/protocol/vitex`: last real TVL change **2023-08-23**
  ($4,944,710); value carried forward unchanged to 2025-08-14 (last point) →
  the "$4.94M" in the finding is a 2023 snapshot, ~3 years stale.
- Wayback Machine: only capture of vitescan.io is 2025-02-16 (SPA shell; no data).
  No later captures — consistent with the explorer dying ~Feb–Mar 2025.
- Common Crawl: no captures of vitescan.io in 2025 indexes checked.

## E. ViteX deployment (addresses from vite.js / vuilder-docs / go-vite source)

ViteX is implemented as **native built-in contracts** in the Vite node software
(go-vite, `vm/contracts/`), not user Solidity++ contracts:

| Contract | Address | Role |
|---|---|---|
| DexTrade | `vite_00000000000000000000000000000000000000079710f19dc7` | ViteX order book / matching |
| DexFund | `vite_0000000000000000000000000000000000000006e82b8ba657` | ViteX asset escrow, mining, dividends, staking |
| Quota (Staking) | `vite_0000000000000000000000000000000000000003f6af7459b9` | VITE staking for quota |
| ConsensusGroup | `vite_0000000000000000000000000000000000000004d28108e76b` | SBP governance/voting |
| Asset | `vite_000000000000000000000000000000000000000595292d996d` | token issuance |
| VX token id | `tti_564954455820434f494e69b5` | ViteX Coin (18 decimals) |
| VITE token id | `tti_5649544520544f4b454e6e40` | native VITE |

ViteX trading/mining/dividend logic: go-vite `vm/contracts/contracts_dex_fund.go`
(2057 lines), `contracts_dex_trade.go` (399), `vm/contracts/dex/*.go` (~7.6k lines).

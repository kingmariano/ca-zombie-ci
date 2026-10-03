# H-05 ViteX child A — Is the Vite chain reachable / alive? (evidence report)

**Collector:** child-A subagent · **Date:** 2026-10-03 (UTC) · **Scope:** read-only network/DNS/archive/GitHub probes, no transactions.
**Raw outputs:** all `child-a-*.txt` / `.json` files in this directory. Machine-readable summary: `child-a-endpoints.json`.
**Probe payload used everywhere:** `POST {"jsonrpc":"2.0","id":1,"method":"ledger_getSnapshotChainHeight","params":[]}` (plus plain HTTP HEAD/GET and TCP connect where noted).

---

## (a) VERDICT

| Question | Verdict | Confidence |
|---|---|---|
| Is **any Vite mainnet node/RPC reachable today by an external party**? | **No.** Exhaustive search (CT, DNS brute force, passive DNS, GitHub, npm/Docker-equivalent code, Wayback, providers) found **zero** working mainnet RPC. Every official endpoint is DNS-dead or TCP-dead; no community/third-party node exists. | **~97 %** |
| Is the **Vite chain still producing snapshots/blocks**? | **No public evidence of production; likely halted/effectively dead.** No explorer, indexer, provider or community observer can see it. Official communications (Feb–May 2025) describe "node and explorer disruptions", "network instability … often cause network disruptions", maintenance-only funding, and the team migrated everything to Solana in May 2025. **Strictly speaking unprovable from outside**: a private SBP set could in theory still be producing; no public artifact attests to that. | **~80–85 % halted** |
| Does any third-party RPC provider support Vite? | **No.** NOWNodes full chain list contains no VITE; Ankr/GetBlock/dRPC/Chainstack/Tatum/PublicNode/BlockPI/Pocket/Alchemy do not list it. Provider subdomains either don't exist or return generic 404s. | **~95 %** |
| **JEETS airdrop snapshot for VITE holders** | **2025-11-11 00:00 UTC** (hardcoded in the official claim page). No public snapshot **height**; the claim page explicitly performed **no live Vite checks**. | date: **certain** (source text); height: **unknown** |

**Bottom line:** as of 2026-10-03 an external party cannot read the Vite chain through any discovered endpoint, and all available signals indicate the chain stopped being publicly observable by mid-2025 at the latest. The "dead 2025-03-01" framing in the parent finding is broadly consistent with the evidence; the last *positive* service news was a February 2025 partial recovery, and the last official code/site activity was 2025-04-13/16.

---

## (b) EVERY ENDPOINT TESTED (exact result + UTC timestamp)

### B1. Vite mainnet RPC / node candidates

| Endpoint | Test | Result | Timestamp |
|---|---|---|---|
| `node.vite.net/gvite` (official RPC) | DNS (Google DoH) | CNAME `vitenode-837259984.us-east-1.elb.amazonaws.com` → **NXDOMAIN (Status 3)** | 15:10–15:11 |
| `https://node.vite.net/gvite` | POST JSON-RPC | **curl 000**, no connection (DNS fail) | 15:45:02 |
| `wss://node.vite.net/gvite/ws` | POST/connect | **000** | 15:45:03 |
| `buidl.vite.net/gvite` (official testnet) | DNS + POST | **NXDOMAIN / 000** | 15:45:03 |
| `vitex.vite.net` | DNS + POST | **NXDOMAIN / 000** | 15:45:05 |
| `vitescan.io` (official explorer) | DNS | **A 47.240.225.75** (Alibaba Cloud HK), NS = AWS | 15:19 |
| `https://vitescan.io/` | curl GET/POST | TCP timeout ≥20 s, **000**; ports 80/443 timeout | 15:19, 15:45:06 |
| `http://47.240.225.75:48132` (gvite default HTTP port) | POST | **timeout, 000** | 15:45:26 |
| `www.vitescan.io`, `test.vitescan.io` | curl GET | **timeout, 000** (same IP) | 15:45:16, 15:45:38 |
| `vitescan.io` from independent nodes | check-host.net 6 nodes | **timeout** from DE, ES, FI, IR, SE, US (parent, `00-endpoint-evidence.md` §B) | 2026-10-03 earlier |
| `stats.vite.net` (hardcoded dashboard target) | DNS + POST | **NXDOMAIN / 000** | 15:45:36 |
| `bootnodes.vite.net/bootmainnet.json` (P2P boot seed from `conf/node_config.json`) | DNS + POST | CNAME `d-5j0jymw5ua.execute-api.us-east-1.amazonaws.com` → **NXDOMAIN / 000** | 15:45:38 |
| `config.vite.net` | DNS | CNAME `d-28npzmg7sk.execute-api…` → **NXDOMAIN** (Wayback 2024/2025 shows only nginx default page) | 15:10 (raw: `child-a-wayback-raw.txt`) |
| `api.vite.net` | DNS | CNAME `d-583y2v6j0e.execute-api…` → **NXDOMAIN** | 15:10 |
| `biforst.vite.net` (ViteConnect LB) | DNS | CNAME `viteconnectlb-1888616360.us-east-1.elb…` → **NXDOMAIN** | parent |
| `gateway.vite.net`, `crosschain.vite.net` | DNS/HTTP | **NXDOMAIN / connect fail** | parent |
| `wallet.vite.net`, `x.vite.net` | DNS/HTTP | Resolve to AWS Global Accelerator (`15.197.225.128`, `3.33.251.168`); **HTTP 301 → https://vite.net** only | 15:12 |
| `explorer.vite.net` | HTTP | **200** static SPA on GitHub Pages (last-modified **2025-04-16**); its JS hardcodes `https://node.vite.net/gvite` + `wss://node.vite.net/gvite/ws` (both dead). `vitelabs/explorer` `src/utils/consts.js`: `DEFAULT_NODE = node.vite.net/gvite` | 15:12, 15:50 |
| `vite.net` | HTTP | **200** "Vite Wallet" SPA (GitHub Pages); its production config points at the dead node/ViteX endpoints → non-functional | 15:12, 15:48 |
| `docs.vite.org` | HTTP | **200** GitHub Pages, content last-modified **2025-03-29**; docs still instruct `curl bootnodes.vite.net/bootmainnet.json` and `node.vite.net/gvite` (both dead) | 15:12 |
| `mainnet.viteview.xyz`, `buidl.viteview.xyz` | HTTP/JS config | **200** static SPA on Cloudflare; config `node.vite.net/gvite` / `buidl.vite.net/gvite` (dead); no backend API; Wayback captures through **2026-01-31** (shell only) | 15:20 |
| `vitcscan.com` (community explorer) | HTTP | **502** Cloudflare (origin down); source `vitcscan-rewrite/src/vite.ts` hardcodes `wss://node.vite.net/gvite/ws` | parent; repo read 15:23 |
| `vitex.net`, `api.vitex.net` | DNS | Cloudflare **REFUSED** (zone removed) | parent |
| `vitetxs.de`, `viteexplorer.eu` | DNS | **NXDOMAIN** | parent |
| CT-found hostnames `node-jp`, `node-tokyo`, `node-1`, `app`, `test`, `testnet`, `ttttt`, `tutorial`, `vitex-internal`, `wallet-beta`, `x-test`, `cdn-test`, `growth`, `gate`, `grin`, `grinx`, `download`, `reward`, `rewardapi`, `forum`, `bootnodes`, `stats` `.vite.net` | DNS sweep | **all NXDOMAIN** (except ones above) | 15:10–15:11 (raw: `child-a-dns-sweep.txt`; names from `child-a-crt-vite.net.json`) |
| `vite.io` / `explorer.vite.io` / `rpc.vite.io` / `*.vite.io` wordlist | DNS/HTTP | Wildcard AWS-GA answers `13.248.169.48`, `76.223.54.146`; only `vite.io` responds (114-byte JS **lander redirect**, repurposed domain). `explorer.vite.io` connect fail; `rpc.vite.io` connect fail | 15:19–15:25 |
| `vite.org`, `docs.vite.org` | CT (certspotter) | Certs issued/auto-renewed 2026 (GitHub Pages LE) — **not** evidence of node activity; `www.vite.org` = GitHub Pages | 15:08 |
| Historical P2P peers (`stats.vite.net/api/getAlivePeers`, Wayback 2022-10-24) | fetch | `{"size":0,"list":[]}` — no peer list recoverable | 15:43 |
| `node-tokyo.vite.net` (Wayback 2022-01-29) | fetch | nginx default page (never a public RPC) | 15:43 |

### B2. Third-party RPC providers (all: no Vite support)

| Provider / endpoint | JSON-RPC POST result | Chain-list citation | Timestamp |
|---|---|---|---|
| `https://vite.nownodes.io` | **HTTP 404** nginx | docs.nownodes.io node list has **no VITE** | 15:25 |
| `https://rpc.ankr.com/vite` | HTTP 403 `API key is not allowed to access blockchain` — **identical for `foobar123xyz` and `ethereum`** → generic, meaningless | Ankr chain docs: no vite | 15:24, control 15:51 |
| `https://vite.drpc.org` | HTTP 404 `{"message":"Not Found"}` | dRPC chainlist: no vite | 15:24 |
| `https://vite.blockpi.network/v1/rpc/public` | HTTP 404 `{"error":{...,"message":"unknown host"}}` | — | 15:24 |
| `https://vite-rpc.publicnode.com`, `https://vite.publicnode.com` | HTTP 404 | — | 15:25 |
| `https://vite.gateway.tatum.io` | HTTP 404 `{"statusCode":404,"message":"Not Found"}` | Tatum supported-blockchains page: no vite (only word "Invite") | 15:25 |
| `https://vite.getblock.io` | DNS none | GetBlock chains page: no vite | 15:24 |
| `https://vite.api.onfinality.io/public` | DNS none | — | 15:24 |
| `https://rpc.vite.io` | connect fail (parked anycast) | — | 15:25 |
| `https://vite-mainnet.g.alchemy.com` | DNS none | — | 15:24 |
| Pocket Network | code search `org:pokt-network vite` → only Vite frontend-tool configs | no Vite blockchain | 15:48 |
| Chainstack | — | `chainstack.com/protocols` grep: no vite | 15:48 |
| chainid.network `chains.json` | — | **no Vite entry** | 15:24 |
| GoldRush/Covalent `api.covalenthq.com/v1/chains/` | — | **no Vite entry** | 15:25 |

### B3. Endpoint-discovery sources searched (negative or partial)

- **crt.sh:** full JSON for `%.vite.net` (verified names listed above; last node certs pre-2025), partial for `%.vitex.net` (`*.vitex.net`, `api.vitex.net`, `vitex.net`, `www.vitex.net`). `vitescan.io`, `vite.org`, `vitcscan.com`, `vitewallet.io`, `vite.org.cn` hit **HTTP 429** despite retries (raw: `child-a-crt-retries.txt`), a limitation.
- **api.certspotter.com:** `vite.org`/`docs.vite.org` (LE auto-renewals), `vite.io`, `viteview.xyz`; **empty arrays** for `vitescan.io`, `vitex.net` (raw: `child-a-certspotter.txt`).
- **DNS wordlist brute force** over rpc/ws/node*/api/gateway/snapshot/sbp/seed/boot*/… for `.vite.net`, `.vite.org`, `.vite.io`: only the known dead/static hosts resolve (raw: `child-a-dns-wordlist.txt`).
- **Passive DNS** (hackertarget hostsearch, rapiddns): additional hostnames `privacy.vite.net`, `test/www.vitescan.io`, `preview/testnet.vitcscan.com`; all resolve to the same dead/CF IPs (raw: `child-a-passive-dns.txt`).
- **GitHub code search** (`node.vite.net/gvite`, `ledger_getSnapshotChainHeight`, `48132`, `41420`, `bootnodes.vite.net`, `bootmainnet.json`, `node.vite.net:8483`, …): every hit is a dead-project client (wallet, explorer, SDK, proxy, dashboards) hardcoding `node.vite.net`/`buidl.vite.net`; no alternative mainnet RPC anywhere (raws: `child-a-gh-search1/2`, `child-a-govite-conf.txt`, `child-a-community-nodes.txt`).
- **Wayback/archive.today:** `config.vite.net` (nginx default), `node.vite.net` (nginx), `vitescan.io` last capture **2025-02-16**, `viteview.xyz` through **2026-01-31** (shell), `bootmainnet.json` **no captures**, tweet capture 2025-10-10 is a JS shell. archive.today has older vitescan captures only.
- **Telegram:** `t.me/s/Jeets_Token` full message list; official Vite channels not web-previewable (302). **X mirrors:** only live tweet is the 2025-05-22 migration announcement; the Oct-2025 airdrop tweet is **deleted** (syndication tombstone).
- **go-vite code/config:** `conf/node_config.json` → `BootSeeds: ["https://bootnodes.vite.net/bootmainnet.json"]`, `DashboardTargetURL: wss://stats.vite.net`, default RPC ports 48132/41420. Repo last commit **2024-09-26**; org's last real commits **2025-04-13/16**. No 2025–2026 mainnet activity reports; only a 2026 private-network bug report (issue #656).

---

## (c) EVIDENCE LIST (chain status timeline, URLs + dates)

1. **2025-02-09** — r/vitelabs (via Redlib): "Servers are updated… Services are now gradually coming back up… basic functions of ViteX and the wallet/app are back online. We are working on full node and MM mining rewards." → a real outage/recovery event weeks before delisting. <https://redlib.vanillax.me/r/vitelabs/comments/1ilobzo/servers_are_updated/>
2. **2025-02-16** — Last Wayback capture of `vitescan.io` (SPA shell; no data); no captures after (raw: `child-a-vitescan-captures.txt`).
3. **2025-02-24** — Binance delists VITE (low volume / insufficient development). <https://adbytes.media/index.php/blog/vite-labs-cancels-roadmap-after-binance-delisting-and-dwf-labs-mismanagement>
4. **2025-03-10** — Vite Labs closes its gateway (withdrawals); earlier than planned (parent; Cryptorank/Bitget).
5. **2025-03-27** — Vite Labs: funds lost to DWF market-making + delisting; "**will only maintain the network operation until it can no longer support it**"; **all roadmap plans canceled**; network in maintenance-only state. <https://www.bitget.com/news/detail/12560604667775> · <https://www.chaincatcher.com/article/2174470>
6. **2025-03-31** — Detail article: FDV ≈ $256,340; gateway shutdown 2025-03-10; "community-run gateways will continue." <https://adbytes.media/index.php/blog/vite-labs-cancels-roadmap-after-binance-delisting-and-dwf-labs-mismanagement>
7. **2025-04-13/16** — Last real GitHub activity in the `vitelabs` org (`vite-org-new`, `vite-web-wallet` "Update links"/"Update Explorer URL"; `explorer` push 2025-04-16). `go-vite` last commit 2024-09-26. Raw: `child-a-repo-commits.txt`, `child-a-govite-status.txt`.
8. **2025-05-22** — Migration announcement (the only vitelabs tweet still live): "…ongoing technical and security concerns affecting the native chain… Network instability: Ongoing performance and reliability issues on the Vite native chain, **including node and explorer disruptions**. Security concerns: Increasing technical vulnerabilities and degraded trust in core infrastructure." **No specific hack or protocol bug is named.** <https://x.com/vitelabs/status/1925499301314097170> (full text captured via fxtwitter; raw: `child-a-xmirrors.txt`)
9. **2025-05-30** — MEXC: "Due to **instability issues on the VITE mainnet, which often cause network disruptions**…" trading suspended, deposits closed, 100:1 swap to JEETS. <https://www.mexc.com/support/articles/17827791524492> · JEETS Telegram #5: "MEXC to Delist VITE Due to Blockchain Issues" (raw: `child-a-telegram-pages.txt`).
10. **2025-07-04** — r/vitelabs: "Vite is dead. I wouldn't expect much. Money gone. My wallet says 15 cents now but there's nowhere to send it anyway because Vite is dead." <https://redlib.vanillax.me/r/vitelabs/comments/1lriuq8/vite_wallet/>
11. **2025-10-03** — JEETS × VITE airdrop claim page (archived): hardcoded `SNAPSHOT_TEXT = "Snapshot (Vite Network): 11/11/25 00:00 (UTC)"`; page says "Eligibility is based only on holding Jeets and VITE / VX (Vite chain) at the snapshot moment… **No live checks here**"; submissions stored in Firebase (project `jeets-ai`); Vite address format `vite_[0-9A-Fa-f]{50}`. <https://web.archive.org/web/20251003122448id_/https://jeets.ai/airdrop_vite/> (raw: `child-a-jeets-airdrop-page.txt`, `child-a-jeets-scripts.txt`).
12. **2025-10-03** — JEETS Telegram forwards `x.com/vitelabs/status/1974080261454536967` ("Jeets airdrop for vite holders"). **The tweet is now deleted** (syndication `TweetTombstone`); Wayback capture 2025-10-10 contains no tweet text. Raw: `child-a-telegram-pages.txt`, `child-a-tweettext-search.txt`.
13. **2025-11-11 00:00 UTC** — Declared Vite-network snapshot moment. No public snapshot height/state file or claim-completion evidence found; `jeets.ai` currently has no address records.
14. **2026-02-08** — Last Jeets Telegram message (image); no chain-status posts.
15. **2026-05-29 / 2026-08-11** — go-vite issue #656 (private network coinbase bug) — the only recent repo issue; no mainnet-liveness reports. Raw: `child-a-issue656.txt`.

**Answer to "was there a hack?":** no public evidence of an exploit or post-mortem. The official language ("technical vulnerabilities", "security concerns", "recent technical incidents") is vague; the concrete documented events are **service outages/disruptions** (Feb 2025 server upgrade/outage, node/explorer disruptions) plus financial collapse after the Binance delisting (Feb 24) and DWF losses (Mar 2025).

**Last known snapshot height/date:** **not recoverable from any public source.** No public explorer/API survives; no archived data pages, no indexer, no provider. The only "chain-moment" date published is the JEETS snapshot moment 2025-11-11 00:00 UTC; by that time no public endpoint existed.

---

## (d) WHAT WOULD CHANGE THE VERDICT

1. **A reachable RPC** (any host:port returning a valid `ledger_getSnapshotChainHeight`/`ledger_getLatestSnapshotBlock`) — flips "unreachable" instantly. None was found after checking ~60 hostnames/IP patterns and all major RPC providers.
2. **A published snapshot height/block hash dated after Feb–May 2025** from the JEETS/JEETS-airdrop team or an SBP operator (e.g., their 2025-11-11 snapshot artifact) — would prove the chain (or a fork of it) was still producible. The airdrop verifying Vite balances at 2025-11-11 is circumstantial evidence the team had chain data, but it is not public and may be a frozen/archived dataset.
3. **Regional reachability**: if a user inside mainland China (or elsewhere) can load `vitescan.io` or any node, "globally dead" becomes "regionally reachable". Parent tested 6 non-CN check-host nodes; CN vantage not tested. Even then, an explorer UI ≠ an RPC endpoint.
4. **A hidden community node** not discoverable by CT/DNS/GitHub (e.g., an IP-only node known in a Telegram/Discord group) — possible but unindexed; would require insider knowledge.
5. **Official reversal**: a new Vite Labs/JEETS statement that the Vite mainnet is being restored (none found; jeets.ai is dead and the last tweet on the account related to Vite is the migration announcement).

---

## (e) EXPLICIT CONFIDENCE

- **"No publicly reachable Vite mainnet node/RPC as of 2026-10-03": ~97 %.** Evidence is exhaustive across DNS (CT + brute force + passive), HTTP/TCP probes (this host + 6 foreign check-host nodes), code (GitHub-wide search), archives (Wayback/archive.today) and all mainstream RPC providers. Residual 3 %: an IP-only or regionally-blocked node not present in any public index; crt.sh 429 limits for 5 domains.
- **"Chain halted / not producing publicly observable snapshots": ~80–85 %.** No observer has seen activity since ~Feb 2025; official statements describe disruptions, the team abandoned the chain in favor of Solana, SBPs had no funding and no monitoring, and no explorer/indexer/provider exists. Not certain because block production cannot be disproven from outside without a running peer, and the JEETS airdrop's 2025-11-11 "Vite Network snapshot" implies the team may have had access to *some* chain state (frozen or live) then.
- **"JEETS airdrop snapshot = 2025-11-11 00:00 UTC": certain** (hardcoded text in the archived official claim page), **but snapshot height is unknown** and no public proof of airdrop execution was found.
- **"No specific publicized hack": high (~90 %)** — searches found only vague official wording and service-outage narratives; absence of a post-mortem doesn't exclude an undisclosed exploit.

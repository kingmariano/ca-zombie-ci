# ShimmerBridge — Remote side (ShimmerEVM) & shutdown timeline

**Child A report — read-only investigation**
Date: 2026-10-13 · Analyst: Child A subagent · Scope: ShimmerEVM (chain id **148**, LayerZero v1 EID **230**) remote side of ShimmerBridge, the WrappedTokenBridge at `0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898`, and the Shimmer sunset timeline.

> **Ground rules observed:** read-only (no transactions signed/sent), no secrets written to files, writes confined to `shimmerbridge/analysis/childA/`, no git add/commit/push, no subagents, light network probes only.

---

## 1. Executive summary

1. **The remote side is permanently dead.** ShimmerEVM (chain 148) stopped block production with the rest of Shimmer on **2026-09-30**; all official RPCs are gone (Cloudflare 502 / 404 / thirdweb `-32603`), the EVM explorer now 302-redirects to the L1-only Tangle Explorer, and even the L1 halted (final milestone **24,359,373**, ~**07:44 UTC** per secondary source). **Nothing can be sent from chain 148 / EID 230 anymore** (Section 6).
2. **Exact last ShimmerEVM block height/time is NOT publicly retrievable anymore.** Every archive path checked (Wayback, archive.today, Blockscout registry, thirdweb, alternate RPCs, indexers) failed. Best available: on-chain anchors from LayerZero Scan (block **8,026,990** at **2026-08-30 22:57:18 UTC** was the last bridge message's block) plus the L1 halt record. A linear estimate puts the final EVM block at **≈ 8.044–8.05M** — **UNVERIFIED** (Section 3). The L1-side proof of the 2026-09-30 halt **is** captured (final milestone 24,359,373; last absolute timestamped milestone 24359372 "Sep 30, 2026 3:44 AM" in the scrape browser's timezone).
3. **WrappedTokenBridge source code identified and saved.** The deployed bridge is LayerZero's *Wrapped-Asset-Bridge*:
   - `github.com/LayerZero-Labs/wrapped-asset-bridge` @ commit **`d89dc70dbfb9576601e4f9d69a4b2c210c256afd`** (2023-12-05). Saved to `src/wrapped-asset-bridge/` (WrappedTokenBridge.sol, OriginalTokenBridge.sol, TokenBridgeBase.sol, WrappedERC20.sol, wrappedTokens/*, interfaces, test harness).
   - **Proven identical** (whitespace-normalized `diff` = IDENTICAL) to the on-chain verified Ethereum deployment source already stored in `analysis/src-eth/` for `TokenBridgeBase.sol` and `OriginalTokenBridge.sol`. This is the same codebase family that ran on ShimmerEVM (mint/burn side).
   - Bridge frontend/SDK: `github.com/iotaledger/iota-evm-bridge` @ **`b91473a348594f54943c9a626cb908c491dd2225`** ("archive repository and point to the monorepo", 2025-07-23). Contracts were later referenced from the `iotaledger/iota` monorepo (`apps/evm-bridge`); the repos `iotaledger/evm-bridge`, `iotaledger/evm-bridge-contracts`, `iotaledger/shimmerbridge`, `iotaledger/bridge-contracts` **do not exist** (HTTP 404).
4. **LayerZero Scan still indexes the bridge as “ShimmerBridge”.** All 8 remote pathways verified for EID 230 in both directions: **101 Ethereum, 102 BSC, 106 Avalanche, 109 Polygon, 110 Arbitrum, 111 Optimism, 112 Fantom, 184 Base**.
5. **No pending/undelivered PT_UNLOCK messages found.** The last 100 messages in each direction all show source/destination status `SUCCEEDED`/`SUCCEEDED`; status queries (`INFLIGHT`, `CONFIRMING`, `PAYLOAD_STORED`, `FAILED`, `BLOCKED`) returned **zero** EID-230-related messages. The last observed outbound message was **2026-08-30 22:57:18 UTC** (nonce 3890, EID 230 → Polygon), delivered 23:43:39 UTC — i.e. it still went through after the announced Aug 29 bridge end.
6. **Value context:** DefiLlama protocol “shimmerbridge” (tokens bridged via shimmerbridge.org) shows **$180.3k locked on 2026-08-29**, **$189.3k on 2026-09-30**, **$185.4k today** across the 8 origin chains. Per-token wrapped supplies on ShimmerEVM are **not recoverable** (explorer DB gone). Chain-level DeFi TVL on ShimmerEVM was ~$575k on Sep 30 and flat-lined to $0 by Oct 6.
7. **User access:** official statement — *“After this date, there is no viable way to bridge assets in or out of Shimmer”* (bridge shut down Aug 29, 2026); farewell page: *“Asset bridging via the LayerZero bridge ended on August 29, 2026.”* Anyone who did not bridge back before then is stranded: unlock requires an EID-230 message that can no longer be produced.

---

## 2. Shutdown timeline (primary-source backed)

| Date (2026) | Event | Source |
|---|---|---|
| 2023-09-28 | ShimmerEVM launches | @theiotafeed summary; blog.shimmer.network |
| 2023-12-27 | “LayerZero Integrates with ShimmerEVM” | blog.shimmer.network (article footer) |
| 2025-07-23 | `iotaledger/iota-evm-bridge` archived → monorepo `apps/evm-bridge` | repo commit b91473a |
| **2026-07-23** | **“Shimmer is Sunsetting”** published (TL;DR: bridging ends Aug 29, full sunset Sep 30) | blog.shimmer.network (WB capture 20260930124706) |
| 2026-07-24 | LayerZero “Support Update” published (later updated Aug 21, Sep 9, Sep 25) | layerzero.network/blog/support-update-july-24-2026 |
| **2026-08-28** | LayerZero DVN + executor support for **Shimmer ends** (listed effective date) | LayerZero support-update table |
| **2026-08-29** | **Bridging shut down** — “no viable way to bridge assets in or out of Shimmer” | blog.shimmer.network |
| 2026-08-30 22:57 UTC | Last observed outbound bridge message from EID 230 (230→Polygon, nonce 3890), delivered 23:43 UTC | LayerZero Scan API |
| 2026-09-22 | Old EVM explorer still captured as a 302 redirect to `explorer.shimmer.network` | Wayback snapshot 20260922201938 |
| **2026-09-30 ~07:44 UTC** | **L1 + ShimmerEVM halt.** Final L1 milestone **24,359,373**; last L1 tx 02:05 UTC | @theiotafeed post (2026-09-30T16:55Z); Tangle Explorer frozen at index 24359373 |
| **2026-09-30** | Official farewell: “Shimmer L1 and ShimmerEVM have officially stopped block production” | shimmer.network + blog.shimmer.network (live) |
| 2026-10-05/06 | DefiLlama ShimmerEVM chain TVL → $0 | DefiLlama API |

---

## 3. Last-block evidence

### 3.1 Shimmer L1 — captured (proves the 2026-09-30 halt)

- **Tangle Explorer (still up, serving frozen data)** — `https://explorer.shimmer.network/` rendered 2026-10-13:
  - Latest milestone: **index 24359373** (block id `0x4541f53be0d52c3c50a70548c8e4e11664eb9fb40be4b54f42da02d68f2df504`, milestone id `0x327a7aa3db2a2de9ee02c34660e83fe85b02e117a7558292aab6048f617db5cd`). This row displays a broken relative timestamp **“8.32s ago”** — identical across two scrapes taken minutes apart, confirming the explorer is frozen, not live.
  - Last milestone with an **absolute** timestamp: **24359372 = “2026-09-30 03:44:04”**; then 24359371 (03:43:59), 24359370 (03:43:54), … every ~5 s (row list).
  - Milestone page for 24359372 states: *“Wednesday, September 30, 2026 **3:44 AM** – 13 days ago”*, “Confirmed”, referenced blocks = 20.
  - Timezone caveat: the scraper's headless browser rendered 12-hour AM/PM (US locale). The secondary source below says the halt was at **07:44 UTC**; 03:44 AM at UTC−4 == 07:44 UTC, so the display timezone is almost certainly US Eastern and the halt time **07:44 UTC** stands. (If the display were UTC, the halt would be 03:44 UTC — flagged as an open question.)
- **@theiotafeed (X) post 2026-09-30 16:55 UTC** (captured via Firecrawl):
  - *“The Shimmer network came to a halt at **07:44 UTC** today, and ShimmerEVM has stopped too.”*
  - *“End: 30 September 2026, at **milestone 24,359,373**, the network’s final confirmation signal. Its last transaction was confirmed at **02:05 UTC**.”*
  - Matches the explorer index exactly (milestone 24,359,373). Secondary source, but precise and consistent.

### 3.2 ShimmerEVM — exact last block NOT recoverable; anchored best-estimate

No surviving source served EVM block data (see attempts table §7). What we do have:

| Anchor | ShimmerEVM block | UTC time | Source |
|---|---|---|---|
| Inbound LZ message delivered on ShimmerEVM (BSC→230 nonce 9993) | 8,020,543 | 2026-08-21 01:27:23 | LZScan `destination.tx.blockNumber` |
| Last outbound LZ message from ShimmerEVM (230→Polygon nonce 3890) | 8,026,990 | 2026-08-30 22:57:18 | LZScan `source.tx.blockNumber` |

Derived average block interval (multiple message pairs, Jul–Aug 2026): **≈ 133–157 s/block (~149 s mean)**, i.e. not a fixed fast cadence in the sampled window.

Linear extrapolation from block 8,026,990 (Aug 30 22:57 UTC) to the halt at ~Sep 30 07:44 UTC (+2,623,860 s ⇒ ≈ +17.5k blocks) gives a **rough** final height of **≈ 8,044,000–8,046,000**. **UNVERIFIED** — treat as an order-of-magnitude estimate only; the block cadence may have changed, and the halt time has a possible ±4 h timezone ambiguity.

> If a definitive final EVM block is required, the only remaining path is a ShimmerEVM state/chain snapshot held privately by the IOTA Foundation/validators or a node's blocklog on an old datadir — none is public as of 2026-10-13.

---

## 4. Bridge contracts — sources, identity proof, and contents

Saved to `src/` (see also `src/SOURCES.md`):

| Repo | Commit | Date | Notes |
|---|---|---|---|
| `LayerZero-Labs/wrapped-asset-bridge` | `d89dc70dbfb9576601e4f9d69a4b2c210c256afd` | 2023-12-05 | **The deployed bridge code.** WrappedTokenBridge.sol (remote mint/burn side), OriginalTokenBridge.sol, TokenBridgeBase.sol, WrappedERC20.sol, wrappedTokens/{USDC,USDT,WETH}.sol, interfaces/{IWrappedERC20,IWETH}.sol, test harnesses |
| `iotaledger/iota-evm-bridge` | `b91473a348594f54943c9a626cb908c491dd2225` | 2025-07-23 | Frontend + SDK only (no `.sol`). Archived; README points to `iotaledger/iota` `apps/evm-bridge` |
| `LayerZero-Labs/lz-address-book` | `c7c7c8f1cde9612fee901d81bffd1c9cb7f724d3` (HEAD 2026-10-13) | — | Contains `shimmer-mainnet` only as **EndpointV2 EID 30230** + DVN registrations; the bridge itself used **V1 EID 230** |

Identity check performed: on-chain verified flattened source from the Ethereum OriginalTokenBridge deployment (`analysis/src-eth/`) vs the repo, whitespace-normalized: `TokenBridgeBase.sol` **IDENTICAL**, `OriginalTokenBridge.sol` **IDENTICAL**. Therefore the ShimmerEVM side was the repo's `WrappedTokenBridge.sol` (lock/mint counterpart; burns wrapped tokens, emits `PT_UNLOCK` payloads).

**LayerZero endpoint on ShimmerEVM:** the bridge is LayerZero EndpointV1 `LzApp`; EndpointV1 is deployed at the canonical address `0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675` on EVM chains (same address pattern as the bridge `0x9C6D…7898` deployment). The endpoint's operation on EID 230 is confirmed by LZScan message records, but the **address itself could not be re-verified on chain 148 post-mortem** — mark **UNVERIFIED** for the exact on-chain instance.

---

## 5. Remote-side state at shutdown

- **Wrapped token supplies / holders:** not recoverable. The Blockscout instance is gone (DB not public; API redirects; no archived supply pages). **UNVERIFIED / N/A.**
- **TVL proxy — DefiLlama protocol `shimmerbridge`** (“Tokens bridged via shimmerbridge.org”; counts value still locked on the origin chains):

| Origin chain | 2026-08-29 | 2026-09-30 | 2026-10-13 (today) |
|---|---|---|---|
| Ethereum | $72,685 | $78,048 | $75,715 |
| BSC | $24,262 | $25,435 | $25,134 |
| Avalanche | $56,845 | $57,914 | $57,616 |
| Optimism | $9,841 | $10,525 | $10,038 |
| Polygon | $8,392 | $9,090 | $8,489 |
| Arbitrum | $7,126 | $7,139 | $7,129 |
| Fantom | $899 | $963 | $1,036 |
| Base | $201 | $218 | $206 |
| **Total** | **$180,251** | **$189,332** | **$185,363** |

  Caveats: DefiLlama-tracked tokens only (methodology “tokens bridged via shimmerbridge.org”); it reflects locked originals, not the wrapped supply frozen on the dead chain; values still update with prices. Chain-level DeFi TVL of ShimmerEVM (different metric): ~$574.7k on 2026-09-30 → $5.7k on Oct 5 → $0 from Oct 6.
- **Configured remote chains (pathways) — verified both directions on LZScan:** EIDs 101/102/106/109/110/111/112/184 (Ethereum, BSC, Avalanche, Polygon, Arbitrum, Optimism, Fantom, Base). This matches the 8 primary chains known from the Ethereum-side analysis.
- **Pending / undelivered PT_UNLOCK messages:** **none found.**
  - Last 100 messages with `srcChainIds=230`: all `(SUCCEEDED, SUCCEEDED)`; most recent = nonce 3890 → Polygon, 2026-08-30 22:57:18 UTC (delivered 23:43:39 UTC); the sample reaches back to 2026-06-03.
  - Last 100 messages with `dstChainIds=230`: all `(SUCCEEDED, SUCCEEDED)`; most recent inbound = BSC nonce 9993, 2026-08-21 01:27:03 UTC; sample back to 2026-04-04.
  - `/messages/status/{INFLIGHT,CONFIRMING,PAYLOAD_STORED,FAILED,BLOCKED}` — zero EID-230-related rows.
  - Caveat: LZScan windows are limited (top-100 per query / recent global status pages); an undelivered message older than the sampled window cannot be strictly excluded, but none is visible, and the last observed messages were all delivered — suggesting orderly close-out, not a stuck queue.
- **Statements about user access:** sunsetting article — *“Bridging assets from Shimmer will no longer be possible after August 29, 2026”*; *“Saturday, August 29, 2026: LayerZero external liquidity bridge for ShimmerEVM is shut down. After this date, there is no viable way to bridge assets in or out of Shimmer.”* Farewell page — *“Asset bridging via the LayerZero bridge ended on August 29, 2026, and network maintenance, block explorers, and services have concluded.”* No explicit per-user “you have lost your tokens” phrasing by the Foundation, but the functional consequence is identical.

---

## 6. What remains possible on the remote side today

**Nothing, functionally:**

1. **No EVM blocks can be produced or read:** chain 148 halted 2026-09-30. Verified: `json-rpc.evm.shimmer.network` → 502/POST 404; `evm.shimmer.network` → 502; `148.rpc.thirdweb.com` answers `eth_chainId`/`net_version`/`web3_clientVersion` from a façade but every block read fails `-32603`; drpc/ankr/blastapi/blockpi/publicnode/Blockscout mirrors all dead (§7).
2. **No message can be sent from EID 230.** `WrappedTokenBridge.bridge()`/burn → `PT_UNLOCK` requires a live ShimmerEVM transaction; impossible. Endpoint V1 on ShimmerEVM no longer exists (origin decommissioned).
3. **No PT_UNLOCK can be relayed even if one existed:** LayerZero DVN + executor support for Shimmer ended **2026-08-28**; Shimmer-side infra is gone. (The last message on Aug 30 was delivered, so relay infra lingered briefly — but it is gone now.)
4. **Unlocking originals on the 8 chains is impossible:** `OriginalTokenBridge._nonblockingLzReceive` accepts `PT_UNLOCK` **only from a LayerZero message whose srcEid is 230**. With no chain 148 and no EID-230 messages ever again, the locked originals cannot be released through the bridge.
5. **What still exists as artifacts:** LZScan records of all bridge messages; Wayback captures of the explorer UI (no data); the frozen L1 explorer (Tangle Explorer); DefiLlama TVL history; archived announcements. I.e. forensic evidence only.

> **Net effect:** wrapped tokens on the dead ShimmerEVM are unredeemable, and the original tokens locked in the 8 `OriginalTokenBridge` contracts are permanently stranded as far as standard bridge mechanics go — unless the IOTA Foundation/community performs an out-of-band recovery (no public plan/path was found; the sunset materials direct users to have bridged out before Aug 29).

---

## 7. Attempts log (URL · status · result)

| # | Target | Status | Result |
|---|---|---|---|
| 1 | `https://148.rpc.thirdweb.com` `eth_chainId` | 200 | `0x94` (=148) — façade alive |
| 2 | same, `eth_blockNumber` | 200 | `-32603 "We are not able to process your request at this time…"` |
| 3 | same, `eth_getBlockByNumber("latest")` | 200 | `-32603` |
| 4 | same, `eth_syncing` | 200 | `-32603` |
| 5 | same, `web3_clientVersion` / `net_version` | 200 | `thirdweb/1.0` / `148` |
| 6 | same, `eth_getBlockByNumber 0x7A1200` and `0x7999A0` | 200 | `-32603` (no historical blocks either) |
| 7 | `https://json-rpc.evm.shimmer.network` GET / POST | 502 / 404 | CF 502; POST "404 page not found" (origin removed) |
| 8 | `https://evm.shimmer.network` | 502 | CF 502 |
| 9 | `https://api.evm.shimmer.network` (DNS exists) | 502 | CF 502 |
| 10 | `https://blockscout.evm.shimmer.network` (DNS exists) | 502 | CF 502 |
| 11 | `https://explorer-api.evm.shimmer.network` (DNS exists) | 502 | CF 502 |
| 12 | `https://shimmer-evm.drpc.org` | 200 | `{"message":"Not Found"}` |
| 13 | `https://rpc.ankr.com/shimmer_evm` (+ `/KEY`) | 403 | "API key is not allowed to access blockchain" |
| 14 | `https://shimmer-evm.public.blastapi.io` | 000 | no response |
| 15 | `https://shimmer.blockpi.network/v1/rpc/public` | 200 | `{"code":-32000,"message":"unknown host"}` |
| 16 | `https://shimmer-evm.rpc.thirdweb.com` | 200 | `"Invalid chain"` |
| 17 | `https://shimmer-evm-rpc.publicnode.com`, `shimmer.publicnode.com` | 404 | not hosted |
| 18 | `https://rpc.shimmer.network` | 000 | DNS fail |
| 19 | `https://shimmer-evm.blockscout.com` | 404 | default backend 404 |
| 20 | chainlist eip155-148 (chainid.network raw JSON) | 200 | only the official (dead) RPC + old explorer listed |
| 21 | `https://explorer.evm.shimmer.network/` (live) | 302 | → `https://explorer.shimmer.network/` |
| 22 | `.../api/v2/stats`, `.../api/v2/blocks` (live) | 302 | API backend retired; redirects to L1 explorer |
| 23 | Wayback CDX (domain explorer.evm.shimmer.network) | 200 | 16 homepage captures in 2026: Jan–Jul 200; **2026-09-22 → 302**; no data-page captures after 2024 |
| 24 | Wayback snapshot 2026-07-11 homepage | 200 | SPA shell; `__NEXT_DATA__.apiData:null` — **no block heights** |
| 25 | Wayback snapshot 2026-09-22 | 302 | Location: `https://explorer.shimmer.network/` |
| 26 | Wayback `/api/v2/*` captures | 200 | only 2024-02-10 / 2024-09-11 (block 6,008,316 era); none 2025–26 |
| 27 | Wayback `api-docs` capture 2026-04-22 | 200 | docs page only, no data |
| 28 | `archive.ph` newest of old explorer | 404 | no snapshot |
| 29 | `explorer.evm.testnet.shimmer.network/api/v2/stats` | 403 | blocked/no data |
| 30 | Blockscout MCP `get_chains_list("shimmer")` (unlock + chains registry) | 200 | **no Shimmer chain registered** → no `direct_api_call` possible |
| 31 | `chains.blockscout.com/api/chains` | 200 | no shimmer entry |
| 32 | GoldRush `block_heights` for `shimmer*` | error | chain unsupported by GoldRush |
| 33 | DefiLlama `protocol/shimmerbridge`, `v2/historicalChainTvl/ShimmerEVM` | 200 | TVL history captured (§5) |
| 34 | `https://explorer.shimmer.network/` (new Tangle Explorer) | 200 | frozen L1 data: final milestone **24359373**; last absolute ts **24359372** Sep 30 |
| 35 | milestone page `…/block/0xc092eaf…` | 200 | "Wednesday, September 30, 2026 **3:44 AM** – 13 days ago", Confirmed |
| 36 | `https://explorer-api.shimmer.network/` | 200 | `{"name":"explorer-api","version":"4.1.1"}` — but route probes (`/api/v1/*`, `/milestones`, `/core/v2/*`, …) all 404; block pages show "Pending" for the last milestone |
| 37 | `https://forum.iota.org/search.json` | 000 | host unreachable |
| 38 | Reddit search JSON (r/IOTA) | blocked | bot-block page |
| 39 | `t.me/s/ShimmerNetwork` | 200 | dormant channel (2022-era posts only) |
| 40 | `scan.layerzero-api.com/v1/openapi` | 200 | full route list obtained |
| 41 | LZScan `messages/latest?srcChainIds=230&limit=100` | 200 | last outbound 2026-08-30 22:57:18 UTC; all SUCCEEDED |
| 42 | LZScan `messages/latest?dstChainIds=230&limit=100` | 200 | last inbound 2026-08-21 01:27:03 UTC; all SUCCEEDED |
| 43 | LZScan pathway matrix 230↔{101,102,106,109,110,111,112,184} | 200 | all 16 directions present |
| 44 | LZScan `messages/wallet/0x9C6D…` | 404 | "Message not found for srcAddress…" (that older path doesn't index OApp addresses; `/messages/latest` does) |
| 45 | LZScan `messages/status/{INFLIGHT,CONFIRMING,PAYLOAD_STORED,FAILED,BLOCKED}` | 200 | zero EID-230-related messages |
| 46 | `layerzero.network/blog/support-update-july-24-2026` | 200 | Shimmer row: effective **Aug 28, 2026** (DVN/executor wind-down) |
| 47 | `blog.shimmer.network/shimmer-is-sunsetting` live + Wayback capture 20260930124706 | 200 | farewell text + original Jul 23 article with deadline language |
| 48 | `shimmer.network` + `/evm` live + Wayback 2026-09-30 capture | 200 | shutdown notices |
| 49 | Wayback `shimmer.network/faqs` 2026-06-17 | 200 | generic FAQ (not sunset-specific) |
| 50 | GitHub repo existence checks (`iotaledger/evm-bridge`, `…-contracts`, `shimmerbridge`, `bridge-contracts`) | 404 | do not exist |
| 51 | Clone `LayerZero-Labs/wrapped-asset-bridge` | 200 | commit d89dc70…; Solidity sources saved |
| 52 | Diff verified ETH source vs repo (whitespace-normalized) | — | IDENTICAL (TokenBridgeBase, OriginalTokenBridge) |
| 53 | Clone `iotaledger/iota-evm-bridge` | 200 | b91473a…; frontend/SDK only; archived |
| 54 | Clone `LayerZero-Labs/lz-address-book` | 200 | `shimmer-mainnet` = EID 30230 (V2) + DVNs; no V1 endpoint data |
| 55 | X `@theiotafeed` post 2105340748090822954 (Firecrawl) | 200 | halt 07:44 UTC; final milestone 24,359,373; last tx 02:05 UTC |
| 56 | X `@shimmernet` profile (Firecrawl) | 200 | no posts returned (login/anti-bot) |
| 57 | crt.sh subdomain enumeration (2 attempts) | 502 | service down; hostname checks done via DNS instead |
| 58 | `status.shimmer.network`, `bridge.shimmer.network` | 000 | no DNS records; no Wayback captures |
| 59 | `status.iota.org` | 200 | live IOTA status page; no Shimmer history exposed |

Other indexers (Dune, Bitquery, Tokenview, OKLink etc.): no public ShimmerEVM dataset surfaced in searches; GoldRush (the one queryable here) confirmed unsupported. Not pursued further as no viable path was identified.

---

## 8. Open questions / explicitly UNVERIFIED

- **Exact final ShimmerEVM block number & timestamp** — not found; estimate ≈8.044–8.05M (method §3.2). UNVERIFIED.
- **Halt timezone detail:** 07:44 UTC per @theiotafeed; explorer shows "3:44 AM" in the scrape browser's locale (consistent with UTC−4). If the explorer display had been UTC, the halt would be 03:44 UTC. Either way the halt was **2026-09-30**.
- **LayerZero EndpointV1 contract address on 148** — assumed canonical `0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675`; not re-verified on-chain (chain dead). UNVERIFIED for that specific chain.
- **Wrapped token supplies / full TVL at shutdown** — not recoverable from public data; DefiLlama protocol TVL is a proxy for locked originals (§5).
- **Completeness of “no pending messages”** — bounded by LZScan’s query windows (top-100 / recent status lists); no contrary evidence found but not exhaustive.

---

## 9. Evidence index (files under `evidence/`)

- `thirdweb-chainid.json`, `thirdweb-blocknumber.json`, `thirdweb-latest-block.json`, `thirdweb-methods.txt` — thirdweb façade + exact errors
- `alt-rpcs.txt` — all alternate RPC probe results
- `cdx-*.json` — Wayback CDX (domain, API prefix, 2026 captures, new explorer)
- `wb-home-20260711.html`, `wb-home-20260615.html`, `wb-home-20260922.headers/.body` — archived explorer captures
- `new-explorer.html`, `new-explorer-env.js`, `explorer-api-probe-*.txt`, `core-*.txt` — Tangle Explorer + API probes
- `blog-sunsetting.html/.txt` (farewell), `blog-sunsetting-original2.html/.txt` (original Jul 23 article), `shimmer-home-20260930.html/.txt` — sunset notices
- `shimmer-faq-20260617.html/.txt` — archived FAQ
- `lz-blog-jul24.html/.txt` — LayerZero support-update post
- `lzscan-src230.json`, `lzscan-dst230.json`, `lzscan-summary.json`, `lzscan-status-*.json` — bridge message records (from/to EID 230)
- `llama-shimmerevm-tvl.json`, `llama-shimmerbridge.json.gz`, `defillama-shimmerbridge-tvl-extract.json` — TVL history
- `chainlist-148.json`, `crtsh-shimmer.json` + `crtsh2.json` (crt.sh 502s), `archiveph-home.html`, `reddit-*.json` (bot-blocked), `tg-ShimmerNetwork.html` (dormant channel), `live-oldexplorer.html` (redirect result) — attempt records
- `tangle-explorer-final-milestones-20261013.md`, `x-theiotafeed-post-20260930.md` — curated transcriptions

Sources saved under `src/` with repo commits recorded in `src/SOURCES.md`.

# Serum v3 (H-22) — enumeration & measurement methods log (dead ends + what worked)

All read-only. Secrets never printed. Captured 2026-10-04. Raw logs: `probe_endpoints.log`, `probe_endpoints2.log`, `probe_endpoints3.log`, `dune_probe.py`, `bitquery_probe.py`, `bq*.json`, `fetch_markets*.log`, `parse_summary*.log`.

## A. `getProgramAccounts` routes (all FAILED for Serum v3)

| Route | Exact result |
|---|---|
| `https://api.mainnet-beta.solana.com` gPA (dataSize 388 + memcmp flags=3) | `-32010 KEY_EXCLUDED_FROM_SECONDARY_INDEX` (program key removed from secondary index) |
| `https://solana-rpc.publicnode.com` gPA | HTTP 403 `Indexed requests require a personal token. Get one at: https://www.allnodes.com/publicnode` |
| `https://free.rpcpool.com`, `https://solana-mainnet.rpcpool.com` gPA | HTTP 403 `{"code":403,"message":"Access forbidden"}` |
| `https://api.metaplex.solana.com`, `https://rpc.hellomoon.io` | DNS NXDOMAIN (hosts gone) |
| `https://solana.public-rpc.com` | TLS `certificate verify failed: self-signed certificate` |
| `https://ssc-dao.genesysgo.net` | non-JSON body (dead) |
| `https://1rpc.io/solana` | HTTP 400 `unknown network` |
| `https://solana.drpc.org` / `https://lb.drpc.org/ogrpc?network=solana&dkey=…` | HTTP 400 `chain is not available on free plan` |
| `https://rpc.ankr.com/solana` and `/solana/$ANKR_API_KEY` | HTTP 403 `API key is not allowed to access blockchain` |
| Alchemy `ALCHEMY_API_KEY` | HTTP 429 `Monthly capacity limit exceeded` |
| Alchemy `ALCHEMY_API_KEY_2` | HTTP 403 `SOLANA_MAINNET is not enabled for this app` |
| Alchemy **MCP** `solana_getProgramAccounts` (all 5 apps via `list_apps`/`select_app`) | 429 `Monthly capacity limit exceeded` on `solana_getVersion`/gPA for every app |
| `QUICKNODE_API_KEY` | value is an Ethereum QuickNode hostname, no Solana endpoint |
| `https://solana.api.onfinality.io/public` | HTTP 429 (rate-limited), gPA untestable |
| `https://solana-mainnet.gateway.tatum.io` | getVersion OK (4.2.2); gPA `-16401 Method 'getProgramAccounts' is available for paid plans only` |
| `https://solana-mainnet.blastapi.io`, `rpc.coinsdo.net/solana`, `solana-mainnet.rpc.extrnode.com`, `solana.mathwallet.xyz`, `solana-mainnet.4everland.org`, `solana.rpc.grove.city`, `solana-mainnet.nodereal.io` | DNS NXDOMAIN / 422 |
| `https://svc.blockdaemon.com/...`, `https://mainnet.helius-rpc.com` | HTTP 401 (key required) |
| `https://api.solana.fm/v0|v1/accounts` | HTTP 502 (no program-enumeration API) |
| `BLOCKPI_RPC_URL` + `/solana` | value is an Ethereum BlockPI endpoint (`Method not found`) |

**Conclusion:** no reachable keyless route performs gPA on this program. Non-gPA methods (`getAccountInfo`, `getMultipleAccounts`, `getTokenAccountBalance`, `getSlot`, `getEpochInfo`, `getTransaction`) work on `api.mainnet-beta.solana.com`.

## B. Indexer/API routes

| Route | Result |
|---|---|
| Dune API (`DUNE_API_KEY`): create query + execute | HTTP 403 `Your account is read-only. Upgrade to create content or run queries.` — cannot run SQL; Solana information_schema unreachable |
| Bitquery v2 (`streaming.bitquery.io/graphql`, `BITQUERY_ACCESS_TOKEN`) | **Works** for realtime Solana cubes (Instructions, DEXPools, DEXTrades, …). Retention for Serum program starts `2026-10-04T04:21:52Z` only. `DEXPools` has **no** Serum rows; `Data` filters (`is`, `startsWith`) work |
| Bitquery v1 (`graphql.bitquery.io`) — historical instructions | HTTP 403 `access restricted: your plan only allows "realtime", but the request uses "archive:solana:instructions"` → no historical enumeration |
| Post-hoc: `startsWith` filter for InitializeMarket (`0000000000`) returned 0 rows (no archive) |
| Allium CLI | not installed; no `~/.allium/credentials` |
| GitHub code search (MCP) | used to locate the DefiLlama adapter `projects/serum.js` |

## C. Working enumeration route (what we used)

1. **Registries (fallback route e):**
   - `https://unpkg.com/@project-serum/serum@latest/lib/markets.json` (npm package; 276 entries, **168** with `programId == 9xQe…`).
   - `https://raw.githubusercontent.com/solana-labs/token-list/main/src/tokens/solana.tokenlist.json` (archived; 13,644 tokens, **365 unique** `extensions.serumV3Usdc`/`serumV3Usdt` market refs; 234 not in npm list).
   - Local copies: `/tmp/opencode/serum_npm_markets.json`, `/tmp/opencode/solana_tokenlist.json`, `/tmp/opencode/tokenlist_serum_markets.json`.
2. **Union** = 402 unique addresses → `getMultipleAccounts` (base64) in 100-key chunks on `api.mainnet-beta.solana.com`; parse 388-byte accounts per OpenBook v1 offsets (flags@5, nonce@45, mints@53/85, vaults@117/165, deposits@149/197, fees@157/205, req_q@221, event_q@253, bids@285, asks@317, lots@349/357, fee_rate_bps@365, referrer@373). Result: **398 initialized (flags&3==3), 4 closed/non-market, 0 disabled**.
   - Scripts: `fetch_markets.py` → `serum_v3_markets_raw.json`; `parse_summary.py` (DefiLlama prices via `coins.llama.fi/prices/current/solana:<mint>`) → `serum_v3_markets.json/.csv`, `serum_v3_summary_raw.json`.
3. **Live census supplement:** Bitquery realtime `Instructions` where `Program.Address == 9xQe…` and `Data == "000e000000"` (CloseOpenOrders, discriminator 14); paginated 10k/page (`bq_harvest.py`). 15 instructions, 13 market candidates, 2 not in the union. (`bq_markets_close.json`.)
4. **Rent accounting:** `serum_v3_rent.py` re-fetched 398 markets + 1,592 sub-accounts + 796 vaults (base64 lamports/sizes). `serum_v3_final.py` computes per-mint totals, identity checks, DL comparison and corrected rent (wSOL vault balances excluded from rent).
5. **Spot checks:** `serum_v3_spotcheck.py` re-read top-4 markets' vaults via `getTokenAccountBalance` (8/8 match) + authority accounts + sub-account lamports (`serum_v3_spotcheck.json`).

## D. Notes / gotchas

- The solana-labs token-list registry is spam-heavy: many of the 234 added markets pair a fake mint with USDC/SOL; their vaults hold only worthless tokens, so they add ~$0 (useful for count/completeness only).
- Every one of the 398 markets satisfies `vault = deposits + fees + pc rebates` exactly except 54 sides with small positive donations.
- The DefiLlama adapter (`projects/serum.js`, saved as `defillama_serum_adapter.js`) sums `deposits + fees` over **all** 388-byte accounts using its own gPA; that is why its number ($17.13M) exceeds the union measurement ($13.87M deposits+fees / $14.15M vaults). The difference (~$3.0M) is markets absent from both registries (proof: STNK first appears in DL's series on 2024-11-27).
- 2026 "activity" on the program is entirely `CloseOpenOrders` rent reclamation via CPI from programs `72K97smK…`/`22Y43yTVx…`, not trading.
- Fee-sweeper account `DeqYsmBd9…` does **not** exist on-chain (key possession unknown), so accrued fees are not provably sweepable; disable authority `5ZVJgw…` and upgrade authority `6XvcBmET…` are system EOAs holding 0.194 SOL / 0.0025 SOL.
- Do not re-investigate gPA on the listed public endpoints: all exact errors above were reproduced on 2026-10-04; a paid gPA-capable RPC (or DefiLlama's own connection) is required to enumerate the remaining unseen markets.

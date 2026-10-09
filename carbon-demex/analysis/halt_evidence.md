# C2-32 Carbon (carbon-1) — halt evidence (read-only, 2026-10-09)

**Verdict: the chain is halted at height 100,279,059 (2026-09-25T20:01:25.423995619Z) and has been
frozen for ~13.8 days at measurement. No transaction, governance vote, staking op, IBC packet or module
call can execute today.**

## 1. Team node says frozen (primary evidence)

`GET https://tm-api.carbon.network/status` (Switcheo-labs RPC, moniker `berryfield`), fetched repeatedly
2026-10-09 07:33–14:44 UTC:

```json
"latest_block_height": "100279059",
"latest_block_time": "2026-09-25T20:01:25.423995619Z",
"earliest_block_height": "95248072",
"catching_up": false,
"voting_power": "0"
```

A `catching_up=false` node reporting a 14-day-old head is a halted chain, not a syncing node.
The node runs `carbond 2.84.0` (commit `5381f6af…`, Go 1.22.11, CometBFT 0.38.19) — the last release
tagged on GitHub (2026-09-23), two days before the halt.

## 2. The team's API is dead behind an nginx cache

`https://api.carbon.network` returns 200 only for a handful of exact URLs that were cached before the
halt; every cache-busting variant 502s:

| route | exact URL | `?cb=<rand>` |
|---|---|---|
| `/cosmos/staking/v1beta1/pool` | **200** (frozen bonded/not-bonded) | **502** |
| `/cosmos/base/tendermint/v1beta1/blocks/latest` | **200** (block 100279059) | **502** |
| `/cosmos/staking/v1beta1/params`, `/cosmos/distribution/v1beta1/params`, `/cosmos/mint/v1beta1/inflation`, `/cosmos/base/tendermint/v1beta1/node_info` | 200 (cached) | — |
| `/cosmos/gov/v1/params`, `/cosmos/distribution/v1beta1/community_pool`, `/cosmos/bank/v1beta1/supply`, `/cosmos/staking/v1beta1/validators`, `/carbon/**`, `/abci_query` (RPC) | **502** | 502 |

The cached routes are exactly the set a chain-status monitor polls — consistent with a backend that
died and a cache with long TTL.

## 3. Third-party endpoints decommissioned

| endpoint | status 2026-10-09 |
|---|---|
| carbon-api.polkachu.com | connection fails / 404 page |
| carbon-mainnet-lcd.autostake.com | 404 (service withdrawn) |
| carbon-rest.publicnode.com | 404 |
| rest.carbon.blockhunters.org | no response |
| rest.lavenderfive.com/carbon | 503 (service unavailable) |
| rest.cosmos.directory/carbon, rpc.cosmos.directory/carbon | 502 (upstream gone) |
| rpc.carbon.polkachu.com, carbon-rpc.polkachu.com | 404 |
| scan.carbon.network | SPA served, backend `/api/*` falls through to the SPA |
| staking-explorer.com/uptime/carbon | `control_block_height_error (probably all public nodes overloaded)` |

## 4. Indexers show the frozen state

- staking-explorer.com/staking/carbon: **6 active nodes / 45 inactive**; bonded 532,905,309 SWTH
  (sums exactly to the cached LCD bonded pool); "Active IBC coins (last 24h): **0**".
- DefiLlama Demex/Nitron TVL series: amounts identical across the last daily points (only re-priced) —
  the adapters read the team's now-dead API.

## 5. Timeline / cause (circumstantial but consistent)

- 2026-08-25: emergency halt #1 (cosmos-evm advisory), resumed by v2.82.1 "Bump halt version 2 → 3".
- 2026-09-23: v2.84.0 released — fixes an **iavl v1.2.2 race "observed on mainnet sentries as the
  fee_collector balance being credited twice and an app hash mismatch at the next block"**; the x/otc
  fix is flagged "consensus-affecting: ship in a coordinated upgrade".
- 2026-09-25 20:01:25Z: chain stops producing blocks (this measurement).
- Since then: no v2.85.0 release, no commit to the public `carbon-bootstrap` repo (last commit
  2026-08-25), no public announcement found (web/X search), core repo `Switcheo/carbon` now private.
- Resume requires a coordinated validator upgrade (x/admin halt-version mechanism), not anything an
  external attacker can trigger.

## 6. What this means for C2-32

The corpus capture (cost $30.6k vs chain TVL $248k, "6/23 validators") describes a **pre-halt** state.
Today: capture = $0 (nothing executes); the $250,097 chain TVL is **S (frozen)**; any latent capture
economics remain broken by liquidity ($607 of SWTH on Osmosis vs 267.3M SWTH needed) and by the
Switcheo Staking veto bloc (38.42% > 33.4%).

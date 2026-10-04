# KiiChain — chain access and endpoints (verified 2026-10-04)

All reads are read-only. No transaction was signed or broadcast.

## Endpoints used

| Purpose | URL | Status |
|---|---|---|
| EVM JSON-RPC (mainnet) | `https://json-rpc.kiivalidator.com` | live, chain id `0x6f7` = **1783** |
| Cosmos RPC (Tendermint) | `https://rpc.kiivalidator.com` | live |
| Cosmos LCD (REST) | `https://lcd.kiivalidator.com` | live |
| Explorer | `https://explorer.kiichain.io` | live (SPA, no public REST API used) |
| Binary mirror | `https://kiichain-snapshots-public.s3.us-east-2.amazonaws.com/releases/v7.4.2/kiichaind-v7.4.2-linux-amd64` | live |

Docs: <https://docs.kiiglobal.io/docs/build-on-kiichain/endpoints-evm>, mainnet chain id
`kiichain_1783-1`, denom `akii` (18 decimals), max supply 1.8B KII.

## Live chain state at probe time (2026-10-04 ~22:20–22:35 UTC)

- EVM block height: **10,665,406 – 10,665,645** (advancing; ~2.5 s/block average
  since the v7.4.2 upgrade). Block production confirmed by two samples 5 s apart
  (10,663,536 → 10,663,541 in 5 s during first access).
- `eth_chainId` = `0x6f7` (1783); `net_version` = 1783; `eth_syncing` = false.
- `web3_clientVersion` = `Version dev () Compiled at using Go go1.24.11 (amd64)`
  (not informative; version evidence comes from LCD + binary, see
  `version-evidence.md`).
- Cosmos `node_info.application_version`:
  - name `kiichain`, app `kiichaind`, **version `v7.4.2`**
  - git commit `0ef04d738aee0f54aca6f9dc82194b2c50483f6e`
  - build tags `muslc,ledger`, go `go1.24.11 linux/amd64`
- CometBFT `0.38.19` node version; consensus `TMCoreSemVer v0.38.21` from the binary.
- Bank supply: `1,799,758,910.6 KII` (max 1.8B; no hyperinflation).
- KII price used for USD: **$0.088334** (CoinGecko `kiichain`, 2026-10-04 ~22:30 UTC).

## Halt / resume timeline (block timestamps via `eth_getBlockByNumber`)

| Event | EVM block | Time (UTC) |
|---|---|---|
| Last block before halt | 9,355,723 | 2026-08-22 22:50:58 |
| First block after resume | 9,355,725 | **2026-08-27 20:24:08** |
| v7.4.2 upgrade height | 10,250,221 | 2026-09-21 18:50:32 |
| Probe block | 10,665,645 | 2026-10-04 22:31 |

The chain was halted for ~5 days, resumed with the incident-recovery upgrade
(v7.4.0, released 2026-08-25), then upgraded to v7.4.2 on 2026-09-21
(governance proposal 13, `KiiChain/mainnets/kiichain/proposals/proposal_13.json`).

## Reproduce

```bash
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  https://json-rpc.kiivalidator.com
curl -s https://lcd.kiivalidator.com/cosmos/base/tendermint/v1beta1/node_info
```

Raw outputs: `analysis/raw/live_probes.json`, `analysis/raw/live_probes.txt`.

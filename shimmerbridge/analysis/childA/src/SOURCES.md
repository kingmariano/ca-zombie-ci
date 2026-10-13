# Saved sources — repos, commits, and file map (Child A)

All sources below were fetched read-only from public GitHub on 2026-10-13 and are stored in this folder (`.git` directories removed; no nested repos).

## 1. `wrapped-asset-bridge/` — THE DEPLOYED BRIDGE CODE (canonical)

- Repo: `https://github.com/LayerZero-Labs/wrapped-asset-bridge`
- Commit: `d89dc70dbfb9576601e4f9d69a4b2c210c256afd` (2023-12-05, "fix unit tests"; main branch, shallow clone)
- Relevant files:
  - `contracts/WrappedTokenBridge.sol` — remote (ShimmerEVM) side: burns wrapped tokens on source, receives `PT_MINT`, constructs `PT_UNLOCK` payloads
  - `contracts/OriginalTokenBridge.sol` — origin-chain side: locks originals, processes `PT_UNLOCK` (the contract at `0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898` on the 8 chains)
  - `contracts/TokenBridgeBase.sol` — packet types (`PT_MINT = 0`, `PT_UNLOCK = 1`), fee logic, `setTrustedRemoteAddress`
  - `contracts/WrappedERC20.sol`, `contracts/wrappedTokens/{USDC,USDT,WETH}.sol`, `contracts/interfaces/{IWrappedERC20,IWETH}.sol`
  - `contracts/test/` — LZ endpoint stub + harnesses
- **Identity proof:** whitespace-normalized `diff` against the on-chain-verified Ethereum deployment source in `../../src-eth/`:
  - `TokenBridgeBase.sol` → **IDENTICAL**
  - `OriginalTokenBridge.sol` → **IDENTICAL**
  - ⇒ the same codebase (thus its `WrappedTokenBridge.sol`) ran on ShimmerEVM.

## 2. `iota-evm-bridge/` — bridge frontend + SDK (archived)

- Repo: `https://github.com/iotaledger/iota-evm-bridge`
- Commit: `b91473a348594f54943c9a626cb908c491dd2225` (2025-07-23, "feat: archive repository and point to the monorepo (#89)")
- README: *"This repository has been deprecated. Please use https://github.com/iotaledger/iota/tree/develop/apps/evm-bridge instead"*
- Contains no Solidity; `app/src/config/*` and `sdk/src/*` show the L1/L2 wiring (L2 = ShimmerEVM config via `VITE_EVM_BRIDGE_CONFIG`, L1 = Shimmer via `isc` interactions).
- Related repos that **do not exist** (404): `iotaledger/evm-bridge`, `iotaledger/evm-bridge-contracts`, `iotaledger/shimmerbridge`, `iotaledger/bridge-contracts`.

## 3. `lz-address-book/` — LayerZero address book (context)

- Repo: `https://github.com/LayerZero-Labs/lz-address-book`
- HEAD at clone time: `c7c7c8f1cde9612fee901d81bffd1c9cb7f724d3` (2026-10-13)
- `src/generated/LZWorkers.sol` registers `shimmer-mainnet` for **EndpointV2 EID 30230** (DVNs: BCW Group, Canary, Horizen, LayerZero Labs, Nethermind, TSS) — ShimmerEVM's V2 deployment metadata. The ShimmerBridge itself is EndpointV1 (EID **230**), so the V1 endpoint address is not in this repo.

## 4. Not saved here (see `../evidence/`)

- Archived sunset announcements, LayerZero support update, WayBack captures, LZScan JSON, DefiLlama JSON — all under `../evidence/` (index in `../report.md` §9).

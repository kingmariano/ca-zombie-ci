# Vela Exchange — Arbitrum + Base

## Status & shutdown evidence (sources, dates)
- DefiLlama slug `vela-exchange` (Arbitrum+Base), TVL **9.99997e-07 USD** (i.e. $0.000001), listed=false. Adapter `projects/vela-exchange/index.js` (fetched 2026-10-04) hallmarks include "2023-04-13 Refunded tokens to VLP holders & traders", "2024-09-17 Burned 65m Vela tokens"; adapter TVL = token balances of the single vault address `0xC4ABADE3a15064F9E3596943c699032748b13352`.
- VELA token `0x088cd8f5eF3652623c22D48b1605DCfE860Cd704`.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- Vault `0xC4ABADE3a15064F9E3596943c699032748b13352`:
  - Arbitrum (block **511521821**): code 4285 bytes; Etherscan V2 (chainid 42161) says **TransparentUpgradeableProxy** (functions: admin, changeAdmin, implementation, upgradeTo, upgradeToAndCall); implementation not pulled in bounded pass.
  - Base (block **52151251**): code 4285 bytes; same proxy type per Etherscan V2 (chainid 8453).
- `owner()`/`paused()` ABI from the adapter's vault differs from the implementation ABI; no owner/paused read succeeded (`execution reverted` for guessed selectors) — implementation ABI unknown in this pass.

## Live balances (token, amount, USD, price source, block)
- Arbitrum: USDC (native) `0xaf88d065…5831` = **0**; USDC.e `0xFF970A61…B5CC8` = **1 wei = 0.000001 USDC** (~$0.000001; DefiLlama USDC.e ≈ $1.0); native ETH = 0. Block 511521821.
- Base: USDbC `0xd9aAEc86…b6CA` = 0; USDC `0x833589…2913` = 0; native ETH = 0. Block 52151251.
- Total live ≈ **$0.000001** — matches DefiLlama's 9.99997e-07 exactly (the whole remaining TVL is one wei of USDC.e).

## Permissionless paths examined (path → gates → live values → verdict; negative results)
- Nothing of value to extract: the entire TVL is 1 wei. Any vault withdrawal requires the (unidentified) implementation's gating; VLP share math operates on ~0 liquidity.
- Staking contracts and VELA/esVELA balances were not enumerated in the bounded window (DefiLlama staking component uses a Goldsky subgraph that was not queried); even a large VELA staking balance would be a token claim, not a drained asset. Checked Goldsky endpoints and vault balances; no value found.
→ E-U $0 (trivially: 1 wei).

## Approvals / user-side residual risk
None material; no live token balance for approvals to drain.

## Classification: S — $0.000001 — confidence high — what would change it
- Unknown implementation could in principle hold tokens in child contracts not covered by the adapter; parent can read implementation via `implementation()` on the proxy if desired. DefiLlama indexer agrees TVL is 1 wei.

## Raw evidence index (files in analysis/)
- raw/es_vela_arb.json, raw/es_vela_base.json (Etherscan V2 getsourcecode, TransparentUpgradeableProxy)
- On-chain reads in this dossier (blocks 511521821 / 52151251)

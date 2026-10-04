# Balancer V2 — Deployment Inventory & Mode/Fraxtal Live-Pool Scan

Prepared: 2026-10-04. Read-only on-chain checks; no transactions signed or sent.

## Sources

- V2 docs deployment-addresses page moved to `https://docs-v2.balancer.fi/reference/contracts/deployment-addresses/` (the URL in the task, `https://docs.balancer.fi/reference/contracts/deployment-addresses/`, is 404; the whole site now points to V3 and `docs-v2.balancer.fi`). The V2 pages lazy-load addresses from JS, so the canonical raw source used is:
- `github.com/balancer/balancer-deployments`, task [`20210418-vault`](https://github.com/balancer/balancer-deployments/tree/master/v2/tasks/20210418-vault/output) (commit `b55dc2b8…`), plus [`20251020-vault-v2.1`](https://github.com/balancer/balancer-deployments/tree/master/v2/tasks/20251020-vault-v2.1/output).
- On-chain verification via `cast` (`eth_getCode` length, `keccak256(code)`, `getPausedState()`), 2026-10-04.

Repo outputs present for Vault: mainnet, arbitrum, polygon, base, optimism, gnosis, avalanche, bsc, zkevm, mode, fraxtal, plasma, sepolia. The repo readme states only networks recorded in task outputs have official Balancer deployments. The patched `Vault v2.1` (for new L2s) has an output only for **Plasma**, and it is also at the canonical address — both tasks agree.

## Task 1 — Balancer V2 Vault deployments

**Every official V2 Vault deployment uses the same address: `0xBA12222222228d8Ba445958a75a0704d566BF2C8`.** No chain differs, no chain returned empty code. All runtime code is 24,512 bytes; keccak differs per chain as expected (the Vault embeds an immutable `_WETH`, itself chain-specific).

| # | Chain | Chain ID | Vault address | Code | keccak256(runtime code) | Paused |
|---|-------|----------|---------------|------|--------------------------|--------|
| 1 | Ethereum | 1 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x9eb70db20a41bfbf4b022fd070fa7f154b7c4aec98177120dde7a958384f4e66 | false |
| 2 | Arbitrum One | 42161 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x96f131af73d8a231741b91e266fb54e0bc8c3041954deb51652113600549093a | false |
| 3 | Polygon PoS | 137 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x70e4262e51138406c00ad6762c7df03169f2717f5f15ea0bbe7a47ca4ab9355e | false |
| 4 | Base | 8453 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0xf73f7f7f4d4fd56067273eade4d46efa681f36bfb51e1ac0ca25d24ed15c16dc | false |
| 5 | OP Mainnet | 10 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x357fe79fc741b850822ac74408e9f299972abd642e73deb262bbe588094f0625 | false |
| 6 | Gnosis | 100 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x7b419abf9f2fc92c6e66aee0ee9cd413510eb49dfedc8723cf87bbc864cbf0ee | false |
| 7 | Avalanche C-Chain | 43114 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x9b975b010aa1e083e90d46729cdc67f346c4868d01cba6ae125862d8acb17ac9 | false |
| 8 | Mode | 34443 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0xb118c2ef7bab642bcbb5701de69294c4bf082d0781a13dfb8858a6d7ba08c4a1 | false |
| 9 | Fraxtal | 252 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x5ce3f6dd137113c88eaa0006255e9a3539ca63042445cce8fb3737771071d27a | false |
| 10 | BNB Smart Chain | 56 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x53be49a66356c543562ee05bf82b576ce4f552c50db49593d8faa3bc831a9517 | false |
| 11 | Polygon zkEVM | 1101 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0xf7b23fe264a7c06a80ee0c8360c8cd8641e07a1823e0cb5dfb294bf3c65bce18 | false |
| 12 | Plasma | 9745 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0x48c528024ff71646ac689440ce76dc4a82e715e61da9fae90c825680310a6580 | false |
| 13 | Sepolia (testnet) | 11155111 | 0xBA12222222228d8Ba445958a75a0704d566BF2C8 | yes | 0xb371e7882b7676296ae6bf27d5873e6f2486a94292e00e02c8e562ddbb0a2974 | false |

Rows 1–9 were explicitly required; rows 10–13 were additionally verified (same address; Sepolia is the only testnet).

### getPausedState() full tuples (bool, pauseWindowEndTime, bufferPeriodEndTime)

| Chain | paused | pauseWindowEndTime | bufferPeriodEndTime |
|-------|--------|--------------------|---------------------|
| Ethereum | false | 1626633407 (2021-07-18) | 1629225407 (2021-08-17) |
| Arbitrum | false | 1637617308 (2021-11-22) | 1640209308 (2021-12-22) |
| Polygon | false | 1631733011 (2021-09-15) | 1634325011 (2021-10-15) |
| Base | false | 1696957419 (2023-10-10) | 1699549419 (2023-11-09) |
| Optimism | false | 1659390227 (2022-08-01) | 1661982227 (2022-08-31) |
| Gnosis | false | 1675104955 (2023-01-30) | 1677696955 (2023-03-01) |
| Avalanche | false | 1684436696 (2023-05-18) | 1687028696 (2023-06-17) |
| Mode | false | 1724164217 (2024-08-20) | 1726756217 (2024-09-19) |
| Fraxtal | false | 1724003903 (2024-08-18) | 1726595903 (2024-09-17) |
| BSC / zkEVM / Plasma / Sepolia | false | (only paused bool captured) | — |

RPCs used: `ethereum-rpc.publicnode.com`, `arbitrum-one-rpc.publicnode.com`, `polygon-bor-rpc.publicnode.com`, `base-rpc.publicnode.com`, `optimism-rpc.publicnode.com`, `gnosis-rpc.publicnode.com`, `api.avax.network/ext/bc/C/rpc`, `mainnet.mode.network`, `rpc.frax.com`, `bsc-rpc.publicnode.com`, `zkevm-rpc.com`, `rpc.plasma.to`, `ethereum-sepolia-rpc.publicnode.com`. Chain IDs confirmed via `eth_chainId` on each RPC.

**Findings: no address differences, no missing code, no paused Vault on any chain.**

---

## Task 2 — Mode & Fraxtal live-pool scan

Method:

- **Fraxtal**: `analysis/scan_chain.py` (PoolRegistered logs via Etherscan V2 getLogs) against `rpc.frax.com` — worked (Etherscan V2 supports chainid 252).
- **Mode**: Etherscan V2 does **not** support chainid 34443 (`Missing or unsupported chainid parameter`). Fallback created and used: `analysis/scan_chain_rpc.py`, which enumerates PoolRegistered logs (`topic0 0x3c13bc30…`) via full-range `eth_getLogs` on `mainnet.mode.network`, then runs the same Vault/`getPoolTokens`/probe pipeline.
- Both Vaults: `paused = false`.
- Scan blocks: Mode 45,462,480; Fraxtal 42,140,842. Raw results: `analysis/chain-mode.json`, `analysis/chain-fraxtal.json` (logs: `scan-mode.log`, `scan-fraxtal.log`).
- `ETHERSCANV2_API_KEY` was read from `/home/heisenberg/CA/.env` at runtime and is not written into any file. Note: `.env` uses bare assignments, so it must be sourced with `set -a` for the key to reach python.

### Summary

| Chain | Pools registered | Pools with non-zero balances | ComposableStable w/ balances | Weighted w/ balances | Linear w/ balances | Pools w/ non-zero rate providers |
|-------|------------------|------------------------------|------------------------------|----------------------|--------------------|----------------------------------|
| Mode | 22 | 2 | 2 | 0 | 0 | 0 |
| Fraxtal | 11 | 7 | 5 | 2 | 0 | 4 |

### Mode — live pools (2)

| Pool | Type | Tokens | Notes |
|------|------|--------|-------|
| `0x45eeca37c02f4da7fe000c32c6eaa0699cfb669c` | ComposableStable | USDT/USDC | bptIndex 0, **recoveryMode = true**, all rate providers zero |
| `0x1224d4e918e69189760888fd40ec1491c93cd59b` | ComposableStable | mBTC/uniBTC | bptIndex 0, **recoveryMode = true**, all rate providers zero. Batch prober first returned "Unknown" (RPC transient); direct calls confirm type |

No Linear pools with balances; no non-zero rate providers on Mode.

### Fraxtal — live pools (7)

| Pool | Type | Tokens | Non-zero rate providers |
|------|------|--------|--------------------------|
| `0xaf125dc597aeac3d3f9f467584275bfaa8b9c08d` | Weighted (variant with rates) | 50wfrxETH/50USDC | none (all zero) |
| `0x760b30eb4be3ccd840e91183e33e2953c6a31253` | ComposableStable | FRAX/USDe/DAI/USDT/USDC | none (all zero) |
| `0xa0b92b33beafce388ce0092afdcd0ca77323eb12` | ComposableStable | sFRAX/sDAI | `0x95eedc9d10B6964a579948Fd717D34F45E15C0C6`, `0x3893E8e1584fF73188034D37Fc6B7d41A255E570`; recoveryMode = true |
| `0xa0af0b88796c1aa67e93db89fead2ab7aa3d6747` | ComposableStable | FRAX/USDe | none (all zero); recoveryMode = true |
| `0x33251abecb0364df98a27a8d5d7b5ccddc774c42` | ComposableStable | sFRAX/sDAI/sUSDe | `0x95eedc9d10B6964a579948Fd717D34F45E15C0C6`, `0x99D033888aCe9d8E01F793Cf85AE7d4EA56494F9`, `0x3893E8e1584fF73188034D37Fc6B7d41A255E570`; recoveryMode = true |
| `0x1570315476480fa80cec1fff07a20c1df1adfd53` | Weighted (variant with rates) | sFRAX/sfrxETH | `0x761efEF0347E23e2e75907A6e2df0Bbc6d3A3F38`, `0x3893E8e1584fF73188034D37Fc6B7d41A255E570` |
| `0x7edca1457aaeacebb2bcbfc3f1c6683ac4a05af4` | ComposableStable | sFRAX/FRAX | `0x3893E8e1584fF73188034D37Fc6B7d41A255E570`; recoveryMode = true |

No Linear pools with balances on Fraxtal. The two "Weighted" pools are a verified WeightedPool source that includes `getRateProviders()` (ContractName `WeightedPool` on Etherscan V2, chainid 252); `getBptIndex()` reverts, `getNormalizedWeights()` returns 50/50.

### Caveats / artifacts

- `scan_chain.py`'s `dec_address_array`/`dec_uint_array` ignore the leading ABI offset word (0x20) of dynamic-array returns: they read the offset as the length and prepend a bogus entry (visible as rate provider `0x…0003`, `0x…0004`, `0x…0006` in the raw JSON). Types and balances are unaffected; the rate-provider values in the tables above were corrected with direct `cast call getRateProviders()(address[])`.
- Pools in `recoveryMode = true` restrict joins/exits; they still hold non-zero balances.
- Balances are raw units as reported by `getPoolTokens` at the scan block; only presence (`> 0`) is asserted here.

# L-2 Phase-1 triage — Triage-C (non-EVM) — live custody screen

**Date:** 2026-10-11 · **Scope:** 22 non-EVM rows from `ci/L2-SPLIT-C.json` · **Status:** read-only; no transactions, no secrets, no writes outside `l2-triage-c/`

**Mission (phase 1 of 3):** custody screening only — find what is LIVE today at the latest block/height for each protocol's core custody contracts/accounts. No vulnerability analysis.

## Method (short)

1. DefiLlama adapter source (public `DefiLlama/DefiLlama-Adapters`) used as the *lead* for each protocol's custody addresses; deleted adapters recovered from git history (commit-walk).
2. Live balances read from chain-native public endpoints at latest height/block: Solana JSON-RPC (Alchemy + public fallbacks), Sui JSON-RPC (`sui-rpc.publicnode.com`), Starknet JSON-RPC (`api.cartridge.gg/x/starknet/mainnet`), Cardano Koios, Radix Gateway (`mainnet.radixdlt.com`), Hedera Hashio, Cosmos LCDs (Injective/Osmosis/Neutron publicnode+polkachu), Filecoin GLIF RPC, BCH Fulcrum (6 servers), Ergo explorer, ICON `ctz.solidwallet.io`, Acala RPC (raw `state_getStorage` with hand-built orml storage keys), Oasis Emerald RPC, Bitcoin (Fiamma API probe).
3. USD valued with `coins.llama.fi` current prices at scan time; amounts converted with on-chain decimals read from each chain (mint accounts / coin metadata / token_info / `decimals()`).
4. Whole enumeration runs in CI (`l2-triage-c/ci/scan.py` via `ci/run.sh`) — results in `ci-out/results.json` (artifact) + `analysis/results-ci-run*.json`.

## Unreachable — exact reasons (evidence)

| Row | What is dead | Probes (2026-10-11) |
|---|---|---|
| Fiamma | bridge TVL API + project domain | `bridge-api.fiammachain.io` HTTP 522; `fiammachain.io` DNS NXDOMAIN; only testnet config in `fiamma-chain/networks`; DefiLlama adapter last good read 2026-03-18 |
| ShadeLend | Shade stats API + all public Secret RPC/LCD | `prodv1.securesecrets.org` DNS dead; tested 12 endpoints (publicnode x3, polkachu, lavenderfive, 01node, stakewolle, saturn, 1rpc) — dead/404/501; DefiLlama deadFrom 2026-08-08 |
| Ocean One | DEX events API + project domain | `events.ocean.one` DNS dead (https+http); `api.mixin.one` alive but exposes no per-app balance endpoint; custody address not published; DefiLlama deadFrom 2024-01-21 |
| SuiDollar Basis | frontend + any published package/object ID | `suidollar.io` DNS dead; repo `suidollar/suidollar-usdc-vault` has `suidollar = "0x0"` placeholder (never published in repo); funds last seen in Navi/Bluefin positions; DefiLlama deadFrom 2025-10-21 ("Project is sunset") |

## Notable per-row notes

- **Moria Protocol (DRAINED/$0):** Moria V1 was **disabled by the team on 2026-04-23** after an external researcher disclosed a vulnerability; Riften Labs redeemed all loans, returned collateral to holders, halted the BP oracle and committed to buy back MUSD. The adapter's loan-contract address now has **0 sats and 0 token UTXOs** (6,851 historical txs; 6 independent Fulcrum servers agree). This closes the row: the funds were *returned*, not exploited.
- **Taiga Acala (LIVE ~$1.41M incl LDOT):** the Acala module account (`modlnuts/staking…`) holds **99,381 DOT + 1,039,284 LDOT** (10.3% of LDOT supply) + unidentified ForeignAsset(13). DefiLlama reports only $122K because it has no LDOT price — the LDOT leg is ~$1.28M at DOT parity (LDOT ≈ liquid-staked DOT; no direct feed exists). This is the largest live custody position found in this split.
- **Omm (LIVE ~$150K):** cash only (USDC 55.7K + USDS 94.8K); outstanding borrows $52.3K. Adapter carries a commented-out 2023-01-22 exploit hallmark.
- **Fountain (LIVE ~$93K cash):** 3 Compound-fork comptrollers on Oasis Emerald; cETHER market's `underlying()` reverts with `mint is paused` (native ROSE market) — handled explicitly. Cash+borrows (TVL convention) = $227K.
- **HashMix (LIVE $1.7K):** pool holds ~1,582 FIL; TVL collapsed from the $164K row (568d stale); `fvm.hashmix.org` API returns 502.
- **SFT (LIVE $59):** only the lending-pool balance is measurable; the miner-enumeration dashboard API (`ww8.sftproject.io`) is DNS-dead, so miner-locked FIL cannot be enumerated — treat as a lower bound.
- **CaviarNine (LIVE $38K):** 82 LSU resources valued through on-chain validator stake-XRD vaults (redemption ratio); matches DefiLlama's current $38K (row's $155K was stale).
- **Armada (LIVE $352K):** 24 CLP vaults; vault token accounts hold USDC/JitoSOL etc. Whirlpool position layer not separately valued (understates).
- **Jet V1 (LIVE $156K):** 21,194 SPL token accounts under the vault authority; debt mints excluded.
- **BlueMove/JediSwap/10KSwap/Dojoswap:** live AMM reserves read directly from factories (pairs enumerated on-chain, reserves cross-checked with `balanceOf` for JediSwap). Dojoswap's factory exposes 900+ pairs; most pools hold dust/test-CW20 tokens — CW20 pricing unavailable via DefiLlama coins API (noted).

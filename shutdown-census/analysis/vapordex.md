# VaporDEX — Avalanche (V1 + V2), Telos, ApeChain

## Status & shutdown evidence (sources, dates)
- Census: "shut 2026". DefiLlama `protocol/vapordex` current TVL (retrieved 2026-10-04): **Avalanche $443,810, Telos $195, ApeChain $5**.
- DefiLlama adapter mapping (github.com/DefiLlama/DefiLlama-Adapters, retrieved 2026-10-04):
  - `registries/uniswapV2.js` → `vapordex`: avax + apechain factory `0xc009a670e2b02e21e7e75ae98e254f467f7ae257`; telos factory `0xDef9ee39FD82ee57a1b789Bc877E2Cbd88fd5caE` → **V1 is a Uniswap-V2-fork**.
  - `registries/uniswapV3.js` → `vapordex-v2`: avax factory `0x62B672E531f8c11391019F6fba0b8B6143504169` fromBlock 36560289 (same address on telos/apechain) → **V2 is a Uniswap-V3-fork** (not a Solidly fork as the task hypothesised).
- Official docs: `github.com/VaporFi/gitbook-vapordex` (bridges/token factory/fee harvesting pages).
- No shutdown post-mortem found in the bounded pass.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
Reads via `https://api.avax.network/ext/bc/C/rpc`, `https://rpc.telos.net`, `https://apechain.calderachain.xyz/http` at latest (block numbers not captured in this bounded pass — **approximate only**, ~2026-10-04).

| Address | Chain | Role | Code | Owner | Notes |
|---|---|---|---|---|---|
| 0xc009a670e2b02e21e7e75ae98e254f467f7ae257 | Avalanche | V1 factory (UniV2 fork) | live | none (`owner()` reverts) | `allPairsLength()=202` |
| 0xc009a670e2b02e21e7e75ae98e254f467f7ae257 | ApeChain | V1 factory | live (code len 23355 chars) | none | `allPairsLength()=2` |
| 0xDef9ee39FD82ee57a1b789Bc877E2Cbd88fd5caE | Telos | V1 factory | live | none | `allPairsLength()=17` |
| 0x62B672E531f8c11391019F6fba0b8B6143504169 | Avalanche (~Telos/ApeChain) | V2 factory (UniV3 fork) | live | `owner()=0x6769DB4e3E94A63089f258B9500e0695586315bA` | `paused()`/`feeTo()` not present |
| 0x6b4bb60CFd7e9E4fc9A6F3bc7a5a52715443c37D | Avalanche | V1 pair0 (USDC.e/AVAX) | live | n/a | `token0=0xA7D7079b…(USDC.e)`, `token1=0xB31f66AA…(WAVAX)`; pair balances 22.558 USDC.e / 2.034 WAVAX vs reserves (first reserve value read 1.791e9 — the printed value was blockTimestampLast; see raw note); `skim(address)` selector executes (returns 0x) |

## Live balances (token, amount, USD, price source, block)
- Avalanche TVL **$443,810**, Telos **$195**, ApeChain **$5** — source DefiLlama `api.llama.fi/protocol/vapordex` (2026-10-04). Not re-derived pair-by-pair in the bounded pass (202 avax pairs + 17 telos + 2 apechain).
- Sample pair0 (avax) token balances at latest: 22,558,014 USDC.e (6dp) + 2.034 WAVAX — i.e. this early pair is dust; the $443.8K aggregate lives in the larger pairs.
- VPR token / gauges / farm contracts were **not identified** in the remaining time (no verified masterchef in the DefiLlama registries).

## Permissionless paths examined (path → gates → live values → verdict)
1. **UniV2 pair `skim(address to)`** — permissionless; transfers only `balanceOf(pair) − reserve` of each token to an arbitrary `to`. Verdict: extracts only excess tokens sitting above reserves. For sampled pair0, balances ≈ reserves ⇒ no extractable excess observed. No protocol-wide excess measurement done (bounded).
2. **UniV2 pair `sync()`** — permissionless, updates reserves to balances; harmless.
3. **LP `burn()` / `mint()`** — LP-token holder only (burns user's LP); principal returned to LP holder. H-O.
4. **Router functions** — standard UniV2 router; no arbitrary-target call or unvalidated calldata found in the registry mapping (router source not fetched).
5. **UniV3-fork (V2) `collect()`** — position-NFT owner only; swap fees accrue to positions; factory owner is a plain address (`0x6769DB4e…`) able to set protocol fee recipient but not move LP principal.
6. **Factory ownership** — V1 factories have no `owner()` (renounced/immutable, UniV2-style); no pause/admin sweep found. V2 factory owner is set.

## Approvals / user-side residual risk
- LP positions remain in pairs; residual token approvals to the router/pairs allow only standard router operations (swap/add/remove) — no arbitrary transferFrom path identified. V2 positions are NFT-gated.

## Classification: **H-O** — $443,810 (Avalanche) + $200 (Telos+ApeChain) — confidence **low-medium** — what would change it
- LP holders can remove liquidity if pair contracts are live (UniV2 `burn`, UniV3 position burn); no unprivileged drain identified in this bounded pass.
- **E-U: $0** (confidence low — pair-level `balance − reserve` excess not exhaustively measured; farm/gauge/veNFT contracts not enumerated).
- Would change: a repo-wide scan of all 221 pairs for `balance > reserve + dust`, discovery of a live farm with `emergencyWithdraw` semantics or a rewarder holding tokens, and verification of the V2 factory owner's privileges.

## Raw evidence index (files in analysis/raw/)
- `vapordex_llama.json` (protocol TVL endpoints; captured in shell output, not separately saved) — see shell log 2026-10-04.
- Contract reads captured in shell session only (bounded pass; no raw dump file created in time).

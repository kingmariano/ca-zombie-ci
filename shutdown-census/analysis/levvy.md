# Levvy — Cardano (bounded, non-EVM)

## Status & shutdown evidence (sources, dates)
- DefiLlama adapters (retrieved 2026-10-04 from `raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/`):
  - `levvy-fi/index.js` — NFT-collateralised loans: `post(https://levvy-api-v2-testnet.up.railway.app/api/v1/nft/platform/stats)`, returns `totalValueLocked` (supplied) + `totalValueBorrowed`.
  - `levvy-fi-tokens/index.js` — fungible-token loans: `.../api/v1/token/platform/stats`.
- Census value: tokens **$21.9K supplied / $10.4K borrowed**, NFTs **$3.6K** (DefiLlama).
- **Backend check 2026-10-04:** both POST endpoints return `HTTP 404 {"status":"error","code":404,"message":"Application not found"}` (Railway app deleted). The protocol's only public data backend is dead; consistent with a 2026 shutdown.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- Cardano is non-EVM: no contract addresses in the DefiLlama adapters (they only call the API). **No script/policy hashes identified.**
- Sources checked for script hashes: `levvy.fi` docs were not reachable within the bounded pass; Koios (`https://api.koios.rest/api/v1`) and cardanoscan were **not queried** before time ran out. Marked **not investigated (Cardano tooling deprioritised per brief; not-EVM)**.

## Live balances (token, amount, USD, price source, block)
- No independent on-chain balance measurement. Census figure ($21.9K supplied / $10.4K borrowed tokens; $3.6K NFTs) is DefiLlama's last known value; the adapter's live API is 404 so feasibility of re-measurement is zero without identifying the scripts.
- Block/slot numbers: **none recorded** (no chain reads performed).

## Permissionless paths examined (path → gates → live values → verdict)
- None examined on-chain. Cardano Plutus scripts gating (borrower/loan NFT) could not be inspected without script hashes. No EVM-style extraction applies.

## Approvals / user-side residual risk
- Unknown. The API being dead means affected users likely interact directly with scripts if they still exist; not verified.

## Classification: **S or H-O (unresolved)** — $21,900 tokens / $10,400 borrowed / $3,600 NFTs — confidence **very low** — what would change it
- **E-U: $0** — no evidence of any extraction path (not investigated).
- Would change: locate Levvy script hashes (Koios `/asset_list`/`/address_info` by known Levvy treasury policy, or archived levvy.fi docs), then inspect loan/loan-NFT validators for unprivileged `Repay`/`Redeem` redirection.
- **Status note: not fully investigated — restart/time interruption after API-death finding.**

## Raw evidence index (files in analysis/raw/)
- `levvy_reads.txt` (adapter source references + dead-API responses)

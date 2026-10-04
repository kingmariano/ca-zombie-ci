# DeltaDeFi — Cardano (Hydra DEX)

## Status & shutdown evidence (sources, dates)
- **Operational pause announced July 15, 2026** due to insufficient funding: CryptoNews.net, "DeltaDeFi Announces Operational Pause Due to Insufficient Funding". Census TVL = $0.
- Project: first Hydra-powered Cardano DEX (Adastack ecosystem page; docs.deltadefi.io; Reddit r/cardano "now live on mainnet (beta)"). GitHub org `deltadefi-protocol` (open-source contracts/off-chain code).

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- **NOT ENUMERATED.** Cardano uses script/policy hashes, not EVM addresses; no script hash was retrieved in the time box. Starting points for a follow-up: `github.com/deltadefi-protocol` repos (plutus/aiken validators) and Cardano explorers (cardanoscan/cexplorer) looking for locked order-book/script UTxOs.

## Live balances (token, amount, USD, price source, block)
- **Not measured.** Any residual value would sit in Hydra heads (off-chain state channels) and script-locked UTxOs, not in EVM-style balances.

## Permissionless paths examined
- **None.** Bounded negative; no chain reads performed.

## Approvals / user-side residual risk
- Cardano has no ERC-20 allowances; risk would be script datum/withdrawal logic and Hydra head snapshot disputes. Not assessed.

## Classification: S (paused/dead) — $0 verified — confidence: low — what would change it: script-hash enumeration + UTxO scan (Cardano tooling-heavy; explicitly not done). E-U unknown.

## Raw evidence index (files in analysis/raw/)
- None (web sources only: cryptonews.net pause article, docs.deltadefi.io architecture/Hydra page, github.com/deltadefi-protocol).

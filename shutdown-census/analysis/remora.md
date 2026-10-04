# Remora Markets — Solana (RWA / tokenized equities)

## Status & shutdown evidence (sources, dates)
- **Shut down with Step Finance**: X @StepFinance_ status 2025986934112145849 (Feb 23, 2026) announced Step Finance ending operations **and its sister brands SolanaFloor and Remora Markets "effective immediately"** (Solanacompass project page; Yahoo Finance/Investing "Step Finance and SolanaFloor Shut Down After Devastating Hack").
- Context: Remora was the tokenized-stock/RWA arm (Solana × RWA push; RWA.xyz platform page `app.rwa.xyz/platforms/remora-markets`). It used Step Finance infrastructure; the Jan-2026 Step hack (est. $27–40M) triggered the group shutdown.
- Census: DefiLlama TVL **$296,074 (dead)** — historic value, not verified live here.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- **NOT ENUMERATED / NOT INVESTIGATED ON-CHAIN.** No Solana program ID was confirmed in the time box; no JSON-RPC reads were made. Starting points for follow-up: Solana program IDs referenced by Step/Remora docs or solanacompass/RWA.xyz pages, then `getProgramAccounts` for vault/AUM accounts and market resolution accounts.

## Live balances (token, amount, USD, price source, block)
- **Not measured.**

## Permissionless paths examined
- **None.** Notably, Remora's tokenized-equity RWA tokens had market-resolution/withdrawal gating concerns (per task framing) — not tested. Do not treat as empty or safe.

## Approvals / user-side residual risk
- Unknown; Solana token delegations/approvals plus any custody vault authority would need review.

## Classification: S? (shut with Step; residual value unmeasured) — $0 verified — confidence: low — what would change it: program-ID discovery and `getProgramAccounts` balance + authority pass (not done in time box). E-U unknown.

## Raw evidence index (files in analysis/raw/)
- None (web sources only: @StepFinance_ shutdown thread, Solanacompass Remora/Step page, RWA.xyz Remora platform, Yahoo/Investing coverage).

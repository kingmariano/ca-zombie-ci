# Step Finance — Solana (portfolio tracker / DeFi)

## Status & shutdown evidence (sources, dates)
- **January 2026 hack**, estimated **$27M–$40M** drained from treasury/fee wallets: The Record "Crypto platform Step Finance shutting down after $40 million theft"; CoinDesk "Step Finance shuts operations after $27 million January hack" (Feb 24, 2026); Halborn "Explained: The Step Finance Hack (January 2026)" (~$30M from Solana wallets); crypto.news.
- **Shutdown announced Feb 23, 2026**, effective immediately, together with SolanaFloor and Remora Markets (@StepFinance_ status 2025986934112145849; Solanacompass: "Step Finance is no longer operating").
- Census: DefiLlama TVL **$0 (dead, hacked)**.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- **NOT ENUMERATED / NOT INVESTIGATED ON-CHAIN.** No Step Finance program IDs were verified in the time box; no Solana JSON-RPC reads were performed. The hack was reportedly against treasury/fee *wallets* (key compromise), not necessarily a program exploit — Halborn/The Record coverage supports wallet-drain over contract bug.
- Starting points for follow-up: Step Finance program IDs from `solanacompass.com/projects/step-finance` or the archived docs; check remaining program-owned token accounts and multisig/timelock authority (incident reports mention multisig/ops-wallet hygiene).

## Live balances (token, amount, USD, price source, block)
- **Not measured.** Any residual funds are likely in fee/treasury wallets or program PDAs.

## Permissionless paths examined
- **None.** Bounded negative; no chain calls made. The known loss already happened via key compromise (not an open permissionless path).

## Approvals / user-side residual risk
- Users who delegated SPL tokens or interacted with Step programs should revoke delegations if programs remain callable; not assessed.

## Classification: S (shut down after hack) — $0 verified — confidence: low — what would change it: Solana program-ID + treasury wallet address enumeration and `getProgramAccounts` balance sweep (not done). E-U unknown.

## Raw evidence index (files in analysis/raw/)
- None (web sources only: The Record, CoinDesk, Yahoo, Halborn, Solanacompass, @StepFinance_).

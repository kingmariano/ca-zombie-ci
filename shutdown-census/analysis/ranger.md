# Ranger Finance — Solana (perps aggregator / smart order router)

## Status & shutdown evidence (sources, dates)
- DefiLlama slug `ranger-finance-perps`, category "Interface", TVL **0** (pull 2026-10-04), listed=false.
- Ranger Finance is a **Smart Order Router (SOR) / aggregator** on Solana that routes perp orders to venues (Drift, Flash Trade, Adrena, Jupiter Perps); it does not appear to custody user collateral — funds remain in the underlying venue accounts under user authority.
- Public presence: GitHub org `ranger-finance` (36 repos), SDK/agent kit (`ranger-agent-kit`, `sor-ts-demo`); CoinDesk coverage 2024-12-12 ("Ranger Finance Targets Crypto Perps Traders of 'Size' on Solana").

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- **No program IDs identified in the bounded window.** Solana programs are referenced via the SDK (API-key routed backend + on-chain routers) but no canonical program address was extracted from the repos/docs summaries reached.
- No JSON-RPC reads performed without a target address.

## Live balances (token, amount, USD, price source, block)
- Aggregator model ⇒ expected protocol-custodied value ≈ **$0** (user funds sit in Drift/Flash/Adrena/Jupiter accounts; DefiLlama TVL null/0). Not independently verified on-chain for lack of program IDs.

## Permissionless paths examined
- None (no program identified). Aggregators without custody present no vault to drain; worst case is routing/authority bugs in its on-chain program, which cannot be assessed without the program ID.

## Approvals / user-side residual risk
- Any user approvals to Ranger's router program remain a residual risk if the program is still live; not enumerable without the ID.

## Classification: S/undetermined (non-custodial aggregator; TVL $0) — $0 measured — confidence low-medium — what would change it
- Extract program IDs from `ranger-finance` GitHub (sor-ts-demo / agent-kit config) and verify executable status + account balances via Solana RPC; expect only rent-exempt program accounts. Flag as no live identifiable value.

## Raw evidence index (files in analysis/)
- Sources checked: `api.llama.fi/protocols` (`ranger-finance-perps`), github.com/ranger-finance, CoinDesk 2024-12-12, DefiLlama perps dashboards, websearch 2026-10-04. Bounded negative dossier.

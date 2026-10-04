# BasePerp — Base (claimed "first Base-native perp DEX")

## Status & shutdown evidence (sources, dates)
- Websites `baseperp.org`, `baseperp.net`, GitBook `baseperp.gitbook.io/baseperp-whitepaper`, X `@BasePerpBuilder`, Chainwire PR 2025-11-03 ("BasePerp to Enable Creation of Perpetual Futures Markets on Base").
- All published material describes the protocol as **pre-launch / active development**: "$BPERP Presale to fund engineering, independent audits, monitoring, testnet operations, and launch readiness", "parameters and timelines are drafts subject to audit and testnet results", "independent security audit is underway".
- No mainnet deployment, no TVL entry on DefiLlama, no shutdown post-mortem found. Census "shut 2026" likely reflects the presale/venture folding; treat as never-launched or abandoned-presale.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- **None published/found.** Bounded checks: no contract address in the whitepaper/site summaries reached via search; DefiLlama adapter repo has no `baseperp` path (GitHub code search `baseperp in:path` → none); no protocol in `api.llama.fi/protocols`; no verified Base deployment surfaced in search results.
- No Base RPC reads possible for lack of addresses.

## Live balances (token, amount, USD, price source, block)
- Unknown/zero on-chain: **no measurable contracts**. Presale proceeds (if any) were off-chain / to team wallets; no protocol vault identified.

## Permissionless paths examined
- None (no contracts). If contracts do exist under an unpublished address, they were not reachable by any public source in the bounded window.

## Approvals / user-side residual risk
- Presale participants likely have no on-chain claim; treat as counterparty loss, not an extractable vault.

## Classification: S/undetermined (no on-chain deployment found) — $0 measured — confidence low-medium — what would change it
- A published Base contract address (from X/Discord/archive) or finding deployment txns from the project's known deployer wallet. Given the presale-only profile, low expected value; flag as no live identifiable contracts.

## Raw evidence index (files in analysis/)
- Sources checked: baseperp.org (home/history/terms), baseperp.net, baseperp.gitbook.io whitepaper, Chainwire 2025-11-03 release, DefiLlama protocols + adapter search, websearch 2026-10-04. Bounded negative dossier.

# Satori Finance (satori-perp) — Linea + multi-chain

## Status & shutdown evidence (sources, dates)
- Decrypt, 2026-06-17: "Coinbase-Backed Crypto Perps Exchange Satori Finance Is Shutting Down" — wind-down announced 2026-06-16; **operations cease after July 16, 2026, 7:59pm ET**; users told to close trades and withdraw ("customers may no longer be able to access their funds").
- Cointelegraph/The Defiant coverage (July 2026) list Satori Finance among recent perp DEX closures.
- DefiLlama slug `satori-perp`: Derivative, chains Linea+Story+Ethereum+BSC+TON+zkSync Era+Base+Arbitrum+Zircuit+Scroll+Polygon zkEVM+Plume+X Layer, TVL **$11,106.91** (pull 2026-10-04). (Note: `projects/satoriSwap` in DefiLlama-Adapters is a different Uniswap-fork DEX on Base/Linea/XLayer; `projects/satori-perp/index.js` returned 404.)

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- **No live identifiable contract set within the bounded window.** The DefiLlama adapter path for `satori-perp` is not present under the expected name in DefiLlama-Adapters main; no official docs/GitHub contract list was reachable in time.
- Bounded sources checked: `raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/{satori-perp,satori-finance,satori}/index.js` (404); GitHub code search `repo:DefiLlama/DefiLlama-Adapters satori in:path` (only `projects/satoriSwap`); `api.llama.fi/protocols` entry (above); Decrypt article; websearch for GitHub org/contracts.
- Linea is where ~$10.4K of the reported TVL sits; **not measured** in this pass.

## Live balances (token, amount, USD, price source, block)
- Not measured — no addresses identified. Reported DefiLlama TVL $11,106.91 implies the protocol (or its remaining vaults) may still hold ~$10–11K on Linea/other chains; this is an unverified indexer figure for this dossier.

## Permissionless paths examined (path → gates → live values → verdict; negative results)
- None examined (no contracts). Given the protocol was a perp exchange and shut down post-July-2026 with a user-withdraw window, expect **H-O** (user self-service withdrawals, possibly still open) or **S** (stuck) rather than E-U. No critical vulnerability identified or excluded.

## Approvals / user-side residual risk
- Users may still hold open positions/collateral at the old perp contracts; withdrawals may be self-service if the withdrawal UI/contracts remain functional.

## Classification: H-O/S (unverified) — ~$10–11K indexed — confidence low — what would change it
- Identify deployments from archived docs (docs.satori.finance), the `Satori-finance` GitHub org, or Linea explorer contract search; then measure vault balances and withdraw gating. Flag to parent: this is the highest unverified indexer value in this batch.

## Raw evidence index (files in analysis/)
- Web sources only (Decrypt 2026-06-17; The Defiant/Cointelegraph July 2026; DefiLlama `api.llama.fi/protocols` entry `satori-perp`). No raw on-chain file (bounded negative).

# Stream Finance — Ethereum (yield/credit)

## Status & shutdown evidence (sources, dates)
- Collapsed **Nov 4, 2025** after disclosing a **$93M loss** by an external fund manager; xUSD stablecoin depegged ~77%. Sources: Yahoo Finance/Decrypt "Stream Finance Stablecoin Plunges 77% After Protocol's Fund Manager…"; CryptoSlate/Cryptopolitan "$93M loss in Stream Fund assets"; DL News "How the Stream Finance debacle affected the rest of DeFi".
- **Wind-down**: The Defiant, "Stream Finance Breaks Six Month Silence With Wind-Down Plan" (2026) — xUSD wind-down steps telegraphed.
- DefiLlama `api.llama.fi/protocol/stream-finance` TVL: **$0 (dead)** per census; not independently re-pulled here (Dune/Ankr/GoldRush quota unavailable at the time).
- Note: settlement is a CeDeFi/fund-manager loss event, not a clean on-chain contract drain; recovery from an external attacker's viewpoint is unlikely.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- **NOT INVESTIGATED ON-CHAIN.** No addresses verified in the time box (server restarts consumed budget). Candidate artifacts to check first: xUSD token, Stream vault/receipt (sxUSD/xUSD) contracts on Ethereum, and any StreamVault/strategy contracts named in the wind-down post.

## Live balances (token, amount, USD, price source, block)
- **Not measured.** Census/DefiLlama TVL = $0. No USD claim made.

## Permissionless paths examined
- **Not examined.** Bounded negative: no on-chain calls were made; do not treat this as proof of emptiness.

## Approvals / user-side residual risk
- Unknown; users holding xUSD/sxUSD should follow the official wind-down process (see The Defiant article) and revoke any Stream-related approvals.

## Classification: S (presumed dead/stuck distribution) — $0 verified — confidence: low — what would change it: on-chain enumeration of Stream vault/xUSD contracts and balances (not done). E-U $0 claimed only as "no evidence", not proven.

## Raw evidence index (files in analysis/raw/)
- None for this protocol (web sources only; URL list above).

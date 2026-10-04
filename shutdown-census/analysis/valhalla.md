# Valhalla (perps) / ValhallaDAO — unknown chain (perps); Avalanche (ValhallaDAO)

## Status & shutdown evidence (sources, dates)
- DefiLlama protocol list (2026-10-04) contains two "Valhalla" entries, neither a perps venue with value:
  - `valhalladao` — Avalanche, category "Reserve Currency" (Olympus-style fork), TVL **5.567966276802548e-07** (~$0).
  - `valhalla` — category "Liquidity Automation", URL `https://valhalla-bot.app/`, TVL 0 (unrelated liquidity bot).
- A perps protocol named "Valhalla" was **not identifiable** in the bounded window; websearch "Valhalla perps DEX protocol shut down 2025 2026" returned only unrelated 2026 shutdown coverage (Dango, BitMEX, Satori, etc.), no Valhalla perps entity.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
- ValhallaDAO (the only Valhalla with known addresses; NOT perps) from DefiLlama adapter `projects/valhalladao/index.js` (fetched 2026-10-04):
  - treasury `0xecd81dfc5a86dd7ffbbe50b8f4ad219950700aa4` (Avalanche), staking `0xfe036c9a04153e60e972c6f46a141fb2e6a6ce48`, token VALDAO `0x84506992349429dac867b2168843ffca263af6e8`
  - Balances not re-measured (bounded pass); indexer TVL ~$0 (MIM + valdaoMimJLP treasury positions).
- No perps contracts identified; none measured.

## Live balances (token, amount, USD, price source, block)
- Perps: no addresses, no balances. ValhallaDAO: indexed ~$0 (not independently measured).

## Permissionless paths examined (path → gates → live values → verdict)
- None (no perps target identified). For ValhallaDAO an OHM-fork treasury is gov-controlled; with ~$0 TVL there is nothing material.

## Approvals / user-side residual risk
- Unknown for the perps entity; ValhallaDAO stakers may have ~0 recoverable.

## Classification: (perps: undetermined, no identifiable contracts) — ValhallaDAO S — ~$0 — confidence low — what would change it
- The census's perps "Valhalla" needs a chain/domain lead (e.g. possible Base/Hyperliquid-ecosystem venue branded Valhalla); nothing was found. ValhallaDAO is a distinct Avalanche reserve-currency fork, TVL ~$0.

## Raw evidence index (files in analysis/)
- Sources checked: `api.llama.fi/protocols` (Valhalla filter), DefiLlama adapter `projects/valhalladao/index.js`, websearch 2026-10-04. Bounded negative dossier.

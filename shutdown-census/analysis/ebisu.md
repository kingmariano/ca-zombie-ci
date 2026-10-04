# Ebisu / Ebisus Bay — Cronos (+ Cronos zkEVM), Ethereum (+ Mode/Plasma)

There are **two distinct projects** in the census data; this dossier covers both and states clearly which is which.

## Status & shutdown evidence (sources, dates)
- **Ebisus Bay** (Cronos DEX + staking; usually spelled "Ebisus Bay"): DefiLlama `protocol/ebisus-bay`, retrieved 2026-10-04: **Cronos $399,820.02, Cronos zkEVM $28,515.37, staking $9,256.29**. Adapter `projects/ebisus-bay/index.js` (retrieved 2026-10-04): UniV2-style factory + `staking(bankContract, FRTN)`.
- **Ebisu** (ebUSD Liquity fork; "Ebisu V2"): DefiLlama `protocol/ebisu`, retrieved 2026-10-04: **Ethereum $25,112, Plasma $0**. Adapter: `registries/liquity.js` entry `'ebisu-ebUSD'`, `eth + plasma 0x5e159fAC2D137F7B83A12B9F30ac6aB2ba6d45E7`. Separately, `registries/deadAdapters.json` lists `ebisu-finance` (ethereum+mode) dead since **2026-07-28** — this is the older "Ebisu V1" CDP (task's "V1 Ethereum $768 / Mode $6.8K" bucket). So: **Ebisus Bay = Cronos DEX/staking; Ebisu (ebUSD) = Liquity-fork CDP. V1 = ebisu-finance (dead 2026-07-28), V2 = ebisu-ebUSD (Eth $25.1K).**

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
Reads at latest (~2026-10-04; Cronos `https://evm.cronos.org`, Ethereum via NodeReal at block 26117051; block numbers not separately captured for Cronos).

| Address | Chain | Role | Code | Owner/paused | Notes |
|---|---|---|---|---|---|
| 0x5f1d751f447236f486f4268b883782897a902379 | Cronos | Ebisus Bay UniV2 factory | live | `owner()` reverts (UniV2-style) | `allPairsLength()=1051` |
| 0x1A695B3aC30D41F9A1D856A27DD0D9DdaaCe750d | Cronos zkEVM | factory (per adapter) | not probed | – | TVL $28.5K |
| 0x1E16Aa4Bb965478Df310E8444CD18Fa56603A25F | Cronos | "bank" staking contract | live | non-standard ABI: `owner()`/`paused()` revert with custom selector fragments (0xf3aee6338da5cb5b / 0xf3aee6335c975abb) | holds **89,384,645.36 FRTN** |
| 0xaF02D78F39C0002D14b95A3bE272DA02379AfF21 | Cronos | FRTN token | live | n/a | implied price ≈ $0.000104 (staking TVL $9,256/89.38M) |
| 0x5e159fAC2D137F7B83A12B9F30ac6aB2ba6d45E7 | Ethereum | Ebisu ebUSD Liquity-fork entry (DefiLlama liquity registry) | live code | all standard calls (`owner`, `paused`, `getEntireSystemColl/Debt`, `symbol`, `totalSupply`, `decimals`, `getTroveManager`) **reverted** at block 26117051 | likely not a proxy core address or a dead/bricked deployment; contract type not confirmed |

## Live balances (token, amount, USD, price source, block)
- Ebisus Bay Cronos: **$399,820.02** TVL (DEX pairs) + **$9,256.29** staked (bank), per DefiLlama 2026-10-04. On-chain confirmation: bank holds 89,384,645.36 FRTN (block latest, Cronos); FRTN implied ~$0.000104/FRTN (DefiLlama TVL ÷ tokens).
- Ebisus Bay Cronos zkEVM: **$28,515.37** (DefiLlama; factory not probed).
- Ebisu ebUSD (Ethereum): **$25,112** (DefiLlama 2026-10-04); on-chain collateral/debt not obtainable with standard ABIs (calls reverted) — bounded pass did not identify the live core contract.
- Ebisu-finance V1 (Eth $768 / Mode $6.8K): **not on-chain verified in this pass**; marked dead by DefiLlama on 2026-07-28.

## Permissionless paths examined (path → gates → live values → verdict)
1. **Ebisus Bay UniV2 pairs `skim`/`sync`** — standard UniV2 semantics (excess-only / reserve update); not measured pair-by-pair (1051 pairs). No drain found.
2. **Bank (staking) withdrawal** — ABI is non-standard (custom `0xf3aee633…` prefix suggests a cloned/custom implementation). Could not resolve `withdraw`/`claim` selectors in the bounded pass; FRTN is staked by users, so any drain would require a bank-level bug. **Not proven.**
3. **Ebisus Bay factory** — no owner, no pause, no admin sweep (UniV2 style). LP principal is in pair contracts; holder-only `burn`.
4. **Ebisu ebUSD CDP** — liquidation/mint gating not examined: the registry address reverted all standard calls, so trove functions could not be probed. **Not investigated — bounded.**
5. **Ebisu-finance V1** — dead since 2026-07-28 per DefiLlama; no live probe.

## Approvals / user-side residual risk
- FRTN stakers retain claims on the bank (if it works); LP holders retain pair redemptions. No unprivileged approval-abuse path identified in the bounded pass.

## Classification
- **Ebisus Bay (Cronos + zkEVM + staking): H-O — $437,591.68 — confidence low** (bounded; bank/factory code not fully read). E-U $0.
- **Ebisu ebUSD (Ethereum): unknown (likely S/P) — $25,112 — confidence low** (standard calls reverted; core not identified). E-U $0.
- **Ebisu-finance V1 (Eth/Mode): S/dust — $768/$6,800 — confidence low** (DefiLlama dead-list only).
- Would change: verifying the bank implementation source and the ebUSD core address (TroveManager/BorrowerOperations), then checking `redeemCollateral`, `liquidate`, oracle gating.

## Raw evidence index (files in analysis/raw/)
- `ebisu_reads.txt` (Cronos factory/bank/FRTN reads; Ethereum ebUSD revert results)
- DefiLlama: `api.llama.fi/protocol/ebisus-bay`, `api.llama.fi/protocol/ebisu`; adapters `projects/ebisus-bay/index.js`, `registries/liquity.js`, `registries/deadAdapters.json`.

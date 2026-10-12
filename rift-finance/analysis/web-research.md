# Rift Finance — desk research (web + GitHub), 2026-10-12

**Scope:** identify the protocol, deployment lists, audits, incidents, and current status. All read-only.
No incidents/exploits found for this Rift (see §5). Marked [confirmed]/[unconfirmed] per source.

## 1. What it is [confirmed]
- DAO-liquidity ("protocol-owned liquidity") tranche protocol by **Recursive Research Inc** (co-founders Austin King, Tyler Tarsi; raised **$18M** Feb-2022, Pantera Capital lead, Two Sigma Ventures, Coinbase Ventures, The Spartan Group, DeFiance, Hashed, Jump Crypto — DefiLlama/Dealroom).
- Mechanism: vaults hold two assets — `token0` "floor" tranche (loss-protected, in practice the WETH/NEAR side) and `token1` "ceiling" tranche (the DAO token side which takes IL/upside); the pair is deployed as Uniswap-V2 LP; `nextEpoch` rebalances and prices each epoch; users claim after epoch close. Matches the on-chain code (see README §3).
- Chains: **Ethereum, Aurora, Fantom** (Fantom legs were not in scope of the triage row; no Fantom vault was found in the deployer's history on the two chains examined — the team's Fantom deployment used a different deployer).
- Aurora launch partners (Medium, auroraisnear): Trisolaris, NearPad, Flux — matching the vault tokens (TRI, PAD, FLX) found on-chain.

## 2. Repository [confirmed]
- `github.com/rift-finance/rift-protocol` — README documents exactly the vault/tranche/epoch model; last commit **2022-06-16** (`f624958`).
- Audit PDFs in-repo: `audits/abdk.pdf`, `audits/certik.pdf`, `audits/peckshield.pdf`.
- No deployment-address list in the README; addresses were enumerated on-chain instead (Core `VaultRegistered` events + full deployer creation history; see README §4/§8).

## 3. Audits [confirmed, no criticals]
- **ABDK** (Rift Protocol Review): 70+ findings, all Minor/Moderate/Suboptimal; notable: CVF-24 (add-liquidity dust threshold, fixed), CVF-26/27 (guardian `rescueTokens` can take user funds while paused — accepted trade-off), CVF-16 (`setEpochDuration` restricted to paused, fixed).
- **CertiK** (2022-02-04): 0 critical; 3 Major all "Centralization/Privilege" (Core/CorePermissions/Vault) — acknowledged; **VCK-01 "Potential Sandwich Attacks" — Informational, Resolved**: `nextEpoch` swaps without min-out rely on the caller-supplied `expectedPoolToken{0,1}` ±0.5% check; CertiK explicitly notes "in case of a human error from the Governor, sandwich attacks could still occur" and accepts the team's mitigation ("sandwich attacks are impossible if arguments are passed correctly").
- **PeckShield** (2022-027, Jan-2022): 9 findings, minor (gas/readability); "Trust Issue of Admin Keys" noted.
- **Implication for this study:** the only economically interesting path (self-called `nextEpoch` with manipulated pool) is gated by *who may call* `nextEpoch`. On Ethereum today that is "any existing position"; on Aurora it is the strategist role only. Both are closed to an external attacker (see PoC).

## 4. Deployment/upgrade history [confirmed on-chain]
- Deployer EOA `0x38e2a3FC1923767f74d2308A529A353e91763ebf` (same on both chains): Aurora first (Apr-2022, 35 creations), Ethereum (May-2022, 14 creations). Mirrored addresses across chains (same nonce sequence), e.g. `0x40A01A40…` is the Core proxy on Aurora but the ProxyAdmin on Ethereum.
- Ethereum vaults created May-2022 with v1 impls, **upgraded to v2 impls in March 2023** (blocks 16,379,187–16,379,303) — v2 added the `depositsEnabled` gate (now `false` on all 9) and changed `nextEpoch` gating from governor → strategist → participant-or-strategist.

## 5. Incidents / status
- **No exploit, hack, post-mortem or rescue found** for this Rift Finance (searches: "Rift Finance exploit/hack/post-mortem/shutdown", Recursive Research, X/Twitter; results were about unrelated projects named Rift/RIFTS).
- Status signals (all indicate the team moved on): company/website `rift.finance` dead (watchlist `deadUrl`; docs.rift.finance 403); X account @RiftFinance dormant (0 posts); repo last commit 2022-06-16; Dealroom marks the DApp inactive since Feb-2025 "due to lack of on-chain activity and unavailability of its official website"; last on-chain activity Nov-2023 (ETH claims), last strategist action Jul-2023 (Aurora).
- DefiLlama still tracks the TVL (live $198,607 on 2026-10-12; ETH $72,289, Aurora $126,317), computed by their adapter from the Rift subgraphs.

## 6. Subgraph endpoints (triage note)
- DefiLlama's adapter (`l2-triage-a/analysis/adapters/rift-finance.js`) uses subgraph IDs Ethereum `44q7UpeVu33BTDwHd1iHJnEYXwcF9NM6HRd5oSVdLFDQ`, Aurora `GkqMC7XyPQFceCjT7rdqc62nzfF5WsVCn6HA9q17VBW` (decentralized-network gateway, requires an API key today). We did **not** rely on the subgraph: vault sets were enumerated directly from Core events, which is authoritative and reproducible.

## 7. Sources
- github.com/rift-finance/rift-protocol (README, audits/*.pdf, commit f624958 2022-06-16)
- api.llama.fi/protocol/rift-finance; defillama.com/protocol/rift-finance
- dealroom.co/companies/rift-finance (team, $18M, inactive status)
- auroraisnear.medium.com "Rift Deploys to Aurora…" (partners), cryptojobslist/company profile (team size/history)
- x.com/RiftFinance (dormant), docs.rift.finance (403)

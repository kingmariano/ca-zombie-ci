# Rage Trade — Arbitrum (v1 delta-neutral vaults)

## Status & shutdown evidence (sources, dates)
- DefiLlama slug `rage-trade-v1` (Arbitrum, TVL $6.07, listed=false); main slug `rage-trade` $0 (delisted). 2026 RootData closure list (via Bitcoin Foundation article "RootData 2026 Crypto Project Closures", 2026) names Rage Trade among DeFi protocols that went dormant/shut down.
- DefiLlama adapter `projects/ragetrade/index.js` (fetched 2026-10-04) lists three Arbitrum vaults measured by `getVaultMarketValue()`, denominated /1e6 into "tether".

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
Measured at Arbitrum block **511551741** (`https://arb1.arbitrum.io/rpc`):
- tricrypto `0x1d42783E7eeacae12EbC315D1D2D0E3C6230a068` — code 4129 bytes; `owner()=0xee2A909e3382cdF45a0d391202Aff3fb11956Ad1` (EOA); `getVaultMarketValue()=0`; `totalAssets()=0`; native 0
- dnGmxSeniorVault `0xf9305009fba7e381b3337b5fa157936d73c2cf36` — code 4099 bytes; same owner; `getVaultMarketValue()=222555`; `totalAssets()=222559`; native 0
- dnGmxJuniorVault `0x8478ab5064ebac770ddce77e7d31d969205f041e` — code 4099 bytes; same owner; `getVaultMarketValue()=5848292`; `totalAssets()=63629023933339567535`; native 0
- Rage Trade v2/perps router: no live deployment identified in bounded pass (docs.rage.trade unreachable from this pass; legacy `app.rage.trade` v1). DefiLlama main slug chains=[] (delisted).

## Live balances (token, amount, USD, price source, block)
- Under DefiLlama's own adapter convention (`raw/1e6` = USDT): total = (0 + 222555 + 5848292)/1e6 = **$6.072** (matches DefiLlama $6.07), block 511551741.
- token-level ERC20 balances not enumerated in bounded pass; `totalAssets` (222559 raw senior, 6.363e19 raw junior) indicate dust-level positions. No native ETH.
- Note: under a 30-decimals interpretation the values are ~1e-25 USD; either way the deployment is economically empty.

## Permissionless paths examined (path → gates → live values → verdict; negative results)
- No public contract was found with a live withdraw/deposit selector enumeration in the bounded window; vaults are owner-controlled (`owner` is a non-timelock EOA `0xee2A…`), and DN-vault withdrawals are normally handler-gated.
- No permissionless call path to move the residual was identified; no liquidation surface known (vault-level market value ~0).
→ E-U $0 (not proven exhaustively; contract source not verified via Etherscan in this pass — expect P if owner EOA is live, S if lost).

## Approvals / user-side residual risk
Not enumerated (bounded pass; residual is dust).

## Classification: P — $6.07 — confidence medium (inferred owner-EOA privileged control; low value makes deeper proof uneconomic) — what would change it
- A verified source showing a permissionless `withdraw`/`redeem` on the junior vault, or owner key loss (→ S), or unexpected large ERC20 balances not reflected by `getVaultMarketValue`.

## Raw evidence index (files in analysis/)
- On-chain reads in this dossier (cast, arb block 511551741) — no raw file saved (short session interrupted); DefiLlama adapter at raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/ragetrade/index.js

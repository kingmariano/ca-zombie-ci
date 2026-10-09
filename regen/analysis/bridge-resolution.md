# C2-27 · The "Toucan NCT bridge $547.1k" claim — resolved

## Verdict
The finding's asset figure is a **misattribution**: **$547.1k is Toucan Protocol's global TVL across four
chains**, not a Regen-governance-controlled pot. Regen governance controls **none** of the Polygon/Celo/Base
contracts and **no** normal message moves the Regen-side bridge/basket funds.

## What the bridge actually is
Two-way TCO2 bridge between Toucan (Polygon) and Regen Ledger, built by Toucan + Regen Network
(repo `github.com/regen-network/toucan-bridge`, archived-lite, last updated 2023-10-14):

- **Polygon contract** `ToucanRegenBridge` **0xdC1Dfa22824Af4e423a558bbb6C53a31c3c11DCC**
  (`contracts/ToucanRegenBridge.sol`; deploys via `deployments/matic/ToucanRegenBridge.json`).
  - `bridge(recipient, tco2, amount)`: burns NCT-eligible TCO2 and emits `Bridge` → Regen side issues credits.
  - `issueTCO2Tokens(...)`: **only `TOKEN_ISSUER_ROLE`** — releases TCO2 on the way back.
  - Constructor roles (args `scripts/arguments-matic.js`): `DEFAULT_ADMIN_ROLE` = `0xCDe1E9f9c7DCAd2242BD85d158A00181aA89B36b`,
    `PAUSER_ROLE` = `0xd4b3e6b915c5f5ba93eebbae0939b130e15c65b9`, `TOKEN_ISSUER_ROLE` = `0x87A13b0A5cE9e621f266b9C68B7014EFCFdddE0a`.
  - **Live state (Polygon block 95,235,089, public RPC):** `paused() = false`; all three role holders still hold
    exactly their roles; `totalTransferred = 1.2737918831e23` raw = **127,379.19 TCO2** bridged lifetime.
  - **None of these roles is Regen governance.** They are operator EOAs; Regen gov proposals cannot call this contract.
- **Regen side**: credits are issued into class **C03** by bridge operator
  `regen1dlszg2sst9r69my4f84l3mj66zxcf3umcgujys30t84srg95dgvs8rn9rj` (class admin + batch issuer, plain BaseAccount).
  All 19 C03 batches have **bank supply 0** now (everything retired or withdrawn); the operator account holds no tokens.

## Regen-side Toucan value: the NCT basket
`eco.uC.NCT` is a Regen x/ecocredit **basket** (id 1, curator `regen1mrvlgpmrjn9s7r7ct69euqfgxjazjt2l5lzqcd`,
accepts class C03, exponent 6, disable_auto_retire).

| item | value |
|---|---|
| NCT total supply | **44,331.178755** (bank denom `eco.uC.NCT`) |
| basket backing (`/regen/ecocredit/basket/v1/basket-balances/eco.uC.NCT`) | **44,331.178755 credits** across 7 C03 batches (C03-005: 28,422.25; C03-008: 9,696.66; C03-007-2017: 2,844.65; C03-009: 2,199.98; C03-002: 621.88; C03-007-2012: 545.30; C03-004: 0.47) — fully backed 1:1 |
| holders | 74; top holder `regen1kq2rzz6fq2q7fsu75a9g7cpzjeanmk68h8wrds` = 38,415.74 NCT (86.7 %) + 11.34M REGEN |
| market value | **$10.2k** at NCT $0.2301 (CoinGecko/DefiLlama); DefiLlama values Toucan's Regen chain TVL at $29.36k (stale ~$0.66/tonne pricing) |

### Can a Regen gov proposal move the basket / bridge funds? **No.**
- `MsgTake` (redeem basket tokens → credits) is signed by the **owner** of the NCT, not the curator/gov
  (`proto/regen/ecocredit/basket/v1/tx.proto`). Basket backing is holder property.
- Gov's only basket message is `MsgUpdateBasketFee` (authority = governance) — changes fees, not custody.
  `MsgUpdateCurator` is signed by the **current curator**, not gov.
- The bridge's Polygon roles are operator EOAs (above); the Regen-side operator account is an EOA.
- The only path to basket/bridge/other-chain assets is a **malicious chain software upgrade** (rewrite state), which
  requires validator adoption — see README §What an attacker can/cannot do.

## DefiLlama Toucan Protocol breakdown (2026-10-09, `api.llama.fi/protocol/toucan-protocol`)
| chain | current TVL (USD) |
|---|---|
| Polygon | 325,904.94 |
| Celo | 159,791.24 |
| Base | 34,735.34 |
| **Regen** | **29,363.14** |
| **total** | **549,794.66** ≈ the finding's "$547.1k" (measured a few days earlier) |

NCT markets are tiny: Polygon NCT/USDC pools ≈ $98.5k combined liquidity, $56/day volume; no NCT market on Regen itself.

# H-35 — Owner & counterparty research (Metis Andromeda, chain 1088)

Safe: `0xdd7c49D1bA862b1285710A30E20C2438b13AE532`
Snapshot blocks: 23238718 / 23238798 / 23238812 (2026-10-04)
Method: Blockscout v2/v1 APIs (andromeda-explorer.metis.io), Metis RPC reads, safe-deployments repo, web search (websearch + Firecrawl), Aave permissions book.
All balances at block 23238812. All code checks at `latest` (≥23238812).

## 1. Owner set (verified 3×: getOwners(), linked-list walk, storage slot 3)

| # | Owner | Role in Safe | First seen | Nonce | Balance (METIS) | Code | 7702 | Explorer label |
|---|-------|--------------|-----------|-------|-----------------|------|------|----------------|
| 1 | `0x02836327aCE76966d0c062A8A25bCBB04e1A0BaB` | initial owner (2023-12-20) | setup | 129 | 4.826 | `0x` | no | none |
| 2 | `0xAdabeccd521dAcE92c85Be0265b84Ca577937882` | initial owner; executed nonce 0–1 | setup | 151 | 4.813 | `0x` | no | none |
| 3 | `0x923170a08b58b18B119e4972DE8d5710b65D1a30` | initial owner; **created the Safe** (factory tx); executed nonce 2 | setup | 43 | 15.734 | `0x` | no | none |
| 4 | `0xb41b842AA0f803eA815eE9A4EEF956ddF8745a66` | added 2023-12-20 15:48 (nonce 0); executed ALL 14 funding txs (2025-12 → 2026-09) | nonce 0 | 72 | 403.093 | `0x` | no | none (but see §2) |
| 5 | `0x0be0515B5369952e4536E0ed2c8133C7F40a0C96` | added 2023-12-20 23:05 (nonce 1) | nonce 1 | **0** | **0** | `0x` | no | none |
| 6 | `0xFA30D7D32288C2F27cD5a099dB7507B085b36071` | added 2023-12-21 16:10 (nonce 2) | nonce 2 | 24 | 7,210.912 | `0x` | no | none |

Notes:
- **All six are plain EOAs**: `eth_getCode` = `0x` at the latest block for every owner → no EIP-7702 delegation (`0xef0100…` marker absent), no contract control, no permissionless entry point through an owner account.
- Owner #5 has **never sent a transaction** (nonce 0, zero balance) — a cold/escrow-style signer key.
- No RemovedOwner events ever; the set only grew 3 → 6.
- None of the owners are labelled on Blockscout (public_tags/private_tags empty; `name` null).

## 2. Identity signals for owners

- `0xb41b842AA0f803eA815eE9A4EEF956ddF8745a66` (owner #4, the active operator):
  - Listed as an **owner of the Metis "Guardian" Safe `0x97177cD80475f8b38945c1E77e12F0c9d50Ac84D` (4/6)** in the Aave DAO permissions book (`aave-dao/aave-permissions-book`, `out/METIS-V3.md`, "Guardians" table). That Safe is the Aave-on-Metis guardian multisig → its signers are Metis-ecosystem operators/delegates.
  - Also appears as a signer of at least one Safe on Ethereum (Etherscan hits for "Smart Account by Safe").
  - Executes all 2025–2026 Safe transactions and holds 403 METIS for gas → the operational/hot proposer of the wallet.
- `0x923170a08b58b18B119e4972DE8d5710b65D1a30` (owner #3): created the Safe through the official factory, and interacts with the **sibling EDF Safe `0xeA0f824CbA2A003d599186DA41A8842E2C4Bd964`** (public explorer tx history), tying it to the same cluster.
- `0x02836327aCE76966d0c062A8A25bCBB04e1A0BaB` (owner #1): owns/interacts with an Ethereum Safe ("Smart Account by Safe 0x878236cd2E580012FA964e45E971A5F6Ac36b884").
- No X/forum post was found that names any of the six owner addresses as individuals. No exploit/loss incident referencing the Safe or its owners was found in public sources.

## 3. Cluster identification — Metis Ecosystem Development Fund (Metis EDF)

Evidence chain (strong, circumstantial — the exact Safe address is not published anywhere we could find):

1. **The funding split is the EDF endowment.** On 2023-12-20 the EOA `0x26eC4FF77DF305d5a9A7660E046dd1c06ce517f6` (Metis ops wallet, active since Metis genesis Dec-2021, 526 txs) sent, in four transactions:
   - 1 METIS (test) + **2,999,999 METIS** → our Safe (total 3,000,000) — blocks 9786880 / 9786892
   - **1,390,000 METIS** → `0xeA0f824CbA2A003d599186DA41A8842E2C4Bd964` (**another GnosisSafeProxy**, same singleton/handler) — block 9786915
   - **200,000 METIS** → EOA `0x1e6A6ad34Ebf2867B3e75D05D645650EB74A2e9a` — block 9787302
   - Total placed: **4,590,000 METIS**.
2. **The EDF was announced on 2023-12-18** as a **4,600,000 METIS** fund, with published allocations: **Sequencer Mining 3,000,000 METIS (65.4%)** and **Ecosystem Funding 1,600,000 METIS (34.6%)**.
   - Sources: metis.io blog "Metis EDF: A New Chapter for Metis" (2023-12-18); The Block (2023-12-18); @MetisL2 on X (2023-12-18).
   - The split matches exactly: 3,000,000 → our Safe ("sequencer mining" wallet); 1,390,000 + 200,000 = 1,590,000 ≈ the 1,600,000 ecosystem allotment. Fund "created December 18, 2023" — wallets funded December 20, 2023.
3. **The sibling Safe shares the signer set**: `0xeA0f824C…` is threshold 4/**7** with owners = our 6 owners **plus** `0x65e4926E02dccD3C58bE135Ea2278518AaAed051`. Same masterCopy (`0xfb1bff…`), same fallback handler (`0x017062…`). Both wallets are operated by the same group.
4. **Spending pattern fits EDF disbursements**: our wallet's 2026 outflows go to an ops wallet (`0xB6bB55B1…`), which forwards to a **BulksenderProxy `0x458b14915e651243Acf89C05859a22d5Cff976A6`** (method `bulksendEther(address[],uint256[],bytes32)`) used for mass distribution — i.e., program/reward payouts, consistent with an ecosystem fund.
5. Sibling Safe's activity: nonce 77, 16,025.5 METIS balance now — clearly the day-to-day EDF wallet; ours (nonce 17) is the larger, slower "sequencer mining" reserve.

**Conclusion (medium-high confidence):** the Safe is the **Metis Foundation / MetisDAO Ecosystem Development Fund (EDF) wallet that received the 3,000,000 METIS sequencer-mining allocation**, operated by a 4-of-6 signer set drawn from Metis Foundation/ecosystem operators (at least one of whom also sits on the Aave-on-Metis guardian multisig).

## 4. Counterparties / recipients

| Counterparty | Type | Observation |
|---|---|---|
| `0x26eC4FF77DF305d5a9A7660E046dd1c06ce517f6` | EOA | Funder: 3,000,000 METIS (2023-12-20). Active Metis ops wallet since Dec 2021; also sent the sibling allocations. |
| `0xB6bB55B1ae79e528d0BeDcD8FaD49A0Ac4252E71` | EOA | Received 653,447.64 METIS (May–Sep 2026). Forwards to `0xab193142…` (≥50,174), `0x5E6299F5…` (163,151), `0x0f33AF4D…` (42,000); small recurring gas top-ups to `0x85f52DE3…`. Ops/payout wallet. |
| `0x0f33AF4DB26A63A916c699f8af0621F57c9737CD` | EOA | Received 89,000 METIS (Jun–Sep 2026); calls **BulksenderProxy `0x458b1491…`** with `bulksendEther` 4× in 2026 to distribute METIS to many wallets → reward/grant distributor. |
| `0x7Ea5c408c84006fA6789C991fc934F177b7fb27F` | EOA | Received 410,000 METIS (Dec 2025); forwarded 200,000 + 1 still-wei to `0x41a950d2…` (2025-12-28) and 50,000 each to `0xE47C50b3…` / `0xd6BBe899…` (2026). Partner/LSD or OTC-style pass-through. |
| `0x65e4926E02dccD3C58bE135Ea2278518AaAed051` | EOA | 7th owner of the sibling EDF Safe; not an owner of ours. |
| Spam tokens received | ERC-20/1155 | `Hi Mom` (100,000), fake-`Metis`/dead-address (185), `NFT 2` (1). Inbound-only airdrop spam; the Safe never interacted with them. |

All counterparties are code-less EOAs except the sibling Safe and the BulksenderProxy. None received a delegation/allowance from the Safe; all outflows were plain `execTransaction` value transfers.

## 5. Search log summary (negative results)

- `"0xdd7c49D1bA862b1285710A30E20C2438b13AE532"` → only metisscan/blockscout/3xpl tracker pages; no social, forum, incident, or leak mention.
- All six owner addresses searched via web + Firecrawl → only explorer pages + the Aave permissions book hit for `0xb41b842A…`; no personal identification.
- `"Metis EDF" multisig signers/address` → official announcement pages only; the exact wallet addresses are not published.
- No exploit, hack, key-leak, or governance post about this Safe or its funds was found (as of 2026-10-04).

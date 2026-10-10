# Djed (Cardano) — C2-55 deep-dive dossier (child-cardano-2)

**Date:** 2026-10-10 · **Chain:** Cardano mainnet (keyless reads only; no signing/sending) ·
**Status:** read-only; validator logic verified from on-chain CBOR/UPLC + hash-verified live state reconstruction.
**Tip at measurement:** block **14,049,765–14,049,880**, slot 200,059,444–200,061,476, epoch 660
(Koios `tip`; ADA/USD **$0.254365**, llama ts 1791627832 = 2026-10-10T10:23Z).

## TL;DR

| Category | USD | What |
|---|---|---|
| **E-U (external unprivileged)** | **$0.00** | no permissionless path to bank/order/oracle/treasury value (gates below) |
| H-O (holder-only) | **$54.00** | 1 pending MintSHEN order (212.304790 ADA) cancellable by its owner |
| P (privileged) | $6.27M custody + all flows | operator (COTI/Artifi key `409d3ec8…`) signs processing; oracle key `51f4ed3f…` signs prices |
| S (stuck) | **$40.13** | 142 ADA at legacy V1 order script (no datum/ticket); 6 malformed 2-ADA V2 orders; 3.78 ADA memocoin dust at bank |

**Live custody (bank address `addr1z8mcpc26…`): 24,642,073.488880 ADA ≈ $6,268,078** (plus preminted token stock).
No extractable value found; see §3 gates and §5 negative results.

## 1. Target set & selection criteria

Djed is COTI/IOG's algorithmic stablecoin. The current (Dec-2024 relaunch) system is defined by the
community front-end registry (`github.com/artifi-labs/open-djed`, HEAD 2026-10-07, `packages/registry/src/index.ts`),
cross-checked against on-chain credentials (bech32 decode + Koios `script_info`). Contract lineage was
enumerated by following the bank UTxOs backwards (Koios `tx_info`/`utxo_info`) — not by blog lists.

| Role | Address (mainnet) | Script hash | Live balance (ref) |
|---|---|---|---|
| **Bank / reserve (current)** | `addr1z8mcpc26j64fmhhd6sv5qj5mk9xqnfxgm6k8zmk7h2rlu4qm5kjdmrpmng059yellupyvwgay2v0lz6663swmds7hp0qhxg9gt` | `f780e15a…` (PlutusV2, 12,698 B) | **24,642,073.488880 ADA** + DJED/SHEN stock + NFTs (UTxO `b1c0f40a…`#0, bh 14,038,672 + 3 dust) |
| Order contract | `addr1wypp5vhw2csaf62d78vmaa4652z20nr4hfgmkhacqnrvgug2vdyq4` | `021a32ee…` (3,002 B) | 224.304790 ADA (7 UTxOs) |
| Order-ticket policy | (policy) `04ea363a…` | `04ea363a…` (4,911 B) | n/a |
| Oracle | `addr1wxyc99q448xlkv4q2y3truxq7j2msr6hkqqg0wmzz9n9r6q8j7kpa` | `89829415…` (2,436 B) | 1.792960 ADA + oracle NFT |
| Oracle NFT policy | (policy) `815aca02…` | `815aca02…` (2,681 B) | n/a |
| Treasury | `addr1w9ut73sw2k94pla354k97zjjxygcxx795hgkdv3hwyp4h8q694wcj` | `78bf460e…` (2,388 B) | **0** (empty) |
| Stake/reward guard | `stake178g00n87…` (reward acct) | `d0f7ccfe…` (302 B) | n/a (0-withdraw guard) |
| Reference-script store | `addr1w83l0f59hjy5wxwk83kdmk7u80rtm2ptgqlndm9ym67jg8q63k62g` | — | 105.146760 ADA (5 ref UTxOs) |
| DJED/SHEN/NFT policy | (policy) `8db269c3…` (PlutusV1, 2,345 B) | `8db269c3…` | total supply 1e18 each, `mint_cnt=1` |
| Legacy bank V1 (Jan-2023) | `addr1z8ru2k4eqtwrf95fvmgxu04pugezz7xg8l3jrrq9mhgh5agm5kjdmrpmng059yellupyvwgay2v0lz6663swmds7hp0q4jak04` | `c7c55ab9…` (PlutusV1, 8,444 B) | **0** (emptied 2023-01-31, bh 8,340,565) |
| Legacy bank v1.2 (2023→Dec-2024) | `addr1zx82ru5f7p8ewhhdvahueg2s4gxs3gxl66fkygdekkjs74sm5kjdmrpmng059yellupyvwgay2v0lz6663swmds7hp0q4vpw0l` | `8ea1f289…` (PlutusV2, 12,785 B) | **0** |
| Legacy bank v1b (Jan-2023) | `addr1z8297ay4…nm8ly0` | `d45f7495…` | **0** |
| Legacy V1 order | `addr1wxy49hzx86ch868hr3uz98lqw8p7ef55j6x8ras7udy3a0gm8cdla` | `8952dc46…` | **142 ADA (4 UTxOs, no datum/ticket)** |
| Legacy V1 treasury | `addr1wx8vgeyxzyrm9qu6ju9fh4useecga8njlwtmqa2357luj3clkzzzx` | `8ec46486…` | 0 |
| Legacy 2024-era order/treasury | `addr1wy3w6lhj…` (`22ed7ef2…`), `addr1wyuzdq9g…` (`382680a8…`) | — | 0 / 0 |

Sources: registry TS (vendored `scripts/open-djed-registry-mainnet.raw.ts`), Koios `address_info`/`address_assets`
(`koios_address_info.json`, `koios_address_assets.json`), `script_info` (`koios_script_info.json`),
`utxo_info`/`tx_info` (`koios_bank_tx_info.json`, `koios_relaunch_txs.json`, `koios_v1_bank_tx_info.json`).

## 2. Live state (exact, hash-verified)

**Bank state reconstruction (proof):** the current bank UTxO `b1c0f40a…`#0 (24,642,069.708550 ADA, bh 14,038,672)
has datum hash `31806cabe96bccf88a61790f745bb8125a1a1f72c7fc35e54e14cab60c4e12c5` (not inline). Starting from the
old pool datum captured in the redemption tx witness (`koios_tx_b1c0f40a_full.json`; old datum hash `cfdc1735…`
matches the spent input) and applying the observed redemption (BurnSHEN 27,216,000,000 micro), the reconstructed
datum hashes **exactly** to `31806cab…` (script `bank_current_datum_reconstructed.json`). Therefore the live
protocol state is:

- `adaInReserve` = **24,642,068.178500 ADA** (bank UTxO lovelace − 1.530050 ADA overhead) = **$6,268,076.63**
- `djedInCirculation` = **1,449,008.966237 DJED** (raw 1,449,008,966,237)
- `shenInCirculation` = **31,196,162.384895 SHEN** (raw 31,196,162,384,895)
- `minADA` = 1.823130 ADA; fixed overhead `_1` = 1.530050 ADA; lastOrder = `a63c6ae9…`#0 @ 1791401413000
- `mintingPolicyUniqRef` = `362e24ab…`#0; lineage ref `_3` = `37116bb7…`#0 (both spent)

**Token stock at bank** (`address_assets`, tip 14,049,765): DjedMicroUSD 999,998,550,991,033,763 (→ circulating
= 1e18 − stock = 1,449,008.966237 DJED); ShenMicroUSD 999,968,803,837,615,105 (→ circulating 31,196,162.384895);
DjedStableCoinNFT 1. `asset_info`: total supply 1e18/1e18/1, `mint_cnt=1` each.

**Collateralisation:** reserves/liabilities = 17.006×. SHEN NAV = (reserves − DJED)/SHEN = 0.743459 ADA ≈ $0.1891
(market on Minswap V2 ADA/SHEN pool 307,410.19 ADA / 512,916.43 SHEN → 0.5994 ADA ≈ $0.152, a ~19% discount to NAV).

**Oracle:** UTxO `71565ca6…`#0, bh 14,049,635, datum = [64-byte signature, {rate 12801/50000 = $0.25602/ADA,
validity 1791623476000–1791624376000 (±15 min)}, "USD", policy 815aca02]. Updated ~every 15 min (several
different signatures observed across snapshots). The bank and oracle scripts both call `verifySignature`
(ed25519) with a hard-coded 32-byte key `51f4ed3f…`; the oracle scripts additionally embed `e35e9582…` (32 B)
and `e194b405…` (28 B). A forged price datum cannot pass the bank's check.

**Activity:** the bank address shows ≥20 txs in the last ~11 days (latest at bh 14,038,672); last processing tx `b1c0f40a…` (bh 14,038,672,
2026-10-07) redeemed 16,337.58 ADA to a user and moved 24.27 ADA to treasury + 24.13 ADA operator fee.
Processing tx pattern (from witness set): spends bank + order UTxOs, withdraws 0 from `stake178g00n…`
(stake guard `d0f7ccfe…`), burns 1 order ticket, recreates bank UTxO, pays user, `addSignerKey(operator)`.

## 3. Mechanism / audit — gates that close E-U

Validator semantics were read from the **live script bytes** (Koios `script_info`; decompiled to UPLC with
`aiken uplc decode`, dumps in `scripts/plutus/*.uplc.gz`), plus the open-source client (`open-djed/packages/txs`,
vendored in `scripts/opendjed/`). No public source/audit for the current validators was found (Tweag's
`Djed-2023-01.pdf` covers the legacy V1 design only; noted as residual uncertainty).

1. **Bank spend (`f780e15a`)** — embed constants: operator PKH `409d3ec8…`, oracle pubkey `51f4ed3f…`, asset
   names, policy `8db269c3…`, order policy `04ea363a…`, order spend `021a32ee…`, oracle policy `815aca02…`,
   treasury `78bf460e…`, fee config (1.5%, operator fee min 5.15 / max 25 ADA, 0.25%), order window 3,600,000 ms,
   `ref (37116bb7…,0)`. One `verifySignature` (oracle price check). The only redeemers used by the client are
   `ProcessOrderSpendPoolRedeemer` (Constr 1); the processor **adds the operator key as required signer**
   (`process-mint-djed-order.ts:143`). Every bank-spending tx on-chain is an operator processing tx
   (witness set shows `valid_contract=True` with the pool datum/redeemers). No admin/update/refund redeemer is
   exposed by the client; no unprivileged path identified. Confidence: **high** (structural), residual = a
   hidden second redeemer branch not exercised by the client (not observed).
2. **Order spend (`021a32ee`)** — embeds only DjedOrderTicket + stake-guard `d0f7ccfe…`; **no signature builtin**.
   Paths: ProcessOrder (Constr 0) and CancelOrder (Constr 1, app adds owner signer, burns ticket
   `cancel-order-by-owner.ts:35,54`). Without the owner key, spending an order requires the operator process
   flow (which routes through the bank). An order UTxO without its ticket cannot be spent (burn −1 of a token
   not present fails value conservation) → the 6 malformed orders are bricked.
3. **Oracle (`89829415` + policy `815aca02`)** — `verifySignature` with constant keys; datum carries a 64-byte
   signature over the price/time fields. Price cannot be forged; oracle UTxO cannot be re-created with a
   different datum without the signature.
4. **One-shot supply (`8db269c3`, PlutusV1)** — DJED/SHEN/StableCoinNFT mint policy is keyed to UTxO
   `362e24ab…`#0 (the Jan-30-2023 genesis output to the operator, 5,000 ADA). `utxo_info`: **`is_spent: true`**
   (spent at bh 8,332,894). `mint_cnt = 1` on-chain. No further minting possible → no inflation/dilution path.
5. **Stake/withdraw guard (`d0f7ccfe`, 302 B)** — small validator requiring the `DjedStableCoinNFT` (policy
   `8db269c3…`) to be involved; invoked as a 0-withdrawal in processing txs. It cannot be satisfied without a
   bank UTxO (which itself is operator-gated).
6. **Treasury (`78bf460e`)** — operator PKH embedded; currently empty (0 ADA), not on any unprivileged path.

## 4. Candidate unprivileged paths tried → result

| Path attempt | Gate that closes it | Evidence |
|---|---|---|
| Drain bank via own order processed by bank | operator signer required for `ProcessOrderSpendPoolRedeemer`; bank verifies oracle-signed price and pool-datum deltas | client `process-mint-djed-order.ts`; bank constants; tx `b1c0f40a` |
| Forge oracle price to mint at wrong rate | ed25519 `verifySignature` vs `51f4ed3f…` in bank+oracle; datum carries signature | UPLC `verifySignature` contexts; oracle datum 64-byte sig |
| Mint more DJED/SHEN (inflation) | one-shot UTxO `362e24ab…`#0 already spent; `mint_cnt=1` | Koios `utxo_info`, `asset_info` |
| Spend someone else's order | order spend has no sig check but routes value through bank; cancel requires owner signer + ticket burn | `cancel-order-by-owner.ts`; order UPLC |
| Spend bank dust UTxOs (memocoins/NFTs) | bank validator expects PoolDatum; no-datum spend fails decoding → stuck | bank UPLC datum decoding; UTxOs `dbb59627…`, `83bc7a17…`, `2bd3680f…` |
| Recover legacy V1 order funds | V1 order UTxOs have **no datum and no ticket**; V1 bank (`c7c55ab9`) retired/empty | `koios_v1_order_addr.json`, `koios_v1_bank_txs.json` |
| Sweep legacy banks | V1 `c7c55ab9` = 0; v1.2 `8ea1f289` = 0; v1b `d45f7495` = 0 | `address_info` batches |

**Negative results (dead ends):** the forum-cited "main contract" `addr1z8ru2k4…` is the retired V1 bank and is
empty; the 2024-era banks and their order/treasury partners are empty; no second live bank deployment was found;
`mint_cnt=1` proves no post-genesis minting.

## 5. Classification & amounts

- **E-U: $0.00 — high confidence.** All value movement requires the operator key, the oracle key, the owner's
  key (cancel), or the spent one-shot UTxO. Unprivileged actions available: create orders (costs the sender
  money) and trigger the 0-withdraw guard (no value). Residual uncertainty: no CEK-machine reproduction of the
  bank gate (marked **CI candidate**: evaluate `f780e15a` with a reconstructed `b1c0f40a` ScriptContext,
  with/without operator in signatories).
- **H-O: $54.00** — pending MintSHEN order `86b113c2…`#0 (212.304790 ADA, bh 14,045,475; owner key
  `cd440b05…`) cancellable by its owner. (Not extractable by third parties.)
- **P: $6.27M bank custody + all processing/oracle authority** — operator PKH `409d3ec8…`, oracle keys
  `51f4ed3f…`/`e35e9582…`; oracle UTxO 1.792960 ADA; ref-script store 105.146760 ADA.
- **S: $40.13** — legacy V1 order address 142 ADA ($36.12; no datum/ticket, validator dead); 6 malformed V2
  orders 12 ADA ($3.05; ticketless); bank memocoin dust 3.780330 ADA ($0.96).

## 6. Blockers / caveats

- Koios returns `address_info` UTxO sets truncated at 6,998 entries; not an issue for Djed (bank ≤ 4 UTxOs).
- No public source or audit found for the Dec-2024 Djed validators; the operator-gate conclusion rests on
  on-chain constants, the client's tx builders, and observed valid processing transactions. A local CEK
  evaluation is the recommended next step (CI candidate) to upgrade confidence from high-structural to proof.
- The oracle update cadence (~15 min) and operator inactivity windows (last processing 2026-10-07) mean
  pending orders may wait; that is liveness, not extractability.
- USD at ADA $0.254365 (llama, ts 1791627832). DJED $1.0017 for stablecoin leg.

## 7. Files

- `koios_address_info.json`, `koios_address_assets.json`, `koios_script_info.json`, `koios_asset_info.json` —
  raw Koios state (tip 14,049,765).
- `koios_tx_b1c0f40a_full.json` — full processing-tx witness set (datums, redeemers, validity, ref inputs).
- `bank_current_datum_reconstructed.json` — reconstructed live pool datum (hash-verified vs `31806cab…`).
- `koios_bank_tx_info.json`, `koios_pool_address_txs.json`, `koios_v1_bank_tx_info.json`,
  `koios_legacy_*`, `koios_oneshot_tx_info.json`, `koios_relaunch_txs.json` — lineage & legacy evidence.
- `scripts/plutus/*.uplc.gz` — decompiled live validators (bank, order spend/mint, oracle+policy, treasury,
  stake guard, V1 bank, V1 policy). `scripts/*.py` — keyless fetch/parse utilities.
- `scripts/opendjed/` — vendored client tx builders/data schemas used as semantics reference.

# Minswap V2 + stableswap (Cardano) — C2-55 deep-dive dossier (child-cardano-2)

**Date:** 2026-10-10 · **Chain:** Cardano mainnet (keyless reads only; no signing/sending) ·
**Status:** read-only; deployed-validator source verified hash-for-hash against on-chain scripts; no local CEK eval.
**Tip at measurement:** block 14,049,765 / slot 200,059,444 (Koios), extended by address_info to 14,049,880 /
slot 200,061,476. Prices: ADA $0.254365 (llama ts 1791627832), BTC $82,750.07, ETH $2,492.54, SOL $109.50,
DJED $1.0017, USDC $0.9997 (stablecoins pegged at $1.00 where no quote; noted).

## TL;DR

| Category | USD | What |
|---|---|---|
| **E-U (external unprivileged)** | **$0.00 (high)** | V2 batching requires an authorized batcher key from the on-chain GlobalSetting (single vkey `5b7e2322…`); pool updates/fee-taking are privileged; no signature-free drain path in source |
| H-O (LP holders) | ≈ **$15.9M** | all V2 LP value (top-292 pools ≈ $15.70M by Minswap USD metric) + stableswap LP ≈ $0.166M |
| P (privileged) | fee-sharing/admin + batcher | GlobalSetting: batcher `5b7e2322…`, fee updater/taker `ac187100…`, stake updater `c4121a88…`, dynamic-fee updater `25af0fc6…`, admin = script `4abd7063…` |
| S (stuck) | small | 45 non-pool datum UTxOs at the pool address; micro-pools (4.5 ADA) |

**On-chain custody measured (Koios `address_info`, tip 14,049,765):**
- V2 volatile pools share **one address** `addr1z84q0denmyep98ph3tmzwsmw0j7zau9ljmsqx6a4rvaau66j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq777e2a`
  (payment `ea07b733…`, stake key `52563c54…`): **3,326 pool UTxOs / 3,325 unique pairs, 26,518,169.351770 ADA
  ($6,745,291) in pools** (26,523,579.308258 ADA at the address incl. 45 non-pool UTxOs).
- 13 mainnet stableswap pools: **$166,262** total (on-chain amounts × prices above), top = USDC-DJED $38,386.

## 1. Target set & selection criteria

Enumerated by on-chain state + official artifacts, not blog lists:

1. **V2 volatile pools**: all UTxOs at the V2 pool address (payment credential = deployed pool validator
   `ea07b733…` from `minswap/sdk` `DexV2Constant.CONFIG` and `minswap-dex-v2/deployed/mainnet/script.json`),
   filtered by the 10-field `PoolV2.Datum` shape (assetA, assetB, totalLiquidity, reserveA, reserveB, fees).
   Count: 3,326 pool UTxOs (3,325 unique pairs; one pair has 2 UTxOs). Pool creation is permissionless
   (`factory_validator.ak`), hence ~3,000 micro-pools.
2. **Stableswap**: 13 pools from `StableswapConstant.CONFIG` mainnet (SDK `constants.ts`), each with its own
   order/pool address; all 13 measured (`koios_stableswap_assets.json`).
3. **V2 contracts**: pool `ea07b733…` (3,965 B), order `c3e28c36…` (2,659 B), factory `7bc5fbd4…` (3,396 B),
   batching stake validator `1eae96ba…` (15,639 B), auth/LP policy `f5808c2c…` (4,699 B), expired-order-cancel
   `c8b0cc61…` (2,854 B), GlobalSetting script at `addr1w86cprpv…`.
4. **V1 re-verification**: separate dossier `../reverify-v1/REPORT.md` (top-3 by USD re-checked on-chain).

## 2. Live funds (exact)

### 2.1 Top V2 pools (my parse `v2_pools_parsed.json` vs my API pull `minswap_v2_metrics_usd_top300.json`)

| Pool | On-chain UTxO (tip 14,049,765) | Minswap API (USD pull) | USD (API) |
|---|---|---|---|
| ADA/NIGHT | 3,790,954.15 ADA; resB 19,750,578.11 NIGHT; bh 14,049,765 | liqA 3,796,094.95 / liqB 19,723,963.37 | $1,931,453 |
| ADA/MIN | 3,072,625.38 ADA; resB 198,265,139.52 MIN; bh 14,049,582 | liqA 3,072,613.39 / liqB 198,265,139.52 | $1,563,346 |
| ADA/SNEK | 2,284,383.28 ADA; resB 650,529,983 SNEK | 2,283,423.64 / 650,803,838 | $1,161,806 |
| ADA/USDM | 1,910,965.75 ADA; resB 487,436.60 USDM | match | $972,295 |
| ADA/USDA | 1,529,538.66 ADA; resB 391,159.08 USDA | match | $778,222 |
| ADA/FLDT | 1,442,186.76 ADA; resB 8,050,740.09 FLDT | match | $733,779 |
| ADA/STRIKE | 1,174,627.53 ADA; resB 568,675.87 | match | $597,634 |
| ADA/ASCEND | 1,168,572.52 ADA; resB 995,117.32 | match | $594,562 |
| NIGHT/SNEK | 583,494 USD (non-ADA pair) | match | $583,494 |
| ADA/SURF | 744,230.54 ADA; resB 1,898,367.95 | match | $378,660 |
| **ADA/DJED** | **445,468.28 ADA + 113,455.89 DJED** (implied $1.00/DJED) | (not in top-300 by LP) | ≈ $560k (self-valued) |
| **ADA/SHEN** | **307,410.19 ADA + 512,916.43 SHEN** (implied $0.152/SHEN) | — | ≈ $385k |

Top-292 V2 pools (3 API pages, sorted by raw LP): **$15,697,462** USD. On-chain ADA in all 3,326 pools:
26,518,169.35 ADA = $6,745,291 ADA-side (CPMM TVL ≈ 2× ADA side ≈ $13.5M for ADA pairs; the API total
$15.7M additionally counts non-ADA pairs and the long tail of ~3,000 micro-pools is negligible).
Reserves in each pool datum are consistent with the UTxO values (ADA side differs from datum only by the
4.5 ADA `DEFAULT_POOL_ADA` + accumulated dust; e.g. ADA/NIGHT UTxO 3,790,954.15 vs datum reserve 3,790,921.28).
Cross-check: the parent's reference pull `raw/minswap_MinswapV2_pools_usd.json` (1,200 pools, 10:57) totals
$15,701,482 with the same top-3 ordering — consistent with my independent pull.

### 2.2 Stableswap (all 13, on-chain `address_assets`)

| Pool | On-chain balances | USD |
|---|---|---|
| USDC-DJED | 18,249.8063 USDC + 20,107.1965 DJED | $38,385.51 |
| DJED-iUSD | 18,193.3376 DJED + 19,820.6842 iUSD | $38,044.60 |
| USDC-iUSD-0.1 | 16,955.2272 USDC + 20,747.8913 iUSD | $37,698.21 |
| wBTC-iBTC | 0.21663319 BTC + 0.061329 iBTC | $23,001.39 |
| USDM-iUSD | 7,292.7878 USDM + 7,434.0266 iUSD | $14,726.81 |
| DJED-USDM | 4,768.9480 DJED + 5,176.1226 USDM | $9,953.09 |
| wETH-iETH | 0.85738221 ETH + 0.237415 iETH | $2,728.83 |
| USDM-USDA | 512.6845 USDM + 472.0481 USDA | $984.73 |
| wSOL-iSOL | 4.29873043 SOL + 1.223664 iSOL | $604.73 |
| DJED-MyUSD / MyUSD-USDM / iUSD-USDA / USDC-iUSD | 2.39 DJED + 47.75 MyUSD / 42.55 + 0.97 / 10.33 + 10.00 / 11.33 + 8.81 | $154.13 |
| **Total** | | **$166,262.02** |

`iUSD`/`USDM`/`USDA`/`MyUSD` priced at $1.00 peg (llama has no quotes); `iBTC`/`iETH`/`iSOL` at their
underlying's price. The pool addresses hold only min-UTxO lovelace (1.7–5.5 ADA each); reserves sit in
asset_list. Stableswap order addresses hold leftovers (e.g. DJED-iUSD order addr: 84.92 DJED ≈ $85).

**Reconciliation with the API (and with the parent's reference pull `raw/minswap_MinswapStable_pools_usd.json`,
$174,507 at 10:57):** the Minswap API lists **14** stableswap pools (one newer USDC/iUSD pool not yet in the
SDK constants: 137.87 USDC + 43.71 iUSD ≈ $182 by labeled prices; total with it ≈ $166,444). The residual
difference is **pricing, not balances**: for the same pools the API's per-side USD implies USDC ≈ $1.18–1.19
and iUSD ≈ $1.06 (e.g. USDC-DJED: API `liquidity_a_currency` 21,695 vs 18,246 USDC held) and BTC ≈ $73.9k vs
llama $82.75k — while its balances agree with my on-chain reads (USDC-DJED: API 18,245.87/20,102.96 vs
on-chain 18,249.81/20,107.20, 0.02% drift; wBTC-iBTC 0.1% drift; DJED-iUSD 3% drift on an actively trading
pool). This dossier therefore uses **on-chain balances + labeled/external prices**; the API's USD is quoted
alongside for comparison, not as ground truth.

## 3. Audit — deployed source is public and matches on-chain byte-for-byte

`github.com/minswap/minswap-dex-v2` (audited by CertiK + Anastasia Labs). `deployed/mainnet/script.json`
scripts hash (unwrapped, `blake2b_224(0x02‖CBOR)` convention) **exactly** to the on-chain scripts I fetched
from Koios (`script_hash_verify` table in `koios_v2_script_info.json`; see `scripts/plutus/*.uplc.gz` dumps):

| Contract | deployed/mainnet hash = on-chain | size |
|---|---|---|
| poolScript | `ea07b733d932129c378af627436e7cbc2ef0bf96e0036bb51b3bde6b` | 3,965 B |
| orderScript | `c3e28c36c3447315ba5a56f33da6a6ddc1770a876a8d9f0cb3a97c4c` | 2,659 B |
| factoryScript | `7bc5fbd41a95f561be84369631e0e35895efb0b73e0a7480bb9ed730` | 3,396 B |
| poolBatchingScript | `1eae96baf29e27682ea3f815aba361a0c6059d45e4bfbe95bbd2f44a` | 15,639 B |
| authen/lp policy | `f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c` | 4,699 B |
| expiredOrderCancel | `c8b0cc61374d409ff9c8512317003e7196a3e4d48553398c656cc124` | 2,854 B |

**Gates (source refs, vendored under `raw/minswap-dex-v2/`):**
- `validators/pool_validator.ak` — spend redeemer `Batching` only requires the tx to withdraw from the pool's
  `pool_batching_stake_credential` (line 34–38). `UpdatePoolParameters` / `WithdrawFeeSharing` are gated by
  GlobalSetting authorizers via `authorize_pool_license` (lines 39–136).
- `validate_pool_batching` (pool_validator.ak lines 141–390): requires `authorize_pool_license(batcher_address)`
  where `batcher_address = batchers[batcher_index]` from the **GlobalSetting** datum (lines 173–197); no minting;
  order inputs must be exactly the input_indexes; then either
  `pool_state_out == order_validation.apply_orders(...)` (single pool) or
  `validate_swap_multi_routing_order` (≤3 pools, line 379) — the full order-economics validation.
- `lib/amm_dex_v2/utils.ak:518` `authorize_pool_license`: `PAMSignature(pkh)` → `list.has(extra_signatories, pkh)`;
  script variants require an input/withdrawal of the script. **No validator contains an ed25519 verify builtin**
  (checked all six UPLC dumps) — authorization is signature-presence or script-presence only.
- **Live GlobalSetting** (`koios_global_setting.json`, UTxO `0dc17712…`#0, 1.96050 ADA, bh 10,532,125 —
  unchanged since Aug-2024): batchers = **[`5b7e23228dba75595645fc357d0f97ba258cfccfff5d588d4bb9165b`]** (single vkey);
  fee updater/taker `ac187100…`; stake-key updater `c4121a88…`; dynamic-fee updater `25af0fc6…`;
  admin = `PAMSpendScript(4abd7063…)`.
- **Audits:** CertiK (`audit-report/certik/`): 0 Critical; 3 Major — 2 Resolved (parameter/reserve validation,
  fee numerator/denominator zero checks) + 1 Acknowledged (**VAL-01 centralization: admin/batcher key power**);
  1 Medium **Resolved** (FAC-02 pool creation complete-withdrawal) + 1 Minor + 5 Informational. Re-audit confirms
  fixes. Anastasia Labs report PDF is image-only (not locally text-extractable; noted as blocker, not OCR'd).

## 4. Candidate unprivileged paths → result

| Path attempt | Gate that closes it | Evidence |
|---|---|---|
| Become batcher and self-deal | `batcher_index` must index GlobalSetting `batchers`; live list = 1 vkey; `authorize_pool_license` requires its signature | `pool_validator.ak:184-197`; `koios_global_setting.json` |
| Spend pool UTxO directly (bypass batching) | `Batching` branch requires withdrawal from the pool's batching stake credential; that validator enforces the batch | `pool_validator.ak:34-38` |
| Mint fake LP / inflate LP | batching forbids mint (`value.is_zero(from_minted_value(mint))`, line 196); LP amounts checked in `apply_orders`/factory | source + CertiK findings |
| Drain via pool creation | factory validator license gate; FAC-02 fixed (CertiK medium, resolved) | `factory_validator.ak`; CertiK |
| Update pool fee/params | privileged authorizers from GlobalSetting | `pool_validator.ak:39-93` |
| Take fee sharing | `fee_sharing_taker` only | `pool_validator.ak:94-136` |
| Fake pool micro-UTxOs (4.5 ADA) | permissionless creation by design; each pool is isolated, no shared value | parse: 4.5 ADA pools with 0 reserves |

**Negative results:** no signature-free value path found in the six live validators; the only unprivileged
actions are creating pools/orders and cancelling your own orders (expired-order cancel script `c8b0cc61…`).

## 5. Classification

- **E-U: $0.00 — high confidence.** Batcher/admin authority (single vkey + multisig script) gates all
  value-moving operations; audits show no open criticals; deployed code verified identical to audited source.
  Residual risk = compromise of the batcher key `5b7e2322…` or admin script `4abd7063…` (centralization,
  acknowledged by CertiK VAL-01), which is P, not external-unprivileged.
- **H-O ≈ $15.9M** (V2 top-292 $15.70M + stableswap $0.166M) — LP withdrawals via the live batcher
  (pending orders: 937 on ADA/NIGHT, 143 on ADA/MIN, etc. — batcher is actively processing; block heights of
  pool UTxOs are at tip).
- **P**: fee-sharing LP, admin/batcher powers (GlobalSetting above).
- **S**: 45 non-pool datum UTxOs at the pool address + micro-pools (4.5 ADA each, reserves ~0).

## 6. Caveats / blockers

- Stableswap USD uses peg prices for iUSD/USDM/USDA/MyUSD; iBTC/iETH/iSOL valued at underlying (no direct
  quotes). If pegs break, USD shifts proportionally (all legs are small except USDC-DJED, which is fully priced).
- Minswap API values can drift from chain state between snapshots; observed drift on ADA/MIN was ADA +0.13% /
  MIN −0.13% over ~15 min of active trading — consistent, not a data conflict. Two zero-volume pools matched
  to the lamport.
- Anastasia Labs audit PDF is scanned (no text layer); not machine-read here.
- No CEK-machine reproduction of a live V2 batch; source-vs-on-chain hash equality is the verification anchor.

## 7. Files

- `v2_pools_parsed.json` — all 3,326 pool UTxOs with decoded datums/reserves (from `address_info`).
- `koios_v2_script_info.json`, `koios_v2_script_info2.json` — script bytes + hash checks; `scripts/plutus/*.uplc.gz`.
- `minswap_v2_metrics_usd_top300.json` — my USD API pull (3 pages).
- `koios_stableswap_assets.json`, `koios_stableswap_info.json`, `minswap-stableswap-configs.json`,
  `stableswap_usd.json` — stableswap evidence and valuation.
- `koios_global_setting.json` — live batcher/admin authority.
- `raw/minswap-dex-v2/` — vendored audited source (validators + lib + deployed params/scripts) matching on-chain.
- `reverify-v1/REPORT.md` — independent re-verification of the parent's Minswap V1 numbers (top-3 by USD).

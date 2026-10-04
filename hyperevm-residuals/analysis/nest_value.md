# Nest protocol on HyperEVM — exact live value held at block 47620218

**Date:** 2026-10-04 · **Chain:** HyperEVM (chainid 999) · **Block:** 47620218 (2026-10-04T06:42:44Z) · **Method:** read-only `eth_call`/`eth_getBalance` at that exact block; no transactions, no signatures.

This is the live-state measurement input for the H-32 headline. Every number below is an on-chain balance read; prices are DefiLlama (`coins.llama.fi/prices/current/hyperliquid:0x…`, timestamp recorded), with Nest app-snapshot prices as a labelled fallback where DefiLlama has no entry. Raw reads: `analysis/nest_value_raw.json`, `analysis/nest_value_stage3.json`, `analysis/nest_native.json`; computed totals: `analysis/nest_value.json`.

## 1. Headline

| # | Item | Amount | USD | Where it sits |
|---|---|---|---|---|
| **X** | **Pool token balances** (69 V3 + 3 V2) | — | **$27,755,149.24** | `balanceOf(pool)` for token0/token1 of every pool |
| | ↳ V3 pools | | $27,386,351.59 | 69 Algebra-style CL pools |
| | ↳ V2 pairs | | $368,797.63 | 3 Solidly-style pairs |
| | Fee vaults (collected protocol fees, 72) | — | $4,036.88 | per-pool `FeesVault` contracts |
| | Gauge token dust (NEST sitting in gauges) | — | $10,813.80 | gauge 0xd61e… only |
| | Protocol NEST dust (Voter) | — | $0.00 | `<2.96e-8 NEST` |
| | Algebra community vault + factory | — | $0.00 | zero on all 43 measured tokens |
| | **Subtotal, protocol-held excl. veNEST** | | **$27,769,999.92** | |
| **Y** | **veNEST locked NEST** (separate asset class) | 1,626,144,414.87 NEST | **$27,847,667.18** | veNEST voting escrow 0x2f2A… |
| | **Total measured (X + fees + Y, no double count)** | | **$55,617,667.10** | |

**Informational, explicitly NOT added (claims / third-party):**
- Gauge-staked LP: `0xd61e0416…` holds **99.5417%** of the NEST/WHYPE V2 pair LP (147,862.758 / 148,543.483 LP). Underlying claim ≈ **$366,841.68** — already inside X (pool balances); LP is a claim on those tokens, not a second asset.
- Third-party Ichi/Steer vaults: idle token balances ≈ **$296,996.51** at 35 vault addresses (user funds, third-party managed; excluded from protocol totals). Their in-pool positions are counted in X.

## 2. Cross-check against DefiLlama “nest CL”

- DefiLlama protocol snapshot (`llama-nest-cl.json`, `tokens`/`tokensInUsd` latest entry, **2026-10-04T03:19:23Z**): **$27,300,109.94** (sum of 29 priced tokens).
- On-chain at 06:42:44Z: V3-only **$27,386,351.59** (+0.32% vs llama, consistent within 3.4h of trading/price drift) and all pools incl. V2 **$27,755,149.24**.
- The DefiLlama composition config appears to track **CL/V3 pools only**: its NEST amount 41,717,552 vs our V3-only 41,716,768 (0.002% apart) while the full on-chain NEST count is 52,376,755 — the 10,659,987 difference is the NEST/WHYPE V2 pair, which llama omits.

| Token | llama snapshot | on-chain V3-only | on-chain all pools | comment |
|---|---|---|---|---|
| WHYPE | 138783.83795 | 136,433.0766 | 138,503.0409 | snapshot lag / active-pool drift |
| USDC | 7766443.8877 | 7,829,434.3486 | 7,829,490.3743 | snapshot lag / active-pool drift |
| NEST | 41717552.39621 | 41,712,767.8115 | 52,376,754.5024 | llama = V3 only (excl. V2 NEST) |
| KHYPE | 25702.56603 | 24,411.4467 | 24,411.4467 | indexer composition difference (see §11) |
| UBTC | 24.50398 | 24.6396 | 24.6396 | snapshot lag / active-pool drift |
| UETH | 271.37574 | 271.9705 | 271.9705 | snapshot lag / active-pool drift |
| USDT0 | 353780.86516 | 350,228.7248 | 350,364.7783 | snapshot lag / active-pool drift |
| KNTQ | 1253787.53798 | 1,229,193.2206 | 1,229,193.2206 | indexer composition difference (see §11) |

Where the two token amounts can be compared directly, the app-API's own per-pool `tvl0`/`tvl1` fields (same pool set) match our on-chain reads closely (worst individual-token drift ±22% on the busiest pool `0xbe512f58…`, USDC/WHYPE, while its USD value moved only +8.1% over the 3.4h window). The remaining per-token differences vs llama (KHYPE −5.0%, KNTQ +2.0%, sKNTQ −20%) are indexer composition differences: llama’s per-token split is not reproducible from the app API's own snapshot fields, but the aggregate totals agree to +0.3%. Our block-pinned on-chain reads are the authoritative measure.

On-chain registration check: `Voter.poolsCounts()` returns `(55, 1, 54)` (total registered 55 = 1 V2 + 54 V3) and `v3Pools`/`v2Pools` enumeration yields exactly the 55 gauged pools. The other 17 app-API pools are factory pools not yet registered with the Voter (no gauge); they were still measured. No on-chain pool was found outside the 72-pool app list.
## 3. Per-token composition of pool balances (plus fees / gauge dust)

Rows sorted by pool USD. `pools` = `balanceOf(pool)` sums; `fee vaults` = collected protocol fees; `gauge dust` = NEST tokens parked in gauges. veNEST locked NEST is a separate line at the bottom.

| Token | Price USD | Source | Pools amount | Pools USD | Fee vaults USD | Gauge dust USD |
|---|---|---|---|---|---|---|
| WHYPE | 89.84945376 | defillama | 138,503.040931 | $12,444,422.57 | $1,401.68 | $0.00 |
| USDC | 1.000023801 | defillama | 7,829,490.374270 | $7,829,676.72 | $341.37 | $0.00 |
| KHYPE | 92.28558262 | defillama | 24,411.446717 | $2,252,824.58 | $79.31 | $0.00 |
| UBTC | 84968.21786 | defillama | 24.639553 | $2,093,578.87 | $56.32 | $0.00 |
| NEST | 0.01712496561 | defillama | 52,376,754.502392 | $896,950.12 | $1,278.93 | $10,813.80 |
| UETH | 2695.440828 | defillama | 271.970513 | $733,080.43 | $74.57 | $0.00 |
| KNTQ | 0.3091016 | defillama | 1,229,193.220560 | $379,945.59 | $159.09 | $0.00 |
| USDT0 | 0.9998562996 | defillama | 350,364.778283 | $350,314.43 | $1.44 | $0.00 |
| USDV | 1.00100045 | nest_api_snapshot | 244,640.392814 | $244,885.14 | $0.00 | $0.00 |
| DRV | 0.4103843627 | defillama | 442,434.778009 | $181,568.31 | $10.68 | $0.00 |
| wNVDAx | 234.6284713 | defillama | 275.721015 | $64,692.00 | $333.20 | $0.00 |
| QONE | 0.00432507761 | nest_api_snapshot | 10,844,714.010936 | $46,904.23 | $0.07 | $0.00 |
| UPUMP | 0.00643763534 | defillama | 7,172,211.685728 | $46,172.08 | $7.80 | $0.00 |
| PURR | 0.171789048 | defillama | 185,781.736695 | $31,915.27 | $0.00 | $0.00 |
| wSPYx | 774.2141542 | defillama | 30.909783 | $23,930.79 | $30.91 | $0.00 |
| TREAD | 1.110261415 | defillama | 21,110.509425 | $23,438.18 | $86.59 | $0.00 |
| wQQQx | 752.2257955 | defillama | 23.818548 | $17,916.93 | $43.71 | $0.00 |
| USOL | 120.9660747 | defillama | 142.774739 | $17,270.90 | $0.00 | $0.00 |
| wMUx | 1069.574367 | defillama | 14.986069 | $16,028.71 | $31.28 | $0.00 |
| wSKHYx | 194.24 | defillama | 72.922967 | $14,164.56 | $31.33 | $0.00 |
| HPL | 0.01214598484 | defillama | 995,194.196651 | $12,087.61 | $0.00 | $0.00 |
| sKNTQ | 0.3194271209 | defillama | 26,471.469664 | $8,455.71 | $0.00 | $0.00 |
| LHYPE | 92.51377607 | defillama | 88.477742 | $8,185.41 | $0.00 | $0.00 |
| ALT | 0.000471960892 | nest_api_snapshot | 14,362,207.675865 | $6,778.40 | $0.00 | $0.00 |
| CAT | 0.1878495783 | nest_api_snapshot | 16,702.375920 | $3,137.53 | $3.11 | $0.00 |
| HAR | 0.002333748607 | defillama | 877,922.113406 | $2,048.85 | $0.00 | $0.00 |
| ONEAR | 4.823616554 | nest_api_snapshot | 397.067223 | $1,915.30 | $0.15 | $0.00 |
| SIGNAL | 0.001930097321 | nest_api_snapshot | 793,722.708006 | $1,531.96 | $55.15 | $0.00 |
| EGG | 0.0002997110458 | nest_api_snapshot | 1,494,500.241190 | $447.92 | $10.14 | $0.00 |
| USDH | 0.9995975492 | defillama | 447.487325 | $447.31 | $0.00 | $0.00 |
| wstHYPE | 92.88600105 | defillama | 3.136387 | $291.33 | $0.00 | $0.00 |
| bbHLP | 1.17280073 | nest_api_snapshot | 110.399473 | $129.48 | $0.01 | $0.00 |
| UXPL | 0.0960658702 | defillama | 51.857903 | $4.98 | $0.00 | $0.00 |
| HYPE5L | 1.100353813 | defillama | 3.037951 | $3.34 | $0.00 | $0.00 |
| PERPME | 0.0003464060321 | nest_api_snapshot | 9,315.532652 | $3.23 | $0.05 | $0.00 |
| kmHYPE | 91.93327982 | defillama | 0.003750 | $0.34 | $0.00 | $0.00 |
| UFART | 0.1758502683 | defillama | 0.699572 | $0.12 | $0.00 | $0.00 |
| *veNEST locked NEST* | 0.01712496561 | defillama | 1,626,144,414.87 | $27,847,667.18 | — | — |

## 4. Largest pools (top 15 by on-chain USD)

| Pool | Type | USD (on-chain) | API tvlUSD (snapshot) |
|---|---|---|---|
| `0xbe512f5881b85c48d9c17bc5bb2be047d156d696` | V3 | $11,805,101.45 | $10,916,088.71 |
| `0xa83d60b1a9ca6dd1d0d2d9275c700114f2f3a8d6` | V3 | $5,754,874.33 | $5,735,794.28 |
| `0xcd238eafadb112515910f8d09d94a90ac8c180fe` | V3 | $3,524,486.81 | $3,506,853.23 |
| `0x535f30f50ebda33575242c38b976e681d13db6fa` | V3 | $868,473.21 | $877,006.67 |
| `0xc8e5ee73b80bb3f6c9b5348771de8217abd412e7` | V3 | $635,588.01 | $634,778.20 |
| `0x998007a512531d9081e116f85605c40d41abd4f1` | V3 | $603,651.93 | $602,929.07 |
| `0x613bc619741354a6171692b04228c9640373e54b` | V3 | $566,213.43 | $566,197.27 |
| `0x770e777cd0be387712cc22444d73de3d60ec0cf8` | V3 | $432,576.79 | $427,591.70 |
| `0xb3fe25af019a8526af0875f5cabf8dc62c87ba74` | V3 | $394,622.28 | $393,924.05 |
| `0x9aa281b23341ce69d4b1500367a43cfc42005538` | V2 | $368,530.53 | $371,617.38 |
| `0xdb544d63d32d9f3e52ff3a8bfe2a374df0463f8d` | V3 | $301,146.39 | $302,198.51 |
| `0x10e8c38bf10f80316603011444d9a1ddc45781f5` | V3 | $257,775.91 | $257,479.17 |
| `0x34a4539f9527d20985e3d14e81d8b473015acf9c` | V3 | $254,876.52 | $254,281.13 |
| `0x51323f313e36a93fac2e1e929e48b961ffce5510` | V3 | $244,992.20 | $244,107.01 |

Per-pool on-chain vs API differences on the biggest pools are ≤~8% and are fully explained by the ~3.4h gap between the API snapshot and the measurement block (on-chain balances of active pools move with swaps): e.g. pool `0xbe512f58…` WHYPE −6.1% / USDC +22.1% vs its API capture, while the pool's USD value moved only +8.1%.

## 5. veNEST (locked NEST) detail

| Field | Value | Call |
|---|---|---|
| veNEST proxy | `0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074` | |
| `supply()` (locked NEST) | 1,626,144,414.8657568 NEST | `0x047fc9aa` |
| `NEST.balanceOf(veNEST)` | 1,626,144,414.8657568 NEST | `0x70a08231` — **identical to supply()** |
| `permanentTotalSupply()` | 1,464,448,156.8128357 NEST | `0x94340b05` |
| `votingPowerTotalSupply()` | 1,547,824,024.927683 | `0xe1ba0c00` |
| veNFT count (`totalSupply()`) | 4,043 | `0x18160ddd` |
| NEST `totalSupply()` | 1,888,234,281.4212382 | `0x18160ddd` |
| Locked share of supply | 86.1198% | |
| NEST price used | $0.0171249656 (DefiLlama ts 1791094910, confidence 0.99) | |

Consistency checks: NEST balances of other protocol contracts at the same block — Minter `0`; veNEST implementation `0`; `0x6652173b0cb3d96d8f0198bc49670440dec69e79` `0`; Voter `0.00000002958` NEST. NEST held by pools (52,376,755) and by veNEST (1,626,144,415) are disjoint holdings of the same token (no overlap).

Independent spot cross-check: the NEST/WHYPE V2 pair held 10,663,986.69 NEST + 2,069.13 WHYPE at the block → implied NEST = 2,069.13 × $89.8495 / 10,663,986.69 = **$0.017435**, within 1.8% of the DefiLlama price.

## 6. Fee vaults (collected protocol fees)

- **72** FeesVault contracts, exactly one per pool, all discovered via `FeesVaultFactory.getVaultForPool(pool)` (`0x705C76e29977Ed52cd93d390A7BBcC61189724C0`); each vault's `pool()` was read back and matched; every gauge's `feeVault()` equals its pool's factory vault — **0 mismatches**.
- Total held: **$4,036.88** in token0/token1 (already-collected protocol fees; tokens sit in the vault, outside the pool → additive).

| Vault | Pool | USD |
|---|---|---|
| `0xaf8f8ca04193ff402284112bdbffc5eddc63ae51` | `0x9aa281b23341ce69d4b1500367a43cfc42005538` | $1,812.85 |
| `0xd78911e236523bffe1e145bc3dd75800a37a817b` | `0x7c2e280a67450add5fafc4db2be5c37c59088d9b` | $586.34 |
| `0xf6ab3217062be4bb2ced7fa473de3d2cae848799` | `0xe97f704999f518a1cc6a65d86b3983c4f5b81bad` | $304.04 |
| `0x1b1f2f313635749d5c08999f515756dbf394e032` | `0xb1fb35a21f2e1dcc6f287bb24bc67199a054adab` | $167.67 |
| `0xac330d0f04d7de9b6fddb85aeac1eb897b1cab8f` | `0x23d95b24ad0c1ff48816a87e1e65dac4fa883afb` | $160.35 |
| `0x1d4173e3d2712c863356c7a2f33cf23d11f48592` | `0xe1c37bb4041b1b5658f8e04dea44c77ec11fb55f` | $139.84 |
| `0xdbc63552ec901e366a840a426f463e35e6339616` | `0x5c7f033356633ab50caece92482e8eb484a2c871` | $135.67 |
| `0x7831de1975f28e5d6edb0ff2e6153469a7334c0e` | `0x20dec26f23b686a9d621ea374fe37d3668c87adb` | $122.81 |
| `0xb7b96bda6df91eb5fbcab75e6e2814667cfe7451` | `0x6f0f99b14d5135d15619f8e7fc71658cefc0e903` | $111.68 |
| `0xa69240f92bad7543a4dcde1725ff8a6297ba8ab5` | `0x0d7ea7b8bc9c0aad5baf3b93971d1fc6953d4e56` | $106.03 |

## 7. Gauges — staked LP accounting (informational; not added)

- 55 gauges from the API; `Voter.poolToGauge(pool)` (proxy `0x566bdc54…`) returns exactly those 55 addresses — **0 mismatches**.
- **54 of 55 gauges have `totalSupply() == 0`** (no LP staked); their token0/token1 balances are also 0 and the gauge `TOKEN()` is the pool itself (a non-ERC20 for V3), so there is no gauge-level value to add for V3.
- The only non-empty gauge is `0xd61e0416a3ce369fb1c328ecb84dfe8cea168219` (NEST/WHYPE **V2** pair `0x9aa281b2…`): `totalSupply() = 147,862.75806538455` LP vs pair `totalSupply() = 148,543.48257966977` LP → **99.5417% staked**. The staked LP is a claim on the pair's token balances already counted in X (claim value ≈ $366,841.68); it is **not** added.
- The same gauge additionally holds **631,463.798 NEST** (non-LP tokens, $10,813.80) — counted under “other”.

## 8. Algebra community vault / factory

- `AlgebraCommunityVault 0x15E408A37cE4D13218202C0054B0f485E38F5768` and `AlgebraFactory 0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3`: **zero balance for all 43 measured tokens**, and zero native HYPE. Nothing to add ($0.00).

## 9. Third-party Ichi/Steer vaults (excluded from protocol totals)

35 vault addresses are advertised in the Nest app pools API (Ichi/Steer automated LP managers). Their **idle** token balances at the block total **$296,996.51** (mostly WHYPE 3,100.65 = $278,591.74; KHYPE 126.91 = $11,711.81; USDT0 6,673.16 = $6,672.20; USDC 19.11; NEST 95.58 with the HYPE-composition rest). These are third-party/user funds and are not protocol-owned. Tokens those vaults have deposited into pools are inside X; only the idle portion above sits at vault addresses.

## 10. Method, completeness checks, no-double-count proof

1. **One explicit block** `47620218` (ts 2026-10-04T06:42:44Z) pinned for every read in stages 2–4.
2. **Pools:** all 72 IDs from the authoritative app API. On-chain check: 72/72 have code; on-chain `token0()`/`token1()` match the API 72/72; `balanceOf(pool)` read for both tokens (144 balanceOf calls + 144 token0/token1 calls).
3. **Gauges:** `poolToGauge` for all 72 pools; 55 gauges; `TOKEN()`, `totalSupply()`, `feeVault()` read for each; token balances read for both pool tokens; LP `balanceOf(gauge)` read for the V2 pair.
4. **Fee vaults:** `getVaultForPool` for all 72 pools (72 distinct vaults); `pool()` verified; token0/token1 balances read.
5. **veNEST:** `supply`/`totalSupply`/`permanentTotalSupply`/`votingPowerTotalSupply` + `NEST.balanceOf` for veNEST proxy/impl/Minter/Voter/0x6652…/Algebra vaults + NEST totalSupply.
6. **Algebra vault/factory** balances for all 43 measured tokens + native balances of 72 pools/55 gauges/72 vaults/core contracts (all zero native HYPE).

**No double counting:** the headline adds only balances held at **disjoint addresses**: pool contracts (X) + fee-vault contracts + gauge NEST dust + Voter dust + Algebra vault. Gauge-held LP is *by construction* excluded and reported as a claim, because the LP represents the pool tokens already inside X. veNEST locked NEST is held by the veNEST contract and is reported as a separate asset class Y. The per-token table's “total” column never sums into the headline.

## 11. Caveats and gaps

- **Prices:** 29 of 43 tokens priced by DefiLlama at block time (timestamps in `nest_value.json.price_timestamps`); the other 14 use the Nest app snapshot's own `priceUSD` (source labelled `nest_api_snapshot`, no timestamp). The fallback-priced tokens are small: the largest are QONE ($46,904), ALT ($6,778), CAT ($3,141), ONEAR ($1,915), SIGNAL ($1,587), EGG ($458), USDV ($244,885 — main one: a stablecoin, plausible), bbHLP ($129), PERPME ($3); rest ≈ $0. If the fallback prices are wrong by 2×, the pool total error is ≤ ~$0.3M (~1.1%).
- **Two non-standard token addresses** appear in two $0-TVL API pools: `0x9d0e8f5b25384c7310cb8c6ae32c8fbeb645d083` has **no code** (not a contract; `balanceOf` returns empty → 0) and `0x78cc152a531dbde2f3fe7001ad659fa120fa893b` has code but `decimals()`/`totalSupply()` revert (balance read as 0). Both pools show API TVL $0, so no value is omitted.
- **Timing:** the API/llama snapshots are ~3.4h older than the block; per-pool token amounts differ where pools traded (documented in §4). The on-chain numbers are the exact state at the block; they drift continuously with swaps.
- **NEST price** is the dominant sensitivity for Y: at $0.017125 the 1.626B locked NEST is $27.85M; at $0.010 it would be $16.26M, at $0.020 $32.52M. The V2 spot cross-check ($0.017435) agrees within 2%.
- **veNEST locked NEST is user-owned**, withdrawable per lock schedule (permanent locks: 1.464B NEST). It is not protocol-owned value; it is reported as a separate headline item per the task instruction (“plus separately veNEST locked NEST = Y”).
- **Pool balances include uncollected LP fees** (normal AMM TVL convention). Fee vaults hold only the portion already swept to the protocol.
- **Enumeration scope:** fee vaults were enumerated per-pool via the factory getter (72/72); no orphan vaults were searched via logs. On-chain pool enumeration via the Voter only lists gauged pools (`poolsCounts() = (55, 1, 54)`; 54 V3 + 1 V2 registered), and no pool outside the 72-pool app API was found. Pools/gauges/vaults derive from the authoritative app API + on-chain cross-checks above.
- **DefiLlama per-token composition** could not be reproduced exactly from the app-API snapshot fields (e.g. llama KHYPE 25,702.57 vs 24,411.45 on-chain; sKNTQ 21,213 vs 26,471). Aggregate totals match (+0.3% on V3-only). All headline numbers here come from direct on-chain reads, not from llama.

## 12. Files

| File | Content |
|---|---|
| `analysis/nest_value.json` | machine-readable result: block, per_contract, per_token_totals, categories, headline, validation, prices |
| `analysis/nest_value_raw.json` | stage 2 raw reads (pool/gauge/vault/core/algebra/tp/meta) |
| `analysis/nest_value_stage3.json` | fee-vault balances, gauge token/LP balances, weird-token probes |
| `analysis/nest_native.json` | native HYPE balances (all zero) |
| `analysis/nest_prices.json` | raw DefiLlama price response (29 coins) |
| `analysis/llama_latest.json` | llama snapshot latest composition |
| `analysis/nest_probe1.py`, `nest_measure.py`, `nest_stage3.py`, `nest_stage4.py`, `nest_compute.py` | reproducible read + compute scripts |
| `analysis/abis_src.json`, `abis_impls.json`, `abi_*.json` | Etherscan V2 ABIs used |


# Mystic Finance (Flare + Plume + Citrea) — Morpho meta-vaults — H2-02 deep dive

**Status:** read-only; live-state reads only; PoC fork-verified in CI; **no mainnet transactions**.
**Date:** 2026-10-10. **Flare block 71,773,173** · **Plume block 98,590,683** · **Citrea block ~13,773,200**.
**All RPCs used are keyless public endpoints** (`https://flare-api.flare.network/ext/C/rpc`, `https://rpc.plume.org`, `https://rpc.mainnet.citrea.xyz`).

---

## 1. Target

Mystic Finance = Morpho-stack lending frontend/infra. DefiLlama `mystic-finance-lending` (2026-10-10):
**Flare $28.11M · Plume $1.96M · Citrea $4.00M** (+ `mystic-finance-myplume` $57k, not audited here).

Discovery used: DefiLlama adapter source (`projects/mystic-finance/index.js`, the ground truth for what the $ numbers count),
on-chain enumeration (Morpho `CreateMarket` events, VaultV2 factories, vault `adapters()`/queues),
and contract source from Blockscout (Flare/Plume/Citrea). Mystic's own REST/GraphQL API is **API-key gated** (401 without key), so it was not used.

---

## 2. What exists (fully enumerated, live)

### 2.1 Flare — `$28.11M` = Mystic Core VaultV2s on Morpho Blue

Morpho Blue singleton (stock upstream `main`, receiver-params build; verified):
`0xF4346F5132e810f80a28487a79c7559d9797E8B0`
- owner = **Safe `0x39fFdD5AB0AcA71824b95De886E1A09E03d92eA4`, threshold 5/9** (owners: 0xe0aeb681…, 0x84D3E4EE…, 0xC100c251…, 0x264c86DB…, 0x30E7c016…, 0x8f02b4a4…, 0xCF263cEe…, 0x69FcEFDe…, 0x13cA8756…), feeRecipient = 0.
- `CreateMarket` count: 15 total; 11 are Mystic-vault markets below, 4 belong to other integrators — all 4 checked: zero supply/borrow (empty shells).
- The deployed bytecode/source diff vs upstream `morpho-org/morpho-blue@main` = **comments/format only** (no logic delta).

VaultV2 factory `0x6FC83ECc0e8142635D77200e5052be8A0a9D2f42` created 5 vaults; 3 are live and hold all the TVL:

| Vault | Symbol | Asset | totalAssets (live) | USD @Llama | Owner | Curator | Registry |
|---|---|---|---|---|---|---|---|
| `0xE8dd6A1e13244A27bDaa19CcBf33013647C675d1` | COREUSDT0 | USD₮0 `0xe7cd86e1…` | 24,128,626.002658 | $24.11M | EOA `0x30988479C2E6a03E7fB65138b94762D41a733458` | EOA `0x72882eb5D27C7088DFA6DDE941DD42e5d184F0ef` | `0x9730d0B3…` (owned by the 5/9 Safe) |
| `0x53184aDaBF312b490BF1EbcFdC896FEfF6019a14` | CSXRP | FXRP `0xAd552A64…` | 2,284,619.077046 (incl. 977,564.58 idle) | $3.21M | same EOA | same EOA | same |
| `0x1aEadA3C251215f1294720B80FcB3D1D005F3585` | COREWFLR | WFLR `0x1D80c49B…` | 113,825,137.13 | $0.80M | same EOA | same EOA | same |
| `0x0afC3D141AC0aEA5ee0d9E9d1E05Ec8240be33Cc` | MUSDT0 ("Mystic USDT0") | USD₮0 | **0.135005** (dust legacy) | $0.13 | EOA `0x37081C7c…` | same EOA | 0 |
| `0x5eaE7E544258e421Cb2774E508e15EE8DadE8200` | — | `0x1702633b…` (reverts) | uninitialized | $0 | 0x0 | 0x0 | 0 |

DefiLlama attribution check: USDT0 24.106M + FXRP 2.285M×$1.4068 + WFLR 113.825M×$0.007049 = **$28.11M** ✓ (matches `currentChainTvls.Flare`).

#### Flare markets (Morpho Blue) and vault exposure

| # | market id (short) | loan/collateral | LLTV | oracle | supply / borrow (live) | util | Core-vault supply |
|---|---|---|---|---|---|---|---|
| m1 | `0xe2e99372…` | USDT0 / WFLR | 62.5% | MorphoChainlinkOracleV2(FTSO FLR/USD, FTSO USDT/USD) | 143,865.35 / 132,295.72 | 92% | USDT0-vault 118,283.52 |
| m2 | `0x2f31ab3f…` | USDT0 / FXRP | 77% | MCOv2(FTSO XRP/USD, FTSO USDT/USD) | 23,729,085.65 / 19,062,138.97 | 80.3% | USDT0-vault **23,729,084.51 (99.99%)** |
| m3 | `0x1f02ffda…` | USDT0 / stXRP | 62.5% | MCOv2(FTSO stXRP/USD, USDT) | 280,716.51 / 170,969.95 | 61% | USDT0-vault 280,716.51 (~100%) |
| m4 | `0xd5e4b411…` | FXRP / USDT0 | 77% | MCOv2(USDT, XRP) | 2,846.27 / 2,016.65 | 71% | FXRP-vault 2,842.27 |
| m5 | `0x6b8a18ea…` | FXRP / stXRP | 62.5% | MCOv2(XRP, XRP) + stXRP vault | 1,105,523.36 / 1,014,929.18 | 92% | FXRP-vault 1,103,711.18 |
| m6 | `0xffa79661…` | FXRP / PT-stXRP(FXRP)-2026/06/04 (**matured**) | 77% | Spectra `PriceFeedCurvePTAssetBounded` — matured branch = redemption 1.000185 FXRP | 489.51 / 483.09 | 98.7% | FXRP-vault 489.51 |
| m7 | `0xabe03a9a…` | FXRP / PT-stXRP(FXRP)-2026/11/26 | 77% | Spectra bounded PT oracle = max(Curve EMA, ZCB), capped at redemption; price 0.997059 FXRP | 200,001.91 / 181,002.06 | 90.5% | FXRP-vault 200,001.81 |
| m8 | `0xd5548b81…` | WFLR / USDT0 | 62.5% | MCOv2(USDT, FLR) | 1,849,687.48 / 1,608,146.38 | 87% | wFLR-vault 1,844,060.01 |
| m9 | `0xf87b6fec…` | WFLR / FXRP | 62.5% | MCOv2(XRP, FLR) | 30,803,446.80 / 27,979,814.56 | 91% | wFLR-vault 30,803,431.69 |
| m10 | `0x0e0a9c0b…` | WFLR / stFLR | **86%** | MCOv2(FTSO stFLR/USD, FTSO FLR/USD) | 81,170,572.87 / 73,375,943.72 | 90.4% | wFLR-vault 81,174,635.88 |
| m11 | `0x21c01d55…` | USDT0 / FXRP | **91.5%** (dormant) | constant 1.0 (all feeds zero) | 0.10 / 0 | 0% | MUSDT0-vault 0.10 |

All 11 oracles are verified `MorphoChainlinkOracleV2`; every input feed is an FTSOv2 "adapted for Chainlink" adapter (18 dec, fresh within seconds), except m6/m7 (Spectra Curve-PT oracles). `ChainlinkDataFeedLib.getPrice()` checks `answer >= 0` **only** (no staleness) — documented risk, but FTSO feeds update continuously and no PT feed can be moved more than ~±0.3% because of its ZCB/redemption bounds.

Oracle ≈ market at audit time (no overvaluation): FLR feed 0.0070264 vs Llama 0.0070493 (−0.3%); XRP 1.40354 vs 1.40677 (−0.2%); stXRP 1.403895 = XRP×1.000256 redemption (−0.08% vs Llama 1.40275); stFLR 0.00738937 vs 0.0074146 (−0.3%); PT-1126 0.997059 FXRP vs Llama 0.9971 (−0.004%). **max-borrow at LLTV is everywhere below realizable collateral value → borrow-and-default is negative-carry.**

### 2.2 Plume — `$1.96M` = 3 MetaMorpho V1.1 vaults (+ dead Aave-fork pool + pUSD)

Plume Morpho Blue singleton `0x42b18785CE0Aed7BF7Ca43a39471ED4C0A3e0bB5` (same receiver-params fork, owner = Safe `0xb651FC34…` 5/9; **48 markets** total — most belong to other integrators).

| Vault | Symbol | Asset | totalAssets | USD | Owner | Curator | fee | timelock | lostAssets (realized bad debt) |
|---|---|---|---|---|---|---|---|---|---|
| `0xc0Df5784f28046D11813356919B869dDA5815B16` | Re7RWAyield | pUSD | 1,950,990.06 | $1.945M | Safe `0xd6316AE3…` (2/5) | 0x0 | 20% | 3d | **105.689854 pUSD** |
| `0x0b14D0bdAf647c541d3887c5b1A4bd64068fCDA7` | MMCpUSD | pUSD | 14,025.27 (all idle) | $14.0k | Safe `0x4F08D2A7…` (2/5) | 0x0 | 20% | 3d | 0 |
| `0xBB748a1346820560875CB7a9cD6B46c203230E07` | MwETH | WETH | 0.711315 (0.5439 idle + 0.16766 in mkt) | $1.78k | Safe `0x4F08D2A7…` | 0x0 | 15% | 3d | 0.0000000321 WETH (dust) |

- **Re7 allocations (live `Morpho.position`):** nOPAL-86 market `0xc867a94e…` 511,704.3 pUSD (**~100% of that market's supply**), nALPHA-86 market `0x7a96549c…` 1,156,034.1 pUSD (**~100%**), WPLUME-77 `0x785c9611…` ≈0.8 pUSD, idle pUSD market `0x234b5cc9…` 283,080.6. Sum ≈ 1.9509M ✓.
- **nOPAL market:** loan pUSD / coll nOPAL, LLTV 86%, oracle `0x0e768E46…` = MorphoChainlinkOracleV2 → Stork `StorkChainlinkAdapter` (fresh: `latestRoundData.updatedAt` ≈ now; `getTemporalNumericValueUnsafeV1`, **no staleness check**). Price 1.1039795 vs Llama nOPAL 1.104124 (−0.013%). Borrow 459,792.4/511,705.1 (89.9%). **Zero liquidatable positions** across 31 live debt positions (min HF≈1.0 dust; total tracked ~388,478 nOPAL collateral / 345,170 pUSD debt).
- **nALPHA market:** same structure, oracle `0x7824e4B3…` → Stork, price 1.1237339 vs Llama 1.123883. Borrow 1,039,880.3/1,156,034.1.
- **WPLUME-77 market** `0x785c9611…`: oracle `0x3ca31d6d…` → a **Chronicle Scribe v2 feed (`wat` = `PLUME/USD`; contract-name artifact `Chronicle_WUSDM_USD_3`)** reporting 0.0189886 vs Llama WPLUME 0.0186235 (+1.96%). No position is near liquidation; over-borrow bound 0.77×oracle = 0.014621 < market 0.018623 → negative-carry.
- **wETH vault / wsuperOETHp-91.5% market** `0x1cdecbb3…`: oracle `0x29356cc5…` = **BRICKED** — `price()` reverts `FeedNotSupported(156)` (eOracle feeds via BeaconProxy: `wsuperOETHp/USD` and `ETH/USD` both revert). Market: supply 0.16766 WETH, borrow 0.051149 WETH. **No liquidation is possible** (oracle reverts), borrower collateral stuck; supplier (wETH vault) can still withdraw free cash (0.1166 WETH) because Morpho supplier-withdraw never touches the oracle (proved in PoC).
- **Mystic "Core Pools" (their own Aave-v3 fork, docs addresses):** Pool `0xCE192A6E…`, Provider `0x6A5F6b4F…` (owner Safe `0x18E1EEC9…`). aTokens are live (`Mystic NRWA/WPLUME/PUSD/WETH`) but supply is ~$30 total (19.48 myNRWA, 407.3 myWPLUME, 136.05 myPUSD, 0.0005 myWETH) — **effectively empty/scrapped**.
- **pUSD** = `0xdddD73F5…`, 2,136,895.01 supply (BoringVault, verified), i.e. the finding's "$2.1M pUSD"; 91.3% of it is inside the Re7 vault, which lends it against nOPAL/nALPHA. Mint/Burn is BoringVault-role gated (not tested further).
- Bad debt history (partial scan of first ~1,000 `Liquidate` logs): only market `0xa39e210a…` (pUSD/WETH 86%) shows non-zero `badDebtAssets` (4 events, 95,211 raw = 0.0952 pUSD); Re7's own 105.69 pUSD realized loss per its `lostAssets` counter came from its own markets over history (dust micro-liquidations; full log pagination NOT completed — see coverage).

### 2.3 Citrea — `$4.00M` = 1 VaultV2

Vault `0x72f8C254548839Fa1Db4156aE01d8C6ae5885EE4` "UltraYield ctUSD Prime" (ultractUSD), asset ctUSD `0x8D82c4E3…` (6 dec), `totalAssets` 4,011,652.30 = idle 2,617.71 + adapter `0x80B85ea1…` realAssets 4,009,034.62.
- Owner **and** curator = EOA `0x2AeDc3843b8F1b8D0C94060F8608c5900DF528C9` (no Safe, no timelock check completed); adapterRegistry `0x83dd673F…` (RegistryList).
- Single market `0xcbe7d4f4…`: loan ctUSD, collateral `0x3100000000000000000000000000000000000006` (**WCBTC9**, wrapped cBTC), LLTV 77%, oracle `0x48119Fea…` price 8.273e28 (= $82,729 per BTC-unit @1e24 scale), supply 4,008,946.31 / borrow 3,563,813.59 (88.9% util). Morpho owner on Citrea = Safe `0x411e9B09…` (5/9).
- Screen only (prioritized Flare/Plume); no position-level audit, no oracle-source analysis, no PoC on Citrea.

### 2.4 Role / permission summary (gated = P)

| Surface | Holder | Timelocks | Can it touch user funds? |
|---|---|---|---|
| Flare Morpho owner | Safe 0x39fFdD5A (5/9) | none (direct) | No direct fund access; `enableIrm/LLTV/setFee/setOwner`, registry ownership |
| Flare Core-vault owner | **EOA 0x30988479…** | `setCurator/setOwner/setIsSentinel` **0s** | Indirect only |
| Flare Core-vault curator | **EOA 0x72882eb5…** (allocator on USDT0+wFLR vaults) | gates/`setIsAllocator`/`setPerformanceFee`/`decreaseAbsoluteCap`/`setAdapterRegistry` **0s**; addAdapter/increaseCap 3d; abdicate 7d | **Can instantly set reverting gates (freeze withdrawals)**; funds can only move to already-whitelisted Morpho adapters; new adapter = 3d public notice |
| Flare adapter registry | Safe 0x39fFdD5A | sub-registry add only | No |
| Plume Morpho owner | Safe 0xb651FC34 (5/9) | none | No direct fund access |
| Plume vault owners | Safes 0xd6316AE3 (Re7, 2/5), 0x4F08D2A7 (MCP/wETH, 2/5) | queue/cap changes 3d | Can redirect supply across whitelisted markets after 3d |
| Citrea vault owner+curator | **EOA 0x2AeDc384…** | not checked | Same VaultV2 model |

---

## 3. Attacker model — exact paths tried

1. **Borrow against overvalued collateral and default (Flare + Plume).**
   Precondition: `market price < LLTV × oracle price`. Live check for every collateral: oracles track (and are never above) market/redemption values within ≤2% (WPLUME feed is +1.96% above Llama, but 0.77×oracle < market ⇒ still negative). **Closed.**
2. **Oracle staleness / manipulation.** Flare: all 11 oracles read FTSOv2 feeds (seconds-fresh, push); `ChainlinkDataFeedLib` has no staleness check but feeds are live; PT oracles are bounded by ZCB/redemption (max ±0.3% move band; matured PT uses redemption directly) ⇒ no profitable swing. Plume: Stork feeds are signature-based (unforgeable by attacker) and fresh; the `UnsafeV1` getter has **no staleness check** — a *hypothetical* stale window could overvalue collateral if Stork stopped pushing + price fell; not actionable today; the wsuperOETHp market's eOracle feeds are bricked (frozen, not exploitable). **Closed today; one residual dependency flagged.**
3. **Liquidation profit.** Flare: 230 live debt positions scanned; only HF<1 is a 5-unit dust ($0.000005) position; largest near-threshold positions (m10, 13.8M stFLR/12.35M WFLR, HF≈1.011) are healthy and their HF *drifts up* (stFLR exchange-rate accrual). Plume Re7 markets: zero liquidatable (min HF≈1.0 dust). Historical liquidations: 426 on Flare, thousands on Plume — all zero-bad-debt except dust. **$0 today; conditional on price moves.**
4. **Permissionless VaultV2 `forceDeallocate` (Flare).** Anyone can pull liquidity from any adapter market back to the vault at penalty **0**; caller receives nothing (proved on fork: +1,000 USDT0 to vault, caller unchanged). Only disables allocator interest-positioning; reparks liquidity for redeemers. **Not extraction; useful public utility.**
5. **Unauthorized curator/owner actions.** `submit`/`setIsAllocator`/`setOwner`/`addAdapter` all revert for a random caller (fork-proved). Gate/allocator changes need the curator EOA key (P). **Closed.**
6. **Share-token attacks (inflation/donation/rounding).** VaultV2 uses `virtualShares` + `firstTotalAssets` transient + `_totalAssets` accounting (Morpho-audited stack); direct donations only raise NAV for existing holders. Not attempted further; flagged as unaudited-by-us.
7. **Redeem/liquidity risk (H-O).** Core USDT0 withdrawals pull from m2 first (free 4.667M USDT0 now) and can be replenished permissionlessly from m1/m3 (11.6k + 109.7k free) + liquidations; FXRP: 977.6k idle + 90.6k free in m5 (m4/m6/m7 nearly fully lent); wFLR: 7.79M free in m10 + others. Users can always redeem available liquidity; illiquidity only if markets stay 100% utilized. Holder redeem proved on fork.

---

## 4. PoC (forks only, CI)

Tests: `poc-mystic/test/MysticFlare.t.sol` (7 tests) and `poc-mystic/test/MysticPlume.t.sol` (4 tests).

| Test | Purpose | Result |
|---|---|---|
| `test_flare_vault_state_and_open_gates` | 3 live vaults, TVL bands, **gates = 0x0 (open)** | pass |
| `test_flare_vault_timelocks` | 0s gates/allocator vs 3d addAdapter vs 7d abdicate | pass |
| `test_flare_unauthorized_curator_actions_revert` | rando cannot `submit`/`setIsAllocator`/`setOwner`/`addAdapter` | pass |
| `test_flare_force_deallocate_permissionless_no_loss` | anyone can pull 1,000 USDT0 m2→vault, caller gains 0 | pass |
| `test_flare_oracles_live_fresh_and_consistent` | FTSO feeds fresh (<1h), oracle == feed ratio ±0.1% | pass |
| `test_flare_no_profitable_liquidation` | healthy 13.8M-stFLR position `liquidate` reverts; only $0.000005 dust HF<1 | pass |
| `test_flare_holder_redeem_works` | real COREUSDT0 holder redeems 1 share → USDT0 received (H-O open) | pass |
| `test_plume_re7_vault_state` | $1.95M TVL, Safe(2/5) owner, 3d timelock, lostAssets=105.689854 pUSD | pass |
| `test_plume_re7_market_oracles_live_no_liquidatable_borrower` | Stork feed fresh; biggest nOPAL borrower healthy → liquidate reverts | pass |
| `test_plume_bricked_oracle_market_frozen` | `price()` reverts FeedNotSupported; liquidate impossible; supplier withdraws 0.1 WETH w/o oracle | pass |
| `test_plume_borrow_budget_below_collateral_value` | oracle == Stork feed exactly; LLTV 86% ⇒ no free borrow | pass |

**CI run(s):** see `analysis/mystic/ci.txt` (URL recorded there and below).
**Log:** `ci-out/poc-mystic.log` in the CI artifacts. Results: 11 tests, see log.

---

## 5. Verdict

**E-U (external unprivileged, live today): $0.**
- No liquidatable position worth gas on any Mystic market (only a $0.000005 dust position on Flare).
- No borrow-and-default edge: `LLTV × oracle ≤ realizable value` for every collateral; oracles at/under market.
- No permissionless value-moving function on the vaults (forceDeallocate returns assets to the vault only).
- No oracle freezes/forgeries currently exploitable on live markets.

**H-O (holders can self-serve): ≈ $32.1M in principle**, with liquidity caveats:
- Flare: $28.11M (24.13M USDT0 + 2.285M FXRP + 113.83M WFLR) — gates open, redeems proved; immediate-atoms liquidity ≈ 4.67M USDT0 / 1.07M FXRP / 7.79M WFLR (rest depends on borrower repayments/liquidations; `forceDeallocate` (0 penalty) lets any redeemer top up from other markets).
- Plume: $1.96M (Re7 $1.945M + MCP $14.0k + wETH $1.78k; wETH market partially frozen by bricked oracle but supplier can exit free cash ≈0.1166 WETH, rest depends on borrower repayment).
- Citrea: $4.00M (screened, assumed similar; not exercised).

**P (privileged): all governance power.** Flare vault owner/curator are **EOAs** with instant gate/allocator power (freeze = DoS, reversible) and 3d-notice paths to new adapters/caps. Flare/Plume/Citrea Morpho owners are 5/9 Safes; Plume vault owners 2/5 Safes; Citrea vault owner+curator is one EOA. No privileged path withdraws user principal directly.

**S (stuck): ≈ $0.3k + dust.**
- Plume wsuperOETHp/wETH market: borrower collateral (wsuperOETHp) is unliquidatable/unwithdrawable while oracle bricked; unrecoverable bad debt unrealized. Mystic wETH vault's lent 0.0511 WETH (~$128) is at risk if borrower defaults (no forced liquidation).
- Plume Re7/WPLUME-77 market: ~0.8 pUSD position (dust) — withdrawable when market has cash.
- Plume bricked-oracle markets with non-Mystic funds (e.g. 9,969 pUSD in `0x4e5b50278…`, 2,744 pUSD in `0x8d009383…`, 1,875 pUSD in `0x9ea0ad4b…`) are frozen for their own users, **not Mystic vault funds**.
- Flare MUSDT0 legacy vault ($0.13) and uninitialized vault (0x5eaE…) — dust.

**Confidence:** **high** for Flare ($0 E-U: live oracle/position/timelock reads + 7 fork tests) and Plume E-U $0 on Re7's two markets (live Stork prices, 31 positions HF-checked, 4 fork tests). **Medium** for the rest of Plume's 48-market surface (screened: oracles/tvl; positions only sampled in 3 markets; liquidate-log bad-debt scan partial) and Citrea (screened only). What would change the verdict: (a) FTSO/Stork feed outage + collateral crash before liquidators act (bad debt to vaults, not attacker extraction); (b) a curator/owner key compromise (P); (c) any currently hidden live-utilization redemption wall in m2/m5/m10 (H-O timing only).

**Coverage:**
- **Fully audited:** Flare — all 5 VaultV2s (3 live), all 11 vault markets + 4 non-Mystic markets (params/balances/oracles), 230 borrower positions HF, 426 liquidations (zero bad debt), all roles/timelocks, adapters/registry, forks proved the negative.
- **Screened:** Plume — 48 markets (params/balances/oracle-liveness), 3 vaults, Aave-fork pool, pUSD; position-level HF for nOPAL (31 debt positions) + top-25 riskiest elsewhere; bad-debt scan partial (first ~1,000 liquidation logs; Re7's own lostAssets = 105.69 pUSD stands).
- **Unreachable / NOT checked:** Mystic REST API (key-gated); myPLUME staking ($57k); Plume myPLUME + structured vaults; Citrea position-level audit & oracle provenance; BoringVault pUSD mint authority; VaultV2 share-accounting fuzzing; full history of Plume liquidations beyond first 1,000 logs; Flare VaultV2 non-Mystic contracts (Superform registry etc.).

---

## 6. Files index & methodology

- `analysis/mystic/evidence/flare_state_71773173.json` — all 11 markets + oracles + feeds live reads.
- `analysis/mystic/evidence/markets_raw_71773173.txt` — raw `cast` dumps (params/market state).
- `analysis/mystic/evidence/flare_positions.json` / `flare_hf.json` — per-user positions & health factors (Flare).
- `analysis/mystic/evidence/plume_markets_full.json` — all 48 Plume markets: params, state, oracle price/revert.
- `analysis/mystic/evidence/plume_positions.json` / `plume_states.json` / `plume_users.json` — Plume position data.
- `poc-mystic/test/MysticFlare.t.sol`, `poc-mystic/test/MysticPlume.t.sol` — fork PoCs (run in CI).
- `analysis/mystic/ci.txt` — CI run URLs + result summary.

Method: DefiLlama adapter + API → address set; on-chain enumeration (factory `CreateVaultV2`, `CreateMarket` logs, `position()` reads, Blockscout v2/Etherscan-style log APIs with block-range pagination where ≤1000-log caps apply); source review of Morpho Blue fork (diff vs upstream), VaultV2, MorphoMarketV1AdapterV2, Spectra PT oracle, Stork/Chronicle adapters; price cross-checks against DefiLlama coin API; fork PoCs in CI.

Caveats: fork tests run against floating latest block (bands used, not exact equality, where state can move); public RPC log caps required partial scans (noted); Plume nALPHA borrower set truncated by API 429s in one pass (nOPAL fully fetched); USD conversions use DefiLlama prices at 2026-10-10 ~17:00 UTC.

---

## Parent addendum (consolidation, 2026-10-10)

- **State drift re-check.** The m1 (USDT0/WFLR) position `0x29566E4AfFd4403b09f43B1B38348E52612Bf867`
  that was HF<1 dust at the audit block (borrowShares 3,904,008; collateral 0.000801 WFLR) has since been
  re-collateralized on live Flare state: borrowShares 161,833,019; collateral 1,657.50 WFLR ≈ $11.62;
  debt ≈ $0.000172 → **healthy (HF ≈ 42,000)**. A parent-authored fork probe
  (`poc-mystic/test/ParentDustProbe.t.sol`) attempted a max-seize liquidation from a funded fresh address
  and the live contract reverted `position is healthy` → **no liquidation path; E-U remains $0**.
- `test_flare_no_profitable_liquidation` was updated to be state-drift-robust: it now attempts the
  liquidation from a funded address and asserts non-profitability if it ever succeeds, or accepts the
  healthy-position revert.
- CI: run 38070536118 (probe first executed); final consolidated run recorded in `ci-log.txt`.

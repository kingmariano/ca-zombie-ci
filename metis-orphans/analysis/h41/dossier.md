# H-41 — Aave V3 Metis aMetMETIS zombie-market dossier

**Scope:** aToken `0x7314Ef2CA509490f65F52CC8FC9E0675C66390b8` ("Aave Metis METIS", aMetMETIS),
underlying METIS `0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000`, Aave V3 Metis Pool
`0x90df02551bB792286e8D4f13E0e357b4Bf1D6a57`, chain 1088.

**Verdict: H-O (holders-only self-service exit; no unprivileged extraction).** Max unprivileged
extraction = **0 METIS / $0**. All value is withdrawable only by the aToken holders themselves
(and only up to currently available liquidity), minus a small formal deficit. Confidence **0.9**.

**Read-only discipline:** all state read via `eth_call`/`eth_getStorageAt` at pinned block
**23,238,719 (2026-10-04T05:27:36Z)** on `https://andromeda.metis.io/?owner=1088`, plus Blockscout
v2 API. No transaction was signed or sent; no anvil; no mainnet writes. Raw evidence in
`evidence.json` and `raw/`.

---

## 0. Corrections to the parent brief (important)

| Parent assumption | Finding at block 23,238,719 | Note |
|---|---|---|
| "flashLoanEnabled=0" for METIS | **flash loans ENABLED on all 5 reserves** (config bit 63 = 1) | The parent decoded bit 61; in this revision (aave-v3-origin, `POOL_REVISION=10`) bit 61 = *borrowable in isolation*, bit 62 = *siloed*, **bit 63 = flashloan enabled** (verified against deployed `DataTypes.sol`). `flashLoanSimple(METIS)` passes validation and reverts only at the EOA-receiver callback (empty revert, not `FlashloanDisabled()`). |
| "stable debt = 0" | confirmed (single shared placeholder stable token `0xf1cd706E...` totalSupply 0 on all reserves) | |
| "accruedToTreasury=0.009342789809185289" | confirmed; METIS `accruedToTreasury = 9342789809185289` | |
| — | **New: METIS reserve deficit = 0.216680562557106426 METIS** (formal bad debt, v3.5 deficit accounting) | `Pool.getReserveDeficit(METIS)`; also deficits on all other reserves. |
| — | Blockscout per-holder `value` fields are stale (sum 27,096.9 > totalSupply); all holder numbers below are re-verified on-chain. | |

---

## 1. Reserve/market state (all values at block 23,238,719 unless noted)

Pool implementation `0x56b814e2ea4ae621b48fdc740850c3bba81d8251` = `L2PoolInstance`
(`POOL_REVISION = 10`, aave-v3-origin v3.5-line; upgraded 2026-01-09, block 21,940,090).
`getReservesList()` returns exactly 5 reserves; every one is **active=1, frozen=1, paused=0, LTV=0,
caps=1/1, RF=99%, flashloans=1**.

| # | Reserve | Asset | aToken | vDebt | aToken supply | Underlying held by aToken | vDebt supply | Deficit | Supply USD @oracle | Debt USD @oracle |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | mDAI | `0x4c078361…2F6ce0` | `0x85ABAdDc…9eFDE24` | `0x13Bd89aF…B4DDbF` | 21,358.493329623428318322 | 20,977.499876417961421559 | 395.29405611975212096 | 1.302026108128326333 | $21,356.93 | $395.27 |
| 1 | **METIS** | `0xDeadDeAd…AD0000` | `0x7314Ef2C…390b8` | `0x01101741…bA2c40` | **26,528.057591889373595056** | **26,448.834076746246245959** | **79.035015032485908383** | **0.216680562557106426** | **$89,346.50** | **$266.19** |
| 2 | mUSDC | `0xEA32A966…cc1a21` | `0x885C8AEC…B9bf27` | `0x571171a7…351380` | 73,617.099046 | 53,247.827105 | 20,379.454023 | 5.400269 | $73,615.63 | $20,379.05 |
| 3 | mUSDT | `0xbB06DCA3…16F4dC` | `0xd9fa75D1…f07b9` | `0x6B45DcE8…AB54e5` | 81,895.282429 | 80,270.458615 | 1,640.39855 | 0.386137 | $81,882.45 | $1,640.14 |
| 4 | WETH | `0x4200…000A` | `0x8acAe350…c09f3a` | `0x8Bb19e3D…898421` | 15.884280483531663051 | 15.096940548001234725 | 0.787659631062382738 | 0.000137511173112147 | $42,757.41 | $2,120.23 |

Total market supply ≈ **$308,958.92** at oracle prices. METIS-denominated equivalents at the
oracle METIS price ($3.368): mDAI 6,341 METIS, METIS 26,528, mUSDC 21,857, mUSDT 24,312,
WETH 12,695.

**METIS reserve detail (exact):**
- aToken totalSupply: `26528057591889373595056`
- aToken actual METIS balance: `26448834076746246245959` (26,448.834076746246245959)
- Pool virtual underlying balance: `26448834047737145969705` (26,448.834047737145969705) — this is the hard cap on aggregate withdrawals; the 29,009,100,276,540,254 wei difference (0.000029 METIS) is unclaimable dust.
- vDebt totalSupply: `79035015032485908383`; stable debt 0; Pool METIS balance 0; aToken balance of Pool 0.
- deficit: `216680562557106426` (0.216680562557106426 METIS); accruedToTreasury `9342789809185289`.
- liquidityIndex `1006644315928683814051784630` (1.006644315928683814), variableBorrowIndex `1047922225816859130077493933` (1.047922225816859130), currentLiquidityRate 0.0015%/yr, currentVariableBorrowRate 5.0463%/yr, lastUpdateTimestamp `1791035563` (2026-10-03T13:52:43Z).
- **Withdrawal math:** supply − actual aToken METIS balance = **79.223515143127349097 METIS**; using the Pool's virtual-balance cap (26,448.834047737145969705) the aggregate ceiling leaves 79.223544152227625351 METIS. Either way ≈ outstanding debt 79.035015032485908383 + deficit 0.216680562557106426 − ~0.0282 residual (interest-index timing + unminted treasury accrual 0.00934). Nothing is lost if borrowers repay; the deficit 0.21668 is permanently unbacked.

**Withdrawals work, market is NOT paused:**
- `withdraw(METIS, 4575098972608146854185, topHolder)` simulated with `from=topHolder` at the pinned block → **returns 4575098972608146854185** (success).
- `supply` and `borrow` for METIS (and `supply` for mUSDC) revert with **`ReserveFrozen()` (0x6d305815)**.
- No global `paused()`/`getPaused()` exists on the Pool. `PoolConfigurator.setPoolPause(bool)` is implemented as a loop of per-reserve `setReservePause(asset,bool)` (source: `PoolConfigurator.sol` L519–532). All 5 reserves have config bit 60 (paused) = 0. `ValidationLogic.validateWithdraw` requires only `isActive && !isPaused` — frozen does **not** block withdrawals.
- Governance-driven configuration events (Configurator logs, by block): LTV→0 / liqThreshold 40% / bonus 10% at block **21,634,800** (2025-11-15); supply cap 600,000→80,000 at **22,152,008** (2026-02-11); `ReserveFrozen(true)` at **22,279,254** (2026-03-03); AIP execution (caps→1, RF 15%→99%, IRM base→5%) at **23,173,987** (2026-09-20).

---

## 2. aMetMETIS holder analysis

- Blockscout claims 26,268 holders; the value-sorted list was fetched to 4,050 addresses and **all 4,050 were re-verified on-chain at block 23,238,719**: nonzero **3,907**, stale-zero 143, **sum = 26,446.183222562602 METIS = 99.69% of totalSupply**. The un-fetched remainder (~81.87 aTokens over ~22k addresses) is dust bounded by the tail values (~0.075–0.076 METIS each).
- **Top-1 holder `0xA4C39Bc895E380e0B54f9b1c952c3bC151cf6FB2` = 4,577.173943612077161473 METIS (17.25%) — EOA**, no label, **5 lifetime transactions** (844,216 gas total). Acquired by two aToken mints: 4,518.6371 METIS on 2024-02-16 and 29.2163 on 2024-04-08; has never transferred or withdrawn since. Self-service exit proven by the withdraw simulation above.
- **Top-10 = 15,088.362889895847618902 METIS (56.88%)**, all EOAs except the Aave Collector.
- **The only contract holder in the list is the Aave Collector `0xB5b64c7E00374e766272f8B442Cd261412D4b118`** (InitializableAdminUpgradeabilityProxy → `CollectorWithCustomImpl`) with **548.714570438941364381 aMetMETIS**. It is the aToken's `RESERVE_TREASURY_ADDRESS`; it accumulates the 99% reserve-factor interest (mints visible daily through 2026-09-29…10-03). Controlled by Aave governance; **no unprivileged function can make it redeem to an attacker**.
- Transferability: plain `ATokenInstance` ERC-20 (`transfer`/`transferFrom`/`permit`), no transfer hooks, no freeze on token transfers. Irrelevant for extraction (no allowance).
- Last aMetMETIS transfer: **2026-10-03T13:52:43Z** (burn of 17.0 METIS = withdrawal). Withdrawals by small holders occur every few days — the market is a live, slowly-draining zombie, not a frozen one.

## 3. Borrower / liquidation analysis

- vDebt token `0x0110174183e13D5Ea59D7512226c5D5A47bA2c40`: 83 addresses from Blockscout, **77 nonzero on-chain**, **all EOAs**, on-chain sum **79.035015032485908424 METIS** vs totalSupply 79.035015032485908383 (**+41 wei**, expected from Aave's half-up `rayMul` in per-account `balanceOf` views; Pool accounting uses scaled amounts). (This Pool revision removed `getUserReserveData`; positions were reconstructed from per-reserve aToken/vDebt `balanceOf` + `getUserAccountData`.)
- `getUserAccountData` for all 83 at block 23,238,719: **count with healthFactor < 1e18 = 0**. **Minimum HF = 1.4500249097265923** (`0x887b8f7168f232d4424F9a28CC8158C30cB6f9c2`, debt 0.0242 METIS). No zero-collateral borrowers; no positions in deficit.
- Largest positions (collateral via aToken/vDebt `balanceOf` across all 5 reserves):

| Borrower | vDebt METIS | HF | Collateral | Debt USD | Liq. price threshold |
|---|---|---|---|---|---|
| `0x24a30823bd87E785B0c4B3803a2bffD91eb6876F` | 53.742939912414548001 | 1.965117347766053139 | 0.1592 WETH ($428.55) | $181.01 | METIS **$6.6185 (+96.51%)** |
| `0xf175846de880d076204156997f30E2BA24247890` | 13.849870316798243978 | 1.671399843691522872 | 99.97 mUSDT ($99.95) | $46.65 | METIS **$5.6293 (+67.14%)** |
| `0x6591C5468DF6C039601B10F1434115266d4b785b` | 8.291855005395796 | 49.29 | 849.73 mUSDC + 0.3004 WETH | $27.93 | — |

  (Both top borrowers have 100% of debt in METIS; 23 borrowers keep aMetMETIS as collateral, 37 mUSDT, 30 mUSDC, 18 WETH, 1 mDAI.)
- **Liquidatable now: none.** To make the top position liquidatable METIS must rise **+96.5%** vs. its WETH collateral (or WETH fall equivalently); #2 needs **+67.1%**. Neither is attacker-controllable (Chainlink feeds, see §4).
- Top borrower history: first METIS borrow 2024-10-21 (53 METIS), peak ~95+, monthly partial repayments (last 2026-08-17, 6.098 METIS). It is an active EOA (1,300 txs), not a contract. Last vDebt activity network-wide: 2026-08-17 — borrows stopped, only repayments/withdrawals since.
- **Theoretical ceiling if everything became liquidatable:** 10% bonus on the full 79.035 METIS book = 7.9035 METIS ≈ **$26.62** gross (before flash-loan premium 5 bps and gas). This is an upper bound, not a live path.

## 4. Oracle assessment

AaveOracle `0x38D36e85E47eA6ff0d18B0adF12E5fC8984A6f8e`; `BASE_CURRENCY = address(0)` (USD), unit 1e8.

| Asset | Price | Source | Feed type | Freshness at pinned block |
|---|---|---|---|---|
| METIS | **$3.368** (336,800,000) | `0xd4a5bb03b5d66d9bf81507379302ac2c2dfdfa6d` | Chainlink **EACAggregatorProxy** "METIS / USD" | `updatedAt=1791091420`, **236 s old** |
| WETH | $2,691.80647524 | `0x3bbe70e2f96c87aece7f67a2b0178052f62e37fe` | Chainlink EACAggregatorProxy "ETH / USD" | 15,013 s old (4.2 h) |
| mDAI | $0.99992671 | `0xf577e512687c83706ccfed31c1939c75e8ea966f` | `PriceCapAdapterStable` (capped) | n/a (capped adapter) |
| mUSDC | $0.99998000 | `0x0b9ca640284cf2636577703f785d5aeec466bc56` | PriceCapAdapterStable | n/a |
| mUSDT | $0.99984335 | `0x433636cb0136cfd75145ccca608bb548e6c037de` | PriceCapAdapterStable | n/a |

- All feeds are live and consistent with on-chain prices; no staleness or fixed-price adapter on METIS (the ARFC's "fixed-price oracle" treatment applies to a different, oracle-risk set — METIS is in the whole-market list, whose feeds are still live for now).
- **Note for USD conversions:** the oracle prices METIS at **$3.368**, not $10. The parent's $10 assumption is used only as a scenario column below.
- Manipulation feasibility: Chainlink aggregator (off-chain reporting) + capped stable adapters — not DEX-manipulable with flash loans. Moreover, with LTV=0, frozen reserves and caps=1 there is no borrow/liquidation action that a mispriced oracle could unlock.

## 5. Governance / incident history

- **2023-05-08** (block 5,592,243): METIS reserve initialized on Aave V3 Metis.
- **2025-11-15** (block 21,634,800): METIS collateral config cut to LTV 0, liqThreshold 40%, bonus 10%.
- **2026-01-09** (block 21,940,090): Pool upgraded to `L2PoolInstance` revision 10 (deficit + virtual accounting), aToken/vDebt upgraded.
- **2026-02-11** (block 22,152,008): supply cap 600,000 → 80,000.
- **2026-03-03** (block 22,279,254): `ReserveFrozen(true)` for METIS (pre-ARFC risk action; the ARFC notes the reserve was already frozen before the deprecation proposal).
- **2026-07-29:** ARFC **"[Low Adoption Asset Deprecation on Aave V3](https://governance.aave.com/t/arfc-low-adoption-asset-deprecation-on-aave-v3/25401)"** (LlamaRisk + Aave Labs) — **whole-market deprecation of Aave V3 Metis** (deposits −79% in 6 months to $297k; <$1k/quarter revenue). Default wind-down: freeze, caps→1, RF→99%, IRM base 5%.
- **2026-08-12** Snapshot vote; **2026-09-16** AIP **#521** created; **2026-09-20** (block 23,173,987) executed — matches on-chain config exactly (caps=1, RF=9900, IRM base 5% → current METIS borrow rate 5.046%).
- ARFC states the next step after positions unwind: **fix the oracle feeds** to retire the market completely. This is a future governance action (P), not an extraction path.
- **No Metis-specific incident/exploit found.** The reserve's 0.21668 METIS deficit is pre-existing bad debt (socialized via v3.5 deficit accounting); it is not a live incident. Broader Aave incidents (Oct-2025 crash liquidations, Mar-2026 wstETH oracle glitch, Apr-2026 KelpDAO rsETH bad debt) did not involve Metis.

## 6. Exhaustive unprivileged extraction-path assessment

| # | Path | Live gating proof | Max extractable |
|---|---|---|---|
| a | Borrow against mispriced/undervalued collateral | All reserves LTV=0, frozen, caps=1; `borrow` reverts `ReserveFrozen()` 0x6d305815; `supply` (collateral) reverts same | **$0** |
| b | Liquidate unhealthy positions for 10% bonus | 0/83 positions with HF<1; min HF 1.4500; top positions need METIS +96.5%/+67.1% | **$0 live** (theoretical ceiling $26.62 if the whole book were liquidatable) |
| c | aToken donation / inflation-rounding | `ATokenInstance` has no `sync`/virtual-balance getter; scaled math standard `rayMul/rayDiv`; donation changes no scaled balance. Measured excess actual-vs-virtual = 0.000029 METIS, unclaimable | **$0** |
| d | Flash loans | **Enabled on all 5 reserves** (bit63=1), premium 5 bps; METIS `flashLoanSimple` passes validation. But no profitable target: no liquidatable positions, oracle not manipulable, supply/borrow frozen | **$0** |
| e | eMode / caps bypass | All reserves eMode category 0/deprecated; caps=1; frozen; supply+borrow revert | **$0** |
| f | Oracle manipulation of a listed asset | Chainlink EACAggregatorProxy (METIS/WETH) + PriceCapAdapterStable; fresh; not DEX-manipulable; and no borrow/liquidation action is unlocked anyway | **$0** |
| g | Interest accrual / timestamp manipulation | Indexes monotonic, timestamp-based; no user input | **$0** |
| h | `mintToTreasury` (permissionless) | Callable by anyone, but mints `accruedToTreasury` (0.009342789809185289 METIS) to the **Aave Collector**; caller gets nothing | **$0** |
| i | `eliminateReserveDeficit` | `onlyUmbrella` (privileged module) | **$0** (P) |
| j | `rescueTokens` (Pool/aToken) | Pool admin only | **$0** (P) |
| k | Steal/withdraw other holders' aTokens | Standard ERC-20; no allowances to any attacker | **$0** |

**Why the two large EOAs do not create an E-U path:** top holder `0xA4C3…` (4,577.17 METIS) and
the Aave Collector (548.71) are the only large non-borrower positions; the holder is a passive EOA
that can only withdraw to itself (simulated), and the Collector is governance-controlled. No farm,
bridge, vault or incentive contract holds aMetMETIS — so there is no third-party contract to
"make redeem to the attacker".

## 7. Final classification

**H-O — holders-only self-service exit.** No unprivileged extraction path (E-U) exists at block
23,238,719. The only privileged surface (P) is standard Aave governance (PoolAdmin/Configurator,
Umbrella-only deficit elimination, future oracle fixing), with no drain path identified.

| Item | METIS | USD @ $10 (parent assumption) | USD @ oracle $3.368 |
|---|---|---|---|
| Max unprivileged extractable | **0** | **$0** | **$0** |
| aToken supply (claims) | 26,528.057591889373595056 | $265,280.58 | $89,346.50 |
| Withdrawable now (aggregate, virtual balance cap) | 26,448.834047737145969705 | $264,488.34 | $89,079.67 |
| Temporarily stranded until borrowers repay (debt + deficit − residual) | 79.223515143127349097 | $792.24 | $266.82 |
| Permanently unbacked (reserve deficit) | 0.216680562557106426 | $2.17 | $0.73 |
| Aave Collector aMetMETIS (governance-controlled) | 548.714570438941364381 | $5,487.15 | $1,848.07 |
| Largest EOA holder (self-withdrawable, simulated) | 4,577.173943612077161473 | $45,750.99 | $15,408.93 |

**Confidence: 0.9.** Caveats: single-block snapshot (block 23,238,719); read-only `eth_call`
simulations (no local fork); the deficit 0.21668 METIS was not dated to a creation block
(Blockscout decoded no `DeficitCreated` event in the recent 750 Pool logs); future governance
(oracle fixing) and METIS price moves can change the liquidation landscape — a +96.5% METIS move
would start to open liquidations against the top borrower's WETH collateral.

## 8. Evidence files

- `evidence.json` — aggregated machine-readable evidence (all numbers above).
- `raw/state_pull.json` — on-chain verification of all 4,050 aToken holders + 83 vDebt holders + reserve/oracle state.
- `raw/reserves_decoded.json` — reserve data + full config decode (v3.5 bit layout).
- `raw/deficits.json`, `raw/oracle_feeds.json`, `raw/pool_probes.json`, `raw/all_borrower_positions.json`.
- `raw/holders_atoken_full.json`, `raw/holders_vdebt_full.json` — Blockscout pagination.
- `raw/sources/`, `raw/sources_cfg/` — verified Pool/Configurator sources used for gating proofs.
- `raw/cfg_metis_events.json`, `raw/pool_upgraded_logs.json`, `raw/atoken_transfers.json`, `raw/vdebt_transfers.json`, `raw/topborrower_vdebt_history.json`, `raw/topholder_transfers_p1.json`.
- Scripts: `rpc.py`, `pull_state.py`, `decode_reserves.py`, `fetch_holders.py`, `build_evidence.py`.

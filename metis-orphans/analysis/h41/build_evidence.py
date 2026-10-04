#!/usr/bin/env python3
"""Aggregate H-41 raw evidence into evidence.json (read-only artifacts only)."""
import json
from decimal import Decimal
D = Decimal

BLOCK = 23238719
BLOCK_TS = 1791091656
P_METIS = D("3.368")
P = {"METIS": P_METIS, "mDAI": D("0.99992671"), "mUSDC": D("0.99998"), "mUSDT": D("0.99984335"), "WETH": D("2691.80647524")}

sp = json.load(open("raw/state_pull.json"))
dec = json.load(open("raw/reserves_decoded.json"))
deficits = json.load(open("raw/deficits.json"))
feeds = json.load(open("raw/oracle_feeds.json"))
holders = json.load(open("raw/holders_atoken_full.json"))
vholders = json.load(open("raw/holders_vdebt_full.json"))
probes = json.load(open("raw/pool_probes.json"))
positions = json.load(open("raw/all_borrower_positions.json"))

ev = {
    "meta": {
        "campaign": "metis-orphans",
        "finding": "H-41",
        "scope": "Aave V3 Metis aToken 0x7314Ef2CA509490f65F52CC8FC9E0675C66390b8 (aMetMETIS)",
        "chain_id": 1088,
        "rpc": "https://andromeda.metis.io/?owner=1088 (fallback https://metis.drpc.org)",
        "pinned_block": BLOCK,
        "pinned_block_timestamp": BLOCK_TS,
        "pinned_block_utc": "2026-10-04T05:27:36Z",
        "mode": "read-only (eth_call/eth_getStorageAt + explorer API); no transactions signed/sent",
    },
    "contracts": {
        "aMetMETIS": "0x7314Ef2CA509490f65F52CC8FC9E0675C66390b8",
        "underlying_METIS": "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000",
        "pool": "0x90df02551bB792286e8D4f13E0e357b4Bf1D6a57",
        "pool_impl": "0x56b814e2ea4ae621b48fdc740850c3bba81d8251",
        "pool_impl_name": "L2PoolInstance (aave-v3-origin, POOL_REVISION=10)",
        "vDebtMETIS": "0x0110174183e13D5Ea59D7512226c5D5A47bA2c40",
        "addresses_provider": "0xB9FABd7500B2C6781c35Dd48d54f81fc2299D7AF",
        "pool_configurator": "0x69FEE8F261E004453BE0800BC9039717528645A6",
        "configurator_impl": "0xebc4b627d8fc48d70bad7de09518677463581281",
        "price_oracle": "0x38D36e85E47eA6ff0d18B0adF12E5fC8984A6f8e",
        "atoken_impl": "0x9ec6457cd8953ac68b5bd612fc64bf8d50df3140 (ATokenInstance)",
        "reserve_treasury": "0xB5b64c7E00374e766272f8B442Cd261412D4b118 (Aave Collector proxy, impl CollectorWithCustomImpl)",
    },
    "reserve_list": [e["asset"] for e in dec],
    "reserve_state": {},
    "oracle": {
        "prices_1e8": feeds and {k: (int(v["latestAnswer"]) if "latestAnswer" in v else None) for k, v in feeds.items()},
        "base_currency": sp["oracle"]["base_currency"],
        "base_currency_unit": sp["oracle"]["base_currency_unit"],
        "sources": sp["oracle"]["sources"],
        "feed_detail": feeds,
        "notes": [
            "METIS source 0xd4a5bb03b5d66d9bf81507379302ac2c2dfdfa6d = Chainlink EACAggregatorProxy 'METIS / USD'",
            "mDAI/mUSDC/mUSDT sources = PriceCapAdapterStable ('Capped .../USD')",
            "WETH source 0x3bbe70e2f96c87aece7f67a2b0178052f62e37fe = Chainlink EACAggregatorProxy 'ETH / USD'",
            "METIS feed updatedAt 1791091420 (236s before pinned block) -> fresh",
        ],
    },
    "pool_misc": sp["pool_misc"],
    "pool_probes": probes,
    "metis_reserve": {
        "aToken_totalSupply_raw": "26528057591889373595056",
        "aToken_actual_underlying_raw": "26448834076746246245959",
        "pool_virtual_underlying_raw": "26448834047737145969705",
        "vDebt_totalSupply_raw": "79035015032485908383",
        "stable_debt_total": "0",
        "deficit_raw": "216680562557106426",
        "accruedToTreasury_raw": "9342789809185289",
        "liquidityIndex_ray": "1006644315928683814051784630",
        "variableBorrowIndex_ray": "1047922225816859130077493933",
        "currentLiquidityRate_ray": "1503319675523779444402",
        "currentVariableBorrowRate_ray": "50463408329202442865335278",
        "lastUpdateTimestamp": 1791035563,
        "lastUpdate_utc": "2026-10-03T13:52:43Z",
    },
    "atoken_holders": {
        "blockscout_claimed_holders": 26268,
        "fetched_top_by_value": len(holders["items"]),
        "onchain_verified_addresses": sp["atoken_holders_verified"]["list_size"],
        "onchain_nonzero": sp["atoken_holders_verified"]["nonzero"],
        "onchain_zero_stale": sp["atoken_holders_verified"]["zero"],
        "onchain_verified_sum_raw": sp["atoken_holders_verified"]["onchain_sum"],
        "onchain_verified_sum_metis": str(D(sp["atoken_holders_verified"]["onchain_sum"]) / D(10**18)),
        "pct_of_total_supply": "99.69%",
        "blockscout_value_sum_metis": "27096.890157 (stale/inconsistent vs on-chain; not used)",
        "top20_onchain": sp["atoken_holders_verified"]["top"][:20],
        "top1_metis": "4577.173943612077161473",
        "top10_metis": "15088.362889895847618902",
        "top10_pct": "56.88%",
        "contract_holders_in_top_list": [
            {"addr": "0xB5b64c7E00374e766272f8B442Cd261412D4b118", "balance_metis": "548.714570438941364381", "identity": "Aave Collector (RESERVE_TREASURY_ADDRESS of aToken)"}
        ],
        "tail_bound": "last fetched page values ~0.075-0.076 METIS (Blockscout value-sorted); remaining ~81.87 aTokens spread over ~22k dust addresses",
    },
    "borrowers": {
        "debt_token_addresses": len(vholders["items"]),
        "onchain_nonzero": sum(1 for b in sp["borrowers"] if b["vdebt"]),
        "onchain_sum_metis": str(D(sum(b["vdebt"] for b in sp["borrowers"] if b["vdebt"])) / D(10**18)),
        "contracts": 0,
        "min_health_factor": "1.4500249097265923",
        "min_hf_address": "0x887b8f7168f232d4424F9a28CC8158C30cB6f9c2",
        "count_hf_below_1": 0,
        "zero_collateral_with_debt": [],
        "top": [
            {
                "addr": b["addr"],
                "vdebt_metis": str(D(b["vdebt"]) / D(10**18)),
                "healthFactor": b["account"]["healthFactor"],
                "collateral_usd_1e8": b["account"]["totalCollateralBase"],
                "debt_usd_1e8": b["account"]["totalDebtBase"],
                "collateral_positions": positions.get(b["addr"], {}),
                "liq_price_metis_usd": "6.6185",
                "upside_to_liquidation_pct": "96.51%",
            }
            for b in sorted([x for x in sp["borrowers"] if x["vdebt"]], key=lambda x: -x["vdebt"])[:5]
        ],
        "theoretical_liq_bonus_pool_metis": "7.9035 (10% of 79.035 total debt; NOT currently liquidatable)",
    },
    "gating_simulations": {
        "withdraw_4575_metis_from_top_holder": "SUCCESS (returns 4575098972608146854185)",
        "withdraw_without_balance": "REVERT 0x47bc4b2c NotEnoughAvailableUserBalance()",
        "supply_1_metis": "REVERT 0x6d305815 ReserveFrozen()",
        "borrow_0.001_metis": "REVERT 0x6d305815 ReserveFrozen()",
        "supply_1_musdc": "REVERT 0x6d305815 ReserveFrozen()",
        "flashLoanSimple_100_metis": "validation passes (bit63=1), reverts at receiver callback (empty data, EOA receiver has no executeOperation) -> flash loans ENABLED",
        "pool_paused_getter": "does not exist in POOL_REVISION=10; pause is per-reserve (bit60); all 5 reserves paused=0",
        "configurator_setPoolPause": "exists; implemented as loop of setReservePause(asset,bool) over reserves; onlyEmergencyOrPoolAdmin",
    },
    "reserve_config_bit_layout": "v3.5 (aave-v3-origin): bit56 active, 57 frozen, 58 borrowing, 59 deprecated stable, 60 paused, 61 borrowable-in-isolation, 62 siloed, 63 flashloan-enabled, 64-79 reserveFactor, 80-115 borrowCap, 116-151 supplyCap, 152-167 liqProtocolFee, 212-251 debtCeiling",
    "governance_timeline": [
        {"block": 5592243, "utc": "2023-05-08T14:04:06Z", "event": "METIS reserve initialized on Aave V3 Metis"},
        {"block": 21634800, "utc": "2025-11-15T14:24:12Z", "event": "CollateralConfigurationChanged METIS: LTV->0, liqThreshold=4000, liqBonus=11000"},
        {"block": 21940090, "utc": "2026-01-09T10:54:08Z", "event": "Pool impl upgraded to L2PoolInstance 0x56b814e2... (revision 10, deficit/virtual accounting); aToken+vDebt upgraded"},
        {"block": 22152008, "utc": "2026-02-11T15:57:57Z", "event": "METIS supply cap 600,000 -> 80,000"},
        {"block": 22279254, "utc": "2026-03-03T12:07:08Z", "event": "METIS ReserveFrozen(true) (pre-ARFC risk action; WETH etc. also frozen)"},
        {"date": "2026-07-29", "event": "ARFC 'Low Adoption Asset Deprecation on Aave V3' (LlamaRisk): whole-market Metis deprecation (freeze, caps->1, RF->99%, IRM base 5%)"},
        {"date": "2026-08-12", "event": "ARFC Snapshot vote"},
        {"date": "2026-09-16", "event": "AIP #521 created"},
        {"block": 23173987, "utc": "2026-09-20T15:06:55Z", "event": "AIP #521 executed: all 5 Metis reserves caps->1, RF->99%, IRM base rate 5%"},
    ],
    "activity": {
        "last_atoken_transfer": "2026-10-03T13:52:43Z (burn 17.0 METIS -> withdrawal)",
        "last_vdebt_transfer": "2026-08-17T12:16:52Z (repayment by 0x24a3... 6.098 METIS)",
        "withdrawals_ongoing": "daily-ish aToken burns Sept-Oct 2026",
        "top_holder_history": "0xA4C3... acquired 4,518.6371 (2024-02-16) + 29.2163 (2024-04-08); only 5 lifetime txs; no label",
        "top_borrower_history": "0x24a3... first METIS borrow 2024-10-21 (53 METIS); monthly partial repayments through 2026-08-17; collateral 0.1592 WETH",
    },
    "usd_valuations": {
        "oracle_metis_usd": "3.368",
        "assumption_metis_usd": "10",
        "metis_supply": {"metis": "26528.057591889373595056", "usd_oracle": "89346.50", "usd_10": "265280.58"},
        "metis_withdrawable_now": {"metis": "26448.834047737145969705 (pool virtual; token balance 26448.834076746246245959)", "usd_oracle": "89079.67", "usd_10": "264488.34"},
        "metis_unwithdrawable_until_repay": {"metis": "79.223515143127349097", "usd_oracle": "266.82", "usd_10": "792.24"},
        "metis_reserve_deficit": {"metis": "0.216680562557106426", "usd_oracle": "0.73", "usd_10": "2.17"},
        "aave_collector_amet": {"metis": "548.714570438941364381", "usd_oracle": "1848.07", "usd_10": "5487.15"},
        "top_holder_amet": {"metis": "4577.173943612077161473", "usd_oracle": "15408.93", "usd_10": "45750.99"},
        "total_market_supply_usd_oracle": "308958.92",
    },
    "classification": {
        "verdict": "H-O (holders-only self-service exit; no unprivileged extraction)",
        "e_u_max_extractable_usd": "0.00",
        "p_notes": "Standard Aave governance powers only (PoolAdmin/Configurator, Umbrella-only eliminateReserveDeficit, oracle deprecation planned). No privileged drain path identified.",
        "confidence": "0.9 (high) for no-E-U at block 23238719; caveats: single-block snapshot, read-only simulations, future price moves/governance can change liquidation landscape",
    },
}

# reserve table
for e in dec:
    n = e["name"]
    rs = sp["reserve_state"][n]
    sc = D(10) ** int(rs["decimals"])
    sup = D(rs["aToken_totalSupply"]) / sc
    wd = D(rs["underlying_bal_atoken"]) / sc
    debt = D(rs["vDebt_totalSupply"]) / sc
    df = D(deficits[n]["deficit_raw"]) / sc
    ev["reserve_state"][n] = {
        "asset": e["asset"],
        "aToken": e["aToken"],
        "variableDebtToken": e["variableDebtToken"],
        "decimals": int(rs["decimals"]),
        "aToken_totalSupply": str(sup),
        "underlying_held_by_aToken": str(wd),
        "vDebt_totalSupply": str(debt),
        "reserve_deficit": str(df),
        "usd_supply_oracle": str((sup * P[n]).quantize(D("0.01"))),
        "usd_debt_oracle": str((debt * P[n]).quantize(D("0.01"))),
        "config_v35": e["config_v35"],
        "liquidityIndex_ray": e["liquidityIndex"],
        "variableBorrowIndex_ray": e["variableBorrowIndex"],
        "lastUpdateTimestamp": int(e["lastUpdateTimestamp"]),
    }

json.dump(ev, open("evidence.json", "w"), indent=1)
print("evidence.json written,", len(json.dumps(ev)), "bytes")

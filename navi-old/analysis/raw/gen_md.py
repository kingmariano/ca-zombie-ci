#!/usr/bin/env python3
"""Generate reward-funds-census.md from the census JSON."""
import json

J = "/home/heisenberg/CA/navi-old/analysis/reward-funds-census.json"
MD = "/home/heisenberg/CA/navi-old/analysis/reward-funds-census.md"
d = json.load(open(J))

LIN_ORDER = ["v3_main_0x81c408", "v3_second_0xacc64a", "v2_main_0xe66f07", "v2_second_0xa49c5d1c"]
LIN_DESC = {
    "v3_main_0x81c408": "v3 main — RewardFund origin 0x81c408… (lineage A v22)",
    "v3_second_0xacc64a": "v3 second — RewardFund origin 0xacc64a… (lineage B v13)",
    "v2_main_0xe66f07": "v2 main — IncentiveFundsPool origin 0xe66f07… (lineage A v9)",
    "v2_second_0xa49c5d1c": "v2 second — IncentiveFundsPool origin 0xa49c5d1c… (lineage B v1)",
}

def short(a):
    return a[:10] + "…" + a[-6:]

def fmt_usd(v):
    return f"${v:,.2f}" if v is not None else "n/a"

funds = d["funds"]
total = d["total_usd"]
orph = [f for f in funds if not f["active_in_iv3"]]
orph_val = sum(f["value_usd"] or 0 for f in orph)
nonzero = [f for f in funds if f["amount"] > 0]
zero = [f for f in funds if f["amount"] == 0]

lines = []
A = lines.append
A("# NAVI reward-fund census — Sui mainnet")
A("")
A(f"- **Generated:** {d['generated_at']} (census data as of checkpoint {d['latest_checkpoint']}, {d['checkpoint_timestamp']})")
A(f"- **Endpoint:** public keyless `https://graphql.mainnet.sui.io/graphql` only (POST); prices from public DefiLlama + CoinGecko (see Method).")
A(f"- **Funds found:** {len(funds)} objects ({len(nonzero)} with non-zero balance, {len(zero)} empty) across 4 struct types / 2 package lineages.")
A(f"- **Total value:** **{fmt_usd(total)}** (estimate at prices captured ~02:40 UTC 2026-10-10).")
A(f"- **Orphaned by coin type** (coin appears in no IncentiveV3 rule): {len(orph)} funds, {fmt_usd(orph_val)}.")
A("")
A("## Funds by lineage")
A("")
for lin in LIN_ORDER:
    fl = [f for f in funds if f["lineage"] == lin]
    val = sum(f["value_usd"] or 0 for f in fl)
    A(f"### {LIN_DESC[lin]} — {len(fl)} funds, {fmt_usd(val)}")
    A("")
    A("| Fund | Type | Symbol | Raw balance | Amount | Price USD | Value USD | active_in_iv3 | Last modified |")
    A("|---|---|---|---:|---:|---:|---:|---|---|")
    for f in fl:
        A(f"| `{short(f['address'])}` | {f['kind'].split('_')[-1]} | {f['symbol']} | {f['raw_balance']} | {f['amount']:,.6f} | {f['price_usd']} | {fmt_usd(f['value_usd'])} | {'yes' if f['active_in_iv3'] else '**NO**'} | {f['last_modified'][:19]} |")
    A("")
A("## Totals by symbol")
A("")
A("| Symbol | Funds | Amount | Value USD |")
A("|---|---:|---:|---:|")
for sym, t in sorted(d["totals_by_symbol"].items(), key=lambda kv: -kv[1]["value_usd"]):
    A(f"| {sym} | {t['funds']} | {t['amount']:,.6f} | {fmt_usd(t['value_usd'])} |")
A(f"| **TOTAL** | **{len(funds)}** | | **{fmt_usd(total)}** |")
A("")
A("## Largest funds (top 10)")
A("")
A("| # | Fund | Lineage | Symbol | Amount | Value USD |")
A("|---:|---|---|---|---:|---:|")
for i, f in enumerate(funds[:10], 1):
    A(f"| {i} | `{f['address']}` | {f['lineage']} | {f['symbol']} | {f['amount']:,.6f} | {fmt_usd(f['value_usd'])} |")
A("")
A("## Orphaned funds (coin type matches no IncentiveV3 rule)")
A("")
A("| Fund | Lineage | Symbol | Amount | Value USD | Note |")
A("|---|---|---|---:|---:|---|")
for f in orph:
    if f["amount"] > 0:
        note = "non-zero balance"
        if f["lineage"].startswith("v2_second") and f["symbol"] in ("USDT", "USDC"):
            note = "large balance stranded in deprecated 2nd-lineage v2 deployment"
        elif f["lineage"].startswith("v3_second"):
            note = "2nd-lineage v3 deployment (its IncentiveV3 has 0 pools)"
        elif f["lineage"] == "v3_main_0x81c408":
            note = "main lineage but coin not used as reward in any current rule"
        A(f"| `{short(f['address'])}` | {f['lineage']} | {f['symbol']} | {f['amount']:,.6f} | {fmt_usd(f['value_usd'])} | {note} |")
A("")
A(f"*Plus {sum(1 for f in orph if f['amount'] == 0)} orphaned funds with zero balance (3 drained main-lineage v2 pools + 2 second-lineage v3 funds; note all 9 main-lineage v2 pools are empty).*")
A("")
A("## Method")
A("")
A("1. Enumerated objects with `objects(first: 50, after: $cursor, filter: {type: \"<pkg>::<module>::<struct>\"})` on the public keyless GraphQL endpoint; the type filter matches all generic instantiations. Pagination used cursors; every type fit in a single page (max 15).")
A("2. Package lineage/type-origin completeness: `MovePackage.typeOrigins` on both lineage heads (A: `0x512f2826…` v26; B: `0x20cb20ed…` v20) lists every struct ever defined. The only fund structs are `incentive_v3::RewardFund` (origins 0x81c408 and 0xacc64a) and `incentive_v2::IncentiveFundsPool` (origins 0xe66f07 and 0xa49c5d1c). No `incentive::IncentiveFundsPool` struct exists in either lineage (0 objects for the v1 type).")
A("3. Balances read from Move object JSON (`balance`, `coin_type`); decimals/symbol from `coinMetadata`; last-modified from `previousTransaction.effects.timestamp`. Balances re-fetched fresh at the end (three funds changed mid-census).")
A("4. Active marking: reward coin types taken from the current main IncentiveV3 parent `0x62982dad…` (`pools[].rules[].reward_coin_type`, 24 pools, 43 rules, all enabled). `active_in_iv3 = coin_type ∈ rule set`.")
A("5. Parent objects read: IncentiveV3 `0x62982dad…` (24 pools); IncentiveV2 `0xf87a8acb…` (funds Table `0x4821004b…` size 9 = exactly the 9 main-lineage v2 pools; `inactive_objs` = 746; pools Table `0xcc4aac9c…` size 746). Lineage B parents also checked (see anomalies).")
A("6. Prices: DefiLlama `coins.llama.fi/prices/current/sui:0x…` for 14/17 coin types. The three legacy bridge tokens `0x0eedc385…::usdc/USDT/WETH` are absent from DefiLlama and were priced via public CoinGecko (USDC 0.999758, USDT 0.999247, WETH = ETH 2491.49).")
A("")
A("## Anomalies")
A("")
A("- **~$197k stranded in the deprecated second lineage (lineage B) v2 pools:** USDT fund `0xf78f9269…` holds 98,554.02 USDT ({}) and USDC fund `0x6797966d…` holds 98,440.91 USDC ({}), last touched 2023-11-22. These funds are registered in lineage B's IncentiveV2 funds table (size 7) but lineage B's IncentiveV3 parents have **0 pools**, i.e. no live reward rules. Their coin types match no rule of the main IncentiveV3 either.".format(fmt_usd(98479.81), fmt_usd(98417.09)))
A("- **Second-lineage v3 RewardFunds are orphaned:** all 13 `0xacc64a…::incentive_v3::RewardFund` objects belong to a deployment whose current IncentiveV3 objects (`0x50d66cc5…`, `0x163227d6…`) have zero pools. Balances are small ($3.5k total) and stale (Feb 2025 – May 2026).")
A("- **Main-lineage BLUE fund orphaned:** `0x1234d898…` holds 89,662.22 BLUE (~$815) but BLUE is not a reward coin in any current IncentiveV3 rule; last touched 2026-10-02.")
A("- **All 9 main-lineage v2 IncentiveFundsPool objects have balance 0** (drained), although 6 of their coin types (NS, vSUI, NAVX, stSUI, DEEP, FDUSD) still appear in current v3 rules. Three of them were last touched 2026-08-12 (NS, vSUI, DEEP) — likely a migration sweep.")
A("- **Live activity during census:** WAL, vSUI and DEEP main-lineage funds decreased between the first and final fetch (−325.93 WAL, −96.89 vSUI, −822.72 DEEP at ~02:33–02:36 UTC), i.e. rewards are actively being claimed. Both parent objects are hot: IncentiveV3 and IncentiveV2 versions advanced repeatedly during the census (both at 1042318409 at 02:39 UTC).")
A("- **Two parallel protocol lineages** with identical module sets exist (A: 26 package versions starting `0xd899cf7d…`; B: 20 versions starting `0xa49c5d1c…`). Only lineage A is referenced by the current NAVI SDK/`IncentiveV3` singleton; lineage B appears abandoned but still holds funds.")
A("")
A("## Notes")
A("")
for n in d["notes"]:
    A(f"- {n}")
A("")
open(MD, "w").write("\n".join(lines) + "\n")
print("wrote", MD, len(lines), "lines")

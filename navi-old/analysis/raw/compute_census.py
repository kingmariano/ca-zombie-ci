#!/usr/bin/env python3
"""Compute NAVI reward-fund census and write JSON + MD deliverables."""
import json, subprocess, datetime, collections

RAW = "/home/heisenberg/CA/navi-old/analysis/raw"
OUT_JSON = "/home/heisenberg/CA/navi-old/analysis/reward-funds-census.json"
OUT_MD = "/home/heisenberg/CA/navi-old/analysis/reward-funds-census.md"

fresh = json.load(open(f"{RAW}/funds_fresh.json"))
merged = json.load(open(f"{RAW}/funds_merged.json"))
meta = json.load(open(f"{RAW}/coin_meta.json"))
llama = json.load(open(f"{RAW}/prices_llama.json"))["coins"]

# CoinGecko fallback (fetched separately, values hardcoded from live response 2026-10-10)
cg = {
    "0eedc3857f39f5e44b5786ebcd790317902ffca9960f44fcea5b7589cfc7a784::usdc::USDC": (0.999758, "coingecko:usd-coin"),
    "0eedc3857f39f5e44b5786ebcd790317902ffca9960f44fcea5b7589cfc7a784::usdt::USDT": (0.999247, "coingecko:tether"),
    "0eedc3857f39f5e44b5786ebcd790317902ffca9960f44fcea5b7589cfc7a784::weth::WETH": (2491.49, "coingecko:ethereum"),
}

def full(c):
    return "0x" + c if not c.startswith("0x") else c

# active coin types from main IV3 parent rules
active_set = {l.strip() for l in open(f"{RAW}/iv3_rule_types_final.txt") if l.strip()}

LINEAGE_LABEL = {
    "A:0x81c408": "v3_main_0x81c408",
    "B:0xacc64a": "v3_second_0xacc64a",
    "A:0xe66f07": "v2_main_0xe66f07",
    "B:0xa49c5d1c": "v2_second_0xa49c5d1c",
}

funds = []
for f in merged:
    a = f["address"]
    fr = fresh[a]
    ct = f["coin_type"]
    m = meta[ct]
    decimals = m["decimals"]
    symbol = m["symbol"]
    raw_balance = fr["raw_balance"]
    amount = int(raw_balance) / (10 ** decimals)
    key = "sui:" + full(ct)
    if key in llama and llama[key]:
        price = llama[key]["price"]
        price_source = "defillama"
    elif ct in cg:
        price, src = cg[ct]
        price_source = src
    else:
        price = None
        price_source = "unknown"
    value = round(amount * price, 2) if price is not None else None
    funds.append({
        "address": a,
        "kind": f["kind"],
        "lineage": LINEAGE_LABEL[f["lineage"]],
        "coin_type": full(ct),
        "symbol": symbol,
        "decimals": decimals,
        "raw_balance": raw_balance,
        "amount": round(amount, 6),
        "price_usd": price,
        "value_usd": value,
        "active_in_iv3": ct in active_set,
        "move_object_version": fr["version"],
        "last_modified": fr["last_modified"],
        "price_source": price_source,
    })

# sort by value desc for convenience
funds.sort(key=lambda x: (-(x["value_usd"] or 0), x["address"]))

totals = collections.OrderedDict()
for sym in sorted({f["symbol"] for f in funds}):
    fl = [f for f in funds if f["symbol"] == sym]
    totals[sym] = {
        "value_usd": round(sum(f["value_usd"] or 0 for f in fl), 2),
        "funds": len(fl),
        "amount": round(sum(f["amount"] for f in fl), 6),
    }

total_usd = round(sum(f["value_usd"] or 0 for f in funds), 2)

by_lineage = collections.OrderedDict()
for lin in ["v3_main_0x81c408", "v3_second_0xacc64a", "v2_main_0xe66f07", "v2_second_0xa49c5d1c"]:
    fl = [f for f in funds if f["lineage"] == lin]
    by_lineage[lin] = {"funds": len(fl), "value_usd": round(sum(f["value_usd"] or 0 for f in fl), 2)}

# fresh checkpoint
r = subprocess.run(["bash", "-c", f"echo '{{\"query\":\"{{ checkpoint {{ sequenceNumber timestamp }} }}\"}}' | {RAW}/gql.sh"],
                   capture_output=True, text=True)
cp = json.loads(r.stdout)["data"]["checkpoint"]

notes = [
    "Endpoint: public keyless https://graphql.mainnet.sui.io/graphql (POST) only. Prices: public DefiLlama coins API, plus public CoinGecko simple/price fallback for 3 legacy bridge tokens absent from DefiLlama (0eedc385::usdc/USDT priced ~$1, 0eedc385::weth priced at ETH).",
    "Census scope: all objects of the four fund struct types across the two NAVI protocol package lineages (A: 0xd899cf7d..512f2826, 26 versions; B: 0xa49c5d1c..20cb20ed, 20 versions), confirmed complete via MovePackage.typeOrigins on each lineage head.",
    "v1 type 0xd899cf7d::incentive::IncentiveFundsPool does not exist as a struct in lineage A (typeOrigins lists no such struct); 0 objects. Same for both lineages' incentive modules.",
    "Two RewardFund origins exist: 0x81c408 (lineage A, version 22) = 15 funds; 0xacc64a (lineage B, version 13) = 13 funds. Two IncentiveFundsPool origins: 0xe66f07 (lineage A, v9) = 9 funds; 0xa49c5d1c (lineage B, v1) = 7 funds. Total 44 fund objects.",
    "active_in_iv3 = fund coin_type appears in any rule of the current main IncentiveV3 parent 0x62982dad. Its 24 pools contain 43 rules across 9 reward coin types (WAL, HAEDAL, NS, CERT, IKA, NAVX, STSUI, DEEP, FDUSD); all 43 rules have enable=true.",
    "Lineage B IncentiveV3 parents (0x50d66cc5, 0x163227d6) have 0 pools => lineage B v3 RewardFunds are orphaned (no rules in either lineage).",
    "Main IncentiveV2 parent 0xf87a8acb: funds Table 0x4821004b.. size 9 = exactly the 9 lineage A v2 IncentiveFundsPool objects; inactive_objs 746; pools Table 0xcc4aac9c.. size 746. All 9 v2 pools have balance 0 (drained).",
    "Lineage B IncentiveV2 parent 0x952b6726: funds Table 0x05537e42.. size 7 = exactly the 7 lineage B v2 pools (all registered). Deployment is stale (funds last touched 2023-11-22 to 2025-02-22).",
    "Live activity during census: three lineage A v3 funds decreased between enumeration and final fetch (WAL -325.93, vSUI/CERT -96.89, DEEP -822.72) at ~2026-10-10T02:33Z, consistent with reward claims/withdrawals. Final balances are the latest.",
    "The main IncentiveV3 and IncentiveV2 parent objects are actively modified (both at version 1042318409 / 2026-10-10T02:39Z during census).",
    "Funds with coin types matching no IV3 rule are flagged active_in_iv3=false (orphaned): 16 funds total, $201,299.59 — 12 in the second lineage B (incl. ~$98.5k USDT and ~$98.4k USDC in its stale v2 pools), the lineage A BLUE fund (0x1234d898, ~89.7k BLUE), and 3 drained lineage A v2 pools (BLUE, haSUI, SUI). All 9 lineage A v2 pools are empty regardless of coin type.",
    "Balances are Move 'Balance' raw values; amount = raw / 10^decimals. USD values are estimates at prices captured 2026-10-10 ~02:40 UTC.",
]

out = {
    "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "latest_checkpoint": cp["sequenceNumber"],
    "checkpoint_timestamp": cp["timestamp"],
    "funds": funds,
    "totals_by_symbol": totals,
    "total_usd": total_usd,
    "totals_by_lineage": by_lineage,
    "notes": notes,
}
json.dump(out, open(OUT_JSON, "w"), indent=2)
print("wrote", OUT_JSON, "total_usd=", total_usd, "funds=", len(funds))
print(json.dumps(by_lineage, indent=1))
for f in funds[:6]:
    print(f["lineage"], f["symbol"], f["value_usd"], f["address"])
print("checkpoint", cp["sequenceNumber"], cp["timestamp"])

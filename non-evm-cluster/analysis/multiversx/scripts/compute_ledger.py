#!/usr/bin/env python3
"""Compute the remnant ledger: per target, per token, USD; classify E-U/H-O/P/S.
Prices (fetched 2026-10-10 ~03:14-03:50 UTC):
  EGLD $4.033253723488384 (coins.llama.fi coingecko:elrond-erd-2, ts 1791600774)
  WEGLD $4.026669153600333, MEX $6.087087452169736e-07 (api.multiversx.com token valueUsd)
  EGLDMEX LP $4.0692 = 2*64,948.2603 WEGLD *$4.0267 / 128,523 LP supply
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")
fb = json.load(open(os.path.join(RAW, "full_balances.json")))
cb = json.load(open(os.path.join(RAW, "candidate_balances.json")))

EGLD = 4.033253723488384
WEGLD = 4.026669153600333
MEX = 6.087087452169736e-07
EGLDMEX = 4.0692

PRICE = {"WEGLD-bd4d79": WEGLD, "MEX-455c57": MEX, "LKMEX-aab910": MEX,
         "EGLDMEX-0be9e5": EGLDMEX, "USDC-c76f1f": 1.0, "USDT-f8c08c": 1.0}

# classification of each full_balances target (address -> class)
CLASS = {
 "proxy_dex_v1_legacy": "H-O", "metabonding_staking_legacy": "H-O",
 "simple_lock_legacy_0": "H-O", "simple_lock_legacy_1": "H-O", "simple_lock_legacy_2": "H-O",
 "price_discovery_0": "S", "price_discovery_1": "S", "price_discovery_2": "S",
 "farm_v1.2_0": "H-O", "farm_v1.2_1": "H-O", "farm_v1.2_2": "H-O",
 "farm_v1.3_locked_0": "H-O", "farm_v1.3_locked_2": "H-O", "farm_v1.3_custom_0": "H-O",
 "farm_v2_deprecated_0": "H-O",
 "distribution_legacy": "S", "locked_asset_factory_legacy": "S",
 "wegld_swap_shard1": "S", "wegld_swap_shard2": "S",
 "community_delegation": "H-O",
}

def ft_usd(ident, bal, dec):
    if ident in PRICE:
        return bal / 10**dec * PRICE[ident]
    return None

print(f"{'target':34s} {'class':5s} {'token':24s} {'amount':>24s} {'USD':>14s}")
tot = {"E-U": 0.0, "H-O": 0.0, "P": 0.0, "S": 0.0}
rows = []
seen_meta = set()  # dedupe (name, token)
for addr, rec in fb.items():
    name = rec["name"]; cls = CLASS.get(name, "?")
    for ident, v in rec["fungible"].items():
        if not v["balance"]:
            continue
        dec = v["decimals"] or 18
        amt = v["balance"] / 10**dec
        usd = ft_usd(ident, v["balance"], dec)
        if usd is None and v.get("usd"):
            usd = v["usd"]
        if usd is not None:
            print(f"{name:34s} {cls:5s} {ident:24s} {amt:>24,.6f} {usd:>14,.2f}")
            tot[cls] += usd
            rows.append({"target": name, "class": cls, "token": ident, "amount": str(amt), "usd": usd})
    for ident, v in rec["metaesdt"].items():
        dec = 18
        amt = v["balance"] / 10**dec
        if ident in PRICE:
            usd = amt * PRICE[ident]
        else:
            usd = None
        if usd is not None:
            print(f"{name:34s} {cls:5s} {ident:24s} {amt:>24,.6f} {usd:>14,.4f}")
            tot[cls] += usd
            rows.append({"target": name, "class": cls, "token": ident, "amount": str(amt), "usd": usd})
        else:
            print(f"{name:34s} {cls:5s} {ident:24s} {amt:>24,.6f} {'(unpriced)':>14s}")
            rows.append({"target": name, "class": cls, "token": ident, "amount": str(amt), "usd": None})

# candidate balances for farms not in full_balances (v1.3 unlocked/custom) - MEX only
SEEN_FARM_NAMES = {"farm_v1.3_unlockedRewards_2", "farm_v1.3_customRewards_0"}
for addr, rec in cb.items():
    name = rec["name"]
    if not name.startswith("farm_v1.3"):
        continue
    key = ("v13", name.replace("Rewards", "_").replace("farm_v1.3_", "")) 
    # canonical dedupe against full_balances names
    canonical = name.replace("farm_v1.3_lockedRewards_", "farm_v1.3_locked_").replace("farm_v1.3_customRewards_", "farm_v1.3_custom_")
    if canonical in {r["target"] for r in rows} or canonical in CLASS:
        continue
    toks = rec["tokens"] if isinstance(rec["tokens"], list) else []
    for t in toks:
        if t.get("identifier") == "MEX-455c57" and t.get("valueUsd"):
            print(f"{name:34s} H-O   MEX-455c57             {int(t['balance'])/1e18:>24,.6f} {t['valueUsd']:>14,.2f}")
            tot["H-O"] += t["valueUsd"]
            rows.append({"target": name, "class": "H-O", "token": "MEX-455c57", "amount": str(int(t['balance'])/1e18), "usd": t["valueUsd"]})

# community delegation (EGLD user-owed; from /delegation-legacy + account balance)
CD_OWED = (616416316203580088866 + 0 + 1536016913153813867855056 + 2983086846186132144944 + 45116219335112700635512) / 1e18
CD_LIQUID = 136994.53627969887
print(f"{'community_delegation':34s} {'H-O':5s} {'EGLD (user-owed)':24s} {CD_OWED:>24,.4f} {CD_OWED*EGLD:>14,.2f}")
print(f"{'community_delegation':34s} {'H-O':5s} {'  of which liquid':24s} {CD_LIQUID:>24,.4f} {CD_LIQUID*EGLD:>14,.2f}")
tot["H-O"] += CD_OWED * EGLD
rows.append({"target": "community_delegation", "class": "H-O", "token": "EGLD", "amount": str(CD_OWED), "usd": CD_OWED * EGLD})

# developer rewards (P) from candidate dump
P_DEV = 0.0
for a, rec in cb.items():
    P_DEV += int(rec["account"].get("developerReward", 0) or 0) / 1e18
tot["P"] += P_DEV * EGLD
print(f"{'(all candidates)':34s} {'P':5s} {'EGLD dev rewards':24s} {P_DEV:>24,.4f} {P_DEV*EGLD:>14,.2f}")
rows.append({"target": "(all candidate contracts)", "class": "P", "token": "EGLD developerReward", "amount": str(P_DEV), "usd": P_DEV * EGLD})

print()
print("TOTALS (priced):", {k: round(v, 2) for k, v in tot.items()})
json.dump({"totals": tot, "rows": rows, "prices": {"EGLD": EGLD, "WEGLD": WEGLD, "MEX": MEX, "EGLDMEX_LP": EGLDMEX}},
          open(os.path.join(RAW, "ledger.json"), "w"), indent=1)
print("wrote raw/ledger.json")

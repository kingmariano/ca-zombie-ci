#!/usr/bin/env python3
"""Summarize a saved Koios address_info + address_assets dump into a compact state table.
Usage: python3 summarize.py <address_info.json> <address_assets.json> <out.json>
Prints: per address lovelace, #utxos, assets (aggregated), plus reference script hashes seen.
"""
import json, sys, collections

ai = json.load(open(sys.argv[1]))
aa = json.load(open(sys.argv[2]))
out = {"queried_at": ai["queried_at"], "tip": ai["tip"], "addresses": {}}

for a in ai["response"]:
    addr = a["address"]
    assets = collections.Counter()
    # asset names map
    for u in a.get("utxo_set", []):
        for al in u.get("asset_list", []):
            key = al["policy_id"] + "." + al["asset_name"]
            assets[key] += int(al["quantity"])
    ref_scripts = []
    for u in a.get("utxo_set", []):
        if u.get("reference_script"):
            ref_scripts.append({"hash": u["reference_script"]["hash"], "size": u["reference_script"]["size"], "type": u["reference_script"]["type"], "tx_hash": u["tx_hash"]})
    out["addresses"][addr] = {
        "lovelace": a["balance"],
        "n_utxos": len(a.get("utxo_set", [])),
        "script_address": a.get("script_address"),
        "stake_address": a.get("stake_address"),
        "assets": dict(assets),
        "reference_scripts": ref_scripts,
    }

# aggregated assets from address_assets (authoritative aggregation incl. native assets)
agg = collections.defaultdict(list)
for r in aa["response"]:
    agg[r["address"]].append({"asset": r["policy_id"] + "." + r["asset_name"], "qty": r["quantity"], "fingerprint": r.get("fingerprint")})
out["address_assets_agg"] = {k: v for k, v in agg.items()}
json.dump(out, open(sys.argv[3], "w"), indent=1)

# human readable
for addr, d in out["addresses"].items():
    print(f"== {addr}\n   lovelace={d['lovelace']} ({int(d['lovelace'])/1e6:,.0f} ADA) utxos={d['n_utxos']} stake={d['stake_address']}")
    for k, v in sorted(d["assets"].items(), key=lambda kv: -kv[1])[:12]:
        print(f"     {k}: {v}")
    for rs in d["reference_scripts"]:
        print(f"     refscript {rs['hash']} {rs['type']} {rs['size']}b tx {rs['tx_hash'][:16]}")
print("TIP block", ai["tip"][0]["block_height"], "slot", ai["tip"][0]["abs_slot"], "time", ai["tip"][0]["block_time"])

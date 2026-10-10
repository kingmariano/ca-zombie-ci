#!/usr/bin/env python3
"""Parse V2 pool UTxOs properly (cbor2), filter by pool auth asset MSP, aggregate per pair."""
import json, cbor2
from collections import Counter, defaultdict

AUTH = "f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c4d5350"  # MSP pool authen
LP_POLICY = "f5808c2c990d86da54bfc97d89cee6efa20cd8461616359478d96b4c"

ai = json.load(open("/home/heisenberg/CA/non-evm-cluster/analysis/cardano/djed/koios_address_info.json"))
shared = [a for a in ai["response"] if a["address"].startswith("addr1z84q0den")][0]
utxos = shared["utxo_set"]

def tag(o):
    return o.tag if hasattr(o, "tag") else None  # 121=Constr0

def asset_str(node):
    if hasattr(node, "tag") and node.tag in (121, 122):
        v = node.value
        pol = v[0].hex() if isinstance(v[0], bytes) else None
        nam = v[1].hex() if isinstance(v[1], bytes) else None
        return pol, nam
    return None, None

pools = []
nonpools = 0
for u in utxos:
    d = u.get("inline_datum")
    if not d: continue
    try:
        obj = cbor2.loads(bytes.fromhex(d["bytes"]))
        f = obj.value
        assets = {a["policy_id"] + "." + a["asset_name"]: int(a["quantity"]) for a in u.get("asset_list", [])}
        is_pool = assets.get(AUTH) == 1
        polA, namA = asset_str(f[1]); polB, namB = asset_str(f[2])
        rec = {
            "tx_hash": u["tx_hash"], "tx_index": u["tx_index"],
            "lovelace": int(u["value"]),
            "totalLiquidity": f[3], "reserveA": f[4], "reserveB": f[5],
            "assetA": (polA or "") + "." + (namA or ""), "assetB": (polB or "") + "." + (namB or ""),
            "block_height": u["block_height"], "block_time": u["block_time"],
            "is_pool": is_pool,
            "lp": {k: v for k, v in assets.items() if k.startswith(LP_POLICY) and k != AUTH},
            "auth": assets.get(AUTH, 0),
            "assets_utxo": assets,
            "n_fields": len(f),
        }
        if is_pool:
            pools.append(rec)
        else:
            nonpools += 1
    except Exception as e:
        nonpools += 1

print("UTxOs:", len(utxos), "pool UTxOs (MSP=1):", len(pools), "other datum UTxOs:", nonpools)
pairc = Counter((p["assetA"], p["assetB"]) for p in pools)
print("unique pairs:", len(pairc), "| max utxos/pair:", pairc.most_common(3))

pools.sort(key=lambda p: -p["lovelace"])
tot = sum(p["lovelace"] for p in pools)
print("total ADA in pool UTxOs:", tot/1e6)
print("\nTop 30 V2 pool UTxOs:")
for p in pools[:30]:
    print(f"  {p['lovelace']/1e6:12,.2f} ADA  resA={p['reserveA']:>16} resB={p['reserveB']:>16}  {p['assetA'][:34]} / {p['assetB'][:34]}  bh={p['block_height']} lp={list(p['lp'].items())[:1]}")
json.dump({"tip": ai["tip"], "n_utxos": len(utxos), "n_pools": len(pools), "pools": pools}, open("v2_pools_parsed.json", "w"), indent=1)

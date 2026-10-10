#!/usr/bin/env python3
"""Final V2 parse: identify pool UTxOs by datum shape; save; compare with metrics page."""
import json, cbor2
from collections import Counter

ai = json.load(open("/home/heisenberg/CA/non-evm-cluster/analysis/cardano/djed/koios_address_info.json"))
shared = [a for a in ai["response"] if a["address"].startswith("addr1z84q0den")][0]
utxos = shared["utxo_set"]

def astr(node):
    try:
        v = node.value
        return (v[0].hex() if isinstance(v[0], bytes) else "") + "." + (v[1].hex() if isinstance(v[1], bytes) else "")
    except Exception:
        return None

pools, others = [], []
for u in utxos:
    d = u.get("inline_datum")
    if not d:
        others.append(u); continue
    try:
        obj = cbor2.loads(bytes.fromhex(d["bytes"]))
        f = obj.value
        if obj.tag == 121 and len(f) == 10 and hasattr(f[1], "tag") and hasattr(f[2], "tag"):
            rec = {
                "tx_hash": u["tx_hash"], "tx_index": u["tx_index"], "lovelace": int(u["value"]),
                "totalLiquidity": int(f[3]), "reserveA": int(f[4]), "reserveB": int(f[5]),
                "assetA": astr(f[1]), "assetB": astr(f[2]),
                "baseFeeA": int(f[6].value[0]) if hasattr(f[6], "value") else None,
                "baseFeeB": int(f[6].value[1]) if hasattr(f[6], "value") else None,
                "block_height": u["block_height"], "block_time": u["block_time"],
                "datum_hash": u.get("datum_hash"),
                "assets": {a["policy_id"] + "." + a["asset_name"]: int(a["quantity"]) for a in u.get("asset_list", [])},
            }
            pools.append(rec)
        else:
            others.append(u)
    except Exception:
        others.append(u)

pools.sort(key=lambda p: -p["lovelace"])
tot = sum(p["lovelace"] for p in pools)
totall = sum(int(u["value"]) for u in utxos)
print(f"UTxOs={len(utxos)} pools={len(pools)} other-datum={len(others)}")
print(f"ADA in pools={tot/1e6:,.6f} ; ADA at address total={totall/1e6:,.6f}")
print(f"unique pairs={len(set((p['assetA'],p['assetB']) for p in pools))}")
out = {"source": "Koios address_info addr1z84q0den...", "tip": ai["tip"], "n_utxos": len(utxos), "n_pools": len(pools), "ada_pools": tot, "ada_total": totall, "pools": pools}
json.dump(out, open("v2_pools_parsed.json", "w"), indent=1)

print("\nTop 20 pools by ADA UTxO:")
for p in pools[:20]:
    print(f"  {p['lovelace']/1e6:12,.2f} ADA  resA={p['reserveA']:>17} resB={p['reserveB']:>17}  {p['assetA'][:34]} / {p['assetB'][:34]}  bh={p['block_height']} liq={p['totalLiquidity']}")

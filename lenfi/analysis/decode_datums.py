#!/usr/bin/env python3
"""Decode live Lenfi datums (PlutusData) and classify UTxOs by role."""
import json, sys
from collections import defaultdict
from pycardano import PlutusData

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
utxos = json.load(open(f"{D}/koios_address_utxos.json"))
datums = json.load(open(f"{D}/koios_datums.json"))
dec = json.load(open(f"{D}/addresses_decoded.json"))
addr2name = {}
for k, v in dec["base_script_addresses"].items():
    addr2name[v["bech32"]] = k
for k, v in dec["bare_script_hashes"].items():
    addr2name[v["enterprise_address"]] = k
for k, v in dec["other"].items():
    addr2name[v["bech32"]] = k


def to_pd(hexstr):
    try:
        return PlutusData.from_cbor(bytes.fromhex(hexstr))
    except Exception as e:
        return f"<decode-error {e}>"


def flat(v):
    """Render PlutusData as python-ish nested structure."""
    from pycardano.serialization import IndefiniteList
    if isinstance(v, PlutusData):
        return {"c": v.constructor, "f": [flat(x) for x in v.fields]}
    if isinstance(v, (IndefiniteList, list)):
        return [flat(x) for x in v]
    if isinstance(v, dict):
        return {flat(k): flat(val) for k, val in v.items()}
    if isinstance(v, bytes):
        return v.hex()
    return v


rows = []
for u in utxos:
    name = addr2name.get(u["address"], u["address"])
    d = None
    if u.get("inline_datum"):
        hexd = u["inline_datum"]["bytes"] if isinstance(u["inline_datum"], dict) else u["inline_datum"]
        d = to_pd(hexd)
        src = "inline"
    elif u.get("datum_hash") and datums.get(u["datum_hash"]):
        d = to_pd(datums[u["datum_hash"]])
        src = "witness"
    else:
        src = "none"
    rows.append({
        "addr": name, "tx": u["tx_hash"], "ix": u["tx_index"], "ada": int(u["value"]) / 1e6,
        "assets": {a["policy_id"] + "." + a["asset_name"]: int(a["quantity"]) for a in (u.get("asset_list") or [])},
        "datum_src": src, "datum": flat(d) if not isinstance(d, str) else d,
        "block": u["block_height"], "time": u["block_time"],
    })

json.dump(rows, open(f"{D}/live_utxos_decoded.json", "w"), indent=1)
print("decoded", len(rows), "utxos")

# show a few examples per class
seen = defaultdict(int)
for r in rows:
    if seen[r["addr"]] < 3:
        seen[r["addr"]] += 1
        print(f"\n--- {r['addr']} {r['tx'][:16]}#{r['ix']} ada={r['ada']} assets={list(r['assets'])[:3]} src={r['datum_src']} t={r['time']}")
        s = json.dumps(r["datum"])
        print(s[:600])

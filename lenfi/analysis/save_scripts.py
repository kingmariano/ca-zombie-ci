#!/usr/bin/env python3
"""Save on-chain script bytes (from Koios script_info) to .hex files; analyze reference_script attachments."""
import json
import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
sci = json.load(open(f"{D}/koios_script_info.json"))
names = {
    "b1259b98f6e4776985fc5a9333717d8c9f1e62744fed8240640461d7": "liquidation_v1",
    "2d75e5cf11622d5f68e2b2ef5be50f0027bb7d485e98c881e665676c": "collateral_v1",
    "d721808a6ca9cb6af91d6d0fac862293f112d659addb8bfdbecb3761": "request_v2",
    "31e7527a2972e83de4e4a77750a8acf8225b8247e86d4c400d4a2651": "collateral_v2",
    "32e8c0ae314ef4be452c16a999867f66d1a1791fc972cb2f7c74e38d": "pool_v1",
    "16ecc417c3ec9a58e4ef07a7e277c1a48289896cd2b0bc69e2b0208d": "debt_request_v1",
    "92862d28096bed36fb01d36dc4c77214f64630d60bc990db9876f250": "interest_v1",
    "8021830afedd85fda1253da2be75b66c0e65c482148eb8ca690903cb": "leftovers_v1",
    "9b99fef5ee9a6b170a418999e89edad93bbf55bf1feef57b6053d634": "collateral_pool_v1",
    "0a5abd03628e0308b63abe546c0d3bd8969faaf46b98d082808b8059": "request_v1",
    "1999507bc0ee90e1c376e608496e624e8645b3d558e244c2cd825a38": "lenfi_stake_holder",
    "34c3e3c66dd2bfcfc2b538c596fa976d3e9be6d5c549d9da8ec28777": "debt_request_v2",
}
for r in sci:
    n = names.get(r["script_hash"], r["script_hash"][:10])
    open(f"{D}/script_{n}.hex", "w").write(r["bytes"])
    print(f"{n:22s} {r['type']:9s} size={r['size']}  creation_tx={r['creation_tx_hash']}")

# reference_script attachments
ut = json.load(open(f"{D}/koios_address_utxos.json"))
dec = json.load(open(f"{D}/addresses_decoded.json"))
addr2name = {}
for k, v in dec["base_script_addresses"].items():
    addr2name[v["bech32"]] = k
for k, v in dec["bare_script_hashes"].items():
    addr2name[v["enterprise_address"]] = k
for k, v in dec["other"].items():
    addr2name[v["bech32"]] = k
from collections import Counter
c = Counter()
sizes = Counter()
for u in ut:
    if u.get("reference_script"):
        c[addr2name.get(u["address"], u["address"][:20])] += 1
        sizes[(addr2name.get(u["address"], "?"), u["reference_script"]["size"])] += 1
print("\nreference-script-bearing UTxOs by address:")
for k, v in c.most_common():
    print(f"  {k:22s} {v}")
print("\nby (address, refscript size):")
for k, v in sizes.most_common(12):
    print("  ", k, v)

#!/usr/bin/env python3
"""Decode the testnet addresses in aada-finance versions.json and compare payment script hashes
against the live mainnet scripts."""
import json, sys
sys.path.insert(0, "/home/heisenberg/.local/lib/python3.10/site-packages")
from pycardano import Address, ScriptHash

vers = json.load(open("/tmp/opencode/aada-finance/versions.json"))
live = json.load(open("/home/heisenberg/CA/lenfi/analysis/addresses_decoded.json"))
live_hashes = {}
for k, v in live["base_script_addresses"].items():
    live_hashes[v["payment_script_hash"]] = k
for k, v in live["bare_script_hashes"].items():
    live_hashes[v["script_hash"]] = k

for ver, fields in vers.items():
    print(f"=== version {ver} ===")
    for name, val in fields.items():
        if name.endswith("ADDRESS"):
            try:
                a = Address.decode(val)
                sh = str(a.payment_part) if isinstance(a.payment_part, ScriptHash) else None
                match = live_hashes.get(sh, "NOT-LIVE")
                print(f"  {name:24s} {sh}  -> {match}")
            except Exception as e:
                print(f"  {name}: decode error {e}")
        else:
            print(f"  {name:24s} {val}")

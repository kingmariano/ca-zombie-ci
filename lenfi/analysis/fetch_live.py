#!/usr/bin/env python3
"""Fetch live Lenfi V1 state from Koios (keyless). Read-only.
Writes analysis/koios_tip.json, analysis/koios_address_info.json, analysis/koios_address_utxos.json,
analysis/koios_script_info.json
"""
import json, time, urllib.request, sys

KOIOS = "https://api.koios.rest/api/v1"
HDR = {"Content-Type": "application/json", "User-Agent": "readonly-research/1.0"}


def post(path, body, retries=4):
    url = f"{KOIOS}{path}"
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=HDR, method="POST")
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:
            print(f"  retry {i+1} {path}: {e}", file=sys.stderr)
            time.sleep(3 * (i + 1))
    raise RuntimeError(f"failed {path}")


import os
D = os.path.dirname(os.path.abspath(__file__))
dec = json.load(open(f"{D}/addresses_decoded.json"))

base_addrs = [v["bech32"] for v in dec["base_script_addresses"].values() if v["payment_script_hash"]]
ent_addrs = [v["enterprise_address"] for v in dec["bare_script_hashes"].values()]
other = [v["bech32"] for v in dec["other"].values()]
all_addrs = base_addrs + ent_addrs + other
script_hashes = [v["payment_script_hash"] for v in dec["base_script_addresses"].values() if v["payment_script_hash"]] + \
                [v["script_hash"] for v in dec["bare_script_hashes"].values()] + \
                [dec["other"]["lenfi_stake_addr"]["payment_script_hash"]]

tip = json.loads(urllib.request.urlopen(f"{KOIOS}/tip", timeout=30).read())
json.dump(tip, open(f"{D}/koios_tip.json", "w"), indent=1)
print("tip:", tip[0]["block_height"], "slot", tip[0]["abs_slot"], "time", tip[0]["block_time"])

info = post("/address_info", {"_addresses": all_addrs})
json.dump(info, open(f"{D}/koios_address_info.json", "w"), indent=1)
for r in info:
    print("addr_info", r.get("address"), "balance:", r.get("balance"), "utxo_count:", r.get("utxo_count"))

utxos = post("/address_utxos", {"_addresses": all_addrs, "_extended": True})
json.dump(utxos, open(f"{D}/koios_address_utxos.json", "w"), indent=1)
print(f"utxos fetched: {len(utxos)}")

sci = post("/script_info", {"_script_hashes": script_hashes})
json.dump(sci, open(f"{D}/koios_script_info.json", "w"), indent=1)
for r in sci:
    print("script_info", r.get("script_hash"), r.get("type"), "size", r.get("serialised_size"),
          "cbor_len", len(r.get("bytecode") or r.get("cbor") or ""))

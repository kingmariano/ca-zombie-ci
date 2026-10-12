#!/usr/bin/env python3
"""Enumerate all addresses sharing the Lenfi stake key (account) via Koios, then fetch UTxOs+datums for
all Lenfi-related script addresses. Read-only, keyless."""
import json, os, sys, time, urllib.request

KOIOS = "https://api.koios.rest/api/v1"
HDR = {"Content-Type": "application/json", "User-Agent": "readonly-research/1.0"}
import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))


def post(path, body, retries=4):
    for i in range(retries):
        try:
            req = urllib.request.Request(f"{KOIOS}{path}", data=json.dumps(body).encode(), headers=HDR, method="POST")
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read())
        except Exception as e:
            print(f"  retry {i+1} {path}: {e}", file=sys.stderr)
            time.sleep(3 * (i + 1))
    raise RuntimeError(f"failed {path}")


# stake address for key hash 69962602a7025d4163233855c5a379313b27239b8623ad53540815cb (mainnet)
from pycardano import Address, Network, ScriptHash, VerificationKeyHash
stake_addr = Address(staking_part=VerificationKeyHash(bytes.fromhex("69962602a7025d4163233855c5a379313b27239b8623ad53540815cb")), network=Network.MAINNET)
print("stake address:", stake_addr)

accts = post("/account_addresses", {"_stake_addresses": [str(stake_addr)]})
json.dump(accts, open(f"{D}/koios_account_addresses.json", "w"), indent=1)
print(json.dumps(accts, indent=1)[:3000])

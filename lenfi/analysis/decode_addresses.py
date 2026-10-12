#!/usr/bin/env python3
"""Decode Lenfi V1 script addresses -> payment script hashes; derive enterprise script addresses.
Read-only, keyless. Run: python3 decode_addresses.py"""
import json
from pycardano import Address, ScriptHash, Network
from pycardano.crypto.bech32 import decode as bech32_decode

ADDRS = {
    "request_v1":         "addr1zy9940grv28qxz9k82l9gmqd80vfd8a2734e35yzsz9cqktfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9smq5w00",
    "collateral_v1":      "addr1zykhtew0z93z6hmgu2ew7kl9puqz0wmafp0f3jypuejkwmrfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9skq4p22",
    "interest_v1":        "addr1zxfgvtfgp9476dhmq8fkm3x8wg20v33s6c9unyxmnpm0y5rfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9st8q78h",
    "liquidation_v1":     "addr1zxcjtxuc7mj8w6v9l3dfxvm30kxf78nzw387mqjqvszxr4mfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sp92046",
    "debt_request_v1":    "addr1zytwe3qhc0kf5k8yaur60cnhcxjg9zvfdnftp0rfu2czprtfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sgzwepc",
    "collateral_v2":      "addr1zyc7w5n699ews00yujnhw59g4nuzykuzgl5x6nzqp49zv5tfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sdyxnxc",
    "debt_request_v2":    "addr1zy6v8c7xdhftln7zk5uvt9h6jaknaxlx6hz5nkw63mpgwamfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sw9snf6",
    "request_v2":         "addr1z8tjrqy2dj5uk6her4ksltyxy2flzykktxkahzlahm9nwctfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9st86ewu",
}
SCRIPTS = {
    "pool_v1":            "script1xt5vpt33fm6tu3fvz65enpnlvmg6z7gle9evktmuwn3c6gjfc7p",
    "collateral_pool_v1": "script1nwvlaa0wnf43wzjp3xv738k6myam74dlrlh027mq20trg3ng772",
    "leftovers_v1":       "script1sqscxzh7mkzlmgf98k3tuadkds8xt3yzzj8t3jnfpypukld9xck",
}
STAKING = {"lenfi_stake_addr": "addr1wyvej5rmcrhfpcwrwmnqsjtwvf8gv3dn64vwy3xzekp95wqqhdkwa"}

out = {"base_script_addresses": {}, "bare_script_hashes": {}, "other": {}}
for name, a in ADDRS.items():
    addr = Address.decode(a)
    pay = addr.payment_part
    stk = addr.staking_part
    rec = {
        "bech32": a,
        "address_type": addr.address_type.name,
        "payment_script_hash": str(pay) if isinstance(pay, ScriptHash) else None,
        "stake_key_hash": str(stk) if stk is not None else None,
    }
    out["base_script_addresses"][name] = rec
    print(name, rec["address_type"], rec["payment_script_hash"], "stake:", rec["stake_key_hash"])

for name, s in SCRIPTS.items():
    data = bech32_decode(s)
    sh = bytes(data).hex()
    enterprise = Address(payment_part=ScriptHash(bytes.fromhex(sh)), network=Network.MAINNET)
    rec = {"script_hash": sh, "enterprise_address": str(enterprise)}
    out["bare_script_hashes"][name] = rec
    print(name, rec["script_hash"], "->", rec["enterprise_address"])

for name, a in STAKING.items():
    addr = Address.decode(a)
    rec = {"bech32": a, "address_type": addr.address_type.name,
           "payment_script_hash": str(addr.payment_part) if isinstance(addr.payment_part, ScriptHash) else None}
    out["other"][name] = rec
    print(name, rec["address_type"], rec["payment_script_hash"])

with open("/home/heisenberg/CA/lenfi/analysis/addresses_decoded.json", "w") as f:
    json.dump(out, f, indent=1)
print("saved addresses_decoded.json")

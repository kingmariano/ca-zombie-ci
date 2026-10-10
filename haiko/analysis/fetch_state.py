#!/usr/bin/env python3
"""Fetch live state for Haiko mainnet contracts (read-only)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, call, block_number, selector_from_name, u256_from_felts, felt_to_int  # noqa

CONTRACTS = {
    "MarketManager": "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5",
    "ReplicatingSolver": "0x073cc79b07a02fe5dcd714903d62f9f3081e15aeb34e3725f44e495ecd88a5a1",
    "ReplicatingStrategy": "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2",
    "Quoter": "0x5860f2d7c1efc21e27fdeb1716a806c7604770603d1c5f161e473231eb261dc",
    "Distributor": "0x5eb02e164f78fd91b9be6a0b9b3aa02c936db485bd760730f65711533c70a26",
}

TOKENS = {
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
}

BAL = selector_from_name("balanceOf")

out = {"block": block_number(), "contracts": {}, "tokens": TOKENS}

for name, addr in CONTRACTS.items():
    entry = {"address": addr}
    ch = rpc("starknet_getClassHashAt", {"block_id": "latest", "contract_address": addr})
    entry["class_hash"] = ch.get("result") if "result" in ch else ch
    # does it have code?
    entry["class_hash_raw"] = ch
    entry["balances"] = {}
    for tname, taddr in TOKENS.items():
        res = call(taddr, BAL, [addr])
        if "result" in res:
            try:
                entry["balances"][tname] = u256_from_felts(res["result"])
            except Exception as e:
                entry["balances"][tname] = f"err {e}: {res['result']}"
        else:
            entry["balances"][tname] = f"rpc-error: {res.get('error')}"
    out["contracts"][name] = entry
    print(name, addr, "class:", entry["class_hash"], "balances:", entry["balances"])

with open(os.path.join(os.path.dirname(__file__), "state_initial.json"), "w") as f:
    json.dump(out, f, indent=1)
print("saved state_initial.json at block", out["block"])

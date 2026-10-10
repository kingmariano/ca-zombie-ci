#!/usr/bin/env python3
"""Fetch class hashes and full class definitions (ABI) for Haiko contracts."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, block_number  # noqa

CONTRACTS = {
    "MarketManager": "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5",
    "ReplicatingSolver": "0x073cc79b07a02fe5dcd714903d62f9f3081e15aeb34e3725f44e495ecd88a5a1",
    "ReplicatingStrategy": "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2",
    "Quoter": "0x5860f2d7c1efc21e27fdeb1716a806c7604770603d1c5f161e473231eb261dc",
    "Distributor": "0x5eb02e164f78fd91b9be6a0b9b3aa02c936db485bd760730f65711533c70a26",
}

OUT = os.path.join(os.path.dirname(__file__), "classes")
os.makedirs(OUT, exist_ok=True)

block = block_number()
summary = {"block": block, "contracts": {}}
for name, addr in CONTRACTS.items():
    ch = rpc("starknet_getClassHashAt", {"block_id": "latest", "contract_address": addr})
    class_hash = ch.get("result")
    print(f"== {name} {addr}\n   class_hash: {class_hash}")
    if not class_hash:
        print("   ERR", ch)
        summary["contracts"][name] = {"address": addr, "error": ch}
        continue
    cls = rpc("starknet_getClass", {"block_id": "latest", "class_hash": class_hash})
    if "result" not in cls:
        print("   getClass ERR", cls)
        summary["contracts"][name] = {"address": addr, "class_hash": class_hash, "error": cls}
        continue
    result = cls["result"]
    ctype = result.get("contract_class_version", "unknown")
    abi = result.get("abi")
    if isinstance(abi, str):
        try:
            abi = json.loads(abi)
        except Exception:
            pass
    fn_names = []
    if isinstance(abi, list):
        for item in abi:
            if item.get("type") == "function":
                fn_names.append(f"{item.get('name')} ({item.get('state_mutability')})")
    print(f"   type: {ctype}, abi entries: {len(abi) if isinstance(abi, list) else 'n/a'}, functions: {len(fn_names)}")
    # save full class
    with open(os.path.join(OUT, f"{name}.json"), "w") as f:
        json.dump(result, f)
    summary["contracts"][name] = {
        "address": addr,
        "class_hash": class_hash,
        "contract_class_version": ctype,
        "n_abi": len(abi) if isinstance(abi, list) else None,
        "n_functions": len(fn_names),
        "functions": fn_names,
        "sierra": "sierra_program" in result,
    }
    print("   saved", f"{name}.json")

with open(os.path.join(OUT, "classes_summary.json"), "w") as f:
    json.dump(summary, f, indent=1)
print("done; block", block)

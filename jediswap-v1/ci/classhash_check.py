#!/usr/bin/env python3
"""Compare compiled class hashes against live on-chain class hashes."""
import json, sys

from starkware.starknet.services.api.contract_class import ContractClass
from starkware.starknet.core.os.class_hash import compute_class_hash

EXPECTED = {
    "Pair": "0x2b39bc3f4c1fd5bef8b7d21504c44e0da59cf27b350551b13d913da52e40d3b",
    "Factory": "0x2580632f25bbee45da5a1a1ef49d03a984f78dde4019069aa9f25aac06f941a",
    "PairProxy": "0x7b5cd6a6949cc1730f89d795f2442f6ab431ea6c9a5be00685d50f97433c5eb",
    "FactoryProxy": "0x26fe8ea36ec7703569cfe4693b05102940bf122647c4dbf0abc0bb919ce27bd",
    "Router": "0x64e7d628b1b2aa04a35fe6610b005689e8b591058f7f92bf4eb234e67cf403b",
    "RouterProxy": "0x7197021c108b0cc57ae354f5ad02222c4b3d7344664e6dd602a0e2298595434",
}
build = sys.argv[1]
ok = 0
for name, expected in EXPECTED.items():
    try:
        d = json.load(open(f"{build}/{name}.json"))
        d["program"]["debug_info"] = None  # on-chain classes have debug info stripped
        cc = ContractClass.loads(json.dumps(d))
        h = hex(compute_class_hash(cc))
        match = (h == expected)
        ok += match
        print(f"{name:14s} computed={h} expected={expected} MATCH={match}")
    except Exception as e:
        print(f"{name:14s} ERROR {str(e)[:200]}")
print(f"RESULT: {ok}/{len(EXPECTED)} class hashes match the live on-chain classes")

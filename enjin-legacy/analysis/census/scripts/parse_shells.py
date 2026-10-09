#!/usr/bin/env python3
"""Parse AdapterCreated logs -> shells.json (baseType, shell, deployer, block, classification)."""
import json, os

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(BASE, "raw", "adapter_created_all.json")
OUT = os.path.join(BASE, "shells_parsed.json")

with open(RAW) as f:
    data = json.load(f)

rows = []
seen = set()
for lg in data["result"]:
    t = lg["topics"]
    base_type = int(t[1], 16)
    deployer = "0x" + t[2][-40:]
    shell = "0x" + lg["data"][-40:]
    block = int(lg["blockNumber"], 16)
    is_nft = bool((base_type >> 247) & 1)
    key = (base_type, shell)
    assert key not in seen, f"duplicate event {key}"
    seen.add(key)
    rows.append({
        "baseType": str(base_type),
        "baseTypeHex": hex(base_type),
        "shell": shell,
        "deployer": deployer,
        "block": block,
        "txHash": lg["transactionHash"],
        "logIndex": lg["logIndex"] if "logIndex" in lg else lg.get("logIndex"),
        "kind": "NFT" if is_nft else "FT",
    })

rows.sort(key=lambda r: r["block"])
with open(OUT, "w") as f:
    json.dump({"count": len(rows), "shells": rows}, f, indent=1)

nft = [r for r in rows if r["kind"] == "NFT"]
ft = [r for r in rows if r["kind"] == "FT"]
bt = {}
for r in rows:
    bt.setdefault(r["baseType"], []).append(r)
print(f"total events/shells: {len(rows)}")
print(f"NFT-type: {len(nft)}  FT-type: {len(ft)}")
print(f"unique baseTypes: {len(bt)}; base types with >1 shell: {sum(1 for v in bt.values() if len(v) > 1)}")
print("first blocks:", rows[0]["block"] if rows else None, "last block:", rows[-1]["block"] if rows else None)
print("distinct deployers:", len({r['deployer'] for r in rows}))

#!/usr/bin/env python3
"""Fast: find staked veNFTs by scanning Deposit events and batch-probing earned()."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hl_rpc as h
from logs_es import get_logs

GAUGE = sys.argv[1] if len(sys.argv) > 1 else "0x382e5db8ec64e8506879b94568b41d159d64577f"
NTRY = int(sys.argv[2]) if len(sys.argv) > 2 else 300
TOPIC_DEPOSIT = "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c"

d = get_logs(GAUGE, TOPIC_DEPOSIT, page=1, offset=1000)
logs = d.get("result") or []
print("deposit logs:", len(logs))
cands = logs[-NTRY:]
calls = []
for r in cands:
    user = "0x" + r["topics"][1][-40:]
    tid = int(r["data"], 16)
    data = h.enc_sel("earned(uint256)") + f"{tid:064x}"
    calls.append(("eth_call", [{"to": GAUGE, "from": user, "data": data}, "latest"]))
res = h.batch(calls, chunk=10)
found = []
for r, out in zip(cands, res):
    if out and out not in ("0x",) and not out.startswith("0x08c379a0"):
        user = "0x" + r["topics"][1][-40:]
        tid = int(r["data"], 16)
        found.append({"user": user, "tokenId": tid, "earned": int(out, 16), "deposit_block": int(r["blockNumber"], 16)})
print(json.dumps(found, indent=1))
json.dump(found, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "staked_sample.json"), "w"), indent=1)

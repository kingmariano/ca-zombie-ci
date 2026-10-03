#!/usr/bin/env python3
"""Fetch ALL Staked events on ylSPHERE by block-range chunking (bypasses 10k cap)."""
import sys, json, time
sys.path.insert(0, '/home/heisenberg/CA/sphere-finance/analysis')
from es import call
from eth_utils import keccak

L = "0x4af613f297ab00361d516454e5e46bc895889653"
TOPIC = "0x" + keccak(text="Staked(address,uint256,uint256)").hex()

all_logs = {}
for lo in range(36900000, 95000000, 2000000):
    hi = lo + 2000000 - 1
    for page in range(1, 20):
        d = call({"module": "logs", "action": "getLogs", "address": L, "topic0": TOPIC,
                  "fromBlock": lo, "toBlock": hi, "page": page, "offset": 1000})
        if d.get("status") != "1":
            break
        res = d["result"]
        for l in res:
            all_logs[(l["transactionHash"], l["logIndex"])] = l
        if len(res) < 1000:
            break
        time.sleep(0.15)
    print(f"[{lo}-{hi}] cumulative unique logs: {len(all_logs)}", flush=True)
    time.sleep(0.15)

logs = list(all_logs.values())
json.dump(logs, open("/home/heisenberg/CA/sphere-finance/analysis/ylsphere_staked_logs_all.json", "w"))
users = sorted({"0x" + l["topics"][1][-40:] for l in logs})
json.dump(users, open("/home/heisenberg/CA/sphere-finance/analysis/yl_users_all.json", "w"))
print("TOTAL logs:", len(logs), "unique users:", len(users))

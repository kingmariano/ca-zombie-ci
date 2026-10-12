#!/usr/bin/env python3
"""Scan Swap/Mint/Burn/Collect events for all SheepDex pools (full history).
Writes events-swap.json, events-mint.json, events-burn.json (compact)."""
import json, os, urllib.request, time
from collections import Counter

RPC = os.environ["BSC_RPC"]
d = json.load(open("pools-state.json"))
pools = [p["pool"] for p in d["pools"]]
FACTORY_START = 11641289

TOPICS = {
    "swap": "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67",
    "mint": "0x7a53080ba414158be7ec69b987b5fb7d07dee101fe85488f0853ae16239d0bde",
    "burn": "0x0c396cd989a39f4459b5fa1aed6a9a8dcdbc45908acfd67e028cd568da98982c",
    "collect": "0x70935338e69775456a85ddef226c395fb668b63fa0115f5f20610b388e6ca9c0",
}

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"})
    for a in range(5):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                resp = json.load(r)
            if "error" in resp:
                print("rpc err:", str(resp["error"])[:150]); time.sleep(3); continue
            return resp["result"]
        except Exception as e:
            print("retry", e); time.sleep(3)
    return []

latest = d["latest_block"]
for name, topic in TOPICS.items():
    out = []
    # query in per-pool batches to keep results manageable
    for i in range(0, len(pools), 20):
        chunk = pools[i:i+20]
        logs = rpc("eth_getLogs", [{"address": chunk, "topics": [topic],
                                    "fromBlock": hex(FACTORY_START), "toBlock": hex(latest)}])
        for lg in logs:
            rec = {"pool": lg["address"], "block": int(lg["blockNumber"], 16), "tx": lg["transactionHash"]}
            if name == "swap":
                t = lg["topics"]; data = lg["data"][2:]
                rec["sender"] = "0x" + t[1][-40:]
                rec["recipient"] = "0x" + t[2][-40:]
                rec["amount0"] = int.from_bytes(bytes.fromhex(data[0:64]), "big", signed=True)
                rec["amount1"] = int.from_bytes(bytes.fromhex(data[64:128]), "big", signed=True)
            elif name == "mint":
                t = lg["topics"]; data = lg["data"][2:]
                rec["sender"] = "0x" + t[1][-40:]
                rec["owner"] = "0x" + t[2][-40:]
                rec["tickLower"] = int.from_bytes(bytes.fromhex(data[0:64]), "big", signed=True)
                rec["tickUpper"] = int.from_bytes(bytes.fromhex(data[64:128]), "big", signed=True)
                rec["amount"] = int.from_bytes(bytes.fromhex(data[128:192]), "big")
            elif name == "burn":
                t = lg["topics"]; data = lg["data"][2:]
                rec["owner"] = "0x" + t[1][-40:]
                rec["tickLower"] = int.from_bytes(bytes.fromhex(data[0:64]), "big", signed=True)
                rec["tickUpper"] = int.from_bytes(bytes.fromhex(data[64:128]), "big", signed=True)
                rec["amount"] = int.from_bytes(bytes.fromhex(data[128:192]), "big")
            out.append(rec)
        print(name, "chunk", i, "cum", len(out), flush=True)
    json.dump(out, open(f"events-{name}.json", "w"))
    print(f"=== {name}: {len(out)} events ===")

# summaries
sw = json.load(open("events-swap.json"))
by_pool = {}
for e in sw:
    by_pool.setdefault(e["pool"], []).append(e)
print("\nlast swap per pool (top by recency):")
lasts = sorted(by_pool.items(), key=lambda kv: -max(e["block"] for e in kv[1]))
for pool, evs in lasts[:25]:
    print(pool, "last block", max(e["block"] for e in evs), "n_swaps", len(evs),
          "last recipient", evs[-1]["recipient"])

mi = json.load(open("events-mint.json"))
owners = Counter(e["owner"] for e in mi)
print("\nMINT owners (all-time):", owners.most_common(20))
bu = json.load(open("events-burn.json"))
bowners = Counter(e["owner"] for e in bu)
print("\nBURN owners (all-time):", bowners.most_common(20))

#!/usr/bin/env python3
"""Enumerate SheepDex SpeFactory pools via PoolCreated logs (full range), using keyed Ankr RPC.
Output: pools.json  (no secrets in output)."""
import json, os, subprocess, sys, urllib.request

RPC = os.environ["BSC_ANKR_RPC"]  # injected; never written to file
FACTORY = "0x571521f8c16f3c4ed5f2490f19187ba7a5a3cbdf"
TOPIC = "0x783cca1c0412dd0d695e784568c96da2e9c22ff989357a2e8b1d9b2b4e6b7118"

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.load(r)
    if "error" in d:
        raise RuntimeError(d["error"])
    return d["result"]

latest = int(rpc("eth_blockNumber", []), 16)
print("latest block:", latest)
logs = rpc("eth_getLogs", [{"address": FACTORY, "topics": [TOPIC], "fromBlock": hex(11641289), "toBlock": hex(latest)}])
print("PoolCreated logs:", len(logs))

pools = []
for lg in logs:
    t = lg["topics"]
    token0 = "0x" + t[1][-40:]
    token1 = "0x" + t[2][-40:]
    fee = int(t[3], 16)
    data = lg["data"][2:]
    tick_spacing = int.from_bytes(bytes.fromhex(data[0:64]), "big", signed=True)
    pool = "0x" + data[64:128][-40:]
    pools.append({"block": int(lg["blockNumber"], 16), "tx": lg["transactionHash"],
                  "token0": token0, "token1": token1, "fee": fee,
                  "tickSpacing": tick_spacing, "pool": pool})

json.dump({"latest_block": latest, "factory": FACTORY, "count": len(pools), "pools": pools},
          open("pools.json", "w"), indent=1)
print("wrote pools.json with", len(pools), "pools")
for p in pools:
    print(p["block"], p["pool"], p["token0"], p["token1"], p["fee"])

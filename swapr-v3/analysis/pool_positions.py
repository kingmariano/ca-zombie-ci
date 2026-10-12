#!/usr/bin/env python3
"""Generic: reconstruct position owners/liquidity for a Swapr V3 pool from Mint/Burn logs.

Usage: python3 pool_positions.py <pool> <out.json>
RPC-read only, public endpoint, full-range eth_getLogs.
"""
import json, sys, time, urllib.request
from web3 import Web3

RPC = "https://rpc.gnosischain.com"
MC3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
MINT = "0x7a53080ba414158be7ec69b987b5fb7d07dee101fe85488f0853ae16239d0bde"
BURN = "0x0c396cd989a39f4459b5fa1aed6a9a8dcdbc45908acfd67e028cd568da98982c"

w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 90}))
MC3_ABI = [{
    "inputs": [{"components": [
        {"internalType": "address", "name": "target", "type": "address"},
        {"internalType": "bool", "name": "allowFailure", "type": "bool"},
        {"internalType": "bytes", "name": "callData", "type": "bytes"}],
        "internalType": "struct Multicall3.Call3[]", "name": "calls", "type": "tuple[]"}],
    "name": "aggregate3", "outputs": [{"components": [
        {"internalType": "bool", "name": "success", "type": "bool"},
        {"internalType": "bytes", "name": "returnData", "type": "bytes"}],
        "internalType": "struct Multicall3.Result[]", "name": "returnData", "type": "tuple[]"}],
    "stateMutability": "payable", "type": "function"}]
mc3 = w3.eth.contract(address=MC3, abi=MC3_ABI)

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "zombie/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["result"]

def getlogs(pool, topic):
    return rpc("eth_getLogs", [{"address": pool, "topics": [topic], "fromBlock": "0x1c9c380", "toBlock": "latest"}])

def topic_addr(t): return "0x" + t[-40:]
def topic_i24(t): return int.from_bytes(bytes.fromhex(t[2:]), "big", signed=True)
def words(data):
    d = data[2:] if data.startswith("0x") else data
    return [d[i:i+64] for i in range(0, len(d), 64)]
def key_of(owner, tl, tu):
    return ((int(owner, 16) << 48) | ((tl & 0xFFFFFF) << 24) | (tu & 0xFFFFFF)).to_bytes(32, "big")

def main():
    pool = sys.argv[1]
    outfile = sys.argv[2]
    block = w3.eth.block_number
    keys = {}
    for topic, tag in ((MINT, "mint"), (BURN, "burn")):
        for lg in getlogs(pool, topic):
            owner = topic_addr(lg["topics"][1]).lower()
            tl, tu = topic_i24(lg["topics"][2]), topic_i24(lg["topics"][3])
            w = words(lg["data"])
            liq = int(w[1], 16)
            k = key_of(owner, tl, tu)
            keys.setdefault(k, {"owner": owner, "tl": tl, "tu": tu, "mint": 0, "burn": 0})
            keys[k][tag] += liq
    kl = list(keys)
    calls = [(pool, "0x514ea4bf" + k.hex()) for k in kl]
    res = []
    for i in range(0, len(calls), 300):
        res.extend(mc3.functions.aggregate3([(Web3.to_checksum_address(t), True, d) for t, d in calls[i:i+300]]).call(block_identifier=block))
        time.sleep(0.05)
    byowner = {}
    for k, r in zip(kl, res):
        ok, data = r
        cur = {"liquidity": 0, "fees0": 0, "fees1": 0}
        if ok:
            if isinstance(data, bytes): data = "0x" + data.hex()
            w = words(data)
            cur = {"liquidity": int(w[0], 16), "fees0": int(w[4], 16), "fees1": int(w[5], 16)}
        v = keys[k]
        v["cur"] = cur
        a = byowner.setdefault(v["owner"], {"n": 0, "liq": 0, "fees0": 0, "fees1": 0, "ranges": []})
        a["n"] += 1; a["liq"] += cur["liquidity"]; a["fees0"] += cur["fees0"]; a["fees1"] += cur["fees1"]
        a["ranges"].append([v["tl"], v["tu"], cur["liquidity"]])
    json.dump({"pool": pool, "block": block, "byowner": byowner,
               "n_keys": len(keys), "total_cur_liq": sum(a["liq"] for a in byowner.values())},
              open(outfile, "w"))
    print(f"pool {pool} block {block}: {len(keys)} keys, {len(byowner)} owners, total liq {sum(a['liq'] for a in byowner.values())}")
    for o, a in sorted(byowner.items(), key=lambda x: -x[1]["liq"]):
        print(f"   {o} n={a['n']} cur_liq={a['liq']} fees0={a['fees0']} fees1={a['fees1']}")

if __name__ == "__main__":
    main()

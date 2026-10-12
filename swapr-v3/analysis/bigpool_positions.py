#!/usr/bin/env python3
"""Reconstruct the big pool's positions from events, read current state via multicall.

Pool: 0xa8be29b73c9752aeb3db3aa78f171861079685c7 (WETH/wstETH, Swapr V3 custom pool, tickSpacing=1)
Output: analysis/bigpool_positions.json
"""
import json, time
from web3 import Web3

RPC = "https://rpc.gnosischain.com"
MC3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
POOL = "0xa8be29b73c9752aeb3db3aa78f171861079685c7"

w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 60}))
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

def topic_addr(t): return "0x" + t[-40:]
def topic_i24(t): return int.from_bytes(bytes.fromhex(t[2:]), "big", signed=True)
def words(data):
    d = data[2:] if data.startswith("0x") else data
    return [d[i:i+64] for i in range(0, len(d), 64)]

def key_of(owner, tl, tu):
    return ((int(owner, 16) << 48) | ((tl & 0xFFFFFF) << 24) | (tu & 0xFFFFFF)).to_bytes(32, "big")

def main():
    block = w3.eth.block_number
    keys = {}
    for fn, tag in (("bigpool_mints.json", "mint"), ("bigpool_burns.json", "burn")):
        d = json.load(open(fn))
        for lg in d["result"]:
            owner = topic_addr(lg["topics"][1]).lower()
            tl = topic_i24(lg["topics"][2])
            tu = topic_i24(lg["topics"][3])
            w = words(lg["data"])
            sender = topic_addr(w[0]).lower()
            liq = int(w[1], 16)
            k = key_of(owner, tl, tu)
            keys.setdefault(k, {"owner": owner, "tl": tl, "tu": tu, "sender": sender, "mint_liq": 0, "burn_liq": 0})
            if tag == "mint":
                keys[k]["mint_liq"] += liq
            else:
                keys[k]["burn_liq"] += liq
    print("unique position keys:", len(keys), flush=True)
    kl = list(keys.keys())
    calls = [(POOL, "0x514ea4bf" + k.hex()) for k in kl]
    res = []
    for i in range(0, len(calls), 300):
        res.extend(mc3.functions.aggregate3([(Web3.to_checksum_address(t), True, d) for t, d in calls[i:i+300]]).call(block_identifier=block))
        time.sleep(0.05)
    for k, r in zip(kl, res):
        ok, data = r
        if not ok:
            keys[k]["cur"] = None
            continue
        if isinstance(data, bytes):
            data = "0x" + data.hex()
        w = words(data)
        keys[k]["cur"] = {
            "liquidity": int(w[0], 16),
            "lastAdd": int(w[1], 16),
            "fees0": int(w[4], 16),
            "fees1": int(w[5], 16),
        }
    out = {"block": block, "pool": POOL, "positions": [{"key": k.hex(), **v} for k, v in keys.items()]}
    json.dump(out, open("bigpool_positions.json", "w"))
    # aggregate by owner
    byowner = {}
    for k, v in keys.items():
        o = v["owner"]
        cur = v["cur"] or {"liquidity": 0, "fees0": 0, "fees1": 0}
        a = byowner.setdefault(o, {"n": 0, "liq": 0, "fees0": 0, "fees1": 0, "keys": []})
        a["n"] += 1
        a["liq"] += cur["liquidity"]
        a["fees0"] += cur["fees0"]
        a["fees1"] += cur["fees1"]
        a["keys"].append({"tl": v["tl"], "tu": v["tu"], "liq": cur["liquidity"]})
    print("\ncurrent liquidity by owner:")
    for o, a in sorted(byowner.items(), key=lambda x: -x[1]["liq"]):
        print(f"  {o} n={a['n']} cur_liq={a['liq']} fees0={a['fees0']} fees1={a['fees1']}")
    print("\ntotal current liquidity in reconstructed positions:", sum(a["liq"] for a in byowner.values()))
    print("pool.liquidity (in-range):", int(w3.eth.get_storage_at(POOL, 7).hex(), 16) if False else "")

if __name__ == "__main__":
    main()

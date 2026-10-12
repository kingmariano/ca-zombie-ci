#!/usr/bin/env python3
"""Enumerate all Swapr V3 NFPM positions exactly via tokenByIndex (handles burn gaps).

Output: analysis/nfpm_positions.json
"""
import json, time
from web3 import Web3

RPC = "https://rpc.gnosischain.com"
MC3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
NFPM = "0x91fD594c46D8B01E62dBDeBed2401dde01817834"

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
SEL_TOKENBYINDEX = "0x4f6ccce7"
SEL_OWNEROF = "0x6352211e"
SEL_POSITIONS = "0x99fbab88"

def u256(n): return hex(n)[2:].rjust(64, "0")

def run(calls, block):
    out = []
    for i in range(0, len(calls), 300):
        res = mc3.functions.aggregate3([(Web3.to_checksum_address(t), True, d) for t, d in calls[i:i+300]]).call(block_identifier=block)
        out.extend(res)
        time.sleep(0.05)
    return out

def main():
    block = w3.eth.block_number
    total = int.from_bytes(run([(NFPM, "0x18160ddd")], block)[0][1], "big")
    print("block:", block, "totalSupply:", total, flush=True)
    calls = [(NFPM, SEL_TOKENBYINDEX + u256(i)) for i in range(total)]
    res = run(calls, block)
    ids = [int.from_bytes(r[1], "big") for r in res if r[0]]
    print("live tokenIds:", len(ids), "max:", max(ids), flush=True)
    calls = []
    for i in ids:
        calls.append((NFPM, SEL_OWNEROF + u256(i)))
        calls.append((NFPM, SEL_POSITIONS + u256(i)))
    res = run(calls, block)
    positions = {}
    for k, i in enumerate(ids):
        own_ok, own = res[k*2]
        pos_ok, pos = res[k*2+1]
        if not own_ok or not pos_ok:
            continue
        owner = "0x" + own[-20:].hex()
        w = [pos[j:j+32] for j in range(0, len(pos), 32)]
        def addr(wd): return "0x" + wd[-20:].hex()
        positions[str(i)] = {
            "owner": owner, "operator": addr(w[1]),
            "t0": addr(w[2]), "t1": addr(w[3]),
            "tl": int.from_bytes(w[4], "big", signed=True),
            "tu": int.from_bytes(w[5], "big", signed=True),
            "liquidity": int.from_bytes(w[6], "big"),
            "owed0": int.from_bytes(w[9], "big"),
            "owed1": int.from_bytes(w[10], "big"),
        }
        if (k+1) % 1000 == 0: print("  ", k+1, flush=True)
    json.dump({"block": block, "total_supply": total, "n_existing": len(positions), "positions": positions},
              open("nfpm_positions.json", "w"))
    print("saved", len(positions), "positions")

if __name__ == "__main__":
    main()

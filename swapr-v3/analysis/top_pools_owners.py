#!/usr/bin/env python3
"""Reconstruct owners for the top-N pools and classify (EOA / contract)."""
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
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "z/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["result"]

def getlogs(pool, topic):
    return rpc("eth_getLogs", [{"address": pool, "topics": [topic], "fromBlock": "0x1c9c380", "toBlock": "latest"}])

def topic_addr(t): return "0x" + t[-40:]
def topic_i24(t): return int.from_bytes(bytes.fromhex(t[2:]), "big", signed=True)
def words(d):
    d = d[2:] if d.startswith("0x") else d
    return [d[i:i+64] for i in range(0, len(d), 64)]
def key_of(owner, tl, tu):
    return ((int(owner, 16) << 48) | ((tl & 0xFFFFFF) << 24) | (tu & 0xFFFFFF)).to_bytes(32, "big")

KNOWN = {
    "0x91fd594c46d8b01e62dbdebed2401dde01817834": "NFPM",
    "0xde51ddf1ae7d5bbd7bf1a0e40aaa1f6c12579106": "FarmingCenter",
    "0x216d3df2df6dec7c95d3b51f018ee4b11e416ebb": "Hypervisor(aWETH-wstETH)",
    "0x4476433bc06210ba265d95736ebc630544d397d9": "Hypervisor(aWETH-WXDAI)",
    "0x8f249cda053070fdb135d87e25a89dfbc8785f1d": "Hypervisor(asDAI-EURe)",
}

def main():
    priced = json.load(open("pools_priced.json"))
    top = [r for r in priced["rows"] if r["usd"] > 300][:40]
    out = {}
    owners_all = {}
    for r in top:
        pool = r["pool"]
        keys = {}
        for topic, tag in ((MINT, "mint"), (BURN, "burn")):
            try:
                lgs = getlogs(pool, topic)
            except Exception as e:
                print(pool, "log err", e); lgs = []
            for lg in lgs:
                owner = topic_addr(lg["topics"][1]).lower()
                tl, tu = topic_i24(lg["topics"][2]), topic_i24(lg["topics"][3])
                liq = int(words(lg["data"])[1], 16)
                k = key_of(owner, tl, tu)
                keys.setdefault(k, {"owner": owner, "mint": 0, "burn": 0})
                keys[k][tag] += liq
        kl = list(keys)
        res = []
        for i in range(0, len(kl), 300):
            res.extend(mc3.functions.aggregate3([(Web3.to_checksum_address(pool), True, "0x514ea4bf" + k.hex()) for k in kl[i:i+300]]).call(block_identifier=priced["block"]))
        by = {}
        for k, rr in zip(kl, res):
            ok, data = rr
            liq = 0
            if ok:
                if isinstance(data, bytes): data = "0x" + data.hex()
                liq = int(words(data)[0], 16)
            o = keys[k]["owner"]
            a = by.setdefault(o, {"n": 0, "liq": 0})
            a["n"] += 1; a["liq"] += liq
        out[pool] = {"usd": r["usd"], "owners": by}
        for o in by:
            owners_all.setdefault(o, 0)
            owners_all[o] += by[o]["liq"]
        print(f"{pool} ${r['usd']:.0f}: " + ", ".join(f"{o[:12]}({v['liq']})" for o, v in sorted(by.items(), key=lambda x: -x[1]['liq'])[:4]), flush=True)
    # classify unknown owners
    print("\n== unknown owners code check ==")
    for o, liq in sorted(owners_all.items(), key=lambda x: -x[1]):
        if o in KNOWN: continue
        code = rpc("eth_getCode", [o, "latest"])
        kind = "EOA" if code in ("0x", "0x0") else f"contract({len(code)//2} bytes)"
        print(f"  {o} liq={liq} {kind}")
    json.dump({"block": priced["block"], "pools": out}, open("top_pools_owners.json", "w"))

if __name__ == "__main__":
    main()

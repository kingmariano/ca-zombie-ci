#!/usr/bin/env python3
"""Read-only live state reader for Rift Finance vaults (Ethereum + Aurora).
Uses ONLY keyless public RPC endpoints. No secrets. No transactions.
Usage: python3 read_state.py ethereum|aurora <vault> [<vault> ...] > out.json
"""
import json, sys, urllib.request

RPCS = {"ethereum": "https://ethereum-rpc.publicnode.com",
        "aurora": "https://mainnet.aurora.dev"}

SEL = {
    "token0": "0x0dfe1681", "token1": "0xd21220a7", "pair": "0xa8aa1b31",
    "epoch": "0x900cf0cf", "epochDuration": "0x4ff0876a", "lastEpochStart": "0xd5bf91e3",
    "depositsEnabled": "0x5392fd1c", "paused": "0x5c975abb", "core": "0xf2f4eb26",
    "token0Data": "0xac896951", "token1Data": "0x930f7ee8", "isNativeVault": "0xa21b927f",
    "token0FloorNum": "0x41213a17", "token1FloorNum": "0xc2306acb",
    "token0ValueLocked": "0xef253eb6", "token1ValueLocked": "0x037a354c",
    "rewarder": "0xdcc3e06e", "pid": "0xf1068454", "feesAccrued": "0x94db0595",
    "whitelistDisabled": "0x1c8e8568",
    "impl_slot": "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
    "admin_slot": "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
}
# balanceOf(address) / allowance / userInfo(uint256,address)
BAL = "0x70a08231"

def batch(url, calls, chunk=25):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc":"2.0","id":j,"method":"eth_call","params":[{"to":t,"data":d},"latest"]}
                   for j,(t,d) in enumerate(part)]
        req = urllib.request.Request(url, json.dumps(payload).encode(),
                                     headers={"Content-Type":"application/json","User-Agent":"rift-research"})
        with urllib.request.urlopen(req, timeout=180) as r:
            res = json.loads(r.read())
        m = {x["id"]: x for x in res}
        for j in range(len(part)):
            x = m.get(j, {})
            out.append(x.get("result") if "result" in x else "ERR:" + json.dumps(x.get("error"))[:100])
    return out

def num(hexs):
    try: return int(hexs, 16)
    except Exception: return None

def addr(hexs):
    try: return "0x" + hexs[-40:]
    except Exception: return None

def main():
    chain = sys.argv[1]
    vaults = sys.argv[2:]
    url = RPCS[chain]
    bn = int(json.loads(urllib.request.urlopen(urllib.request.Request(
        url, json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(),
        headers={"Content-Type":"application/json","User-Agent":"rift-research"}), timeout=60).read())["result"], 16)
    result = {"chain": chain, "block": bn, "vaults": {}}
    for v in vaults:
        calls = [(v, SEL[k]) for k in ["token0","token1","pair","epoch","epochDuration","lastEpochStart",
                                       "depositsEnabled","paused","core","token0Data","token1Data",
                                       "isNativeVault","token0FloorNum","token1FloorNum",
                                       "token0ValueLocked","token1ValueLocked","feesAccrued",
                                       "impl_slot","admin_slot"]]
        res = batch(url, calls)
        d = dict(zip(["token0","token1","pair","epoch","epochDuration","lastEpochStart",
                      "depositsEnabled","paused","core","token0Data","token1Data",
                      "isNativeVault","token0FloorNum","token1FloorNum",
                      "token0ValueLocked","token1ValueLocked","feesAccrued",
                      "impl_slot","admin_slot"], res))
        out = {
            "token0": addr(d["token0"]), "token1": addr(d["token1"]), "pair": addr(d["pair"]),
            "epoch": num(d["epoch"]), "epochDuration": num(d["epochDuration"]),
            "lastEpochStart": num(d["lastEpochStart"]),
            "depositsEnabled": (d["depositsEnabled"][-1] == "1") if d["depositsEnabled"].startswith("0x") else d["depositsEnabled"],
            "paused": (d["paused"][-1] == "1") if d["paused"].startswith("0x") else d["paused"],
            "core": addr(d["core"]), "impl": addr(d["impl_slot"]), "admin": addr(d["admin_slot"]),
            "isNativeVault": (d["isNativeVault"][-1] == "1") if d["isNativeVault"].startswith("0x") else d["isNativeVault"],
            "token0FloorNum": num(d["token0FloorNum"]), "token1FloorNum": num(d["token1FloorNum"]),
            "token0ValueLocked": num(d["token0ValueLocked"]), "token1ValueLocked": num(d["token1ValueLocked"]),
            "feesAccrued": [num(d["feesAccrued"][2+i*64:2+(i+1)*64]) if d["feesAccrued"].startswith("0x") else None for i in range(2)],
        }
        if d["token0Data"].startswith("0x"):
            w = [num(d["token0Data"][2+i*64:2+(i+1)*64]) for i in range(5)]
            out["token0Data"] = {"reserves": w[0], "active": w[1], "depositRequestsTotal": w[2],
                                 "withdrawRequestsTotal": w[3], "claimableTotal": w[4]}
        if d["token1Data"].startswith("0x"):
            w = [num(d["token1Data"][2+i*64:2+(i+1)*64]) for i in range(5)]
            out["token1Data"] = {"reserves": w[0], "active": w[1], "depositRequestsTotal": w[2],
                                 "withdrawRequestsTotal": w[3], "claimableTotal": w[4]}
        # balances
        if out["token0"] and out["token1"]:
            bal_calls = []
            for tok in [out["token0"], out["token1"]]:
                bal_calls.append((tok, BAL + "0"*24 + v[2:]))
            if out["pair"] and out["pair"] != "0x" + "0"*40:
                bal_calls.append((out["pair"], BAL + "0"*24 + v[2:]))
            bres = batch(url, bal_calls)
            out["vaultBalanceToken0"] = num(bres[0]); out["vaultBalanceToken1"] = num(bres[1])
            if len(bres) > 2: out["vaultBalanceLP"] = num(bres[2])
        result["vaults"][v] = out
    print(json.dumps(result, indent=1))

if __name__ == "__main__":
    main()

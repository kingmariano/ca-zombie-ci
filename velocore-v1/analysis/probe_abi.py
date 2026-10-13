#!/usr/bin/env python3
"""Probe the live Velocore V1 pool ABI surface (zkSync Era)."""
import json, urllib.request

RPC = "https://mainnet.era.zksync.io"
P = "0xcd52cbc975fbb802f82a1f92112b1250b5a997df"
FROM = "0x0000000000000000000000000000000000000001"

# (signature, encoded args after selector) -- only fixed-size args here
probes = {
    "factory()": "",
    "fees()": "",
    "voter()": "",
    "tokens()": "",
    "observationLength()": "",
    "lastObservation()": "",
    "MINIMUM_LIQUIDITY()": "",
    "reserve0()": "",
    "reserve1()": "",
    "blockTimestampLast()": "",
    "price0CumulativeLast()": "",
    "price1CumulativeLast()": "",
    "index0()": "",
    "index1()": "",
    "supplyIndex0(address)": "0"*24+"1"*40,
    "supplyIndex1(address)": "0"*24+"1"*40,
    "claimable0(address)": "0"*24+"1"*40,
    "claimable1(address)": "0"*24+"1"*40,
    "nonces(address)": "0"*24+"1"*40,
    "balanceOf(address)": "0"*24+"1"*40,
    "allowance(address,address)": "0"*24+"1"*40+"0"*24+"1"*40,
    "claimFees()": "",
    "claimFeesFor(address)": "0"*24+"1"*40,
    "getAmountOut(uint256,address)": "0"*63+"1"+"0"*24+"1"*40,
    "current(address,uint256)": "0"*24+"1"*40+"0"*63+"1",
    "quote(address,uint256,uint256)": "0"*24+"1"*40+"0"*63+"1"+"0"*63+"1",
    "sample(address,uint256,uint256,uint256)": "0"*24+"1"*40+"0"*63+"1"+"0"*63+"1"+"0"*63+"1",
    "prices(address,uint256,uint256)": "0"*24+"1"*40+"0"*63+"1"+"0"*63+"1",
    "isStable()": "",
    "stable()": "",
    "decimals()": "",
    "token0()": "",
    "token1()": "",
    "sync()": "",
    "getReserves()": "",
    "metadata()": "",
    "currentCumulativePrices()": "",
    "lastWithdrawTimestamp()": "",
    "fee1e9()": "",
    "feeMultiplier()": "",
    "poolType()": "",
    "gauge()": "",
    "voterAddress()": "",
    "version()": "",
    "hook(address,uint256,uint256,bytes)": "0"*24+"1"*40+"0"*63+"1"+"0"*63+"1"+"0"*63+"20",
    "claimFees(address)": "0"*24+"1"*40,
    "withdrawFee()": "",
    "swapFee()": "",
}

import subprocess
def selector(sig):
    return subprocess.run(["cast","sig",sig],capture_output=True,text=True).stdout.strip()

def call(data):
    payload={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"from":FROM,"to":P,"data":data},"latest"]}
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            d=json.loads(r.read())
        if "result" in d: return ("OK", d["result"][:80])
        return ("REVERT", d.get("error",{}).get("data","")[:40] if isinstance(d.get("error"),dict) else str(d.get("error"))[:60])
    except Exception as e:
        return ("ERR", str(e)[:60])

for sig, args in probes.items():
    sel = selector(sig)
    st, res = call(sel+args)
    print(f"{sig:44} {sel} {st:7} {res}")

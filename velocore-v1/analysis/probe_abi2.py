#!/usr/bin/env python3
"""Probe more selectors on the live pool to pin down the codebase."""
import json, urllib.request, subprocess

RPC = "https://mainnet.era.zksync.io"
P = "0xcd52cbc975fbb802f82a1f92112b1250b5a997df"
FROM = "0x0000000000000000000000000000000000000001"
probes = {
    "observations(uint256)": "0"*63+"0",
    "periodSize()": "",
    "reserve0CumulativeLast()": "",
    "reserve1CumulativeLast()": "",
    "poolFees()": "",
    "getK()": "",
    "initialize(address,address,bool)": "0"*24+"1"*40+"0"*24+"1"*40+"0"*63+"1",
    "setName(string)": "0"*63+"20"+"0"*63+"0",
    "setSymbol(string)": "0"*63+"20"+"0"*63+"0",
    "isForPair()": "",
    "name()": "",
    "symbol()": "",
    "lastObservation()": "",
    "observationLength()": "",
    "tokens()": "",
    "metadata()": "",
    "voter()": "",
    "factory()": "",
    "fees()": "",
    "gauges(address)": "0"*24+"1"*40,
    "gauge()": "",
    "index0()": "",
    "claimable0(address)": "0"*24+"1"*40,
    "poolType()": "",
    "token0()": "",
    "token1()": "",
    "stable()": "",
    "reserve0()": "",
    "reserve1()": "",
    "blockTimestampLast()": "",
    "skim(address)": "0"*24+"1"*40,
    "sync()": "",
    "mint(address)": "0"*24+"1"*40,
    "burn(address)": "0"*24+"1"*40,
    "swap(uint256,uint256,address,bytes)": "0"*63+"0"+"0"*63+"0"+"0"*24+"1"*40+"0"*63+"80"+"0"*63+"0",
    "claimFees()": "",
    "claimFeesFor(address)": "0"*24+"1"*40,
    "currentCumulativePrices()": "",
    "getReserves()": "",
    "decimals()": "",
    "totalSupply()": "",
    "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)": "0"*24+"1"*40+"0"*24+"1"*40+"0"*63+"1"+"0"*63+"1"+"0"*63+"1"+"0"*63+"1"+"0"*63+"1",
    "nonces(address)": "0"*24+"1"*40,
    "DOMAIN_SEPARATOR()": "",
}
def selector(sig):
    return subprocess.run(["cast","sig",sig],capture_output=True,text=True).stdout.strip()
def call(data):
    payload={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"from":FROM,"to":P,"data":data},"latest"]}
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            d=json.loads(r.read())
        if "result" in d: return ("OK", d["result"][:70])
        e=d.get("error",{})
        return ("REVERT", str(e.get("data") or e.get("message",""))[:50])
    except Exception as e:
        return ("ERR", str(e)[:50])
for sig,args in probes.items():
    st,res = call(selector(sig)+args)
    print(f"{sig:46} {st:7} {res}")

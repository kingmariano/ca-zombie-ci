#!/usr/bin/env python3
"""Batch JSON-RPC helper for read-only mainnet reads. KIT rules: public RPCs only."""
import json, sys, urllib.request, time

RPCS = ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth"]
UA = "Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0"

def rpc_batch(calls, rpc=None):
    """calls: list of (method, params). Returns list of results (or {'error':...})."""
    payload = [{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
    data = json.dumps(payload).encode()
    last = None
    for url in ([rpc] if rpc else RPCS):
        try:
            req = urllib.request.Request(url, data=data, headers={"Content-Type":"application/json","User-Agent":UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read().decode())
            res = [None]*len(calls)
            for item in out:
                res[item["id"]] = item.get("result", item.get("error"))
            if all(x is not None for x in res):
                return res
            last = out
        except Exception as e:
            last = str(e)
            time.sleep(0.5)
    raise RuntimeError(f"rpc batch failed: {last}")

def one(method, params, rpc=None):
    return rpc_batch([(method,params)], rpc)[0]

def block_number():
    return int(one("eth_blockNumber",[]),16)

def balances(addrs, block="latest"):
    res = rpc_batch([("eth_getBalance",[a,block]) for a in addrs])
    return {a: int(v,16)/1e18 if isinstance(v,str) else v for a,v in zip(addrs,res)}

def codes(addrs, block="latest"):
    res = rpc_batch([("eth_getCode",[a,block]) for a in addrs])
    return {a: v for a,v in zip(addrs,res)}

def calls(callobjs, block="latest"):
    """callobjs: list of dicts {to,data,from?}. Returns results."""
    params=[]
    for c in callobjs:
        p={"to":c["to"],"data":c.get("data","0x")}
        if c.get("from"): p["from"]=c["from"]
        if c.get("value"): p["value"]=c["value"]
        if c.get("gas"): p["gas"]=c["gas"]
        params.append(p)
    return rpc_batch([("eth_call",[p,block]) for p in params])

def get_storage(addrs, slot, block="latest"):
    res = rpc_batch([("eth_getStorageAt",[a,hex(slot),block]) for a in addrs])
    return res

def sel(sig):
    # keccak selector via cast
    import subprocess
    return subprocess.check_output(["cast","sig",sig]).decode().strip()[:10]

#!/usr/bin/env python3
"""Fetch factory PairCreated events -> pair creation timeline (block/timestamp) per class."""
import json, urllib.request, os, time

ENDPOINTS = ["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(HERE, "..", "analysis")
FACTORY = "0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e"

def rpc(method, params, timeout=60, retries=5):
    last=None
    for i in range(retries):
        url=ENDPOINTS[i%len(ENDPOINTS)]
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req,timeout=timeout) as r: out=json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last=out
        except Exception as e: last=repr(e)
        time.sleep(0.5)
    raise RuntimeError(str(last))

def main():
    # try selector for PairCreated
    import subprocess
    h = subprocess.run(["cast","keccak","PairCreated"],capture_output=True,text=True).stdout.strip()
    sel = hex(int(h,16) & ((1<<250)-1))
    print("PairCreated selector:", sel)
    events=[]
    token=None
    flt={"from_block":{"block_number":0},"to_block":"latest","address":FACTORY,"keys":[[sel]]}
    while True:
        params={"filter":flt,"chunk_size":1000}
        if token: params["continuation_token"]=token
        res=rpc("starknet_getEvents",[params])
        ev=res.get("events",[]); events+=ev
        token=res.get("continuation_token")
        print("  got",len(ev),"total",len(events))
        if not token or not ev: break
    print("total PairCreated events:",len(events))
    # fetch block timestamps (cache)
    blocks=sorted({int(e["block_number"]) for e in events})
    ts={}
    for i,b in enumerate(blocks):
        r=rpc("starknet_getBlockWithTxHashes",[{"block_number":b}])
        ts[b]=r.get("timestamp")
        if (i+1)%25==0: print("  ts",i+1,"/",len(blocks))
    out=[]
    for e in events:
        b=int(e["block_number"])
        out.append({"pair":e["data"][0] if e["data"] else None,"keys":e["keys"],"block":b,"ts":ts[b]})
    with open(os.path.join(OUT,"pair_created_events.json"),"w") as fh: json.dump(out,fh,indent=1)
    import datetime
    for r in out[:5]+out[-5:]:
        print(r["pair"], r["block"], datetime.datetime.utcfromtimestamp(r["ts"]).isoformat())

if __name__=="__main__":
    main()

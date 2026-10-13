#!/usr/bin/env python3
"""Complete adaptive getLogs walker: split on BOTH 'exceeds max results' and 'range too large'."""
import json, urllib.request, os, time, sys

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"
TRANSFER="0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

def rpc(m,p,tries=5):
    for i in range(tries):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            return json.load(urllib.request.urlopen(req,timeout=90))
        except Exception as e:
            if i==tries-1: return {"error":{"message":str(e)[:100]}}
            time.sleep(2+2*i)

def getlogs(addr, frm, to):
    r=rpc("eth_getLogs",[{"address":addr,"topics":[TRANSFER],"fromBlock":hex(frm),"toBlock":hex(to)}])
    if "error" in r: return None, json.dumps(r["error"])
    return r.get("result") or [], None

def walk(addr, lo, hi):
    out=[]
    stack=[(lo,hi)]
    calls=0; splits=0
    while stack:
        a,b=stack.pop()
        if b<a: continue
        logs,err=getlogs(addr,a,b)
        calls+=1
        if err is not None:
            if b-a>0:
                mid=(a+b)//2
                stack.append((mid+1,b)); stack.append((a,mid)); splits+=1
            else:
                sys.stderr.write(f"PERMANENT err {a}-{b}: {err[:100]}\n")
            continue
        out.extend(logs)
        if calls%50==0:
            print(f"  ...{len(out)} logs, {calls} calls, {splits} splits, queue {len(stack)}",file=sys.stderr)
    return out

def first_code_block(t):
    latest=int(rpc("eth_blockNumber",[])["result"],16)
    lo,hi=1,latest
    while lo<hi-1:
        mid=(lo+hi)//2
        c=rpc("eth_getCode",[t,hex(mid)])["result"]
        if c and c!="0x": hi=mid
        else: lo=mid
    return hi

def main():
    tokens={"LP3":"0xf2511b5e4fb0e5e2d123004b672ba14850478c14",
            "BTCLP":"0xd1d5af92c606c6f2ec59d453f57a6fcc188d7db5",
            "ETHLP":"0x0d283bf16a9bde49cfc48d8dc050af28b71bdd90"}
    allh={}
    for name,t in tokens.items():
        start=first_code_block(t)
        latest=int(rpc("eth_blockNumber",[])["result"],16)
        print(f"{name} start={start} latest={latest}")
        logs=walk(t,start-1,latest)
        addrs=sorted({"0x"+tp[26:] for l in logs for tp in l["topics"][1:3]})
        allh[name]=addrs
        print(f"{name}: {len(logs)} transfers, {len(addrs)} unique addrs")
    with open("/home/heisenberg/CA/nerve-qc/analysis/lp_transfer_addrs.json","w") as f:
        json.dump(allh,f,indent=2)
    print("saved")

if __name__=="__main__": main()

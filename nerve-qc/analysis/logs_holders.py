#!/usr/bin/env python3
"""Adaptive eth_getLogs walker (Ankr 10k cap) to enumerate all Transfer
counterparties of the Nerve base LP tokens => complete holder sweep."""
import json, urllib.request, os, time, sys

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"
TRANSFER="0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

def rpc(m,p,tries=4):
    for i in range(tries):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            return json.load(urllib.request.urlopen(req,timeout=90))
        except Exception as e:
            if i==tries-1: raise
            time.sleep(2+2*i)

def getlogs(addr, frm, to):
    r=rpc("eth_getLogs",[{"address":addr,"topics":[TRANSFER],"fromBlock":hex(frm),"toBlock":hex(to)}])
    if "error" in r: return None, r["error"]
    return r.get("result") or [], None

def walk(addr, lo, hi):
    """Collect all logs in [lo,hi]; bisect on the 10k cap."""
    out=[]
    stack=[(lo,hi)]
    calls=0
    while stack:
        a,b=stack.pop()
        logs,err=getlogs(addr,a,b)
        calls+=1
        if err is not None:
            msg=json.dumps(err)
            if "exceeds max results" in msg and b-a>0:
                mid=(a+b)//2
                stack.append((mid+1,b)); stack.append((a,mid))
            else:
                sys.stderr.write(f"err range {a}-{b}: {msg[:120]}\n")
            continue
        out.extend(logs)
        if calls%20==0: print(f"  ... {len(out)} logs, {calls} calls, queue {len(stack)}", file=sys.stderr)
    return out

def main():
    tokens={
      "LP3":"0xf2511b5e4fb0e5e2d123004b672ba14850478c14",
      "BTCLP":"0xd1d5af92c606c6f2ec59d453f57a6fcc188d7db5",
      "ETHLP":"0x0d283bf16a9bde49cfc48d8dc050af28b71bdd90",
    }
    allh={}
    for name,t in tokens.items():
        # find first block with code
        lo,hi=1,int(rpc("eth_blockNumber",[])["result"],16)
        if rpc("eth_getCode",[t,"latest"])["result"] in (None,"0x"):
            print(name,"no code"); continue
        while lo<hi-1:
            mid=(lo+hi)//2
            c=rpc("eth_getCode",[t,hex(mid)])["result"]
            if c and c!="0x": hi=mid
            else: lo=mid
        print(f"{name} first code block={hi}")
        logs=walk(t,hi-1,int(rpc("eth_blockNumber",[])["result"],16))
        addrs=set()
        for l in logs:
            for tp in l["topics"][1:3]:
                addrs.add("0x"+tp[26:])
        allh[name]=sorted(addrs)
        print(f"{name}: {len(logs)} transfers, {len(addrs)} unique addresses")
    with open("/home/heisenberg/CA/nerve-qc/analysis/lp_transfer_addrs.json","w") as f:
        json.dump(allh,f,indent=2)
    print("saved")

if __name__=="__main__":
    main()

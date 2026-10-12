#!/usr/bin/env python3
"""Probe lengths of V1 stakedUserAddresses and the repo userAddresses arrays (binary search)."""
import json, urllib.request, time
RPC="https://polygon-bor-rpc.publicnode.com"
UA={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"}
def batch(calls):
    out=[]
    for i in range(0,len(calls),10):
        chunk=calls[i:i+10]
        payload=[{"jsonrpc":"2.0","id":j,"method":m,"params":p} for j,(m,p) in enumerate(chunk)]
        req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),headers=UA)
        for a in range(5):
            try: resp=json.loads(urllib.request.urlopen(req,timeout=40).read()); break
            except Exception:
                if a==4: raise
                time.sleep(1.5*(a+1))
        by={r["id"]:r for r in resp}
        for j in range(len(chunk)):
            r=by.get(j,{}); out.append(r.get("result",{"error":r.get("error")}))
    return out
def sel(sig=None, s=None): return s
def pad(x): return hex(x)[2:].rjust(64,"0")
def length_of(addr, selector, lo=0, hi=20000):
    def exists(i):
        r=batch([("eth_call",[{"to":addr,"data":selector+pad(i)},"latest"])])[0]
        return isinstance(r,str)
    if not exists(0): return 0
    while lo+1<hi:
        mid=(lo+hi)//2
        if exists(mid): lo=mid
        else: hi=mid
    return hi
V1="0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61bc2B2"
REPO="0x8709278f89D6fB589f1188F6b415d3eDEe88a2F6"
print("V1 stakedUserAddresses len:", length_of(V1,"0x7fd77137"))
print("REPO userAddresses len (probe)

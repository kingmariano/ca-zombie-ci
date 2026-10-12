#!/usr/bin/env python3
"""Probe candidate addresses for per-contract lastCollectedPeriod + unclaimed dividends."""
import json, urllib.request, time, sys
RPC="https://polygon-bor-rpc.publicnode.com"
UA={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"}
SEL_U="0xa87430ba"   # users(address)
SEL_C="0x8fc91480"   # calculateUnclaimedDividends(address)
CONTRACTS={
 "SB0":"0xf6380D9b4CC3a0a180d5f1D78e3b7a33ec3048E3",
 "SB1":"0x9E8eE4F17F17371d53e2fB19BDDE7a084215bb0E",
 "SB17":"0x070aEf7a90bD7B4B3b43355C81c56011D5B2A238",
 "SB18":"0x33c3834262903d6bCecB0Ba936fc65CAa4d11B26",
}
CANDIDATES=[
 "0x16f548b6f256a6ef6cc21941ab2404045dc53cf2","0x83b566c00f8a96c86a2be5091f52fd7deb8192c5",
 "0x2a9651856cc66865f035d0bdb4161d76e0003300","0xbe958864291682f6fb1884455722bd483fa33c26",
 "0x0e3284c5f7687a12015d7fb9b98d8cf3c0859643","0x2d0c7f2e4475ad0a3df13c47f2992e995bf9364f",
 "0x43de4cdccbb1252ef9ab5203d2c10be8d280d024","0x5ffd31dccd9098ad711eb6d19fc20a640d7ad7ee",
 "0xc42a8abebea0d36775f4d274e0cb87e160e02945","0x288c58e824834c9648aab8b4308b8f13dc35c1dc",
 "0x2a46208a3c6b50d86e8dc093993631dfe92e6198","0x3202e721a97f921fc0a32920d0723ed97e9f50e2",
 "0x923f39b6ae8a01dd42613b592f629444caf1d8ba","0xd97d2fe146369e69755aa9090f0e74030a0a0789",
 "0xd940633d48c756a2d28b63bea4fb7366da0ce9b9","0xc645aa326b10429661e2110d3cccca2d45ce93c2",
 "0xa5fb64aa7116c2abc66595f6a40a5c537371a67d","0x49f45912358aead6dcaa463bfac5f96a0856646b",
 "0x1db484e63645258e79e29e373283bdfa173f08bd","0xe01c132c5f89f11167c8133cac313f6b9f87bb0".replace("67c","67C") if False else "0xe01c132c5f89f111c67c8133cac313f6b9f87bb0",
]
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
def enc(a): return a.lower().replace("0x","").rjust(64,"0")
out={}
for name,addr in CONTRACTS.items():
    calls=[("eth_call",[{"to":addr,"data":SEL_U+enc(c)},"latest"]) for c in CANDIDATES]
    calls+=[("eth_call",[{"to":addr,"data":SEL_C+enc(c)},"latest"]) for c in CANDIDATES]
    res=batch(calls)
    rows=[]
    for i,c in enumerate(CANDIDATES):
        lec=int(res[i],16) if isinstance(res[i],str) else None
        unc=int(res[i+len(CANDIDATES)],16) if isinstance(res[i+len(CANDIDATES)],str) else None
        if lec is not None and (unc or 0)>0:
            rows.append({"addr":c,"lastCollectedPeriod":lec,"unclaimed_usdc":unc/1e6})
    rows.sort(key=lambda r:r["unclaimed_usdc"])
    out[name]=rows
    print("==",name)
    for r in rows[:10]: print("  ", r["addr"], "lec",r["lastCollectedPeriod"],"unclaimed",r["unclaimed_usdc"])
json.dump(out,open("sb_candidates.json","w"),indent=1)

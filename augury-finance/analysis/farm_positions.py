#!/usr/bin/env python3
"""Check MasterAugur userInfo for candidate addresses across all 19 pools."""
import json, urllib.request, time
RPC="https://polygon-bor-rpc.publicnode.com"
UA={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"}
M="0x6ad70613d14c34aa69e1604af91c39e0591a132e"
SEL_UI="0x93f1a40b"  # userInfo(uint256,address)
CANDS=[
 "0x923f39b6ae8a01dd42613b592f629444caf1d8ba",
 "0xbe958864291682f6fb1884455722bd483fa33c26",
 "0x83b566c00f8a96c86a2be5091f52fd7deb8192c5",
 "0x16f548b6f256a6ef6cc21941ab2404045dc53cf2",
 "0x2a9651856cc66865f035d0bdb4161d76e0003300",
 "0x1db484e63645258e79e29e373283bdfa173f08bd",
 "0xd97d2fe146369e69755aa9090f0e74030a0a0789",
 "0x288c58e824834c9648aab8b4308b8f13dc35c1dc",
 "0x2d0c7f2e4475ad0a3df13c47f2992e995bf9364f",
 "0xd940633d48c756a2d28b63bea4fb7366da0ce9b9",
 "0xc645aa326b10429661e2110d3cccca2d45ce93c2",
 "0xa5fb64aa7116c2abc66595f6a40a5c537371a67d",
 "0x49f45912358aead6dcaa463bfac5f96a0856646b",
 "0x0e3284c5f7687a12015d7fb9b98d8cf3c0859643",
 "0x29965a1174645714c64f400cd54b6c0a5bbc1cb7",
 "0xe2e26bac2ff37a7ae219ecef74c5a1bf95d5f854",
 "0x57831e532fc14846511d3b8a86aa692528e06a9a",
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
def enc_u(i): return hex(i)[2:].rjust(64,"0")
def enc_a(a): return a.lower().replace("0x","").rjust(64,"0")
found={}
calls=[]
for c in CANDS:
    for pid in range(19):
        calls.append(("eth_call",[{"to":M,"data":SEL_UI+enc_u(pid)+enc_a(c)},"latest"]))
res=batch(calls)
k=0
for c in CANDS:
    for pid in range(19):
        r=res[k]; k+=1
        if isinstance(r,str) and len(r)>=2+128:
            amount=int(r[2:66],16)
            if amount>0:
                found.setdefault(c,{})[pid]=amount
print(json.dumps({c:{str(p):str(a) for p,a in d.items()} for c,d in found.items()}, indent=1))
json.dump(found, open("farm_live_positions.json","w"), indent=1)

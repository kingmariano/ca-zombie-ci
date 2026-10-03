#!/usr/bin/env python3
import json, time, urllib.request
POOL=["https://rpcapi.fantom.network","https://fantom.api.onfinality.io/public","https://fantom.drpc.org"]
i=[0]
def post(payload):
    last=None
    for a in range(9):
        url=POOL[i[0]%len(POOL)]
        req=urllib.request.Request(url,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
        try: return json.loads(urllib.request.urlopen(req,timeout=40).read())
        except Exception as e:
            last=e; i[0]+=1; time.sleep(0.8+a*0.4)
    raise last
def call(to,sel,arg=None):
    data=sel+(arg[2:].lower().rjust(64,"0") if arg else "")
    r=post({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]})
    return r.get("result")
def fw(r): return int(r[2:66],16) if isinstance(r,str) and len(r)>=66 else None
M="0x2359012ebe36cca231203d78b914284947b58aa3"
acts=json.load(open("sclink_actors.json"))
cands=[h["addr"] for h in acts["holders"]]
# add borrowers
cands+= [b["addr"] for b in acts["borrowers"]]
cands=sorted(set(cands))
out={}
for a in cands:
    b=fw(call(M,"0x70a08231",a))
    out[a]=b
nz={a:b for a,b in out.items() if b}
print("candidates:",len(cands),"nonzero:",len(nz),"sum ctokens:",sum(nz.values())/1e8)
for a,b in sorted(nz.items(),key=lambda kv:-kv[1])[:40]:
    print(f"{a} {b/1e8:.4f}")
json.dump(out,open("sclink_balances.json","w"),indent=2)

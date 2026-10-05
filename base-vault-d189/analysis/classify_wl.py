import json, os, urllib.request, time, sys
SIB="0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23"
eps=[("https://base.drpc.org",{"X-API-Key":os.environ["DRPC_API_KEY"]}),("https://base-rpc.publicnode.com",{}),("https://mainnet.base.org",{})]
def rpc(method,params):
    last=None
    for url,h in eps:
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0",**h})
            r=json.load(urllib.request.urlopen(req,timeout=12))
            if "result" in r: return r["result"]
            last=r.get("error")
        except Exception as e: last=e
    return None
IMPL="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
wl=json.load(open("sibling_wl_current.json"))
ones=sorted(a for a,v in wl.items() if v["sib"]==1)
out={}
for i,a in enumerate(ones):
    code=rpc("eth_getCode",[a,"latest"])
    if code is None: out[a]={"error":True}; continue
    if code=="0x":
        out[a]={"type":"EOA"}
    else:
        impl=rpc("eth_getStorageAt",[a,IMPL,"latest"])
        im="0x"+impl[-40:] if impl else "?"
        out[a]={"type":"contract","len":len(code)//2-1,"impl":im}
    if i%20==0: print("..",i,flush=True)
json.dump(out, open("sibling_wl_class.json","w"), indent=1)
from collections import Counter
c=Counter(v.get("impl") for v in out.values() if v.get("type")=="contract")
print("EOAs:", sum(1 for v in out.values() if v.get("type")=="EOA"))
print("impls:", c.most_common())
print("\nEOA list:")
for a,v in out.items():
    if v.get("type")=="EOA": print("  ",a)

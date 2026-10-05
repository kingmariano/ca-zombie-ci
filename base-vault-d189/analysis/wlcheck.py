import json, os, urllib.request, time, sys
SIB="0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23"; V="0xD1895f2019c2152FC2b9022D57f19198c4CFCABC"
eps=[("https://base.drpc.org",{"X-API-Key":os.environ["DRPC_API_KEY"]}),("https://base-rpc.publicnode.com",{}),("https://mainnet.base.org",{})]
def call(to,data):
    last=None
    for url,h in eps:
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}).encode(),
                headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0",**h})
            r=json.load(urllib.request.urlopen(req,timeout=12))
            if "result" in r: return int(r["result"],16)
            last=r.get("error")
        except Exception as e: last=e
    return ("ERR",str(last)[:30])
def pads(a): return "0"*24+a[2:]
targets=json.load(open(sys.argv[1]))
out={}
for i,a in enumerate(targets):
    ws=call(SIB,"0x9b19251a"+pads(a)); wv=call(V,"0x9b19251a"+pads(a))
    out[a]={"sib":ws,"vault":wv}
    if i%25==0: print("..",i,flush=True)
json.dump(out, open(sys.argv[2],"w"), indent=1)
ones=[a for a,v in out.items() if v["sib"]==1]
print("sib whitelisted:",len(ones))
for a in sorted(ones): print("  ",a,"vaultWL",out[a]["vault"])
errs=[a for a,v in out.items() if not isinstance(v["sib"],int)]
print("errors:",errs[:5])

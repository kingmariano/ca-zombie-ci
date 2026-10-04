import json, urllib.request, time, subprocess
URL="https://rpc.grxchain.io"
_sel={}
def sel(sig):
    if sig not in _sel: _sel[sig]=subprocess.check_output(["cast","sig",sig]).decode().strip()
    return _sel[sig]
def pad(a): return a.lower().replace("0x","").rjust(64,"0")
def batch(items):
    reqs=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(items)]
    out={}
    for j in range(0,len(reqs),10):
        ch=reqs[j:j+10]
        r=urllib.request.Request(URL,data=json.dumps(ch).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        for a in range(3):
            try: resp=json.load(urllib.request.urlopen(r,timeout=90)); break
            except Exception as e: time.sleep(2)
        for x in resp: out[x["id"]]=x.get("result") or str(x.get("error"))
    return out
F2="0x9b4876befc20d1d209852ca9ea83fe36733818c4"
items=[("eth_getCode",[F2,"latest"])]
labels=["code"]
items.append(("eth_call",[{"to":F2,"data":sel("allPairsLength()")},"latest"])); labels.append("len")
items.append(("eth_call",[{"to":F2,"data":sel("feeTo()")},"latest"])); labels.append("feeTo")
items.append(("eth_call",[{"to":F2,"data":sel("feeToSetter()")},"latest"])); labels.append("feeToSetter")
out=batch(items)
res={labels[i]:v for i,v in out.items()}
print("code len:",(len(res["code"])-2)//2)
n=int(res["len"],16) if res["len"] and res["len"].startswith("0x") else 0
print("allPairsLength:",n,"feeTo:",res["feeTo"],"feeToSetter:",res["feeToSetter"])
# enumerate pairs
items=[];labels=[]
for i in range(n):
    items.append(("eth_call",[{"to":F2,"data":sel("allPairs(uint256)")+hex(i)[2:].rjust(64,"0")},"latest"])); labels.append(f"pair{i}")
out=batch(items)
pairs=[out[i] for i in range(n)]
print("pairs:",pairs)
# for each pair get token0/token1/getReserves/totalSupply
items=[];labels=[]
for i,p in enumerate(pairs):
    pa="0x"+p[-40:]
    for fn in ["token0()","token1()","getReserves()","totalSupply()"]:
        items.append(("eth_call",[{"to":pa,"data":sel(fn)},"latest"])); labels.append(f"p{i}.{fn}")
out=batch(items)
for i,v in out.items(): print(labels[i],"=",v)
json.dump({"pairs":[("0x"+p[-40:]) for p in pairs]},open("factory2.json","w"),indent=1)

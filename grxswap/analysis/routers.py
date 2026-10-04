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
routers={"router02":"0xC9e92Cd01e4C0b734d7d3a5775DEf789d532691d","routerV2":"0x28fC93b8a20570f2B59d5CA9f8a1dA02C4DBcDF5"}
tokens={"WGRX_a":"0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5","USDT18_a":"0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2","USDT18_b":"0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75","WGRX_b":"0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212","SAFE":"0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F","ST":"0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081","BTC":"0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275","ETH":"0x02D129c8A26839c814925eE0f1D320F63114E1FE","USDT6":"0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20"}
items=[];labels=[]
for rn,ra in routers.items():
    for fn in ["factory()","WETH()"]:
        items.append(("eth_call",[{"to":ra,"data":sel(fn)},"latest"])); labels.append(f"{rn}.{fn}")
    items.append(("eth_getBalance",[ra,"latest"])); labels.append(f"{rn}.native")
    for tn,ta in tokens.items():
        items.append(("eth_call",[{"to":ta,"data":sel("balanceOf(address)")+pad(ra)},"latest"])); labels.append(f"{rn}.bal.{tn}")
out=batch(items)
for i,v in out.items(): print(labels[i],"=",v)
json.dump({labels[i]:v for i,v in out.items()},open("routers.json","w"),indent=1)

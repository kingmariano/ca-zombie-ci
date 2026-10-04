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
addrs={
 "WGRX_39Be":"0x39Be0ad46aB4f8032F8959517292D2ba25dd1B6E",
 "WGRX_D7e1":"0xD7e1118134EA003665916A56e29bB7ab2a0CC367",
 "WGRX_be44":"0xbe440Ffe3a0d6ED61ee201aCC830C8C00DB60454",
 "WGRX_e83A":"0xe83A56363C21232F74Fe81e121eC6dCFa47014eE",
 "BTC_95ae":"0x95aeb9FE0F6c260af31F63afCA00544803159B1b",
 "BTC_BF6F":"0xBF6F446B47eEBe758659Ab80DaeEcE6FFCd3AE72",
 "bot":"0x08F4C1c0D5ad8030DA757Ed475fD2ba91B03C090",
 "lp_holder1":"0x79b5a2d395dB1711A6e6c42a95Eb48710276F666",
 "lp6_holder":"0x317a858f7Ea8a7217804Cd11cB09994508b681aC",
 "validatorHelper":"0x2dfb2d492084911cE71ae2D513FCA79841726935",
 "multiSender":"0xF5f71cA925a7F22b07cED1f2Ee5b282734Dc41b5",
 "traits":"0x1482bF92AE3636B82C841424a29bD66Ec2349107",
}
items=[];labels=[]
for n,a in addrs.items():
    items.append(("eth_getCode",[a,"latest"])); labels.append(f"code.{n}")
    items.append(("eth_getBalance",[a,"latest"])); labels.append(f"native.{n}")
    items.append(("eth_getTransactionCount",[a,"latest"])); labels.append(f"nonce.{n}")
    for fn in ["owner()","totalSupply()","name()","symbol()"]:
        items.append(("eth_call",[{"to":a,"data":sel(fn)},"latest"])); labels.append(f"{n}.{fn}")
out=batch(items)
res={labels[i]:v for i,v in out.items()}
for n in addrs:
    c=res.get(f"code.{n}","0x")
    print(f"--- {n} {addrs[n]}")
    print(f"    code={'EOA' if c=='0x' else str((len(c)-2)//2)+' bytes'} native={int(res.get('native.'+n,'0x0'),16)/1e18 if res.get('native.'+n,'0x0').startswith('0x') else '?'} nonce={int(res.get('nonce.'+n,'0x0'),16) if res.get('nonce.'+n,'0x0').startswith('0x') else '?'}")
    for fn in ["owner()","totalSupply()","name()","symbol()"]:
        v=res.get(f"{n}.{fn}")
        print(f"    {fn} -> {v}")
json.dump(res,open("others.json","w"),indent=1)

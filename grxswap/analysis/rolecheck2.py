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
roles={"ADMIN":"0x0000000000000000000000000000000000000000000000000000000000000000","MINTER":"0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6","PAUSER":"0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a","COMPLIANCE":"0x442a94f1a1fac79af32856af2a64f63648cfa2ef3b98610a5bb7cbec4cee6985","BLOCKLISTER":"0x5442dc837335aa278534a338d1e63d0c5649b0678ad376ddd382f1af9b8f250a"}
tokens={"USDT6":"0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20","BTC":"0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275","ETH":"0x02D129c8A26839c814925eE0f1D320F63114E1FE"}
cands={"grantor":"0xc5d349a096bc9c9ab482ca51e2e82630fe1d32fb","mid":"0x0edc1bbc571baf713e86a7e2475fb43ae62d6d39","owner":"0x53e6a26f382e6b6d50a183c747cb0c7607ba8043"}
items=[];labels=[]
for n,a in cands.items():
    items.append(("eth_getCode",[a,"latest"])); labels.append(f"code.{n}")
    items.append(("eth_getTransactionCount",[a,"latest"])); labels.append(f"nonce.{n}")
    items.append(("eth_getBalance",[a,"latest"])); labels.append(f"native.{n}")
    for tn,ta in tokens.items():
        for rn,rh in roles.items():
            items.append(("eth_call",[{"to":ta,"data":sel("hasRole(bytes32,address)")+rh[2:]+pad(a)},"latest"])); labels.append(f"{tn}.{rn}.{n}")
out=batch(items)
for i,v in out.items():
    l=labels[i]
    if l.startswith("code."): print(l,"len",(len(v)-2)//2 if v and v!="0x" else 0)
    elif l.startswith(("nonce.","native.")): print(l,int(v,16) if v.startswith("0x") else v)
    elif v.endswith("1"): print("ROLE:",l)

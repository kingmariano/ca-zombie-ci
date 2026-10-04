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
roles={
 "ADMIN":"0x0000000000000000000000000000000000000000000000000000000000000000",
 "MINTER":"0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
 "PAUSER":"0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a",
 "COMPLIANCE":"0x442a94f1a1fac79af32856af2a64f63648cfa2ef3b98610a5bb7cbec4cee6985",
 "BLOCKLISTER":"0x5442dc837335aa278534a338d1e63d0c5649b0678ad376ddd382f1af9b8f250a",
}
tokens={
 "USDT6":"0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20",
 "BTC":"0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275",
 "ETH":"0x02D129c8A26839c814925eE0f1D320F63114E1FE",
}
cands={
 "deployer?":"0x53e6a26f382e6b6d50a183c747cb0c7607ba8043",
 "feeTo":"0xDb9011614CC30136Af7EBBa4e314641e07c10221",
 "ownerB":"0xb25aca59f939138be076ab3fa450c7d078855555",
 "router02":"0xC9e92Cd01e4C0b734d7d3a5775DEf789d532691d",
 "routerV2":"0x28fC93b8a20570f2B59d5CA9f8a1dA02C4DBcDF5",
 "bot":"0x08F4C1c0b6aBd15F1f2d1A6e3c2D5f6A7b8C9d0e",
 "lp_holder":"0x79b5a2d395dB1711A6e6c42a95Eb48710276F666",
 "lp6_holder":"0x317a858f7Ea8a7217804Cd11cB09994508b681aC",
}
items=[];labels=[]
for tn,ta in tokens.items():
    for rn,rh in roles.items():
        for cn,ca in cands.items():
            items.append(("eth_call",[{"to":ta,"data":sel("hasRole(bytes32,address)")+rh[2:]+pad(ca)},"latest"]))
            labels.append(f"{tn}.{rn}.{cn}")
out=batch(items)
hits=[(labels[i],v) for i,v in out.items() if v and v.endswith("1")]
for l,v in hits: print("ROLE HIT:",l)
print("total checks:",len(labels),"hits:",len(hits))
json.dump({labels[i]:v for i,v in out.items()},open("roles.json","w"),indent=1)

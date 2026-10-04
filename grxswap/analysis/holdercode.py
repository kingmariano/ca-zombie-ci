import json, urllib.request, time
URL="https://rpc.grxchain.io"
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
addrs=["0xDcf3449c03635E77C43522d21a3e5473c457a82e","0x50e6d2e4E01008dCe22E69aC2EF76BEBdA535Dc2","0x7ee04cd7187D9EDb18646e58168bAbB9CEF75923","0x57248320b725c7396A840F17F1389ca3BAf01F86","0x9E927EF96DD80AEa2Fc6843afC2351e35aB724db","0x44078257d20906bc1D9Afd550281771c9d70b482","0x79b5a2d395dB1711A6e6c42a95Eb48710276F666","0x53e6A26f382e6b6d50a183C747cb0C7607ba8043","0x0eDC1BbC571bAF713E86a7E2475fb43ae62D6D39","0xFF5949D19EA261c1b398295Cf9D345335e22aC52","0x317a858f7Ea8a7217804Cd11cB09994508b681aC","0x1BD3C1BD99aAe8f57aBD1eB772995bDc9f6cB2e7","0x5C283F85278Bab45a93cC6Bfa6E497796E6e666E"]
items=[]
for a in addrs:
    items.append(("eth_getCode",[a,"latest"]))
    items.append(("eth_getTransactionCount",[a,"latest"]))
out=batch(items)
for i,a in enumerate(addrs):
    c=out[2*i]; n=out[2*i+1]
    ln=(len(c)-2)//2 if c and c!="0x" else 0
    print(f"{a} code={'EOA' if ln==0 else str(ln)+'B'} nonce={int(n,16)}")

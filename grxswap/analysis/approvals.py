import json,urllib.request,time
APPROVAL="0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
TOKENS={
 "WGRX_a":"0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5",
 "USDT18_a":"0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",
 "USDT18_b":"0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75",
 "BTC":"0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275",
 "ETH":"0x02D129c8A26839c814925eE0f1D320F63114E1FE",
 "USDT6":"0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20",
 "SAFE":"0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F",
 "ST":"0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081",
}
def fetch(url,maxp=12):
    items=[]
    for _ in range(maxp):
        try:
            r=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0"})
            d=json.load(urllib.request.urlopen(r,timeout=40))
        except Exception as e:
            print("err",e); break
        items+=d.get("items",[])
        np=d.get("next_page_params")
        if not np: break
        url=url.split("?")[0]+"?"+"&".join(f"{k}={v}" for k,v in np.items())
    return items
allap={}
for n,a in TOKENS.items():
    items=fetch(f"https://grxscan.io/api/v2/addresses/{a}/logs?topic={APPROVAL}")
    pairs=set()
    for it in items:
        try:
            owner="0x"+it["topics"][1][-40:]; spender="0x"+it["topics"][2][-40:]
            pairs.add((owner,spender))
        except Exception: pass
    allap[n]=sorted(pairs)
    print(f"{n}: {len(items)} approval events, {len(pairs)} unique (owner,spender)")
json.dump(allap,open("approvals_scan.json","w"),indent=1)
# summarize unique spenders
sp=set()
for n,ps in allap.items():
    for o,s in ps: sp.add(s)
print("unique spenders:",sp)

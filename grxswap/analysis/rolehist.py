import json,urllib.request,time
TOKENS={
 "USDT6":"0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20",
 "BTC":"0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275",
 "ETH":"0x02D129c8A26839c814925eE0f1D320F63114E1FE",
}
GRANT="0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d"
REVOKE="0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b"
roles={"0x00":"ADMIN","0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6":"MINTER","0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a":"PAUSER","0x442a94f1a1fac79af32856af2a64f63648cfa2ef3b98610a5bb7cbec4cee6985":"COMPLIANCE","0x5442dc837335aa278534a338d1e63d0c5649b0678ad376ddd382f1af9b8f250a":"BLOCKLISTER"}
def fetch(url):
    items=[]
    for _ in range(10):
        try:
            r=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0"})
            d=json.load(urllib.request.urlopen(r,timeout=40))
        except Exception as e: print("err",e); break
        items+=d.get("items",[])
        np=d.get("next_page_params")
        if not np: break
        url=url.split("?")[0]+"?"+"&".join(f"{k}={v}" for k,v in np.items())
    return items
for tn,ta in TOKENS.items():
    print("#####",tn)
    for ev,topic in [("GRANT",GRANT),("REVOKE",REVOKE)]:
        items=fetch(f"https://grxscan.io/api/v2/addresses/{ta}/logs?topic={topic}")
        for it in items:
            t=it["topics"]
            role=roles.get(t[1][:66],"0x"+t[1][2:10])
            acct="0x"+t[2][-40:]
            sender="0x"+t[3][-40:]
            print(f"  {ev} blk={it['block_number']} role={role} account={acct} sender={sender}")

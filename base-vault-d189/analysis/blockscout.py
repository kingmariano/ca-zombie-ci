import json, urllib.request, urllib.parse, time, sys

UA={"User-Agent":"Mozilla/5.0","Accept":"application/json"}
BASE="https://base.blockscout.com"
def get(path, params=None):
    u=BASE+path+("?"+urllib.parse.urlencode(params) if params else "")
    for a in range(4):
        try:
            return json.load(urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=45))
        except Exception as e:
            sys.stderr.write(f"retry {a} {u} {e}\n"); time.sleep(2+2*a)
    raise RuntimeError("blockscout fail "+u)

V="0xD1895f2019c2152FC2b9022D57f19198c4CFCABC"
# sanity
info=get(f"/api/v2/addresses/{V}")
print("vault:", info.get("name") or "(no name)", "tx_count:", (info.get("transaction_count") or info.get("transactions_count")))
# v1 txlist (full input)
alltx=[]
page=1
while True:
    d=get("/api",{"module":"account","action":"txlist","address":V,"page":page,"offset":100,"sort":"asc"})
    res=d.get("result") or []
    if isinstance(res,dict): print("ERR",res); break
    alltx+=res
    print("txlist page",page,"got",len(res),"total",len(alltx))
    if len(res)<100: break
    page+=1
    if page>60: break
json.dump(alltx, open("vault_txlist.json","w"))
print("TOTAL direct txs to/from vault:", len(alltx))

import json, urllib.request, time, sys
S="0xa88800cd213da5ae406ce248380802bd53b47647"
base=f"https://eth.blockscout.com/api/v2/addresses/{S}/transactions?filter=to"
hdr={"User-Agent":"research","Accept":"application/json"}
seen={}
cur=base; pages=0
while cur and pages<800:
    req=urllib.request.Request(cur,headers=hdr)
    try:
        d=json.load(urllib.request.urlopen(req,timeout=30))
    except Exception as e:
        print("err",e); time.sleep(2); continue
    for it in d.get("items",[]):
        f=(it.get("from") or {}).get("hash")
        if f:
            seen.setdefault(f,{"n":0,"first":None,"last":None})
            seen[f]["n"]+=1
            ts=it.get("timestamp")
            if ts:
                if not seen[f]["first"] or ts<seen[f]["first"]: seen[f]["first"]=ts
                if not seen[f]["last"] or ts>seen[f]["last"]: seen[f]["last"]=ts
    pages+=1
    nxt=d.get("next_page_params")
    if not nxt: break
    q="&".join(f"{k}={urllib.parse.quote(str(v))}" for k,v in nxt.items())
    cur=base+"&"+q
    time.sleep(0.15)
print("pages:",pages,"unique senders:",len(seen))
json.dump(seen,open("settlement_senders.json","w"),indent=1)
for a,v in sorted(seen.items(),key=lambda kv:-kv[1]["n"]):
    print(a, v["n"], v["first"], v["last"])

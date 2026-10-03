#!/usr/bin/env python3
import sys, json, time
sys.path.insert(0,'/home/heisenberg/CA/sphere-finance/analysis')
from es import txlist
deployer=sys.argv[1] if len(sys.argv)>1 else "0x7754d8b057CC1d2D857d897461DAC6C3235B4aAe"
out=sys.argv[2] if len(sys.argv)>2 else "deployer_txlist_full.json"
all_txs=[]
for page in range(1,80):
    d=txlist(deployer,page=page,offset=200,sort="asc")
    if d.get("status")!="1":
        print("page",page,"status",d.get("status"),str(d.get("result"))[:100], flush=True); break
    res=d["result"]
    all_txs.extend(res)
    if len(res)<200:
        print("last page",page,"got",len(res), flush=True); break
    print("page",page,"total",len(all_txs), flush=True)
    time.sleep(0.1)
json.dump(all_txs, open(out,"w"))
creates=[t for t in all_txs if t.get("to","")=="" ]
print("TOTAL txs:",len(all_txs),"contract creations:",len(creates), flush=True)
if all_txs:
    print("first block",all_txs[0]["blockNumber"],"last block",all_txs[-1]["blockNumber"], flush=True)
for t in creates:
    print(t["hash"][:14], t["blockNumber"], t.get("contractAddress"), flush=True)

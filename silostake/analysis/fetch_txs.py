import json, urllib.request, urllib.parse, base64, time

HUB="sei1e3gttzq5e5k49f9f5gzvrl0rltlav65xu6p9xc0aj7e84lantdjqp7cncc"
UA={"User-Agent":"Mozilla/5.0"}
def get(url):
    req=urllib.request.Request(url, headers=UA)
    return json.loads(urllib.request.urlopen(req, timeout=40).read().decode())

all_txs=[]
key=None
for i in range(6):
    params={"events":f"wasm._contract_address='{HUB}'","limit":"100","order_by":"ORDER_BY_DESC"}
    if key: params["pagination.key"]=key
    url="https://rest.sei-apis.com/cosmos/tx/v1beta1/txs?"+urllib.parse.urlencode(params)
    d=get(url)
    txs=d.get("txs",[])
    all_txs.extend(txs)
    key=d.get("pagination",{}).get("next_key")
    print("page",i,"got",len(txs),"key", (key[:20] if key else None), flush=True)
    if not key or not txs: break
    time.sleep(0.5)

json.dump(all_txs, open("txs_raw.json","w"))
# summarize
from collections import Counter
summary=Counter()
samples={}
for tx in all_txs:
    t=tx.get("timestamp")
    for m in tx.get("body",{}).get("messages",[]):
        typ=m.get("@type")
        if typ=="/cosmwasm.wasm.v1.MsgExecuteContract":
            msg=m.get("msg")
            try: decoded=base64.b64decode(msg).decode()
            except Exception: decoded=str(msg)[:80]
            try: msgdict=json.loads(decoded)
            except Exception: msgdict={"_raw":decoded[:120]}
            action=list(msgdict.keys())[0] if msgdict else "?"
            if "callback" in msgdict:
                action="callback:"+str(msgdict.get("callback",{}).get("msg",{}).keys())
            summary[action]+=1
            if action not in samples:
                samples[action]=(t, m.get("sender"), decoded[:400], m.get("funds"))
print(json.dumps(dict(summary), indent=1))
print("--- earliest in page set:", min((tx.get("timestamp","") for tx in all_txs), default=None), "latest:", max((tx.get("timestamp","") for tx in all_txs), default=None))
json.dump(samples, open("tx_samples.json","w"), indent=1)
for k,v in samples.items():
    print("=====",k,"\n time:",v[0],"\n sender:",v[1],"\n msg:",v[2][:300],"\n funds:",v[3])

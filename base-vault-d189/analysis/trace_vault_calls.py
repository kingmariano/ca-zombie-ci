import json, urllib.request, os, time, sys
DRPC="https://base.drpc.org"; DKEY=os.environ["DRPC_API_KEY"]
def rpc(method, params):
    for a in range(4):
        try:
            req=urllib.request.Request(DRPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                headers={"Content-Type":"application/json","X-API-Key":DKEY,"User-Agent":"Mozilla/5.0"})
            r=json.load(urllib.request.urlopen(req, timeout=90))
            if "result" in r or "error" in r: return r
        except Exception as e:
            sys.stderr.write(f"retry {a} {method}: {e}\n"); time.sleep(1.5*(a+1))
    raise RuntimeError("rpc fail "+method)
V="0xD1895f2019c2152FC2b9022D57f19198c4CFCABC".lower()
H="0xcdfe91301356da873562ef513828a60dba1f569d"
SIB="0x416ec2ca21a38cbcfeacd6a14532b3f348356d23"
ints=json.load(open("vault_internal_v2.json"))
txs=sorted({t["transaction_hash"] for t in ints if (t.get("to") or {}).get("hash","").lower()==V}, key=lambda h: next(t["block_number"] for t in ints if t["transaction_hash"]==h))
print("parent txs:", len(txs))
def walk(node, out, depth=0):
    if not isinstance(node,dict): return
    out.append(node)
    for c in node.get("calls",[]) or []: walk(c,out,depth+1)
SEL={"0x38edc837":"__setWhitelist__","0x9a39f8dd":"__withdraw","0xa415bcad":"borrow","0x69328dec":"withdraw/helper","0x617ba037":"supply","0x573ade81":"repay","0x4abb8b6f":"4abb8b6f","0x6b711cc9":"6b711cc9","0x76309d0e":"76309d0e","0xd2b2de5b":"d2b2de5b","0x698442db":"698442db","0xcb984317":"cb984317","0xdebd4ffc":"__redeem"}
records=[]
for i,h in enumerate(txs):
    r=rpc("debug_traceTransaction",[h,{"tracer":"callTracer","tracerConfig":{"withLog":False}}])
    if "result" not in r:
        print("ERR trace",h,str(r.get("error"))[:100]); continue
    calls=[]; walk(r["result"],calls)
    for c in calls:
        to=(c.get("to") or "").lower()
        if to not in (V,H,SIB): continue
        inp=c.get("input") or "0x"
        sel=inp[:10]
        records.append({"tx":h,"block":None,"to":("vault" if to==V else "helper" if to==H else "sibling"),
                        "from":(c.get("from") or "").lower(),"type":c.get("type"),"sel":sel,
                        "name":SEL.get(sel,sel),"input":inp,"ok":("error" not in c),"error":c.get("error")})
    time.sleep(0.2)
json.dump(records, open("vault_call_traces.json","w"), indent=1)
print("call records to vault/helper/sibling:", len(records))
from collections import Counter
print(Counter((r["to"],r["name"]) for r in records).most_common(30))
print("\n=== calls = __setWhitelist__ ===")
for r in records:
    if r["name"]=="__setWhitelist__":
        ri=r["input"]; addr="0x"+ri[34:74]; val=int(ri[74:138],16) if len(ri)>=138 else None
        print(r["from"], "->", addr, "=", val, "sel", r["sel"], "ok", r["ok"], "tx", r["tx"][:14])
print("\n=== calls by from to vault (distinct) ===")
for k,v in Counter(r["from"] for r in records if r["to"]=="vault").most_common():
    print(k, v)

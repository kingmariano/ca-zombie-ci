#!/usr/bin/env python3
"""Chunked resumable Borrow/Repay/Liquidate fetcher for a given market."""
import json, sys, time, urllib.request, os
RPC="https://rpcapi.fantom.network"
TOPICS={"Borrow":"0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80",
"RepayBorrow":"0x1a2a22cb034d26d1854bdc6666a5b91fe25efbbb5dcad3b0355478d6f5c362a1",
"LiquidateBorrow":"0x298637f684da70674f26509b10f07ec2fbc77a335ab1e7d6215a4b2484d8bb52"}
def post(payload):
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
    for a in range(5):
        try: return json.loads(urllib.request.urlopen(req,timeout=90).read())
        except Exception:
            if a==4: raise
            time.sleep(1.5*(a+1))
def main():
    addr=sys.argv[1]; tag=sys.argv[2]
    out=f"/home/heisenberg/CA/scream/analysis/logs_{tag}.jsonl"
    state=f"/home/heisenberg/CA/scream/analysis/logs_{tag}.state.json"
    latest=int(post({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]})["result"],16)
    st=json.load(open(state)) if os.path.exists(state) else {"topics":{k:{"done_upto":0,"chunk":2000000} for k in TOPICS}}
    f=open(out,"a")
    for name,topic in TOPICS.items():
        s=st["topics"][name]; lo=s["done_upto"]; chunk=s["chunk"]
        while lo<latest:
            hi=min(lo+chunk,latest)
            try:
                r=post({"jsonrpc":"2.0","id":1,"method":"eth_getLogs","params":[{"fromBlock":hex(lo),"toBlock":hex(hi),"address":addr,"topics":[topic]}]})
                if "result" not in r: raise RuntimeError(str(r)[:150])
                logs=r["result"]
            except Exception as e:
                if chunk>25000: chunk//=4; s["chunk"]=chunk; continue
                print(f"{name} give up {lo}-{hi}: {e}",file=sys.stderr); time.sleep(3); continue
            for lg in logs: f.write(json.dumps({"topic":name,**lg})+"\n")
            f.flush(); lo=hi+1; s["done_upto"]=lo
            if len(logs)>5000: chunk=max(50000,chunk//2); s["chunk"]=chunk
            json.dump(st,open(state,"w"))
    json.dump(st,open(state,"w")); f.close(); print("DONE",tag,latest)
main()

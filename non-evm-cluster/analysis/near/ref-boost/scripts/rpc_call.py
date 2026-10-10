#!/usr/bin/env python3
"""Full (untruncated) read-only view call: rpc_call.py <account> <method> <json-args> <outfile>"""
import base64, json, sys, time, urllib.request
RPC="https://rpc.mainnet.near.org"
acct, method = sys.argv[1], sys.argv[2]
args = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else {}
out = sys.argv[4] if len(sys.argv) > 4 else None
def rpc(m,p):
    for i in range(6):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":"r","method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=60) as r: d=json.loads(r.read())
            if "error" in d: raise RuntimeError(json.dumps(d["error"])[:300])
            return d["result"]
        except Exception as e:
            err=e; time.sleep(8*(i+1))
    raise RuntimeError(str(err))
ab=base64.b64encode(json.dumps(args).encode()).decode()
r=rpc("query",{"request_type":"call_function","account_id":acct,"method_name":method,"args_base64":ab,"finality":"final"})
raw=bytes(r.get("result",[]))
try: dec=json.loads(raw.decode())
except Exception: dec={"_raw_hex": raw.hex()[:400]}
res={"account":acct,"method":method,"args":args,"block_height":r.get("block_height"),"result":dec}
if out:
    with open(out,"w") as f: json.dump(res,f,indent=1)
    print(f"saved {out} block={r.get('block_height')} len={len(raw)}")
else:
    print(json.dumps(res)[:4000])

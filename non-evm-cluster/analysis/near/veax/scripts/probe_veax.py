import base64, json, time, urllib.request
RPC="https://rpc.mainnet.near.org"
def call(acct, method, args=None):
    for i in range(5):
        try:
            ab=base64.b64encode(json.dumps(args or {}).encode()).decode()
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":"r","method":"query","params":{"request_type":"call_function","account_id":acct,"method_name":method,"args_base64":ab,"finality":"final"}}).encode(),headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=40) as r: d=json.loads(r.read())
            if "error" in d: return {"error": str(d["error"])[:200]}
            raw=bytes(d["result"].get("result",[]))
            try: return {"block": d["result"].get("block_height"), "res": json.loads(raw.decode())}
            except Exception: return {"block": d["result"].get("block_height"), "raw": raw[:200].hex()}
        except Exception as e:
            time.sleep(6*(i+1))
    return {"error":"throttled"}
for m,args in [("get_owner",{}),("get_version",{}),("metadata",{}),("get_protocol_fee_amounts",{}),("get_verified_tokens",{}),("get_pools",{"from_index":0,"limit":5})]:
    r=call("veax.near",m,args)
    print(json.dumps({"method":m,"result":r})[:900]); print("---")
    time.sleep(3)

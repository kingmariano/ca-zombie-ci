import base64, json, time, urllib.request
RPC="https://rpc.mainnet.near.org"
def rpc(m,p):
    for i in range(8):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":"r","method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=40) as r: d=json.loads(r.read())
            if "error" in d: raise RuntimeError(json.dumps(d["error"])[:150])
            return d["result"]
        except Exception as e:
            time.sleep(10*(i+1))
    raise RuntimeError("throttled")
def bal(tok, acct):
    ab=base64.b64encode(json.dumps({"account_id":acct}).encode()).decode()
    r=rpc("query",{"request_type":"call_function","account_id":tok,"method_name":"ft_balance_of","args_base64":ab,"finality":"final"})
    return bytes(r.get("result",[])).decode("utf8","replace"), r.get("block_height")
jobs=[("v1.orderbook.near","a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.factory.bridge.near"),
      ("v1.orderbook.near","dac17f958d2ee523a2206206994597c13d831ec7.factory.bridge.near"),
      ("v1.orderbook.near","usdt.tether-token.near"),
      ("v1.orderbook.near","2260fac5e5542a773aa44fbcfedf7c193bc2c599.factory.bridge.near"),
      ("v1.orderbook.near","aurora"),
      ("v1.orderbook.near","meta-pool.near"),
      ("v1.orderbook.near","meta-token.near"),
      ("v1.tonic-perps.near","usdt.tether-token.near"),
      ("v1.tonic-perps.near","aurora"),
      ("veax.near","aurora")]
out={}
for acct,tok in jobs:
    try:
        v,bh=bal(tok,acct); out[f"{acct}|{tok}"]={"raw":v,"block":bh}
        print(f"{acct}\t{tok}\t{v}\tbh={bh}", flush=True)
    except Exception as e:
        out[f"{acct}|{tok}"]={"error":str(e)}
        print(f"{acct}\t{tok}\tERR {e}", flush=True)
    time.sleep(4)
json.dump(out, open("dumps/balances_round2.json","w"), indent=1)

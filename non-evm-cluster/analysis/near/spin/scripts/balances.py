import base64, json, time, urllib.request, os
RPC="https://rpc.mainnet.near.org"
def rpc(m,p):
    for i in range(6):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":"r","method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=40) as r: d=json.loads(r.read())
            if "error" in d: raise RuntimeError(json.dumps(d["error"])[:150])
            return d["result"]
        except Exception as e:
            time.sleep(6*(i+1))
    raise RuntimeError("throttled")
def bal(tok, acct):
    ab=base64.b64encode(json.dumps({"account_id":acct}).encode()).decode()
    r=rpc("query",{"request_type":"call_function","account_id":tok,"method_name":"ft_balance_of","args_base64":ab,"finality":"final"})
    raw=bytes(r.get("result",[]))
    return raw.decode("utf8","replace")
JOBS=[
 ("veax","veax.near","aurora"),
 ("veax","veax.near","token.stlb.near"),
 ("spin","spot.spin-fi.near","wrap.near"),
 ("spin","spot.spin-fi.near","a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.factory.bridge.near"),
 ("spin","spot.spin-fi.near","usdt.tether-token.near"),
 ("spin","spot.spin-fi.near","dac17f958d2ee523a2206206994597c13d831ec7.factory.bridge.near"),
 ("spin","spot.spin-fi.near","2260fac5e5542a773aa44fbcfedf7c193bc2c599.factory.bridge.near"),
 ("spin","spot.spin-fi.near","aurora"),
 ("spin","spot.spin-fi.near","token.v2.ref-finance.near"),
 ("spin","spot.spin-fi.near","17208628f84f5d6ad33f0da3bbbeb27ffcb398eac501a31bd6ad2011e36133a1"),
 ("spin","spot.spin-fi.near","token.paras.near"),
 ("spin","spot.spin-fi.near","token.pembrock.near"),
 ("spin","v1.vault.spin-fi.near","wrap.near"),
 ("spin","v1.vault.spin-fi.near","a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.factory.bridge.near"),
 ("spin","v1.vault.spin-fi.near","dac17f958d2ee523a2206206994597c13d831ec7.factory.bridge.near"),
 ("spin","v1.vault.spin-fi.near","2260fac5e5542a773aa44fbcfedf7c193bc2c599.factory.bridge.near"),
 ("spin","v1.vault.spin-fi.near","aurora"),
 ("spin","v1.vault.spin-fi.near","meta-pool.near"),
 ("spin","v1.vault.spin-fi.near","linear-protocol.near"),
 ("spin","v2_0_2.perp.spin-fi.near","a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.factory.bridge.near"),
 ("spin","v2_0_2.perp.spin-fi.near","17208628f84f5d6ad33f0da3bbbeb27ffcb398eac501a31bd6ad2011e36133a1"),
 ("tonic","v1.orderbook.near","a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.factory.bridge.near"),
 ("tonic","v1.orderbook.near","dac17f958d2ee523a2206206994597c13d831ec7.factory.bridge.near"),
 ("tonic","v1.orderbook.near","usdt.tether-token.near"),
 ("tonic","v1.orderbook.near","2260fac5e5542a773aa44fbcfedf7c193bc2c599.factory.bridge.near"),
 ("tonic","v1.orderbook.near","aurora"),
 ("tonic","v1.orderbook.near","meta-pool.near"),
 ("tonic","v1.orderbook.near","meta-token.near"),
 ("tonic","v1.tonic-perps.near","usdt.tether-token.near"),
 ("tonic","v1.tonic-perps.near","aurora"),
]
results={}
for proto, acct, tok in JOBS:
    key=f"{acct}|{tok}"
    try:
        raw=bal(tok,acct); results[key]=raw
        print(f"{proto}\t{acct}\t{tok}\t{raw}", flush=True)
    except Exception as e:
        results[key]={"error":str(e)}
        print(f"{proto}\t{acct}\t{tok}\tERR {e}", flush=True)
    time.sleep(2)
for proto in set(j[0] for j in JOBS):
    outdir=f"/home/heisenberg/CA/non-evm-cluster/analysis/near/{proto}/dumps"
    os.makedirs(outdir, exist_ok=True)
    sub={k:v for k,v in results.items() if k.split("|")[0] in [f"{j[1]}" for j in JOBS if j[0]==proto]}
    json.dump(sub, open(f"{outdir}/ft_balances_round2.json","w"), indent=1)
print("done")

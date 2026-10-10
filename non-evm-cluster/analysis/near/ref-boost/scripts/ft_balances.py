#!/usr/bin/env python3
"""Read ft_balance_of for a list of token contracts for one account (read-only)."""
import base64, json, sys, time, urllib.request

RPC = "https://rpc.mainnet.near.org"

def rpc(method, params, tries=6):
    last=None
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":"r","method":method,"params":params}).encode(), headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d=json.loads(r.read())
            if "error" in d: raise RuntimeError(json.dumps(d["error"])[:200])
            return d["result"]
        except Exception as e:
            last=e; time.sleep(1+i)
    raise RuntimeError(str(last))

def ft_balance(token, account):
    args = base64.b64encode(json.dumps({"account_id": account}).encode()).decode()
    res = rpc("query", {"request_type":"call_function","account_id":token,"method_name":"ft_balance_of","args_base64":args,"finality":"final"})
    raw = bytes(res.get("result",[]))
    try: return json.loads(raw.decode())
    except Exception: return None

def ft_metadata(token):
    res = rpc("query", {"request_type":"call_function","account_id":token,"method_name":"ft_metadata","args_base64":base64.b64encode(b"{}").decode(),"finality":"final"})
    raw = bytes(res.get("result",[]))
    try: return json.loads(raw.decode())
    except Exception: return None

if __name__ == "__main__":
    account = sys.argv[1]
    tokens = json.load(open(sys.argv[2]))
    out = {"account": account, "balances": {}}
    for t in tokens:
        try:
            b = ft_balance(t, account)
            m = ft_metadata(t)
            out["balances"][t] = {"raw": b, "decimals": (m or {}).get("decimals"), "symbol": (m or {}).get("symbol")}
            print(f"{t}\t{b}\tdec={(m or {}).get('decimals')}\tsym={(m or {}).get('symbol')}", flush=True)
        except Exception as e:
            out["balances"][t] = {"error": str(e)[:200]}
            print(f"{t}\tERROR\t{e}", flush=True)
        time.sleep(0.15)
    json.dump(out, open(f"dumps/{account}.ft_balances.json","w"), indent=1)

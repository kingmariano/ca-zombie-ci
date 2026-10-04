#!/usr/bin/env python3
"""Enumerate LimitOrderRegistry LP positions + ERC20 balances across chains (read-only)."""
import json, urllib.request, sys, time

def rpc(url, method, params, retries=3):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type":"application/json","User-Agent":"zombie-hunt/1.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.load(r)
            if "result" in d: return d["result"]
            print("RPC err", d.get("error"), file=sys.stderr)
        except Exception as e:
            print("retry", i, e, file=sys.stderr); time.sleep(2)
    return None

def call(url, to, data):
    return rpc(url, "eth_call", [{"to":to,"data":data}, "latest"])

def balance_of(url, token, owner):
    # balanceOf(address) = 0x70a08231
    r = call(url, token, "0x70a08231" + owner[2:].lower().rjust(64,"0"))
    return int(r,16) if r and r != "0x" else None

def u256(hexstr):
    return int(hexstr,16) if hexstr and hexstr!="0x" else 0

def token_of_owner(url, nfpm, owner, i):
    # tokenOfOwnerByIndex(address,uint256)
    data = "0x2f745c59" + owner[2:].lower().rjust(64,"0") + hex(i)[2:].rjust(64,"0")
    r = call(url, nfpm, data)
    return u256(r)

def positions(url, nfpm, tid):
    data = "0x99fbab88" + hex(tid)[2:].rjust(64,"0")
    r = call(url, nfpm, data)
    if not r or r=="0x": return None
    b = r[2:]
    words = [b[i:i+64] for i in range(0, len(b), 64)]
    if len(words) < 12: return None
    return {
        "nonce": int(words[0],16),
        "operator": "0x"+words[1][24:],
        "token0": "0x"+words[2][24:],
        "token1": "0x"+words[3][24:],
        "fee": int(words[4],16),
        "tickLower": int(words[5],16, ) if int(words[5],16) < 2**255 else int(words[5],16)-2**256,
        "tickUpper": int(words[6],16) if int(words[6],16) < 2**255 else int(words[6],16)-2**256,
        "liquidity": int(words[7],16),
        "owed0": int(words[10],16),
        "owed1": int(words[11],16),
    }

def scan(chain, url, lor, nfpm):
    out = {"chain":chain, "lor":lor, "nfpm":nfpm, "positions":[], "summary":{}}
    bn = rpc(url,"eth_blockNumber",[])
    out["block"] = int(bn,16) if bn else None
    bal = call(url, nfpm, "0x70a08231" + lor[2:].lower().rjust(64,"0"))
    n = u256(bal) if bal else 0
    out["nfpm_balance"] = n
    nonempty = 0; total_liq = 0
    for i in range(min(n, 400)):
        tid = token_of_owner(url, nfpm, lor, i)
        if not tid: continue
        p = positions(url, nfpm, tid)
        if not p: continue
        p["tokenId"]=tid
        if p["liquidity"]>0 or p["owed0"]>0 or p["owed1"]>0:
            nonempty += 1; total_liq += p["liquidity"]
        out["positions"].append(p)
    out["summary"] = {"positions_total": n, "nonempty": nonempty, "total_liquidity": str(total_liq)}
    return out

if __name__ == "__main__":
    chains = {
        "scroll": ("https://rpc.scroll.io", "0xeC3E5eeC51D8C3D4f03DABB84B4Db313a739f377", "0xB39002E4033b162fAc607fc3471E205FA2aE5967"),
        "linea":  ("https://rpc.linea.build", "0x63c8527f670d4eb3401c80c5905ceca8727f1e74", "0x4615C383F85D0a2BbED973d83ccecf5CB7121463"),
    }
    for name,(url,lor,nfpm) in chains.items():
        print("scanning", name, file=sys.stderr)
        d = scan(name, url, lor, nfpm)
        json.dump(d, open(f"/home/heisenberg/CA/oku-trade/analysis/lor_positions_{name}.json","w"), indent=1)
        print(name, d["summary"], "block", d["block"])

#!/usr/bin/env python3
"""Fetch full positions of shortfall accounts: entered markets, balances, debts."""
import requests, json, sys, time
from Crypto.Hash import keccak

R = "https://mainnet.aurora.dev"
BLOCK = sys.argv[1] if len(sys.argv) > 1 else "latest"
MARKETS = {
    "cETH":  "0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0",
    "cNEAR": "0x8C14ea853321028a7bb5E4FB0d0147F183d3B677",
    "cUSDC": "0xe5308dc623101508952948b141fD9eaBd3337D99",
    "cUSDT": "0x845E15A441CFC1871B7AC610b0E922019BaD9826",
    "cWBTC": "0xfa786baC375D8806185555149235AcDb182C033b",
}
UNITROLLER = "0x6De54724e128274520606f038591A00C5E94a1F6"

def sel(sig):
    k=keccak.new(digest_bits=256); k.update(sig.encode()); return "0x"+k.hexdigest()[:8]
def enc_addr(a): return a[2:].lower().rjust(64,"0")

short = list(json.load(open("account_liquidity.json"))["shortfall"].keys())
print("shortfall accounts:", len(short))

sess = requests.Session()
def run_batch(calls):
    payload=[{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to,"data":data}, BLOCK]} for i,(to,data) in enumerate(calls)]
    res=None
    for k in range(8):
        try:
            j=sess.post(R,json=payload,timeout=240).json()
            if isinstance(j, dict):  # error object -> retry
                time.sleep(3*(k+1)); continue
            res=j; break
        except Exception:
            time.sleep(3*(k+1))
    if not isinstance(res, list):
        print("batch failed after retries; falling back to individual calls")
        res=[]
        for i,c in enumerate(calls):
            single={"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":c[0],"data":c[1]}, BLOCK]}
            ok=False
            for k in range(5):
                try:
                    j=sess.post(R,json=single,timeout=60).json()
                    if isinstance(j, dict) and "result" in j:
                        res.append({"id":i,"result":j["result"]}); ok=True; break
                    time.sleep(2*(k+1))
                except Exception:
                    time.sleep(2*(k+1))
            if not ok:
                res.append({"id":i})
    byid={x.get("id"):x for x in res}
    return [byid.get(i,{}).get("result") for i in range(len(calls))]

SEL_BAI=sel("getAssetsIn(address)")
SEL_BAL=sel("balanceOf(address)")
SEL_BBS=sel("borrowBalanceStored(address)")

pos={}
CH=8
for i in range(0,len(short),CH):
    chunk=short[i:i+CH]
    calls=[]
    for a in chunk:
        calls.append((UNITROLLER, SEL_BAI+enc_addr(a)))
        for mn,addr in MARKETS.items():
            calls.append((addr, SEL_BAL+enc_addr(a)))
            calls.append((addr, SEL_BBS+enc_addr(a)))
    res=run_batch(calls)
    idx=0
    for a in chunk:
        assets_raw=res[idx]; idx+=1
        entered=[]
        if isinstance(assets_raw,str) and len(assets_raw)>2:
            d=assets_raw[2:]
            n=int(d[64:128],16)
            for j in range(n):
                w=d[128+j*64:128+(j+1)*64]
                entered.append("0x"+w[24:])
        bal={}; debt={}
        for mn in MARKETS:
            b=res[idx]; idx+=1; d=res[idx]; idx+=1
            bal[mn]=int(b,16) if isinstance(b,str) and b.startswith("0x") else 0
            debt[mn]=int(d,16) if isinstance(d,str) and d.startswith("0x") else 0
        pos[a]={"entered":entered,"balances":bal,"debts":debt}
    print(f"positions {i+len(chunk)}/{len(short)}", flush=True)

json.dump(pos, open("shortfall_positions.json","w"), indent=1)
print("saved shortfall_positions.json")
# quick aggregate
tot_debt_usd_oracle=0
print("sample:", short[0], json.dumps(pos[short[0]])[:400])

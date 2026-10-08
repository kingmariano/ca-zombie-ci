#!/usr/bin/env python3
"""Detailed snapshots for shortfall accounts + verification of collateral/debt USD."""
import json, requests, time, sys

RPCS=["https://worldchain-mainnet.g.alchemy.com/public","https://480.rpc.thirdweb.com","https://worldchain.drpc.org"]
UNITROLLER="0x589d63300976759a0fc74ea6fA7D951f581252D7"
SEL_ASSETS_IN="0xabfceffc"
SEL_SNAPSHOT="0xc37f68e2"
SEL_ACCT_LIQ="0x5ec88c79"

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")

def rpc_batch(calls, rpc_idx=0):
    out=[]
    for attempt in range(8):
        R=RPCS[rpc_idx % len(RPCS)]
        try:
            payload=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
            r=requests.post(R,json=payload,timeout=90)
            j=r.json()
            if isinstance(j,list):
                byid={x.get('id'):x for x in j}
                res=[]; ok=True
                for i in range(len(calls)):
                    x=byid.get(i)
                    if x is None or 'error' in x: res.append(None); ok=False
                    else: res.append(x.get('result'))
                if ok: return res
        except Exception:
            pass
        time.sleep(1.2); rpc_idx+=1
    return [None]*len(calls)

def call(to,data):
    r=rpc_batch([("eth_call",[{"to":to,"data":data},"latest"])])
    return r[0]

def main():
    liq=json.load(open('account_liquidity.json'))
    debt=json.load(open('current_debtors.json'))
    mk=json.load(open('markets_worldchain_raw.json'))
    market_list=[(m['symbol'],m['market']) for m in mk['markets']]
    short=[b for b,v in liq.items() if v and v['shortfall']>0]
    res={}
    for b in short:
        v=call(UNITROLLER,SEL_ASSETS_IN+enc_addr(b))
        # assetsIn returns dynamic array: offset(32) len(32) items
        assets=[]
        if v:
            raw=v[2:]
            ln=int(raw[64:128],16)
            assets=["0x"+raw[128+i*64+24:128+(i+1)*64] for i in range(ln)]
        entry={"shortfall_1e18":liq[b]['shortfall'],"liquidity_1e18":liq[b]['liquidity'],"assetsIn":assets,"snapshots":{},"debts":{}}
        for name,M in market_list:
            if M.lower() in [a.lower() for a in assets]:
                sv=call(M,SEL_SNAPSHOT+enc_addr(b))
                if sv and len(sv)>=258:
                    err=int(sv[2:66],16); ctok=int(sv[66:130],16); bor=int(sv[130:194],16); exr=int(sv[194:258],16)
                    entry["snapshots"][name]={"cTokenBalance":ctok,"borrowBalance":bor,"exchangeRate":exr}
        for name,md in debt.items():
            if b in md: entry["debts"][name]=md[b]
        res[b]=entry
        print(b,json.dumps(entry)[:400],file=sys.stderr)
    json.dump(res,open('shortfall_details.json','w'),indent=1)
    print("saved",len(res),file=sys.stderr)

if __name__=="__main__": main()

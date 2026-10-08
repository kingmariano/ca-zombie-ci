#!/usr/bin/env python3
"""Check current borrow balances for all historical borrowers, then account liquidity for debtors."""
import json, requests, time, sys

RPCS=["https://worldchain-mainnet.g.alchemy.com/public","https://480.rpc.thirdweb.com","https://worldchain.drpc.org"]
MARKETS={
"caETH":"0xaAd91abe333c4536FFbF02b83daBaB49C9Aa23ed",
"caUSDC":"0x05350F1FC5d396917A73FCE318524551e287D1Df",
"caWBTC":"0xCdA6e3bF6e6529cdEF7D6BE0B133bEd79390796D",
"caLAC":"0x03c1cF154d621E0fD7e2b88be3aE60CCf07Aca31",
"caWARS":"0xF36749472Ad6dA1CcF9eDe8ff321654990635FfA",
"caWLD":"0x57Dd2468FA18023978804240B503D3Ea315eFc95",
"caWBRL":"0x90208d4Be7F539bd46E0e0847085E672E23b3d9A",
}
UNITROLLER="0x589d63300976759a0fc74ea6fA7D951f581252D7"
SEL_BORROW_STORED="0x17bfdfbc"  # borrowBalanceStored(address)
SEL_ACCT_LIQ="0x5ec88c79"      # getAccountLiquidity(address)
SEL_ASSETS_IN="0xabfceffc"     # getAssetsIn(address)
SEL_SNAPSHOT="0xc37f68e2"      # getAccountSnapshot(address)

def enc_addr(a):
    return a.lower().replace("0x","").rjust(64,"0")

def rpc_batch(calls, rpc_idx=0):
    """calls: list of (method, params) -> results in order, with fallback RPCs."""
    out=[]
    for attempt in range(6):
        R=RPCS[rpc_idx % len(RPCS)]
        try:
            payload=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
            r=requests.post(R,json=payload,timeout=90)
            j=r.json()
            if isinstance(j,list):
                byid={x.get('id'):x for x in j}
                ok=True
                res=[]
                for i in range(len(calls)):
                    x=byid.get(i)
                    if x is None or 'error' in x:
                        res.append(None); ok=False
                    else:
                        res.append(x.get('result'))
                if ok: return res
            time.sleep(1.0)
        except Exception as e:
            time.sleep(1.5)
        rpc_idx+=1
    return [None]*len(calls)

def main():
    borrowers=json.load(open('borrowers_unique.json'))
    # 1) current borrow balances
    debt={}
    for name,blist in borrowers.items():
        M=MARKETS[name]
        vals=[]
        for i in range(0,len(blist),40):
            chunk=blist[i:i+40]
            calls=[("eth_call",[{"to":M,"data":SEL_BORROW_STORED+enc_addr(b)},"latest"]) for b in chunk]
            res=rpc_batch(calls)
            for b,v in zip(chunk,res):
                vals.append((b,int(v,16) if v else None))
        debt[name]={b:v for b,v in vals if v and v>0}
        print(name,"historical",len(blist),"current debtors",len(debt[name]),file=sys.stderr)
    json.dump(debt,open('current_debtors.json','w'),indent=1)

    # 2) union of debtors, account liquidity
    allb=sorted(set(b for m in debt.values() for b in m))
    print("total current debtors:",len(allb),file=sys.stderr)
    liq={}
    for i in range(0,len(allb),40):
        chunk=allb[i:i+40]
        calls=[("eth_call",[{"to":UNITROLLER,"data":SEL_ACCT_LIQ+enc_addr(b)},"latest"]) for b in chunk]
        res=rpc_batch(calls)
        for b,v in zip(chunk,res):
            if v and len(v)>=194:
                err=int(v[2:66],16); col=int(v[66:130],16); short=int(v[130:194],16)
                liq[b]={"err":err,"liquidity":col,"shortfall":short}
            else:
                liq[b]=None
    json.dump(liq,open('account_liquidity.json','w'),indent=1)
    short=[b for b,v in liq.items() if v and v['shortfall']>0]
    print("SHORTFALL accounts:",len(short),file=sys.stderr)
    for b in short[:50]:
        print(b,liq[b],debt.get('caUSDC',{}).get(b),debt.get('caWARS',{}).get(b),debt.get('caWLD',{}).get(b),debt.get('caWBTC',{}).get(b),debt.get('caETH',{}).get(b),debt.get('caWBRL',{}).get(b),file=sys.stderr)

if __name__=="__main__":
    main()

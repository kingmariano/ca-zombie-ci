import json, urllib.request

def llama(chain, addrs):
    addrs=[a for a in addrs if a]
    if not addrs: return {}
    q=",".join(f"{chain}:{a}" for a in addrs)
    with urllib.request.urlopen(f"https://coins.llama.fi/prices/current/{q}", timeout=30) as r:
        d=json.load(r)
    return {k.split(':')[-1].lower():v['price'] for k,v in d.get('coins',{}).items()}

DEC_ETH={'pETH':18,'pDAI':18,'pUSDT':6,'pUSDC':6,'pWBTC':8,'pUNI':18,'pYFII':18,'pLRC':18,'pxLON':18,'pRAI':18}
def breakdown(name, chainid, path, decmap, eth_native_price=None):
    d=json.load(open(path))
    mks=d['markets']
    und=[m.get('underlying') for m in mks if m.get('underlying')]
    real=llama(chainid, und)
    tot_cash=tot_claim=tot_res=tot_borr=0
    rows=[]
    for m in mks:
        sym=m['symbol']; dec=decmap.get(sym,18)
        pu=None
        if m.get('underlying'): pu=real.get(m['underlying'].lower())
        if pu is None and sym in ('pETH','pBNB') and eth_native_price: pu=eth_native_price
        if pu is None:
            # fall back to oracle
            op=m.get('oraclePrice'); pu=op/10**(36-dec) if op else 0
        cash=(m.get('cash') or 0)/10**dec*pu
        claim=((m.get('totalSupply') or 0)*(m.get('exchangeRateStored') or 0)/1e18)/10**dec*pu
        res=(m.get('totalReserves') or 0)/10**dec*pu
        borr=(m.get('totalBorrows') or 0)/10**dec*pu
        tot_cash+=cash; tot_claim+=claim; tot_res+=res; tot_borr+=borr
        rows.append((sym,round(cash),round(claim),round(res),round(borr)))
    print(f"== {name}: cash ${tot_cash:,.0f} | supplier claims (H-O) ${tot_claim:,.0f} | reserves (P) ${tot_res:,.0f} | borrows ${tot_borr:,.0f}")
    for r in rows: print(f"   {r[0]:7s} cash ${r[1]:>9,} claim ${r[2]:>9,} reserves ${r[3]:>9,} borrows ${r[4]:>8,}")
    return dict(cash=tot_cash, claim=tot_claim, reserves=tot_res, borrows=tot_borr, rows=rows)

out={}
out['ethereum']=breakdown('ethereum',1,'/home/heisenberg/CA/wepiggy/analysis/eth-markets.json',DEC_ETH, eth_native_price=None)
# ETH native price from real feed? use pETH oracle via llama WETH
out['arbitrum']=breakdown('arbitrum',42161,'/home/heisenberg/CA/wepiggy/analysis/arb-markets.json',{'pETH':18,'pWBTC':8,'pUSDC':6,'pUSDT':6,'pLINK':18,'pDAI':18})
out['optimism']=breakdown('optimism',10,'/home/heisenberg/CA/wepiggy/analysis/op-markets.json',{k:(8 if k=='pWBTC' else 6 if k in ('pUSDC','pUSDT') else 18) for k in ['pETH','pUSDC','pUSDT','pDAI','pWBTC','pLINK','pOP']})
out['bsc']=breakdown('bsc',56,'/home/heisenberg/CA/wepiggy/analysis/bsc-markets.json',{'pBNB':18,'pETH':18,'pBTCB':18,'pDAI':18,'pUSDT':18,'pUSDC':18,'pBUSD':18,'pDOT':18,'pUNI':18,'pCAKE':18,'pLTC':18,'pLINK':18,'pADA':18,'pFIL':18,'pNULS':8,'pMASK':18})
json.dump({k:{kk:vv for kk,vv in v.items() if kk!='rows'} for k,v in out.items()}, open('/home/heisenberg/CA/wepiggy/analysis/value-breakdown.json','w'), indent=1)

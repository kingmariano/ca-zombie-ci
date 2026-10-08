"""Per-chain corrected Hundred-class scan with fine grids + oracle freshness check."""
import json, math, urllib.request, sys

def llama(chain, addrs):
    if not addrs: return {}
    q=",".join(f"{chain}:{a}" for a in addrs)
    try:
        with urllib.request.urlopen(f"https://coins.llama.fi/prices/current/{q}", timeout=30) as r:
            d=json.load(r)
        return {k.split(':')[-1].lower():v['price'] for k,v in d.get('coins',{}).items()}
    except Exception as e:
        print('llama err', e); return {}

DEC={'pETH':18,'pDAI':18,'pUSDT':6,'pUSDC':6,'pWBTC':8,'pUNI':18,'pYFII':18,'pLRC':18,'pxLON':18,'pRAI':18,
     'pLINK':18,'pOP':18,'pBNB':18,'pBTCB':8,'pBUSD':18,'pDOT':18,'pCAKE':18,'pLTC':8,'pADA':18,'pFIL':18,'pMASK':18,'pNULS':18}

def prep(chain, d, chainid):
    mks=[]
    for m in d['markets']:
        dec=DEC.get(m['symbol'],18)
        op=m.get('oraclePrice')
        oracle_usd=op/10**(36-dec) if op else None
        raw=m.get('totalSupply') or 0
        xr=m.get('exchangeRateStored') or 0
        cash=m.get('cash') or 0
        V_und=raw*xr/1e18/10**dec
        C_und=cash/10**dec
        mintp=m.get('pTokenMintGuardianPaused'); borrowp=m.get('pTokenBorrowGuardianPaused')
        if mintp is None: mintp=m.get('mintGuardianPaused')
        if borrowp is None: borrowp=m.get('borrowGuardianPaused')
        mks.append(dict(chain=chain,symbol=m['symbol'],cToken=m['cToken'],underlying=m.get('underlying'),
                        T=raw, cf=(m.get('collateralFactorMantissa') or 0)/1e18,
                        V_und=V_und,C_und=C_und,oracle_usd=oracle_usd,
                        mint_paused=bool(mintp), borrow_paused=bool(borrowp),
                        reserves=m.get('totalReserves'), borrows=m.get('totalBorrows')))
    # real prices
    und=[m['underlying'] for m in mks if m['underlying']]
    real=llama(chainid, und)
    eth_real=None
    for m in mks:
        if m['underlying'] is None:
            m['real_usd']=None
        else:
            m['real_usd']=real.get(m['underlying'].lower())
    return mks

def sim(V,T,cash,cf,B,D,X):
    if T<=0 or V<=0 or cf<=0 or B<=0: return None
    r0=V/T
    t=D/r0
    S=T+t
    rate2=(V+D+X)/S
    if cf*t*rate2 < B*(1-1e-12): return None
    k=max(1,math.ceil(B/(cf*rate2)))
    if k>t: return None
    r=t-k
    R=min(cash+D+X,(r+1)*rate2)
    return R+B-D-X, R, k

def scan(m, B, gridD, gridX):
    best=None
    for D in gridD:
        for X in gridX:
            o=sim(m['V_usd'],m['T'],m['cash_usd'],m['cf'],B,D,X)
            if o is None: continue
            if best is None or o[0]>best[0]: best=(o[0],D,X,o[1],o[2])
    return best

def run(chain, chainid, path, sym_dec=None):
    d=json.load(open(path))
    mks=prep(chainid, d, chainid)
    # USD using real price if available else oracle
    for m in mks:
        pu=m['real_usd'] or m['oracle_usd'] or 0
        m['price_used']=pu
        m['V_usd']=m['V_und']*pu
        m['cash_usd']=m['C_und']*pu
    print(f"\n##### {chain} #####")
    print("oracle vs real:")
    for m in mks:
        if m['oracle_usd'] and m['real_usd']:
            div=(m['oracle_usd']/m['real_usd']-1)*100
            print(f"  {m['symbol']:7s} oracle=${m['oracle_usd']:.6g} real=${m['real_usd']:.6g} div={div:+.2f}% cf={m['cf']} mintP={m['mint_paused']} borrowP={m['borrow_paused']}")
        else:
            print(f"  {m['symbol']:7s} oracle=${m['oracle_usd']} real={m['real_usd']} cf={m['cf']} mintP={m['mint_paused']} borrowP={m['borrow_paused']}")
    gridD=[0,1,10,100,1e3,1e4,1e5,1e6,1e7]
    gridX=[0,1,10,100,1e3,1e4,1e5,1e6,1e7,1e8]
    tot=0
    for m in mks:
        B=sum(o['cash_usd'] for o in mks if o is not m and not o['borrow_paused'])
        best=scan(m,B,gridD,gridX)
        r0=m['V_usd']/m['T'] if m['T'] else 0
        print(f"  {m['symbol']:7s} T={m['T']:.3e} V=${m['V_usd']:.2f} cash=${m['cash_usd']:.2f} cf={m['cf']:.2f} r0={r0:.3e} Bmax=${B:.0f} -> " + (f"best net=${best[0]:.2f} (D=${best[1]:.0f},X=${best[2]:.0f})" if best else "INFEASIBLE"))
        if best: tot=max(tot,best[0])
    return mks

if __name__=='__main__':
    run('ethereum',1,'/home/heisenberg/CA/wepiggy/analysis/eth-markets.json')
    run('arbitrum',42161,'/home/heisenberg/CA/wepiggy/analysis/arb-markets.json')
    run('optimism',10,'/home/heisenberg/CA/wepiggy/analysis/op-markets.json')
    run('bsc',56,'/home/heisenberg/CA/wepiggy/analysis/bsc-markets.json')

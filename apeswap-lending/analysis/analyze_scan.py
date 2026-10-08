#!/usr/bin/env python3
"""Analyze liquidity_scan.json: list accounts with shortfall and their composition."""
import json
from concurrent.futures import ThreadPoolExecutor
import urllib.request, time

RPCS = ['https://bsc-rpc.publicnode.com','https://bsc-dataseed.bnbchain.org','https://1rpc.io/bnb']
CMP='0xad48b2c9dc6709a560018c678e918253a65df86e'
SEL_ASSETS='0xabfceffc'   # getAssetsIn(address)
SEL_SNAP='0xc37f68e2'     # getAccountSnapshot(address)
SEL_PRICE='0x62563c31'    # getUnderlyingPriceInLen(address)
SEL_MKTS='0x8e8f294b'     # markets(address)
MARKETS = [
 ('oBANANA','0xC2E840BdD02B4a1d970C87A912D8576a7e61D314','0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95'),
 ('oETH','0xaA1b1E1f251610aE10E4D553b05C662e60992EEd','0x2170Ed0880ac9A755fd29B2688956BD959F933F8'),
 ('oBUSD','0x0096B6B49D13b347033438c4a699df3Afd9d2f96','0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'),
 ('oUSDT','0xdBFd516D42743CA3f1C555311F7846095D85F6Fd','0x55d398326f99059fF775485246999027B3197955'),
 ('oCake','0x3353f5bcfD7E4b146F2eD8F1e8D875733Cd754a7','0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82'),
 ('oUSDC','0x91B66a9Ef4f4CAD7F8AF942855C37Dd53520f151','0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'),
 ('oBNB','0x34878F6a484005AA90E7188a546Ea9E52b538F6f','0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
 ('oBTCB','0x5fce5D208DC325ff602c77497dC18F8EAdac8ADA','0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c'),
 ('oDOT','0x92D106c39aC068EB113B3Ecb3273B23Cd19e6e26','0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402'),
 ('oBNBx','0x3EE2bd8C244B5B3656673c2A49447e41D31F8E1e','0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275'),
]
MK={a.lower():s for s,a,u in MARKETS}

def rpc(method, params):
    body=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode()
    for url in RPCS:
        for _ in range(2):
            try:
                req=urllib.request.Request(url,data=body,headers={'content-type':'application/json','User-Agent':'curl/8.5.0'})
                with urllib.request.urlopen(req,timeout=30) as r: d=json.load(r)
                if 'error' in d: raise RuntimeError(d['error'])
                return d['result']
            except Exception:
                time.sleep(0.3)
    return None

def words(h):
    h=h[2:] if h.startswith('0x') else h
    return [int(h[i:i+64],16) for i in range(0,len(h),64)]

def call(to,data):
    return rpc('eth_call',[{'to':to,'data':data},'latest'])

def assets_in(a):
    out=call(CMP,SEL_ASSETS+a[2:].lower().rjust(64,'0'))
    w=words(out)
    if len(w)<2: return []
    off=w[0]//32
    n=w[off]
    return ['0x'+out[2+ (off+1+i)*64: 2+(off+2+i)*64][24:] for i in range(n)]

def snap(m,a):
    out=call(m,SEL_SNAP+a[2:].lower().rjust(64,'0'))
    if not out or len(out)<2+256: return None
    w=words(out)
    return {'err':w[0],'tokens':w[1],'borrows':w[2],'er':w[3]}

def main():
    res=json.load(open('/home/heisenberg/CA/apeswap-lending/analysis/liquidity_scan.json'))
    bad={a:r for a,r in res.items() if r.get('shortfall')}
    print('total accounts',len(res),'with stored shortfall',len(bad))
    tot=sum(r['shortfall'] for r in bad.values())/1e18
    print('sum shortfall USD', tot)
    # retry errored accounts with more patience
    errs=[a for a,r in res.items() if r.get('err') not in (0,)]
    print('errored',len(errs))
    def detail(a):
        try:
            ai=assets_in(a)
            rows=[]
            for m in ai:
                s=snap(m,a)
                if s: rows.append((m,s))
            return a,rows
        except Exception as e:
            return a,[('ERR',str(e)[:60])]
    with ThreadPoolExecutor(max_workers=5) as ex:
        dets=dict(ex.map(detail, list(bad.keys())+errs[:20]))
    out={}
    for a,rows in dets.items():
        print('====',a, 'shortfall_usd', res[a].get('shortfall',0)/1e18 if res[a].get('shortfall') else res[a].get('error','')[:40])
        rec=[]
        for m,s in rows:
            sym=[k for k,(ma,_,_) in zip(MK.keys(),[(x,y,z) for x,y,z in [(s2,s3,s4) for s2,s3,s4 in []]])] if False else None
            rec.append((m, s if isinstance(s,dict) else s))
            if isinstance(s,dict):
                print('   ',m,'tokens',s['tokens'],'borrows',s['borrows'],'er',s['er'])
            else:
                print('   ',m,s)
        out[a]=rec
    json.dump(out,open('/home/heisenberg/CA/apeswap-lending/analysis/shortfall_detail.json','w'),indent=1,default=str)

if __name__=='__main__':
    main()

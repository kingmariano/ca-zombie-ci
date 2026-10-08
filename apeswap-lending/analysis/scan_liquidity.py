#!/usr/bin/env python3
"""Scan all ApeSwap Lending cToken holders for liquidation shortfall (read-only).
Uses comptroller.getAccountLiquidityByLiquidationFactor + getAccountSnapshot.
"""
import json, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

RPCS = [
    'https://bsc-rpc.publicnode.com',
    'https://bsc-dataseed.bnbchain.org',
    'https://bsc-dataseed1.defibit.io',
    'https://1rpc.io/bnb',
]
CMP = '0xad48b2c9dc6709a560018c678e918253a65df86e'
MARKETS = {
 'oBANANA':('0xC2E840BdD02B4a1d970C87A912D8576a7e61D314',18,'0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95'),
 'oETH':('0xaA1b1E1f251610aE10E4D553b05C662e60992EEd',18,'0x2170Ed0880ac9A755fd29B2688956BD959F933F8'),
 'oBUSD':('0x0096B6B49D13b347033438c4a699df3Afd9d2f96',18,'0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'),
 'oUSDT':('0xdBFd516D42743CA3f1C555311F7846095D85F6Fd',18,'0x55d398326f99059fF775485246999027B3197955'),
 'oCake':('0x3353f5bcfD7E4b146F2eD8F1e8D875733Cd754a7',18,'0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82'),
 'oUSDC':('0x91B66a9Ef4f4CAD7F8AF942855C37Dd53520f151',18,'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'),
 'oBNB':('0x34878F6a484005AA90E7188a546Ea9E52b538F6f',18,'0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
 'oBTCB':('0x5fce5D208DC325ff602c77497dC18F8EAdac8ADA',18,'0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c'),
 'oDOT':('0x92D106c39aC068EB113B3Ecb3273B23Cd19e6e26',18,'0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402'),
 'oBNBx':('0x3E52b0fa5e17e2cb1b2e4b5f00ad2807a2e8e5ad',18,'0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275'),
}
# fix oBNBx addr
MARKETS['oBNBx']=('0x3EE2bd8C244B5B3656673c2A49447e41D31F8E1e',18,'0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275')

SEL_LIQ = None  # computed below via keccak
SEL_SNAP = None

def keccak_selector(sig):
    # minimal keccak256 via hashlib fallback: use eth-hash? Not installed; use precomputed known constants.
    raise NotImplementedError

# Precomputed selectors (verified via cast):
SEL_LIQ = '0x5513dd45'  # getAccountLiquidityByLiquidationFactor(address)
SEL_SNAP = '0xc37f68e2'  # getAccountSnapshot(address)

def rpc(method, params, rid=1):
    body = json.dumps({'jsonrpc':'2.0','id':rid,'method':method,'params':params}).encode()
    last = None
    for url in RPCS:
        for attempt in range(2):
            try:
                req = urllib.request.Request(url, data=body, headers={'content-type':'application/json','User-Agent':'curl/8.5.0'})
                with urllib.request.urlopen(req, timeout=30) as r:
                    d = json.load(r)
                if 'error' in d:
                    raise RuntimeError(d['error'])
                return d.get('result')
            except Exception as e:
                last = e
                time.sleep(0.4)
    raise last

def eth_call(to, data, block='latest'):
    return rpc('eth_call', [{'to':to,'data':data}, block])

def words(hexdata):
    h = hexdata[2:] if hexdata.startswith('0x') else hexdata
    return [int(h[i:i+64],16) for i in range(0,len(h),64)]

def liq(account):
    data = SEL_LIQ + account[2:].lower().rjust(64,'0')
    out = eth_call(CMP, data)
    w = words(out)
    return {'err':w[0],'liquidity':w[1],'shortfall':w[2]}

def snap(market, account):
    data = SEL_SNAP + account[2:].lower().rjust(64,'0')
    out = eth_call(market, data)
    w = words(out)
    return {'err':w[0],'tokens':w[1],'borrows':w[2],'exchangeRate':w[3]}

def main():
    holders = json.load(open('/home/heisenberg/CA/apeswap-lending/analysis/holders_unique.json'))
    print('holders', len(holders))
    # quick parallel liquidity scan (only accounts that hold non-BANANA assets first)
    res = {}
    def check(a):
        try:
            return a, liq(a)
        except Exception as e:
            return a, {'err':-1,'shortfall':None,'error':str(e)[:80]}
    with ThreadPoolExecutor(max_workers=6) as ex:
        for a, r in ex.map(check, holders):
            res[a] = r
    bad = {a:r for a,r in res.items() if r.get('shortfall')}
    errs = [a for a,r in res.items() if r.get('err') not in (0,)]
    print('checked', len(res), 'shortfall accounts', len(bad), 'other errors', len(errs))
    json.dump(res, open('/home/heisenberg/CA/apeswap-lending/analysis/liquidity_scan.json','w'), indent=1)
    for a, r in sorted(bad.items(), key=lambda kv:-kv[1]['shortfall'])[:50]:
        print('SHORTFALL', a, r)
    for a in errs[:10]:
        print('ERR', a, res[a])

if __name__ == '__main__':
    main()

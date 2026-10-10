#!/usr/bin/env python3
"""Comprehensive local-fork probe of the SKYDAO controller & token.

All actions run on a LOCAL anvil fork (read-only against BSC).
No keys; no mainnet transactions.
"""
import json, urllib.request, time, itertools

RPC = 'http://127.0.0.1:8545'
CTRL = '0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c'
USDT = '0x55d398326f99059fF775485246999027B3197955'
TOKEN = '0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c'
CFG = '0x85870c50677c142f5e37930915d8984cce7623e1'
OWNER = '0x6390ef00953dd0e0c5b15c50b28da36c2944d5d9'
CFG20 = '0xffa467ebb29be842b0898e7dccbb1a70a9cf2672'
CFG25 = '0xa210a12e4417ce53b3cd745e865e62b361d0796d'   # results[25]; sells 2.9B SKYDAO
PAIR  = '0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8'
DEAD  = '0x000000000000000000000000000000000000dEaD'
ATTACKER = '0x1111111111111111111111111111111111111111'
RECIPIENTS = [
    PAIR,                                             # results[16]
    '0x8e97f47963806306bff8b2caabcbfefab1923397',    # [6]
    '0x34d36a5cf68042ae64be6033aee3dd34b5257219',    # [14]
    '0x6c526c40a779c42233c1268b41a269621da07e46',    # [19]
    '0x9f9785aaf02157b465ab60420514bce0dc033391',    # [4]
    '0xdebb963f450718a7d1933c73aff605f27a990c02',    # [21]
]
WATCH = [ATTACKER, CTRL, PAIR, TOKEN, DEAD] + RECIPIENTS

def rpc(method, params, retries=5):
    for k in range(retries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),
                                         headers={'Content-Type':'application/json'})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            if k == retries-1: raise
            time.sleep(2)

def erc20_bal(token, addr):
    d = rpc('eth_call', [{'to':token,'data':'0x70a08231'+'0'*24+addr[2:].lower()}, 'latest'])
    return int(d['result'],16) if 'result' in d else 0

def snap():
    return {'usdt': {a: erc20_bal(USDT,a) for a in WATCH},
            'sky':  {a: erc20_bal(TOKEN,a) for a in WATCH}}

def sdiff(before, after):
    out = []
    for kind in ('usdt','sky'):
        for a in WATCH:
            d = after[kind][a] - before[kind][a]
            if d: out.append((kind, a, d))
    return out

def send(frm, to, data, value=0, gas=9_000_000):
    return rpc('eth_sendTransaction', [{'from':frm.lower(),'to':to.lower(),'data':data,'value':hex(value),'gas':hex(gas),'gasPrice':hex(10**9)}])

def fund(addr, bnb=50):
    rpc('anvil_setBalance', [addr, hex(bnb*10**18)])

def enc_u(v): return f'{v:064x}'
def enc_a(a): return '0'*24 + a[2:].lower()

def main():
    deploy_block = rpc('eth_blockNumber', [])['result']
    print(f"[fork] block {int(deploy_block,16)}")

    for a in [ATTACKER, OWNER, CFG20, CFG25, TOKEN, PAIR]:
        fund(a)
    results = {'fork_block': int(deploy_block,16), 'tests': []}

    # ---------- Test 1: real sell flow (impersonated holder -> pair) ----------
    print("\n===== T1: real sell flow: 1000 SKYDAO given to attacker, sell 100 SKYDAO to pair")
    send(CFG25, TOKEN, '0xa9059cbb'+enc_a(ATTACKER)+enc_u(1000*10**18))  # give tokens (impersonated whale)
    time.sleep(0.5)
    b = snap()
    r = None
    try:
        r = send(ATTACKER, TOKEN, '0xa9059cbb'+enc_a(PAIR)+enc_u(100*10**18))  # SELL 100 SKYDAO
    except Exception as e:
        r = {'error': str(e)}
    time.sleep(0.5)
    a = snap()
    print("sell result:", json.dumps(r)[:160])
    for k,addr,dv in sdiff(b,a):
        print(f"  {k.upper()} {addr} {dv/1e18:+.9f}")
    results['tests'].append({'name':'T1_real_sell_100SKY','result':str(r)[:200],
                             'diffs':[(k,ad,str(dv)) for k,ad,dv in sdiff(b,a)]})

    # ---------- Test 2: direct sellToken from token, status 0 and 1 ----------
    for status in (0,1):
        print(f"\n===== T2: sellToken(35 SKYDAO, {status}) directly from token")
        fund(TOKEN); fund(ATTACKER)
        b = snap()
        try:
            r = send(TOKEN, CTRL, '0x473a9ad9'+enc_u(35*10**18)+enc_u(status))
        except Exception as e:
            r = {'error': str(e)}
        time.sleep(0.5)
        a = snap()
        print("result:", json.dumps(r)[:200])
        for k,addr,dv in sdiff(b,a):
            print(f"  {k.upper()} {addr} {dv/1e18:+.9f}")
        results['tests'].append({'name':f'T2_sellToken_direct_status{status}','result':str(r)[:200],
                                 'diffs':[(k,ad,str(dv)) for k,ad,dv in sdiff(b,a)]})

    # ---------- Test 3: every public function from attacker ----------
    print("\n===== T3: all public functions from unprivileged attacker")
    CUR = snap()
    # selector map from disassembly
    sel = json.load(open('raw/sel2body.json'))
    sigs = {
        '0e35201b':('address,uint256',),'14ba5c09':(),'1e359efd':('uint256',),'2c00983e':('address',),
        '2c4e3db0':('uint256,address',),'3931092d':('address,uint256',),'473a9ad9':('uint256,uint256',),
        '53fe7d7e':('uint256,uint256',),'6d705ebb':('address,uint256',),'6f016bc8':('address',),
        '70e16b80':('uint256,uint256',),'714e4b9b':('uint256',),'715018a6':(),'7521d3a3':('address,uint256',),
        '78e97925':(),'79502c55':(),'874d6d81':(),'87d8d643':(),'8da5cb5b':(),'adee8014':('uint256,uint256',),
        'aff4d27e':(),'b0467deb':('uint256',),'b110544f':('address',),'b5cb15f7':(),'c9f54be0':('address,uint256',),
        'd56ad458':(),'dcd15367':('address',),'ddcde7cb':('address',),'df526413':('address',),
        'ec715a31':(),'f2fde38b':('address',),'f4c6aa92':('address,uint256'),'fa302aec':('uint256,address',),
        'ffd49c84':(),'200d2ed2':(),'22153832':(),'280e31cc':('address',),'2b334dac':('uint256,address',),
        '2b606426':('address',),'2b7b8838':('uint256',),'32dc2225':(),'32fe7b26':(),'4e1b0ae9':(),
    }
    for s in sorted(sel):
        types = sigs.get(s)
        if types is None:
            print(f"  ?? unknown selector {s}"); continue
        variants = []
        if len(types)==0:
            variants = [[]]
        elif len(types)==1:
            t = types[0]
            variants = [[]] if False else []
            variants.append(['attacker'] if t=='address' else [10**18])
            if t=='address': variants.append([CFG20])
        else:
            variants = [[('attacker' if t=='address' else 10**18) for t in types]]
        for v in variants:
            data = '0x'+s
            for t,x in zip(types,v):
                data += enc_a(ATTACKER if x=='attacker' else x) if t=='address' else enc_u(x)
            d = rpc('eth_call', [{'from':ATTACKER.lower(),'to':CTRL.lower(),'data':data,'gas':hex(8_000_000)}, 'latest'])
            st = 'OK' if 'result' in d else 'REVERT'
            sent=None; diffs=[]
            if st=='OK':
                try:
                    send(ATTACKER, CTRL, data)
                    time.sleep(0.3)
                    a = snap(); diffs = sdiff(CUR, a); CUR = a
                    sent='sent'
                except Exception as e:
                    sent = 'sendfail: '+str(e)[:80]
            line = f"  {s} {types} args={v} -> {st} {json.dumps(d.get('error',''))[:60]} {sent or ''}"
            print(line)
            if diffs:
                for k,ad,dv in diffs: print(f"      {k} {ad} {dv/1e18:+.9f}")
            results['tests'].append({'name':f'T3_{s}','args':str(v),'call':st,'error':str(d.get('error',''))[:200],'sent':sent,'diffs':[(k,ad,str(dv)) for k,ad,dv in diffs]})
        # refresh snapshot baseline for next probe
        CUR = snap()

    json.dump(results, open('raw/probe_full_results.json','w'), indent=1)
    print("\nsaved raw/probe_full_results.json")

if __name__ == '__main__':
    CUR = snap()
    main()

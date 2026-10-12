#!/usr/bin/env bash
# AbstraDEX Phase-2 heavy scan (runs in GitHub Actions, public repo — no secrets here).
# 1) Live scan of every AbstraDEX pair on 6 chains: reserves, balances (skim excess),
#    LP burn share, zero/tiny-reserve classification. Uses JSON-RPC batching to stay
#    under public-RPC rate limits.
# 2) LP holder identification for X Layer pools whose LP is NOT fully burned
#    (creation-window mints + recent transfers + current balances).
set -uo pipefail
cd "$(dirname "$0")/.."   # finding folder root
mkdir -p ci-out
export PYTHONUNBUFFERED=1

python3 - <<'PYEOF' 2>&1 | tee ci-out/scan_log.txt
import json, urllib.request, time

PUB = {
 'xlayer':      ('https://rpc.xlayer.tech',                             '0xa7afb6163c331ddb0845843889d6f9544328846f'),
 'morph':       ('https://rpc.morphl2.io',                              '0x174c4C03DfeA09682728A5959A253bf1F7C7766F'),
 'cronos_zkevm':('https://mainnet.zkevm.cronos.org',                    '0x76D1fC018676f8A973474C24F40A2e14e401b770'),
 'zeta':        ('https://zetachain-evm.blockpi.network/v1/rpc/public', '0x174c4C03DfeA09682728A5959A253bf1F7C7766F'),
 'zkfair':      ('https://rpc.zkfair.io',                               '0x174c4C03DfeA09682728A5959A253bf1F7C7766F'),
 'blast':       ('https://rpc.blast.io',                                '0xA7afb6163c331DDb0845843889D6f9544328846F'),
}
DEAD = '0x000000000000000000000000000000000000dead'
ZERO = '0x0000000000000000000000000000000000000000'
SEL = {'allPairsLength':'0x574f2ba3','allPairs':'0x1e3dd18b','token0':'0x0dfe1681','token1':'0xd21220a7',
       'getReserves':'0x0902f1ac','totalSupply':'0x18160ddd','balanceOf':'0x70a08231'}

def post(url, payload, retries=8):
    for a in range(retries):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                         headers={'Content-Type':'application/json','User-Agent':'zombie-ci/1.0'})
            return json.load(urllib.request.urlopen(req, timeout=60))
        except Exception as e:
            if a == retries-1: raise
            time.sleep(2.0*(a+1))

def batch(url, calls, size=10):
    """calls: list of (method, params). returns list of results in order."""
    out = []
    for i in range(0, len(calls), size):
        chunk = calls[i:i+size]
        payload = [{'jsonrpc':'2.0','id':j,'method':m,'params':p} for j,(m,p) in enumerate(chunk)]
        resp = post(url, payload)
        byid = {r['id']: r for r in (resp if isinstance(resp,list) else [resp])}
        for j in range(len(chunk)):
            r = byid.get(j, {})
            if 'result' in r: out.append(r['result'])
            else: out.append(None)
        time.sleep(0.05)
    return out

def ecall(to, data):
    return ('eth_call', [{'to':to,'data':data},'latest'])
def dec(x): return int(x,16) if x and x != '0x' else 0
def addr(x): return '0x'+x[-40:]
def enc_addr(a): return a.lower().replace('0x','').rjust(64,'0')
def enc_uint(n): return hex(n)[2:].rjust(64,'0')

results = {}
for chain,(url,factory) in PUB.items():
    t0=time.time()
    try:
        head = batch(url, [('eth_blockNumber',[]), ecall(factory,SEL['allPairsLength'])])
        tip = dec(head[0]); n = dec(head[1])
        print(f"[{chain}] tip={tip} factory={factory} allPairsLength={n}")
        calls=[ecall(factory, SEL['allPairs']+enc_uint(i)) for i in range(n)]
        raw = batch(url, calls, size=10)
        pairs = [addr(x) for x in raw if x]
        recs=[]
        for p in pairs:
            # per-pair batch: token0,token1,reserves,ts,dead,zero  (balances need token addrs -> second phase)
            r = batch(url, [ecall(p,SEL['token0']), ecall(p,SEL['token1']), ecall(p,SEL['getReserves']),
                            ecall(p,SEL['totalSupply']), ecall(p,SEL['balanceOf']+enc_addr(DEAD)),
                            ecall(p,SEL['balanceOf']+enc_addr(ZERO))], size=6)
            if not r or not r[0] or not r[1] or not r[2]:
                recs.append({'pair':p,'error':'read failed'}); continue
            t0a=addr(r[0]); t1a=addr(r[1])
            res=r[2]; r0=dec(res[2:66]); r1=dec(res[66:130])
            rec={'pair':p,'t0':t0a,'t1':t1a,'r0':str(r0),'r1':str(r1),'totalSupply':str(dec(r[3])),
                 'lpDead':str(dec(r[4])),'lpZero':str(dec(r[5]))}
            recs.append(rec)
        # balances in a second batched phase
        bal_calls=[]; idx=[]
        for k,rec in enumerate(recs):
            if 'error' in rec: continue
            bal_calls.append(ecall(rec['t0'], SEL['balanceOf']+enc_addr(rec['pair']))); idx.append((k,'b0'))
            bal_calls.append(ecall(rec['t1'], SEL['balanceOf']+enc_addr(rec['pair']))); idx.append((k,'b1'))
        bal = batch(url, bal_calls, size=10)
        for (k,f),v in zip(idx, bal):
            recs[k][f]=str(dec(v))
        zero_side=[]; tiny_side=[]; excess=[]; burn_hi=0; errors=0
        for rec in recs:
            if 'error' in rec or 'b0' not in rec: errors+=1; continue
            r0,r1,b0,b1=int(rec['r0']),int(rec['r1']),int(rec['b0']),int(rec['b1'])
            ts,dead,z=int(rec['totalSupply']),int(rec['lpDead']),int(rec['lpZero'])
            rec['skimExcess0']=str(max(0,b0-r0)); rec['skimExcess1']=str(max(0,b1-r1))
            if b0>r0 or b1>r1: excess.append(rec)
            if r0==0 and r1>0: zero_side.append({**rec,'zeroSide':'t0','other':rec['t1'],'otherAmt':str(r1)})
            if r1==0 and r0>0: zero_side.append({**rec,'zeroSide':'t1','other':rec['t0'],'otherAmt':str(r0)})
            if 0<r0<=10**6 and r1>10**15: tiny_side.append({**rec,'tinySide':'t0','other':rec['t1'],'otherAmt':str(r1)})
            if 0<r1<=10**6 and r0>10**15: tiny_side.append({**rec,'tinySide':'t1','other':rec['t0'],'otherAmt':str(r0)})
            if ts and (dead+z)*10000//ts >= 9990: burn_hi+=1
        results[chain]={'url':url,'factory':factory,'tip':tip,'pairs':len(recs),'errors':errors,
                        'lp_burned_ge_99_9pct':burn_hi,'skim_excess_pairs':excess,
                        'zero_reserve_pairs':zero_side,'tiny_reserve_pairs':tiny_side,'all_pairs':recs}
        print(f"[{chain}] scanned {len(recs)} pairs ({errors} errors) in {time.time()-t0:.0f}s; burned>=99.9%: {burn_hi}; "
              f"skim-excess: {len(excess)}; zero-side: {len(zero_side)}; tiny-side: {len(tiny_side)}")
    except Exception as e:
        print(f"[{chain}] SCAN FAILED: {e}")
        results[chain]={'error':str(e)}

json.dump(results, open('ci-out/scan_all_chains.json','w'), indent=1)
print("scan_all_chains.json written")
PYEOF

# ---- Part 2: LP holder identification for non-burned X Layer pools (100-block windows) ----
python3 - <<'PYEOF' 2>&1 | tee -a ci-out/scan_log.txt
import json, urllib.request, time

XL='https://rpc.xlayer.tech'
TRANSFER='0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
DEAD='0x000000000000000000000000000000000000dead'
ZERO='0x0000000000000000000000000000000000000000'
POOLS = {
 '0x0b07f323697348879bb21c44f8341e2511604858':'OKcat/WOKB (812.9 WOKB)',
 '0x09ff07229119a358e60dcbcb2d1918e5c69ba93f':'AIPEPE/WOKB (24.5 WOKB)',
 '0x91797202867eba02d4174d0f531790516ddbd5f3':'WOKB pool (5.9 WOKB)',
 '0x852e96ac40c61d2e8e501fc58f2e3c7d292fd941':'WOKB pool (4.2 WOKB)',
 '0x7d7756b4bd8900e204b0eb7b9e341586f7cb23f4':'BabyOKB/WOKB (29.2 WOKB)',
}
def post(url,payload,retries=8):
    for a in range(retries):
        try:
            req=urllib.request.Request(url,data=json.dumps(payload).encode(),headers={'Content-Type':'application/json','User-Agent':'zombie-ci/1.0'})
            return json.load(urllib.request.urlopen(req,timeout=60))
        except Exception:
            if a==retries-1: raise
            time.sleep(2.0*(a+1))
def batch(url,calls,size=10):
    out=[]
    for i in range(0,len(calls),size):
        chunk=calls[i:i+size]
        payload=[{'jsonrpc':'2.0','id':j,'method':m,'params':p} for j,(m,p) in enumerate(chunk)]
        resp=post(url,payload)
        byid={r['id']:r for r in (resp if isinstance(resp,list) else [resp])}
        for j in range(len(chunk)):
            r=byid.get(j,{}); out.append(r.get('result'))
        time.sleep(0.05)
    return out
def dec(x): return int(x,16) if x and x!='0x' else 0
def ecall(to,data): return ('eth_call',[{'to':to,'data':data},'latest'])
def elogs(pool,f,t): return ('eth_getLogs',[{'address':pool,'fromBlock':hex(f),'toBlock':hex(t),'topics':[TRANSFER]}])
def enc_addr(a): return a.lower().replace('0x','').rjust(64,'0')

out={}
for pool,desc in POOLS.items():
    t0=time.time()
    tip=dec(post(XL,{'jsonrpc':'2.0','id':1,'method':'eth_blockNumber','params':[]})['result'])
    lo,hi=326101,tip
    # binary search creation block
    while lo<hi:
        mid=(lo+hi)//2
        c=post(XL,{'jsonrpc':'2.0','id':1,'method':'eth_getCode','params':[pool,hex(mid)]})['result']
        if c and c!='0x': hi=mid
        else: lo=mid+1
    created=lo
    wins=[]
    # creation window (5k blocks) + recent window (25k blocks), 100-block windows
    for f in range(created, created+5000, 100): wins.append((f,min(f+99,created+5000)))
    for f in range(max(created,tip-25000), tip, 100): wins.append((f,min(f+99,tip)))
    logs=batch(XL,[elogs(pool,f,t) for f,t in wins],size=10)
    evs=[]
    for ls in logs:
        for l in (ls or []):
            if l['address'].lower()!=pool.lower(): continue
            evs.append((dec(l['blockNumber']),'0x'+l['topics'][1][-40:],'0x'+l['topics'][2][-40:],
                        dec(l['data']) if l['data'] not in ('0x','') else 0))
    cands=set()
    for e in evs: cands.add(e[1]); cands.add(e[2])
    cands -= {ZERO,DEAD}
    bals=batch(XL,[ecall(pool,'0x70a08231'+enc_addr(a)) for a in cands],size=10)
    holders={}
    for a,v in zip(cands,bals):
        v=dec(v)
        if v>0: holders[a]=v
    ts=dec(post(XL,{'jsonrpc':'2.0','id':1,'method':'eth_call','params':[{'to':pool,'data':'0x18160ddd'},'latest']})['result'])
    deadbal=dec(post(XL,{'jsonrpc':'2.0','id':1,'method':'eth_call','params':[{'to':pool,'data':'0x70a08231'+enc_addr(DEAD)},'latest']})['result'])
    covered=sum(holders.values())
    out[pool]={'desc':desc,'created_block':created,'tip':tip,'windows':len(wins),'events':len(evs),
               'totalSupply':str(ts),'lpDead':str(deadbal),
               'holders':{a:str(v) for a,v in sorted(holders.items(),key=lambda x:-x[1])[:20]},
               'covered':str(covered),'coverage_complete':covered+deadbal>=ts}
    print(f"[lp] {pool} {desc}: created={created} windows={len(wins)} events={len(evs)} holders={len(holders)} "
          f"covered={covered} dead={deadbal} ts={ts} complete={covered+deadbal>=ts} ({time.time()-t0:.0f}s)")
    for a,v in sorted(holders.items(),key=lambda x:-x[1])[:6]:
        print(f"      {a} {v}")

json.dump(out, open('ci-out/lp_holders.json','w'), indent=1)
print("lp_holders.json written")
PYEOF

echo "[ci] abstradex scan done"
ls -la ci-out/

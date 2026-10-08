import sys, json, time, subprocess, urllib.request
sys.path.insert(0,'/home/heisenberg/CA/wepiggy/analysis')
import rpc
T0='0x2dd79f4fccfd18c360ce7f9132f3621bf05eee18f995224badb32d17f172df73'
d=json.load(open('/home/heisenberg/CA/wepiggy/analysis/op-markets.json'))
C=d['comptroller']
def fetch(a, page):
    u=f"https://optimism.blockscout.com/api?module=logs&action=getLogs&fromBlock=0&toBlock=latest&address={a}&topic0={T0}&page={page}&offset=1000"
    req=urllib.request.Request(u, headers={'User-Agent':'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36'})
    with urllib.request.urlopen(req, timeout=60) as r: j=json.load(r)
    res=j.get('result')
    return [{'data':x['data']} for x in res] if isinstance(res,list) else []
ev={}
for m in d['markets']:
    allr=[]; page=1
    while True:
        try: res=fetch(m['cToken'], page)
        except Exception as e: print(m['symbol'],'page',page,'ERR',str(e)[:60], flush=True); break
        allr+=res
        if len(res)<1000: break
        page+=1; time.sleep(1)
        if page>6: break
    ev[m['symbol']]=allr; print(m['symbol'], len(allr), flush=True); time.sleep(0.8)
json.dump(ev, open('/home/heisenberg/CA/wepiggy/analysis/op-borrow-events.json','w'))
url='https://mainnet.optimism.io'
sel_bb=subprocess.run(['cast','sig','borrowBalanceStored(address)'],capture_output=True,text=True).stdout.strip()
sel_liq=subprocess.run(['cast','sig','getAccountLiquidity(address)'],capture_output=True,text=True).stdout.strip()
mk={m['symbol']:m for m in d['markets']}
pairs=[]
for sym,lst in ev.items():
    for b in set('0x'+x['data'][2:][24:64] for x in lst):
        pairs.append((sym,b))
print('pairs', len(pairs), flush=True)
debts=[]; CH=30
for i in range(0,len(pairs),CH):
    chunk=pairs[i:i+CH]
    calls=[(mk[s]['cToken'],sel_bb+rpc.enc_addr(b)) for s,b in chunk]
    try: rr=rpc.batch(url,calls,chunk=CH)
    except Exception: rr=[None]*len(chunk)
    for (s,b),res in zip(chunk,rr):
        if res and res!='0x':
            v=rpc.to_int(res)
            if v and v>0: debts.append((s,b,v))
accts=sorted(set(b for _,b,_ in debts))
print('accounts with debt:', len(accts), flush=True)
liq=[]
for i in range(0,len(accts),CH):
    chunk=accts[i:i+CH]
    calls=[(C,sel_liq+rpc.enc_addr(b)) for b in chunk]
    try: rr=rpc.batch(url,calls,chunk=CH)
    except Exception: rr=[None]*len(chunk)
    for b,res in zip(chunk,rr):
        if res and len(res)>=2+64*3:
            bb=bytes.fromhex(res[2:]); sf=int.from_bytes(bb[64:96],'big')
            if sf>0: liq.append((b,sf))
print('shortfall accounts:', len(liq), flush=True)
for x in sorted(liq,key=lambda y:-y[1])[:15]: print('  ',x[0],x[1]/1e18, flush=True)
json.dump({'debts':debts,'shortfall':liq}, open('/home/heisenberg/CA/wepiggy/analysis/op-liquidations.json','w'))
print('DONE', flush=True)

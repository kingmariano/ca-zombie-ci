import json, urllib.request, concurrent.futures as cf, collections
infos=json.load(open('contract_infos.json'))
targets=[]
for a,i in infos.items():
    lab=(i.get('label') or '').lower()
    if any(p in lab for p in ['astrovault','eris','barch','balanced','liquid.finance','pampit','bolt-market','bolt-router','vote-escrow']):
        targets.append(a)
print('targets:',len(targets),flush=True)
def get(url):
    for _ in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as r: return json.load(r)
        except Exception as e: err=e
    return {'error':str(err)}
def bal(addr):
    d=get(f'https://api.mainnet.archway.io/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=1000')
    return addr, d.get('balances',[])
bals={}
with cf.ThreadPoolExecutor(24) as ex:
    for a,b in ex.map(bal, targets): bals[a]=b
json.dump(bals,open('key_contract_balances.json','w'))
grp=collections.defaultdict(lambda: collections.defaultdict(float))
for a,b in bals.items():
    lab=(infos[a].get('label') or '').lower()
    g=('astrovault' if 'astrovault' in lab else 'eris' if ('eris' in lab or 'barch' in lab or 'amparch' in lab) else
       'balanced' if 'balanced' in lab else 'liquid.finance' if 'liquid.finance' in lab else
       'pampit' if 'pampit' in lab else 'bolt' if 'bolt-' in lab else 'other')
    for x in b: grp[g][x['denom']]+=float(x['amount'])
for g,dm in grp.items():
    print('==',g)
    for d,amt in sorted(dm.items(),key=lambda x:-x[1])[:14]:
        if d=='aarch': print(f'   aarch {amt/1e18:,.2f}')
        elif d.startswith('ibc/'): print(f'   {d[:26]} {amt:,.2f}')
        else: print(f'   {d} {amt:,.2f}')
print('DONE')

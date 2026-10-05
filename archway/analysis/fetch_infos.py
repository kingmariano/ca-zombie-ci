import json, urllib.request, concurrent.futures as cf, collections, time
res=json.load(open('code_contracts.json'))
base='https://api.mainnet.archway.io'
allc=[c for v in res.values() for c in v]
print('contracts to fetch:',len(allc),flush=True)
def get(url):
    for _ in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as r: return json.load(r)
        except Exception as e: err=e
    return {'error':str(err)}
def info(addr):
    d=get(f'{base}/cosmwasm/wasm/v1/contract/{addr}')
    ci=d.get('contract_info',{})
    return addr, {'code_id':ci.get('code_id'),'creator':ci.get('creator'),'admin':ci.get('admin'),'label':ci.get('label')}
infos={}
with cf.ThreadPoolExecutor(24) as ex:
    for n,(addr,i) in enumerate(ex.map(info, allc)):
        infos[addr]=i
        if n%1000==0: print(n,flush=True)
json.dump(infos,open('contract_infos.json','w'))
labels=collections.Counter(i.get('label','') for i in infos.values())
print('n labels:',len(labels))
for lab,n in labels.most_common(60): print(n,'|',lab)

import json, urllib.request, time, sys

UA={'User-Agent':'Mozilla/5.0'}
def get(url):
    req=urllib.request.Request(url, headers=UA)
    for _ in range(3):
        try:
            return json.load(urllib.request.urlopen(req, timeout=30))
        except Exception as e:
            print('retry', e); time.sleep(2)
    raise SystemExit('fail '+url)

DEP=set(['0x90890809c654f11d6e72a28fa60149770a0d11ec6c92319d6ceb2bb0a4ea1a15',
         '0xf279e6a1f5e320cca91135676d9cb6e44ca8a08c0b88342bcdb1144f6511b568',
         '0xbb757047c2b5f3974fe26b7c10f732e7bce710b0952a71082702781e62ae0595'])
contracts={
 'chicken':('0x87ae4928f6582376a0489e9f70750334bbc2eb35',0),
 'gov':('0x4dac3e07316d2a31baabb252d89663dee8f76f09',2),
 'mystery':('0x07261a6e37adbfab11e6474bca54634c7782b195',0),
 'star':('0xb60c12d2a4069d339f49943fc45df6785b436096',0),
 'bdp':('0x0de845955e2bf089012f682fe9bc81dd5f11b372',1),
}
out={}
for name,(addr,wpid) in contracts.items():
    users={}
    url=f'https://eth.blockscout.com/api/v2/addresses/{addr}/logs'
    n=0
    while url and n<3000:
        d=get(url)
        for it in d.get('items',[]):
            n+=1
            t=(it.get('topics') or [None])[0]
            if t not in DEP: continue
            dec=it.get('decoded') or {}
            params=dec.get('parameters') or []
            vals={p['name']:p.get('value') for p in params}
            pid=vals.get('pid'); user=vals.get('user')
            if pid is None or user is None: continue
            try: pid=int(pid,16) if isinstance(pid,str) else int(pid)
            except: continue
            if pid!=wpid: continue
            users.setdefault(user,0); users[user]+=1
        np=d.get('next_page_params')
        url=f'https://eth.blockscout.com/api/v2/addresses/{addr}/logs?{urllib.parse.urlencode(np)}' if np else None
    out[name]={'addr':addr,'wpid':wpid,'n_logs':n,'users':list(users.keys())}
    print(name, 'logs',n,'weth-pid users',len(users))
json.dump(out, open('weth_pool_users.json','w'), indent=1)

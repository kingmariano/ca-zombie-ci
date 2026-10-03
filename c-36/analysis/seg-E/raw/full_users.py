import json, urllib.request, urllib.parse, time

UA={'User-Agent':'Mozilla/5.0'}
def get(url):
    req=urllib.request.Request(url, headers=UA)
    for _ in range(4):
        try: return json.load(urllib.request.urlopen(req, timeout=30))
        except Exception as e: print('retry', e); time.sleep(2)
    raise SystemExit('fail '+url)

SIGS={
 'dep':'0x90890809c654f11d6e72a28fa60149770a0d11ec6c92319d6ceb2bb0a4ea1a15',
 'wd':'0xf279e6a1f5e320cca91135676d9cb6e44ca8a08c0b88342bcdb1144f6511b568',
 'ewd':'0xbb757047c2b5f3974fe26b7c10f732e7bce710b0952a71082702781e62ae0595',
}
contracts={
 'chicken':('0x87ae4928f6582376a0489e9f70750334bbc2eb35',0,11360000),
 'gov':('0x4dac3e07316d2a31baabb252d89663dee8f76f09',2,13300000),
 'mystery':('0x07261a6e37adbfab11e6474bca54634c7782b195',0,10910000),
 'star':('0xb60c12d2a4069d339f49943fc45df6785b436096',0,11250000),
 'bdp':('0x0de845955e2bf089012f682fe9bc81dd5f11b372',1,12020000),
}
out={}
for name,(addr,pid,fromb) in contracts.items():
    users=set(); counts={}
    for ev,sig in SIGS.items():
        page=1; n=0
        while True:
            q=urllib.parse.urlencode({'module':'logs','action':'getLogs','fromBlock':fromb,'toBlock':'latest',
                'address':addr,'topic0':sig,'topic0_2_opr':'and','topic2':'0x'+format(pid,'064x'),
                'page':page,'offset':1000})
            d=get('https://eth.blockscout.com/api?'+q)
            r=d.get('result')
            if not isinstance(r,list) or not r: break
            for x in r:
                t=x['topics']
                u='0x'+t[1][-40:]
                users.add(u); n+=1
            if len(r)<1000: break
            page+=1
        counts[ev]=n
    out[name]={'addr':addr,'pid':pid,'users':sorted(users),'counts':counts}
    print(name, 'counts',counts,'unique users',len(users))
json.dump(out, open('weth_pool_users_full.json','w'), indent=1)

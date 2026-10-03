import json, urllib.request, urllib.parse, time
UA={'User-Agent':'Mozilla/5.0'}
def get(url, tries=6):
    for i in range(tries):
        try:
            req=urllib.request.Request(url, headers=UA)
            return json.load(urllib.request.urlopen(req, timeout=30))
        except Exception as e:
            time.sleep(3+3*i)
    return None
WETH='0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
contracts={
 'chicken':'0x87ae4928f6582376a0489e9f70750334bbc2eb35',
 'gov':'0x4dac3e07316d2a31baabb252d89663dee8f76f09',
 'mystery':'0x07261a6e37adbfab11e6474bca54634c7782b195',
 'star':'0xb60c12d2a4069d339f49943fc45df6785b436096',
 'bdp':'0x0de845955e2bf089012f682fe9bc81dd5f11b372',
}
out={}
for name,addr in contracts.items():
    url=f'https://eth.blockscout.com/api/v2/addresses/{addr}/token-transfers?token={WETH}'
    cp=set(); n=0; pages=0
    while url and pages<200:
        d=get(url)
        if not d: break
        for it in d.get('items',[]):
            n+=1
            for side in ('from','to'):
                h=it.get(side,{}).get('hash')
                if h and h.lower()!=addr.lower(): cp.add(h)
        np=d.get('next_page_params')
        url=f'https://eth.blockscout.com/api/v2/addresses/{addr}/token-transfers?token={WETH}&{urllib.parse.urlencode(np)}' if np else None
        pages+=1
        time.sleep(0.3)
    out[name]={'addr':addr,'counterparties':sorted(cp),'n_transfers':n,'pages':pages}
    print(name,'transfers',n,'pages',pages,'counterparties',len(cp))
json.dump(out, open('weth_counterparties.json','w'), indent=1)

import json, os, sys, urllib.request, time
UA="Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0"
seg=[a.lower() for a in json.load(open('../seg_A_addrs.json'))]
children=["0xbf4ed7b27f1d666546e30d74d50d173d20bca754","0x23ea10cc1e6ebdb499d24e45369a35f43627062f",
"0x26b7dedab33c58bc9edc26d9cd81b8eee43c24dd","0xea4df6f41e90dd7b6c482bda228925de159c03f5",
"0x02b9806a64cb05f02aa8dcc1c178b88159a61304"]
os.makedirs('raw/src',exist_ok=True)
for a in seg+children:
    f='raw/src/%s.json'%a
    if os.path.exists(f): continue
    url='https://eth.blockscout.com/api/v2/smart-contracts/%s'%a
    try:
        req=urllib.request.Request(url,headers={"User-Agent":UA})
        d=json.loads(urllib.request.urlopen(req,timeout=45).read().decode())
        json.dump(d,open(f,'w'))
        print('OK',a,d.get('name'),'verified=',d.get('is_verified'),'proxy=',(d.get('proxy_type') or d.get('implementations') is not None))
    except Exception as e:
        print('FAIL',a,repr(e)[:120])
    time.sleep(0.4)

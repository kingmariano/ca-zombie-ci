import urllib.request, json, time
UA={"User-Agent":"Mozilla/5.0"}
DEN="8FEFAE6AECF6E2A255585617F781F35A8D5709A545A804482A261C0C9548A9D3"
def get(url):
    for i in range(3):
        try:
            req=urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r: return json.loads(r.read())
        except Exception as e:
            err=e; time.sleep(2)
    raise err
matches=[]
base="https://lcd.osmosis.zone/osmosis/gamm/v1beta1/pools?pagination.limit=1000"
off=0
while True:
    d=get(base+f"&pagination.offset={off}")
    pools=d.get('pools',[])
    if not pools: break
    for p in pools:
        toks=json.dumps(p)
        if DEN in toks:
            matches.append(p)
    off+=1000
    print("gamm fetched",off,"matches",len(matches))
    if len(pools)<1000: break
open('raw/osmosis_gamm_matches.json','w').write(json.dumps(matches,indent=1))
print("=== gamm matches ===")
for p in matches:
    print("id:",p.get('id'),"| tokens:",[(t['denom'][:14], t['amount']) for t in p.get('poolAssets',[]) or p.get('pool_assets',[])])
# CL pools
matches2=[]
base2="https://lcd.osmosis.zone/osmosis/concentratedliquidity/v1beta1/pools?pagination.limit=1000"
off=0
while True:
    try: d=get(base2+f"&pagination.offset={off}")
    except Exception as e: print("CL err",e); break
    pools=d.get('pools',[])
    if not pools: break
    for p in pools:
        if DEN in json.dumps(p): matches2.append(p)
    off+=1000
    print("CL fetched",off,"matches",len(matches2))
    if len(pools)<1000: break
open('raw/osmosis_cl_matches.json','w').write(json.dumps(matches2,indent=1))
print("=== CL matches ===")
for p in matches2:
    print("id:",p.get('id'),"| token0:",p.get('token0'),"| token1:",p.get('token1'))

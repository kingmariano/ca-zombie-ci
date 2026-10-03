import json, subprocess, urllib.request, urllib.parse, time, concurrent.futures
RPC='https://ethereum-rpc.publicnode.com'
UA={'User-Agent':'Mozilla/5.0'}
D='0x93314Ee69BF8F943504654f9a8ECed0071526439'
T='0x0c48250eb1f29491f1efbeec0261eb556f0973c7'
def get(url,tries=6):
    for i in range(tries):
        try:
            req=urllib.request.Request(url,headers=UA)
            return json.load(urllib.request.urlopen(req,timeout=30))
        except Exception as e:
            time.sleep(3+3*i)
    return None
holders=[]
url=f'https://eth.blockscout.com/api/v2/tokens/{T}/holders'
pages=0
while url and pages<60:
    d=get(url)
    if not d: break
    for it in d.get('items',[]):
        holders.append((it['address']['hash'], int(it['value'])))
    np=d.get('next_page_params')
    url=f'https://eth.blockscout.com/api/v2/tokens/{T}/holders?{urllib.parse.urlencode(np)}' if np else None
    pages+=1
    time.sleep(0.3)
print('holders fetched',len(holders),'pages',pages, flush=True)
def ga(u):
    r=subprocess.run(['cast','call',D,'getAccount(address)(address,uint256,uint256)',u,'--json','--rpc-url',RPC],capture_output=True,text=True)
    if r.returncode!=0: return (u,0,0)
    try:
        v=json.loads(r.stdout)
        return (u,int(v[1]),int(v[2]))
    except Exception: return (u,0,0)
with concurrent.futures.ThreadPoolExecutor(max_workers=16) as ex:
    res=list(ex.map(ga,[h for h,_ in holders]))
totw=0; tota=0; nz=0; top=[]
for u,w,a in res:
    totw+=w; tota+=a
    if w>0: nz+=1; top.append((w,u))
print('scanned',len(res),'nonzero withdrawable',nz,'sum withdrawable',totw/1e18,'sum accumulative',tota/1e18, flush=True)
for w,u in sorted(top,reverse=True)[:15]: print('  ',u,w/1e18, flush=True)
json.dump({'n':len(res),'sum_withdrawable':totw,'sum_accum':tota,'nonzero':nz,'top':[{'user':u,'w':w} for w,u in sorted(top,reverse=True)[:50]]},open('aimbot_scan.json','w'),indent=1)
print('DONE')

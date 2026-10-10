import json, subprocess
v1=json.load(open('dedust_v1_pools.json'))
scored=[]
for p in v1:
    try: s=int(p.get('left_token_reserve') or 0)+int(p.get('right_token_reserve') or 0)
    except: s=0
    scored.append((s,p['address'],p.get('left_token_symbol'),p.get('right_token_symbol')))
scored.sort(key=lambda x:-x[0])
addrs=[a for _,a,_,_ in scored[:30]]
r=subprocess.run(['curl','-s','-X','POST','https://tonapi.io/v2/accounts/_bulk','-H','Content-Type: application/json','-d',json.dumps({'account_ids':addrs})],capture_output=True,text=True).stdout
j=json.loads(r)
tot=0; out=[]
for a in j['accounts']:
    tot += int(a['balance'])
    line=f"{a['address'][:24]} bal={a['balance']} ifaces={a.get('interfaces')} status={a.get('status')}"
    print(line); out.append(line)
print('top30 v1 pools total TON balance:', tot/1e9)
open('/home/heisenberg/CA/non-evm-cluster/analysis/ton/dedust/v1_pool_sample.txt','w').write('\n'.join(out)+f"\ntotal_top30_ton={tot/1e9}\n")

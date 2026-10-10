import json, subprocess, time
FACTORY='EQBfBWT7X2BHg9tXAxzhz2aKiNTU1tpt5NsiK0uSDW_YAJ67'
def post(url, body, tries=6):
    for a in range(tries):
        r=subprocess.run(['curl','-s','-X','POST',url,'-H','Content-Type: application/json','-d',json.dumps(body)],capture_output=True,text=True).stdout
        try:
            j=json.loads(r)
            if isinstance(j,dict) and j.get('success'): return j
            last=j
        except Exception: last=r[:150]
        time.sleep(3)
    return last
def get(url, tries=6):
    for a in range(tries):
        r=subprocess.run(['curl','-s',url],capture_output=True,text=True).stdout
        try:
            j=json.loads(r)
            if isinstance(j,dict) and 'balances' in j: return j
            last=j
        except Exception: last=r[:150]
        time.sleep(3)
    return last
tokens=[l.split()[0] for l in open('top_jettons_list.txt') if l.strip()]
# validate + build BOCs in node, output mapping only for VALID
node_script = '''
const {beginCell,Address}=require('@ton/core');const fs=require('fs');
const toks=fs.readFileSync('/tmp/opencode/top_jettons_list.txt','utf8').trim().split('\\n').map(l=>l.split(' ')[0]);
const out={};const bad=[];
for(const a of toks){try{const A=Address.parse(a);const c=beginCell().storeUint(1,4).storeInt(A.workChain,8).storeBuffer(A.hash).endCell();out[a]={boc:c.toBoc().toString('hex'),raw:'0:'+A.hash.toString('hex')};}catch(e){bad.push(a);}}
fs.writeFileSync('/tmp/opencode/asset_bocs2.json',JSON.stringify(out));
console.log(JSON.stringify({valid:Object.keys(out).length,bad}));
'''
r=subprocess.run(['node','-e',node_script],capture_output=True,text=True,cwd='/tmp/opencode/tonkit')
print(r.stdout[:300], r.stderr[:200])
ab=json.load(open('asset_bocs2.json'))
res={}
for i,(a,v) in enumerate(ab.items()):
    j=post(f'https://tonapi.io/v2/blockchain/accounts/{FACTORY}/methods/get_vault_address', {'args':[{'type':'slice','value':v['boc']}]})
    vault=(j.get('decoded') or {}).get('vault_addr') if isinstance(j,dict) else None
    if not vault and isinstance(j,dict) and j.get('stack'):
        import base64
        try: vault='0:'+base64.b64decode(j['stack'][0]['cell'])[-32:].hex()
        except Exception: pass
    time.sleep(1.3)
    bal=None
    if vault:
        k=get(f'https://tonapi.io/v2/accounts/{vault}/jettons')
        if isinstance(k,dict) and 'balances' in k:
            for b in k['balances']:
                if b['jetton']['address'].lower()==v['raw'].lower(): bal=b['balance']; break
            else: bal='0'
        else: bal='ERR'
        time.sleep(1.3)
    res[a]={'vault':vault,'balance':bal,'raw':v['raw']}
    print(f"[{i+1}/{len(ab)}] {a[:16]} vault={vault} bal={bal}", flush=True)
json.dump(res, open('jetton_vaults2.json','w'), indent=1)
print('DONE2')

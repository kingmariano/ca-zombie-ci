#!/usr/bin/env python3
import json, os, urllib.request, urllib.parse, time
URL='https://ethereum-rpc.publicnode.com'
def rpc(method, params, url=URL, timeout=60):
    req=urllib.request.Request(url, data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(), headers={'Content-Type':'application/json','User-Agent':'research'})
    with urllib.request.urlopen(req, timeout=timeout) as r: return json.loads(r.read().decode())
def rpc_ok(method, params):
    d=rpc(method,params)
    if 'result' not in d: raise RuntimeError(str(d)[:160])
    return d['result']
proxy='0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0'
impl='0xdf39face16519376e47bba3b9be15e69d8a66f2c'
AM='0xDd6E67942a9566A70446f7400a21240C5f71377C'
blk=int(rpc_ok('eth_blockNumber',[]),16)
# --- tx hashes ---
txs={
 '0x556b7541_1':'0xa3250dca77b3628a93e1095e16868958d96fbb936b86e5662727917c698c680d',
 '0x04c32fd2_1':'0xbaff59b39c89acc70abae115e203dfdd587e594689e568e119c36af114ad1013',
 '0x5d007a99_1':'0x9b651f5f1e3a0a489beb9153e0d472096da435a83f36b8d08ace2b89b0ebde0f',
 '0x6184bf91_1':'0x227dea07acfd5a4187b5e23188a3abab40716b953a949b50fb0fb69922f3573b',
 '0x2b98c640_1':'0x3a731f5dd45792de4206ebc59fdbe97db4b83d2a657432be22b3a7a4fc125f73',
}
meta={}
for name,h in txs.items():
    tx=rpc_ok('eth_getTransactionByHash',[h])
    open(f'evidence/calldata_{name}.hex','w').write(tx['input'])
    meta[name]={'tx':h,'block':int(tx['blockNumber'],16),'from':tx['from'],'to':tx['to']}
    tr=rpc('debug_traceTransaction',[h,{'tracer':'callTracer'}])
    if 'result' in tr:
        json.dump(tr['result'], open(f'traces/{name}_trace.json','w'), indent=1)
        print('trace ok', name)
    else:
        print('trace FAIL', name, str(tr)[:100])
# first 556b7541 tx from etherscan (for mutation oracle)
env={}
for line in open('/home/heisenberg/CA/.env'):
    line=line.strip()
    if '=' in line and not line.startswith('#'):
        k,v=line.split('=',1); env[k]=v.strip().strip('"').strip("'")
KEY=env.get('ETHERSCANV2_API_KEY','')
if KEY:
    try:
        u=f'https://api.etherscan.io/v2/api?chainid=1&module=account&action=txlist&address={proxy}&startblock=0&endblock=99999999&page=1&offset=1000&sort=asc&apikey={KEY}'
        d=json.loads(urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'research'}),timeout=40).read())
        first=None
        for t in d.get('result',[]):
            if t['input'][:10]=='0x556b7541': first=t; break
        if first:
            tx=rpc_ok('eth_getTransactionByHash',[first['hash']])
            open('evidence/calldata_0x556b7541_first.hex','w').write(tx['input'])
            meta['0x556b7541_first']={'tx':first['hash'],'block':int(first['blockNumber']),'from':first['from']}
            print('first 556b7541 tx:', first['hash'], 'block', first['blockNumber'])
    except Exception as e: print('etherscan err', str(e)[:120])
json.dump(meta, open('evidence/network_txs.json','w'), indent=1)
print('head', blk)

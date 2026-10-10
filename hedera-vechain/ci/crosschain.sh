#!/usr/bin/env bash
# H2-06 cross-chain live state recheck (read-only, keyless public endpoints).
# Re-verifies the headline custody/gate state for VeChain, Stacks, Filecoin, IOTA in CI.
set -uo pipefail
OUT="${1:-ci-out}"
mkdir -p "$OUT"
python3 - "$OUT/crosschain_recheck.json" <<'PY'
import json,sys,urllib.request
def http(url,data=None,headers=None,timeout=60):
    req=urllib.request.Request(url,data=data,headers=headers or {'User-Agent':'research-readonly'})
    return json.load(urllib.request.urlopen(req,timeout=timeout))
res={'finding':'H2-06','read_only':True,'checks':[]}
def add(name,ok,val,note=''):
    res['checks'].append({'check':name,'ok':bool(ok),'value':val,'note':note})
# --- VeChain (Thor REST, keyless) ---
try:
    d=http('https://mainnet.vechain.org/accounts/0x03c557be98123fdb6fad325328ac6eb77de7248c')
    bal=int(d.get('balance','0x0'),16)
    add('vechain.StarGate.VET_wei',bal>0,str(bal),'expect ~6.98e26 wei (698M VET)')
except Exception as e: add('vechain.StarGate',False,str(e)[:140])
try:
    d=http('https://mainnet.vechain.org/accounts/0x1856c533ac2d94340aaa8544d35a5c1d4a21dee7')
    add('vechain.StarGateNFT.energy',True,str(int(d.get('energy','0x0'),16)),'')
except Exception as e: add('vechain.StarGateNFT',False,str(e)[:140])
# --- Stacks (Hiro, keyless) ---
try:
    b=http('https://api.hiro.so/extended/v1/address/SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-swap-v2-1/balances')
    stx=int(b['stx']['balance']); ft=b.get('fungible_tokens',{})
    usda=ft.get('SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token::usda',{}).get('balance')
    diko=ft.get('SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token::diko',{}).get('balance')
    add('stacks.swapv2.STX_micro',stx>6.8e11,str(stx),'expect ~685180e6')
    add('stacks.swapv2.USDA_micro',usda is not None,str(usda),'expect ~191132e6')
    add('stacks.swapv2.DIKO_raw',diko is not None,str(diko),'expect ~1.35e13 raw')
except Exception as e: add('stacks.swapv2',False,str(e)[:140])
# --- Filecoin FEVM (glif, keyless) ---
def fil_balance(addr):
    d=http('https://api.node.glif.io/rpc/v1',
           data=json.dumps({'jsonrpc':'2.0','id':1,'method':'eth_getBalance','params':[addr,'latest']}).encode(),
           headers={'Content-Type':'application/json'})
    return int(d['result'],16)
try:
    add('filecoin.hashking_vault.FIL_wei',fil_balance('0xe012F3957226894B1a2a44b3ef5070417a069dC2')>0,
        str(fil_balance('0xe012F3957226894B1a2a44b3ef5070417a069dC2')),'expect ~9414 FIL')
except Exception as e: add('filecoin.hashking',False,str(e)[:140])
try:
    add('filecoin.filliquid_pool.FIL_wei',fil_balance('0xFD669BDDfbb0d085135cBd92521785C39c95bA4b')==0,
        str(fil_balance('0xFD669BDDfbb0d085135cBd92521785C39c95bA4b')),'expect 0 (swept 2026-09-03)')
except Exception as e: add('filecoin.filliquid',False,str(e)[:140])
# --- IOTA Rebased (public RPC, keyless) ---
try:
    def rpc(m,p):
        return http('https://api.mainnet.iota.cafe',
                    data=json.dumps({'jsonrpc':'2.0','id':1,'method':m,'params':p}).encode(),
                    headers={'Content-Type':'application/json'})
    cp=rpc('iota_getLatestCheckpointSequenceNumber',[])['result']
    add('iota.checkpoint',int(cp)>201990868,str(cp),'')
    f=rpc('iota_getObject',['0x6101272394511caf38ce5a6d120d3b4d009b6efabae8faac43aa9ac938cec558',{'showContent':True}])['result']['data']['content']['fields']
    add('iota.stabilitypool.vusd_balance',int(f['vusd_balance'])>0,str(f['vusd_balance']),'expect ~189497634597')
    add('iota.stabilitypool.liquidator',True,str(f['liquidator']),'whitelisted liquidator (E-U gate)')
    af=rpc('iota_getObject',['0x7c16ffdac553a4816db57e5e2cfbba8245337f2983b4ffb4dd944493a530c556',{'showContent':True}])['result']['data']['content']['fields']
    ts=int(af['current_result']['fields']['min_timestamp_ms'])
    add('iota.oracle.last_update_ms',ts<1791640000000,str(ts),'stale => price-dependent ops revert')
except Exception as e: add('iota',False,str(e)[:140])
res['passed']=sum(1 for c in res['checks'] if c['ok'])
res['failed']=sum(1 for c in res['checks'] if not c['ok'])
json.dump(res,open(sys.argv[1],'w'),indent=1)
print('wrote',sys.argv[1],'passed',res['passed'],'failed',res['failed'])
sys.exit(0 if res['failed']==0 else 2)
PY

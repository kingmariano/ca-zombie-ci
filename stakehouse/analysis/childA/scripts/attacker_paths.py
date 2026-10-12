#!/usr/bin/env python3
"""Trace the attacker paths (read-only) and replay/negative tests; save evidence."""
import json, urllib.request
DRPC='https://eth.drpc.org'; RPC='https://ethereum-rpc.publicnode.com'
def post(url,payload,timeout=90):
    req=urllib.request.Request(url,data=json.dumps(payload).encode(),headers={'Content-Type':'application/json','User-Agent':'research'})
    with urllib.request.urlopen(req,timeout=timeout) as r: return json.loads(r.read().decode())
def trace(to,data,frm='0x000000000000000000000000000000000000dEaD',value='0x0',url=DRPC):
    d=post(url,{'jsonrpc':'2.0','id':1,'method':'debug_traceCall','params':[{'from':frm,'to':to,'data':data,'value':value,'gas':'0x1c9c380'},'latest',{'tracer':'callTracer'}]})
    return d.get('result') or {'ERROR':str(d.get('error'))[:160]}
def ethcall(to,data,frm='0x000000000000000000000000000000000000dEaD'):
    d=post(RPC,{'jsonrpc':'2.0','id':1,'method':'eth_call','params':[{'from':frm,'to':to,'data':data},'latest']})
    if 'result' in d: return d['result']
    return {'ERROR':str(d.get('error',{}).get('message'))[:120],'data':str(d.get('error',{}).get('data'))[:80]}
proxy='0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0'; AM='0xDd6E67942a9566A70446f7400a21240C5f71377C'
att='0x000000000000000000000000000000000000dEaD'
K0='b9df4050e3cd5da6df1012a5aad0402e7358c55bb46b5e4c48ccc3e10938c1dd524b384a3412efdaef16c5d1968db1eb'
def enc_bytes(h): 
    b=bytes.fromhex(h); return ('%064x'%32)+('%064x'%len(b))+b.hex().ljust(64,'0')
out={}
# reportSweeps replay with expired deadline
base=open('evidence/calldata_0x556b7541_first.hex').read().strip()
out['reportSweeps_replay_expired_deadline']=ethcall(proxy,base)
# reportSweeps with fresh deadline (digest invalid) -> Invalid Report
A=bytearray.fromhex(base[10:]); 
import time
blk=int(post(RPC,{'jsonrpc':'2.0','id':1,'method':'eth_blockNumber','params':[]})['result'],16)
A[32:64]=(blk+1000).to_bytes(32,'big')
out['reportSweeps_fresh_deadline_modified_sig']=ethcall(proxy,'0x556b7541'+A.hex())
# key mismatch
A=bytearray.fromhex(base[10:]); A[32:64]=(blk+1000).to_bytes(32,'big')
report=int.from_bytes(A[0:32],'big')
A[report+0xa0+0x20+31]^=1
out['reportSweeps_key_mismatch']=ethcall(proxy,'0x556b7541'+A.hex())
out_files={
 'init_from_attacker':trace(proxy,'0x86863ec6'+att[2:].rjust(64,'0')*2+'%064x'%100),
 'manageVerifier_from_attacker':trace(proxy,'0x7ec2e278'+att[2:].rjust(64,'0')+'1'.rjust(64,'0')),
 'updateTotal_from_attacker':trace(proxy,'0x4a1a8df6'+enc_bytes(K0)+'%064x'%1+'%064x'%1),
 'unwrapDETH_from_attacker':trace(proxy,'0x690b4c40'+enc_bytes(K0)+'%064x'%(10**17)),
 'AM_withdrawETH_direct':trace(AM,'0x4782f779'+att[2:].rjust(64,'0')+'%064x'%(10**17)),
 'manageVerifier_AC_probe':ethcall('0xba86e2917a98c4d6bcb171516252348f1e06fffd','0x956c1ca5'+'9785f8e50229ebd2b3788452abc31d1942394e0c'.rjust(64,'0')),
}
# also non-trace probes for manage (AC function on reporter)
out_files['manageVerifier_AC_probe_report'] = ethcall('0xba86e2917a98c4d6bcb171516252348f1e06fffd','0x956c1ca5'+proxy[2:].rjust(64,'0'))
json.dump(out,open('evidence/revert_reasons.json','w'),indent=1)
for k,v in out_files.items():
    json.dump(v,open(f'traces/{k}.json','w'),indent=1)
print(json.dumps(out,indent=1))
print('traces saved:', list(out_files))

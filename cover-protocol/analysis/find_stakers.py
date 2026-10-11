#!/usr/bin/env python3
"""Find live stakers in Blacksmith + BonusRewards for PoC."""
import json, os, urllib.request
import eth_abi

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
BS = '0xe0b94a7bb45dd905c79bb1992c9879f40f1caed5'
BR = '0x8fc8551dd5e2dc5d2b04f2957e543d7d53a79f1e'

# candidate (lpToken, user) pairs seen in 2020 deposits + pool BPT holders
CANDS = [
    ('0xf1469c0c8cde46466d6cbf0a1e0b03b98cbb301f', '0xf42a339f93c1fa4c5d9ace33db308a504e7b0bde'),
    ('0xd5f9790b02357666a168ff09f662ee569b2fee36', '0xf42a339f93c1fa4c5d9ace33db308a504e7b0bde'),
    ('0xd9b92e84b9f96267bf548cfe3a3ae21773872138', '0x13e252df0cafe34116cec052177b7540afc75f76'),
    ('0xd5f9790b02357666a168ff09f662ee569b2fee36', '0x13e252df0cafe34116cec052177b7540afc75f76'),
    ('0x33bc3abfabde8fceb0ced58e16184fb4cfc163ef', '0x00c3217f7de62f3c6c014d7203cf999b5549b6bb'),
    ('0x9a43e689dbe8f60ec12ba899d58b94a14d852e37', '0x3f3003dec579ffe478be29133c22dc1bb273a2b8'),
    ('0x6c701226204f7937750671b041996a73180a47d6', '0x4b426794cc04193c89a993d5a3ddf4d4fd5021eb'),
    ('0xd5f9790b02357666a168ff09f662ee569b2fee36', '0x2f80e5163a7a774038753593010173322ea6f9fe'),
    ('0xf1469c0c8cde46466d6cbf0a1e0b03b98cbb301f', '0x2f80e5163a7a774038753593010173322ea6f9fe'),
    ('0xd9b92e84b9f96267bf548cfe3a3ae21773872138', '0x2f80e5163a7a774038753593010173322ea6f9fe'),
    ('0x53e6728366d8518e69867ee15fa990708c0d8cd6', '0x2f80e5163a7a774038753593010173322ea6f9fe'),
    ('0xd5f9790b02357666a168ff09f662ee569b2fee36', '0xdd79dc5b781b14ff091686961adc5d47e434f4b0'),
    ('0xd9b92e84b9f96267bf548cfe3a3ae21773872138', '0xdd79dc5b781b14ff091686961adc5d47e434f4b0'),
]
# miners(address,address) selector
sel_bs = '0x' + __import__('eth_utils').keccak(b'miners(address,address)')[:4].hex()
print('sel miners', sel_bs)
calls = []
for lp, u in CANDS:
    calls.append(("eth_call", [{"to": BS, "data": sel_bs + enc(lp) + enc(u)}, hex(block)]))
res = rpc_batch(calls)
print('== Blacksmith miners ==')
live_bs = []
for (lp, u), r in zip(CANDS, res):
    if r and r != '0x':
        amt = int(r[2:66], 16)
        if amt:
            print(f"LIVE {lp} {u} amount={amt/1e18:.4f}")
            live_bs.append((lp, u, amt))

# BonusRewards getUser(lpToken, addr) returns (User, uint256[])
sel_br = '0x' + __import__('eth_utils').keccak(b'getUser(address,address)')[:4].hex()
calls = []
for lp, u in CANDS:
    calls.append(("eth_call", [{"to": BR, "data": sel_br + enc(lp) + enc(u)}, hex(block)]))
res = rpc_batch(calls)
print('== BonusRewards users ==')
for (lp, u), r in zip(CANDS, res):
    if r and r != '0x' and len(r) > 200:
        try:
            user, rewards = eth_abi.decode(['(uint256,uint256[])', 'uint256[]'], bytes.fromhex(r[2:]))
            if user[0]:
                print(f"LIVE {lp} {u} amount={user[0]/1e18:.4f}")
        except Exception as e:
            pass

json.dump({'block': block, 'blacksmith_live': live_bs}, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stakers.json'), 'w'), indent=1)

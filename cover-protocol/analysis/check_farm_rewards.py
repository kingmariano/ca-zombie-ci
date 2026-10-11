#!/usr/bin/env python3
"""Check for orphaned farm rewards: Blacksmith pools (COVER) and BonusRewards bonuses with remBonus>0.
Also read Blacksmith pool weights.
"""
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
sel_getPoolList = '0x' + eth_utils.keccak(b'getPoolList()')[:4].hex()

# Blacksmith pools
r = rpc_batch([("eth_call", [{"to": BS, "data": sel_getPoolList}, hex(block)])])[0]
(bs_pools,) = eth_abi.decode(['address[]'], bytes.fromhex(r[2:]))
print('Blacksmith pools:', len(bs_pools))
sel_pools = '0x' + eth_utils.keccak(b'pools(address)')[:4].hex()
calls = []
for p in bs_pools:
    calls.append(("eth_call", [{"to": BS, "data": sel_pools + enc(p)}, hex(block)]))
    calls.append(("eth_call", [{"to": p, "data": '0x70a08231' + enc(BS)}, hex(block)]))
    calls.append(("eth_call", [{"to": p, "data": '0x18160ddd'}, hex(block)]))
res = rpc_batch(calls)
def safe_int(v):
    try:
        return int(v, 16) if v and v != '0x' else 0
    except Exception:
        return 0
bs_rows = []
for i, p in enumerate(bs_pools):
    weight, acc, last = eth_abi.decode(['uint256', 'uint256', 'uint256'], bytes.fromhex(res[i*3][2:]))
    held = safe_int(res[i*3+1])
    ts = safe_int(res[i*3+2])
    bs_rows.append({'pool': p, 'weight': weight, 'held': held, 'ts': ts})
    if weight > 0 and held < 1e18:  # less than 1 BPT staked
        print(f"  LOW/NO STAKE: {p} weight={weight} held={held/1e18:.6f}")
json.dump(bs_rows, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'blacksmith_pools.json'), 'w'), indent=1)

# BonusRewards pools + bonuses
r = rpc_batch([("eth_call", [{"to": BR, "data": sel_getPoolList}, hex(block)])])[0]
(br_pools,) = eth_abi.decode(['address[]'], bytes.fromhex(r[2:]))
print('BonusRewards pools:', len(br_pools))
sel_getPool = '0x' + eth_utils.keccak(b'getPool(address)')[:4].hex()
calls = []
for p in br_pools:
    calls.append(("eth_call", [{"to": BR, "data": sel_getPool + enc(p)}, hex(block)]))
    calls.append(("eth_call", [{"to": p, "data": '0x70a08231' + enc(BR)}, hex(block)]))
res = rpc_batch(calls)
bonus_types = '((address,uint48,uint48,uint256,uint256,uint256)[],uint256)'
br_rows = []
for i, p in enumerate(br_pools):
    try:
        (bonuses, last) = eth_abi.decode([bonus_types], bytes.fromhex(res[i*2][2:]))
    except Exception as e:
        bonuses, last = [], 0
    held = safe_int(res[i*2+1])
    row = {'pool': p, 'held': held, 'lastUpdatedAt': last, 'bonuses': []}
    for b in bonuses:
        addr, st, et, wr, acc, rem = b
        row['bonuses'].append({'token': addr, 'start': st, 'end': et, 'weekly': wr, 'rem': rem})
        if rem > 0:
            print(f"  BONUS rem>0: pool {p} token {addr} rem={rem/1e18:.4f} end={et} held={held/1e18:.4f}")
    br_rows.append(row)
json.dump(br_rows, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'bonusrewards_pools.json'), 'w'), indent=1)
print('done')

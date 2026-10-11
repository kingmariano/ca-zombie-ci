#!/usr/bin/env python3
"""For each top pool, enumerate depositors into BonusRewards/Blacksmith and sum live records vs held BPT."""
import json, os, time, urllib.request
import eth_abi, eth_utils

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
RPC = ENV.get('NODEREAL_ETH_RPC_URL') or ENV.get('BLOCKPI_RPC_URL') or ENV.get('RPC_URL')
KEY = ENV['ETHERSCANV2_API_KEY']

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

def es_logs(address, topic2, topic0):
    out = []
    page = 1
    while page <= 6:
        url = f'https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs&address={address}&topic0={topic0}&topic2=0x{topic2.lower().replace("0x","").rjust(64,"0")}&page={page}&offset=1000&apikey={KEY}'
        d = None
        for attempt in range(4):
            try:
                d = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=40).read())
            except Exception as e:
                d = None
                time.sleep(1 + attempt)
                continue
            if d.get('status') == '1':
                break
            time.sleep(1.5 + attempt)
        if not d or d.get('status') != '1':
            print('   logs fetch failed:', str(d)[:120])
            break
        out.extend(d['result'])
        if len(d['result']) < 1000:
            break
        page += 1
    return out

block = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
BR = '0x8fc8551dd5e2dc5d2b04f2957e543d7d53a79f1e'
BS = '0xe0b94a7bb45dd905c79bb1992c9879f40f1caed5'
T0 = eth_utils.keccak(b'Transfer(address,address,uint256)').hex()
T0 = '0x' + T0
sel_br = '0x' + eth_utils.keccak(b'getUser(address,address)')[:4].hex()
sel_bs = '0x' + eth_utils.keccak(b'miners(address,address)')[:4].hex()

pools = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pools.json')))
top = [p for p in sorted(pools['pools'], key=lambda x: -x['holdingRedeemable'])[:16]]
out = {'block': block, 'pools': []}
for p in top:
    rec = {'pool': p['addr'], 'redeemable': p['holdingRedeemable']}
    for name, holder, sel, kind in (('bonusRewards', BR, sel_br, 'br'), ('blacksmith', BS, sel_bs, 'bs')):
        logs = es_logs(p['addr'], holder, T0)
        depositors = sorted(set('0x' + l['topics'][1][-40:] for l in logs))
        if not depositors:
            continue
        calls = [("eth_call", [{"to": holder, "data": sel + enc(p['addr']) + enc(u)}, hex(block)]) for u in depositors]
        res = rpc_batch(calls)
        live = []
        for u, r in zip(depositors, res):
            amt = 0
            if r and r != '0x':
                if kind == 'bs':
                    amt = int(r[2:66], 16)
                else:
                    try:
                        user, _ = eth_abi.decode(['(uint256,uint256[])', 'uint256[]'], bytes.fromhex(r[2:]))
                        amt = user[0]
                    except Exception:
                        amt = 0
            if amt:
                live.append({'user': u, 'amount': amt})
        rec[name] = {'depositors': len(depositors), 'liveUsers': live, 'liveSum': sum(x['amount'] for x in live)}
        print(f"{p['addr']} {name}: {len(depositors)} depositors, {len(live)} live, liveSum={rec[name]['liveSum']/1e18:.4f}")
        time.sleep(0.3)
    out['pools'].append(rec)
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'staker_enum.json'), 'w'), indent=1)
print('saved staker_enum.json')

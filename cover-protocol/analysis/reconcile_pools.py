#!/usr/bin/env python3
"""Reconcile: per pool, BPT held by BonusRewards/Blacksmith vs live staker records vs orphaned."""
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
pools = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pools.json')))
stakers = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'staker_enum.json')))
st_by_pool = {p['pool']: p for p in stakers['pools']}

# BPT balances for all pools
allp = sorted(pools['pools'], key=lambda x: -x['holdingRedeemable'])
calls = []
for p in allp:
    calls.append(("eth_call", [{"to": p['addr'], "data": '0x18160ddd'}, hex(block)]))
    calls.append(("eth_call", [{"to": p['addr'], "data": '0x70a08231' + enc(BR)}, hex(block)]))
    calls.append(("eth_call", [{"to": p['addr'], "data": '0x70a08231' + enc(BS)}, hex(block)]))
res = rpc_batch(calls)

rows = []
for i, p in enumerate(allp):
    ts = int(res[i*3] or '0x0', 16)
    br = int(res[i*3+1] or '0x0', 16)
    bs = int(res[i*3+2] or '0x0', 16)
    st = st_by_pool.get(p['addr'], {})
    live_br = (st.get('bonusRewards') or {}).get('liveSum', 0) or 0
    live_bs = (st.get('blacksmith') or {}).get('liveSum', 0) or 0
    rows.append({'pool': p['addr'], 'redeemable': p['holdingRedeemable'], 'bptSupply': ts,
                 'brBPT': br, 'bsBPT': bs, 'liveBR': live_br, 'liveBS': live_bs})

tot_redeem = 0
tot_staked_live = 0
tot_orphan = 0
tot_other = 0
print(f"{'pool':44s} {'redeem$':>10s} {'brBPT':>14s} {'liveBR':>14s} {'bsBPT':>14s} {'liveBS':>14s} {'other':>12s}")
for r in rows:
    other = r['bptSupply'] - r['brBPT'] - r['bsBPT']
    live = min(r['liveBR'], r['brBPT']) + min(r['liveBS'], r['bsBPT'])
    orphan = (r['brBPT'] - min(r['liveBR'], r['brBPT'])) + (r['bsBPT'] - min(r['liveBS'], r['bsBPT']))
    frac_live = live / r['bptSupply'] if r['bptSupply'] else 0
    frac_orph = orphan / r['bptSupply'] if r['bptSupply'] else 0
    frac_other = other / r['bptSupply'] if r['bptSupply'] else 0
    tot_redeem += r['redeemable']
    tot_staked_live += r['redeemable'] * frac_live
    tot_orphan += r['redeemable'] * frac_orph
    tot_other += r['redeemable'] * frac_other
    if r['redeemable'] > 5:
        print(f"{r['pool']:44s} {r['redeemable']:>10.1f} {r['brBPT']/1e18:>14.1f} {r['liveBR']/1e18:>14.1f} {r['bsBPT']/1e18:>14.1f} {r['liveBS']/1e18:>14.1f} {other/1e18:>12.1f}")

print()
print(f"total covToken redeemable sitting in pools: {tot_redeem:.2f}")
print(f"  reachable via live staker records (H-O):   {tot_staked_live:.2f}")
print(f"  held by other BPT holders (EOAs etc.):     {tot_other:.2f}")
print(f"  orphaned in staking contracts (S):         {tot_orphan:.2f}")
json.dump(rows, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pool_reconcile.json'), 'w'), indent=1)

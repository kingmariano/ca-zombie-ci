#!/usr/bin/env python3
"""Check CoverRouter residuals: token balances + BPT balances for all pools.
Also check the pools' BPT holders (top) and the two zero-controller pools.
"""
import json, os, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
RPC = ENV.get('NODEREAL_ETH_RPC_URL') or ENV.get('BLOCKPI_RPC_URL') or ENV.get('RPC_URL')

def rpc_batch(calls, retries=4):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        body = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(RPC, data=body, headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
                resp = json.loads(urllib.request.urlopen(req, timeout=90).read())
                byid = {r['id']: r for r in resp}
                out.extend([byid[j].get('result') for j in range(len(chunk))])
                break
            except Exception:
                if attempt == retries - 1:
                    raise
                time.sleep(2 * (attempt + 1))
    return out

def enc_addr(a): return a.lower().replace('0x', '').rjust(64, '0')

pools = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pools.json')))
state = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')))
block = state['block']
ROUTERS = ['0x5b63c3c6b259dfd3966f32514318d91a92dcf175', '0xe303f7081be3530f66de12cdbe2a2e98c0939125']

# 1) router balances of all pool tokens + BPT
calls = []
meta = []
for r in ROUTERS:
    calls.append(("eth_getBalance", [r, hex(block)])); meta.append(('ETH', r))
    for p in pools['pools']:
        calls.append(("eth_call", [{"to": p['addr'], "data": '0x70a08231' + enc_addr(r)}, hex(block)])); meta.append(('BPT:' + p['addr'], r))
        for t in p['tokens']:
            calls.append(("eth_call", [{"to": t, "data": '0x70a08231' + enc_addr(r)}, hex(block)])); meta.append(('TOK:' + t, r))
res = rpc_batch(calls)
bal = {}
for (kind, r), v in zip(meta, res):
    val = int(v, 16) if v and v != '0x' else 0
    if val:
        bal.setdefault(r, {})[kind] = val
print('== ROUTER RESIDUAL BALANCES ==')
for r in ROUTERS:
    print(r, json.dumps({k: (v if k == 'ETH' else v / 1e18) for k, v in bal.get(r, {}).items()}, indent=1))

# 2) BPT holders for pools: use GoldRush token_holders_v2 on pool address (BPT is ERC20)
ENVK = ENV['GOLD_RUSH_API_KEY']
def holders(token):
    url = f'https://api.covalenthq.com/v1/eth-mainnet/tokens/{token}/token_holders_v2/?page-size=100'
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {ENVK}', 'User-Agent': 'Mozilla/5.0'})
    try:
        r = json.loads(urllib.request.urlopen(req, timeout=60).read())
        if r.get('error'):
            return None
        return r['data']['items']
    except Exception:
        return None

top = sorted(pools['pools'], key=lambda x: -x['holdingRedeemable'])[:8]
print()
print('== BPT HOLDERS (top pools) ==')
for p in top:
    hs = holders(p['addr'])
    print(f"{p['addr']} redeemable={p['holdingRedeemable']:.1f}")
    if hs is None:
        print('   (holder fetch failed)')
        continue
    tot = sum(int(h['balance']) for h in hs)
    print(f"   BPT supply={p.get('bptSupply') or '?'} holders sum={tot/1e18:.4f} n={len(hs)}")
    for h in hs[:8]:
        print(f"   {h['address']} {int(h['balance'])/1e18:.4f}")
    time.sleep(0.2)

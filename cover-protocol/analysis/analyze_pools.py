#!/usr/bin/env python3
"""Analyze Balancer V1 BPools holding covTokens: composition, public swap, spot price of covToken."""
import json, os, time, urllib.request
import eth_abi

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
def call(to, data, block):
    return rpc_batch([("eth_call", [{"to": to, "data": data}, hex(block)])])[0]

SEL = {
    'getCurrentTokens()': '0xcc77828d',
    'isPublicSwap()': '0x260937f2',
    'getController()': '0x3018205f',
    'getBalance(address)': '0xf8b2cb4f',
    'getSpotPrice(address,address)': '0x15e84af9',
    'getNormalizedWeight(address)': '0x948d8ce6',
    'totalSupply()': '0x18160ddd',
}

def main():
    hc = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'holders_classified.json')))
    state = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')))
    block = state['block']
    # collect pools (codeLen 22537) with their covToken holdings
    pools = {}
    for tok, rec in hc['tokens'].items():
        for h in rec['holderList']:
            if h['isContract'] and h['codeLen'] == 22537:
                pools.setdefault(h['addr'], []).append({'token': tok, 'bal': h['bal'], 'kind': rec['kind'], 'cover': rec['coverName'], 'ratio': rec['ratio']})
    print(f'{len(pools)} BPools hold covTokens')
    addrs = list(pools.keys())
    # isPublicSwap + controller + currentTokens
    res_pub = rpc_batch([("eth_call", [{"to": a, "data": SEL['isPublicSwap()']}, hex(block)]) for a in addrs])
    res_ctl = rpc_batch([("eth_call", [{"to": a, "data": SEL['getController()']}, hex(block)]) for a in addrs])
    res_tok = rpc_batch([("eth_call", [{"to": a, "data": SEL['getCurrentTokens()']}, hex(block)]) for a in addrs])
    poolinfo = {}
    calls = []
    keymap = []
    for i, a in enumerate(addrs):
        info = {'addr': a, 'publicSwap': (res_pub[i] or '0x0')[-1] == '1',
                'controller': '0x' + (res_ctl[i] or '0x')[-40:].lower() if res_ctl[i] else None,
                'tokens': []}
        try:
            (toks,) = eth_abi.decode(['address[]'], bytes.fromhex(res_tok[i][2:]))
            info['tokens'] = [t.lower() for t in toks]
        except Exception as e:
            info['err'] = str(e)
        poolinfo[a] = info
        for t in info['tokens']:
            calls.append(("eth_call", [{"to": a, "data": SEL['getBalance(address)'] + enc_addr(t)}, hex(block)]))
            keymap.append((a, t))
    res_bal = rpc_batch(calls)
    for (a, t), r in zip(keymap, res_bal):
        poolinfo[a].setdefault('balances', {})[t] = int(r, 16) if r and r != '0x' else 0
    # spot prices of covToken vs first non-covToken token (if any)
    for a, info in poolinfo.items():
        covs = set(x['token'] for x in pools[a])
        others = [t for t in info['tokens'] if t not in covs]
        info['otherTokens'] = others
        if others and info['tokens']:
            data = SEL['getSpotPrice(address,address)'] + enc_addr(list(covs)[0]) + enc_addr(others[0])
            r = call(a, data, block)
            info['spotPrice'] = int(r, 16) if r and r != '0x' else None
        else:
            info['spotPrice'] = None
    out = {'block': block, 'pools': []}
    for a, info in poolinfo.items():
        rec = dict(info)
        rec['holdings'] = pools[a]
        rec['holdingValuePar'] = sum(x['bal'] for x in pools[a]) / 1e18
        rec['holdingRedeemable'] = sum(x['bal'] * x['ratio'] for x in pools[a]) / 1e18
        out['pools'].append(rec)
    out['pools'].sort(key=lambda x: -x['holdingRedeemable'])
    json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pools.json'), 'w'), indent=1)
    for rec in out['pools'][:30]:
        print(f"{rec['addr']} public={rec['publicSwap']} ctrl={rec['controller']} tokens={len(rec['tokens'])} redeemable={rec['holdingRedeemable']:.2f} spot={rec.get('spotPrice')}")
        for h in rec['holdings']:
            print(f"    {h['kind']:7s} {h['cover'][:42]:42s} {h['bal']/1e18:.4f}")
        for t, b in (rec.get('balances') or {}).items():
            tag = 'COV' if any(h['token'] == t for h in rec['holdings']) else '   '
            print(f"    bal {tag} {t} {b/1e18:.6f}")
    print('saved pools.json')

if __name__ == '__main__':
    main()

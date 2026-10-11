#!/usr/bin/env python3
"""Fetch CoverFeeReceiver source + check balances of privileged/related addresses."""
import json, os, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV['ETHERSCANV2_API_KEY']
RPC = ENV.get('NODEREAL_ETH_RPC_URL') or ENV.get('BLOCKPI_RPC_URL') or ENV.get('RPC_URL')

def es(params):
    url = 'https://api.etherscan.io/v2/api?chainid=1&' + '&'.join(f'{k}={v}' for k, v in params.items()) + f'&apikey={KEY}'
    for _ in range(3):
        try:
            return json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=30).read())
        except Exception:
            time.sleep(2)
    return {'status': '0', 'result': 'fetch failed'}

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
    return json.loads(urllib.request.urlopen(req, timeout=60).read()).get('result')

out = {}
# 1. CoverFeeReceiver source
r = es({'module': 'contract', 'action': 'getsourcecode', 'address': '0xe0632311772d362f49b5118c40d5251c44bc8b2e'})
x = r['result'][0]
open('/tmp/opencode/cover_fee_receiver.sol', 'w').write(x['SourceCode'])
out['feeReceiverName'] = x['ContractName']
print('CoverFeeReceiver source saved, len', len(x['SourceCode']))

block = int(rpc('eth_blockNumber', []), 16)
out['block'] = block
print('block', block)

# 2. balances
TOKENS = {
    'DAI': '0x6b175474e89094c44da98b954eedeac495271d0f',
    'yDAI': '0x16de59092dae5ccf4a1e6439d611fd0653f0bd01',
    'COVER_v2': '0x5d8d9f5b96f4438195be9b99eee6118ed4304286',
    'USDC': '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    'WETH': '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    'COVER_v1': '0x4688a8b1f292fdab17e9a90c8bc379dc1dbd8713',
}
ADDRS = {
    'factory': '0xedfc81bf63527337cd2193925f9c0cf2d537acca',
    'feeReceiver': '0xe0632311772d362f49b5118c40d5251c44bc8b2e',
    'claimManagement': '0xd33f2e0173fd0ae2a64b208a7bd16bcdc68bc862',
    'safe_dev': '0x15957f0ca310d35b2e73fb5070ce44a5b0141ab1',
    'safe_gov': '0xc698645b5c5b662b52a5a5c092804f23e3f5b4c5',
    'safe_auditor': '0x7eba9c735f8c1fe0670be69edf61dbfbbb3c76e4',
    'safe_cm_treasury': '0x859eefc267671595d987d0f6589d7771d4877113',
    'eoa_old_admin': '0xdd79dc5b781b14ff091686961adc5d47e434f4b0',
    'cover_impl': '0xcb0900d9307da7fd4e000a9093f24ce25d937d42',
    'coverERC20_impl': '0xd18124029b167e03bbaab8d5d6fbb646ae020e1d',
    'protocol_impl': '0xb6886b2c3537673941e4ead63b95eacb47173f6a',
}
out['balances'] = {}
for an, a in ADDRS.items():
    rec = {}
    rec['ETH'] = int(rpc('eth_getBalance', [a, hex(block)]), 16)
    for tn, t in TOKENS.items():
        data = '0x70a08231' + a.lower().replace('0x', '').rjust(64, '0')
        v = rpc('eth_call', [{'to': t, 'data': data}, hex(block)])
        rec[tn] = int(v, 16) if v and v != '0x' else 0
    out['balances'][an] = rec
    print(an, a, {k: (v if k == 'ETH' else v / 1e18) for k, v in rec.items() if v})

json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'privileged_balances.json'), 'w'), indent=1)
print('saved')

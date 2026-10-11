#!/usr/bin/env python3
"""Probe unverified holder contracts: extract selectors from bytecode, resolve via 4byte.directory.
Also read Blacksmith.cover, COVER token price, BonusRewards paused, and exact holdings of value-bearing tokens."""
import json, os, re, time, urllib.request

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")
RPC = ENV.get('NODEREAL_ETH_RPC_URL') or ENV.get('BLOCKPI_RPC_URL') or ENV.get('RPC_URL')

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
    return json.loads(urllib.request.urlopen(req, timeout=60).read()).get('result')

def call(to, data, block):
    return rpc('eth_call', [{"to": to, "data": data}, hex(block)])

block = int(rpc('eth_blockNumber', []), 16)
print('block', block)

TARGETS = {
    'c_63242a4e': '0x63242a4ea82847b20e506b63b0e2e2eff0cc6cb0',
    'c_00000f91': '0x00000f91109c4d0007e90000d9facad5298a0cac',
    'c_c7f877d8': '0xc7f877d838cf16d4f10a19564edba719792e80be',
    'c_0eae044f': '0x0eae044f00b0af300500f090ea00027097d03000',
    'c_2f80e516': '0x2f80e5163a7a774038753593010173322ea6f9fe',
}
# extract PUSH4 selectors from bytecode
for label, addr in TARGETS.items():
    code = rpc('eth_getCode', [addr, hex(block)])
    if not code or code == '0x':
        print(label, 'no code'); continue
    b = bytes.fromhex(code[2:])
    sels = set()
    for i in range(len(b) - 4):
        if b[i] == 0x63:  # PUSH4
            sels.add(b[i+1:i+5].hex())
    print(f'== {label} {addr} codeLen={len(b)} selectors={len(sels)}')

# resolve selectors for c_63242a4e and others via 4byte
def resolve(sel):
    url = f'https://www.4byte.directory/api/v1/signatures/?hex_signature=0x{sel}'
    try:
        r = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=20).read())
        return [x['text_signature'] for x in r.get('results', [])][:3]
    except Exception:
        return []

for label in ['c_63242a4e', 'c_00000f91', 'c_c7f877d8', 'c_0eae044f']:
    addr = TARGETS[label]
    code = rpc('eth_getCode', [addr, hex(block)])
    b = bytes.fromhex(code[2:])
    sels = []
    for i in range(len(b) - 4):
        if b[i] == 0x63:
            s = b[i+1:i+5].hex()
            if s not in sels:
                sels.append(s)
    print(f'\n== {label} {addr}: resolving {len(sels)} selectors (first 40)')
    for s in sels[:40]:
        names = resolve(s)
        if names:
            print(f'  0x{s} {names}')
        time.sleep(0.05)

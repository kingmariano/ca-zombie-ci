#!/usr/bin/env python3
"""Pinned-block state snapshot for StarGate (keyless endpoints, read-only).
Writes raw evidence (request/response) to raw/state_snapshot.json and prints summary."""
import json, subprocess, os, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(BASE, 'raw')
RPC = 'https://rpc-mainnet.vechain.energy'
THOR = 'https://mainnet.vechain.org'
VTHO = '0x0000000000000000000000000000456E65726779'
STARGATE = '0x03c557be98123fdb6fad325328ac6eb77de7248c'
NFT = '0x1856c533ac2d94340aaa8544d35a5c1d4a21dee7'
STAKER = '0x00000000000000000000000000005374616b6572'
SG_IMPL = '0x987f2ebfd1c0e3490962b270488dc94a7d687a0f'
NFT_IMPL = '0xce31931f42099cb5b0a19f565d976084785cde2f'
ADMIN = '0xba04313060012a2c8623b2b3cb6d4c5e2b1becea'

def rpc(method, params):
    body = {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}
    p = subprocess.run(['curl', '-s', '--max-time', '30', '-X', 'POST', RPC,
                        '-H', 'Content-Type: application/json', '-d', json.dumps(body)],
                       capture_output=True, text=True)
    try:
        return json.loads(p.stdout).get('result')
    except Exception:
        return p.stdout

def balance_of(addr, block_hex):
    data = '0x70a08231' + addr[2:].rjust(64, '0')
    return rpc('eth_call', [{'to': VTHO, 'data': data}, block_hex])

def call(to, data, block_hex):
    return rpc('eth_call', [{'to': to, 'data': data}, block_hex])

def main():
    evidence = {}
    block = rpc('eth_blockNumber', [])
    evidence['block_hex'] = block
    bn = int(block, 16)
    print('pinned block:', bn)
    addrs = {'stargate': STARGATE, 'stargate_nft': NFT, 'protocol_staker': STAKER,
             'stargate_impl': SG_IMPL, 'nft_impl': NFT_IMPL, 'admin_eoa': ADMIN}
    for name, a in addrs.items():
        vet = rpc('eth_getBalance', [a, block])
        vtho = balance_of(a, block)
        evidence[name] = {'address': a, 'vet_wei': vet, 'vtho_wei': vtho}
        print(f'{name:18s} {a} VET={int(vet,16)/1e18:,.4f} VTHO={int(vtho,16)/1e18:,.4f}')
    # NFT supply
    ts = call(NFT, '0x18160ddd', block)  # totalSupply()
    ct = call(NFT, '0xcbb15329'.replace('0x','0x'), block) if False else call(NFT, subprocess.run(['cast','sig','getCurrentTokenId()'],capture_output=True,text=True).stdout.strip(), block)
    evidence['nft_total_supply'] = ts
    evidence['nft_current_token_id'] = ct
    print('NFT totalSupply:', int(ts, 16) if ts and ts != '0x' else ts)
    print('NFT currentTokenId:', int(ct, 16) if ct and ct != '0x' else ct)
    json.dump(evidence, open(os.path.join(RAW, 'state_snapshot.json'), 'w'), indent=1)
    print('saved raw/state_snapshot.json')

if __name__ == '__main__':
    main()

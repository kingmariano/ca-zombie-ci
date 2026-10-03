#!/usr/bin/env python3
"""Verify logic-identity of base/arb/mantle facet bytecode (strip CBOR metadata)."""
import json, subprocess, sys

m = json.load(open('facets/all_facets.json'))
rpcs = {'base': 'https://base-rpc.publicnode.com', 'arb': 'https://arb1.arbitrum.io/rpc', 'mantle': 'https://rpc.mantle.xyz'}

def code(chain, addr):
    return subprocess.run(['cast', 'code', addr, '--rpc-url', rpcs[chain]], capture_output=True, text=True).stdout.strip()

def strip_meta(h):
    b = bytes.fromhex(h[2:])
    ln = int.from_bytes(b[-2:], 'big')
    if 0 < ln < 200:
        return b[:len(b)-2-ln]
    return b

base_addrs = list(m['base']['facets'].keys())
# build index by position: facets order is same across chains (29 each)
rows = []
for i in range(len(base_addrs)):
    codes = {}
    addrs = {}
    for chain in ['base', 'arb', 'mantle']:
        a = list(m[chain]['facets'].keys())[i]
        addrs[chain] = a
        codes[chain] = strip_meta(code(chain, a))
    eq = codes['base'] == codes['arb'] == codes['mantle']
    rows.append((i, addrs['base'], addrs['arb'], addrs['mantle'], len(codes['base']), eq))
    print(f"[{i:02d}] {addrs['base']} arb={addrs['arb']} mantle={addrs['mantle']} len={len(codes['base'])} identical={eq}", flush=True)

json.dump(rows, open('facets/base_arb_mantle_identity.json', 'w'), indent=1)
print("ALL IDENTICAL:", all(r[5] for r in rows))

#!/usr/bin/env python3
"""Parse raw/positions_dump.json (fixed nested parse) -> raw/positions_parsed.json.
Re-fetches if needed. Read-only, public RPC."""
import json, urllib.request, sys

RPC = 'https://api.mainnet.iota.cafe'

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),
                                 headers={'Content-Type':'application/json'})
    d = json.load(urllib.request.urlopen(req, timeout=60))
    if 'result' not in d: raise RuntimeError(json.dumps(d)[:300])
    return d['result']

TABLES = {
    'IOTA':   '0x5c11faed36d39720599f9185af224df9fb10ba382bb4709d4b37d9ba00f69fdd',
    'stIOTA': '0x33c758d26ff2879034b96019b58b8e31289d0ba3794d1dee85500b055885f0c3',
    'vIOTA':  '0x7ee80e78a24aae1076dadfea89decb45d5e5369b1cbedc6b060892429b2a0a7c',
}

out = {'checkpoint': rpc('iota_getLatestCheckpointSequenceNumber', []), 'vaults': {}}
for name, table in TABLES.items():
    positions = []
    cursor = None
    while True:
        r = rpc('iotax_getDynamicFields', [table, cursor, 100])
        data = r.get('data', [])
        for f in data:
            key = f.get('name', {}).get('value')
            fo = rpc('iotax_getDynamicFieldObject', [table, {'type':'address','value':key}])
            obj = fo.get('data', {}) or {}
            flds = (obj.get('content') or {}).get('fields', {})
            node = flds.get('value') or {}
            pos = (node.get('fields') or {}).get('value') or {}
            posf = pos.get('fields') or {}
            positions.append({
                'debtor': key,
                'coll_amount': posf.get('coll_amount'),
                'debt_amount': posf.get('debt_amount'),
                'ts': posf.get('timestamp'),
                'prev': (node.get('fields') or {}).get('prev'),
                'next': (node.get('fields') or {}).get('next'),
                'version': obj.get('version'),
            })
        if r.get('hasNextPage') and data:
            cursor = data[-1].get('objectId')
        else:
            break
    out['vaults'][name] = {'table': table, 'positions': positions}
    print(f"{name}: {len(positions)} positions", file=sys.stderr)

out['checkpoint_end'] = rpc('iota_getLatestCheckpointSequenceNumber', [])
json.dump(out, open('raw/positions_parsed.json','w'), indent=1)
print('written raw/positions_parsed.json', file=sys.stderr)

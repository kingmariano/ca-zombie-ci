#!/usr/bin/env python3
"""Read-only dump of Virtue CDP positions via IOTA public RPC.
Usage: python3 dump_positions.py > positions_dump.json
No secrets. Public endpoint only."""
import json, urllib.request, sys, time

RPC = 'https://api.mainnet.iota.cafe'

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),
                                 headers={'Content-Type':'application/json'})
    for attempt in range(4):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=60))
            if 'result' in d: return d['result']
            raise RuntimeError(json.dumps(d)[:300])
        except Exception as e:
            if attempt == 3: raise
            time.sleep(1.5)

VAULTS = {
    'IOTA':   {'vault':'0xaf306be8419cf059642acdba3b4e79a5ae893101ae62c8331cefede779ef48d5',
               'table':'0x5c11faed36d39720599f9185af224df9fb10ba382bb4709d4b37d9ba00f69fdd'},
    'stIOTA': {'vault':'0xc9cb494657425f350af0948b8509efdd621626922e9337fd65eb161ec33de259',
               'table':'0x33c758d26ff2879034b96019b58b8e31289d0ba3794d1dee85500b055885f0c3'},
    'vIOTA':  {'vault':'0x53b6405d2672be1e73f8ddea1766dbda57f1fed677be58fbfedc9fdddaafdd26',
               'table':'0x7ee80e78a24aae1076dadfea89decb45d5e5369b1cbedc6b060892429b2a0a7c'},
}

out = {'checkpoint_at_start': None, 'vaults': {}}
out['checkpoint_at_start'] = rpc('iota_getLatestCheckpointSequenceNumber', [])

for name, v in VAULTS.items():
    fields = []
    cursor = None
    while True:
        lim = 100
        r = rpc('iotax_getDynamicFields', [v['table'], cursor, lim])
        data = r.get('data', [])
        fields.extend(data)
        if r.get('hasNextPage') and data:
            cursor = data[-1].get('objectId') or data[-1].get('name',{}).get('value')
            # cursor for getDynamicFields is the objectId of the last field
            if not cursor: break
        else:
            break
    positions = []
    for f in fields:
        nameval = f.get('name', {}).get('value')
        fo = rpc('iotax_getDynamicFieldObject', [v['table'], {'type':'address','value':nameval}])
        obj = fo.get('data', {})
        content = obj.get('content', {}) or {}
        flds = content.get('fields', {})
        val = (flds.get('value') or {}).get('fields', {}) if isinstance(flds.get('value'), dict) else {}
        positions.append({
            'addr': nameval,
            'node_type': (content.get('type') or '')[:160],
            'prev': (flds.get('prev') or {}).get('fields',{}).get('vec', [None]) if isinstance(flds.get('prev'), dict) else None,
            'next': (flds.get('next') or {}).get('fields',{}).get('vec', [None]) if isinstance(flds.get('next'), dict) else None,
            'timestamp': val.get('timestamp'),
            'coll_amount': val.get('coll_amount'),
            'debt_amount': val.get('debt_amount'),
            'obj_version': obj.get('version'),
        })
    out['vaults'][name] = {'vault_id': v['vault'], 'table_id': v['table'], 'count': len(fields), 'positions': positions}
    print(f"{name}: {len(fields)} positions", file=sys.stderr)

out['checkpoint_at_end'] = rpc('iota_getLatestCheckpointSequenceNumber', [])
json.dump(out, sys.stdout, indent=1)

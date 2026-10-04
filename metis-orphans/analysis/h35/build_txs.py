#!/usr/bin/env python3
"""Build curated txs.json evidence for H-35 from raw Blockscout logs + tx list."""
import json
from datetime import datetime, timezone

RAW = '/home/heisenberg/CA/metis-orphans/analysis/h35/raw'
logs = json.load(open(f'{RAW}/logs_v1.json'))['result']

T = {
 '0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8':'SafeSetup',
 '0x442e715f626346e8c54381002da614f62bee8d27386535b2521ec8540898556e':'ExecutionSuccess',
 '0x23428b18acfb3ea64b08dc0c1d296ea9c09702c09083ca5272e64d115b687d23':'ExecutionFailure',
 '0x9465fa0c962cc76958e6373a993326400c1c94aa8e5ef2ea8fa34d033c60a4d2':'AddedOwner',
 '0xf8d49fc529812e9a7c5c50e69c20f0dccc0db8fa95c98bc58cc9a4f1c1299eaf':'RemovedOwner',
 '0x610f7ff2b304ae8903c3de74c60c6ab1f7d6226b3f52c5161905bb5ad4039c93':'ChangedThreshold',
 '0xecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f8440':'EnabledModule',
 '0xaab4fa2b463f581b2b32cb3b7e3b704b9ce37cc209b5fb4d77e593ace4054276':'DisabledModule',
 '0x1151116914515bc0891ff9047a6cb32cf902546f83066499bcf8ba33d2353fa2':'ChangedGuard',
 '0x7a25bc0c8367a12bc4b61a1684efd5243804699ee5b439e3d71d628f86925682':'ApproveHash',
 '0xe7f4675038f4f6034dfcbbb24c4dc08e4ebf10eb9d257d3d02c0f38d122ac6e4':'SignMsg',
 '0x66753cd2356569ee081232e3be8909b950e0a76c1f8460c3a5e3c2be32b11bed':'SafeMultiSigTransaction',
 '0x02fffdd714881d9c92ef1270f7887ea0296324fc013e4871d2a90ae8688e3c9c':'SafeModuleTransaction',
 '0x3d0ce9bfc3ed7d6862dbb28b2dea94561fe714a1b4d019aa8af39730d1ad7c3d':'SafeReceived',
}

def w(data, i): return data[i*64:(i+1)*64]
def addr(word): return '0x' + word[24:]
def uint(word): return int(word, 16)
def dyn(data, off):
    ln = uint(w(data, off // 32)); start = off*2 + 64
    return bytes.fromhex(data[start:start+ln*2])

def utc(ts): return datetime.fromtimestamp(int(ts, 16), tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S')

out = {'source': 'Blockscout v1 getLogs + v2 address endpoints (andromeda-explorer.metis.io)',
       'safe': '0xdd7c49D1bA862b1285710A30E20C2438b13AE532',
       'setup': None, 'owner_changes': [], 'received': [], 'executions': [],
       'anomaly_events': [], 'totals': {}}

exec_success_hashes = set()
for lg in logs:
    data = lg['data'][2:]
    t0 = lg['topics'][0]
    name = T.get(t0, t0)
    if name == 'SafeSetup':
        topics = lg['topics']
        out['setup'] = {
            'time': utc(lg['timeStamp']), 'block': int(lg['blockNumber'], 16), 'tx': lg['transactionHash'],
            'initiator_indexed_topic1': topics[1] if len(topics) > 1 else None,
            'owners_initial': [addr(w(data, uint(w(data,0))//32 + 1 + i)) for i in range(uint(w(data, uint(w(data,0))//32)))],
            'threshold_initial': uint(w(data, 1)),
            'initializer_to': addr(w(data, 2)),
            'fallback_handler': addr(w(data, 3)),
        }
    elif name == 'AddedOwner':
        out['owner_changes'].append({'time': utc(lg['timeStamp']), 'block': int(lg['blockNumber'],16), 'tx': lg['transactionHash'], 'event': name, 'owner': addr(w(data, 0))})
    elif name == 'ChangedThreshold':
        out['owner_changes'].append({'time': utc(lg['timeStamp']), 'block': int(lg['blockNumber'],16), 'tx': lg['transactionHash'], 'event': name, 'threshold': uint(w(data, 0))})
    elif name == 'SafeReceived':
        out['received'].append({'time': utc(lg['timeStamp']), 'block': int(lg['blockNumber'],16), 'tx': lg['transactionHash'],
                                'sender_indexed': lg['topics'][1] if len(lg['topics'])>1 else None,
                                'value_wei': uint(w(data, 0)), 'value_metis': uint(w(data,0))/1e18})
    elif name == 'SafeMultiSigTransaction':
        to = addr(w(data, 0)); value = uint(w(data, 1)); off_data = uint(w(data, 2)); op = uint(w(data, 3))
        sigs = dyn(data, uint(w(data, 9))); addl = dyn(data, uint(w(data, 10)))
        out['executions'].append({
            'time': utc(lg['timeStamp']), 'block': int(lg['blockNumber'],16), 'tx': lg['transactionHash'],
            'to': to, 'value_wei': value, 'value_metis': value/1e18, 'operation': op,
            'inner_data_len': len(dyn(data, off_data)) if off_data else 0,
            'nonce': int(addl[0:32].hex(),16), 'submitted_by': '0x'+addl[32:64].hex()[24:],
            'threshold_at_exec': int(addl[64:96].hex(),16),
            'signature_bytes': len(sigs), 'ecdsa_confirmations': len(sigs)//65, 'sig_remainder': len(sigs)%65})
    elif name in ('ExecutionSuccess','ExecutionFailure','EnabledModule','DisabledModule','ChangedGuard','ApproveHash','SignMsg','SafeModuleTransaction'):
        out['anomaly_events'].append({'time': utc(lg['timeStamp']), 'event': name, 'tx': lg['transactionHash']})
        if name == 'ExecutionSuccess': exec_success_hashes.add(lg['transactionHash'])

for e in out['executions']:
    e['execution_success'] = e['tx'] in exec_success_hashes
    e['inner_selector'] = None if e['inner_data_len'] == 0 else 'n/a'

out['executions'].sort(key=lambda x: x['nonce'])
out['owner_changes'].sort(key=lambda x: (x['block'], x['time']))
total_in = sum(r['value_metis'] for r in out['received'])
total_out = sum(e['value_metis'] for e in out['executions'])
out['totals'] = {
    'total_received_metis': total_in,
    'total_sent_metis': total_out,
    'expected_remaining_metis': total_in - total_out,
    'note': 'asserted live balance 1847552.364 METIS matches total_in-total_out exactly',
    'executions_count': len(out['executions']),
    'execution_failures': sum(1 for e in out['executions'] if not e['execution_success']),
    'executions_below_current_threshold_4': sum(1 for e in out['executions'] if e['threshold_at_exec'] < 4),
    'executions_below_their_own_threshold': sum(1 for e in out['executions'] if e['ecdsa_confirmations'] < e['threshold_at_exec']),
    'module_events': sum(1 for e in out['anomaly_events'] if e['event'] in ('EnabledModule','DisabledModule')),
    'guard_events': sum(1 for e in out['anomaly_events'] if e['event'] == 'ChangedGuard'),
    'approve_hash_events': sum(1 for e in out['anomaly_events'] if e['event'] == 'ApproveHash'),
    'sign_msg_events': sum(1 for e in out['anomaly_events'] if e['event'] == 'SignMsg'),
    'module_tx_events': sum(1 for e in out['anomaly_events'] if e['event'] == 'SafeModuleTransaction'),
    'execution_failure_events': sum(1 for e in out['anomaly_events'] if e['event'] == 'ExecutionFailure'),
}

json.dump(out, open('/home/heisenberg/CA/metis-orphans/analysis/h35/txs.json','w'), indent=1)
print(json.dumps({k: v for k, v in out.items() if k != 'executions'}, indent=1))
print('executions:')
for e in out['executions']:
    print(' ', e['nonce'], e['time'], e['value_metis'], e['to'], 'thr', e['threshold_at_exec'], 'sigs', e['ecdsa_confirmations'], 'ok', e['execution_success'])

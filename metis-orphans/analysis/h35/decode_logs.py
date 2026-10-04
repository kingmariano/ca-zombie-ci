#!/usr/bin/env python3
"""Decode SafeL2 logs: SafeMultiSigTransaction (threshold at exec time, endorsers), SafeSetup, owner/threshold changes."""
import json, sys

logs = json.load(open('/home/heisenberg/CA/metis-orphans/analysis/h35/raw/logs_v1.json'))['result']

TOPICS = {
 '0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8':'SafeSetup',
 '0x442e715f626346e8c54381002da614f62bee8d27386535b2521ec8540898556e':'ExecutionSuccess',
 '0x23428b18acfb3ea64b08dc0c1d296ea9c09702c09083ca5272e64d115b687d23':'ExecutionFailure',
 '0x9465fa0c962cc76958e6373a993326400c1c94aa8e5ef2ea8fa34d033c60a4d2':'AddedOwner',
 '0x9465fa0c962cc76958e6373a993326400c1c94aa8e5ef2ea8fa34d033c60a4d2b':'X',
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
 '0x3d0ce9bfc3ed7d6862dbb28b2dea94561fe714a1b4d019aa8af39730d1ad7c3d':'?3d0ce9bf',
}

def w(data, i):  # i-th 32-byte word
    return data[i*64:(i+1)*64]

def addr(word): return '0x' + word[24:]

def uint(word): return int(word, 16)

def dyn_bytes(data, byte_off):
    if byte_off == 0: return b''
    ln = uint(w(data, byte_off // 32))
    start = byte_off * 2 + 64
    return bytes.fromhex(data[start:start + ln * 2])

rows = []
for lg in logs:
    data = lg['data'][2:]
    t0 = lg['topics'][0]
    name = TOPICS.get(t0, t0)
    ts = int(lg['timeStamp'], 16)
    blk = int(lg['blockNumber'], 16)
    tx = lg['transactionHash']
    if name == 'SafeMultiSigTransaction':
        to = addr(w(data, 0)); value = uint(w(data, 1))
        data_off = uint(w(data, 2)); op = uint(w(data, 3))
        safeTxGas = uint(w(data, 4)); baseGas = uint(w(data, 5)); gasPrice = uint(w(data, 6))
        gasToken = addr(w(data, 7)); refund = addr(w(data, 8))
        sigs = dyn_bytes(data, uint(w(data, 9)))
        addl = dyn_bytes(data, uint(w(data, 10)))
        # additionalInfo = abi.encode(nonce, msg.sender, threshold)
        nonce = int(addl[0:32].hex(), 16) if len(addl) >= 96 else None
        endorser = '0x' + addl[32:64].hex()[24:] if len(addl) >= 96 else None
        threshold = int(addl[64:96].hex(), 16) if len(addl) >= 96 else None
        sig_count = len(sigs) // 65
        sig_rem = len(sigs) % 65
        inner_sel = data[data_off*2:data_off*2+8] if data_off else ''
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, to=to, value=value, op=op,
                         safeTxGas=safeTxGas, baseGas=baseGas, gasPrice=gasPrice,
                         gasToken=gasToken, refundReceiver=refund, sig_bytes=len(sigs),
                         sig_count=sig_count, sig_rem=sig_rem, nonce=nonce, endorser=endorser,
                         threshold=threshold, inner_selector='0x'+inner_sel,
                         inner_data_len=len(dyn_bytes(data, data_off)) if data_off else 0))
    elif name == 'SafeSetup':
        # SafeSetup(address initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler)
        initiator = addr(w(data, 0))
        owners_off = uint(w(data, 1))
        threshold = uint(w(data, 2))
        initializer = addr(w(data, 3))
        fh = addr(w(data, 4))
        owners = []
        if owners_off:
            ln = uint(w(data, owners_off // 32))
            for i in range(ln):
                owners.append(addr(w(data, owners_off // 32 + 1 + i)))
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, initiator=initiator, owners=owners,
                         threshold=threshold, initializer=initializer, fallbackHandler=fh))
    elif name in ('AddedOwner', 'RemovedOwner'):
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, owner=addr(w(data, 0))))
    elif name == 'ChangedThreshold':
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, threshold=uint(w(data, 0))))
    elif name == 'ChangedGuard':
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, guard=addr(w(data, 0))))
    elif name in ('EnabledModule', 'DisabledModule'):
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, module=addr(w(data, 0))))
    elif name == 'ApproveHash':
        # ApproveHash(address indexed approvedHash, address indexed owner)
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, topics=lg['topics']))
    elif name == 'SignMsg':
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, data=lg['data']))
    else:
        rows.append(dict(ts=ts, blk=blk, tx=tx, ev=name, topic0=t0, data=lg['data'][:74]))

rows.sort(key=lambda r: (r['blk'], r['ts']))
from datetime import datetime, timezone
for r in rows:
    r['utc'] = datetime.fromtimestamp(r['ts'], tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
    print(json.dumps(r, default=str))

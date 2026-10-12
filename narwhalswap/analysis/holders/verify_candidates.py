#!/usr/bin/env python3
"""Direct on-chain balanceOf verification of candidate holder sets (fixes gaps in event/GoldRush data)."""
import json, os, sys, time
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))

def retry_batch(calls, chunk=40):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        for att in range(6):
            try:
                out.extend(bsc.rpc_batch(part))
                break
            except Exception:
                time.sleep(1.5 * (att + 1))
        else:
            out.extend([None] * len(part))
    return out

def verify(token, candidates, label, blk):
    addrs = sorted(set(a.lower() for a in candidates))
    calls = [("eth_call", [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)]) for a in addrs]
    calls += [("eth_getCode", [a, hex(blk)]) for a in addrs]
    res = retry_batch(calls)
    n = len(addrs)
    bal, code = {}, {}
    for a, r in zip(addrs, res[:n]):
        v = int(r, 16) if r and r != '0x' else 0
        bal[a] = v
    for a, r in zip(addrs, res[n:]):
        code[a] = (len(r) - 2) // 2 if r else 0
    nz = {a: v for a, v in bal.items() if v > 0}
    print(f"== {label}: candidates={n} nonzero={len(nz)} sum={sum(nz.values())/1e18:,.9f}")
    with open(os.path.join(HERE, f'verified_{label}.json'), 'w') as f:
        json.dump({'block': blk, 'token': token, 'balances': bal, 'code_len': code}, f, indent=1)
    return bal, code

def candidates_from(name):
    cands = set()
    # reconstructed
    try:
        r = json.load(open(f'reconstructed_{name}.json'))
        for a, v in r['balances'].items():
            if v > 0:
                cands.add(a)
    except Exception as e:
        print('recon load err', e)
    # goldrush lists
    try:
        pages = json.load(open(f'raw_goldrush/holders_{name}.json'))
        for pg in pages:
            for it in (pg.get('data') or {}).get('items') or []:
                cands.add(it['address'].lower())
    except Exception as e:
        print('gr load err', e)
    cands.add('0x' + '7' * 40)
    cands.discard('0x' + '0' * 40)
    return cands

if __name__ == '__main__':
    blk = bsc.block_number()
    print('block', blk)
    meta = json.load(open('token_meta.json'))
    for name, tok in [('rNLP5', '0x6451571cb5bee9fd575ad98506e96f3d09c66f91'),
                      ('rNLP6', '0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a')]:
        bal, code = verify(tok, candidates_from(name), name, blk)
        sup = meta['tokens'][name]['totalSupply_raw']
        tot = sum(v for v in bal.values() if v > 0)
        print(f"   SUM={tot} SUPPLY={sup} delta={(tot-sup)}")

#!/usr/bin/env python3
"""FINAL authoritative balance verification for NAR & THUGS.
- treats '0x' (empty) as FAILURE, never as zero
- multi-endpoint rotation, batches of 20, cooldown on failure streaks
- priority order: knowns/bigs first
- resumable; saves every 25 batches
"""
import json, os, sys, time, urllib.request
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
UA = {'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'}
RPCS = [
    "https://bsc-rpc.publicnode.com", "https://1rpc.io/bnb",
    "https://bsc-dataseed.bnbchain.org", "https://bsc-dataseed1.defibit.io",
    "https://bsc-dataseed1.ninicoin.io", "https://bsc-dataseed2.bnbchain.org",
    "https://bsc-dataseed3.bnbchain.org", "https://bsc-dataseed4.bnbchain.org",
    "https://bsc.publicnode.com", "https://rpc.4everland.org",
]
_idx = {"i": 0}
ZERO = '0x' + '0' * 40

def parse_hex_result(r):
    """Return int if r is a valid 32-byte hex result, else None."""
    if not isinstance(r, str):
        return None
    if r.startswith('0x') and len(r) == 66:
        try:
            return int(r, 16)
        except ValueError:
            return None
    return None

def batch_call(token, addrs, blk):
    payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                "params": [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)]}
               for j, a in enumerate(addrs)]
    data = json.dumps(payload).encode()
    try:
        url = RPCS[_idx["i"] % len(RPCS)]
        _idx["i"] += 1
        req = urllib.request.Request(url, data=data, headers=UA)
        with urllib.request.urlopen(req, timeout=25) as r:
            resp = json.loads(r.read().decode())
        if isinstance(resp, list):
            out = [None] * len(addrs)
            for item in resp:
                j = item.get('id')
                if isinstance(j, int) and 0 <= j < len(out):
                    out[j] = parse_hex_result(item.get('result'))
            return out
    except Exception:
        pass
    return None

def get_block():
    for att in range(10):
        try:
            url = RPCS[att % len(RPCS)]
            r = urllib.request.Request(url, data=json.dumps(
                {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(), headers=UA)
            with urllib.request.urlopen(r, timeout=20) as f:
                return int(json.loads(f.read().decode())['result'], 16)
        except Exception:
            time.sleep(1 + att)
    return None

def build_candidates(name):
    base = name.lower()
    cands = set()
    try:
        d = json.load(open(os.path.join(HERE, f'nar_recon_netpos.json' if name == 'NAR' else 'thugs_recon_netpos.json')))
        cands |= set(d['netpos'].keys())
    except Exception as e:
        print(name, 'recon err', e)
    pages = json.load(open(os.path.join(HERE, f'raw_goldrush/holders_{name}.json')))
    grv = {}
    for pg in pages:
        for it in (pg.get('data') or {}).get('items') or []:
            cands.add(it['address'].lower()); grv[it['address'].lower()] = int(it['balance'])
    tf = os.path.join(HERE, f'{base}_topic_missing.json')
    topic_extra = []
    if os.path.exists(tf):
        topic_extra = json.load(open(tf))
        cands |= set(topic_extra)
    # merge previous verified states + recon for PRIORITY
    prio_val = dict(grv)
    try:
        rc = json.load(open(os.path.join(HERE, 'nar_recon_netpos.json' if name == 'NAR' else 'thugs_recon_netpos.json')))
        for a, v in rc['netpos'].items():
            a = a.lower()
            v = int(v)
            if v > prio_val.get(a, 0):
                prio_val[a] = v
    except Exception:
        pass
    for fn in (f'verified_{name}.json', f'verified_{name}_v2.json', f'unknown_{name}.json'):
        p = os.path.join(HERE, fn)
        if os.path.exists(p):
            try:
                st = json.load(open(p))
                for a, v in (st.get('balances') or {}).items():
                    if v:
                        prio_val[a] = max(prio_val.get(a, 0), v)
            except Exception:
                pass
    cands.discard(ZERO)
    # sort: desc by prio_val, then unknown
    order = sorted(cands, key=lambda a: -prio_val.get(a, 0))
    return order, prio_val

def run(name, token):
    blk = get_block()
    print(f"=== {name} block {blk}", flush=True)
    order, prio_val = build_candidates(name)
    print(f"{name} candidates {len(order)}", flush=True)
    out_path = os.path.join(HERE, f'verified_{name}_FINAL.json')
    state = {'block': blk, 'balances': {}, 'done': []}
    if os.path.exists(out_path):
        try:
            st = json.load(open(out_path))
            if st.get('block') == blk:
                state = st
        except Exception:
            pass
    have = set(state['balances'])
    todo = [a for a in order if a not in have]
    print(f"{name} todo {len(todo)} (already {len(have)})", flush=True)
    CH = 20
    fail_streak = 0
    i = 0
    while i < len(todo):
        part = todo[i:i+CH]
        got = batch_call(token, part, blk)
        if got is None or all(v is None for v in got):
            fail_streak += 1
            if fail_streak % 12 == 0:
                print(f"{name} cooling down 45s (fail_streak={fail_streak})", flush=True)
                time.sleep(45)
                json.dump(state, open(out_path, 'w'))
            else:
                time.sleep(0.6)
            if fail_streak > 240:
                print(f"{name} too many failures, stopping round", flush=True)
                break
            continue
        fail_streak = 0
        any_new = False
        for a, v in zip(part, got):
            if v is not None:
                state['balances'][a] = v
                any_new = True
        i += CH
        if (i // CH) % 25 == 0:
            json.dump(state, open(out_path, 'w'))
            nz = sum(1 for v in state['balances'].values() if v)
            print(f"{name} progress {i}/{len(todo)} resolved={len(state['balances'])} nonzerodone... nz={nz}", flush=True)
        time.sleep(0.15)
    json.dump(state, open(out_path, 'w'))
    nz = {a: v for a, v in state['balances'].items() if v}
    sup = json.load(open(os.path.join(HERE, 'token_meta.json')))['tokens'][name]['totalSupply_raw']
    print(f"{name} DONE resolved={len(state['balances'])} nonzero={len(nz)} sum={sum(nz.values())/1e18:,.4f} supplynote={sup/1e18:,.4f}", flush=True)
    return state

if __name__ == '__main__':
    which = sys.argv[1] if len(sys.argv) > 1 else 'BOTH'
    if which in ('BOTH', 'NAR'):
        run('NAR', '0xa1303e6199b319a891b79685f0537d289af1fc83')
    if which in ('BOTH', 'THUGS'):
        run('THUGS', '0xe10e9822a5de22f8761919310dda35cd997d63c0')
    print('FINAL_VERIFY_DONE', flush=True)

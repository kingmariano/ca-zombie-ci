#!/usr/bin/env python3
"""Fast final verification pass: batches of 40 across fresh endpoints; NAR + THUGS."""
import json, os, sys, time, urllib.request
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
UA = {'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'}
RPCS = [
    "https://bsc-rpc.publicnode.com",
    "https://bsc.publicnode.com",
    "https://bsc-dataseed.bnbchain.org",
    "https://bsc-dataseed2.bnbchain.org",
    "https://bsc-dataseed3.bnbchain.org",
    "https://bsc-dataseed4.bnbchain.org",
    "https://bsc-dataseed1.bnbchain.org",
    "https://bsc-dataseed1.defibit.io",
    "https://bsc-dataseed1.ninicoin.io",
    "https://bsc-dataseed2.ninicoin.io",
]
_i = {"n": 0}
ZERO = '0x' + '0' * 40

def parse(r):
    if isinstance(r, str) and r.startswith('0x') and len(r) == 66:
        try:
            return int(r, 16)
        except Exception:
            return None
    return None

def batch(token, addrs, blk):
    payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                "params": [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)]}
               for j, a in enumerate(addrs)]
    body = json.dumps(payload).encode()
    for att in range(6):
        url = RPCS[_i["n"] % len(RPCS)]
        _i["n"] += 1
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=25) as r:
                resp = json.loads(r.read().decode())
            if isinstance(resp, list):
                out = [None] * len(addrs)
                for item in resp:
                    j = item.get('id')
                    if isinstance(j, int) and 0 <= j < len(out):
                        out[j] = parse(item.get('result'))
                return out
        except Exception:
            time.sleep(0.15)
    return None

def blknum():
    for att in range(10):
        url = RPCS[att % len(RPCS)]
        try:
            req = urllib.request.Request(url, data=json.dumps(
                {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(), headers=UA)
            with urllib.request.urlopen(req, timeout=15) as r:
                return int(json.loads(r.read().decode())['result'], 16)
        except Exception:
            time.sleep(0.5)
    return None

def load(fn):
    try:
        return json.load(open(os.path.join(HERE, fn)))
    except Exception:
        return {}

def run(name, token):
    blk = blknum()
    print(f"=== {name} block {blk}", flush=True)
    # candidates
    cands = set()
    rc = load('nar_recon_netpos.json' if name == 'NAR' else 'thugs_recon_netpos.json')
    cands |= set(rc.get('netpos', {}).keys())
    for pg in (load(f'raw_goldrush/holders_{name}.json') or []):
        for it in (pg.get('data') or {}).get('items') or []:
            cands.add(it['address'].lower())
    tm = load(f'{name.lower()}_topic_missing.json')
    if isinstance(tm, list):
        cands |= set(tm)
    cands.discard(ZERO)
    # priority: any previous nonzero value, desc
    prio = {}
    for fn in [f'verified_{name}_FINAL.json', f'verified_{name}_v2.json', f'verified_{name}.json', f'unknown_{name}.json']:
        d = load(fn)
        for a, v in (d.get('balances') or {}).items():
            if v:
                prio[a] = max(prio.get(a, 0), v)
    for a, v in rc.get('netpos', {}).items():
        v = int(v)
        if v > prio.get(a, 0):
            prio[a] = v
    for pg in (load(f'raw_goldrush/holders_{name}.json') or []):
        for it in (pg.get('data') or {}).get('items') or []:
            a = it['address'].lower(); v = int(it['balance'])
            if v > prio.get(a, 0):
                prio[a] = v
    order = sorted(cands, key=lambda a: -prio.get(a, 0))
    print(f"{name} candidates {len(order)}", flush=True)
    out_path = os.path.join(HERE, f'verified_{name}_FINAL3.json')
    state = {'block': blk, 'balances': {}}
    todo = list(order)  # FULL pass - re-read everything at one block
    print(f"{name} todo {len(todo)}", flush=True)
    CH = 40
    for i in range(0, len(todo), CH):
        part = todo[i:i+CH]
        got = batch(token, part, blk)
        if got is None:
            time.sleep(0.5)
            got = batch(token, part, blk)
        if got is None:
            print(f"{name} chunk {i}..{i+CH} failed; retrying later", flush=True)
            time.sleep(1.0)
            continue
        for a, v in zip(part, got):
            if v is not None:
                state['balances'][a] = v
        if (i // CH) % 15 == 0:
            json.dump(state, open(out_path, 'w'))
            print(f"{name} {i}/{len(todo)} resolved={len(state['balances'])}", flush=True)
        time.sleep(0.05)
    json.dump(state, open(out_path, 'w'))
    nz = {a: v for a, v in state['balances'].items() if v}
    print(f"{name} DONE resolved={len(state['balances'])} nonzero={len(nz)} sum={sum(nz.values())/1e18:,.4f}", flush=True)

if __name__ == '__main__':
    run('NAR', '0xa1303e6199b319a891b79685f0537d289af1fc83')
    run('THUGS', '0xe10e9822a5de22f8761919310dda35cd997d63c0')
    print('FASTFINAL_DONE', flush=True)

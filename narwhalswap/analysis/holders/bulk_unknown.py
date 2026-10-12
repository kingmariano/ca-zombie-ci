#!/usr/bin/env python3
"""Bulk-verify unknown topic addresses for NAR and THUGS (batched, 3 rounds)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
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

def batch_call(token, addrs, blk):
    payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                "params": [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)]}
               for j, a in enumerate(addrs)]
    data = json.dumps(payload).encode()
    for att in range(5):
        url = RPCS[_idx["i"] % len(RPCS)]
        _idx["i"] += 1
        try:
            req = urllib.request.Request(url, data=data, headers=UA)
            with urllib.request.urlopen(req, timeout=25) as r:
                resp = json.loads(r.read().decode())
            if isinstance(resp, list):
                out = [None] * len(addrs)
                for item in resp:
                    j = item.get('id')
                    if isinstance(j, int) and 0 <= j < len(out) and 'result' in item:
                        out[j] = item['result']
                return out
        except Exception:
            pass
        time.sleep(0.5 + att * 0.5)
    return None

def run(name, token_path, missing_path, out_path):
    blk = None
    for att in range(8):
        try:
            r = urllib.request.Request(RPCS[0], data=json.dumps(
                {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(), headers=UA)
            with urllib.request.urlopen(r, timeout=20) as f:
                blk = int(json.loads(f.read().decode())['result'], 16)
            break
        except Exception:
            time.sleep(1)
    if blk is None:
        print('no rpc'); return
    print(name, 'block', blk, flush=True)
    todo = json.load(open(missing_path))
    balances = {}
    if os.path.exists(out_path):
        try:
            st = json.load(open(out_path))
            if st.get('block') == blk:
                balances = st.get('balances', {})
        except Exception:
            pass
    todo = [a for a in todo if a not in balances]
    print(name, 'todo', len(todo), flush=True)
    CH = 25
    for rnd in range(3):
        still = []
        for i in range(0, len(todo), CH):
            part = todo[i:i+CH]
            got = batch_call(token_path, part, blk)
            if got is None:
                still.extend(part)
                continue
            for a, r in zip(part, got):
                if r is not None:
                    balances[a] = int(r, 16) if r != '0x' else 0
                else:
                    still.append(a)
            time.sleep(0.12)
        json.dump({'block': blk, 'balances': balances}, open(out_path, 'w'))
        print(f"{name} round {rnd}: resolved={len(balances)} still={len(still)}", flush=True)
        todo = still
        if not still:
            break
    nz = {a: v for a, v in balances.items() if v and v > 0}
    print(f"{name} DONE resolved={len(balances)} nonzero={len(nz)} sum={sum(nz.values())/1e18:,.4f}", flush=True)

if __name__ == '__main__':
    run('NAR', '0xa1303e6199b319a891b79685f0537d289af1fc83', 'nar_topic_missing.json', os.path.join(HERE, 'unknown_NAR.json'))
    run('THUGS', '0xe10e9822a5de22f8761919310dda35cd997d63c0', 'thugs_topic_missing.json', os.path.join(HERE, 'unknown_THUGS.json'))

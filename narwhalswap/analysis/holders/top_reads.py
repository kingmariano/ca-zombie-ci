#!/usr/bin/env python3
"""Re-read the top holders of every token at ONE final block; write top_reads.json (override for the assembler)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
UA = {'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'}
RPCS = ["https://bsc-rpc.publicnode.com", "https://bsc.publicnode.com",
        "https://bsc-dataseed.bnbchain.org", "https://bsc-dataseed2.bnbchain.org",
        "https://bsc-dataseed3.bnbchain.org", "https://bsc-dataseed4.bnbchain.org"]
_i = {"n": 0}
TOKENS = {
    'NAR': '0xa1303e6199b319a891b79685f0537d289af1fc83',
    'NLP_NARWBNB': '0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2',
    'LP_WBNBTHUGS': '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957',
    'LP_WBNBBUSD': '0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3',
    'rNLP5': '0x6451571cb5bee9fd575ad98506e96f3d09c66f91',
    'rNLP6': '0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a',
    'THUGS': '0xe10e9822a5de22f8761919310dda35cd997d63c0',
}

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
            with urllib.request.urlopen(req, timeout=20) as r:
                resp = json.loads(r.read().decode())
            if isinstance(resp, list):
                out = [None] * len(addrs)
                for item in resp:
                    j = item.get('id')
                    if isinstance(j, int) and 0 <= j < len(out):
                        rr = item.get('result')
                        if isinstance(rr, str) and rr.startswith('0x') and len(rr) == 66:
                            out[j] = int(rr, 16)
                return out
        except Exception:
            time.sleep(0.2)
    return None

def load(fn):
    try:
        return json.load(open(os.path.join(HERE, fn)))
    except Exception:
        return {}

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

def main():
    blk = blknum()
    out = {'block': blk, 'tokens': {}}
    for name in TOKENS:
        d = load(f'verified_{name}_FINAL2.json') or load(f'verified_{name}_FINAL.json') or load(f'verified_{name}_v2.json') or load(f'verified_{name}.json') or {}
        b = d.get('balances') or {}
        rows = sorted([(a, v) for a, v in b.items() if v], key=lambda x: -x[1])[:80]
        addrs = [a for a, _ in rows]
        if not addrs:
            continue
        res = batch(TOKENS[name], addrs, blk)
        if res is None:
            res = batch(TOKENS[name], addrs, blk)
        vals = {}
        for a, v in zip(addrs, res or []):
            if v is not None:
                vals[a] = v
        out['tokens'][name] = vals
        print(name, f"{len(vals)}/{len(addrs)} re-read at block {blk}", flush=True)
    json.dump(out, open(os.path.join(HERE, 'top_reads.json'), 'w'), indent=1)
    print('top_reads.json written')

if __name__ == '__main__':
    main()

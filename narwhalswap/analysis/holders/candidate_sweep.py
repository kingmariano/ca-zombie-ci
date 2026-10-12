#!/usr/bin/env python3
"""Sweep balanceOf for all known narwhal-ecosystem candidate addresses across the 7 tokens."""
import sys, json, glob, os, re
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
ANA = '/home/heisenberg/CA/narwhalswap/analysis'

TOKENS = {
    "NAR": "0xa1303e6199b319a891b79685f0537d289af1fc83",
    "NLP_NARWBNB": "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
    "LP_WBNBTHUGS": "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
    "LP_WBNBBUSD": "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
    "rNLP5": "0x6451571cb5bee9fd575ad98506e96f3d09c66f91",
    "rNLP6": "0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a",
    "THUGS": "0xe10e9822a5de22f8761919310dda35cd997d63c0",
}

def load_candidates():
    cands = {}
    # sources filenames that are addresses
    for f in glob.glob(os.path.join(ANA, 'sources', '*')):
        m = re.match(r'(0x[0-9a-fA-F]{40})', os.path.basename(f))
        if m: cands[m.group(1).lower()] = 'source:' + os.path.basename(f)
    # state dumps
    try:
        sd = json.load(open(os.path.join(ANA, 'state-dump.json')))
        for p, v in (sd.get('pairs') or {}).items():
            cands[p.lower()] = 'pair'
            for tk in ('token0', 'token1'):
                if v.get(tk): cands[v[tk].lower()] = 'pair-token'
    except Exception as e: print('state-dump err', e)
    for fname in ('collecter-state.json', 'farms-state.json'):
        try:
            d = json.load(open(os.path.join(ANA, fname)))
            def walk(o, path=''):
                if isinstance(o, dict):
                    for k, v in o.items():
                        if isinstance(k, str) and re.match(r'^0x[0-9a-fA-F]{40}$', k): cands[k.lower()] = fname
                        if isinstance(v, str) and re.match(r'^0x[0-9a-fA-F]{40}$', v): cands[v.lower()] = fname + ':' + k
                        walk(v, path + '/' + str(k))
                elif isinstance(o, list):
                    for i, v in enumerate(o): walk(v, path + '/' + str(i))
            walk(d)
        except Exception as e: print(fname, 'err', e)
    # 0x7777 token list (rNLP generations & LP tokens)
    try:
        d = json.load(open(os.path.join(HERE, 'raw_goldrush', 'balances_7777.json')))
        for it in d['data']['items']:
            cands[it['contract_address'].lower()] = 'from-7777-balances:' + str(it['contract_ticker_symbol'])
    except Exception as e: print('7777 err', e)
    # known big ones
    for a, why in {
        '0x7777777777777777777777777777777777777777': 'burn pool 0x7777',
        '0x000000000000000000000000000000000000dead': 'dead',
        '0x0000000000000000000000000000000000000000': 'zero',
        '0x1d227f7e283d653a60f94d2350cab7a49bb85c6f': 'farm5',
        '0x6da9ee0c0571b63e38950d1e12e835d5343f601b': 'farm6',
        '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9': 'team',
        '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5': 'governance',
        '0xb9fa84912ff2383a617d8b433e926adf0dd3fea1': 'factory',
        '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9': 'collector',
        '0x1d791eaa684a21de92618dedea7bf373e2486956': 'powerStrategy',
    }.items(): cands[a] = why
    return cands

def main():
    cands = load_candidates()
    print('candidates:', len(cands))
    blk = bsc.block_number()
    out = {"block": blk, "tokens": {}, "candidates": cands}
    for tname, taddr in TOKENS.items():
        bal = {}
        items = list(cands.items())
        for i in range(0, len(items), 50):
            chunk = items[i:i+50]
            calls = [("eth_call", [{"to": taddr, "data": bsc.SEL["balanceOf"] + bsc.word(a)}, hex(blk)]) for a, _ in chunk]
            res = bsc.rpc_batch(calls)
            for (a, why), r in zip(chunk, res):
                v = None
                if r and r != '0x':
                    try: v = int(r, 16)
                    except Exception: v = None
                if v: bal[a] = v
        out['tokens'][tname] = bal
        print(f"{tname}: {len(bal)} of {len(cands)} non-zero")
        # show top 10 of sweep
        for a, v in sorted(bal.items(), key=lambda x: -x[1])[:10]:
            print(f"   {a} {v/1e18:,.6f}  [{cands[a][:40]}]")
    json.dump(out, open(os.path.join(HERE, 'candidate_sweep.json'), 'w'), indent=1)

if __name__ == '__main__':
    main()

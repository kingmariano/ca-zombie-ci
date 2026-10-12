#!/usr/bin/env python3
"""Discover all rNLP generations + farms; sweep NAR/NLP across farms and pairs."""
import json, os, sys, time
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc
from keccak import selector

HERE = os.path.dirname(os.path.abspath(__file__))
ANA = '/home/heisenberg/CA/narwhalswap/analysis'
OUT = os.path.join(HERE, 'farm_discovery.json')

def retry_batch(calls, chunk=40):
    out = []
    for i in range(0, len(calls), chunk):
        for attempt in range(6):
            try:
                res = bsc.rpc_batch(calls[i:i+chunk])
                out.extend(res); break
            except Exception as e:
                time.sleep(1.5*(attempt+1))
        else:
            out.extend([None]*(min(chunk, len(calls)-i)))
    return out

def main():
    blk = bsc.block_number()
    print('block', blk)
    # 1) all rNLP + NLP-ish token contracts known from 0x7777 balances
    d = json.load(open(os.path.join(HERE, 'raw_goldrush', 'balances_7777.json')))
    rnlps = {}
    lps = {}
    for it in d['data']['items']:
        sym = (it.get('contract_ticker_symbol') or '')
        if sym == 'rNLP':
            rnlps[it['contract_address'].lower()] = int(it['balance'])
        elif sym == 'NLP':
            lps[it['contract_address'].lower()] = int(it['balance'])
    print('rNLP contracts from 0x7777:', len(rnlps))
    for k in rnlps: print('  ', k)
    print('NLP contracts from 0x7777:', list(lps))
    # 2) for each rNLP: owner() and minter() -> farm candidates
    sel_owner = bsc.SEL['owner']          # 0x8da5cb5b
    sel_minter = selector('minter()')
    sel_getOwner = bsc.SEL['getOwner']    # 0x893d20e8
    sel_nar = selector('nar()')
    calls = []
    keys = []
    for r in rnlps:
        for sname, sel in [('owner', sel_owner), ('minter', sel_minter), ('getOwner', sel_getOwner)]:
            calls.append(("eth_call", [{"to": r, "data": sel}, hex(blk)]))
            keys.append((r, sname))
    res = retry_batch(calls)
    cand_farms = set()
    rnlp_meta = {}
    for (r, sname), v in zip(keys, res):
        if v and v != '0x' and len(v) >= 66:
            addr = '0x' + v[-40:]
            rnlp_meta.setdefault(r, {})[sname] = addr
            if addr != '0x0000000000000000000000000000000000000000':
                cand_farms.add(addr)
    for r, meta in rnlp_meta.items():
        print('rNLP', r, meta)
    print('candidate farms:', len(cand_farms))
    # 3) farm: lpToken(), nar(), rnlp(); verify rnlp relationship
    sel_lp = selector('lpToken()')
    sel_rnlp = selector('rnlp()')
    farm_info = {}
    calls = []; keys = []
    for f in sorted(cand_farms):
        for sname, sel in [('lpToken', sel_lp), ('nar', sel_nar), ('rnlp', sel_rnlp)]:
            calls.append(("eth_call", [{"to": f, "data": sel}, hex(blk)]))
            keys.append((f, sname))
    res = retry_batch(calls)
    for (f, sname), v in zip(keys, res):
        if v and v != '0x' and len(v) >= 66:
            farm_info.setdefault(f, {})[sname] = '0x' + v[-40:]
    for f, info in sorted(farm_info.items()):
        print('farm?', f, info)
    json.dump({'block': blk, 'rnlps': rnlps, 'rnlp_meta': rnlp_meta,
               'cand_farms': sorted(cand_farms), 'farm_info': farm_info},
              open(OUT, 'w'), indent=1)

if __name__ == '__main__':
    main()

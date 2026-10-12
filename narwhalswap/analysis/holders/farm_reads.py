#!/usr/bin/env python3
"""Farm reads for rNLP holders: farm.balanceOf(holder) + farm.userInfo(holder) decoded.

userInfo(address) selector 0x1959a002 -> 5 words:
0 userRewardPerTokenPaid, 1 rewards, 2 currentBuffrate, 3 currentPower, 4 timeStamp
"""
import json, os, sys, time
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
USERINFO_SEL = '0x1959a002'
FIELDS = ['userRewardPerTokenPaid', 'rewards', 'currentBuffrate', 'currentPower', 'timeStamp']

def retry_batch(calls, chunk=40):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        for att in range(6):
            try:
                out.extend(bsc.rpc_batch(part)); break
            except Exception:
                time.sleep(1.5 * (att + 1))
        else:
            out.extend([None] * len(part))
    return out

def run(rnlp_name, farm, out_name):
    blk = bsc.block_number()
    v = json.load(open(os.path.join(HERE, f'verified_{rnlp_name}.json')))
    holders = [a for a, bal in v['balances'].items() if bal > 0]
    print(f"== {rnlp_name}: {len(holders)} holders, farm {farm}, block {blk}")
    calls, keys = [], []
    for h in holders:
        calls.append(("eth_call", [{"to": farm, "data": bsc.SEL['balanceOf'] + bsc.word(h)}, hex(blk)]))
        keys.append((h, 'staked'))
        calls.append(("eth_call", [{"to": farm, "data": USERINFO_SEL + bsc.word(h)}, hex(blk)]))
        keys.append((h, 'userinfo'))
    res = retry_batch(calls)
    data = {}
    for (h, kind), r in zip(keys, res):
        d = data.setdefault(h, {})
        if kind == 'staked':
            d['staked'] = int(r, 16) if r and r != '0x' else None
        else:
            if r and r != '0x' and len(r) >= 2 + 64 * 5:
                words = [int(r[2 + i * 64:2 + (i + 1) * 64], 16) for i in range(5)]
                d['userInfo'] = dict(zip(FIELDS, words))
            else:
                d['userInfo'] = None
    out = {'block': blk, 'farm': farm, 'rnlp': rnlp_name,
           'rnlp_token': '0x6451571cb5bee9fd575ad98506e96f3d09c66f91' if rnlp_name == 'rNLP5' else '0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a',
           'supply_raw': v['balances'] and sum(1 for _ in v['balances']),  # placeholder replaced below
           'rows': []}
    meta = json.load(open(os.path.join(HERE, 'token_meta.json')))
    out['supply_raw'] = meta['tokens'][rnlp_name]['totalSupply_raw']
    for h in holders:
        d = data[h]
        out['rows'].append({
            'holder': h,
            'rnlp_balance': v['balances'][h],
            'share_pct': v['balances'][h] / out['supply_raw'] * 100,
            'staked_lp': d['staked'],
            'userInfo': d['userInfo'],
            'is_contract': bool(v['code_len'].get(h, 0) > 0),
            'code_len': v['code_len'].get(h, 0),
        })
    out['rows'].sort(key=lambda x: -x['rnlp_balance'])
    json.dump(out, open(os.path.join(HERE, f'{out_name}.json'), 'w'), indent=1)
    print('saved', out_name)
    for row in out['rows'][:10]:
        print(f"  {row['holder']} rnlp={row['rnlp_balance']/1e18:,.6f} share={row['share_pct']:.4f}% staked={0 if row['staked_lp'] is None else row['staked_lp']/1e18:,.6f} contract={row['is_contract']}")

if __name__ == '__main__':
    run('rNLP5', '0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f', 'farm_reads_rNLP5')
    run('rNLP6', '0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B', 'farm_reads_rNLP6')

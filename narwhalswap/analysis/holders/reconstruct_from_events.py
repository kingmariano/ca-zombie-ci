#!/usr/bin/env python3
"""Reconstruct ERC20 holder balances from a GoldRush events JSONL (Transfer events only)."""
import json, sys, os

TF = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'

def reconstruct(path, supply_raw=None):
    bal = {}
    n_transfer = 0
    n_other = 0
    min_blk = None
    max_blk = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            topics = e.get('raw_log_topics') or []
            if not topics or topics[0].lower() != TF:
                n_other += 1
                continue
            if len(topics) < 3:
                n_other += 1
                continue
            frm = '0x' + topics[1][-40:].lower()
            to = '0x' + topics[2][-40:].lower()
            data = e.get('raw_log_data') or '0x'
            val = int(data, 16) if data and data != '0x' else 0
            n_transfer += 1
            bh = e.get('block_height')
            if bh is not None:
                min_blk = bh if min_blk is None else min(min_blk, bh)
                max_blk = bh if max_blk is None else max(max_blk, bh)
            bal[frm] = bal.get(frm, 0) - val
            bal[to] = bal.get(to, 0) + val
    # drop zero/negative dust
    out = {a: v for a, v in bal.items() if v > 0}
    zero = '0x' + '0' * 40
    meta = {
        'transfers': n_transfer, 'other_events': n_other,
        'holders': len(out), 'sum_raw': sum(out.values()),
        'zero_addr_balance': bal.get(zero, 0),
        'min_block': min_blk, 'max_block': max_blk,
    }
    if supply_raw is not None:
        meta['supply_raw'] = supply_raw
        meta['delta_vs_supply'] = sum(out.values()) - supply_raw
    return out, meta

if __name__ == '__main__':
    path = sys.argv[1]
    supply = int(sys.argv[2]) if len(sys.argv) > 2 else None
    bal, meta = reconstruct(path, supply)
    meta['negative_or_zero_dropped'] = True
    top = sorted(bal.items(), key=lambda x: -x[1])[:15]
    print(json.dumps(meta, indent=1))
    for a, v in top:
        print(f"  {a} {v/1e18:,.6f}")

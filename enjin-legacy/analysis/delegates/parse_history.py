#!/usr/bin/env python3
"""Parse raw Etherscan logs pages into an ordered history of delegates-table changes."""
import json, glob, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))

def decode_string(data_hex: str) -> str:
    b = bytes.fromhex(data_hex[2:])
    off = int.from_bytes(b[0:32], 'big')
    length = int.from_bytes(b[off:off+32], 'big')
    return b[off+32:off+32+length].decode('utf-8', errors='replace')

def parse_pages(label: str):
    rows = []
    for f in sorted(glob.glob(os.path.join(BASE, 'raw', f'{label}_page_*.json'))):
        d = json.load(open(f))
        assert d.get('status') == '1' and isinstance(d['result'], list), f'{f}: {d}'
        for e in d['result']:
            t = e['topics']
            assert t[0].lower() == '0x3234040ce3bd4564874e44810f198910133a1b24c4e84aac87edbf6b458f5353'
            selectors = '0x' + t[1][2:10]
            old = '0x' + t[2][-40:]
            new = '0x' + t[3][-40:]
            rows.append({
                'block': int(e['blockNumber'], 16),
                'logIndex': int(e['logIndex'], 16),
                'tx': e['transactionHash'],
                'selector': selectors,
                'old': old,
                'new': new,
                'signature': decode_string(e['data']),
                'timestamp': int(e['timeStamp'], 16),
            })
    rows.sort(key=lambda r: (r['block'], r['logIndex']))
    return rows

def main():
    history = {}
    for label in ('nft', 'ft'):
        rows = parse_pages(label)
        history[label] = rows
        print(f'{label}: {len(rows)} events, blocks {rows[0]["block"]}..{rows[-1]["block"]}')
    with open(os.path.join(BASE, 'history.json'), 'w') as f:
        json.dump(history, f, indent=2)
    print('wrote history.json')

if __name__ == '__main__':
    main()

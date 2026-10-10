#!/usr/bin/env python3
"""Fetch all DelegationRewardsClaimed events for the StarGate proxy in a block window.
Uses keyless Thor REST /logs/event with offset pagination; stores minimal fields."""
import json, subprocess, sys, os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(BASE, 'raw')
TOPIC = '0xf4cde2b5a31835b3dac5ba586238b7160063a46803ccbf2322db0933efe694ed'
ADDR = '0x03c557be98123fdb6fad325328ac6eb77de7248c'

def fetch(frm, to, offset, limit=1000):
    body = {
        "range": {"unit": "block", "from": frm, "to": to},
        "options": {"offset": offset, "limit": limit},
        "criteriaSet": [{"address": ADDR, "topic0": TOPIC}],
        "order": "asc",
    }
    p = subprocess.run(['curl', '-s', '--max-time', '60', '-X', 'POST',
                        'https://mainnet.vechain.org/logs/event',
                        '-H', 'Content-Type: application/json',
                        '-d', json.dumps(body)], capture_output=True, text=True)
    try:
        return json.loads(p.stdout)
    except Exception:
        return []

def main():
    frm, to, outfile, maxev = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], int(sys.argv[4]
        if len(sys.argv) > 4 else 200000)
    offset = 0
    total = 0
    with open(outfile, 'w') as f:
        while total < maxev:
            evs = fetch(frm, to, offset)
            if not evs:
                break
            for e in evs:
                d = e['data'][2:]
                rec = {
                    'block': e['meta']['blockNumber'],
                    'tx': e['meta']['txID'],
                    'receiver': '0x' + e['topics'][1][-40:],
                    'tokenId': int(e['topics'][2], 16),
                    'delegationId': int(e['topics'][3], 16),
                    'amount': int(d[0:64], 16),
                    'firstPeriod': int(d[64:128], 16),
                    'lastPeriod': int(d[128:192], 16),
                }
                f.write(json.dumps(rec) + '\n')
            total += len(evs)
            offset += len(evs)
            if total % 10000 < 1000:
                print(f'  fetched {total} (offset {offset})', flush=True)
            if len(evs) < 1000:
                break
    print(f'done: {total} events -> {outfile}')

if __name__ == '__main__':
    main()

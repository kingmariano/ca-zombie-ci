#!/usr/bin/env python3
"""Generic fetcher for StarGate proxy events with two indexed topic filters.
Usage: fetch_events.py <fromBlock> <toBlock> <topic0> <outfile.jsonl> [maxEvents]
Amount is taken as first data word (works for DelegationInitiated / DelegationWithdrawn)."""
import json, subprocess, sys, os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(BASE, 'raw')
ADDR = '0x03c557be98123fdb6fad325328ac6eb77de7248c'

def fetch(frm, to, topic0, offset, limit=1000):
    body = {"range": {"unit": "block", "from": frm, "to": to},
            "options": {"offset": offset, "limit": limit},
            "criteriaSet": [{"address": ADDR, "topic0": topic0}],
            "order": "asc"}
    p = subprocess.run(['curl', '-s', '--max-time', '60', '-X', 'POST',
                        'https://mainnet.vechain.org/logs/event',
                        '-H', 'Content-Type: application/json',
                        '-d', json.dumps(body)], capture_output=True, text=True)
    try:
        return json.loads(p.stdout)
    except Exception:
        return []

def main():
    frm, to, topic0, outfile = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4]
    maxev = int(sys.argv[5]) if len(sys.argv) > 5 else 300000
    offset = 0; total = 0
    with open(outfile, 'w') as f:
        while total < maxev:
            evs = fetch(frm, to, topic0, offset)
            if not evs: break
            for e in evs:
                d = e['data'][2:]
                f.write(json.dumps({
                    'block': e['meta']['blockNumber'], 'tx': e['meta']['txID'],
                    'tokenId': int(e['topics'][1], 16),
                    'delegationId': int(e['topics'][3], 16) if len(e['topics']) > 3 else None,
                    'amount': int(d[0:64], 16)}) + '\n')
            total += len(evs); offset += len(evs)
            if len(evs) < 1000: break
    print(f'done: {total} -> {outfile}')

if __name__ == '__main__':
    main()

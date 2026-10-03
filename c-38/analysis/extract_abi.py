#!/usr/bin/env python3
"""Extract ABI JSON for specific contract addresses from the Tectonic app bundle (robust)."""
import json
import sys

path = sys.argv[1]
want = [a.lower() for a in sys.argv[2:]]
data = open(path, "r", encoding="utf-8", errors="replace").read()


def scan_string(s, start):
    """start points at first char after opening quote. Return (content, index_after_closing_quote)."""
    out = []
    i = start
    n = len(s)
    while i < n:
        c = s[i]
        if c == '\\':
            out.append(c)
            if i + 1 < n:
                out.append(s[i + 1])
                i += 2
                continue
            i += 1
            continue
        if c == '"':
            return ''.join(out), i + 1
        out.append(c)
        i += 1
    return ''.join(out), i


def deep_json(s):
    for _ in range(5):
        if isinstance(s, (list, dict)):
            return s
        try:
            s = json.loads(s)
        except Exception:
            try:
                s = json.loads('"' + s + '"')
            except Exception:
                return None
    return s if isinstance(s, (list, dict)) else None


needle = '"contractName":"'
i = 0
found = {}
while True:
    i = data.find(needle, i)
    if i < 0:
        break
    j = data.find('","address":"', i)
    if j < 0:
        break
    name = data[i + len(needle):j]
    k = j + len('","address":"')
    addr = data[k:k + 42]
    if not (addr.startswith('0x') and len(addr) == 42):
        i = k
        continue
    m = data.find('","abi":"', k)
    if m < 0 or m > k + 200:
        i = k
        continue
    s = m + len('","abi":"')
    raw, nxt = scan_string(data, s)
    abi = deep_json(raw)
    if isinstance(abi, list) and addr.lower() in want:
        found.setdefault(addr.lower(), []).append((name, abi))
    i = max(nxt, k)

for addr in want:
    for name, abi in found.get(addr, []):
        print(f"### {name} {addr}")
        for item in abi:
            if not isinstance(item, dict):
                continue
            if item.get('type') == 'function':
                ins = ','.join(x['type'] for x in item.get('inputs', []))
                outs = ','.join(x['type'] for x in item.get('outputs', []))
                mut = item.get('stateMutability', '')
                print(f"  {item['name']}({ins}) -> ({outs}) [{mut}]")
        print()

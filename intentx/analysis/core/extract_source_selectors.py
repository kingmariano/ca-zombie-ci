#!/usr/bin/env python3
"""Extract all external/public function selectors from Solidity sources, resolving structs/enums.
Usage: python3 extract_source_selectors.py <root_dir> > out.json"""
import os, re, sys, json
from eth_utils import keccak

root = sys.argv[1]
files = []
for dp, dn, fn in os.walk(root):
    for f in fn:
        if f.endswith('.sol'):
            files.append(os.path.join(dp, f))

structs = {}   # name -> [(type, name)]
enums = set()
fdecls = []    # (file, name, rawparams, vis)

fn_re = re.compile(r'\bfunction\s+(\w+)\s*\(')
struct_re = re.compile(r'\bstruct\s+(\w+)\s*\{')
enum_re = re.compile(r'\benum\s+(\w+)\s*\{')

def balanced(s, i, o='(', c=')'):
    d = 0
    while i < len(s):
        if s[i] == o: d += 1
        elif s[i] == c:
            d -= 1
            if d == 0: return i
        i += 1
    return -1

for path in files:
    txt = open(path, errors='ignore').read()
    for m in struct_re.finditer(txt):
        name = m.group(1)
        end = txt.find('}', m.end())
        if end < 0: continue
        body = txt[m.end():end]
        fields = []
        for line in body.split(';'):
            line = line.strip()
            if not line or line.startswith('//'): continue
            toks = line.split()
            if len(toks) >= 2:
                fields.append((toks[0], toks[1]))
        structs.setdefault(name, fields)
    for m in enum_re.finditer(txt):
        enums.add(m.group(1))
    for m in fn_re.finditer(txt):
        name = m.group(1)
        j = balanced(txt, m.end()-1)
        if j < 0: continue
        params = txt[m.end():j]
        rest = txt[j+1:j+200]
        # cut at first ';' or '{'
        cut = min([x for x in [rest.find(';'), rest.find('{')] if x >= 0] or [len(rest)])
        tail = rest[:cut]
        fdecls.append((path, name, params, tail))

def canon_type(t, depth=0):
    t = t.strip()
    if depth > 6: return 'uint256'
    # arrays
    am = re.match(r'^(.*)\[(\d*)\]$', t)
    arr = ''
    if am:
        t = am.group(1).strip(); arr = f"[{am.group(2)}]"
    # strip data location
    for loc in [' memory', ' calldata', ' storage']:
        if t.endswith(loc): t = t[:-len(loc)].strip()
    if t in enums: return 'uint8' + arr
    base = t
    if base in structs:
        inner = ','.join(canon_type(ft, depth+1) for ft, fn_ in structs[base])
        return f"({inner}){arr}"
    if base == 'address payable': return 'address' + arr
    if base.startswith('contract '): return 'address' + arr
    return base + arr

def parse_params(raw):
    out = []
    cur = ''
    d = 0
    for ch in raw:
        if ch in '([': d += 1
        if ch in ')]': d -= 1
        if ch == ',' and d == 0:
            out.append(cur); cur = ''
        else:
            cur += ch
    if cur.strip(): out.append(cur)
    res = []
    for p in out:
        p = ' '.join(p.split())
        if not p: continue
        toks = p.split()
        if len(toks) == 1:
            res.append(canon_type(toks[0]))
        elif toks[0] in ('uint256[]','bytes32','string','bytes'):
            res.append(canon_type(toks[0]))
        else:
            # last token may be name; if first token is struct/enum we need multi-token type? not for these
            res.append(canon_type(toks[0]))
    return res

found = {}
for path, name, rawp, tail in fdecls:
    if 'external' not in tail and 'public' not in tail: continue
    if name in ('constructor', 'receive', 'fallback'): continue
    try:
        types = parse_params(rawp)
    except Exception:
        continue
    sig = f"{name}({','.join(types)})"
    sel = '0x' + keccak(text=sig)[:4].hex()
    found.setdefault(sel, (sig, os.path.relpath(path, root)))

json.dump(found, open(sys.argv[2], 'w'), indent=1)
targets = ['0xb052244f', '0xb98ff519', '0xcb32cdbc', '0xe0020899', '0xfa59fbe8']
for t in targets:
    print(t, '->', found.get(t, 'NOT FOUND'))
print('total selectors from source:', len(found))

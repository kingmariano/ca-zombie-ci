#!/usr/bin/env python3
"""Extract one function from a sui disassembly and normalize for diffing."""
import re, sys

def parse_functions(path):
    txt = open(path).read()
    # function header: line ending with '{' that contains 'fun ' (may span type params)
    lines = txt.split('\n')
    funcs = {}
    cur = None
    buf = []
    depth = 0
    for ln in lines:
        if cur is None:
            hdr = re.match(r'^(public(\(friend\)|\(package\))?|entry|fun|friend)\s+(?:fun\s+)?([A-Za-z0-9_]+)\s*(<.*?>)?\s*\(', ln)
            if hdr and ln.rstrip().endswith('{'):
                name = hdr.group(3)
                cur = name; buf = [ln]; depth = ln.count('{') - ln.count('}')
            else:
                continue
        else:
            buf.append(ln)
            depth += ln.count('{') - ln.count('}')
            if depth <= 0:
                funcs.setdefault(cur, []).append('\n'.join(buf))
                cur = None; buf = []; depth = 0
    return funcs

def normalize(body):
    out = []
    for ln in body.split('\n'):
        # drop label-only lines and declaration of locals lines keep types
        m = re.match(r'^L\d+:\s*(loc\d+):\s*(.*)$', ln)
        if m:
            out.append(f'LOC {m.group(2)}')
            continue
        ln = re.sub(r'L\d+:', '', ln)
        ln = re.sub(r'loc\d+', 'L', ln)
        ln = re.sub(r'\[(\d+)\]', '[]', ln)
        ln = ln.strip()
        if ln:
            out.append(ln)
    return out

if __name__ == '__main__':
    a, b, names = sys.argv[1], sys.argv[2], sys.argv[3:]
    fa, fb = parse_functions(a), parse_functions(b)
    for n in names:
        A = normalize(fa.get(n, ['<missing>'])[0])
        B = normalize(fb.get(n, ['<missing>'])[0])
        import difflib
        print(f'######## {n}: {a} vs {b} ########')
        for line in difflib.unified_diff(A, B, lineterm='', n=1):
            print(line)

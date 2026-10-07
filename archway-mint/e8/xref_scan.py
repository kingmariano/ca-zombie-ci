#!/usr/bin/env python3
"""Call-site xref scanner: find every direct `call`/`jmp` to a set of target
functions in a GNU objdump dump of archwayd, using entry addresses recovered
from the Go pclntab (functions.txt produced by pclntab_dump).

Usage:
    xref_scan.py <objdump.txt> <functions.txt> <name-substr-or-regex> [...]

Output: per target, the number of call sites and their addresses + the raw line.
"""
import re
import sys
from collections import defaultdict

RX_LINE = re.compile(r'^\s*([0-9a-f]+):\t[0-9a-f ]+\t(call|jmp)[a-z]*\s+([0-9a-f]+)(?:\s|$|<)')


def main():
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    asm_path, fns_path = sys.argv[1], sys.argv[2]
    patterns = [re.compile(p) for p in sys.argv[3:]]

    # entry -> name, restricted to matching candidates
    candidates = {}
    with open(fns_path, errors='replace') as f:
        for line in f:
            parts = line.rstrip('\n').split('\t')
            if len(parts) != 2:
                continue
            try:
                entry = int(parts[0], 16)
            except ValueError:
                continue
            name = parts[1]
            if any(p.search(name) for p in patterns):
                candidates[entry] = name

    print(f"# candidate targets: {len(candidates)}")
    for e in sorted(candidates):
        print(f"#   0x{e:x}  {candidates[e]}")

    hits = defaultdict(list)
    n_inst = 0
    with open(asm_path, errors='replace') as f:
        for line in f:
            n_inst += 1
            m = RX_LINE.match(line)
            if not m:
                continue
            try:
                target = int(m.group(3), 16)
            except ValueError:
                continue
            if target in candidates:
                hits[target].append((m.group(1), line.strip()))

    print(f"\n# scanned {n_inst} lines")
    print(f"# targets with call sites: {len(hits)}")
    for target in sorted(hits, key=lambda t: -len(hits[t])):
        name = candidates[target]
        callers = hits[target]
        print(f"\n== {name} @0x{target:x} — {len(callers)} call site(s) ==")
        for addr, raw in callers[:25]:
            print(f"  0x{addr} | {raw}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

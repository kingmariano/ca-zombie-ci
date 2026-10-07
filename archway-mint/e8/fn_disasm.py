#!/usr/bin/env python3
"""Extract per-function disassembly from a GNU objdump dump of a STRIPPED Go binary,
using the pclntab function table (produced by pclntab_dump) as the symbol source.

Works because the pclntab gives exact entry addresses: a function's code is the
address range [entry, next_entry). No `go tool objdump` needed (it fails on
fully-stripped binaries).

Usage:
    fn_disasm.py <objdump.txt> <functions.txt> <name-pattern> [<name-pattern> ...]

Output (stdout):
    ########## <name> @0x<entry> ##########
    <addr>: <mnemonic + operands>
    ...
    ;; callees: 0xADDR=<name> 0xADDR=<name> ...
"""
import re
import sys
from bisect import bisect_right

MAX_FUNCS_PER_PATTERN = 20
MAX_LINES_PER_FUNC = 1500
RX_LINE = re.compile(r'^\s*([0-9a-f]+):\t[0-9a-f ].*?\t(.*)$')
RX_TARGET = re.compile(r'^(call|jmp)[a-z]*\s+(?:0x)?([0-9a-f]+)\b')


def main():
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    asm_path, fns_path = sys.argv[1], sys.argv[2]
    patterns = [re.compile(p) for p in sys.argv[3:]]

    funcs = []  # (entry, name) sorted by entry
    with open(fns_path, errors='replace') as f:
        for line in f:
            parts = line.rstrip('\n').split('\t')
            if len(parts) != 2:
                continue
            try:
                funcs.append((int(parts[0], 16), parts[1]))
            except ValueError:
                continue
    funcs.sort()
    entries = [e for e, _ in funcs]
    name_of = {e: n for e, n in funcs}

    targets = []  # (start, end, name)
    seen = set()
    for pat in patterns:
        count = 0
        for e, n in funcs:
            if count >= MAX_FUNCS_PER_PATTERN:
                break
            if pat.search(n) and (e, n) not in seen:
                seen.add((e, n))
                i = bisect_right(entries, e)
                end = entries[i] if i < len(entries) else e + 0x100000
                targets.append((e, end, n))
                count += 1
    targets.sort()

    print(f"# targets: {len(targets)}", file=sys.stderr)
    for e, _, n in targets:
        print(f"#   0x{e:x}  {n}", file=sys.stderr)

    # single pass over the dump, collecting instruction lines per target
    idx = 0
    n_targets = len(targets)
    collected = {e: [] for e, _, _ in targets}
    truncated = set()
    if n_targets:
        cur_start, cur_end, cur_name = targets[0]
        with open(asm_path, errors='replace') as f:
            for line in f:
                m = RX_LINE.match(line)
                if not m:
                    continue
                try:
                    a = int(m.group(1), 16)
                except ValueError:
                    continue
                while idx < n_targets and a >= targets[idx][1]:
                    idx += 1
                    if idx < n_targets:
                        cur_start, cur_end, cur_name = targets[idx]
                if idx >= n_targets:
                    break
                if cur_start <= a < cur_end:
                    if len(collected[cur_start]) < MAX_LINES_PER_FUNC:
                        collected[cur_start].append((a, m.group(2).strip()))
                    elif cur_start not in truncated:
                        truncated.add(cur_start)
                        collected[cur_start].append((-1, "; ... truncated ..."))

    for e, end, n in targets:
        print(f"\n########## {n} @0x{e:x} ##########")
        callees = []
        seen_callees = set()
        for a, inst in collected.get(e, []):
            print(f"  0x{a:x}: {inst}" if a >= 0 else inst)
            tm = RX_TARGET.match(inst)
            if tm:
                t = int(tm.group(2), 16)
                if t != e and t not in seen_callees:
                    seen_callees.add(t)
                    callees.append(t)
        if callees:
            res = []
            for t in callees[:80]:
                res.append(f"0x{t:x}=" + (name_of.get(t, "?")))
            print(";; callees: " + "  ".join(res))
    return 0


if __name__ == "__main__":
    sys.exit(main())

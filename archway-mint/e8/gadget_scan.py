#!/usr/bin/env python3
"""Categorised ROP/JOP gadget scanner for GNU objdump output (AT&T syntax).

Designed for the stripped archwayd release binary dump (`objdump -d /tmp/archwayd`),
which has no symbols: all results are raw addresses in archwayd's non-PIE text.

Categories
----------
  PIVOT   : rsp-writing sequences ending in `ret` (pop %rsp / leave / mov|lea|xchg -> %rsp /
            add|sub|and|or|xor $imm,%rsp)
  REGIND  : indirect call/jmp through a register or memory operand, with the nearby
            instruction that loads the target register (if any)
  PUSHret : push %reg shortly before ret  (stack-smash / value-staging helpers)
  WRITE   : memory-write primitives ending in ret (mov %reg,(...) / mov %reg,imm(...) /
            mov $imm,(...))

Usage: gadget_scan.py <objdump.txt>
Output: summary + per-category examples on stdout (grep-friendly, one gadget per line):
        0xADDR | instr ; instr ; ret
"""
import re
import sys
from collections import Counter

MAX_EXAMPLES = 80
WINDOW = 6

RX_LINE = re.compile(r'^\s*([0-9a-f]+):\t([0-9a-f ].*?)\t(.*)$')

# Strong pivots: attacker-controlled rsp source (register or stack pop).
PIVOT_STRONG_RXS = [
    re.compile(r'^pop\s+%rsp\b'),
    re.compile(r'^leave\b'),
    re.compile(r'^mov[a-z]*\s+%[a-z0-9]+,\s*%rsp\b'),
    re.compile(r'^xchg[a-z]*\s+%[a-z0-9]+,\s*%rsp\b'),
    re.compile(r'^lea[a-z]*\s+.+,\s*%rsp\b'),
]
# Arithmetic rsp adjustments (mostly epilogues; large ones may still be useful).
PIVOT_ARITH_RXS = [
    re.compile(r'^(add|sub|and|or|xor)[a-z]*\s+\$0x[0-9a-f]+,\s*%rsp\b'),
]
REGIND_RX = re.compile(r'^(call|jmp)[a-z]*\s+\*(\S+)$')
PUSH_RX = re.compile(r'^push[a-z]*\s+%([a-z0-9]+)$')
WRITE_RX = re.compile(r'^mov[a-z]*\s+(\$0x[0-9a-f]+|%[a-z0-9]+),\s*(\S.*)$')


def norm(inst: str) -> str:
    return re.sub(r'\s+', ' ', inst.strip())


def is_ret(i: str) -> bool:
    return i in ('ret', 'retq')


def pivot_class(i: str):
    """Return 'strong', 'arith' or None for an instruction."""
    if any(rx.match(i) for rx in PIVOT_STRONG_RXS):
        return 'strong'
    if any(rx.match(i) for rx in PIVOT_ARITH_RXS):
        return 'arith'
    return None


def is_mem_dst(dst: str) -> bool:
    # AT&T memory operand: contains '(' or is a bare address / *%reg
    return '(' in dst or dst.startswith('*') or re.match(r'^0x[0-9a-f]+$', dst) is not None


def regname(operand: str):
    m = re.search(r'%([a-z0-9]+)', operand)
    return m.group(1) if m else None


def main():
    if len(sys.argv) < 2:
        print("usage: gadget_scan.py <objdump.txt>", file=sys.stderr)
        return 2
    path = sys.argv[1]

    pivots_strong, pivots_arith, reginds, pushrets, writes = [], [], [], [], []
    sig_counts = Counter()
    n_lines = 0
    n_inst = 0

    window = []  # list of (addr, inst)
    with open(path, 'r', errors='replace') as f:
        for line in f:
            n_lines += 1
            m = RX_LINE.match(line)
            if not m:
                continue
            addr, raw, inst = m.group(1), m.group(2), norm(m.group(3))
            if not inst or inst.startswith('('):
                continue
            n_inst += 1

            # REGIND (checked on the instruction itself)
            rm = REGIND_RX.match(inst)
            if rm:
                target = rm.group(2)
                treg = regname(target)
                setter = ""
                if treg:
                    for (_, wi) in reversed(window[-4:]):
                        if re.match(rf'^(pop|mov[a-z]*|lea[a-z]*)\b.*%{re.escape(treg)}\b', wi) or \
                           re.match(rf'^pop\s+%{re.escape(treg)}$', wi):
                            setter = wi + " ; "
                            break
                reginds.append((addr, f"{setter}{inst}"))

            # PUSHret + WRITE + PIVOT sequences are detected at `ret`
            if is_ret(inst):
                seq = window[-WINDOW:] + [(addr, inst)]
                # PIVOT: nearest pivot instruction inside the window
                for j in range(len(seq) - 2, -1, -1):
                    cls = pivot_class(seq[j][1])
                    if cls:
                        text = ' ; '.join(x[1] for x in seq[j:])
                        if len(seq) - j <= 4:
                            dst = pivots_strong if cls == 'strong' else pivots_arith
                            dst.append((seq[j][0], text))
                            cat = 'PIVOT' if cls == 'strong' else 'PIVOTARITH'
                            sig_counts[(cat, re.sub(r'0x[0-9a-f]+', '0xN', text))] += 1
                        break
                # PUSHret: push %reg within 2 before ret
                for j in range(max(0, len(seq) - 3), len(seq) - 1):
                    pm = PUSH_RX.match(seq[j][1])
                    if pm:
                        pushrets.append((seq[j][0], ' ; '.join(x[1] for x in seq[j:])))
                        break
                # WRITE: memory write within 2 before ret
                for j in range(max(0, len(seq) - 3), len(seq) - 1):
                    wm = WRITE_RX.match(seq[j][1])
                    if wm and is_mem_dst(wm.group(2)):
                        writes.append((seq[j][0], ' ; '.join(x[1] for x in seq[j:])))
                        break

            window.append((addr, inst))
            if len(window) > WINDOW:
                window.pop(0)

    def emit(name, items, extra=None):
        print(f"\n== {name} ({len(items)} total) ==")
        seen = set()
        shown = 0
        for addr, text in items:
            key = re.sub(r'0x[0-9a-f]+', '0xN', text)
            if key in seen:
                continue
            seen.add(key)
            print(f"0x{addr} | {text}")
            shown += 1
            if shown >= MAX_EXAMPLES:
                break
        if extra is not None:
            print(f"-- top {name} signatures --")
            for sig, cnt in sig_counts.most_common(20):
                if sig[0] == name:
                    print(f"{cnt:6d}  {sig[1]}")

    print(f"parsed {n_inst} instructions from {n_lines} lines")
    emit("PIVOT-STRONG", pivots_strong)
    emit("PIVOT-ARITH", pivots_arith)
    emit("REGIND", reginds)
    emit("PUSHret", pushrets)
    emit("WRITE", writes)
    print("\n== SUMMARY ==")
    print(f"PIVOT-STRONG total={len(pivots_strong)}")
    print(f"PIVOT-ARITH total={len(pivots_arith)}")
    print(f"REGIND total={len(reginds)}")
    print(f"PUSHret total={len(pushrets)}")
    print(f"WRITE total={len(writes)}")
    print("\n-- top signatures --")
    for (cat, sig), cnt in sig_counts.most_common(30):
        print(f"{cnt:6d}  [{cat}] {sig}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

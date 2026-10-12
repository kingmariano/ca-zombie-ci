#!/usr/bin/env python3
"""Parse an EVM runtime bytecode dispatcher: extract selector->jumpdest entries.

Reads raw hex (with 0x) from argv[1], scans the first DISPATCH_REGION bytes only
(the dispatcher table comes right after the prologue), decoding PUSH payloads, and
extracts patterns:
   PUSH4 sel ; EQ ; PUSH2 dest ; JUMPI      (linear/binary-search compare)
   PUSH4 sel ; GT ; PUSH2 dest ; JUMPI      (binary-search pivot)
Also reports the fallback target and any other PUSH4 constants found in the region
with a small context window (to classify call-constants vs table entries).
"""
import sys

OPS_PUSH = {0x60 + i: i + 1 for i in range(32)}  # PUSH1..PUSH32 -> payload size

def decode(hexstr, limit=None):
    b = bytes.fromhex(hexstr[2:] if hexstr.startswith('0x') else hexstr)
    out = []  # (offset, opcode, payload_or_None, raw_len)
    i = 0
    while i < len(b):
        op = b[i]
        if op in OPS_PUSH:
            n = OPS_PUSH[op]
            payload = b[i+1:i+1+n]
            out.append((i, op, payload, 1+n))
            i += 1 + n
        else:
            out.append((i, op, None, 1))
            i += 1
        if limit and i >= limit:
            break
    return out, b

def main():
    path = sys.argv[1]
    raw = open(path).read().strip()
    ops, b = decode(raw)
    region = 0x100  # dispatcher region we care about
    entries = []
    others = []
    for idx, (off, op, payload, ln) in enumerate(ops):
        if off > region:
            break
        if op == 0x63 and payload is not None:  # PUSH4
            sel = payload.hex()
            nxt = ops[idx+1:idx+4]
            nxt2 = ops[idx+1:idx+5]
            # pattern: EQ/GT at +1, PUSH2 at +2, JUMPI at +3
            if (len(nxt2) == 4 and nxt2[0][1] in (0x14, 0x11) and nxt2[1][1] == 0x61
                    and nxt2[2][1] == 0x57):
                target = int.from_bytes(nxt2[1][2], 'big')
                kind = 'EQ' if nxt2[0][1] == 0x14 else 'GT'
                entries.append((sel, kind, hex(target), hex(off)))
            else:
                # capture nearby opcodes for classification
                ctx = []
                for o in ops[idx:idx+6]:
                    ctx.append(f"{o[1]:02x}" + (o[2].hex() if o[2] is not None else ""))
                others.append((sel, hex(off), ' '.join(ctx)))
    print(f"# file: {path}  runtime_bytes={len(b)}  (0x{len(b):x})")
    print("## dispatcher table entries (selector, cmp, jumpdest, offset):")
    for e in entries:
        print(f"0x{e[0]}  {e[1]:2s}  -> {e[2]}   (at off {e[3]})")
    print(f"# total table entries: {len(entries)}")
    print("## other PUSH4 constants in region (may include inline outgoing-call selectors):")
    for o in others:
        print(f"0x{o[0]}  at {o[1]}  ctx: {o[2]}")

if __name__ == '__main__':
    main()

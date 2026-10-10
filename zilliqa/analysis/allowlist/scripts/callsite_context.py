#!/usr/bin/env python3
"""For given code files, locate CALL-family opcodes and classify the call target's origin.

Heuristic: walk instructions; track last writes to stack via opcodes:
 - CALLDATALOAD/ CALLDATACOPY near the call => calldata-sourced data possible
 - SLOAD => storage-sourced
 - PUSH20/PUSH4 constant => constant target
Prints a window around each CALL/DELEGATECALL/STATICCALL/CALLCODE to raw/callsites_<addr>.txt
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
RAW = HERE / "raw"

OPS = {0xF1: "CALL", 0xF2: "CALLCODE", 0xF4: "DELEGATECALL", 0xFA: "STATICCALL",
       0xF0: "CREATE", 0xF5: "CREATE2", 0xFF: "SELFDESTRUCT"}


def decode(code: bytes):
    i = 0
    out = []
    while i < len(code):
        op = code[i]
        if 0x60 <= op <= 0x7F:
            ln = op - 0x5F
            out.append((i, op, ln, code[i + 1:i + 1 + ln]))
            i += 1 + ln
        else:
            out.append((i, op, 0, b""))
            i += 1
    return out


def main(addr):
    p1 = RAW / f"code_{addr}.hex"
    p2 = RAW / f"code_extra_{addr}.hex"
    code_hex = (p1 if p1.exists() else p2).read_text().strip()
    code = bytes.fromhex(code_hex[2:])
    ins = decode(code)
    lines = []
    for n, (off, op, ln, imm) in enumerate(ins):
        if op in OPS:
            lines.append(f"\n==== {OPS[op]} at 0x{off:x} ====")
            for m in range(max(0, n - 45), min(len(ins), n + 8)):
                o, o2, l2, im2 = ins[m]
                name = OPS.get(o2, "")
                extra = ""
                if o2 == 0x63 and l2 == 4:
                    extra = f" (sel 0x{im2.hex()})"
                elif o2 == 0x60 and l2 == 1:
                    extra = f" 0x{im2.hex()}"
                elif o2 == 0x61 and l2 == 2:
                    extra = f" 0x{im2.hex()}"
                elif o2 == 0x62 and l2 == 3:
                    extra = f" 0x{im2[0]:02x}{im2[1]:02x}{im2[2]:02x}"
                elif o2 == 0x73 and l2 == 20:
                    extra = f" 0x{im2.hex()}"
                elif o2 == 0x7f and l2 == 32:
                    extra = f" 0x{im2.hex()[:24]}..."
                lines.append(f"  {o:6d} {'>>' if m == n else '  '} {name or hex(o2)}{extra}")
    (RAW / f"callsites_{addr}.txt").write_text("\n".join(lines))
    print(addr, "wrote", len(lines), "lines")


if __name__ == "__main__":
    for a in sys.argv[1:]:
        main(a)

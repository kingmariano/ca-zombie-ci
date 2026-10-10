#!/usr/bin/env python3
"""Cairo 0 disassembler for read-only bytecode audit (v0.10.3 encoding).

Usage: python3 disasm.py <program.json> <start_pc> <end_pc>
Renders each instruction; call targets are annotated with identifier names when known.
"""
import json, sys

PRIME = 2**251 + 17 * 2**192 + 1
MASK16 = 0xFFFF

def dec_off(enc):
    return enc - 0x8000

def decode(data, pc):
    w = data[pc]
    off0 = dec_off(w & MASK16)
    off1 = dec_off((w >> 16) & MASK16)
    off2 = dec_off((w >> 32) & MASK16)
    f = w >> 48
    d = dict(
        off0=off0, off1=off1, off2=off2,
        dst_fp=(f >> 0) & 1, op0_fp=(f >> 1) & 1,
        op1_imm=(f >> 2) & 1, op1_fp=(f >> 3) & 1, op1_ap=(f >> 4) & 1,
        res_add=(f >> 5) & 1, res_mul=(f >> 6) & 1,
        pc_jump=(f >> 7) & 1, pc_jump_rel=(f >> 8) & 1, pc_jnz=(f >> 9) & 1,
        ap_add=(f >> 10) & 1, ap_add1=(f >> 11) & 1,
        op_call=(f >> 12) & 1, op_ret=(f >> 13) & 1, op_assert=(f >> 14) & 1,
    )
    d['imm'] = data[pc + 1] if d['op1_imm'] else None
    d['size'] = 2 if d['op1_imm'] else 1
    return d

def reg(base, off):
    if off == 0:
        return f'[{base}]'
    return f'[{base}{off:+d}]'

def fmt(d, pc, names):
    dst = reg('fp' if d['dst_fp'] else 'ap', d['off0'])
    op0 = reg('fp' if d['op0_fp'] else 'ap', d['off1'])
    if d['op1_imm']:
        imm = d['imm']
        simm = imm if imm < PRIME // 2 else imm - PRIME
        target = (pc + simm) % PRIME
        label = names.get(target, '')
        op1 = f'{simm}' + (f'  -> {label}' if label else (f'  -> 0x{target:x}' if abs(simm) > 0xffff else ''))
    elif d['op1_ap']:
        op1 = reg('ap', d['off2'])
    elif d['op1_fp']:
        op1 = reg('fp', d['off2'])
    else:
        op1 = reg('op0', d['off2'])
    if d['res_add']:
        res = f'{op0} + {op1}'
    elif d['res_mul']:
        res = f'{op0} * {op1}'
    else:
        res = op1
    # opcode
    if d['op_call']:
        base = f'call {op1}'
    elif d['op_ret']:
        base = 'ret'
    elif d['op_assert']:
        base = f'{dst} = {res}'
    else:
        base = f'nop (res: {res})' if not (d['pc_jnz'] or d['pc_jump'] or d['pc_jump_rel']) else 'nop'
    # pc update
    if d['pc_jnz']:
        base += f'  [jnz -> {op1} if {dst} != 0]'
    elif d['pc_jump']:
        base = f'jmp {res}'
    elif d['pc_jump_rel'] and not d['op_call']:
        base = f'jmp rel {op1}'
    # ap update
    if d['op_call']:
        base += '  (ap+=2)'
    elif d['ap_add']:
        base += f'  (ap += {res})'
    elif d['ap_add1']:
        base += '  (ap++)'
    return base

def main():
    path, start, end = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    prog = json.load(open(path))
    data = [int(x, 16) if isinstance(x, str) else int(x) for x in prog['data']]
    ids = prog.get('identifiers', {})
    names = {}
    for k, v in ids.items():
        if isinstance(v, dict) and v.get('type') == 'function':
            names.setdefault(v['pc'], k)
    # also label pc-1/2-3 (functions can be reached mid-prologue? no)
    pc = start
    while pc < end:
        d = decode(data, pc)
        name = names.get(pc, '')
        prefix = f'>>> {name}\n' if name else ''
        print(f'{prefix}{pc:5d} {fmt(d, pc, names)}')
        pc += d['size']

if __name__ == '__main__':
    main()

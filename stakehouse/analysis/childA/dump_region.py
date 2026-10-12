#!/usr/bin/env python3
import sys, re
from pyevmasm import disassemble_all
B = bytes.fromhex(open('refs/SweepReporting_impl.bytecode.txt').read().strip()[2:])
INS = list(disassemble_all(B))
PC2I = {x.pc:i for i,x in enumerate(INS)}
def dump(lo, hi, label=None):
    if label: print(f"## {label} [{hex(lo)},{hex(hi)})")
    for x in INS:
        if lo<=x.pc<hi:
            op = ''
            if x.operand is not None:
                op = hex(x.operand)
                if x.name=='PUSH32':
                    bb=x.operand.to_bytes(32,'big')
                    txt=''.join(chr(c) if 32<=c<127 else '.' for c in bb)
                    if re.search(r'[A-Za-z]{4,}', txt): op += f"  ; \"{txt}\""
            mark=''
            if x.name in ('CALL','DELEGATECALL','STATICCALL','CREATE','CREATE2'): mark='   <== EXT CALL'
            if x.name in ('SLOAD','SSTORE'): mark='   <== '+x.name
            if x.name=='REVERT': mark='   <== REVERT'
            print(f"{x.pc:6d} 0x{x.pc:04x}: {x.name} {op}{mark}")
if __name__=='__main__':
    lo=int(sys.argv[1],16); hi=int(sys.argv[2],16)
    dump(lo,hi, label=sys.argv[3] if len(sys.argv)>3 else None)

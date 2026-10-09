#!/usr/bin/env python3
"""Extract function selectors from the unverified oracle runtime bytecode."""
import json, re
from Crypto.Hash import keccak

d=json.load(open('/home/heisenberg/CA/aurigami/analysis/src/oracle.json'))
code=d.get('deployed_bytecode','').replace('0x','')
print("runtime len:", len(code)//2)
b=bytes.fromhex(code)

sels=set()
# PUSH4 pattern: 0x63 followed by 4 bytes; also PUSH4 appears as operand after 0x7f? scan all 63 occurrences
for i in range(len(b)-4):
    if b[i]==0x63:
        sel=b[i+1:i+5]
        # heuristic: must be found in dispatcher (followed later by 0x14 EQ or appear in binary search)
        sels.add(sel.hex())
print("PUSH4 candidates:", len(sels))
for s in sorted(sels):
    print("0x"+s)

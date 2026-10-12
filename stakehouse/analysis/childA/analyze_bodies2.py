#!/usr/bin/env python3
"""Call/return-aware reachability + string attribution for the deployed impl."""
import json, re
from pyevmasm import disassemble_all

CODE = open('refs/SweepReporting_impl.bytecode.txt').read().strip()
if CODE.startswith('0x'): CODE=CODE[2:]
B = bytes.fromhex(CODE)
INS = list(disassemble_all(B))
BY_PC = {x.pc: x for x in INS}
IDX = {x.pc: i for i,x in enumerate(INS)}
N = len(INS)

def next_pc(pc):
    x=BY_PC.get(pc)
    return None if x is None else pc+x.size

def last_push_before(i):
    """walk back from index i (exclusive) within the basic block, return (idx,ins) of last PUSH"""
    j=i-1
    while j>=0:
        p=INS[j]
        if p.name=='JUMPDEST': break
        if p.name in ('PUSH1','PUSH2','PUSH4','PUSH8','PUSH32'): return j,p
        if p.name in ('JUMP','JUMPI','REVERT','RETURN','STOP','INVALID'): break
        j-=1
    return None,None

def call_target_and_return(i):
    """at ins index i = JUMP|JUMPI: return (target, return_addr_candidate)"""
    j,p = last_push_before(i)
    if p is None: return None,None
    target = p.operand
    ret=None
    k=j-1
    while k>=0:
        q=INS[k]
        if q.name=='JUMPDEST': break
        if q.name=='PUSH2':
            ret=q.operand
            # sanity: the call convention is PUSH2 ret; ...; PUSH2 target; JUMP
            if ret != target: break
        if q.name in ('JUMP','JUMPI','REVERT','RETURN','STOP'): break
        k-=1
    return target,ret

def traverse(entry, limit=100000):
    seen=set(); stack=[entry]; edges=0
    while stack and len(seen)<limit:
        pc=stack.pop()
        while pc is not None and pc not in seen and len(seen)<limit:
            x=BY_PC.get(pc)
            if x is None: break
            seen.add(pc)
            nm=x.name
            if nm=='JUMP' or nm=='JUMPI':
                t,r = call_target_and_return(IDX[pc])
                if nm=='JUMPI':
                    pc=next_pc(pc)
                    if t is not None and t in BY_PC: stack.append(t)
                    continue
                # JUMP
                if t is not None and t in BY_PC:
                    if r is not None and r in BY_PC: stack.append(r)
                    pc=t; edges+=1; continue
                break
            if nm in ('STOP','RETURN','REVERT','INVALID','SELFDESTRUCT'): break
            pc=next_pc(pc)
    return seen

# inline PUSH32 strings
def inline_strings(cov):
    out=[]
    for pc in sorted(cov):
        x=BY_PC[pc]
        if x.name=='PUSH32' and x.operand is not None:
            b = x.operand.to_bytes(32,'big')
            txt = ''.join(chr(c) if 32<=c<127 else '.' for c in b)
            if re.search(r'[A-Za-z]{4,}', txt):
                out.append((pc, txt))
    return out

def call_sites(cov):
    return [(pc, BY_PC[pc].name) for pc in sorted(cov) if BY_PC[pc].name in ('CALL','DELEGATECALL','STATICCALL','CREATE','CREATE2')]

def const_word_refs(cov):
    out=[]
    for pc in sorted(cov):
        x=BY_PC[pc]
        if x.name=='PUSH32' and x.operand is not None and x.operand > 2**200:
            i=IDX[pc]
            for j in range(i+1, min(i+16,N)):
                nm=INS[j].name
                if nm in ('SLOAD','SSTORE'):
                    out.append((pc, '0x%064x'%x.operand, nm)); break
                if nm in ('JUMP','REVERT','RETURN'): break
    return out

disp=json.load(open('childA/dispatch_table.json'))['dispatch']
res={}
for s in disp:
    sel=s['selector']; entry=s['body_pc']
    cov=traverse(entry)
    r={'entry':entry,'n':len(cov),
       'strings':inline_strings(cov),
       'calls':call_sites(cov),
       'const_refs':const_word_refs(cov)}
    res[sel]=r
    ss=['%s@0x%x'%(t.strip('.')[:28],p) for p,t in r['strings'] if len(t.strip('.'))>3]
    print(f"0x{sel} entry=0x{entry:04x} ins={len(cov)} calls={len(r['calls'])} {r['calls']}")
    for p,t in r['strings']:
        if re.search(r'[A-Za-z]{3,}',t): print('    str @0x%x: %r'%(p,t))
    for c in r['const_refs'][:8]: print('    const',c)
json.dump(res, open('childA/function_regions2.json','w'), indent=1, default=str)

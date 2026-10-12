#!/usr/bin/env python3
"""Static reachability analysis of the deployed ShanghaiSweepReporting impl.
Builds literal-jump reachability from each dispatch stub, then attributes
revert strings, SLOAD/SSTORE slots, and CALL-family sites to functions."""
import json, re, sys
from collections import defaultdict
from pyevmasm import disassemble_all

CODE = open('refs/SweepReporting_impl.bytecode.txt').read().strip()
if CODE.startswith('0x'): CODE=CODE[2:]
B = bytes.fromhex(CODE)
INS = list(disassemble_all(B))
BY_PC = {x.pc: x for x in INS}
PC_IDX = {x.pc: i for i,x in enumerate(INS)}
JUMPDESTS = {x.pc for x in INS if x.name=='JUMPDEST'}

def next_pc(pc):
    x = BY_PC.get(pc)
    if x is None: return None
    return pc + x.size

def literal_target(pc):
    """if instruction at pc is JUMP/JUMPI and previous ins is PUSH1/2/4, return pushed value"""
    x = BY_PC.get(pc)
    if x is None or x.name not in ('JUMP','JUMPI'): return None
    # walk back up to 8 instructions for the top-of-stack literal
    i = PC_IDX[pc]
    for j in range(i-1, max(-1, i-9), -1):
        p = INS[j]
        if p.name in ('PUSH1','PUSH2','PUSH4','PUSH8'):
            return p.operand
        if p.name in ('JUMP','JUMPI','JUMPDEST','DUP1','DUP2','SWAP1'): break
    return None

def traverse(entry, limit=200000):
    stack=[entry]; seen=set(); order=[]
    while stack:
        pc=stack.pop()
        while pc is not None and pc not in seen and len(seen)<limit:
            x=BY_PC.get(pc)
            if x is None: break
            seen.add(pc); order.append(pc)
            nm=x.name
            if nm=='JUMP':
                t=literal_target(pc)
                if t is not None: pc=t; continue
                break
            if nm=='JUMPI':
                t=literal_target(pc)
                if t is not None: stack.append(t)
                pc=next_pc(pc); continue
            if nm in ('STOP','RETURN','REVERT','INVALID','SELFDESTRUCT'): break
            pc=next_pc(pc)
    return seen, order

# strings map
strs=[]
for m in re.finditer(rb'[\x20-\x7e]{4,}\n?', B):
    s=m.group().decode(errors='replace')
    if re.search(r'[A-Za-z]', s) and not re.fullmatch(r'[0-9a-fA-Fx]+', s):
        strs.append((m.start(), s))

disp = json.load(open('childA/dispatch_table.json'))['dispatch']
targets = {s['selector']: s['body_pc'] for s in disp}
NAME = {
 '697feeee':'reportSweeps(new)', '4fd329a0':'reportAndWithdrawETH(new)',
 'f12ef017':'reportMulti(new)','c56992d7':'postRageQuit(new)','b36a4591':'batchPostRageQuit(new)',
 '690b4c40':'unwrapDETH','2b98c640':'batchUnwrapDETH','b8f0a9ab':'isSweepReported',
 '678e15d9':'totalETHSent','f78844a6':'totalSweepsUnknownTopUps','61cd11e1':'totalReportedNotWithdrawn',
 'a4850c03':'totalUnknownTopUps','17ffd8af':'getListUnreported','8e33771f':'validatorIndexToBLSKey',
 '83147048':'previewMintable','7b172270':'getSumUnreported','e6618789':'sweepsHash','86421457':'hasBLSReported',
 '17ab1b56':'hashBLS','7ec2e278':'manageVerifier','22bbe554':'isVerifier','86863ec6':'init',
 '3659cfe6':'upgradeTo','4f1ef286':'upgradeToAndCall','554c1b1f':'universe','4b705bd0':'validatorSetSize',
 'a68645a3':'cachedAM','a9956aef':'getAMCore','80ca2193':'getSavETHCore',
 '04c32fd2':'?04c32fd2','0626f5ac':'?0626f5ac','4a1a8df6':'?4a1a8df6','556b7541':'?556b7541',
 '5d007a99':'?5d007a99','6184bf91':'?6184bf91','67fbfe86':'?67fbfe86','b6797489':'?b6797489'}

def fmt_strs_for(cov):
    out=[]
    for off,s in strs:
        # string data region roughly [off, off+len+1)
        # find PUSH2/PUSH1 in covered pcs whose operand == off
        for pc in cov:
            x=BY_PC[pc]
            if x.name.startswith('PUSH') and x.operand==off:
                out.append((off,s,pc))
    return out

def call_sites(cov):
    return [(pc, BY_PC[pc].name) for pc in sorted(cov) if BY_PC[pc].name in ('CALL','DELEGATECALL','STATICCALL','CREATE','CREATE2')]

def slots(cov):
    reads=set(); writes=set()
    for pc in sorted(cov):
        x=BY_PC[pc]
        if x.name=='SLOAD':
            reads.add(pc)
        if x.name=='SSTORE':
            writes.add(pc)
    return reads,writes

# const slot detection: find PUSH32 then SLOAD/SSTORE within a window, or via symbolic-ish scan
def const_refs(cov):
    """(pc, const, op) where PUSH32 (or PUSH20 for mappings) feeds SLOAD/SSTORE soon after"""
    res=[]
    arr=sorted(cov)
    for pc in arr:
        x=BY_PC[pc]
        if x.name in ('PUSH32','PUSH20','PUSH7','PUSH1','PUSH2','PUSH4','PUSH5','PUSH8') :
            # scan next 12 instructions for SLOAD/SSTORE/keccak
            i=PC_IDX[pc]
            for j in range(i+1, min(i+14, len(INS))):
                nm=INS[j].name
                if nm in ('SLOAD','SSTORE'):
                    res.append((pc, hex(x.operand) if x.operand is not None else None, nm, INS[j].pc)); break
                if nm in ('JUMP','JUMPI','RETURN','REVERT'):
                    break
    return res

results={}
for sel,entry in sorted(targets.items(), key=lambda t:t[1]):
    cov,order=traverse(entry)
    r={}
    r['entry']=entry; r['n_ins']=len(cov)
    r['strings']=fmt_strs_for(cov)
    r['calls']=call_sites(cov)
    rd,wr=slots(cov)
    r['slots']={'reads':len(rd),'writes':len(wr)}
    r['const_refs']=const_refs(cov)
    results[sel]=r
    print(f"== 0x{sel} {NAME.get(sel,'?')} entry=0x{entry:04x} reachable_ins={len(cov)} strings={[(hex(o),s,hex(p)) for o,s,p in r['strings']][:6]} calls={r['calls']}")
json.dump(results, open('childA/function_regions.json','w'), indent=1, default=str)

#!/usr/bin/env python3
"""Rebuild dispatch table + selector mapping + region dumps from on-chain runtime code."""
import json, re
from eth_utils import keccak
from pyevmasm import disassemble_all
CODE=open('evidence/impl_runtime.hex').read().strip()
B=bytes.fromhex(CODE[2:] if CODE.startswith('0x') else CODE)
INS=list(disassemble_all(B))
PC2I={x.pc:i for i,x in enumerate(INS)}
disp=[]
for i,x in enumerate(INS):
    if x.name=='PUSH4' and i+3<len(INS):
        a,b,c,d=INS[i],INS[i+1],INS[i+2],INS[i+3]
        if a.name=='PUSH4' and b.name=='EQ' and c.name=='PUSH2' and d.name=='JUMPI':
            disp.append({'selector':'0x%08x'%a.operand,'body_pc':c.operand,'selector_push_pc':a.pc})
json.dump(disp, open('evidence/dispatch_table.json','w'), indent=1)
# stub -> body (pattern JUMP; JUMPDEST; PUSH2 x; JUMP)
def after(x): return x.pc+x.size
def find_body(entry):
    i=PC2I[entry]
    for k in range(i,i+40):
        a,b,c,d=INS[k],INS[k+1],INS[k+2],INS[k+3]
        if a.name=='JUMP' and after(a)==b.pc and b.name=='JUMPDEST' and after(b)==c.pc and c.name=='PUSH2' and after(c)==d.pc and d.name=='JUMP':
            return c.operand
    return None
out=[]
for s in disp:
    out.append({'selector':s['selector'],'stub':s['body_pc'],'body':find_body(s['body_pc'])})
json.dump(out, open('evidence/selector_to_body.json','w'), indent=1)
# selector name map (canonical from IShanghaiSweepReporting + data structs + deployed mapping)
REPORT="(address,bytes,uint256,uint256,(uint256,uint256,address,uint256)[])"
SIG="(uint248,uint8,bytes32,bytes32)"
STATE="(bytes,bytes,bool,uint64,uint64,uint64,uint64,uint64,uint64)"
names={
 '0x556b7541':'reportSweeps-equivalent (deployed)','0x67fbfe86':'reportAndWithdrawETH-equivalent (deployed)',
 '0x04c32fd2':'reportSweepsForMultipleBLSPublicKeys-equivalent (deployed)','0x6184bf91':'reportSweepsPostRageQuit-equivalent (deployed)',
 '0x5d007a99':'batchReportSweepsPostRageQuit-equivalent (deployed)','0x690b4c40':'unwrapDETH',
 '0x2b98c640':'batchUnwrapDETH','0x4a1a8df6':'updateTotalETHSentToBlsPublicKeyFromFinalReport(bytes,uint256,uint256)',
 '0x86863ec6':'init','0x7ec2e278':'manageDesignatedVerifier','0x0626f5ac':'isValidShanghaiReport-equivalent (deployed, view)',
 '0x17ab1b56':'getHashOfBlsPublicKey','0x17ffd8af':'getListOfUnreportedWithdrawalIndexes','0x22bbe554':'isDesignatedVerifier',
 '0x3659cfe6':'upgradeTo','0x4b705bd0':'validatorSetSizeBeforeShanghai','0x4f1ef286':'upgradeToAndCall','0x554c1b1f':'universe',
 '0x61cd11e1':'totalReportedETHNotWithdrawn','0x678e15d9':'totalETHSentToBlsPublicKey','0x7b172270':'getSumOfUnreportedSweeps',
 '0x80ca2193':'getSavETHRegistryCoreModule','0x83147048':'previewTotalMintableDETH','0x86421457':'hasBLSPublicKeyBeenReportedInShanghai',
 '0x8e33771f':'validatorIndexToBLSKey','0xa4850c03':'totalReportedUnknownTopUpsForBlsPublicKey','0xa68645a3':'cachedAccountManagerAddress',
 '0xa9956aef':'getAccountManagerCoreModule','0xb8f0a9ab':'isSweepReported','0xe6618789':'getSweepsHashFromSweepsArray',
 '0xf78844a6':'totalSweepsReportedAgainstUnknownTopUpsForBlsPublicKey','0x0e9a':'upgrade base','0x2c87':'internal helper zone',
}
json.dump({o['selector']:{'name':names.get(o['selector'],'?'),'stub':o['stub'],'body':o['body']} for o in out}, open('evidence/selector_map.json','w'), indent=1)
def dump(lo,hi,path,label):
    with open(path,'w') as f:
        f.write(f"## {label} [{hex(lo)},{hex(hi)})\n")
        for x in INS:
            if lo<=x.pc<hi:
                op=''
                if x.operand is not None:
                    op=hex(x.operand)
                    if x.name=='PUSH32':
                        bb=x.operand.to_bytes(32,'big')
                        txt=''.join(chr(c) if 32<=c<127 else '.' for c in bb)
                        if re.search(r'[A-Za-z]{4,}',txt): op+=f'  ; "{txt}"'
                tag=''
                if x.name in ('CALL','DELEGATECALL','STATICCALL','CREATE','CREATE2'): tag='   <== EXT CALL'
                if x.name in ('SLOAD','SSTORE'): tag='   <== '+x.name
                if x.name=='REVERT': tag='   <== REVERT'
                f.write(f"{x.pc:6d} 0x{x.pc:04x}: {x.name} {op}{tag}\n")
dumps=[
 (0x1006,0x1200,'evidence/region_reportSweeps_p1.txt','reportSweeps 0x556b7541 body part1'),
 (0x1200,0x1400,'evidence/region_reportSweeps_p2.txt','reportSweeps part2'),
 (0x1400,0x175b,'evidence/region_reportSweeps_p3.txt','reportSweeps part3'),
 (0x175b,0x18c5,'evidence/region_batchPostRQ.txt','batchReportSweepsPostRageQuit 0x5d007a99 body'),
 (0x18c5,0x1c42,'evidence/region_reportPostRQ.txt','reportSweepsPostRageQuit 0x6184bf91 body'),
 (0x1c42,0x23c2,'evidence/region_reportAndWithdrawETH.txt','reportAndWithdrawETH 0x67fbfe86 body'),
 (0x0695,0x080f,'evidence/region_multiReport.txt','reportSweepsForMultiple 0x04c32fd2 body'),
 (0x080f,0x0947,'evidence/region_validator.txt','isValidShanghaiReport-equivalent 0x0626f5ac body'),
 (0x0d25,0x0e9a,'evidence/region_updateTotal.txt','updateTotalETHSent… 0x4a1a8df6 body'),
 (0x0aa5,0x0baa,'evidence/region_batchUnwrapDETH.txt','batchUnwrapDETH 0x2b98c640 body'),
 (0x23c2,0x253e,'evidence/region_unwrapDETH.txt','unwrapDETH 0x690b4c40 body'),
 (0x269f,0x28b7,'evidence/region_manageVerifier.txt','manageDesignatedVerifier 0x7ec2e278 body'),
 (0x293b,0x2b6c,'evidence/region_init.txt','init 0x86863ec6 body'),
 (0x3300,0x3600,'evidence/region_sharedA.txt','shared report logic A (0x332d onlyCore, 0x3475 sweeps loop)'),
 (0x3600,0x3900,'evidence/region_sharedB.txt','shared report logic B (isSweepReported check/mark, 0x3809/0x38b8)'),
 (0x3900,0x3c20,'evidence/region_sharedC.txt','shared report logic C'),
 (0x2ef0,0x2f60,'evidence/region_ecdsa.txt','ECDSA helpers 0x2f05 / 0x2f1e'),
]
for lo,hi,path,label in dumps: dump(lo,hi,path,label)
# full disassembly
with open('evidence/disasm_full.txt','w') as f:
    for x in INS:
        f.write(f"0x{x.pc:04x}: {x.name} {hex(x.operand) if x.operand is not None else ''}\n")
print('dispatch entries:', len(disp), '| dumps:', len(dumps))

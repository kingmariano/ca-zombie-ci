#!/usr/bin/env python3
"""Inspect verified contract JSON from Blockscout: list ABI funcs, extract function bodies."""
import json,sys,os,re

def load(addr):
    d=json.load(open('raw/src/%s.json'%addr.lower()))
    return d

def funcs(addr):
    d=load(addr)
    abi=d.get('abi') or []
    out=[]
    for e in abi:
        if e.get('type')=='function':
            ins=','.join((i.get('type','')+(('['+str(i.get('components'))+']') if False else '')+((' '+i.get('name','')) if i.get('name') else '')) for i in e.get('inputs',[]))
            outs=','.join(i.get('type','') for i in e.get('outputs',[]))
            out.append("%s(%s) %s [%s] %s"%(e.get('name'),ins,outs,e.get('stateMutability'),'payable' if e.get('payable') else ''))
        elif e.get('type') in ('constructor','fallback','receive'):
            out.append('<%s> %s'%(e.get('type'),e.get('stateMutability')))
    return out

def source(addr):
    d=load(addr)
    sc=d.get('source_code') or ''
    name=d.get('name') or ''
    # Blockscout may return multiple files concatenated with '// File: ' markers; find main
    return sc

def extract(addr, names=None, allf=False):
    sc=source(addr)
    # match 'function NAME' with optional visibility
    pattern=re.compile(r'\n\s*function\s+([A-Za-z0-9_]+)\s*\(')
    if names:
        pats=[re.compile(r'\n\s*function\s+%s\s*\('%n) for n in names]
    out=[]
    for m in pattern.finditer(sc):
        nm=m.group(1)
        if names and not allf and nm not in names: continue
        # find opening brace
        i=sc.find('{',m.end())
        # handle ';' (interface) 
        semi=sc.find(';',m.end())
        if semi!=-1 and (i==-1 or semi<i): 
            out.append(sc[m.start():semi+1].strip()); continue
        depth=0; j=i
        while j<len(sc):
            if sc[j]=='{': depth+=1
            elif sc[j]=='}':
                depth-=1
                if depth==0: break
            j+=1
        out.append(sc[m.start():j+1].strip())
    return '\n\n'.join(out)

if __name__=='__main__':
    cmd=sys.argv[1]
    if cmd=='funcs':
        for a in sys.argv[2:]:
            d=load(a)
            print('==',a,d.get('name'),'verified',d.get('is_verified'))
            for f in funcs(a): print('   ',f)
    elif cmd=='fn':
        a=sys.argv[2]; names=sys.argv[3:]
        print(extract(a,names))
    elif cmd=='allsrc':
        a=sys.argv[2]
        print(source(a))
    elif cmd=='grep':
        a=sys.argv[2]; pat=sys.argv[3]
        sc=source(a)
        for i,l in enumerate(sc.split('\n')):
            if re.search(pat,l): print(i,l)

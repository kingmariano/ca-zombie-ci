import sys,json,re
sys.path.insert(0,'raw'); from srctool import load,source,extract,funcs
ADDR=sys.argv[1]
PAT=sys.argv[2] if len(sys.argv)>2 else r'(withdraw|refund|claim|final|payout|redeem|burn|collect|sweep|rescue|drain|halt|cancel|abort|kill|migrate|emergency|initialize|init|owner|fallback|payable|send|transfer)'
d=load(ADDR)
print('=== %s %s verified=%s'%(ADDR,d.get('name'),d.get('is_verified')))
sc=source(ADDR)
for m in re.finditer(r'\n\s*function\s+([A-Za-z0-9_]+)\s*\(',sc):
    nm=m.group(1)
    if not re.search(PAT,nm,re.I): continue
    i=sc.find('{',m.end()); semi=sc.find(';',m.end())
    if semi!=-1 and (i==-1 or semi<i):
        print(sc[m.start():semi+1].strip()[:200]); continue
    depth=0;j=i
    while j<len(sc):
        if sc[j]=='{':depth+=1
        elif sc[j]=='}':
            depth-=1
            if depth==0:break
        j+=1
    body=sc[m.start():j+1]
    # trim
    lines=body.split('\n')
    if len(lines)>30: body='\n'.join(lines[:30])+'\n   ...(%d lines)'%len(lines)
    print(body)
    print('---')

import json,urllib.request,time,math
RPC="https://rpc.blast.io"
MGV="0xb1a49c54192ea59b233200ea38ab56650dfb448c"
READER="0x26fD9643Baf1f8A44b752B28f0D90AEBd04AB3F8"
def call(to,data):
    for t in range(4):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            return json.load(urllib.request.urlopen(req,timeout=40)).get('result')
        except Exception: time.sleep(0.4*(t+1))
    return None
def word(h,i): return h[2+64*i:2+64*(i+1)]
def s256(x): return x-2**256 if x>=2**255 else x
markets=json.load(open("mgv_markets.json"))
# 1) local(OLKey) for each market: selector cast sig "local((address,address,uint256))"
import subprocess
sel_local=subprocess.check_output(["cast","sig","local((address,address,uint256))"]).decode().strip()
sel_offers=subprocess.check_output(["cast","sig","offers((address,address,uint256),uint256)"]).decode().strip()
sel_offlist=subprocess.check_output(["cast","sig","offerList((address,address,uint256),uint256,uint256)"]).decode().strip()
print("sels",sel_local,sel_offers,sel_offlist)
def enc_mkt(m): return m[0][2:].zfill(64)+m[1][2:].zfill(64)+hex(m[2])[2:].zfill(64)
for mi,m in enumerate(markets):
    r=call(MGV,sel_local+enc_mkt(m))
    if not r or r=="0x": print("market",mi,"local FAIL"); continue
    V=int(word(r,0),16)
    active=(V>>255)&1; fee=(V>>247)&0xff; density=(V>>238)&0x1ff; lock=(V>>98)&1
    print(f"market {mi} active={active} fee={fee} density={density} lock={lock}")
# 2) full offer dump with int ticks
alloff={}
for mi,m in enumerate(markets):
    for direction,(base,quote) in enumerate([(m[0],m[1]),(m[1],m[0])]):
        cur=0; got=[]
        for _ in range(60):
            data=sel_offlist+base[2:].zfill(64)+quote[2:].zfill(64)+hex(m[2])[2:].zfill(64)+hex(cur)[2:].zfill(64)+hex(100)[2:].zfill(64)
            r=call(READER,data)
            if not r: break
            cid=int(word(r,0),16)
            ioff=int(word(r,1),16)//32
            ooff=int(word(r,2),16)//32
            noff=int(word(r,ooff),16)
            b=ooff+1
            for i in range(noff):
                prev=int(word(r,b+i*4),16); nxt=int(word(r,b+i*4+1),16)
                tick=s256(int(word(r,b+i*4+2),16)); gives=int(word(r,b+i*4+3),16)
                got.append({"prev":prev,"next":nxt,"tick":tick,"gives":gives})
            if cid==0: break
            cur=cid
        key=f"{mi}:{direction}"
        alloff[key]={"base":base,"quote":quote,"tickSpacing":m[2],"offers":got}
        if got: print(key,base[:10],'->',quote[:10],'n',len(got),'ticks',sorted(set(o['tick'] for o in got)))
json.dump(alloff,open("mgv_offers2.json","w"),indent=1)

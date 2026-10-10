import json,urllib.request,time,subprocess
RPC="https://rpc.blast.io"
READER="0x26fD9643Baf1f8A44b752B28f0D90AEBd04AB3F8"
def call(to,data):
    for t in range(4):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            return json.load(urllib.request.urlopen(req,timeout=40)).get('result')
        except Exception: time.sleep(0.4*(t+1))
    return None
def word(h,i): return h[2+64*i:2+64*(i+1)]
sel_offlist=subprocess.check_output(["cast","sig","offerList((address,address,uint256),uint256,uint256)"]).decode().strip()
markets=json.load(open("mgv_markets.json"))
mk=set(); out={}
for mi,m in enumerate(markets):
    for direction,(base,quote) in enumerate([(m[0],m[1]),(m[1],m[0])]):
        cur=0; recs=[]
        for _ in range(60):
            data=sel_offlist+base[2:].zfill(64)+quote[2:].zfill(64)+hex(m[2])[2:].zfill(64)+hex(cur)[2:].zfill(64)+hex(100)[2:].zfill(64)
            r=call(READER,data)
            if not r: break
            cid=int(word(r,0),16)
            ioff=int(word(r,1),16)//32
            ooff=int(word(r,2),16)//32
            doff=int(word(r,3),16)//32
            noff=int(word(r,ooff),16)
            ids=[int(word(r,ioff+1+i),16) for i in range(int(word(r,ioff),16))]
            b=ooff+1
            for i in range(noff):
                maker="0x"+word(r,doff+1+i*4)[24:]
                recs.append({"id":ids[i],"tick":int(word(r,b+i*4+2),16),"gives":int(word(r,b+i*4+3),16),
                             "maker":maker,"gasreq":int(word(r,doff+1+i*4+1),16),
                             "kgb":int(word(r,doff+1+i*4+2),16),"gasprice":int(word(r,doff+1+i*4+3),16)})
                mk.add(maker)
            if cid==0: break
            cur=cid
        out[f"{mi}:{direction}"]=recs
json.dump(out,open("mgv_details.json","w"),indent=1)
print("unique makers:",len(mk))
for a in sorted(mk):
    code=call(a,"0x")
    print(a,"code_len",len(code)//2 if code and code!="0x" else 0)

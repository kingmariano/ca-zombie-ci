import json,urllib.request,time
RPC="https://rpc.blast.io"
READER="0x26fD9643Baf1f8A44b752B28f0D90AEBd04AB3F8"
def call(to,data):
    for t in range(3):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            r=json.load(urllib.request.urlopen(req,timeout=40))
            return r.get('result')
        except Exception:
            time.sleep(0.5*(t+1))
    return None
def word(h,i): return h[2+64*i:2+64*(i+1)]
def dec_str(h):
    if not h or h=="0x": return None
    b=bytes.fromhex(h[2:])
    if len(b)<64: return None
    off=int.from_bytes(b[:32],'big')//32
    ln=int.from_bytes(b[off*32:off*32+32],'big')
    return b[off*32+32:off*32+32+ln].decode('utf-8',errors='replace')
tokens=["0x4300000000000000000000000000000000000003","0x4300000000000000000000000000000000000004","0x9a50953716ba58e3d6719ea5c437452ac578705f","0x999f220296b5843b2909cc5f8b4204aaca5341d8","0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34","0xb1a5700fa2358173fe465e6ea4ff52e36e88e2ad"]
for t in tokens:
    sym=dec_str(call(t,"0x95d89b41")); dec=call(t,"0x313ce567")
    print(t,"sym",sym,"dec",int(dec,16) if dec and dec!="0x" else None)
markets=json.load(open("mgv_markets.json"))
def offer_list(mkt, frm, mx):
    data="0x79bfb7e1"+mkt[0][2:].zfill(64)+mkt[1][2:].zfill(64)+hex(mkt[2])[2:].zfill(64)+hex(frm)[2:].zfill(64)+hex(mx)[2:].zfill(64)
    return call(READER,data)
def decode_offers(r):
    if not r or r=="0x": return None,None
    cur=int(word(r,0),16)
    ids_off=int(word(r,1),16)//32
    off_off=int(word(r,2),16)//32
    nids=int(word(r,ids_off),16)
    ids=[int(word(r,ids_off+1+i),16) for i in range(nids)]
    noff=int(word(r,off_off),16)
    offs=[]
    b=off_off+1
    for i in range(noff):
        prev=int(word(r,b+i*4),16); nxt=int(word(r,b+i*4+1),16)
        w2=int(word(r,b+i*4+2),16); w3=int(word(r,b+i*4+3),16)
        offs.append({"prev":prev,"next":nxt,"w2":w2,"w3":w3})
    return cur,offs
all_offers={}
for mi,mkt in enumerate(markets):
    for direction,(base,quote) in enumerate([(mkt[0],mkt[1]),(mkt[1],mkt[0])]):
        cur=0; collected=[]; loops=0
        while True:
            r=offer_list((base,quote,mkt[2]),cur,100)
            c,offs=decode_offers(r)
            if offs is None: break
            collected+=offs
            loops+=1
            if c==0 or loops>50: break
            cur=c
        key=f"{mi}:{direction}:{base}->{quote}"
        all_offers[key]={"base":base,"quote":quote,"tick":mkt[2],"n":len(collected),"offers":collected[:200]}
        print(key,"n_offers",len(collected))
json.dump(all_offers,open("mgv_offers.json","w"),indent=1)

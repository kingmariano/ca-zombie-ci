import json,urllib.request,time
RPC="https://rpc.blast.io"
READER="0x26fD9643Baf1f8A44b752B28f0D90AEBd04AB3F8"
def call(to,data):
    for t in range(3):
        try:
            req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            r=json.load(urllib.request.urlopen(req,timeout=40))
            if 'result' in r: return r['result']
            return None
        except Exception as e:
            time.sleep(0.5*(t+1))
    return None
def word(h,i): return h[2+64*i:2+64*(i+1)]
r=call(READER,"0x8267f649")
print("openMarkets raw len:", len(r) if r else None)
# returns (address,address,uint256)[] -> ABI dynamic array: offset, len, then tuples
off=int(word(r,0),16)//32
n=int(word(r,off),16)
print("n markets",n)
markets=[]
base=off+1
for i in range(n):
    # tuple is 3 words inline (static struct in dynamic array)
    a="0x"+word(r,base+i*3)[24:]
    b="0x"+word(r,base+i*3+1)[24:]
    ts=int(word(r,base+i*3+2),16)
    markets.append((a,b,ts))
    print("market",i,a,b,ts)
json.dump(markets,open("/tmp/opencode/mgv_markets.json","w"))

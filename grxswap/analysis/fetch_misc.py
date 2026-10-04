import json, urllib.request, time, sys
URL="https://rpc.grxchain.io"
def rpc(method, params, batch=False):
    req={"jsonrpc":"2.0","id":1,"method":method,"params":params}
    r=urllib.request.Request(URL,data=json.dumps(req).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for a in range(3):
        try: return json.load(urllib.request.urlopen(r,timeout=60)).get("result")
        except Exception as e: time.sleep(2)
    return None
def batch(items):
    # items: list of (method, params)
    reqs=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(items)]
    out={}
    for j in range(0,len(reqs),10):
        ch=reqs[j:j+10]
        r=urllib.request.Request(URL,data=json.dumps(ch).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        for a in range(3):
            try:
                resp=json.load(urllib.request.urlopen(r,timeout=90)); break
            except Exception as e: time.sleep(2)
        for x in resp: out[x["id"]]=x.get("result") or str(x.get("error"))
    return out

addrs={
 "pair0":"0x490620Fa57f554073D67C77c6ccdCCc1e6188B32",
 "pair1":"0x47b7F566A7c2F827d16a2336684B31929E1cB386",
 "pair2":"0x165AA0A040da0504036dB32130C9d69233c69cC5",
 "pair3":"0xB8D0a95d6c3551B4096382f1b9447db714E8a649",
 "pair4":"0x1787BBA5bd5C132894B65eAADe1B54C205F41946",
 "pair5":"0x5916FF9D9c2CA2cee90045171554ecaa902A41b8",
 "pair6":"0xaB664e44cdcD8354FC11F7ec7836662e403053f0",
 "pair7":"0x1E30EA8fba02FC12B3f8b8b80E1bD65a19BC781C",
 "router02":"0xC9e92Cd01e4C0b734d7d3a5775DEf789d532691d",
 "routerV2":"0x28fC93b8a20570f2B59d5CA9f8a1dA02C4DBcDF5",
 "factory":"0xc7316818841f355c5107753a3f3fdea799bd25f6",
 "feeTo":"0xDb9011614CC30136Af7EBBa4e314641e07c10221",
 "USDT18_a_owner":"0x53e6a26f382e6b6d50a183c747cb0c7607ba8043",
 "USDT18_b_owner":"0xb25aca59f939138be076ab3fa450c7d078855555",
 "WGRX_a":"0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5",
 "USDT18_a":"0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",
 "USDT18_b":"0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75",
 "WGRX_b":"0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212",
 "SAFE":"0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F",
 "ST":"0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081",
 "BTC":"0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275",
 "ETH":"0x02D129c8A26839c814925eE0f1D320F63114E1FE",
 "USDT6":"0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20",
}
items=[]
labels=[]
for n,a in addrs.items():
    items.append(("eth_getCode",[a,"latest"])); labels.append(f"code.{n}")
# storage slots of USDT18_a and _b
for n in ["USDT18_a","USDT18_b"]:
    for s in range(0,9):
        items.append(("eth_getStorageAt",[addrs[n],hex(s),"latest"])); labels.append(f"slot{s}.{n}")
out=batch(items)
res={labels[i]:v for i,v in out.items()}
for k,v in res.items():
    if v and len(v)>200 and k.startswith("code."):
        print(f"{k}: codelen={(len(v)-2)//2} hash=0x{v[2:][:0]}...") if False else print(f"{k}: codelen={(len(v)-2)//2}")
    else:
        print(f"{k}: {v}")
# code hashes
import hashlib
print("=== keccak-ish code identity: compare full code equality ===")
codes={}
for k,v in res.items():
    if k.startswith("code."): codes[k[5:]]=v
base=None
for n,c in codes.items():
    if base is None: base=(n,c)
    print(n, "same-as-"+base[0] if c==base[1] else "DIFFERENT", "len", (len(c)-2)//2)
json.dump(res,open("misc1.json","w"),indent=1)

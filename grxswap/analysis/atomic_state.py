import json, urllib.request, time, subprocess
URL="https://rpc.grxchain.io"
_sel={}
def sel(sig):
    if sig not in _sel: _sel[sig]=subprocess.check_output(["cast","sig",sig]).decode().strip()
    return _sel[sig]
def pad(a): return a.lower().replace("0x","").rjust(64,"0")
def rpc(method,params):
    req={"jsonrpc":"2.0","id":1,"method":method,"params":params}
    r=urllib.request.Request(URL,data=json.dumps(req).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for a in range(3):
        try: return json.load(urllib.request.urlopen(r,timeout=60)).get("result")
        except Exception as e: time.sleep(2)
    return None
def batch(items):
    reqs=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(items)]
    out={}
    for j in range(0,len(reqs),10):
        ch=reqs[j:j+10]
        r=urllib.request.Request(URL,data=json.dumps(ch).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        for a in range(3):
            try: resp=json.load(urllib.request.urlopen(r,timeout=90)); break
            except Exception as e: time.sleep(2)
        for x in resp: out[x["id"]]=x.get("result") or str(x.get("error"))
    return out

blk=int(rpc("eth_blockNumber",[]),16)
blk_hex=hex(blk)
print("pinned block",blk)
pairs={
 "pair0":("0x490620Fa57f554073D67C77c6ccdCCc1e6188B32",["0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5","0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081"]),
 "pair1":("0x47b7F566A7c2F827d16a2336684B31929E1cB386",["0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2","0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5"]),
 "pair2":("0x165AA0A040da0504036dB32130C9d69233c69cC5",["0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20","0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275"]),
 "pair3":("0xB8D0a95d6c3551B4096382f1b9447db714E8a649",["0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2","0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275"]),
 "pair4":("0x1787BBA5bd5C132894B65eAADe1B54C205F41946",["0x02D129c8A26839c814925eE0f1D320F63114E1FE","0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2"]),
 "pair5":("0x5916FF9D9c2CA2cee90045171554ecaa902A41b8",["0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75","0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212"]),
 "pair6":("0xaB664e44cdcD8354FC11F7ec7836662e403053f0",["0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5","0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F"]),
 "pair7":("0x1E30EA8fba02FC12B3f8b8b80E1bD65a19BC781C",["0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75","0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F"]),
}
items=[];labels=[]
for p,(pa,toks) in pairs.items():
    items.append(("eth_call",[{"to":pa,"data":sel("getReserves()")},blk_hex])); labels.append(f"{p}.reserves")
    for i,t in enumerate(toks):
        items.append(("eth_call",[{"to":t,"data":sel("balanceOf(address)")+pad(pa)},blk_hex])); labels.append(f"{p}.bal{i}")
    items.append(("eth_call",[{"to":pa,"data":sel("totalSupply()")},blk_hex])); labels.append(f"{p}.lpTotal")
items.append(("eth_getBlockByNumber",[blk_hex,False])); labels.append("block")
out=batch(items)
res={labels[i]:v for i,v in out.items()}
json.dump(res,open("atomic_state.json","w"),indent=1)
blkdata=res["block"]; import datetime
print("block ts", int(blkdata["timestamp"],16), datetime.datetime.utcfromtimestamp(int(blkdata["timestamp"],16)))
for p in pairs:
    r=res[f"{p}.reserves"]
    if r.startswith("0x") and len(r)==2+64*3:
        r0=int(r[2:66],16); r1=int(r[66:130],16); ts=int(r[130:],16)
    else:
        r0=r1=ts=None
    b0=int(res[f"{p}.bal0"],16); b1=int(res[f"{p}.bal1"],16)
    lp=int(res[f"{p}.lpTotal"],16)
    print(f"{p}: res0={r0} res1={r1} ts={ts}")
    print(f"   bal0={b0} bal1={b1} lpTotal={lp}")
    if r0 is not None:
        print(f"   excess0={b0-r0} excess1={b1-r1}")

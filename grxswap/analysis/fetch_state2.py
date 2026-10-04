import json, urllib.request, time, subprocess
URL="https://rpc.grxchain.io"
_sel={}
def sel(sig):
    if sig not in _sel: _sel[sig]=subprocess.check_output(["cast","sig",sig]).decode().strip()
    return _sel[sig]
def pad(a): return a.lower().replace("0x","").rjust(64,"0")
pairs={
 "pair0":"0x490620Fa57f554073D67C77c6ccdCCc1e6188B32",
 "pair1":"0x47b7F566A7c2F827d16a2336684B31929E1cB386",
 "pair2":"0x165AA0A040da0504036dB32130C9d69233c69cC5",
 "pair3":"0xB8D0a95d6c3551B4096382f1b9447db714E8a649",
 "pair4":"0x1787BBA5bd5C132894B65eAADe1B54C205F41946",
 "pair5":"0x5916FF9D9c2CA2cee90045171554ecaa902A41b8",
 "pair6":"0xaB664e44cdcD8354FC11F7ec7836662e403053f0",
 "pair7":"0x1E30EA8fba02FC12B3f8b8b80E1bD65a19BC781C",
}
toks={
 "pair0":["0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5","0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081"],
 "pair1":["0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2","0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5"],
 "pair2":["0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20","0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275"],
 "pair3":["0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2","0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275"],
 "pair4":["0x02D129c8A26839c814925eE0f1D320F63114E1FE","0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2"],
 "pair5":["0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75","0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212"],
 "pair6":["0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5","0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F"],
 "pair7":["0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75","0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F"],
}
extra={
 "router02":"0xC9e92Cd01e4C0b734d7d3a5775DEf789d532691d",
 "routerV2":"0x28fC93b8a20570f2B59d5CA9f8a1dA02C4DBcDF5",
 "WGRX_a":"0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5",
 "WGRX_b":"0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212",
 "factory":"0xc7316818841f355c5107753a3f3fdea799bd25f6",
 "feeTo":"0xDb9011614CC30136Af7EBBa4e314641e07c10221",
 "USDT18_a_owner":"0x53e6a26f382e6b6d50a183c747cb0c7607ba8043",
 "USDT18_b_owner":"0xb25aca59f939138be076ab3fa450c7d078855555",
}
items=[]; labels=[]
for p,t in toks.items():
    for i,tk in enumerate(t):
        items.append(("eth_call",[{"to":tk,"data":sel("balanceOf(address)")+pad(pairs[p])},"latest"])); labels.append(f"bal.{p}.tok{i}")
for p in pairs:
    items.append(("eth_call",[{"to":pairs[p],"data":sel("totalSupply()")},"latest"])); labels.append(f"lpTotal.{p}")
    items.append(("eth_call",[{"to":pairs[p],"data":sel("balanceOf(address)")+pad("0x0000000000000000000000000000000000000000")},"latest"])); labels.append(f"lpBal0.{p}")
for n,a in extra.items():
    items.append(("eth_getBalance",[a,"latest"])); labels.append(f"native.{n}")
    items.append(("eth_getCode",[a,"latest"])); labels.append(f"code.{n}")
    items.append(("eth_getTransactionCount",[a,"latest"])); labels.append(f"nonce.{n}")
out={}
reqs=[{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(items)]
for j in range(0,len(reqs),10):
    ch=reqs[j:j+10]
    r=urllib.request.Request(URL,data=json.dumps(ch).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for a in range(3):
        try: resp=json.load(urllib.request.urlopen(r,timeout=90)); break
        except Exception as e: print("retry",j,e); time.sleep(2)
    for x in resp: out[labels[x["id"]]]=x.get("result") or str(x.get("error"))
for k,v in out.items():
    if k.startswith("code."):
        print(f"{k}: len={(len(v)-2)//2 if v and v!='0x' else 0}")
    else:
        print(f"{k}: {v}")
json.dump(out,open("state2.json","w"),indent=1)

import json, urllib.request, subprocess, time
URL="https://rpc.grxchain.io"
_sel={}
def sel(sig):
    if sig not in _sel:
        _sel[sig]=subprocess.check_output(["cast","sig",sig]).decode().strip()
    return _sel[sig]
def pad(addr): return addr.lower().replace("0x","").rjust(64,"0")
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
factory="0xc7316818841f355c5107753a3f3fdea799bd25f6"
tokens={
 "WGRX_a":"0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5",
 "ST":"0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081",
 "USDT18_a":"0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",
 "BTC":"0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275",
 "USDT6":"0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20",
 "ETH":"0x02D129c8A26839c814925eE0f1D320F63114E1FE",
 "USDT18_b":"0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75",
 "WGRX_b":"0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212",
 "SAFE":"0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F",
}
calls=[]
for i in range(8):
    calls.append((f"allPairs[{i}]",factory,sel("allPairs(uint256)")+hex(i)[2:].rjust(64,"0")))
calls.append(("feeTo",factory,sel("feeTo()")))
calls.append(("feeToSetter",factory,sel("feeToSetter()")))
calls.append(("factory_allPairsLength",factory,sel("allPairsLength()")))
for name,addr in pairs.items():
    for fn in ["token0()","token1()","getReserves()","totalSupply()","kLast()","factory()"]:
        calls.append((f"{name}.{fn}",addr,sel(fn)))
for name,addr in tokens.items():
    for fn in ["owner()","getOwner()","totalSupply()","decimals()","symbol()","paused()"]:
        calls.append((f"{name}.{fn}",addr,sel(fn)))
out={}
reqs=[{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to,"data":data},"latest"]} for i,(label,to,data) in enumerate(calls)]
for j in range(0,len(reqs),10):
    chunk=reqs[j:j+10]
    req=urllib.request.Request(URL,data=json.dumps(chunk).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for attempt in range(3):
        try:
            resp=json.load(urllib.request.urlopen(req,timeout=90)); break
        except Exception as e:
            print("retry",j,e); time.sleep(2)
    else: continue
    for r in resp:
        out[calls[r["id"]][0]]=r.get("result") or str(r.get("error"))
open("state1.json","w").write(json.dumps(out,indent=1))
# pretty print compact
for k,v in out.items():
    print(f"{k}: {v}")

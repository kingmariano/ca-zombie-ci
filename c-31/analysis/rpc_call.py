#!/usr/bin/env python3
"""Generic batched eth_call helper. Usage: rpc_call.py <rpc> <block> <spec.json>
spec.json: [{"to":..,"sig":"name()","args":[...]}...]
prints JSON results (decoded ints/address/string/raw hex)."""
import json, sys, urllib.request

RPC, BLOCK, SPEC = sys.argv[1], sys.argv[2], sys.argv[3]
if BLOCK.isdigit(): BLOCK = hex(int(BLOCK))

SIGS = {
 "name()":"0x06fdde03","symbol()":"0x95d89b41","decimals()":"0x313ce567","totalSupply()":"0x18160ddd",
 "getPricePerFullShare()":"0x77c7b8fc","token()":"0xfc0c546a","want()":"0x1f1fcd51","balance()":"0xb69ef8a8",
 "controller()":"0xf77c4791","governance()":"0x5aa6e675","strategy()":"0xa8c62e76","strategies(address)":"0x39ebf823","marketLiquidity()":"0x612ef80b","totalAssetSupply()":"0x8fb807c5","supplyInterestRate()":"0x09ec6b6b","loanTokenAddress()":"0x797bf385","borrowInterestRate()":"0x8325a1c0","balanceFulcrum()":"0x1f42a8f8","balanceFulcrumInToken()":"0x3a8f4b4d","balanceDydx()":"0x1c9e9632","balanceAave()":"0x5a1e6d9a","balanceCompound()":"0x35a2a5a5","balanceCompoundInToken()":"0x6dcd0665","provider()":"0x085d4883","balanceDydx()":"0x39c0a7e1","balanceAave()":"0xcf8ca426","balanceCompound()":"0x61c1ec55","balanceCompoundInToken()":"0xa7287971","balanceFulcrum()":"0x0eb2a267","balanceFulcrumInToken()":"0xf5a41dea","fulcrum()":"0x58782c21","compound()":"0xf69e2046","aaveToken()":"0x06a3fe59","dydx()":"0x8e4ec6ef","dToken()":"0xd9d7858a","apr()":"0x57ded9c9","vaults(address)":"0xa622ee7c","split()":"0xf7654176","earn(address,uint256)":"0xb02bf4b9","withdraw(address,uint256)":"0xf3fef3a3",
 "calcPoolValueInToken()":"0x7137ef99","totalAssets()":"0x01e1d114","pricePerShare()":"0x99530b06",
 "balanceOf(address)":"0x70a08231","balanceOf()":"0x722713f7","assetBalanceOf(address)":"0x06b3efd6",
 "tokenPrice()":"0x7ff9b596","exchangeRateStored()":"0x182df0f5","getPricePerFullShare()":"0x77c7b8fc",
 "withdrawAll()":"0x853828b6","reserve()":"0x4d4e65dd","paused()":"0x5c975abb","owner()":"0x8da5cb5b",
 "min()":"0x5d8f53a4","available()":"0x48a0d754","rewards()":"0x9ec5a894","strategist()":"0x1fe4a686",
 "get_virtual_price()":"0xbb7b8b80","balances(uint256)":"0x4903b0d1","coins(uint256)":"0xc6610657",
 "minter()":"0x07546172","minters(address)":"0x35cf608a","getRate()":"0x679aefce","rate()":"0x2c4e722e",
 "totalAssets()":"0x01e1d114","convertToAssets(uint256)":"0x07a2d13a","previewRedeem(uint256)":"0x4cdad506",
 "asset()":"0x38d52e0f","balanceOfUnderlying(address)":"0x3af9e669","cToken()":"0x6f307dc3",
 "admin()":"0xf851a440","implementation()":"0x5c60da1b","paused()":"0x5c975abb",
}
def enc_arg(a):
    if isinstance(a,str) and a.startswith("0x"):
        return a[2:].rjust(64,"0")
    return format(int(a),'x').rjust(64,"0")

spec = json.load(open(SPEC))
calls=[]; meta=[]
for item in spec:
    sig = item["sig"]; sel = SIGS.get(sig)
    if sel is None:
        raise SystemExit(f"unknown sig {sig}")
    data = sel + "".join(enc_arg(a) for a in item.get("args",[]))
    calls.append({"to":item["to"],"data":data}); meta.append((item["to"],sig,item.get("args",[])))
payload=[{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":c["to"],"data":c["data"]},BLOCK]} for i,c in enumerate(calls)]
req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),headers={"Content-Type":"application/json","User-Agent":"research"})
r=json.load(urllib.request.urlopen(req,timeout=120))
byid={x["id"]:x for x in r}
def decode(res, sig):
    if res is None: return None
    b=bytes.fromhex(res[2:])
    if sig in ("name()","symbol()"):
        if len(b)<64: return None
        off=int.from_bytes(b[:32],"big"); ln=int.from_bytes(b[off:off+32],"big")
        return b[off+32:off+32+ln].decode(errors="replace")
    if not b: return None
    v=int.from_bytes(b[:32],"big")
    if sig in ("token()","want()","controller()","governance()","strategy()","strategies(address)","owner()","minter()","asset()","cToken()","admin()","implementation()","rewards()","strategist()"):
        return "0x"+hex(v)[2:].rjust(40,"0")
    return v
out=[]
for i,(to,sig,args) in enumerate(meta):
    x=byid.get(i,{})
    out.append({"to":to,"sig":sig,"args":args,"result":decode(x.get("result"),sig),"error":x.get("error",{}).get("message") if x.get("error") else None})
print(json.dumps(out,indent=1))

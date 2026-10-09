#!/usr/bin/env python3
"""Probe the unverified oracle for batch-vs-individual consistency and edge cases."""
import json, urllib.request, hashlib

RPC = "https://mainnet.aurora.dev"
ORACLE = "0x5A7B8E3CDc6ee2E0E6Ad0d4fab8dCD70990157EE"
M = {
 "auUSDC":"0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
 "auETH":"0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
 "auWBTC":"0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
 "auUSDT":"0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
 "auDAI":"0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
 "auWNEAR":"0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
 "auSTNEAR":"0x3195949f267702723bc614cAE037cdc8D1E94786",
 "auAURORA":"0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf",
 "auTRI":"0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca",
 "auPLY":"0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c",
 "auUSN":"0x5cCAD065400341db391FD3a4B7F50087B678D7CC",
 "auNEARX":"0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
 "auUSDCNative":"0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
 "auUSDTNative":"0xdDfd0407220026c6566979B5be6A4983d1247a3E",
}

def sel(sig):
    from Crypto.Hash import keccak as _k; h=_k.new(digest_bits=256); h.update(sig.encode()); return "0x"+h.hexdigest()[:8]

S_PRICE = sel("getUnderlyingPrice(address)")
S_PRICES = sel("getUnderlyingPrices(address[])")

def eth_call(to, data):
    p = {"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}
    req = urllib.request.Request(RPC, data=json.dumps(p).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    out = json.load(urllib.request.urlopen(req, timeout=60))
    if "error" in out:
        return ("REVERT", out["error"].get("message",""))
    return ("OK", out["result"])

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")

def enc_arr(addrs):
    n=len(addrs)
    head=format(32,'064x')
    ln=format(n,'064x')
    body="".join(enc_addr(a) for a in addrs)
    return head+ln+body

def dec_words(res):
    b=res[2:]
    return [int(b[i:i+64],16) for i in range(0,len(b),64)]

names=list(M.keys())
print("=== individual ===")
ind={}
for n in names:
    st,r = eth_call(ORACLE, S_PRICE+enc_addr(M[n]))
    if st=="OK":
        v=dec_words(r)[0]
        ind[n]=v
        print(f"{n:14s} {v}")
    else:
        ind[n]=None
        print(f"{n:14s} REVERT: {r.split(':')[-1][:60]}")

print()
print("=== batch order tests ===")
tests = [
  ["auWNEAR","auUSDC"],
  ["auUSDC","auWNEAR"],
  ["auWBTC","auETH","auUSDC"],
  ["auUSDC","auUSDC","auUSDC"],
  ["auNEARX","auSTNEAR","auDAI","auAURORA"],
]
for t in tests:
    st,r = eth_call(ORACLE, S_PRICES+enc_arr([M[x] for x in t]))
    if st=="OK":
        vals=dec_words(r)
        # first word is offset; then length then values
        off=vals[0]//32
        ln=vals[off]
        prices=vals[off+1:off+1+ln]
        exp=[ind[x] for x in t]
        match = prices==exp
        print(f"{t} -> {prices} expected {exp} match={match}")
    else:
        print(f"{t} -> REVERT {r.split(':')[-1][:60]}")

print()
print("=== empty array and unknown token ===")
st,r = eth_call(ORACLE, S_PRICES+enc_arr([]))
print("empty arr:", st, r[:80] if isinstance(r,str) else r)
st,r = eth_call(ORACLE, S_PRICE+enc_addr("0x0000000000000000000000000000000000000001"))
print("unknown token price:", st, r[:80] if isinstance(r,str) else r)

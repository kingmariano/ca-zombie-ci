#!/usr/bin/env python3
"""Read-only Silicon state: Orbit Bridge vault, ORC token, CDK bridge mappings."""
import json, urllib.request

SILICON="https://rpc.silicon.network"
_id=[0]
def rpc(method, params, url=SILICON):
    _id[0]+=1
    req=urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":_id[0],"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (X11; Linux x86_64) research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        d=json.load(r)
    if "error" in d: raise RuntimeError(d["error"])
    return d["result"]
def call(to,data): return rpc("eth_call",[{"to":to,"data":data},"latest"])
def u(h): return None if not h or h=="0x" else int(h,16)
def a(h): return None if not h or h=="0x" else "0x"+h[-40:]
def s(h):
    if not h or h=="0x": return None
    b=bytes.fromhex(h[2:]); off=int.from_bytes(b[0:32],"big"); ln=int.from_bytes(b[off:off+32],"big")
    return b[off+32:off+32+ln].decode("utf-8","replace")
def abi_encode_addr(addr): return addr[2:].lower().rjust(64,"0")

VAULT="0x5aaacf28ecdd691b4a657684135d8848d38236bb"
ORC="0x37908ffdEf18aDD36518e781a9a77C2C6f4A4260"
CDK="0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe"
ETH_ORC="0x662b67d00a13faf93254714dd601f5ed49ef2f51"
TOKENS={
 "ORC":(ORC,18), "USDC":("0xa8ce8aee21bc2a48a5ef670afcc9274c7bbbc035",6),
 "USDT":("0x1e4a5963abfd975d8c9021ce480b42188849d41d",6), "WBTC":("0xea034fb02eb1808c2cc3adbc15f447b93cbe08e1",8),
 "DAI":("0xc5015b9d9161dca7e18e32f6f25c4ad850731fd4",18), "oETH":("0xb985c4038fbfb93d2f31e464fbc5e3cc880ef51a",18),
 "oUSDC":("0x526706950ce5c6bb6d30cf12297f4d2070d3adaa",6), "oWBTC":("0xf641817e8fdbaaa721d59ae9c6640d3bd73a4b42",8),
 "oUSDT":("0xeda06e07deab7de0885efe3a489fdc471728868b",6), "oDAI":("0x94021eb912e5837dcf8314914f5ae681b1180770",18),
 "POL":("0xa2036f0538221a77a3937f1379699f44945018d0",18),
}
HOLDERS={
 "OrbitVault0x5aaa":VAULT,
 "Voting0x33fa":  "0x33fa9a4f2C06de9bD80A34663C72C797E257D3d9",
 "Governor0x3d0F": "0x3d0FD4bB3eA78657727eD7d20d9195288EaBC7dF",
 "CDKbridge":CDK,
}
if __name__=="__main__":
    bn=int(rpc("eth_blockNumber",[]),16)
    print("# Silicon block", bn)
    print("== code presence ==")
    for n,addr in [("OrbitVault",VAULT),("ORC",ORC),("CDKbridge",CDK)]:
        c=rpc("eth_getCode",[addr,"latest"])
        print(f"  {n:10} {addr} codelen={len(c)//2-1}")
    print("== vault reads (EthVault-like selectors) ==")
    for name,sel,dec in [("chain()","0x05f5d2f5","s"),("isActivated","0xd0ac6af3","u"),("implementation","0x5c60da1b","a"),
                          ("required","0xdc8452cd","u"),("policyAdmin","0x39a66e6b","a"),("feeGovernance","0x1e3117a3","a"),
                          ("getVersion","0x3c530b3d","s"),("depositCount","0x2dfdf0b5","u"),("transactionCount","0x6f2fd1f4","u"),
                          ("getOwners0","0x025e7c27"+"0"*64,"a"),("hub","0xa2d68f2d","a"),("governance","0x5aa6e675","a"),("owner","0x8da5cb5b","a")]:
        try:
            r=call(VAULT,sel)
            print(f"  {name:18}", a(r) if dec=="a" else (s(r) if dec=="s" else u(r)))
        except Exception as e:
            print(f"  {name:18} ERR {str(e)[:70]}")
    print("  native ETH:", int(rpc("eth_getBalance",[VAULT,"latest"]),16)/1e18)
    print("== balances held by vault/holders ==")
    for tn,(ta,dec) in TOKENS.items():
        try:
            for hn,ha in HOLDERS.items():
                b=u(call(ta,"0x70a08231"+abi_encode_addr(ha)))
                if b: print(f"  {tn:6} in {hn:20} {b/10**dec:,.4f}")
        except Exception as e:
            print(f"  {tn:6} ERR {str(e)[:50]}")
    print("== ORC token on Silicon ==")
    for name,sel,dec in [("name","0x06fdde03","s"),("symbol","0x95d89b41","s"),("decimals","0x313ce567","u"),
                          ("totalSupply","0x18160ddd","u"),("owner","0x8da5cb5b","a"),("minter","0x07546172","a"),
                          ("implementation","0x5c60da1b","a"),("governance","0x5aa6e675","a")]:
        try:
            r=call(ORC,sel)
            print(f"  {name:16}", a(r) if dec=="a" else (s(r) if dec=="s" else u(r)))
        except Exception as e:
            print(f"  {name:16} ERR {str(e)[:60]}")
    print("== CDK bridge wrapped-token lookups (originNetwork=0) ==")
    for tn,(ta,dec) in TOKENS.items():
        origin = ETH_ORC if tn=="ORC" else None
        if not origin: continue
        for fn,sel in [("getWrappedToken","0x968e77ed"),("getTokenWrappedAddress","0xbe5831c7")]:
            data=sel+"0"*64+abi_encode_addr(origin)
            try:
                r=call(CDK,data); print(f"  {fn} {tn} -> {a(r)}")
            except Exception as e:
                print(f"  {fn} {tn} ERR {str(e)[:50]}")

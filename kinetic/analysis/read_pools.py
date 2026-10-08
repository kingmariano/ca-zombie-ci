#!/usr/bin/env python3
"""Quick generic multi-comptroller market state reader. Usage: python3 read_pools.py <rpc> <comptroller> [<comptroller>...]"""
import json, sys, requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://14.rpc.thirdweb.com"
CMS = sys.argv[2:]
NATIVE_SIGS = {"underlying()"}

def sel(s): return keccak(text=s)[:4].hex()
def call(to, sig, atypes=[], avals=[], rtypes=["uint256"]):
    data = "0x" + sel(sig) + (abi_encode(atypes, avals).hex() if atypes else "")
    r = requests.post(RPC, json={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}, timeout=30).json()
    h = r.get("result")
    if not h or h == "0x":
        return None
    return abi_decode(rtypes, bytes.fromhex(h[2:]))

def try_call(to, sig, atypes=[], avals=[], rtypes=["uint256"]):
    try:
        v = call(to, sig, atypes, avals, rtypes)
        return v[0] if v else None
    except Exception:
        return None

for C in CMS:
    print(f"\n=== COMPTROLLER {C} (codesize {len(requests.post(RPC, json={'jsonrpc':'2.0','id':1,'method':'eth_getCode','params':[C,'latest']}, timeout=30).json().get('result','0x'))//2 - 1 if True else '?'}) ===")
    print("oracle:", try_call(C, "oracle()(address)", rtypes=["address"]))
    print("admin:", try_call(C, "admin()(address)", rtypes=["address"]))
    print("impl:", try_call(C, "comptrollerImplementation()(address)", rtypes=["address"]))
    mk = call(C, "getAllMarkets()", [], [], ["address[]"])
    mks = mk[0] if mk else []
    print("markets:", mks)
    for M in mks:
        sym = try_call(M, "symbol()(string)", rtypes=["string"])
        und = try_call(M, "underlying()(address)", rtypes=["address"])
        cash = try_call(M, "getCash()(uint256)")
        ts = try_call(M, "totalSupply()(uint256)")
        tb = try_call(M, "totalBorrows()(uint256)")
        tr = try_call(M, "totalReserves()(uint256)")
        er = try_call(M, "exchangeRateStored()(uint256)")
        mkst = call(C, "markets(address)", ["address"], [M], ["bool", "uint256"])
        mp = try_call(C, "mintGuardianPaused(address)(bool)", ["address"], [M], ["bool"])
        bp = try_call(C, "borrowGuardianPaused(address)(bool)", ["address"], [M], ["bool"])
        bc = try_call(C, "borrowCaps(address)(uint256)", ["address"], [M])
        print(f"  {sym} {M}")
        print(f"    und={und} cash={cash} supply={ts} borrows={tb} reserves={tr} exRate={er}")
        print(f"    listed={mkst} mintPaused={mp} borrowPaused={bp} borrowCap={bc}")

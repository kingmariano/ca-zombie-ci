#!/usr/bin/env python3
"""Dump VaultV2 adapter market state on Base (read-only, keyless RPC)."""
import json, urllib.request, sys, time

RPCS = ["https://mainnet.base.org", "https://base.publicnode.com", "https://base.drpc.org"]
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"

def sel(s):
    import subprocess
    return subprocess.run(["cast","sig",s],capture_output=True,text=True).stdout.strip()

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def enc_uint(n): return hex(n)[2:].rjust(64,"0")
def enc_b32(b): return b.lower().replace("0x","").rjust(64,"0")

def rpc_batch(calls, tries=3):
    for attempt in range(tries):
        rpc = RPCS[attempt % len(RPCS)]
        payload = [{"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":t,"data":d},"latest"]} for i,(t,d) in enumerate(calls)]
        req = urllib.request.Request(rpc, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        try:
            out = json.load(urllib.request.urlopen(req, timeout=60))
            res = {item["id"]: item.get("result") for item in out}
            return [res.get(i) for i in range(len(calls))]
        except Exception as e:
            print(f"  rpc batch failed ({rpc}): {e}", file=sys.stderr); time.sleep(2)
    return [None]*len(calls)

def words(h):
    h=h[2:] if h and h.startswith("0x") else h or ""
    return [h[i:i+64] for i in range(0,len(h),64)]

def addr_of(w): return "0x"+w[-40:]
def uint_of(w): return int(w,16)

S = {k: sel(k) for k in ["marketIdsLength()","marketIds(uint256)","supplyShares(bytes32)","expectedSupplyAssets(bytes32)","realAssets()",
    "market(bytes32)","position(bytes32,address)","idToMarketParams(bytes32)","supplyShares(bytes32,address)","allocation(bytes32)",
    "absoluteCap(bytes32)","relativeCap(bytes32)","forceDeallocatePenalty(address)","isAllocator(address)","isSentinel(address)",
    "canSendAssets(address)","isInRegistry(address)","asset()"]}

VAULTS = {
 "usdc_prime":   ("0x89712980cb434ef5ae4ab29349419eb976b0b496","0xC2ec18c8049ab354756304Fb8F9e45e084097972"),
 "weth_prime":   ("0xd6dcad2f7da91fbb27bda471540d9770c97a5a43","0xa54d822CD2a3E95A847AcFce2400D0b38205ffD8"),
 "cbbtc_prime":  ("0x99dcd0d75822ba398f13b2a8852b07c7e137ec70","0x2eeb629c6F2998842617cb6d1E8167Cc86F44e13"),
 "usdc_frontier":("0x314fD07319ef645bA7D548915CCd91F4788A1839","0xD0500CD83eCA6085dcFbE0A052B335F26da71BFd"),
}

out={"morpho":MORPHO,"vaults":{}}
for name,(vault,adapter) in VAULTS.items():
    print("="*20,name)
    v={"vault":vault,"adapter":adapter}
    # adapter basics
    calls=[(adapter,S["marketIdsLength()"]),(adapter,S["realAssets()"])]
    res=rpc_batch(calls)
    n=int(res[0],16) if res[0] else 0
    v["marketIdsLength"]=n; v["realAssets_raw"]=res[1]
    # market ids
    ids=[]
    calls=[(adapter,S["marketIds(uint256)"]+enc_uint(i)) for i in range(n)]
    res=rpc_batch(calls) if calls else []
    for i,h in enumerate(res):
        if h and h!="0x": ids.append("0x"+h[-64:])
    v["marketIds"]=ids
    # for each id: morpho params, market state, position, adapter supplyShares/expected, vault caps
    mkts=[]
    for mid in ids:
        calls=[
          (MORPHO,S["idToMarketParams(bytes32)"]+enc_b32(mid)),
          (MORPHO,S["market(bytes32)"]+enc_b32(mid)),
          (MORPHO,S["position(bytes32,address)"]+enc_b32(mid)+enc_addr(adapter)),
          (adapter,S["supplyShares(bytes32)"]+enc_b32(mid)),
          (adapter,S["expectedSupplyAssets(bytes32)"]+enc_b32(mid)),
        ]
        r=rpc_batch(calls)
        p=words(r[0]) if r[0] else []
        m=words(r[1]) if r[1] else []
        pos=words(r[2]) if r[2] else []
        mkt={"id":mid,
             "loanToken":addr_of(p[0]) if p else None,"collateralToken":addr_of(p[1]) if p else None,
             "oracle":addr_of(p[2]) if p else None,"irm":addr_of(p[3]) if p else None,"lltv":uint_of(p[4]) if len(p)>4 else None,
             "totalSupplyAssets":uint_of(m[0]) if m else None,"totalSupplyShares":uint_of(m[1]) if m else None,
             "totalBorrowAssets":uint_of(m[2]) if m else None,"totalBorrowShares":uint_of(m[3]) if m else None,
             "lastUpdate":uint_of(m[4]) if len(m)>4 else None,"fee":uint_of(m[5]) if len(m)>5 else None,
             "adapterSupplyShares":uint_of(pos[0]) if pos else None,"adapterBorrowShares":uint_of(pos[1]) if pos else None,
             "adapterCollateral":uint_of(pos[2]) if len(pos)>2 else None,
             "adapterSupplySharesInternal":uint_of(words(r[3])[0]) if r[3] else None,
             "expectedSupplyAssets":uint_of(words(r[4])[0]) if r[4] else None,
        }
        # vault caps key = keccak256(abi.encode("this/marketParams", adapter, marketParams))
        import subprocess
        enc = subprocess.run(["cast","abi-encode","f((address,address,address,address,uint256))",
             f"({mkt['loanToken']},{mkt['collateralToken']},{mkt['oracle']},{mkt['irm']},{mkt['lltv']})"],capture_output=True,text=True).stdout.strip()
        key = subprocess.run(["cast","keccak",enc],capture_output=True,text=True).stdout.strip()
        # keccak256(abi.encode("this/marketParams", address(this), marketParams)) -- need exact encoding
        enc2 = subprocess.run(["cast","abi-encode","f(string,address,(address,address,address,address,uint256))",
             "this/marketParams",adapter,f"({mkt['loanToken']},{mkt['collateralToken']},{mkt['oracle']},{mkt['irm']},{mkt['lltv']})"],capture_output=True,text=True).stdout.strip()
        key2 = subprocess.run(["cast","keccak",enc2],capture_output=True,text=True).stdout.strip()
        mkt["caps_key"]=key2
        r2=rpc_batch([(vault,S["allocation(bytes32)"]+enc_b32(key2)),(vault,S["absoluteCap(bytes32)"]+enc_b32(key2)),(vault,S["relativeCap(bytes32)"]+enc_b32(key2))])
        mkt["vaultAllocation"]=uint_of(words(r2[0])[0]) if r2[0] else None
        mkt["vaultAbsoluteCap"]=uint_of(words(r2[1])[0]) if r2[1] else None
        mkt["vaultRelativeCap"]=uint_of(words(r2[2])[0]) if r2[2] else None
        mkts.append(mkt)
        print(json.dumps({k:mkt[k] for k in ["loanToken","collateralToken","oracle","lltv","totalSupplyAssets","totalBorrowAssets","adapterSupplyShares","expectedSupplyAssets","vaultAllocation","vaultAbsoluteCap","vaultRelativeCap"]}))
    v["markets"]=mkts
    # penalty, allocator flags for known actors
    r=rpc_batch([(vault,S["forceDeallocatePenalty(address)"]+enc_addr(adapter))])
    v["forceDeallocatePenalty"]=uint_of(words(r[0])[0]) if r[0] else None
    print(" penalty:",v["forceDeallocatePenalty"])
    out["vaults"][name]=v

json.dump(out,open("market-state.json","w"),indent=1)
print("saved market-state.json")

#!/usr/bin/env python3
"""childA live probes: execute add/remove roundtrips and swap cycles ON the real pool
inside eth_call with state overrides (Tenderly gateway). Compare vs exact model.
READ-ONLY (eth_call / eth_estimateGas only)."""
import json, subprocess, time, sys
sys.path.insert(0, "/home/heisenberg/CA/swerve/analysis")
import importlib

U = "https://gateway.tenderly.co/public/mainnet"
CALLER = "0x1111111111111111111111111111111111111111"   # helper code injected here
POOL = "0x329239599afB305DA0A2eC69c58F8a6697F9F88d"
LP   = "0x77c6e4a580c0dce4e5c7a17d0bc077188a83a059"
TOK  = ["0x6B175474E89094C44Da98b954EedeAC495271d0F",
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        "0x0000000000085d4780B73119b644AE5ecd22b376"]
SLOTS = {"bal":[2,9,2,14], "alw":[3,10,5,15]}
MAX = "0x" + "f"*64

from Crypto.Hash import keccak as _ck
def keccak_hex(b):
    h=_ck.new(digest_bits=256); h.update(b); return "0x"+h.hexdigest()
def pad32(a): return bytes.fromhex(a[2:]).rjust(32,b"\x00")
def kaddr(a,s): return keccak_hex(pad32(a)+s.to_bytes(32,"big"))
def knest(a1,a2,s): return keccak_hex(pad32(a2)+bytes.fromhex(kaddr(a1,s)[2:]))

def rpc(method, params, tries=5):
    p=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params})
    for a in range(tries):
        r=subprocess.run(["curl","-s","-X","POST",U,"-H","content-type: application/json","--data-binary",p],capture_output=True,text=True,timeout=180)
        try: d=json.loads(r.stdout)
        except Exception: d={"raw":r.stdout[:300]}
        if isinstance(d,dict) and d.get("error",{}).get("code")==-32005:
            time.sleep(4*(a+1)); continue
        return d
    return d

def sig(s):
    return subprocess.run(["cast","sig",s],capture_output=True,text=True).stdout.strip()

def compile_helper():
    out=subprocess.run(["solc","--bin-runtime","/home/heisenberg/CA/swerve/analysis/childA_probe.sol"],capture_output=True,text=True)
    lines=[l for l in out.stdout.splitlines() if l.strip()]
    hexline=[l for l in lines if l.startswith("60") or (len(l)>200 and all(c in "0123456789abcdef" for c in l.strip()))]
    # take the last long hex line
    cand=[l.strip() for l in lines if len(l.strip())>1000 and all(c in "0123456789abcdefABCDEF" for c in l.strip())]
    if not cand:
        print("solc output:", out.stdout[:500], out.stderr[:500]); raise SystemExit(1)
    return "0x"+cand[-1]

HELPER_CODE = compile_helper()

def pad32hex(x): return "0x" + hex(x & (2**256-1))[2:].rjust(64, "0")

def overrides(funds):
    ov = {CALLER: {"code": HELPER_CODE}}
    for k in range(4):
        ov.setdefault(TOK[k], {"stateDiff": {}})
        ov[TOK[k]]["stateDiff"][kaddr(CALLER, SLOTS["bal"][k])] = pad32hex(funds[k])
        ov[TOK[k]]["stateDiff"][knest(CALLER, POOL, SLOTS["alw"][k])] = MAX
    return ov

def run_live(data, funds):
    d = rpc("eth_call", [{"from": CALLER, "to": CALLER, "data": data, "gas": "0x1c9c380"}, "latest", overrides(funds)])
    if "result" not in d: return {"error": d.get("error") or d}
    hx = d["result"][2:]
    return [int(hx[i:i+64],16) for i in range(0,len(hx),64)]

def enc_u(x): return hex(x & (2**256-1))[2:].rjust(64,"0")
def enc_i(x): return enc_u(x & (2**128-1))

if __name__ == "__main__":
    m = importlib.import_module("childA_model")
    print("model state:", m.BAL, "supply", m.SUPPLY)

    print("\n== LIVE add_liquidity -> remove_liquidity roundtrips ==")
    vectors = [
        [10**18,0,0,0],
        [0,10**6,0,0],
        [0,0,10**6,0],
        [0,0,0,10**18],
        [1000*10**18,1000*10**6,1000*10**6,1000*10**18],
        [10**18,10**6,10**6,10**18],
    ]
    for amt in vectors:
        data = sig("roundtrip(uint256[4])") + "".join(enc_u(a) for a in amt)
        res = run_live(data, amt)
        if isinstance(res, dict): print("  amt",amt,"->",res); continue
        minted, bal = res[0], res[1:5]
        net = [bal[k]-amt[k] for k in range(4)]
        try:
            mmint, mst, mfees, mD1, mD2 = m.add_liquidity(m.BAL, amt, m.SUPPLY)
            mgot, mst2 = m.remove_liquidity(mst, mmint, m.SUPPLY+mmint)
            mnet = [mgot[k]-amt[k] for k in range(4)]
        except Exception as e:
            mmint, mnet = f"REVERT {e}", None
        match = (minted==mmint and mnet==net)
        print(f"  amt={amt}\n    live mint={minted} net={net}\n    model mint={mmint} net={mnet}  MATCH={match}")

    print("\n== LIVE single swaps ==") 
    for i,j,dx in [(0,2,10**18),(0,1,10**18),(3,1,10**18),(0,1,0),(0,3,0),(3,2,0),(1,0,10**6)]:
        fund = [0]*4; fund[i]=dx
        data = sig("single(int128,int128,uint256)") + enc_i(i)+enc_i(j)+enc_u(dx)
        res = run_live(data, fund)
        if isinstance(res, dict): print("  ",(i,j,dx),"->",res); continue
        bal = res[0:4]; in0 = res[4]
        dy = bal[j]
        try:
            mdy, mst, _ = m.exchange(m.BAL,i,j,dx)
        except Exception as e:
            mdy = f"REVERT {e}"
        print(f"  {i}->{j} dx={dx}: live dy={dy} model dy={mdy} MATCH={dy==mdy}")

    print("\n== LIVE triple swaps (cycle back to input coin) ==") 
    for i,j,k,dx in [(0,1,3,1),(0,3,1,1),(0,1,2,10**18),(0,1,2,10**18)]:
        fund=[0]*4; fund[i]=dx
        data = sig("triple(int128,int128,int128,uint256)") + enc_i(i)+enc_i(j)+enc_i(k)+enc_u(dx)
        res = run_live(data, fund)
        if isinstance(res, dict): print("  ",(i,j,k,dx),"->",res); continue
        bals, d1, d2, final_i = res[0:4], res[4], res[5], res[6]
        # model
        try:
            md1, s1, _ = m.exchange(m.BAL,i,j,dx)
            md2, s2, _ = m.exchange(s1,j,k,md1)
            md3, s3, _ = m.exchange(s2,k,i,md2)
        except Exception as e:
            md1=md2=md3=f"REVERT {e}"
        print(f"  {i}->{j}->{k}->{i} dx={dx}: live d1={d1} d2={d2} final_i={final_i} profit={final_i-dx}")
        print(f"      model d1={md1} d2={md2} d3={md3}")

    print("\n== gas estimates (direct pool calls, with overrides) ==")
    # exchange(0,2,1e18,0) from a funded EOA
    caller2 = "0x2222222222222222222222222222222222222222"
    ov2 = {}
    for k in range(4):
        ov2.setdefault(TOK[k], {"stateDiff": {}})
        ov2[TOK[k]]["stateDiff"][kaddr(caller2, SLOTS["bal"][k])] = pad32hex(10**24)
        ov2[TOK[k]]["stateDiff"][knest(caller2, POOL, SLOTS["alw"][k])] = MAX
    data_ex = sig("exchange(int128,int128,uint256,uint256)")+enc_i(0)+enc_i(2)+enc_u(10**18)+enc_u(0)
    d = rpc("eth_estimateGas",[{"from":caller2,"to":POOL,"data":data_ex},"latest",ov2])
    print("  exchange(0,2,1e18) gas:", d.get("result") or d.get("error"))
    data_al = sig("add_liquidity(uint256[4],uint256)")+"".join(enc_u(a) for a in [10**18,0,0,0])+enc_u(0)
    d = rpc("eth_estimateGas",[{"from":caller2,"to":POOL,"data":data_al},"latest",ov2])
    print("  add_liquidity([1e18,0,0,0]) gas:", d.get("result") or d.get("error"))
    # remove_liquidity: estimate from the GAUGE (holds 2.74e23 swUSD; no override needed)
    GAUGE = "0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa"
    data_rl = sig("remove_liquidity(uint256,uint256[4])")+enc_u(10**18)+enc_u(0)*4
    d = rpc("eth_estimateGas",[{"from":GAUGE,"to":POOL,"data":data_rl},"latest"])
    print("  remove_liquidity(1e18) gas (from gauge):", d.get("result") or d.get("error"))

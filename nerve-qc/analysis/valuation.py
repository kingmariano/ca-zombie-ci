#!/usr/bin/env python3
"""QC-5 final consolidated valuation from the fresh snapshot (fingerprint.json + live reads)."""
import json, urllib.request, os

KEY=os.environ["ANKR_API_KEY"]
RPC=f"https://rpc.ankr.com/bsc/{KEY}"
def rpc(m,p):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),headers={"Content-Type":"application/json"})
    r=json.load(urllib.request.urlopen(req,timeout=45))
    if "error" in r: raise RuntimeError(str(r["error"])[:100])
    return r.get("result")
def u256(x): return hex(int(x))[2:].rjust(64,"0")
def pad(a): return a.lower().replace("0x","").rjust(64,"0")
def ci(to,data):
    r=rpc("eth_call",[{"to":to,"data":data},"latest"])
    return int(r,16) if r and r!="0x" else None

PX={"BUSD":0.99996,"USDT":0.99906,"USDC":0.99963,"BTCB":82828.53,"ETH":2500.12,
    "UST":0.00916,"fUSDT":1.0,"rUSD":0.05445,"anyBTC":0.0,"anyETH":0.0}
DEC={"BUSD":18,"USDT":18,"USDC":18,"BTCB":18,"ETH":18,"UST":18,"fUSDT":6,"rUSD":18,"anyBTC":8,"anyETH":18,"3poolLP":18}

P3="0x1b3771a66ee31180906972580ade9b81afc5fcdc"
BTC="0x6c341938bb75dde823faafe7f446925c66e6270c"
ETH="0x146cd24dcc9f4eb224dfd010c5bf2b0d25afa9c0"
USTM="0x2dcce1586b1664f41c72206900e404ec3ca130e0"
FUSDM="0xd0fbf0a224563d5ffc8a57e4fda6ae080ebcf3d3"
E7="0x0eafaa7ed9866c1f08ac21dd0ef3395e910f7114"
LP3="0xf2511b5e4fb0e5e2d123004b672ba14850478c14"
FARM="0x2ebe8cdbcb5fb8564bc45999dab8da264e31f24e"

def internal(pool,i): return ci(pool,"0x91ceb3eb"+u256(i))
def admin(pool,i): return ci(pool,"0xef0a712f"+u256(i))
def bal(tok,who): return ci(tok,"0x70a08231"+pad(who))
def ts(tok): return ci(tok,"0x18160ddd")

out={"prices":PX}
# LP3 NAV
i3=[internal(P3,i) for i in range(3)]
v3=sum(x*PX[s]/1e18 for x,s in zip(i3,["BUSD","USDT","USDC"]))
lp3_ts=ts(LP3)/1e18
nav=v3/lp3_ts
PX["3poolLP"]=nav
out["lp3"]={"internal_value_usd":v3,"supply":lp3_ts,"nav_usd":nav}

# base pools
for nm,pool,syms in [("3pool",P3,["BUSD","USDT","USDC"]),("btcpool",BTC,["BTCB","anyBTC"]),("ethpool",ETH,["ETH","anyETH"])]:
    d={"internal_usd":0,"admin_usd":0}
    for i,s in enumerate(syms):
        d[f"internal_{s}"]=internal(pool,i)
        d[f"admin_{s}"]=admin(pool,i)
        d["internal_usd"]+=internal(pool,i)*PX[s]/10**DEC[s]
        d["admin_usd"]+=admin(pool,i)*PX[s]/10**DEC[s]
    out[nm]=d

# funded metas
for nm,pool,syms in [("ustmeta",USTM,["UST","3poolLP"]),("fusdtmeta",FUSDM,["fUSDT","3poolLP"])]:
    d={"internal_usd":0,"admin_usd":0,"paused":ci(pool,"0x5c975abb")}
    for i,s in enumerate(syms):
        d[f"internal_{s}"]=internal(pool,i)
        d[f"admin_{s}"]=admin(pool,i)
        d["internal_usd"]+=internal(pool,i)*PX[s]/10**DEC[s]
        d["admin_usd"]+=admin(pool,i)*PX[s]/10**DEC[s]
    out[nm]=d

# E7 (rUSD pool)
out["e7"]={"internal_rUSD":internal(E7,0),"internal_LP3":internal(E7,1),
           "admin_rUSD":admin(E7,0),"admin_LP3":admin(E7,1)}
out["e7"]["internal_usd"]=internal(E7,0)*PX["rUSD"]/1e18+internal(E7,1)*nav/1e18
out["e7"]["admin_usd"]=admin(E7,0)*PX["rUSD"]/1e18+admin(E7,1)*nav/1e18

# farm
out["farm"]={"lp3":bal(LP3,FARM),"lp3_usd":bal(LP3,FARM)/1e18*nav}

# totals
admin_total = out["3pool"]["admin_usd"]+out["btcpool"]["admin_usd"]+out["ethpool"]["admin_usd"]+out["ustmeta"]["admin_usd"]+out["fusdtmeta"]["admin_usd"]+out["e7"]["admin_usd"]
internal_total = out["3pool"]["internal_usd"]+out["btcpool"]["internal_usd"]+out["ethpool"]["internal_usd"]+out["ustmeta"]["internal_usd"]+out["fusdtmeta"]["internal_usd"]+out["e7"]["internal_usd"]
out["totals"]={"admin_owner_only_usd":admin_total,"internal_holders_usd":internal_total}
out["e_u_ceiling"]={
  "lp3_side_across_unpaused_wei":10381892022701008814,
  "lp3_side_usd":10381892022701008814/1e18*nav,
  "e7_rUSD_side_usd":internal(E7,0)*PX["rUSD"]/1e18,
  "e6_fUSDT_side_usd":41491/1e6*PX["fUSDT"],
  "realistic_fresh_attacker_usd":"<= ~2.5 (needs market-buyable token0; E0-E5 token0 dead)"
}
print(json.dumps(out,indent=2))
json.dump(out,open("/home/heisenberg/CA/nerve-qc/analysis/valuation.json","w"),indent=2)

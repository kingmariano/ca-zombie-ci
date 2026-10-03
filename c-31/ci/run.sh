#!/usr/bin/env bash
# C-31 heavy enumeration (read-only): Yearn legacy v1 registry + iEarn family + strategies + yETH.
# Writes JSON state dumps to ci-out/.
set -uo pipefail
mkdir -p ci-out
RPC="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
BLOCK="$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo latest)"
echo "[c-31] rpc=${RPC%%\?*} block=$BLOCK"

python3 - "$RPC" "$BLOCK" <<'PY'
import json, sys, urllib.request, time

RPC = sys.argv[1]
BLOCK = sys.argv[2]
if BLOCK.isdigit(): BLOCK = hex(int(BLOCK))

REG = "0x3eE41C098f9666ed2eA246f4D2558010e59d63A0"
EXTRA = [
 "0x9d25057e62939d3408406975ad75ffe834da4cdd","0x16de59092dae5ccf4a1e6439d611fd0653f0bd01",
 "0xC2cB1040220768554cf699b0d863A3cd4324ce32","0x26EA744E5B887E5205727f55dFBE8685e3b21951",
 "0xd6ad7a6750a7593e092a9b218d66c0a814a3436e","0xa2609b2b43ac0f5ebe27deb944d2a399c201e3da",
 "0xE6354ed5bC4b393a5Aad09f21c46E101e692d447","0x83f798e925bcd4017eb265844fddabb448f1707d",
 "0xa1787206d5b1bE0f432C4c4f96Dc4D1257A1Dd14","0x73a052500105205d34daf004eab301916da8190f",
 "0x36324b8168f960A12a8fD01406C9C78143d41380","0xF61718057901F84C4eEC4339EF8f0D86D2B45600",
 "0x04ef8121ad039ff41d10029c91ea1694432514e9","0x04Aa51bbcB46541455cCF1B8bef2ebc5d3787EC9",
 "0x04bc0ab673d88ae9dbc9da2380cb6b79c4bca9ae",
]
FUNCS = {
 "name":"0x06fdde03","symbol":"0x95d89b41","decimals":"0x313ce567","totalSupply":"0x18160ddd",
 "getPricePerFullShare":"0x77c7b8fc","token":"0xfc0c546a","balance":"0xb69ef8a8",
 "controller":"0xf77c4791","governance":"0x5aa6e675","strategy":"0xa8c62e76",
 "calcPoolValueInToken":"0x7137ef99","balanceDydx":"0x39c0a7e1","balanceAave":"0xcf8ca426",
 "balanceCompoundInToken":"0xa7287971","balanceFulcrumInToken":"0xf5a41dea","fulcrum":"0x58782c21",
 "provider":"0x085d4883","totalAssets":"0x01e1d114","asset":"0x38d52e0f",
 "getVaultsLength":"0x44b19dfc","getVault":"0x9403b634",
}

def rpc_batch(calls):
    payload=[]
    for i,(to,data) in enumerate(calls):
        payload.append({"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to,"data":data},BLOCK]})
    req=urllib.request.Request(RPC,data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"research"})
    for _ in range(4):
        try:
            r=json.load(urllib.request.urlopen(req,timeout=120)); break
        except Exception as e:
            print("retry",e,file=sys.stderr); time.sleep(3)
    else:
        raise RuntimeError("rpc failed")
    by={x["id"]:x for x in r}
    return [by[i].get("result") for i in range(len(calls))]

def dec(hexstr, fn):
    if not hexstr or hexstr=="0x": return None
    b=bytes.fromhex(hexstr[2:])
    if fn in ("name","symbol"):
        if len(b)<64: return None
        off=int.from_bytes(b[:32],"big"); ln=int.from_bytes(b[off:off+32],"big")
        return b[off+32:off+32+ln].decode(errors="replace")
    v=int.from_bytes(b[:32],"big")
    if fn in ("token","controller","governance","strategy","fulcrum","asset"):
        return "0x"+hex(v)[2:].rjust(40,"0")
    return v

# 1) registry vaults
r=rpc_batch([(REG,"0x44b19dfc")]); n=int(r[0],16)
res=rpc_batch([(REG,"0x9403b634"+format(i,'x').rjust(64,"0")) for i in range(n)])
registry=["0x"+x[-40:] for x in res if x and int(x,16)!=0]
vaults=registry+EXTRA

calls=[]; meta=[]
for v in vaults:
    for fn,sel in FUNCS.items():
        calls.append((v,sel)); meta.append((v,fn))
res=rpc_batch(calls)
state={}
for (v,fn),h in zip(meta,res):
    state.setdefault(v,{})[fn]=dec(h,fn)

# 2) controller strategies for registry vaults
CTRL="0x9E65Ad11b299CA0Abefc2799dDB6314Ef2d91080"
tokens=set()
for v in registry:
    t=state[v].get("token")
    if t: tokens.add(t)
calls=[(CTRL,"0x39ebf823"+t[2:].rjust(64,"0")) for t in tokens]
res=rpc_batch(calls)
strategies={t:("0x"+x[-40:] if x and x!="0x" and int(x,16)!=0 else None) for t,x in zip(tokens,res)}

# strategy balances
calls=[]; meta=[]
for t,s in strategies.items():
    if s:
        calls.append((s,"0x722713f7")); meta.append((s,"balanceOf"))
        calls.append((s,"0x1f1fcd51")); meta.append((s,"want"))
res=rpc_batch(calls)
strat_state={}
for (s,fn),h in zip(meta,res):
    strat_state.setdefault(s,{})[fn]=dec(h,fn) if fn=="want" else (int(h,16) if h and h!="0x" else None)

# 3) yPool
YPOOL="0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51"
calls=[(YPOOL,"0x065a80d8"+format(i,'x').rjust(64,"0")) for i in range(4)] # balances(int128)
res=rpc_batch(calls)
ypool={f"balances{i}": (int(x,16) if x and x!="0x" else None) for i,x in enumerate(res)}
calls=[(YPOOL,"0x23746eb8"+format(i,'x').rjust(64,"0")) for i in range(4)] # coins(int128)
res=rpc_batch(calls)
for i,x in enumerate(res):
    ypool[f"coin{i}"]=("0x"+x[-40:]) if x and x!="0x" else None

# 4) yETH system
YETH_POOL="0xCcd04073f4BdC4510927ea9Ba350875C3c65BF81"
STYETH="0x583019fF0f430721aDa9cfb4fac8F06cA104d0B4"
YETH="0x1BED97CBC3c24A4fb5C069C6E311a967386131f7"
YETH_CURVE="0x69ACcb968B19a53790f43e57558F5E443A91aF22"
calls=[(YETH_POOL,"0x5c975abb"),(YETH_POOL,"0x01e1d114"),(YETH,"0x18160ddd"),(STYETH,"0x01e1d114"),
       (STYETH,"0x38d52e0f"),(YETH_CURVE,"0x4903b0d1"),(YETH_CURVE,"0x4903b0d1"+format(1,'x').rjust(64,"0")),
       (YETH,"0x70a08231"+format(0x000000000004444c5dc75cb358380d2e3de08a90,'x').rjust(64,"0"))]
res=rpc_batch(calls)
yeth={
 "main_pool_paused": bool(int(res[0],16)) if res[0] and res[0]!="0x" else None,
 "yeth_token_supply": int(res[2],16) if res[2] and res[2]!="0x" else None,
 "styeth_total_assets": int(res[3],16) if res[3] and res[3]!="0x" else None,
 "styeth_asset": ("0x"+res[4][-40:]) if res[4] and res[4]!="0x" else None,
 "curve_pool_balances0": int(res[5],16) if res[5] and res[5]!="0x" else None,
 "curve_pool_balances1": int(res[6],16) if res[6] and res[6]!="0x" else None,
 "v4_manager_yeth": int(res[7],16) if res[7] and res[7]!="0x" else None,
}

out={"block":BLOCK,"rpc":RPC.split("?")[0],"registry_count":n,"vaults":state,
     "controller":CTRL,"strategies":strategies,"strategy_state":strat_state,
     "ypool":ypool,"yeth":yeth}
json.dump(out,open("ci-out/c31_state.json","w"),indent=1)
print("registry vaults:",n,"| all vaults:",len(vaults),"| strategies:",len([s for s in strategies.values() if s]))
print("yPool:",ypool)
print("yETH:",yeth)
PY

ls -la ci-out/

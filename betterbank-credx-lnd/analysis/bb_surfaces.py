#!/usr/bin/env python3
"""Decode the reward-state JSON into readable form + probe remaining value surfaces."""
import json, sys
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc, batch
from Crypto.Hash import keccak
URL = "https://rpc.pulsechain.com"
def k(s):
    h = keccak.new(digest_bits=256); h.update(s.encode()); return "0x" + h.hexdigest()
def sel(s): return k(s)[:10]
def b32(a): return a[2:].lower().rjust(64, '0')
def u(h):
    if not isinstance(h, str) or h == '0x': return None
    return int(h, 16)
def toaddr(i):
    if i is None: return None
    return "0x" + hex(i)[2:].rjust(40, '0')
def dec_str(hexstr):
    if not isinstance(hexstr, str) or hexstr == '0x': return None
    try:
        b = bytes.fromhex(hexstr[2:]); ln = int.from_bytes(b[32:64],'big'); return b[64:64+ln].decode()
    except Exception: return None

st = json.load(open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_reward_state.json'))
R = st['results']
WRAPPER="0x9361841a51bd90999fac8382abecf976273141f7"
REDEEMER="0x6bbc91c980780c393e9dac11ec58684191de611d"
FAVORS={"PDAIF":"0xbc91e5ae4ce07d0455834d52a9a4df992e12fe12","PLSF":"0x30be72a397667fdfd641e3e5bd68db657711eb20","PLSXF":"0x47c3038ad52e06b9b4aca6d672ff9ff39b126806"}
UNK=["0xff98af981c113488b91934e8af779194cc1b53ad","0xc8ccaec1e239c8591cbb8715bd0a43dd4c9cc95a","0xddbe64f89268026027d7823d1141846d546d6bac","0x2070ea9c18df743b3fdf37485fccc390a3694eb9","0xefd766ccb38eaf1dfd701853bfce31359239f305"]
print("=== wrapper owner:", toaddr(R.get(f"{WRAPPER}:owner()")), "router:", toaddr(R.get(f"{WRAPPER}:uniswapRouter()")))
for a in UNK:
    print("wrapper.isFavorToken", a, R.get(f"{WRAPPER}:isFavorToken(address)"))
print("=== redeemer priceOracles decoded:")
for n,a in FAVORS.items():
    print(" ", n, toaddr(R.get(f"{REDEEMER}:priceOracles(address)")))
print("oracle pair:", toaddr(R.get("0x5c717b63105b9ef7ea5b7b521581c23c7193fd88:pair()")))

# Now probe: favor token minters, treasuries, staking, redeemer balances, unknown token metadata
TREASURIES = {"FavorTreasuryPDAIF":"0x9aea2185b4cc1a8fd5034112bf8429b13932af2c","FavorTreasuryPLSF":"0x9361799b70fee9618d308190a8bf4b9fb63fc743","FavorTreasuryPLSXF":"0xd333e60789622bab2d448aaa18c06537fd65e3b5"}
STAKING = {"StakingPDAIF":"0x42e8ea9cfd8eaabb35e82322609ebd55bddb1f22","StakingPLSF":"0xd5c451660a5db203a143b6dd0a97e0112329aa8a","StakingPLSXF":"0xd809e3b3b939e79354e005e5ff1807830f1e0f3c"}
MISC = {"MinterOracle1":"0x766cbe8bee1a6bc5b15502fea2011683a402f3ec","MinterOracle2":"0xcd424ed62c18df5d15f23799091597c99406b700","Oracle":"0x5c717b63105b9ef7ea5b7b521581c23c7193fd88","LPZapper1":"0x26b7eb39bd506dfaaaa9f08d405f86764de6d3d5","LPZapper2":"0x59e7374f4c8bb8e73b9ac671655dc2d2bb73a648","EsteemOracleHelper1":"0xb4563182e15717c23784a57030095635a9ef428f","EsteemOracleHelper2":"0xdab8fd4415ffe1b49a35e8b97c9bf50b03fa36a8","EsteemOracleHelper3":"0xe1387ad4ef0f3a9ab3996022389c206b70bed573"}

calls=[]; labels=[]
def C(to,sig,*args):
    data=sel(sig)+"".join(b32(a) if isinstance(a,str) and a.startswith('0x') else hex(int(a))[2:].rjust(64,'0') for a in args)
    calls.append(("eth_call",[{"to":to,"data":data},"latest"])); labels.append((to,sig))
def S(to,sig,*args):
    data=sel(sig)+"".join(b32(a) if isinstance(a,str) and a.startswith('0x') else hex(int(a))[2:].rjust(64,'0') for a in args)
    calls.append(("eth_call",[{"to":to,"data":data},"latest"])); labels.append((to,sig))

ALL = {**TREASURIES, **STAKING, **MISC}
# native + key token balances for all protocol contracts
TOKENS = {"WPLS":"0xa1077a294dde1b09bb078844df40758a5d0f9a27","DAI":"0x6b175474e89094c44da98b954eedeac495271d0f","PLSX":"0x95b303987a60c71504d99aa1b13b4da07b0790ab","ESTEEM":"0xdbb8fd196e804d05bb8047dd3e91a9245b7819a7","PDAIF":"0xbc91e5ae4ce07d0455834d52a9a4df992e12fe12","PLSF":"0x30be72a397667fdfd641e3e5bd68db657711eb20","PLSXF":"0x47c3038ad52e06b9b4aca6d672ff9ff39b126806"}
for nm, ad in ALL.items():
    C(ad,"owner()")
    for tn, ta in TOKENS.items():
        C(ta,"balanceOf(address)",ad)
for nm, ad in UNK.items() if isinstance(UNK,dict) else []:
    pass
for ad in UNK:
    S(ad,"symbol()"); S(ad,"name()"); S(ad,"decimals()"); S(ad,"totalSupply()"); S(ad,"owner()")

res = batch(URL, calls)
out={"block": st['block'], "decoded": {}}
# re-associate
idx=0
for nm, ad in ALL.items():
    o = {}
    o["owner"] = toaddr(u(res[idx])); idx+=1
    for tn, ta in TOKENS.items():
        o[tn] = u(res[idx]); idx+=1
    out["decoded"][nm] = o
    print(f"\n{nm} {ad} owner={o['owner']}")
    for tn in TOKENS:
        if o[tn]: print(f"   {tn}: {o[tn]}")
unkout={}
for ad in UNK:
    d={}
    d["symbol"]=dec_str(res[idx]); idx+=1
    d["name"]=dec_str(res[idx]); idx+=1
    d["decimals"]=u(res[idx]); idx+=1
    d["totalSupply"]=u(res[idx]); idx+=1
    d["owner"]=toaddr(u(res[idx])); idx+=1
    unkout[ad]=d
    print("\nUNK", ad, d)
out["unknown_tokens"]=unkout
json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_surfaces.json','w'), indent=1)
print("\nsaved")

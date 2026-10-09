#!/usr/bin/env python3
"""C2-30 deeper checks: module accounts, outstanding rewards, authz, ETH pool, CEX books, osmosis pools."""
import json, subprocess, time, hashlib

UA="Mozilla/5.0 (X11; Linux x86_64) research"
def curl(url,t=30,post=None,headers=None):
    cmd=["curl","-s","--max-time",str(t),"-A",UA]
    if headers:
        for h in headers: cmd+=["-H",h]
    if post is not None:
        cmd+=["-X","POST","-H","Content-Type: application/json","-d",json.dumps(post)]
    cmd.append(url)
    for _ in range(2):
        o=subprocess.run(cmd,capture_output=True,text=True).stdout
        if o.strip(): return o
        time.sleep(1)
    return o
def jget(url,base=None):
    try: return json.loads(curl((base or "")+url))
    except Exception: return {"_err":True}

out={}
HLCD="https://api.humans.nodestake.org"

# 1. all module accounts + balances
mods=jget(f"{HLCD}/cosmos/auth/v1beta1/module_accounts?pagination.limit=200").get("accounts",[])
modbal={}
for m in mods:
    name=m.get("name"); addr=m.get("base_account",{}).get("address")
    b=jget(f"{HLCD}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200")
    modbal[name]={"addr":addr,"balances":b.get("balances")}
    print("module", name, addr, json.dumps(b.get("balances"))[:160])
out["module_accounts_full"]=modbal

# 2. outstanding rewards across bonded validators
st=json.load(open("raw/state.json"))
total_rew=0
rews={}
for v in st["validators_bonded"]:
    op=v["operator_address"]
    r=jget(f"{HLCD}/cosmos/distribution/v1beta1/validators/{op}/outstanding_rewards")
    amt=0
    for c in (r.get("rewards",{}).get("rewards") or []):
        if c["denom"]=="aheart": amt=float(c["amount"])
    rews[v["description"]["moniker"]]=amt
    total_rew+=amt
print("outstanding rewards sum (HEART):", total_rew/1e18)
out["outstanding_rewards_sum_aheart"]=total_rew
out["outstanding_rewards_by_val"]=rews

# 3. authz grants where gov is grantee/granter
gov="human10d07y265gmmuvt4z0w9aw880jnsr700jcdatdv"
out["authz_grantee_gov"]=jget(f"{HLCD}/cosmos/authz/v1beta1/grants/grantee/{gov}")
out["authz_granter_gov"]=jget(f"{HLCD}/cosmos/authz/v1beta1/grants/granter/{gov}")

# 4. Ethereum Uniswap V2 HEART/WETH pair
ETH="https://ethereum-rpc.publicnode.com"
HEART_ETH="0x8fAC8031E079F409135766C7D5De29cF22eF897c"
WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
def eth_call(to,data):
    payload={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data},"latest"]}
    r=json.loads(curl(ETH,post=payload))
    return r.get("result")
FACTORY="0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
sel="0xe6a43905"  # getPair(address,address)
pair=eth_call(FACTORY, sel+"000000000000000000000000"+HEART_ETH[2:].lower()+"000000000000000000000000"+WETH[2:].lower())
print("HEART/WETH pair:", pair)
if pair and pair!="0x"+ "0"*64:
    pa="0x"+pair[-40:]
    out["eth_pair"]=pa
    r0=eth_call(pa,"0x0902f1ac")  # getReserves
    print("getReserves:", r0)
    out["eth_pair_reserves_raw"]=r0
    tok0=eth_call(pa,"0x0dfe1681")
    out["eth_pair_token0"]=tok0
    # block
    bn=json.loads(curl(ETH,post={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}))
    out["eth_block"]=bn.get("result")
    print("eth block:", bn.get("result"))

# 5. KuCoin book retry
k=jget("https://api.kucoin.com/api/v1/market/orderbook/level2_100?symbol=HEART-USDT")
out["kucoin_book"]=k
print("kucoin:", json.dumps(k)[:400])

# 6. osmosis pools detail (1493 gamm, 2323 CL)
p1493=jget("https://lcd.osmosis.zone/osmosis/gamm/v1beta1/pools/1493")
out["osmo_pool_1493"]=p1493
print("pool1493:", json.dumps(p1493)[:500])
p2323=jget("https://lcd.osmosis.zone/osmosis/concentratedliquidity/v1beta1/pools/2323")
out["osmo_pool_2323"]=p2323
print("pool2323:", json.dumps(p2323)[:700])

json.dump(out, open("raw/deep_checks.json","w"), indent=1)
print("saved raw/deep_checks.json")

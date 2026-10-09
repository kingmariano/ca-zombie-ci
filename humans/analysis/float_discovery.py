#!/usr/bin/env python3
"""HEART IBC float discovery: humans-side escrows + remote-chain supply/pools."""
import json, hashlib, subprocess, time

UA="Mozilla/5.0 (X11; Linux x86_64) research"
def curl(url, timeout=30):
    for _ in range(2):
        out=subprocess.run(["curl","-s","--max-time",str(timeout),"-A",UA,url],capture_output=True,text=True).stdout
        if out.strip(): return out
        time.sleep(1)
    return out
def jget(url):
    try: return json.loads(curl(url))
    except Exception: return {"_error":True}

CHARSET="qpzry9x8gf2tvdw0s3jn54khce6mua7l"
def polymod(values):
    gen=[0x3b6a57b2,0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3]; chk=1
    for v in values:
        b=chk>>25; chk=((chk&0x1ffffff)<<5)^v
        for i in range(5):
            if (b>>i)&1: chk^=gen[i]
    return chk
def hrp_expand(hrp): return [ord(x)>>5 for x in hrp]+[0]+[ord(x)&31 for x in hrp]
def bech32(hrp,data):
    pm=polymod(hrp_expand(hrp)+data+[0]*6)^1
    cs=[(pm>>5*(5-i))&31 for i in range(6)]
    return hrp+"1"+"".join(CHARSET[d] for d in data+cs)
def conv(data,fb,tb,pad=True):
    acc=bits=0; ret=[]; maxv=(1<<tb)-1
    for v in data:
        acc=(acc<<fb)|v; bits+=fb
        while bits>=tb:
            bits-=tb; ret.append((acc>>bits)&maxv)
    if pad and bits: ret.append((acc<<(tb-bits))&maxv)
    return ret
def addr(hrp, name):
    h=hashlib.sha256(name.encode()).digest()[:20]
    return bech32(hrp, conv(list(h),8,5))

out={}
# humans-side escrow per channel
escrows={}
for ch in range(5):
    a=addr("human", f"transfer/channel-{ch}")
    b=jget(f"https://api.humans.nodestake.org/cosmos/bank/v1beta1/balances/{a}")
    escrows[f"channel-{ch}"]={"escrow":a,"balances":b.get("balances")}
    print("humans escrow", ch, a, b.get("balances"))
out["humans_escrows"]=escrows

# remote side denoms
denoms={
 "osmosis-1": {"channel-15750":"ibc/DB3CE83F4195CF2186F6FE114457A98139CA9ADC25A6AB317C727810BFDDFCA2",
               "channel-18272":"ibc/6D38DD1975F99150A2379E88F3F32D6191C33D5035203451493CFB041A5AE013",
               "channel-20082":"ibc/35CECC330D11DD00FACB555D07687631E0BC7D226260CC5F015F6D7980819533"},
 "fetchhub-4": {"channel-32":"ibc/E6A255BBE29AC5DF529DD261310989EA4E6A364BEB46A19C387A036CDFC27919"},
 "cosmoshub-4": {"channel-788":"ibc/E7EC1FC708930A434E95095023855A79B7C1DEDE4979624FE086CA9ECA84CD13"},
}
out["remote_supply"]={}
for chain,chans in denoms.items():
    base={"osmosis-1":"https://lcd.osmosis.zone","fetchhub-4":"https://rest-fetchhub.fetch.ai","cosmoshub-4":"https://cosmos-rest.publicnode.com"}[chain]
    for ch,den in chans.items():
        d=jget(f"{base}/cosmos/bank/v1beta1/supply/by_denom?denom={den}")
        out["remote_supply"][f"{chain}/{ch}"]=d.get("amount")
        print(chain, ch, "supply:", d.get("amount"))

# osmosis pools containing any HEART denom
osmo_pools=jget("https://lcd.osmosis.zone/osmosis/poolmanager/v1beta1/all-pools?pagination.limit=8000")
pools=osmo_pools.get("pools",[])
print("osmosis pools total:", len(pools))
heart_denoms=set(denoms["osmosis-1"].values())
hits=[]
for p in pools:
    s=json.dumps(p)
    for d in heart_denoms:
        if d in s:
            hits.append(p); break
print("HEART pools on osmosis:", len(hits))
out["osmosis_heart_pools"]=hits
json.dump(out, open("raw/float.json","w"), indent=1)
for p in hits:
    print(json.dumps({k:p.get(k) for k in ("@type","id","address","pool_params") if k in p})[:400])
    if p.get("@type","").endswith("Pool"):
        print("  denoms:", [ (c.get("token",{}).get("denom"), c.get("token",{}).get("amount")) for c in p.get("pool_assets",[]) ] or [p.get("token0",{}).get("denom"), p.get("token1",{}).get("denom")])

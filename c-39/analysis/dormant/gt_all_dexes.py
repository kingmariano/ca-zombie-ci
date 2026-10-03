#!/usr/bin/env python3
"""Pull top pools for all PulseChain venues from GeckoTerminal (rate-limit safe)."""
import json, time, urllib.request, os
D = os.path.dirname(os.path.abspath(__file__))
dexs = ["pulsex","pulsex-v2","9mm-v2","9mm-v3","phux","9inch","sparkswap","eazyswap",
        "velocimeter-pulsechain","wizardswap-pulsechain","dextop","pulsegun","function-island",
        "liberty-swap","finvesta","pdex-vision","pulse-rate"]
out={}
for dex in dexs:
    pools=[]
    for page in (1,2):
        url=f"https://api.geckoterminal.com/api/v2/networks/pulsechain/dexes/{dex}/pools?page={page}"
        for attempt in range(3):
            try:
                req=urllib.request.Request(url,headers={"Accept":"application/json","User-Agent":"Mozilla/5.0"})
                with urllib.request.urlopen(req,timeout=30) as r:
                    j=json.loads(r.read())
                for x in j.get("data",[]):
                    a=x["attributes"]
                    pools.append({"address":a.get("address"),"name":a.get("name"),
                                  "reserve_usd":a.get("reserve_in_usd"),
                                  "vol24":(a.get("volume_usd") or {}).get("h24"),
                                  "created":a.get("pool_created_at")})
                break
            except Exception as e:
                time.sleep(4)
        time.sleep(2.4)
    out[dex]=pools
    tot=sum(float(p["reserve_usd"] or 0) for p in pools)
    print(f"{dex:26s} pools={len(pools):3d} top-reserve-sum=${tot:,.0f}", flush=True)
json.dump(out,open(os.path.join(D,"gt_all_dexes.json"),"w"),indent=1)

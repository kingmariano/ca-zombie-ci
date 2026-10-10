#!/usr/bin/env python3
import json, urllib.request, time, sys, datetime
BASE="https://api.koios.rest/api/v1"
addr="addr1z8snz7c4974vzdpxu65ruphl3zjdvtxw8strf2c2tmqnxz2j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq0xmsha"
def koios(endpoint, body, retries=8, timeout=600):
    url=f"{BASE}/{endpoint}"; data=json.dumps(body).encode()
    for i in range(retries):
        try:
            req=urllib.request.Request(url, data=data, method="POST", headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r: return json.loads(r.read().decode())
        except Exception as e:
            print(datetime.datetime.now().isoformat(), "retry",i,e,file=sys.stderr, flush=True); time.sleep(3*(i+1))
    return None
tip=koios("tip", {})
res=koios("address_info", {"_addresses":[addr]})
if res is not None:
    out={"queried_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"tip":tip,"response":res}
    json.dump(out, open("v1_pool_address_info.json","w"))
    a=res[0]
    print("OK balance", a["balance"], "utxos", len(a.get("utxo_set",[])), flush=True)
else:
    print("FAILED", flush=True)

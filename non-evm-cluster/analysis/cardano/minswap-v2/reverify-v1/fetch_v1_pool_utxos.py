#!/usr/bin/env python3
"""Fetch all UTxOs at the Minswap V1 pool address (paged), index by asset names, for top-3 pool verification."""
import json, urllib.request, time, sys

POOL_ADDR = "addr1z8snz7c4974vzdpxu65ruphl3zjdvtxw8strf2c2tmqnxz2j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq0xmsha"
BASE = "https://api.koios.rest/api/v1"

def koios_utxos(addr, offset, limit=1000, retries=7):
    url = f"{BASE}/address_utxos?limit={limit}&offset={offset}"
    data = json.dumps({"_addresses": [addr], "_extended": False}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=data, method="POST", headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=180) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print("retry", i, e, file=sys.stderr); time.sleep(2*(i+1))
    return None

allu = []
for off in range(0, 8000, 1000):
    res = koios_utxos(POOL_ADDR, off)
    if res is None:
        print("FAILED at", off); break
    print("offset", off, "->", len(res))
    allu.extend(res)
    if len(res) < 1000: break
    time.sleep(1)

json.dump(allu, open("v1_pool_utxos_all.json", "w"))
print("total UTxOs fetched:", len(allu))
tot = sum(int(u["value"]) for u in allu)
print("total lovelace:", tot, "=", tot/1e6, "ADA")
print("unspent:", sum(1 for u in allu if not u.get("is_spent")))

# index by asset token names
idx = {}
for u in allu:
    for a in u.get("asset_list") or []:
        key = (a["policy_id"], a["asset_name"])
        idx.setdefault(key, []).append(u)
json.dump({f"{p}.{n}": [u["tx_hash"]+"#"+str(u["tx_index"]) for u in v] for (p,n),v in idx.items()},
          open("v1_pool_utxos_by_asset.json", "w"), indent=1)
print("distinct assets:", len(idx))

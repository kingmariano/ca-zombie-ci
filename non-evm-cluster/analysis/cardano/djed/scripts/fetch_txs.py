#!/usr/bin/env python3
"""Fetch bank tx info + address_txs for pool/order + check one-shot UTxO 362e24ab..."""
import json, sys, time, urllib.request

BASE = "https://api.koios.rest/api/v1"
def koios(endpoint, body, query="", retries=7):
    url = f"{BASE}/{endpoint}{query}"
    data = json.dumps(body).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=data, method="POST", headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print("retry", i, e, file=sys.stderr); time.sleep(2*(i+1))
    return None

ai = json.load(open("koios_address_info.json"))
pool = [a for a in ai["response"] if a["address"].startswith("addr1z8mcpc26")][0]
order = [a for a in ai["response"] if a["address"].startswith("addr1wypp5vhw")][0]

pool_hashes = [u["tx_hash"] for u in pool["utxo_set"]]
res = koios("tx_info", {"_tx_hashes": pool_hashes})
json.dump(res, open("koios_bank_tx_info.json", "w"), indent=1)
print("bank creation txs:", [(t["tx_hash"][:20], t["block_height"]) for t in res])

res2 = koios("address_txs", {"_addresses": [pool["address"], order["address"]]}, "?limit=40&order=desc")
json.dump(res2, open("koios_pool_order_txs.json", "w"), indent=1)
print("address txs:", len(res2))
for t in res2[:40]:
    print(t["tx_hash"][:20], t["block_height"], t["block_time"])

# one-shot UTxO from policy constant 362e24ab3b1aacf8108c52aec7ddc6c2e007fef3c3a125eebe849a0be4203902#0
res3 = koios("tx_info", {"_tx_hashes": ["362e24ab3b1aacf8108c52aec7ddc6c2e007fef3c3a125eebe849a0be4203902"]})
if res3 is not None:
    json.dump(res3, open("koios_oneshot_tx_info.json", "w"), indent=1)
    for t in res3:
        print("oneshot tx", t["tx_hash"][:20], "bh", t["block_height"], "time", t["block_time"], "outputs", [(o.get("tx_hash","")[:12], o["output_index"], o["value"]) for o in t.get("outputs",[])][:5])

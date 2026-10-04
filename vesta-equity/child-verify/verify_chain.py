#!/usr/bin/env python3
"""Read-only indexer checks for Vesta Equity H-23 verification. No tx submission."""
import json, base64, urllib.request, urllib.parse, time, sys

IDX = "https://mainnet-idx.algonode.cloud"
RQI = "RQIQQIHYGFF4NR5ODLSYMK5EGETHCYZT2YDAILPW4MNEBF4OUTJTMWDSOI"
ESCROWS = [
 "3JMMSUISULB5JGEKBG654UVBXTH5UEEFDZWO5XLJUCTHPYUS6CUEGIBHYU",
 "CWNSUHA2IC4I3SL67H5UI7OV2ZWMLGBKI32RX2RDQ75BXGUVFKVW32TONU",
 "FCGL5AJEC5WGM7VHBLL5WXGHSM3HCLHJD4WYSZW3H5KVYZT6EU2Z7PQSEY",
 "FJMNV6SXJWJXMPMUOLASTHFW3OCW5ZGWLZTISVVD7ZN3ICPH4XFQVTKIDQ",
 "IQXC57YUU2DEXYW6L2KA4HIKUPXXOP7AOPKJPG24RZQTEWRI3RHQUCYI2Q",
 "LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY",
 "PJRCTS5SB7773PGKWF2IRYQX5WVO5CLSVQ236AZF72LDHQMA52ALDBCUFM",
 "VYC7JZCMQ5OW2XO3ZJML4MWTZSV2MTSQ4K64TMRXVJDMRGVPTKHL6NQALY",
]

def get(path, params=None):
    url = IDX + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    for attempt in range(6):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.load(r)
        except Exception as e:
            if attempt == 5:
                sys.stderr.write("FAILED URL: %s\nERROR: %r\n" % (url, e))
                try:
                    sys.stderr.write("BODY: %r\n" % e.read()[:500])
                except Exception:
                    pass
                raise
            time.sleep(2.0 + attempt)

out = {"indexer": IDX, "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

# ---------- Task 3: locate the two historical drain groups ----------
task3 = {}
for addr, name in [("3JMMSUISULB5JGEKBG654UVBXTH5UEEFDZWO5XLJUCTHPYUS6CUEGIBHYU","3JMM"),
                   ("CWNSUHA2IC4I3SL67H5UI7OV2ZWMLGBKI32RX2RDQ75BXGUVFKVW32TONU","CWN")]:
    data = get(f"/v2/accounts/{addr}/transactions", {"limit":100})
    txs = data["transactions"]
    task3[name] = []
    for t in txs:
        sig = t.get("signature",{}).get("logicsig")
        if not sig: continue
        args = [base64.b64decode(a).decode("utf-8","replace") for a in sig.get("args",[])]
        tx = {"id": t["id"], "round": t["confirmed-round"], "tx-type": t["tx-type"], "group": t.get("group"),
              "sender": t.get("sender"), "args": args, "fee": t.get("fee"),
              "group-size-reported:" if False else "note": None}
        if t["tx-type"]=="axfer":
            a=t["asset-transfer-transaction"]; tx["axfer"]={"asset-id":a.get("asset-id"),"amount":a.get("amount"),"receiver":a.get("receiver"),"close-to":a.get("close-to"),"close-amount":a.get("close-amount"),"sender":a.get("sender")}
        elif t["tx-type"]=="pay":
            p=t["payment-transaction"]; tx["pay"]={"amount":p.get("amount"),"receiver":p.get("receiver"),"close-remainder-to":p.get("close-remainder-to"),"close-amount":p.get("close-amount")}
        task3[name].append(tx)
out["task3_escrow_txs"] = task3

# fetch the two full group rounds to confirm group size == 3
rounds = {}
for rnd in [28242472, 27910878]:
    try:
        b = get(f"/v2/blocks/{rnd}")
        txs = b.get("transactions",[])
        simple = []
        for t in txs:
            sig = t.get("signature",{}).get("logicsig")
            entry = {"id": t["id"], "tx-type": t["tx-type"], "sender": t.get("sender"), "group": t.get("group")}
            if sig:
                entry["lsig-args"] = [base64.b64decode(a).decode("utf-8","replace") for a in sig.get("args",[])]
                entry["lsig-logic-sha_b64"] = base64.b64encode(__import__("hashlib").sha512_256(base64.b64decode(sig["logic"])).digest()).decode()
            if t["tx-type"]=="axfer":
                a=t["asset-transfer-transaction"]; entry["axfer"]={"asset-id":a.get("asset-id"),"amount":a.get("amount"),"receiver":a.get("receiver"),"close-to":a.get("close-to"),"close-amount":a.get("close-amount")}
            if t["tx-type"]=="pay":
                p=t["payment-transaction"]; entry["pay"]={"amount":p.get("amount"),"receiver":p.get("receiver"),"close-remainder-to":p.get("close-remainder-to"),"close-amount":p.get("close-amount")}
            simple.append(entry)
        rounds[str(rnd)] = {"num-txns": len(txs), "transactions": simple, "group_ids": list({t.get("group") for t in txs if t.get("group")})}
    except Exception as e:
        rounds[str(rnd)] = {"error": str(e)}
out["task3_rounds"] = rounds

# ---------- Task 5: created applications ----------
apps = {}
for addr in [RQI] + ESCROWS:
    d = get(f"/v2/accounts/{addr}/created-applications", {"limit":100})
    apps[addr] = {"total": d.get("total-applications", d.get("total", len(d.get("applications",[])))), "apps": [{"id":a.get("id"),"params-creator":a.get("params",{}).get("creator")} for a in d.get("applications",[])]}
out["task5_created_apps"] = apps

# ---------- Task 6: RQI payment receivers -> any lsig? ----------
rqi_txs = []
next_tok = None
pages = 0
while pages < 5:
    params = {"limit":100}
    if next_tok: params["next"] = next_tok
    d = get(f"/v2/accounts/{RQI}/transactions", params)
    rqi_txs.extend(d["transactions"])
    next_tok = d.get("next-token")
    pages += 1
    if not next_tok: break
receivers = sorted({t["payment-transaction"]["receiver"] for t in rqi_txs if t["tx-type"]=="pay" and t.get("payment-transaction",{}).get("receiver")})
out["task6_rqi_tx_count_fetched"] = len(rqi_txs)
out["task6_distinct_pay_receivers"] = receivers
lsig_found = {}
for addr in receivers:
    d = get(f"/v2/accounts/{addr}/transactions", {"sig-type":"lsig","limit":1})
    lsig_found[addr] = {"lsig_tx_count_returned": len(d.get("transactions",[])), "sample_id": d["transactions"][0]["id"] if d.get("transactions") else None}
out["task6_receiver_lsig_check"] = lsig_found

# also explicitly check the 8 escrows + RQI for lsig usage (sanity)
for addr in [RQI]+ESCROWS:
    d = get(f"/v2/accounts/{addr}/transactions", {"sig-type":"lsig","limit":1})
    out.setdefault("task6_self_lsig", {})[addr] = len(d.get("transactions",[]))

json.dump(out, open("raw.json","w"), indent=1)
print("RQI txs fetched:", len(rqi_txs), "distinct pay receivers:", len(receivers))
print("escrow tx summary:")
for name, txs in task3.items():
    print(" ", name, len(txs), "txs")
    for t in txs:
        if t["args"] and "reject" in t["args"]:
            print("   REJECT tx:", t["id"], "round", t["round"], t["tx-type"], json.dumps({k:v for k,v in t.items() if k in ("axfer","pay")}))
print("rounds:")
for r,v in rounds.items():
    print(" round", r, "num-txns", v.get("num-txns"), "groups", v.get("group_ids"))
print("apps:", {k:(v["total"] if isinstance(v,dict) else v) for k,v in apps.items()})
print("receivers:", len(receivers))
print("any receiver with lsig:", {k:v for k,v in lsig_found.items() if v["lsig_tx_count_returned"]>0})
print("self lsig:", out["task6_self_lsig"])

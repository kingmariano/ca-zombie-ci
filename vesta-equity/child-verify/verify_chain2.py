#!/usr/bin/env python3
"""Read-only indexer/algod checks for Vesta Equity H-23 verification. No tx submission."""
import json, base64, hashlib, urllib.request, urllib.parse, time, sys, os

IDX = "https://mainnet-idx.algonode.cloud"
ALGOD = "https://mainnet-api.algonode.cloud"
RQI = "RQIQQIHYGFF4NR5ODLSYMK5EGETHCYZT2YDAILPW4MNEBF4OUTJTMWDSOI"
# Escrow addresses; VYC corrected from chain data (parent context had ZJ/JZ transposition)
ESCROWS = [
 "3JMMSUISULB5JGEKBG654UVBXTH5UEEFDZWO5XLJUCTHPYUS6CUEGIBHYU",
 "CWNSUHA2IC4I3SL67H5UI7OV2ZWMLGBKI32RX2RDQ75BXGUVFKVW32TONU",
 "FCGL5AJEC5WGM7VHBLL5WXGHSM3HCLHJD4WYSZW3H5KVYZT6EU2Z7PQSEY",
 "FJMNV6SXJWJXMPMUOLASTHFW3OCW5ZGWLZTISVVD7ZN3ICPH4XFQVTKIDQ",
 "IQXC57YUU2DEXYW6L2KA4HIKUPXXOP7AOPKJPG24RZQTEWRI3RHQUCYI2Q",
 "LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY",
 "PJRCTS5SB7773PGKWF2IRYQX5WVO5CLSVQ236AZF72LDHQMA52ALDBCUFM",
 "VYC7JZCMQ5OW2XO3JZML4MWTZSV2MTSQ4K64TMRXVJDMRGVPTKHL6NQALY",
]

def get(base, path, params=None, tries=6):
    url = base + path + ("?" + urllib.parse.urlencode(params) if params else "")
    for a in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.load(r)
        except Exception as e:
            if a == tries-1:
                sys.stderr.write("FAILED %s : %r\n" % (url, e))
                raise
            time.sleep(1.5 + a)

def save(name, obj):
    with open(name, "w") as f:
        json.dump(obj, f, indent=1)
    print("saved", name)

# ---------- Task 2: LGWHT balances (indexer account + algod account + asset balances) ----------
t2 = {}
t2["indexer_account"] = get(IDX, f"/v2/accounts/LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY")
try:
    t2["algod_account"] = get(ALGOD, f"/v2/accounts/LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY")
except Exception as e:
    t2["algod_account_error"] = repr(e)
# asset 31566704 balances, restricted to large holders; search pages for LGWHT
found = None
tok = None
for page in range(10):
    p = {"currency-greater-than": 74999999, "limit": 1000}
    if tok: p["next"] = tok
    try:
        d = get(IDX, "/v2/assets/31566704/balances", p, tries=3)
    except Exception as e:
        t2["asset_balances_error_page_"+str(page)] = repr(e); break
    for b in d.get("balances", []):
        if b.get("address") == "LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY":
            found = b
    tok = d.get("next-token")
    t2["asset_balances_pages_fetched"] = page+1
    t2["asset_balances_page_%d_n" % page] = len(d.get("balances", []))
    if found or not tok: break
t2["LGWHT_usdc_balance_entry"] = found
t2["LGWHT_usdc_balance_endpoint"] = IDX + "/v2/assets/31566704/balances?currency-greater-than=74999999"
save("task2_balances.json", t2)

# ---------- Task 3: historical drain rounds ----------
t3 = {}
t3["escrow_logicsig_txs"] = {}
for addr, name in [(ESCROWS[0], "3JMM"), (ESCROWS[1], "CWN"), (ESCROWS[5], "LGWHT")]:
    d = get(IDX, f"/v2/accounts/{addr}/transactions", {"limit":100})
    rows = []
    for t in d["transactions"]:
        sig = t.get("signature", {}).get("logicsig")
        if not sig: continue
        row = {"id": t["id"], "round": t["confirmed-round"], "tx-type": t["tx-type"],
               "group": t.get("group"), "sender": t.get("sender"), "fee": t.get("fee"),
               "args": [base64.b64decode(a).decode("utf-8","replace") for a in sig.get("args",[])],
               "logic_sha512_256_hex": hashlib.new("sha512_256", base64.b64decode(sig["logic"])).hexdigest()}
        if t["tx-type"]=="axfer":
            a=t["asset-transfer-transaction"]; row["axfer"]={"asset-id":a.get("asset-id"),"amount":a.get("amount"),"receiver":a.get("receiver"),"close-to":a.get("close-to"),"close-amount":a.get("close-amount")}
        if t["tx-type"]=="pay":
            p=t["payment-transaction"]; row["pay"]={"amount":p.get("amount"),"receiver":p.get("receiver"),"close-remainder-to":p.get("close-remainder-to"),"close-amount":p.get("close-amount")}
        rows.append(row)
    t3["escrow_logicsig_txs"][name] = rows
t3["rounds"] = {}
for rnd in [28242472, 27910878]:
    try:
        b = get(IDX, f"/v2/blocks/{rnd}")
        txs = b.get("transactions", [])
        simple = []
        for t in txs:
            sig = t.get("signature", {}).get("logicsig")
            entry = {"id": t["id"], "tx-type": t["tx-type"], "sender": t.get("sender"), "group": t.get("group"),
                     "fee": t.get("fee"), "first-valid": t.get("first-valid"), "last-valid": t.get("last-valid")}
            if sig:
                entry["lsig-args"] = [base64.b64decode(a).decode("utf-8","replace") for a in sig.get("args",[])]
                entry["lsig-logic-sha512_256-hex"] = hashlib.new("sha512_256", base64.b64decode(sig["logic"])).hexdigest()
            if t["tx-type"]=="axfer":
                a=t["asset-transfer-transaction"]; entry["axfer"]={"asset-id":a.get("asset-id"),"amount":a.get("amount"),"receiver":a.get("receiver"),"close-to":a.get("close-to"),"close-amount":a.get("close-amount")}
            if t["tx-type"]=="pay":
                p=t["payment-transaction"]; entry["pay"]={"amount":p.get("amount"),"receiver":p.get("receiver"),"close-remainder-to":p.get("close-remainder-to"),"close-amount":p.get("close-amount")}
            simple.append(entry)
        t3["rounds"][str(rnd)] = {"num-txns": len(txs), "txns": simple,
                                  "group_ids": sorted({t.get("group") for t in txs if t.get("group")})}
    except Exception as e:
        t3["rounds"][str(rnd)] = {"error": repr(e)}
save("task3_rounds.json", t3)

# ---------- Task 5: balances + created apps for RQI and escrows + 5 sampled receivers ----------
recv = json.load(open("tmp_rqi_receivers.json"))["receivers"]
# sample receivers deterministically: 5 spread across list
sample_idx = [0, len(recv)//4, len(recv)//2, 3*len(recv)//4, len(recv)-1]
sampled = [recv[i] for i in sample_idx]
t5 = {"sampled_receivers": sampled, "accounts": {}, "created_applications": {}}
all_addrs = [RQI] + ESCROWS + sampled
for addr in all_addrs:
    try:
        acct = get(IDX, f"/v2/accounts/{addr}")
        a = acct.get("account", {})
        t5["accounts"][addr] = {
            "amount_microalgos": a.get("amount"),
            "status": a.get("status"),
            "total-txns": a.get("total-txns"),
            "assets": [{"asset-id": x.get("asset-id"), "amount": x.get("amount"), "is-frozen": x.get("is-frozen")}
                       for x in a.get("assets", [])],
            "apps-local-state": len(a.get("apps-local-state", [])),
            "total-apps-created": a.get("total-apps-created"),
            "created-assets": len(a.get("created-assets", [])),
        }
    except Exception as e:
        t5["accounts"][addr] = {"error": repr(e)}
    try:
        apps = get(IDX, f"/v2/accounts/{addr}/created-applications", {"limit":100})
        t5["created_applications"][addr] = {
            "total-applications": apps.get("total-applications"),
            "applications_returned": len(apps.get("applications", [])),
            "current-round": apps.get("current-round"),
        }
    except Exception as e:
        t5["created_applications"][addr] = {"error": repr(e)}
save("task5_apps_balances.json", t5)

# ---------- Task 6: any other lsig accounts among RQI pay receivers? ----------
t6 = {"receiver_count": len(recv), "lsig_users": {}, "errors": {}}
if os.path.exists("task6_lsig_receivers.json"):
    t6 = json.load(open("task6_lsig_receivers.json"))
done = set(t6["lsig_users"].keys()) | set(t6.get("checked_no_lsig", []))
for i, addr in enumerate(recv):
    if addr in done: continue
    try:
        d = get(IDX, f"/v2/accounts/{addr}/transactions", {"sig-type":"lsig","limit":1}, tries=3)
        if d.get("transactions"):
            t6["lsig_users"][addr] = {"sample_txid": d["transactions"][0]["id"],
                                      "round": d["transactions"][0]["confirmed-round"],
                                      "senders": d["transactions"][0].get("sender")}
        else:
            t6.setdefault("checked_no_lsig", []).append(addr)
    except Exception as e:
        t6["errors"][addr] = repr(e)
    if (i+1) % 40 == 0:
        save("task6_lsig_receivers.json", t6)
    time.sleep(0.12)
save("task6_lsig_receivers.json", t6)

print("=== SUMMARY ===")
print("T2 LGWHT:", json.dumps({k:v for k,v in t2.items() if k in ("LGWHT_usdc_balance_entry","asset_balances_pages_fetched")}))
print("T3 reject txs:")
for name, rows in t3["escrow_logicsig_txs"].items():
    for r in rows:
        if "reject" in r["args"]:
            print(" ", name, r["id"], "round", r["round"], r["tx-type"], json.dumps(r.get("axfer") or r.get("pay")))
print("T3 rounds group ids:", {k: v.get("group_ids") for k,v in t3["rounds"].items()})
print("T5 apps totals:", {k: v.get("total-applications") for k,v in t5["created_applications"].items()})
print("T5 escrow balances:", {k: v.get("amount_microalgos") for k,v in t5["accounts"].items() if k in ESCROWS})
print("T6 receivers:", len(recv), "lsig users:", list(t6["lsig_users"].keys()), "errors:", len(t6["errors"]))

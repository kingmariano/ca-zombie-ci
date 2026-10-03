"""Spot-check: surviving token approvals to the (now MySwapLegacy) core from sunset distribution recipients."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from starknet_nodep import rpc, call, sel, norm, u256, hexint  # noqa

CORE = "0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28"
ETH = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
USDC = "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8"
TX = "0x33f2f3c41a6c33caf3fa3d8409fef8ad47894313a3a0ffdbf420283a3f895f8"

out = {"tx": TX, "core": CORE, "sample": []}
receipt = rpc("starknet_getTransactionReceipt", [TX])
transfer_sel = sel("Transfer")
recipients = []
for ev in receipt.get("events", []):
    if ev.get("from_address", "").lower().endswith(ETH[-20:].lower()):
        keys = ev.get("keys", [])
        data = ev.get("data", [])
        if keys and int(keys[0], 16) == int(transfer_sel, 16) and len(data) >= 2:
            to = norm(data[1])  # Cairo0 event: data = [from, to, value.low, value.high]
            if to != norm(CORE):
                recipients.append(to)
    if len(recipients) >= 5:
        break
print("sampled recipients:", recipients)

for who in recipients:
    row = {"owner": who}
    for name, tok in [("ETH", ETH), ("USDC", USDC)]:
        try:
            r = call(tok, "allowance", [who, CORE])
            row[name] = str(u256(r))
        except Exception as e:
            row[name] = f"ERR {e}"
    out["sample"].append(row)
    print(row)

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "approvals_sample.json"), "w") as f:
    json.dump(out, f, indent=1)
print("wrote approvals_sample.json")

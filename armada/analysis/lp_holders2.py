#!/usr/bin/env python3
"""LP holders via getProgramAccounts on SPL Token (memcmp mint, dataSlice owner+amount)."""
import sys, json, base64
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *
r1 = json.load(open("/home/heisenberg/CA/armada/analysis/recon1.json"))
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
out = {}
for vk, v in r1["vaults"].items():
    m = v["lp_mint"]
    try:
        accs = rpc("getProgramAccounts", [TOKEN, {"encoding": "base64",
                   "filters": [{"memcmp": {"offset": 0, "bytes": m}}],
                   "dataSlice": {"offset": 32, "length": 40}}], timeout=60)
    except Exception as e:
        out[vk] = {"err": redact(e)[:120]}
        print(vk[:8], "ERR", redact(e)[:80], flush=True)
        continue
    holders = []
    for a in accs or []:
        raw = base64.b64decode(a["account"]["data"][0])
        owner = b58encode(raw[0:32]); amt = int.from_bytes(raw[32:40], "little")
        if amt > 0:
            holders.append({"owner": owner, "amount": amt, "ata": a["pubkey"]})
    holders.sort(key=lambda x: -x["amount"])
    out[vk] = {"lp_mint": m, "holders": len(holders), "top": holders[:8]}
    print(vk[:8], "holders:", len(holders), "top:", [(h["owner"][:10], h["amount"]) for h in holders[:3]], flush=True)
json.dump(out, open("/home/heisenberg/CA/armada/analysis/recon6_lpholders.json", "w"), indent=1)
print("DONE")

#!/usr/bin/env python3
"""Find currently-staked veNFTs in a GaugeCL by scanning Deposit events and probing earned()."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hl_rpc as h
from logs_es import get_logs

GAUGE = sys.argv[1] if len(sys.argv) > 1 else "0x382e5db8ec64e8506879b94568b41d159d64577f"
TOPIC_DEPOSIT = "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c"

def call_from(to, data, frm, block="latest"):
    import urllib.request
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": to, "data": data, "from": frm}, block]}).encode()
    req = urllib.request.Request("https://rpc.hyperliquid.xyz/evm", data=body,
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        out = json.loads(r.read())
    if "result" in out:
        return ("OK", out["result"])
    return ("ERR", out.get("error", {}).get("message", ""))

def enc(sig, args=()):
    data = h.enc_sel(sig)
    for a in args:
        data += f"{a:064x}"
    return data

d = get_logs(GAUGE, TOPIC_DEPOSIT, page=1, offset=1000)
logs = d.get("result") or []
print("deposit logs:", len(logs))
found = []
for r in reversed(logs):
    user = "0x" + r["topics"][1][-40:]
    tid = int(r["data"], 16)
    st, out = call_from(GAUGE, enc("earned(uint256)", (tid,)), user)
    if st == "OK":
        found.append({"user": user, "tokenId": tid, "earned": int(out, 16), "block": int(r["blockNumber"], 16)})
        if len(found) >= 10:
            break
print(json.dumps(found, indent=1))
json.dump(found, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "staked_sample.json"), "w"), indent=1)

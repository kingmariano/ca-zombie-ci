#!/usr/bin/env python3
"""Cross-check the suspicious balances with direct (non-batched) calls on two RPCs."""
import json
import urllib.request

PAIRS = {
    "atLUNA/xLUNA": ("0x6a6ef3b7879f949c61c453a8e334c080ea873fd7",
                     [("0xc4bdd27c33ec7daa6fcfd8532ddb524bf4038096", "atLUNA"),
                      ("0xe24c7f50a9f514db6ccf151ff9a9411de2110740", "xLUNA")]),
    "PLRS/xLUNA": ("0x96b92827b75fa5f4e0cf5b0ff4c86e8fc4611bc8",
                   [("0x631edd14bb0b2505c91176feedc5f082d27dd5b8", "PLRS"),
                    ("0xe24c7f50a9f514db6ccf151ff9a9411de2110740", "xLUNA")]),
    "xNEAR/wNEAR": ("0x05692a796eeae39b48f0ca935b5ef3a22d905623",
                    [("0xb9636d074c3e8550449feba3be63fe95a582e876", "xNEAR"),
                     ("0xc42c30ac6cc15fac9bd938618bcaa1a1fae8501d", "wNEAR")]),
    "xNEAR/xLUNA": ("0x0a980ff91cd89205a0c96517ed150635fdcc224a",
                    [("0xb9636d074c3e8550449feba3be63fe95a582e876", "xNEAR"),
                     ("0xe24c7f50a9f514db6ccf151ff9a9411de2110740", "xLUNA")]),
}


def call(rpc, to, data):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]}
    req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r).get("result")


def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")


for rpc in ["https://mainnet.aurora.dev", "https://aurora.drpc.org"]:
    print("=== RPC:", rpc)
    for name, (pair, toks) in PAIRS.items():
        res = call(rpc, pair, "0x0902f1ac")  # getReserves
        raw = (res or "0x")[2:]
        r0 = int(raw[0:64] or "0", 16)
        r1 = int(raw[64:128] or "0", 16)
        line = f"{name} pair={pair[:10]} res0={r0} res1={r1}"
        for t, sym in toks:
            b = call(rpc, t, "0x70a08231" + enc(pair))
            line += f" | {sym}.balanceOf={int(b,16) if b and b!='0x' else None}"
        print(line)

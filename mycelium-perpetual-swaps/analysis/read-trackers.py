#!/usr/bin/env python3
"""Batch-read tracker/contract state. Public RPC only."""
import json, subprocess, sys
sys.path.insert(0, '.')
from rpc import rpc_batch, rpc

ARB = "https://arb1.arbitrum.io/rpc"
BLK = rpc(ARB, "eth_blockNumber", [])
print("block", BLK, int(BLK, 16))

def sig(s):
    return subprocess.check_output(["cast", "sig", s]).decode().strip()

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def enc_uint(v):
    return hex(v)[2:].rjust(64, "0")

def enc_call(s, args=None):
    sel = sig(s)
    data = sel
    if args:
        for a in args:
            data += enc_addr(a) if a.startswith("0x") else enc_uint(a)
    return data

def dec_addr(h):
    if not isinstance(h, str) or not h.startswith("0x") or len(h) < 66:
        return h
    return "0x" + h[-40:]

def dec_uint(h):
    try:
        return int(h, 16)
    except Exception:
        return h

def dec_bool(h):
    try:
        return bool(int(h, 16))
    except Exception:
        return h

trackers = {
    "F9B003Ee(old?)": "0xF9B003Ee160dA9677115Ad3c5bd6BB6dADcB2F93",
    "stakedMycTracker": "0x2BC8E28f5d41a4b112BC62EB7Db1B757c85f37Ff",
    "bonusMycTracker": "0xbF86a15fa2604dbA2ad7E843c589FAAAd78bF318",
    "feeMycTracker": "0x0cA0147c21F9DB9D4627e6a996342A11D25972C5",
    "stakedMlpTracker": "0xF7Bd2ed13BEf9C27a2188f541Dc5ED85C5325306",
    "feeMlpTracker": "0xF0BFB95087E611897096982c33B6934C8aBfA083",
}
RR = "0xd98d8e458F7aD22DD3C1d7A8B35C74005eb52b0b"
WETH = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
MYC = "0xC74fE4c715510Ec2F8C61d70D397B32043F55Abe"
MLP = "0x752b746426b6D0c3188bb530660374f92FD9cf7c"
ESMYC = "0x7CEC785fba5ee648B48FBffc378d74C8671BB3cb"
BNMYC = "0xb97f91bd8f7fb6ac761Fb84cB953e4F52f049486"

out = {}
calls = []
meta = []
for name, addr in trackers.items():
    fields = [
        ("symbol", enc_call("symbol()(string)")),
        ("totalSupply", enc_call("totalSupply()(uint256)")),
        ("gov", enc_call("gov()(address)")),
        ("distributor", enc_call("distributor()(address)")),
        ("rewardToken", enc_call("rewardToken()(address)")),
        ("inPrivateStakingMode", enc_call("inPrivateStakingMode()(bool)")),
        ("inPrivateClaimingMode", enc_call("inPrivateClaimingMode()(bool)")),
        ("isHandler_RR", enc_call("isHandler(address)(bool)", [RR])),
        ("weth_bal", enc_call("balanceOf(address)(uint256)", [WETH]).replace(sig("balanceOf(address)(uint256)"), "")),
    ]
    for fname, data in fields:
        calls.append((addr, data))
        meta.append((name, fname))

# balances need token contract as `to`
calls2 = []
meta2 = []
for tok_name, tok in [("WETH", WETH), ("MYC", MYC), ("MLP", MLP), ("esMYC", ESMYC), ("bnMYC", BNMYC)]:
    for name, addr in trackers.items():
        calls2.append((tok, enc_call("balanceOf(address)(uint256)", [addr])))
        meta2.append((name, tok_name + "_bal"))

res = rpc_batch(ARB, calls, BLK)
res2 = rpc_batch(ARB, calls2, BLK)

for (name, f), r in zip(meta, res):
    if "bal" in f:
        continue
    v = r
    if f in ("gov", "distributor", "rewardToken"):
        v = dec_addr(r)
    elif f in ("totalSupply",):
        v = dec_uint(r)
    elif f.startswith("inPrivate") or f.startswith("isHandler"):
        v = dec_bool(r)
    elif f == "symbol":
        # decode string
        if isinstance(r, str) and r.startswith("0x") and len(r) > 130:
            ln = int(r[2:66], 16)
            v = bytes.fromhex(r[66:66 + ln * 2]).decode("utf8", "replace")
        else:
            v = r
    out.setdefault(name, {})[f] = v

for (name, f), r in zip(meta2, res2):
    out.setdefault(name, {})[f] = dec_uint(r)

print(json.dumps(out, indent=1))
json.dump(out, open("trackers-state.json", "w"), indent=1)

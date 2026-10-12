#!/usr/bin/env python3
"""NarCard discovery + THUGS constructor decode + Power callers. Read-only."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr

FARM1 = "0x1d227f7e283d653a60f94d2350cab7a49bb85c6f"
FARM2 = "0x6da9ee0c0571b63e38950d1e12e835d5343f601b"
POWER1 = "0x1d791eaa684a21de92618dedea7bf373e2486956"
POWER2 = "0xa1992a9777c3c11c466f44a4b9c7530719a22ea2"

def call(to, sig, args=""):
    r = rpc("eth_call", [{"to": to, "data": sel(sig) + args}, "latest"])
    return r

for name, addr in [("Power0x1d79", POWER1), ("Power0xa199", POWER2)]:
    try:
        print(name, "governance:", dec_addr(call(addr, "governance()")) if False else dec_addr(call(addr, "_governance()")))
        print(name, "_contractCaller:", dec_addr(call(addr, "_contractCaller()")))
    except Exception as e:
        print(name, "ERR", str(e)[:120])
for name, addr in [("Farm1", FARM1), ("Farm2", FARM2)]:
    for sig in ["_narcardFactory()", "_narcardToken()", "_governance()", "governance()"]:
        try:
            print(name, sig, "=>", dec_addr(call(addr, sig)))
        except Exception as e:
            print(name, sig, "ERR", str(e)[:80])

# THUGS deploy tx decode
tx = rpc("eth_getTransactionByHash", ["0x94c7c4e5e17e9255572914740ae37e91bf8336016d65b2c0e889fdcfa5b3baa9"])
data = tx["input"][2:]
# find where bytecode ends: constructor args are last 6*64 hex chars
args = data[-6*64:]
words = [args[i:i+64] for i in range(0, len(args), 64)]
labels = ["_minDeltaTwap", "_initialDistributionAddress", "_burnReservesAddress", "_teamAddress", "_devAddress", "_marketingAddress"]
print("\nTHUGS constructor args:")
for l, w in zip(labels, words):
    print(" ", l, "=", (int(w, 16) if l == "_minDeltaTwap" else dec_addr("0x" + w)))

# farm1 deploy tx decode (4 args) - find them in input tail
tx2 = rpc("eth_getTransactionByHash", ["0x620063e93fc98ff394cc6557d68959726522bb5498a1a23390392cf083723ad6"])
a2 = tx2["input"][2:][-4*64:]
w2 = [a2[i:i+64] for i in range(0, len(a2), 64)]
print("\nFarm1 constructor args:", [dec_addr("0x" + w) for w in w2])
print("deployer:", tx2["from"], "block", hexint(tx2["blockNumber"]))

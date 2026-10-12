#!/usr/bin/env python3
"""Final probes: NarCardFactory check on 0xe207ea20, balances, collecter owner, router verify."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint

BLOCK = hexint(rpc("eth_blockNumber", []))
MYST = "0xe207ea201a1ac5907e333c68e2ecd96fdb9389e1"

# does it implement getNarCard(uint256)?
r = rpc_batch([("eth_call", [{"to": MYST, "data": sel("getNarCard(uint256)") + enc_addr("0000000000000000000000000000000000000000000000000000000000000001")}, "latest"]),
               ("eth_call", [{"to": MYST, "data": sel("name()")}, "latest"]),
               ("eth_call", [{"to": MYST, "data": sel("symbol()")}, "latest"]),
               ("eth_call", [{"to": MYST, "data": sel("narCardToken()")}, "latest"]),
               ("eth_call", [{"to": MYST, "data": sel("narcardToken()")}, "latest"]),
               ("eth_call", [{"to": MYST, "data": sel("nar()")}, "latest"])], timeout=60)
print("myst getNarCard(1):", r[0])
print("myst name():", r[1], "symbol:", r[2], "narCardToken:", r[3], "narcardToken:", r[4], "nar:", r[5])
# raw name bytes32?
if r[1] and r[1] != "0x" and len(r[1]) == 66:
    try: print("  name bytes32:", bytes.fromhex(r[1][2:]).decode("utf-8","replace"))
    except Exception as e: print("  name raw:", r[1])

# balances of key contracts
TOKENS = {"NAR": "0xa1303e6199b319a891b79685f0537d289af1fc83", "WBNB": "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",
          "BUSD": "0xe9e7cea3dedca5984780bafc599bd69add087d56", "USDT": "0x55d398326f99059ff775485246999027b3197955",
          "THUGS": "0xe10e9822a5de22f8761919310dda35cd997d63c0", "LP_NARWBNB": "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
          "LP_WBNBTHUGS": "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957", "LP_WBNBBUSD": "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3"}
TARGETS = {"NarwhalSwap": "0x849b7b4541cde9cbe41cfd064d9d7ff459b9cea4", "NarCardToken": "0x828b5adbe8e0a06aaf5d5a5fd16e6b15a393d86e",
           "NarNft": "0xce7a099a7c5c062a4f66a6bbdec191a222baa3f2", "myst": MYST,
           "collecter": "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9", "router": "0xe85c6ab56a3422e7bafd71e81eb7d0f290646078"}
calls = []
for tn, ta in TARGETS.items():
    calls.append(("eth_getBalance", [ta, hex(BLOCK)], tn, "BNB"))
for tn, ta in TARGETS.items():
    for tk, tk2 in TOKENS.items():
        calls.append(("eth_call", [{"to": tk2, "data": sel("balanceOf(address)") + enc_addr(ta)}, hex(BLOCK)], tn, tk))
rs = rpc_batch(calls, timeout=120)
out = {}
for (k, p, tn, tk), rr in zip(calls, rs):
    v = hexint(rr) if rr else 0
    if v: out.setdefault(tn, {})[tk] = str(v)
print(json.dumps(out, indent=1))

# collecter owner/threshold + narwhalswap owner
r3 = rpc_batch([("eth_call", [{"to": "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9", "data": sel("owner()")}, "latest"]),
                ("eth_call", [{"to": "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9", "data": sel("threshold()")}, "latest"]),
                ("eth_call", [{"to": "0x849b7b4541cde9cbe41cfd064d9d7ff459b9cea4", "data": sel("owner()")}, "latest"]),
                ("eth_call", [{"to": "0xe85c6ab56a3422e7bafd71e81eb7d0f290646078", "data": sel("WETH()")}, "latest"]),
                ], timeout=60)
print("collecter owner:", dec_addr(r3[0]), "threshold:", dec_uint(r3[1]))
print("narwhalswap owner:", dec_addr(r3[2]), "| router WETH:", dec_addr(r3[3]), r3[3])
json.dump({"block": BLOCK, "balances": out}, open("misc_balances.json", "w"), indent=1)

#!/usr/bin/env python3
"""Probe mystery contract 0xe207ea20 + NarwhalSwap/NarCard balances + fry deploys."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint

BLOCK = hexint(rpc("eth_blockNumber", []))
MYST = "0xe207ea201a1ac5907e333c68e2ecd96fdb9389e1"
probes = ["token()","nft()","narcardToken()","narCardToken()","factory()","vault()",
          "getReward()","rewardPerToken()","stakingToken()","rewardsToken()","periodFinish()",
          "duration()","beneficiary()","releaseTime()","unlockTime()","harvest()","totalSupply()",
          "available()","claim()","withdraw()","owner()","governance()","getOwner()","minters(address)",
          "baseURI()","uri()","NAR()","narToken()","rewardToken()","startTime()","claimTime()","batchMint()"]
calls = [("eth_call", [{"to": MYST, "data": sel(f)}, "latest"]) for f in probes]
rs = rpc_batch(calls, timeout=90)
print("== 0xe207ea20 probes:")
for f, r in zip(probes, rs):
    if r and r != "0x":
        print(f"   {f} -> {r[:130]}")
# selector scan of e207 bytecode
code = rpc("eth_getCode", [MYST, "latest"])
sels = set()
b = bytes.fromhex(code[2:])
i = 0
while i + 4 <= len(b):
    if b[i] == 0x63 and i + 5 <= len(b):  # PUSH4
        sels.add("0x" + b[i+1:i+5].hex()); i += 5
    else:
        i += 1
print("push4 selectors found:", len(sels))
print(sorted(sels)[:40])

# balances for the three contracts
TOKENS = {"NAR":"0xa1303e6199b319a891b79685f0537d289af1fc83","WBNB":"0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c","BUSD":"0xe9e7cea3dedca5984780bafc599bd69add087d56","USDT":"0x55d398326f99059ff775485246999027b3197955","THUGS":"0xe10e9822a5de22f8761919310dda35cd997d63c0","LP_NARWBNB":"0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2","LP_WBNBTHUGS":"0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957"}
targets = {"NarwhalSwap_849b":"0x849b7b4541cde9cbe41cfd064d9d7ff459b9cea4",
           "NarCardToken_828b":"0x828b5adbe8e0a06aaf5d5a5fd16e6b15a393d86e",
           "NarNft_ce7a":"0xce7a099a7c5c062a4f66a6bbdec191a222baa3f2",
           "myst_e207":MYST}
calls2 = []
for tn, ta in targets.items():
    calls2.append(("eth_getBalance", [ta, hex(BLOCK)], tn, "BNB"))
for tn, ta in targets.items():
    for tk, tk2 in TOKENS.items():
        calls2.append(("eth_call", [{"to": tk2, "data": sel("balanceOf(address)") + enc_addr(ta)}, hex(BLOCK)], tn, tk))
rs2 = rpc_batch(calls2, timeout=120)
out = {}
for (k, _, tn, tk), r in zip(calls2, rs2):
    v = hexint(r) if r else 0
    if v: out.setdefault(tn, {})[tk] = str(v)
print(json.dumps(out, indent=1))
# NarCard governance + minters
nc = "0x828b5adbe8e0a06aaf5d5a5fd16e6b15a393d86e"
r3 = rpc_batch([("eth_call",[{"to":nc,"data":sel("_governance()")},"latest"]),
                ("eth_call",[{"to":nc,"data":sel("_minters(address)")+enc_addr("0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5")},"latest"]),
                ("eth_call",[{"to":nc,"data":sel("baseURI()")},"latest"])], timeout=60)
print("NarCard _governance:", dec_addr(r3[0]), "| team is minter:", dec_uint(r3[1]), "| baseURI:", r3[2][:100] if r3[2] else None)
json.dump({"block":BLOCK,"balances":out}, open("misc_balances.json","w"), indent=1)

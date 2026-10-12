#!/usr/bin/env python3
"""Enumerate NAR minters + V3 farm family + rNLP registry. Read-only."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint

BLOCK = hexint(rpc("eth_blockNumber", []))
NAR = "0xa1303e6199b319a891b79685f0537d289af1fc83"

def c1(to, sig, args=""):
    r = rpc("eth_call", [{"to": to, "data": sel(sig) + args}, "latest"])
    return r

# NAR constants
out = {"block": BLOCK}
for sig in ["_rewardPool()", "_burnPool()", "_teamWallet()", "_governance()", "_burnRate()", "_rewardRate()",
            "_rateBase()", "_maxSupply()", "_teamMinted()", "_totalBurnToken()", "_totalRewardToken()",
            "_openTransfer()", "minterAddressesLength()", "totalSupply()", "name()", "symbol()"]:
    try:
        r = c1(NAR, sig)
        if sig in ("name()", "symbol()"):
            if r and len(r) > 130:
                off = int(r[2:66], 16); ln = int(r[66+off*2:66+off*2+64], 16)
                v = bytes.fromhex(r[66+off*2+64:66+off*2+64+ln*2]).decode("utf-8","replace")
            else: v = r
        elif sig.endswith("()") and sig in ("_rewardPool()","_burnPool()","_teamWallet()","_governance()"):
            v = dec_addr(r)
        else:
            v = dec_uint(r)
        print("NAR", sig, "=>", v)
        out["nar_" + sig] = str(v)
    except Exception as e:
        print("NAR", sig, "ERR", str(e)[:80])

n = dec_uint(c1(NAR, "minterAddressesLength()")) or 0
print("\nNAR minters count:", n)
minters = []
for i in range(n):
    a = dec_addr(c1(NAR, "_minterAddresses(uint256)", ("%064x" % i)))
    minters.append(a)
    print("  minter", i, a)
out["nar_minters"] = minters

# inspect minters
for a in minters:
    if not a: continue
    cl = (len(rpc("eth_getCode", [a, "latest"])) - 2) // 2
    info = {"address": a, "code_size": cl}
    if cl > 0:
        rs = rpc_batch([("eth_call", [{"to": a, "data": sel(s)} , "latest"]) for s in
                        ["nar()", "rnlp()", "lpToken()", "teamWallet()", "_governance()", "minter()", "name()", "symbol()", "totalSupply()"]], timeout=60)
        names = ["nar()", "rnlp()", "lpToken()", "teamWallet()", "_governance()", "minter()", "name()", "symbol()", "totalSupply()"]
        for s, r in zip(names, rs):
            if not r or r == "0x": continue
            if s in ("nar()", "rnlp()", "lpToken()", "teamWallet()", "_governance()", "minter()"):
                info[s] = dec_addr(r)
            elif s in ("name()", "symbol()"):
                try:
                    off = int(r[2:66], 16); ln = int(r[66+off*2:66+off*2+64], 16)
                    info[s] = bytes.fromhex(r[66+off*2+64:66+off*2+64+ln*2]).decode("utf-8","replace")
                except Exception: info[s] = r[:66]
            else:
                info[s] = str(dec_uint(r))
        # extra farm fields
        rs2 = rpc_batch([("eth_call", [{"to": a, "data": sel(s)}, "latest"]) for s in
                         ["rewardRate()", "periodFinish()", "_initReward()", "totalSupply()"]], timeout=60)
        for s, r in zip(["rewardRate()", "periodFinish()", "_initReward()", "totalSupply()"], rs2):
            if r and r != "0x": info[s] = str(dec_uint(r))
    # balances
    rb = rpc_batch([("eth_getBalance", [a, hex(BLOCK)]),
                    ("eth_call", [{"to": NAR, "data": sel("balanceOf(address)") + enc_addr(a)}, hex(BLOCK)])], timeout=60)
    info["bnb"] = str(hexint(rb[0]) or 0)
    info["nar_bal"] = str(hexint(rb[1]) or 0)
    print(json.dumps(info)[:400])
    out.setdefault("minter_info", []).append(info)

json.dump(out, open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/nar_minters.json", "w"), indent=1)
print("\nsaved nar_minters.json")

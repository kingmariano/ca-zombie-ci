#!/usr/bin/env python3
"""Identify large-code NAR recipients (likely farm family)."""
import sys, json, subprocess, os
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint

BLOCK = hexint(rpc("eth_blockNumber", []))
CAND = ["0x2368bab38a79827f49fc768bf1b6d04226704d35","0x3dfb186e8ce513f321232098dd551e22886c1051",
        "0x4ed7fd4f2ca11a5af9cd4519187d468d2577798b","0x657ba421cc8b1be5891aa9ac7aa2b936e5d08b65",
        "0x7f0414886ebf34cce32148ba0cf64dd8ec88a274","0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107",
        "0xb85a8c269cfc6ec4bd44e7dbd312b233a38eea0d","0xc3a471421bb1364d74b8f384cd73fe34d2ce1773",
        "0xc8e70639ad7d91d4d4bcf5d5ab8e2264abb7b25e","0xe6e0646bd4fcd37ec7258d21295dd4cdc347f57a",
        "0xf7a36c87c3a8909949638120f23cd721bf572032"]
out = []
for a in CAND:
    info = {"address": a}
    f = f"sourcify/{a}_full.json"
    if not os.path.exists(f):
        subprocess.run(["curl", "-s", "-m", "45", f"https://sourcify.dev/server/v2/contract/56/{a}?fields=compilation,deployment", "-o", f])
    try:
        d = json.load(open(f))
        if d.get("matchId"):
            info["verified"] = (d.get("compilation") or {}).get("name")
            info["deployer"] = (d.get("deployment") or {}).get("deployer")
            info["deploy_block"] = (d.get("deployment") or {}).get("blockNumber")
    except Exception: pass
    sigs = ["nar()", "lpToken()", "rnlp()", "governance()", "_governance()", "owner()", "totalSupply()", "name()", "symbol()", "stakingToken()", "rewardToken()", "minter()", "token0()", "token1()"]
    rs = rpc_batch([("eth_call", [{"to": a, "data": sel(s)}, "latest"]) for s in sigs], timeout=90)
    probes = {}
    for s, r in zip(sigs, rs):
        if r and r != "0x":
            if s in ("nar()", "lpToken()", "rnlp()", "governance()", "_governance()", "owner()", "stakingToken()", "rewardToken()", "minter()", "token0()", "token1()"):
                probes[s] = dec_addr(r)
            elif s == "totalSupply()": probes[s] = str(dec_uint(r))
            else: probes[s] = r[:66]
    info["probes"] = probes
    rb = rpc_batch([("eth_getBalance", [a, hex(BLOCK)]),
                    ("eth_call", [{"to": "0xa1303e6199b319a891b79685f0537d289af1fc83", "data": sel("balanceOf(address)") + enc_addr(a)}, hex(BLOCK)])], timeout=60)
    info["bnb"] = str(hexint(rb[0]) or 0)
    info["nar_bal"] = str(hexint(rb[1]) or 0)
    if probes.get("lpToken()"):
        r3 = rpc_batch([("eth_call", [{"to": probes["lpToken()"], "data": sel("balanceOf(address)") + enc_addr(a)}, hex(BLOCK)]),
                        ("eth_call", [{"to": probes["lpToken()"], "data": sel("totalSupply()")}, hex(BLOCK)])], timeout=60)
        info["lp_held"] = str(hexint(r3[0]) or 0)
        info["lp_supply"] = str(hexint(r3[1]) or 0)
    print(json.dumps(info, default=str)[:500])
    out.append(info)
json.dump({"block": BLOCK, "candidates": out}, open("farm_family.json", "w"), indent=1)
print("saved farm_family.json")

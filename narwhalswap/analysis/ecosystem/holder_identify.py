#!/usr/bin/env python3
"""Identify top LP holder addresses: code/verify/owner/balances."""
import sys, json, subprocess, os
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint

BLOCK = hexint(rpc("eth_blockNumber", []))
HOLDERS = {
    "lp_thugs_top1": "0x4d710603238427ae805b980bab8261624f5260c7",
    "lp_thugs_top2": "0xe99140fc04e458ac58d47c29c0649bcc3914dc0a",
    "lp_thugs_top3": "0xb752f0cb591ecfb1c5058a93e1332f066bf38473",
    "lp_busd_top1": "0xbb38f7551025a433f36590be85271110212655de",
    "lp_busd_top2": "0xa9d5f138ba6b6ce6ed0ed2e335e76b7d2a237621",
    "lp_narwbnb_top2": "0xbe85812237741d75f81aebf1d9af52d544542168",
    "lp_narwbnb_top3": "0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835",
}
res = {}
for k, a in HOLDERS.items():
    code = rpc("eth_getCode", [a, "latest"])
    cl = (len(code) - 2) // 2
    bnb = hexint(rpc("eth_getBalance", [a, "latest"])) or 0
    verified = None
    if cl > 0:
        f = f"sourcify/{a}_full.json"
        if not os.path.exists(f):
            subprocess.run(["curl", "-s", "-m", "50", f"https://sourcify.dev/server/v2/contract/56/{a}?fields=all", "-o", f])
        try:
            d = json.load(open(f))
            if d.get("matchId"):
                verified = {"name": (d.get("compilation") or {}).get("name"),
                            "deployer": (d.get("deployment") or {}).get("deployer"),
                            "block": (d.get("deployment") or {}).get("blockNumber")}
        except Exception: pass
    # common probes
    probes = ["owner()", "farm()", "lpToken()", "stakingToken()", "rewardToken()", "governance()",
              "name()", "symbol()", "totalSupply()", "pendingOwner()", "token()", "want()", "underlying()", "strategy()"]
    pr = rpc_batch([("eth_call", [{"to": a, "data": sel(s)}, "latest"]) for s in probes], timeout=90)
    pinfo = {}
    for s, r in zip(probes, pr):
        if r and r != "0x":
            if s in ("owner()", "farm()", "lpToken()", "stakingToken()", "rewardToken()", "governance()", "pendingOwner()", "token()", "want()", "underlying()", "strategy()"):
                pinfo[s] = dec_addr(r)
            elif s == "totalSupply()":
                pinfo[s] = str(dec_uint(r))
            else:
                pinfo[s] = r[:66]
    res[k] = {"address": a, "code_size": cl, "bnb": str(bnb), "verified": verified, "probes": pinfo}
    print(json.dumps(res[k], default=str))
json.dump({"block": BLOCK, "identify": res}, open("holder_identify.json", "w"), indent=1)
print("\nsaved holder_identify.json block", BLOCK)

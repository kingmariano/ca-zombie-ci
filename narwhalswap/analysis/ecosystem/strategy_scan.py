#!/usr/bin/env python3
"""Value scan for Grand Banks strategies + FryDutchMan servicers. Read-only."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint

BLOCK = hexint(rpc("eth_blockNumber", []))
G = json.load(open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/grand_enum.json"))

farms = {"v1": "0x08f886b14af4fc75e49d6475f46d041f5f257ce1",
         "v2": "0x3d8fd880976a3ea0f53cad02463867013d331107"}
SIGS = ["wantLockedTotal()", "sharesTotal()", "paused()", "onlyGov()", "govAddress()", "owner()", "wantAddress()"]

# build call list
calls = []      # (kind, meta)
for label, farm in farms.items():
    for p in G["farms"][("grand_%s_farm" % label)]["pools"]:
        st = p["strat"]; want = p["want"]
        if st and st != "0x" + "0"*40:
            for s in SIGS:
                calls.append(("call", {"to": st, "data": sel(s)}, (label, p["pid"], st, want, s)))
            calls.append(("call", {"to": want, "data": sel("balanceOf(address)") + enc_addr(st)}, (label, p["pid"], st, want, "want.balanceOf(strat)")))
            calls.append(("call", {"to": want, "data": sel("balanceOf(address)") + enc_addr(farm)}, (label, p["pid"], st, want, "want.balanceOf(farm)")))
            calls.append(("bnb", st, None))
# fry contracts
frys = set()
for label in ("v1", "v2"):
    for p in G["farms"][("grand_%s_farm" % label)]["pools"]:
        for k in ("frySailing", "fryLanding"):
            a = p[k]
            if a and a != "0x" + "0"*40: frys.add(a)
for f in sorted(frys):
    calls.append(("call", {"to": f, "data": sel("owner()")}, ("fry", 0, f, "", "owner()")))
    calls.append(("bnb", f, None))
# farm summary
for label, farm in farms.items():
    for s in ["totalAllocPoint()", "owner()", "poolLength()"]:
        calls.append(("call", {"to": farm, "data": sel(s)}, ("farm", 0, farm, "", s)))
calls.append(("call", {"to": "0xee814f5b2bf700d2e843dc56835d28d095161dd9", "data": sel("balanceOf(address)") + enc_addr(farms["v2"])}, ("farm", 0, farms["v2"], "", "grandv2.balanceOf(farm)")))
calls.append(("call", {"to": "0xd37ebaeb28c0a6c9a62d5c5c0119d464e28b367e", "data": sel("balanceOf(address)") + enc_addr(farms["v1"])}, ("farm", 0, farms["v1"], "", "grandv1.balanceOf(farm)")))

print("total calls:", len(calls))
# execute in batches of 60
results = [None] * len(calls)
CH = 60
for i in range(0, len(calls), CH):
    part = calls[i:i+CH]
    batch = []
    for kind, a, b in part:
        if kind == "call": batch.append(("eth_call", [a, hex(BLOCK)]))
        elif kind == "bnb": batch.append(("eth_getBalance", [a, hex(BLOCK)]))
    rs = rpc_batch(batch, timeout=120)
    for j, r in enumerate(rs):
        results[i+j] = r

# aggregate per strategy
strats = {}
for (kind, a, b), r in zip(calls, results):
    if kind == "call":
        label, pid, st, want, s = b
        strats.setdefault(st, {"want": want, "pools": []})
        if s == "want.balanceOf(strat)": strats[st]["bal"] = hexint(r)
        elif s == "want.balanceOf(farm)": strats[st].setdefault("farm_bals", [])
        elif s == "owner()" and label == "fry": strats[st]["owner"] = dec_addr(r)
        elif label == "farm": strats[st].setdefault("farmsumm", {})[s] = hexint(r) if s != "owner()" else dec_addr(r)
        else: strats[st][s] = hexint(r)
    elif kind == "bnb":
        st = b[2] if isinstance(b, tuple) else b
        strats.setdefault(st, {})["bnb"] = hexint(r) if r else 0

# value filter
live = []
for st, d in strats.items():
    wlt = d.get("wantLockedTotal()") or 0
    bal = d.get("bal") or 0
    bnb = d.get("bnb") or 0
    shares = d.get("sharesTotal()") or 0
    if wlt or bal or bnb or shares:
        live.append((st, d))
print("\n=== strategies/fry with nonzero state:", len(live))
for st, d in sorted(live, key=lambda x: -((x[1].get("wantLockedTotal()") or 0))):
    print(json.dumps({"strat": st, **{k: v for k, v in d.items() if k != "pools"}}, default=str))
json.dump({"block": BLOCK, "strategies": strats}, open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/strategy_scan.json", "w"), indent=1, default=str)
print("\nsaved strategy_scan.json block", BLOCK)

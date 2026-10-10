#!/usr/bin/env python3
"""Compare user_deposits vs event-derived net shares (deposit - withdraw).

Detects whether the deployed strategy has TOB-SPH-19 (deposit overwrite) and
TOB-SPH-20 (partial withdraw zeroes shares) live.
"""
import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import call, selector_from_name  # noqa

S = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"


def u256(d, i):
    return int(d[i], 16) + (int(d[i + 1], 16) << 128)


def load(fn):
    with open(os.path.join(os.path.dirname(__file__), fn)) as f:
        return json.load(f)


def analyze(market, depfile, wdfile):
    dep = defaultdict(lambda: {"shares": 0, "n": 0})
    wd = defaultdict(lambda: {"shares": 0, "n": 0})
    for e in load(depfile):
        c = e["keys"][1]
        dep[c]["shares"] += u256(e["data"], 4)
        dep[c]["n"] += 1
    for e in load(wdfile):
        c = e["keys"][1]
        wd[c]["shares"] += u256(e["data"], 4)
        wd[c]["n"] += 1
    users = set(dep) | set(wd)
    rows = []
    for u in users:
        net = dep[u]["shares"] - wd[u]["shares"]
        r = call(S, selector_from_name("user_deposits"), [market, u])
        cur = u256(r["result"], 0) if "result" in r else None
        rows.append({
            "user": u, "n_dep": dep[u]["n"], "n_wd": wd[u]["n"],
            "sum_dep": dep[u]["shares"], "sum_wd": wd[u]["shares"],
            "net": net, "user_deposits": cur,
            "match_net": cur == net,
            "match_last_dep_only": cur == dep[u]["shares"] if dep[u]["n"] == 1 else None,
        })
    return rows


out = {}
for mname, mid, dfile, wfile in [
    ("M2_wstETH_ETH", "0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2", "deposits_M2.json", "withdraws_M2.json"),
    ("M4_STRK_USDC", "0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b", "deposits_M4.json", "withdraws_M4.json"),
]:
    rows = analyze(mid, dfile, wfile)
    n_match = sum(1 for r in rows if r["match_net"])
    n_mismatch = sum(1 for r in rows if not r["match_net"])
    print(f"== {mname}: users={len(rows)}, match_net={n_match}, mismatch={n_mismatch}")
    # show interesting mismatches
    mism = [r for r in rows if not r["match_net"]]
    for r in mism[:12]:
        print(f"   {r['user'][:16]} dep×{r['n_dep']} wd×{r['n_wd']} net={r['net']} onchain={r['user_deposits']}")
    out[mname] = {"users": len(rows), "match_net": n_match, "mismatch": n_mismatch, "rows": rows}

with open(os.path.join(os.path.dirname(__file__), "share_accounting_check.json"), "w") as f:
    json.dump(out, f, indent=1)
print("saved share_accounting_check.json")

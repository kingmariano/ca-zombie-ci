#!/usr/bin/env python3
"""CI share-accounting check: on-chain user_deposits vs event-derived net shares.

Detects live TOB-SPH-19 (deposit overwrite) / TOB-SPH-20 (partial withdraw zeroes).
Reads events from ci-out (written by ci_scan_events.py).
"""
import json
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from starknet_rpc import call, selector_from_name, block_number  # noqa

OUT = os.path.join(HERE, "..", "ci-out")
S = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"

MARKETS = {
    "M1_ETH_USDC": "0x6812a18046f6b1d926ce6d081ceee71cb0ec7fbdb38167cc07d618ee8f5713e",
    "M2_wstETH_ETH": "0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2",
    "M3_USDC_USDT": "0xeb87f342e5267cb250240851fdeaa111ce548934e529c41137fea49ccebdf",
    "M4_STRK_USDC": "0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b",
    "M5_STRK_ETH": "0x3ddeeae1e54ed0b70d57e067fa696ef333e69cc6dbe8b4469ad0e9900546b54",
    "M6_ETH_WBTC": "0x16707e0f13b27d91c357a8294b28ff023e30acbf1456e5391f61fa22cdb0d76",
}


def u256(d, i):
    return int(d[i], 16) + (int(d[i + 1], 16) << 128)


def load(fn):
    p = os.path.join(OUT, fn)
    if not os.path.exists(p):
        return None
    return json.load(open(p))


results = {"block": block_number(), "markets": {}}

for name, mid in MARKETS.items():
    dep = load(f"events_Deposit_{name}.json")
    wd = load(f"events_Withdraw_{name}.json")
    if dep is None or wd is None:
        print(f"{name}: missing event files, skip")
        continue
    dsum = defaultdict(lambda: [0, 0])  # user -> [shares, n]
    wsum = defaultdict(lambda: [0, 0])
    for e in dep:
        u = e["keys"][1]
        dsum[u][0] += u256(e["data"], 4)
        dsum[u][1] += 1
    for e in wd:
        u = e["keys"][1]
        wsum[u][0] += u256(e["data"], 4)
        wsum[u][1] += 1

    users = set(dsum) | set(wsum)
    # selection: multiple deposits/withdrawals, or top-30 by net
    interesting = [u for u in users if dsum[u][1] > 1 or wsum[u][1] > 1 or (dsum[u][1] >= 1 and wsum[u][1] >= 1)]
    nets = sorted(users, key=lambda u: -(dsum[u][0] - wsum[u][0]))[:30]
    sel = list(dict.fromkeys(interesting + nets))[:150]

    rows = []
    for u in sel:
        net = dsum[u][0] - wsum[u][0]
        r = call(S, selector_from_name("user_deposits"), [mid, u])
        cur = u256(r["result"], 0) if "result" in r else None
        rows.append({
            "user": u, "n_dep": dsum[u][1], "n_wd": wsum[u][1],
            "sum_dep": dsum[u][0], "sum_wd": wsum[u][0], "net": net,
            "user_deposits": cur,
            "match": cur == net,
            "would_match_last_dep_only": (cur == dsum[u][0]) if dsum[u][1] == 1 else None,
        })
    n_match = sum(1 for r in rows if r["match"])
    mism = [r for r in rows if not r["match"]]
    results["markets"][name] = {
        "total_unique_users": len(users),
        "sampled": len(rows),
        "match": n_match,
        "mismatch": len(mism),
        "mismatches": mism[:40],
    }
    print(f"{name}: users={len(users)} sampled={len(rows)} match={n_match} mismatch={len(mism)}")
    for r in mism[:8]:
        print(f"   MISMATCH {r['user'][:18]} dep×{r['n_dep']} wd×{r['n_wd']} net={r['net']} onchain={r['user_deposits']}")

json.dump(results, open(os.path.join(OUT, "share_check.json"), "w"), indent=1)
print("saved ci-out/share_check.json")

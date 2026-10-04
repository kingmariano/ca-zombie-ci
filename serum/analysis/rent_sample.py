#!/usr/bin/env python3
"""Sample 8 OpenBook v1 markets to estimate per-market locked rent."""
import sys, json, base64, struct
sys.path.insert(0, "/home/heisenberg/CA/serum/analysis")
from rpc import rpc, bytes_to_b58

MB = ["https://api.mainnet-beta.solana.com"]
PN = ["https://solana-rpc.publicnode.com"]

# pick sample pubkeys from chunk files across nonces
picks = []
import glob
for pat in ["chunks/n0_b0.jsonl", "chunks/n0_b100.jsonl", "chunks/n0_b200.jsonl",
            "chunks/n1_b0.jsonl", "chunks/n1_b100.jsonl", "chunks/n2_b0.jsonl", "chunks/n3_b0.jsonl"]:
    try:
        with open(pat) as f:
            for i, line in enumerate(f):
                if i >= 2: break
                j = json.loads(line)
                picks.append(j["pubkey"])
    except Exception:
        pass
picks = picks[:8]
print("sample:", picks)

eps = MB
ma = rpc("getMultipleAccounts", [picks, {"encoding": "base64", "commitment": "finalized"}], endpoints=eps)
subs = {}
for pk, v in zip(picks, ma["value"]):
    if not v:
        print(pk, "missing"); continue
    d = base64.b64decode(v["data"][0])
    subs[pk] = {
        "market": (pk, v["lamports"], v["space"]),
        "req_q": (bytes_to_b58(d[221:253]), None, None),
        "event_q": (bytes_to_b58(d[253:285]), None, None),
        "bids": (bytes_to_b58(d[285:317]), None, None),
        "asks": (bytes_to_b58(d[317:349]), None, None),
    }
addrs = []
for pk, s in subs.items():
    for k in ("req_q", "event_q", "bids", "asks"):
        addrs.append(s[k][0])
ma2 = rpc("getMultipleAccounts", [addrs, {"encoding": "base64", "commitment": "finalized"}], endpoints=eps)
vals = ma2["value"]
it = iter(vals)
totals = []
for pk, s in subs.items():
    tot = s["market"][1]
    parts = {"market": s["market"][1]}
    for k in ("req_q", "event_q", "bids", "asks"):
        v = next(it)
        if v:
            tot += v["lamports"]
            parts[k] = v["lamports"]
            parts[k + "_size"] = v["space"]
    # vaults: token accounts owned by vault signer are not fetched here; assume 2 x 2,039,280
    parts["vaults_est"] = 2 * 2039280
    tot += parts["vaults_est"]
    parts["total_lamports"] = tot
    totals.append((pk, parts))
for pk, p in totals:
    print(pk, json.dumps(p))
sums = [p["total_lamports"] for _, p in totals]
print("n =", len(sums), "avg SOL =", sum(sums) / len(sums) / 1e9 if sums else None,
      "min =", min(sums) / 1e9 if sums else None, "max =", max(sums) / 1e9 if sums else None)
json.dump({"samples": [{"pubkey": pk, **p} for pk, p in totals],
           "avg_sol": (sum(sums) / len(sums) / 1e9) if sums else None},
          open("/home/heisenberg/CA/serum/analysis/rent_sample.json", "w"), indent=1)

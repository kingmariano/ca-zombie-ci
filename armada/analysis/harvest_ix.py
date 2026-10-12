#!/usr/bin/env python3
"""Harvest real Armada program instructions (with account lists) from recent history."""
import sys, json, base64, collections, time
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
A = "/home/heisenberg/CA/armada/analysis"

sigs = rpc("getSignaturesForAddress", [PROG, {"limit": 1000}])
print("sigs:", len(sigs))
samples = collections.defaultdict(list)
ix_count = collections.Counter()
errors = collections.Counter()

# scan first 400 sigs
for i, s in enumerate(sigs[:400]):
    if i % 50 == 0:
        print("...", i, flush=True)
    try:
        tx = rpc("getTransaction", [s["signature"], {"encoding": "json", "maxSupportedTransactionVersion": 0}])
    except Exception as e:
        continue
    if not tx:
        continue
    meta = tx.get("meta") or {}
    msg = (tx.get("transaction") or {}).get("message") or {}
    keys = msg.get("accountKeys") or []
    for ix in msg.get("instructions") or []:
        if ix.get("programId") != PROG:
            continue
        data = ix.get("data") or ""
        disc = data[:16]
        ix_count[disc] += 1
        # find anchor log name for this tx
        name = None
        for log in (meta.get("logMessages") or []):
            if "Program log: Instruction:" in log:
                nm = log.split("Instruction:")[-1].strip()
                if nm.lower().replace("_", "") in ("withdraw", "deposit", "collectfees", "collectrewards",
                                                   "setvaultratiocache", "externalswapsetup", "externalswapcleanup",
                                                   "decreaseliquidity", "increaseliquidity", "openposition",
                                                   "closeposition", "updateconfig", "update_token_meta",
                                                   "updatetokenmeta", "initialize", "initializepositionbundle"):
                    name = nm
        rec = {"sig": s["signature"], "slot": s["slot"], "blockTime": s.get("blockTime"),
               "data": data, "accounts": ix.get("accounts"), "num_accounts": len(ix.get("accounts") or []),
               "anchor_name": name, "err": meta.get("err")}
        samples[name or f"unk_{disc}"].append(rec)
    if i > 0 and i % 100 == 0:
        json.dump({k: v[:10] for k, v in samples.items()}, open(f"{A}/ix-samples-partial.json", "w"), indent=1)

print("\n=== instruction counts (by first 16 b58 chars of data) ===")
for d, c in ix_count.most_common():
    print(f"  {d}: {c}")
print("\n=== named samples ===")
for k, v in samples.items():
    print(f"  {k}: {len(v)}")
out = {k: v[:20] for k, v in samples.items()}
json.dump(out, open(f"{A}/ix-samples.json", "w"), indent=1)
print("saved ix-samples.json")

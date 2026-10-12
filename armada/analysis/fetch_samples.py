#!/usr/bin/env python3
"""Fetch recent txs, extract full Armada instruction records (discriminator, accounts, data)."""
import sys, json, hashlib, base64, collections
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import *

PROG = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
A = "/home/heisenberg/CA/armada/analysis"
names = ["initialize", "update_config", "initialize_position_bundle", "deposit", "withdraw", "open_position",
         "close_position", "increase_liquidity", "decrease_liquidity", "collect_rewards", "collect_fees",
         "update_token_meta", "set_vault_ratio_cache", "external_swap_setup", "external_swap_cleanup"]
disc = {hashlib.sha256(f"global:{n}".encode()).digest()[:8]: n for n in names}
b58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58e(b):
    n = int.from_bytes(b, "big"); out = ""
    while n: n, r = divmod(n, 58); out = b58[r] + out
    return out or "1"

r4 = json.load(open(f"{A}/recon4_activity.json"))
sigs = [s["sig"] for s in r4["recent_sigs"]]
print("sigs to scan:", len(sigs))
found = collections.defaultdict(list)
for i, s in enumerate(sigs):
    try:
        tx = rpc("getTransaction", [s, {"encoding": "jsonParsed", "maxSupportedTransactionVersion": 0}], timeout=45)
    except Exception as e:
        print("fail", i, s[:10], redact(e)[:60]); continue
    if not tx:
        continue
    msg = (tx.get("transaction") or {}).get("message") or {}
    keys = msg.get("accountKeys") or []
    # also handle loaded addresses (v0)
    loaded = (tx.get("meta") or {}).get("loadedAddresses") or {}
    allkeys = list(keys) + list(loaded.get("writable") or []) + list(loaded.get("readonly") or [])
    for ix in msg.get("instructions") or []:
        if ix.get("programId") != PROG:
            continue
        data = b58decode(ix.get("data") or "")
        nm = disc.get(data[:8], f"unk_{data[:8].hex()}")
        rec = {"sig": s, "slot": tx.get("slot"), "blockTime": tx.get("blockTime"), "name": nm,
               "data": (ix.get("data") or ""), "accounts": [allkeys[a] if isinstance(a, int) else a for a in ix.get("accounts") or []],
               "err": (tx.get("meta") or {}).get("err")}
        found[nm].append(rec)
    if i % 20 == 0:
        print("...", i, flush=True)

out = {k: v[:6] for k, v in found.items()}
json.dump(out, open(f"{A}/ix-full-samples.json", "w"), indent=1)
for k, v in found.items():
    print(f"{k}: {len(v)} samples; first sig {v[0]['sig'][:20] if v else None}")
print("saved")

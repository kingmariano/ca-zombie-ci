#!/usr/bin/env python3
"""Probe DxSale variant lockers: find wallets whose unlockToken(j) currently succeeds.

Usage: probe_unlock.py <rpc> <locker> <total> <step> <maxj>
"""
import json, sys, time, urllib.request

RPC, LOCKER, TOTAL, STEP, MAXJ = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
SEL_LR = "0x0e48606b"
SEL_UNLOCK = "0xdd2e0ac0"

def enc_u(x): return hex(int(x))[2:].rjust(64, "0")

def batch(calls, chunk=10):
    """Returns list of raw results; on RPC error -> 'ERR:<msg>'."""
    out = [None] * len(calls)
    for s in range(0, len(calls), chunk):
        sub = calls[s:s + chunk]
        for attempt in range(4):
            payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [c, "latest"]}
                       for i, c in enumerate(sub)]
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json", "User-Agent": "z"})
                res = json.load(urllib.request.urlopen(req, timeout=90))
                for x in res:
                    if "result" in x:
                        out[s + x["id"]] = x["result"]
                    else:
                        out[s + x["id"]] = "ERR:" + x.get("error", {}).get("message", "")[:100]
                break
            except Exception as e:
                if attempt == 3:
                    for i in range(len(sub)):
                        out[s + i] = "RPC_FAIL:" + str(e)[:60]
                time.sleep(1 + 2 * attempt)
        time.sleep(0.08)
    return out

ids = list(range(0, TOTAL, STEP))
wres = batch([{"to": LOCKER, "data": SEL_LR + enc_u(i)} for i in ids], chunk=15)
wallets = []
for i, r in zip(ids, wres):
    if isinstance(r, str) and r.startswith("0x") and len(r) >= 42:
        wallets.append((i, "0x" + r[-40:]))
    else:
        if i < 10: print("  sample err", i, str(r)[:80], flush=True)
print("sampled ids:", len(ids), "wallets:", len(wallets), flush=True)
calls, meta = [], []
for i, w in wallets:
    for j in range(MAXJ + 1):
        calls.append({"to": LOCKER, "data": SEL_UNLOCK + enc_u(j), "from": w})
        meta.append((i, w, j))
print("probe calls:", len(calls), flush=True)
res = batch(calls, chunk=10)
ok = []
for (i, w, j), r in zip(meta, res):
    if isinstance(r, str) and r.startswith("0x"):
        ok.append({"id": i, "wallet": w, "index": j})
print(json.dumps({"locker": LOCKER, "total": TOTAL, "sampled": len(wallets), "ok": ok}, indent=1))

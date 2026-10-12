#!/usr/bin/env python3
"""Enumerate MasterAugur pool balances and token identifiers via public RPC. No secrets."""
import json, urllib.request, time, sys

RPC = "https://polygon-bor-rpc.publicnode.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers=UA)
        for attempt in range(5):
            try:
                resp = json.loads(urllib.request.urlopen(req, timeout=40).read())
                break
            except Exception:
                if attempt == 4: raise
                time.sleep(1.5 * (attempt + 1))
        by_id = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            out.append(r.get("result", {"error": r.get("error")}))
    return out

def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_uint(h):
    if not h or h == "0x": return None
    return int(h, 16)

M = "0x6ad70613d14c34aa69e1604af91c39e0591a132e"

# poolInfo outputs
pool_len = dec_uint(batch([("eth_call", [{"to": M, "data": "0x081e3eda"}, "latest"])])[0])
print("poolLength:", pool_len, file=sys.stderr)

calls = []
for i in range(pool_len):
    data = "0x1526fe27" + hex(i)[2:].rjust(64, "0")
    calls.append(("eth_call", [{"to": M, "data": data}, "latest"]))
res = batch(calls)

pools = []
for i, r in enumerate(res):
    if not isinstance(r, str): 
        print("pool", i, "err", r, file=sys.stderr); continue
    body = r[2:]
    lp = "0x" + body[24:64]
    alloc = int(body[64:128], 16)
    lastReward = int(body[128:192], 16)
    acc = int(body[192:256], 16)
    fee = int(body[256:320], 16)
    pools.append({"pid": i, "lp": lp, "allocPoint": str(alloc), "lastRewardBlock": lastReward, "accOmenPerShare": str(acc), "depositFeeBP": fee})

print(json.dumps(pools, indent=1))
json.dump(pools, open("pools_raw.json", "w"), indent=1)

# balances of lp tokens at farm + totalSupply
calls = []
for p in pools:
    calls.append(("eth_call", [{"to": p["lp"], "data": "0x70a08231" + enc_addr(M)}, "latest"]))
    calls.append(("eth_call", [{"to": p["lp"], "data": "0x18160ddd"}, "latest"]))
res = batch(calls)
for idx, p in enumerate(pools):
    p["farm_balance"] = str(dec_uint(res[2*idx]) if isinstance(res[2*idx], str) else res[2*idx])
    p["lp_totalSupply"] = str(dec_uint(res[2*idx+1]) if isinstance(res[2*idx+1], str) else res[2*idx+1])

# decimals + symbol for each lp
calls = []
for p in pools:
    calls.append(("eth_call", [{"to": p["lp"], "data": "0x313ce567"}, "latest"]))
    calls.append(("eth_call", [{"to": p["lp"], "data": "0x95d89b41"}, "latest"]))
res = batch(calls)
def dec_str(h):
    if not isinstance(h, str) or h == "0x": return None
    b = bytes.fromhex(h[2:])
    if len(b) >= 64:
        ln = int.from_bytes(b[32:64], "big"); return b[64:64+ln].decode("utf8", "replace")
    return b.decode("utf8", "replace").rstrip("\x00")
for idx, p in enumerate(pools):
    d = res[2*idx]; s = res[2*idx+1]
    p["decimals"] = dec_uint(d) if isinstance(d, str) else None
    p["symbol"] = dec_str(s)

json.dump(pools, open("pools_raw.json", "w"), indent=1)
print(json.dumps(pools, indent=1))

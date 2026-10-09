#!/usr/bin/env python3
"""Score all candidate users: getUserAccountData + flags. Read-only RPC batch."""
import json, sys, time
sys.path.insert(0, "/home/heisenberg/CA/yeilend/analysis")
from rpc import rpc, block_number

POOL1 = "0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638"
POOL2 = "0x7b5b1A719d54664657451db7600FD5C3ca0fa136"
SEL_UAD = "0xbf92857c"  # getUserAccountData(address)

def get_users(paths):
    us = set()
    for p in paths:
        try:
            ev = json.load(open(p))
        except Exception:
            continue
        for e in ev:
            t = e.get("topics", [])
            if len(t) >= 3:
                us.add("0x" + t[2][26:])   # onBehalfOf for Borrow
    return sorted(us)

def batch_rpc(calls, chunk=25):
    out = []
    for i in range(0, len(calls), chunk):
        payload = []
        for j, (to, data) in enumerate(calls[i:i+chunk]):
            payload.append({"jsonrpc": "2.0", "id": i + j, "method": "eth_call",
                            "params": [{"to": to, "data": data}, "latest"]})
        import urllib.request
        req = urllib.request.Request("https://evm-rpc.sei-apis.com",
                                     data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            res = json.loads(r.read())
        res.sort(key=lambda x: x["id"])
        out.extend(res)
        if i % 500 == 0:
            print("  ...", i, flush=True)
    return out

def main(prefix):
    users = get_users([f"analysis/events_Borrow_0x4a4d9abD.json", f"analysis/events_Borrow_0x7b5b1A71.json",
                       "analysis/events_Borrow_partial.json"])
    print("candidate users:", len(users))
    blk = block_number()
    calls = [(POOL1, SEL_UAD + u[2:].rjust(64, "0")) for u in users]
    calls += [(POOL2, SEL_UAD + u[2:].rjust(64, "0")) for u in users]
    res = batch_rpc(calls)
    rows = []
    for u in users:
        d1 = res.pop(0); d2 = res.pop(0)
        def dec(r):
            if "result" not in r or not r["result"] or len(r["result"]) < 2 + 64*6:
                return None
            h = r["result"][2:]
            return [int(h[i:i+64], 16) for i in range(0, 64*6, 64)]
        v1 = dec(d1); v2 = dec(d2)
        rows.append({"user": u, "pool1": v1, "pool2": v2})
    json.dump({"block": blk, "rows": rows}, open(f"analysis/accounts_{prefix}.json", "w"), indent=1)
    # summary
    unhealthy1 = [r for r in rows if r["pool1"] and r["pool1"][1] > 0 and r["pool1"][5] < 10**18]
    unhealthy2 = [r for r in rows if r["pool2"] and r["pool2"][1] > 0 and r["pool2"][5] < 10**18]
    print("users with debt pool1:", sum(1 for r in rows if r["pool1"] and r["pool1"][1] > 0))
    print("HF<1 pool1:", len(unhealthy1), " pool2:", len(unhealthy2))
    for r in unhealthy1[:40]:
        v = r["pool1"]
        print(f"  {r['user']} coll={v[0]/1e8:.2f} debt={v[1]/1e8:.2f} HF={v[5]/1e18:.4f}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "partial")

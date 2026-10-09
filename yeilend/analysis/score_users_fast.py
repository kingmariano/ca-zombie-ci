#!/usr/bin/env python3
"""Concurrent user scorer: getUserAccountData for all candidates. Read-only."""
import json, sys, time, urllib.request, concurrent.futures as cf

POOLS = {
    "pool1": "0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638",
    "pool2": "0x7b5b1A719d54664657451db7600FD5C3ca0fa136",
}
URLS = ["https://evm-rpc.sei-apis.com", "https://sei-evm-rpc.publicnode.com"]

def users_from(paths):
    us = set()
    for p in paths:
        try:
            if p.endswith(".jsonl"):
                for l in open(p):
                    e = json.loads(l); us.add("0x" + e["topics"][2][26:])
            else:
                for e in json.load(open(p)):
                    us.add("0x" + e["topics"][2][26:])
        except Exception as ex:
            print("skip", p, ex)
    return sorted(us)

def call_batch(pool, users, url, wid):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": pool, "data": "0xbf92857c" + u[2:].rjust(64, "0")}, "latest"]}
               for i, u in enumerate(users)]
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                res = json.loads(r.read())
            res.sort(key=lambda x: x["id"])
            out = []
            for u, r in zip(users, res):
                v = None
                if isinstance(r.get("result"), str) and len(r["result"]) >= 2 + 64 * 6:
                    h = r["result"][2:]
                    v = [int(h[i:i + 64], 16) for i in range(0, 64 * 6, 64)]
                out.append({"user": u, "v": v})
            return out
        except Exception:
            time.sleep(1 + attempt)
    return [{"user": u, "v": None} for u in users]

def main(paths, out_path):
    users = users_from(paths)
    print("users:", len(users), flush=True)
    jobs = []
    B = 20
    for pool in POOLS.values():
        for i in range(0, len(users), B):
            jobs.append((pool, users[i:i + B]))
    results = {k: {} for k in POOLS}
    t0 = time.time()
    with cf.ThreadPoolExecutor(max_workers=10) as ex:
        futs = []
        for j, (pool, batch) in enumerate(jobs):
            futs.append((pool, ex.submit(call_batch, pool, batch, URLS[j % len(URLS)], j % 10)))
        done = 0
        for pool, f in futs:
            for row in f.result():
                results[[k for k, v in POOLS.items() if v == pool][0]][row["user"]] = row["v"]
            done += 1
            if done % 100 == 0:
                print(f"  {done}/{len(jobs)} batches {time.time()-t0:.0f}s", flush=True)
    json.dump(results, open(out_path, "w"), indent=1)
    print("wrote", out_path)
    # summary
    for pname, d in results.items():
        with_debt = [(u, v) for u, v in d.items() if v and v[1] > 0]
        unhealthy = [(u, v) for u, v in with_debt if v[5] < 10**18]
        print(f"{pname}: scored {len(d)} with_debt {len(with_debt)} HF<1 {len(unhealthy)}")
        for u, v in sorted(unhealthy, key=lambda x: x[1][5])[:50]:
            print(f"   {u} coll=${v[0]/1e8:,.2f} debt=${v[1]/1e8:,.2f} HF={v[5]/1e18:.6f} LT={v[3]/1e4:.2f}%")

if __name__ == "__main__":
    main(sys.argv[2:], sys.argv[1])

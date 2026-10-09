#!/usr/bin/env python3
"""
YeiLend borrower health scan (CI heavy job), v2:
 1. reuse rows already in ci-out/user_scan.jsonl
 2. for the missing users, first screen vToken balances (cheap) on the reserves they ever borrowed
 3. only users with a non-zero debt-token balance get the expensive getUserAccountData call
 4. rebuild summary + flat helper files
Read-only eth_call via public RPC endpoints; no keys.
"""
import gzip, json, os, sys, time, urllib.request
import concurrent.futures as cf

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "ci-out")
os.makedirs(OUT, exist_ok=True)

POOL1 = "0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638"
POOL2 = "0x7b5b1A719d54664657451db7600FD5C3ca0fa136"
URLS = [
    "https://evm-rpc.sei-apis.com",
    "https://sei-evm-rpc.publicnode.com",
    "https://sei.drpc.org",
    "https://1329.rpc.thirdweb.com",
]
SEL_UAD = "0xbf92857c"          # getUserAccountData(address)
SEL_BAL = "0x70a08231"          # balanceOf(address)

def load_json_gz(p):
    with gzip.open(p, "rt") as f:
        return json.load(f)

def call_batch(items, url):
    """items: list of (to, data). Returns list of results (hex or None)."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]} for i, (to, data) in enumerate(items)]
    body = json.dumps(payload).encode()
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, data=body,
                                         headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                res = json.loads(r.read())
            res.sort(key=lambda x: x["id"])
            return [x.get("result") for x in res]
        except Exception:
            if attempt == 3:
                return [None] * len(items)
            time.sleep(1.5 * (attempt + 1))

def parse_uad(r):
    if isinstance(r, str) and len(r) >= 2 + 64 * 6:
        h = r[2:]
        return [int(h[i:i + 64], 16) for i in range(0, 64 * 6, 64)]
    return None

def main():
    t0 = time.time()
    allu = load_json_gz(os.path.join(HERE, "analysis", "all_borrowers.json.gz"))
    reserves = load_json_gz(os.path.join(HERE, "analysis", "user_reserves_pool1.json.gz"))
    vtok = json.load(open(os.path.join(HERE, "analysis", "vtokens.json")))  # asset -> vToken
    scan_path = os.path.join(OUT, "user_scan.jsonl.gz")
    rows = {}
    for cand in (scan_path, os.path.join(OUT, "user_scan.jsonl")):
        if os.path.exists(cand):
            op = gzip.open if cand.endswith(".gz") else open
            with op(cand, "rt") as f:
                for line in f:
                    r = json.loads(line)
                    rows[(r["p"], r["u"])] = r
            break
    print(f"existing rows: {len(rows)}", flush=True)

    done1 = set(u for (p, u) in rows if p == POOL1)
    missing = [u for u in allu if u not in done1]
    print(f"missing users: {len(missing)}", flush=True)
    if not missing:
        print("nothing to scan")
        return summarize(rows)

    # ---- phase 1: cheap balance screen grouped by reserve
    per_res = {}
    for u in missing:
        for a in reserves.get(u, []):
            per_res.setdefault(a, []).append(u)
    jobs = []
    for asset, users in per_res.items():
        vt = vtok.get(asset)
        if not vt:
            continue
        for i in range(0, len(users), 25):
            jobs.append((asset, vt, users[i:i + 25]))
    print(f"balance-screen jobs: {len(jobs)}", flush=True)

    has_debt = set()
    fails = 0
    done = 0
    with cf.ThreadPoolExecutor(max_workers=24) as ex:
        futs = []
        for j, (asset, vt, users) in enumerate(jobs):
            items = [(vt, SEL_BAL + u[2:].rjust(64, "0")) for u in users]
            futs.append((users, ex.submit(call_batch, items, URLS[j % len(URLS)])))
        for users, f in futs:
            res = f.result()
            for u, r in zip(users, res):
                if r is None:
                    fails += 1
                elif isinstance(r, str) and len(r) >= 66 and int(r[2:], 16) > 0:
                    has_debt.add(u)
            done += 1
            if done % 250 == 0:
                print(f"  screen {done}/{len(jobs)} batches, {time.time()-t0:.0f}s, fails={fails}, debtors={len(has_debt)}", flush=True)
    # users with no borrowed-reserve entries at all are clean by construction
    no_res = [u for u in missing if not reserves.get(u)]
    for u in no_res:
        rows[(POOL1, u)] = {"u": u, "p": POOL1, "v": [0, 0, 0, 0, 0, 0]}
    print(f"screen done: debtors={len(has_debt)} fails={fails} no-reserve users={len(no_res)}", flush=True)

    # ---- phase 2: account data for debtors
    debt_users = sorted(has_debt)
    jobs2 = [debt_users[i:i + 10] for i in range(0, len(debt_users), 10)]
    print(f"account-data jobs: {len(jobs2)}", flush=True)
    with cf.ThreadPoolExecutor(max_workers=24) as ex:
        futs = []
        for j, batch in enumerate(jobs2):
            items = [(POOL1, SEL_UAD + u[2:].rjust(64, "0")) for u in batch]
            futs.append((batch, ex.submit(call_batch, items, URLS[j % len(URLS)])))
        done = 0
        for batch, f in futs:
            res = f.result()
            for u, r in zip(batch, res):
                v = parse_uad(r)
                if v is None:
                    fails += 1
                    rows[(POOL1, u)] = {"u": u, "p": POOL1, "v": None}
                else:
                    rows[(POOL1, u)] = {"u": u, "p": POOL1, "v": v}
            done += 1
            if done % 250 == 0:
                print(f"  account {done}/{len(jobs2)} batches, {time.time()-t0:.0f}s", flush=True)
    print(f"scan v2 done in {time.time()-t0:.0f}s, total rows {len(rows)}, fails {fails}", flush=True)

    with gzip.open(scan_path, "wt") as f:
        for r in rows.values():
            f.write(json.dumps(r) + "\n")
    summarize(rows, extra_fails=fails)

def summarize(rows, extra_fails=0):
    pools = {}
    for (p, u), r in rows.items():
        pools.setdefault(p, []).append(r)
    summary = {"fails": extra_fails, "pools": {}}
    for pool, rs in pools.items():
        ok = [r for r in rs if r["v"] is not None]
        with_debt = [r for r in ok if r["v"][1] > 0]
        unhealthy = sorted([r for r in with_debt if r["v"][5] < 10**18], key=lambda r: -r["v"][0])
        summary["pools"][pool] = {
            "scanned": len(ok),
            "with_debt": len(with_debt),
            "unhealthy_count": len(unhealthy),
            "total_collateral_base": sum(r["v"][0] for r in with_debt),
            "total_debt_base": sum(r["v"][1] for r in with_debt),
            "unhealthy": [{"user": r["u"], "collateral_usd": r["v"][0] / 1e8, "debt_usd": r["v"][1] / 1e8,
                           "lt_pct": r["v"][3] / 100, "hf": r["v"][5] / 1e18} for r in unhealthy[:200]],
            "top_debtors": [{"user": r["u"], "collateral_usd": r["v"][0] / 1e8, "debt_usd": r["v"][1] / 1e8,
                             "hf": r["v"][5] / 1e18} for r in sorted(with_debt, key=lambda r: -r["v"][1])[:100]],
        }
    json.dump(summary, open(os.path.join(OUT, "user_scan_summary.json"), "w"), indent=1)
    p1 = summary["pools"].get(POOL1, {})
    json.dump({"count": len(p1.get("unhealthy", [])), "items": [
        {"user": r["user"], "hf": r["hf"], "collateral_usd": r["collateral_usd"], "debt_usd": r["debt_usd"]}
        for r in p1.get("unhealthy", [])]}, open(os.path.join(OUT, "unhealthy_pool1.json"), "w"), indent=1)
    json.dump({"count": len(p1.get("top_debtors", [])), "items": [
        {"user": r["user"], "hf": r["hf"], "collateral_usd": r["collateral_usd"], "debt_usd": r["debt_usd"]}
        for r in p1.get("top_debtors", [])]}, open(os.path.join(OUT, "top_debtors_pool1.json"), "w"), indent=1)
    for pool, s in summary["pools"].items():
        print(f"{pool}: scanned={s['scanned']} with_debt={s['with_debt']} HF<1={s['unhealthy_count']} "
              f"coll=${s['total_collateral_base']/1e8:,.0f} debt=${s['total_debt_base']/1e8:,.0f}", flush=True)
        for r in s["unhealthy"][:15]:
            print(f"   {r['user']} coll=${r['collateral_usd']:,.4f} debt=${r['debt_usd']:,.4f} HF={r['hf']:.6f}", flush=True)

if __name__ == "__main__":
    main()

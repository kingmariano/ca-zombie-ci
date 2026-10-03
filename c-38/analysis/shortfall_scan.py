#!/usr/bin/env python3
"""Scan all Tectonic borrower accounts for current shortfall via getAccountLiquidity(address)."""
import json
import urllib.request
import concurrent.futures as cf
import time

RPC = "https://cronos-evm-rpc.publicnode.com"
UNITROLLER = "0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0"
SEL = "0x5ec88c79"  # getAccountLiquidity(address)


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def rpc_batch(accounts):
    payload = [
        {"jsonrpc": "2.0", "method": "eth_call",
         "params": [{"to": UNITROLLER, "data": SEL + enc_addr(a)}, "latest"], "id": i}
        for i, a in enumerate(accounts)
    ]
    body = json.dumps(payload).encode()
    last = None
    for _ in range(4):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                got = json.loads(r.read())
            by_id = {x.get("id"): x for x in got}
            out = []
            for i in range(len(accounts)):
                it = by_id.get(i, {})
                if "result" in it and isinstance(it["result"], str) and len(it["result"]) >= 2 + 64 * 3:
                    b = bytes.fromhex(it["result"][2:])
                    out.append({
                        "err": int.from_bytes(b[0:32], "big"),
                        "liquidity": int.from_bytes(b[32:64], "big"),
                        "shortfall": int.from_bytes(b[64:96], "big"),
                    })
                else:
                    out.append({"err": None, "raw": it.get("error", it.get("result"))})
            return out
        except Exception as e:
            last = str(e)
            time.sleep(1.0)
    return [{"err": None, "raw": last} for _ in accounts]


def main():
    d = json.load(open("subgraph_borrowers.json"))
    accounts = sorted(set(x["account"]["id"] for x in d["borrowers"]))
    print(f"accounts: {len(accounts)}")
    chunks = [accounts[i:i + 10] for i in range(0, len(accounts), 10)]
    results = {}
    done = 0
    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(rpc_batch, c): c for c in chunks}
        for fut in cf.as_completed(futs):
            c = futs[fut]
            try:
                res = fut.result()
            except Exception as e:
                res = [{"err": None, "raw": str(e)}] * len(c)
            for a, r in zip(c, res):
                results[a] = r
            done += 1
            if done % 50 == 0:
                print(f"  {done}/{len(chunks)} batches", flush=True)
    bad = sum(1 for r in results.values() if r.get("err") is None)
    short = {a: r for a, r in results.items() if r.get("shortfall", 0) > 0}
    print(f"failed reads: {bad}; accounts with shortfall>0: {len(short)}")
    tot = sum(r["shortfall"] for r in short.values()) / 1e18
    print(f"total shortfall USD: {tot:,.2f}")
    top = sorted(short.items(), key=lambda kv: -kv[1]["shortfall"])[:60]
    for a, r in top:
        print(f"{a} shortfall=${r['shortfall']/1e18:,.2f} liquidity=${r['liquidity']/1e18:,.2f}")
    json.dump(results, open("shortfall_scan.json", "w"), indent=1)
    json.dump({a: r for a, r in short.items()}, open("shortfall_accounts.json", "w"), indent=1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Full sweep of code 31 (EvolvNFT factory, ~17.8k instances) — the one code whose
pagination is unstable in the main enumeration. Fetches every instance address and its
bank balances, checks a sample of contract_info for admin/label, and summarizes value.

Writes code31_contracts.json / code31_balances.json / code31_summary.json to ci-out/.
"""
import json, os, time, urllib.request, urllib.parse, concurrent.futures as cf
from collections import defaultdict

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
LCD = "https://api.mainnet.archway.io"
UA = {"User-Agent": "Mozilla/5.0 (zombie-hunt-ci; read-only research)"}
CONC = 30

def get(url, tries=6, timeout=60):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except Exception as e:
            last = e
            time.sleep(0.5 * (i + 1))
    return {"_error": str(last)}

def main():
    # 1. full address list (no height pin; robust retries)
    addrs = []; key = None; pages = 0
    while pages < 500:
        u = f"{LCD}/cosmwasm/wasm/v1/code/31/contracts?pagination.limit=100"
        if key:
            u += "&pagination.key=" + urllib.parse.quote(key)
        d = get(u)
        if "contracts" not in d:
            print("stop page", pages, str(d)[:120], flush=True); break
        addrs += d["contracts"]; pages += 1
        key = (d.get("pagination") or {}).get("next_key")
        if not key:
            break
    print("code31 addresses:", len(addrs), "pages:", pages, flush=True)
    json.dump(addrs, open(os.path.join(D, "code31_contracts.json"), "w"))

    # 2. balances for all instances
    def bal(a):
        d = get(f"{LCD}/cosmos/bank/v1beta1/balances/{a}?pagination.limit=1000")
        return a, d.get("balances", [])
    bals = {}
    with cf.ThreadPoolExecutor(CONC) as ex:
        for n, (a, b) in enumerate(ex.map(bal, addrs)):
            bals[a] = b
            if n and n % 4000 == 0:
                print("balances:", n, flush=True)
    json.dump(bals, open(os.path.join(D, "code31_balances.json"), "w"))

    # 3. sample contract_info (first 30 + 30 random)
    import random
    sample = addrs[:30] + (random.sample(addrs, 30) if len(addrs) > 60 else addrs[30:])
    infos = {}
    for a in sample:
        d = get(f"{LCD}/cosmwasm/wasm/v1/contract/{a}")
        ci = d.get("contract_info", {})
        infos[a] = {"admin": ci.get("admin"), "label": ci.get("label"), "code_id": ci.get("code_id")}
    json.dump(infos, open(os.path.join(D, "code31_sample_infos.json"), "w"))

    # 4. summary
    tot = defaultdict(float)
    withbal = 0
    top = []
    for a, b in bals.items():
        s = 0.0
        for x in b:
            tot[x["denom"]] += float(x["amount"])
            s += float(x["amount"])
        if s > 0:
            withbal += 1
            top.append((s, a, b))
    top.sort(reverse=True)
    admins = {i.get("admin") for i in infos.values()}
    summary = {
        "code_id": 31, "n_instances": len(addrs), "n_with_balance": withbal,
        "totals_by_denom": dict(tot),
        "sample_admins": sorted(x for x in admins if x is not None),
        "sample_labels": sorted({i.get("label") for i in infos.values()}),
        "top_holders": [{"addr": a, "balances": b} for _, a, b in top[:20]],
        "pagination_pages": pages,
    }
    json.dump(summary, open(os.path.join(D, "code31_summary.json"), "w"), indent=1)
    print(json.dumps({k: v for k, v in summary.items() if k != "top_holders"}, indent=1)[:2000])

if __name__ == "__main__":
    main()

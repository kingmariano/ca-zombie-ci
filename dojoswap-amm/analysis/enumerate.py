#!/usr/bin/env python3
"""dojoswap-amm live enumeration (read-only, public LCDs only).

- Enumerates all pairs from factory inj1pc2vxcmnyzawnwkf03n2ggvt997avtuwagqngk
- Queries each pair's pool state {assets, total_share}
- Cross-checks against /cosmwasm/wasm/v1/code/290/contracts
- Dumps bank balances of factory + fee collector
Never writes secrets. Output: pairs-live.json
"""
import json, base64, time, sys, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

LCDS = [
    "https://injective-api.polkachu.com",
    "https://injective-rest.publicnode.com",
    "https://rest.cosmos.directory/injective",
]
FACTORY = "inj1pc2vxcmnyzawnwkf03n2ggvt997avtuwagqngk"
FEE_COLLECTOR = "inj18xg2xfhv36v4z7dr3ldqnm43fzukqgsafyyg63"

def get(path, timeout=30):
    last = None
    for lcd in LCDS:
        try:
            req = urllib.request.Request(lcd + path, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
            continue
    raise RuntimeError(f"all LCDs failed for {path}: {last}")

def cwq(contract, query):
    b64 = base64.b64encode(json.dumps(query, separators=(",", ":")).encode()).decode()
    d = get(f"/cosmwasm/wasm/v1/contract/{contract}/smart/{b64}")
    return d.get("data", d)

def height():
    d = get("/cosmos/base/tendermint/v1beta1/blocks/latest")
    return int(d["block"]["header"]["height"])

def main():
    t0 = time.time()
    h0 = height()
    print(f"[start] height={h0}", flush=True)

    # 1. all pairs from factory
    pairs, start_after = [], None
    while True:
        q = {"pairs": {"limit": 30}}
        if start_after:
            q["pairs"]["start_after"] = start_after
        d = cwq(FACTORY, q)
        page = d["pairs"]
        if not page:
            break
        pairs.extend(page)
        start_after = page[-1]["asset_infos"]
        print(f"[pairs] {len(pairs)}", flush=True)
        if len(page) < 30:
            break
    print(f"[pairs] total {len(pairs)}", flush=True)

    # 2. cross-check code-290 contract list
    code290, next_key = [], None
    while True:
        p = "/cosmwasm/wasm/v1/code/290/contracts?pagination.limit=100"
        if next_key:
            p += "&pagination.key=" + urllib.parse.quote(next_key)
        d = get(p)
        code290.extend(d.get("contracts", []))
        next_key = (d.get("pagination") or {}).get("next_key")
        if not next_key:
            break
    print(f"[code290] total {len(code290)}", flush=True)

    factory_set = {p["contract_addr"] for p in pairs}
    code_set = set(code290)
    print(f"[diff] in factory not code290: {len(factory_set - code_set)}; "
          f"in code290 not factory: {len(code_set - factory_set)}", flush=True)

    # 3. pool state per pair
    def pool_state(addr):
        try:
            d = cwq(addr, {"pool": {}})
            return {"contract": addr, "pool": d}
        except Exception as e:
            return {"contract": addr, "error": str(e)}

    with ThreadPoolExecutor(max_workers=4) as ex:
        pools = list(ex.map(pool_state, [p["contract_addr"] for p in pairs]))
    errs = [p for p in pools if "error" in p]
    print(f"[pools] done, errors={len(errs)}", flush=True)

    # 4. balances of factory + fee collector
    def all_balances(addr):
        out, key = [], None
        while True:
            path = f"/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200"
            if key:
                path += "&pagination.key=" + urllib.parse.quote(key)
            d = get(path)
            out.extend(d.get("balances", []))
            key = (d.get("pagination") or {}).get("next_key")
            if not key:
                break
        return out

    h1 = height()
    result = {
        "generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "lcds_used": LCDS,
        "height_start": h0,
        "height_end": h1,
        "factory": FACTORY,
        "fee_collector": FEE_COLLECTOR,
        "pair_count_factory": len(pairs),
        "pair_count_code290": len(code290),
        "only_in_factory": sorted(factory_set - code_set),
        "only_in_code290": sorted(code_set - factory_set),
        "pairs": pairs,
        "pools": pools,
        "factory_balances": all_balances(FACTORY),
        "fee_collector_balances": all_balances(FEE_COLLECTOR),
    }
    with open("pairs-live.json", "w") as f:
        json.dump(result, f, indent=1)
    print(f"[done] {time.time()-t0:.0f}s height {h0}->{h1}", flush=True)

if __name__ == "__main__":
    import urllib.parse
    main()

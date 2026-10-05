#!/usr/bin/env python3
"""Enumerate Loop Finance and White Whale JUNO pools on juno-1. Read-only."""
import json, time, urllib.request, base64, sys

LCD = "https://juno-api.polkachu.com"
UA = "Mozilla/5.0 (X11; Linux x86_64) verification-research"

def get(path):
    req = urllib.request.Request(LCD + path, headers={"User-Agent": UA})
    for a in range(3):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print(f"retry {a+1}: {e}", file=sys.stderr)
            time.sleep(2)
    raise RuntimeError(path)

def smart(contract, query):
    b = base64.b64encode(json.dumps(query).encode()).decode().replace("+", "-").replace("/", "_")
    return get(f"/cosmwasm/wasm/v1/contract/{contract}/smart/{b}")

def denom_of(info):
    if not isinstance(info, dict):
        return str(info)
    nt = info.get("native_token") or {}
    if nt.get("denom"):
        return nt["denom"]
    if info.get("native"):
        return info["native"]
    tok = info.get("token")
    if isinstance(tok, str):
        return tok
    if isinstance(tok, dict) and tok.get("contract_addr"):
        return tok["contract_addr"]
    return str(info)

def enumerate_factory(name, factory, outfile, max_pairs=500):
    pairs = []
    start_after = None
    for i in range(30):
        q = {"pairs": {"limit": 30}}
        if start_after:
            q["pairs"]["start_after"] = start_after
        d = smart(factory, q)
        batch = d.get("data", {}).get("pairs", [])
        pairs.extend(batch)
        print(f"{name}: page {i+1}: {len(batch)}", file=sys.stderr)
        if len(batch) < 30 or len(pairs) >= max_pairs:
            break
        start_after = batch[-1]["asset_infos"]
        time.sleep(0.25)

    juno_pairs = []
    for p in pairs:
        infos = p.get("asset_infos", [])
        if not any(denom_of(i) == "ujuno" for i in infos):
            continue
        time.sleep(0.25)
        try:
            pool = smart(p["contract_addr"], {"pool": {}}).get("data", {})
        except Exception as e:
            print(f"  {name} pool fail {p['contract_addr']}: {e}", file=sys.stderr)
            continue
        juno_res = other_res = None
        other_denom = None
        assets = pool.get("assets") or []
        for a in assets:
            info = a.get("info") if isinstance(a.get("info"), dict) else a
            dn = denom_of(info)
            amt = int(a.get("amount", 0))
            if dn == "ujuno":
                juno_res = amt
            else:
                other_res = amt
                other_denom = dn
        if juno_res is None and "reserve0" in pool:
            d0 = denom_of(infos[0])
            if d0 == "ujuno":
                juno_res, other_res = int(pool["reserve0"]), int(pool["reserve1"])
            else:
                juno_res, other_res = int(pool["reserve1"]), int(pool["reserve0"])
            other_denom = denom_of(infos[1] if d0 == "ujuno" else infos[0])
        if juno_res is None:
            print(f"  {name} UNPARSED {p['contract_addr']}: {json.dumps(pool)[:150]}", file=sys.stderr)
            continue
        juno_pairs.append({"pair": p["contract_addr"], "juno_ujuno": juno_res,
                           "juno": juno_res / 1e6, "other_denom": other_denom,
                           "other_amount": other_res})

    juno_pairs.sort(key=lambda x: -x["juno_ujuno"])
    total = sum(j["juno_ujuno"] for j in juno_pairs) / 1e6
    print(f"{name}: total pairs {len(pairs)}, JUNO pairs {len(juno_pairs)}, total JUNO {total:.6f}", file=sys.stderr)
    for j in juno_pairs:
        print(f"  {j['pair']} juno={j['juno']:.4f} other={str(j['other_denom'])[:60]} amt={j['other_amount']}")
    with open(outfile, "w") as f:
        json.dump({"factory": factory, "total_pairs": len(pairs), "juno_pairs": juno_pairs,
                   "juno_total": total}, f, indent=1)
    return total

t1 = enumerate_factory("loop", "juno1p4dmvjtdf3qw9394k7zl65eg8g5ehzvdxnvm9hd3ju7a7aslrmdqaspeak",
                       "loop_juno_pools.json")
t2 = enumerate_factory("whitewhale", "juno14m9rd2trjytvxvu4ldmqvru50ffxsafs8kequmfky7jh97uyqrxqs5xrnx",
                       "whitewhale_juno_pools.json")
print(f"LOOP {t1:.6f} + WHITEWHALE {t2:.6f}")

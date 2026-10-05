#!/usr/bin/env python3
"""Enumerate WYND DEX pairs on juno-1 and their ujuno reserves. Read-only LCD pulls.
Dumps raw pool responses first, then parses both wynd asset formats."""
import json, time, urllib.request, base64, sys

LCD = "https://juno-api.polkachu.com"
UA = "Mozilla/5.0 (X11; Linux x86_64) verification-research"
FACTORY = "juno16adshp473hd9sruwztdqrtsfckgtd69glqm6sqk0hc4q40c296qsxl3u3s"

def get(path):
    req = urllib.request.Request(LCD + path, headers={"User-Agent": UA})
    for a in range(3):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print(f"retry {a+1} {path[:80]}: {e}", file=sys.stderr)
            time.sleep(2)
    raise RuntimeError(path)

def smart(contract, query):
    b = base64.b64encode(json.dumps(query).encode()).decode()
    b = b.replace("+", "-").replace("/", "_")
    return get(f"/cosmwasm/wasm/v1/contract/{contract}/smart/{b}")

pairs = smart(FACTORY, {"pairs": {"limit": 100}})["data"]["pairs"]
print(f"total pairs: {len(pairs)}", file=sys.stderr)

raw_pools = []
juno_pairs = []
for p in pairs:
    infos = p.get("asset_infos", [])
    has_juno = any((i.get("native") == "ujuno" or
                    (i.get("native_token") or {}).get("denom") == "ujuno") for i in infos)
    if not has_juno:
        continue
    time.sleep(0.25)
    try:
        pool = smart(p["contract_addr"], {"pool": {}}).get("data", {})
    except Exception as e:
        print(f"  pool query failed {p['contract_addr']}: {e}", file=sys.stderr)
        continue
    raw_pools.append({"pair": p["contract_addr"], "asset_infos": infos, "pool": pool})
    # flexible parse
    juno_res = other_res = None
    other_denom = None
    if "assets" in pool:
        for a in pool["assets"]:
            info = a.get("info") if isinstance(a.get("info"), (dict,)) else a
            if isinstance(info, str):
                denom = info
            else:
                denom = info.get("native") or (info.get("native_token") or {}).get("denom")
                if not denom:
                    tok = info.get("token")
                    denom = tok if isinstance(tok, str) else (tok or {}).get("contract_addr")
                if not denom:
                    denom = str(info)
            amt = int(a.get("amount", 0))
            if denom == "ujuno":
                juno_res = amt
            else:
                other_res = amt
                other_denom = denom
    elif "reserve0" in pool:
        # figure orientation from asset_infos
        d0 = (infos[0].get("native") or (infos[0].get("native_token") or {}).get("denom")
              or infos[0].get("token", {}).get("contract_addr"))
        if d0 == "ujuno":
            juno_res, other_res = int(pool["reserve0"]), int(pool["reserve1"])
            other_denom = (infos[1].get("native") or (infos[1].get("native_token") or {}).get("denom")
                           or infos[1].get("token", {}).get("contract_addr"))
        else:
            juno_res, other_res = int(pool["reserve1"]), int(pool["reserve0"])
            other_denom = d0
    if juno_res is None:
        print(f"  UNPARSED {p['contract_addr']}: {json.dumps(pool)[:200]}", file=sys.stderr)
        continue
    juno_pairs.append({
        "pair": p["contract_addr"],
        "liquidity_token": p.get("liquidity_token"),
        "juno_ujuno": juno_res,
        "juno": juno_res / 1e6,
        "other_denom": other_denom,
        "other_amount": other_res,
    })

juno_pairs.sort(key=lambda x: -x["juno_ujuno"])
total = sum(j["juno_ujuno"] for j in juno_pairs) / 1e6
print(f"WYND JUNO pairs: {len(juno_pairs)}, total JUNO = {total:.6f}", file=sys.stderr)
for j in juno_pairs:
    print(f"  {j['pair']} juno={j['juno']:.2f} other={str(j['other_denom'])[:50]} amt={j['other_amount']}")

with open("wynd_juno_pools.json", "w") as f:
    json.dump({"factory": FACTORY, "total_pairs": len(pairs), "juno_pairs": juno_pairs,
               "juno_total": total}, f, indent=1)
with open("wynd_raw_pools.json", "w") as f:
    json.dump(raw_pools, f, indent=1)
print(f"WYND TOTAL JUNO = {total:.6f}")

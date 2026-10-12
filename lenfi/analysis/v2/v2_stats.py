#!/usr/bin/env python3
"""V2 deep stats: pool balances/LP, pool-NFT custody, registries vs liquidation leftovers."""
import json, time, urllib.request, sys, cbor2
from collections import Counter, defaultdict

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
KOIOS = "https://api.koios.rest/api/v1"
POOL_SH = "32e8c0ae314ef4be452c16a999867f66d1a1791fc972cb2f7c74e38d"
COLL_SH = "8021830afedd85fda1253da2be75b66c0e65c482148eb8ca690903cb"
LEFTOVER_SH = "9b99fef5ee9a6b170a418999e89edad93bbf55bf1feef57b6053d634"


def post(path, body, retries=4):
    for i in range(retries):
        try:
            req = urllib.request.Request(f"{KOIOS}{path}", data=json.dumps(body).encode(),
                                         headers={"Content-Type": "application/json", "User-Agent": "readonly/1.0"}, method="POST")
            return json.loads(urllib.request.urlopen(req, timeout=120).read())
        except Exception as e:
            print("retry", path, e, file=sys.stderr)
            time.sleep(3 * (i + 1))
    raise RuntimeError(path)


def dd(x):
    if isinstance(x, cbor2.CBORTag):
        t = x.tag
        if 121 <= t <= 127: return {"c": t - 121, "f": [dd(v) for v in x.value]}
        if 1280 <= t <= 1400: return {"c": t - 1280 + 7, "f": [dd(v) for v in x.value]}
        return {"tag": t}
    if isinstance(x, (bytes, bytearray)): return {"bytes": bytes(x).hex()}
    if isinstance(x, bool): return {"bool": x}
    if isinstance(x, int): return {"int": x}
    if isinstance(x, list): return {"list": [dd(v) for v in x]}
    if isinstance(x, dict): return {"map": [[dd(k), dd(v)] for k, v in x.items()]}
    return {"?": repr(x)}


ut = json.load(open(f"{D}/v2_all_utxos.json"))
# 1) pool UTxOs with assets (extended)
pool_addrs = sorted({u["address"] for u in ut if u["address"].startswith("addr1xyew3s9wx")})
print("pool addresses:", len(pool_addrs))
ext = []
for i in range(0, len(pool_addrs), 8):
    ext += post("/address_utxos", {"_addresses": pool_addrs[i:i + 8], "_extended": True})
    time.sleep(0.3)
adm = defaultdict(list)
for u in ext:
    for a in (u.get("asset_list") or []):
        adm[a["asset_name"]].append((u["address"], a["quantity"]))
print("distinct assets on pool UTxOs:", len(adm))
for name, lst in list(adm.items())[:8]:
    print("   asset", name[:16], "instances", len(lst), "sample", lst[0])
pool_nft_names = [n for n in adm if len(n) == 56]
print("56-hex asset names (pool NFTs/LP):", len(pool_nft_names))

# 2) pool datum stats (balance/lent/lp) from v2_all_utxos (datums resolved inline or hash)
need = [u for u in ut if not u.get("inline_datum") and u.get("datum_hash")]
datums = {}
for i in range(0, len(need), 25):
    r = post("/datum_info", {"_datum_hashes": [u["datum_hash"] for u in need[i:i + 25]]})
    for x in r:
        datums[x["datum_hash"]] = x.get("bytes")
    time.sleep(0.3)
stats = {"n_pools": 0, "sum_balance": 0, "sum_lent": 0, "sum_lp": 0, "sum_ada": 0.0, "max_balance": 0, "pools_with_lp": 0}
rows = []
for u in ut:
    if not u["address"].startswith("addr1xyew3s9wx"):
        continue
    hx = u["inline_datum"]["bytes"] if isinstance(u.get("inline_datum"), dict) else u["inline_datum"] or datums.get(u.get("datum_hash"))
    if not hx:
        continue
    try:
        d = dd(cbor2.loads(bytes.fromhex(hx)))
    except Exception:
        continue
    f = d.get("f", [])
    if d.get("c") == 0 and len(f) == 4 and f[0].get("c") == 0 and len(f[0].get("f", [])) == 8:
        balance = f[1].get("int") or 0
        lent = f[2].get("int") or 0
        lp = f[3].get("int") or 0
        stats["n_pools"] += 1
        stats["sum_balance"] += balance
        stats["sum_lent"] += lent
        stats["sum_lp"] += lp
        stats["sum_ada"] += int(u["value"]) / 1e6
        stats["max_balance"] = max(stats["max_balance"], balance)
        if lp:
            stats["pools_with_lp"] += 1
        rows.append({"tx": u["tx_hash"][:16], "ix": u["tx_index"], "ada": int(u["value"]) / 1e6,
                     "balance": balance, "lent": lent, "lp": lp})
print("pool stats:", json.dumps({k: (round(v, 2) if isinstance(v, float) else v) for k, v in stats.items()}, indent=1))

# 3) registries vs liquidation leftovers split (leftovers_cred 2-field datums)
reg = {"n": 0, "ada": 0.0}
liq = {"n": 0, "ada": 0.0}
other = {"n": 0, "ada": 0.0}
for u in ut:
    if not (u["address"].startswith("addr1wxdenlh") or u["address"].startswith("addr1xxdenlh")):
        continue
    hx = u["inline_datum"]["bytes"] if isinstance(u.get("inline_datum"), dict) else u["inline_datum"] or datums.get(u.get("datum_hash"))
    v = int(u["value"]) / 1e6
    if not hx:
        other["n"] += 1; other["ada"] += v; continue
    try:
        d = dd(cbor2.loads(bytes.fromhex(hx)))
    except Exception:
        other["n"] += 1; other["ada"] += v; continue
    if d.get("c") == 0 and len(d.get("f", [])) == 2 and d["f"][0].get("bytes") == POOL_SH:
        reg["n"] += 1; reg["ada"] += v
    elif d.get("c") == 0 and len(d.get("f", [])) == 2 and d["f"][0].get("bytes") == COLL_SH:
        liq["n"] += 1; liq["ada"] += v
    else:
        other["n"] += 1; other["ada"] += v
print("registries:", reg, "\nliquidation leftovers:", liq, "\nother:", other)

# 4) pool NFT policy supply
ai = post("/asset_info", {"_asset_list": [[POOL_SH, n] for n in pool_nft_names[:40]]}) if pool_nft_names else []
print("pool NFT asset_info entries:", len(ai))
minted = sum(int(a.get("total_supply") or 0) for a in ai)
burns = sum(int(a.get("burn_cnt") or 0) for a in ai)
print("pool NFTs: minted(total_supply sum)", minted, "burn_cnt sum", burns)
json.dump({"pool_stats": stats, "registries": reg, "liquidation_leftovers": liq, "other": other,
           "pool_rows": rows, "asset_info": ai}, open(f"{D}/v2_stats.json", "w"), indent=1)

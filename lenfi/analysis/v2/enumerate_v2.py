#!/usr/bin/env python3
"""Enumerate the V2 (Aiken) Lenfi addresses properly: pool / leftovers / collateral credential address sets
(stake-enabled variants were missed by the triage). Decode datums, classify, and value."""
import json, time, urllib.request, sys, cbor2
from collections import Counter, defaultdict

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
KOIOS = "https://api.koios.rest/api/v1"


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


addrs = {}
for f, label in [("koios_pool_addresses_info.json", "pool_cred"),
                 ("koios_leftovers_addresses_info.json", "leftovers_cred"),
                 ("koios_collateral_addresses_info.json", "collateral_cred")]:
    try:
        for e in json.load(open(f"{D}/{f}")):
            addrs[e["address"]] = label
    except Exception as ex:
        print("skip", f, ex)
print("addresses:", len(addrs))
al = sorted(addrs)
utxos = []
for i in range(0, len(al), 8):
    r = post("/address_utxos", {"_addresses": al[i:i + 8], "_extended": False})
    utxos += r
    time.sleep(0.3)
json.dump(utxos, open(f"{D}/v2_all_utxos.json", "w"), indent=1)
print("utxos:", len(utxos), "total ADA:", sum(int(u['value']) for u in utxos) / 1e6)

# resolve datum witnesses for V2 (inline mostly?)
need = [u for u in utxos if not u.get("inline_datum") and u.get("datum_hash")]
datums = {}
for i in range(0, len(need), 25):
    r = post("/datum_info", {"_datum_hashes": [u["datum_hash"] for u in need[i:i + 25]]})
    for x in r:
        datums[x["datum_hash"]] = x.get("bytes")
    time.sleep(0.3)

POOL_SH = "32e8c0ae314ef4be452c16a999867f66d1a1791fc972cb2f7c74e38d"
LEFTOVER_SH = "9b99fef5ee9a6b170a418999e89edad93bbf55bf1feef57b6053d634"
COLL_SH = "8021830afedd85fda1253da2be75b66c0e65c482148eb8ca690903cb"

kind = defaultdict(lambda: {"n": 0, "ada": 0.0, "assets": Counter()})
samples = {}
for u in utxos:
    cls = addrs.get(u["address"], "?")
    hx = None
    if isinstance(u.get("inline_datum"), dict):
        hx = u["inline_datum"].get("bytes")
    elif u.get("datum_hash"):
        hx = datums.get(u["datum_hash"])
    d = None
    if hx:
        try:
            d = dd(cbor2.loads(bytes.fromhex(hx)))
        except Exception:
            d = None
    if d is None:
        k = f"{cls}:NO_DATUM"
    elif d.get("c") == 0 and len(d.get("f", [])) == 0:
        k = f"{cls}:carrier(unit)"
    elif d.get("c") == 0 and len(d.get("f", [])) == 4:
        k = f"{cls}:datum4fields"
    elif d.get("c") == 0 and len(d.get("f", [])) == 1:
        k = f"{cls}:datum1field"
    elif d.get("c") == 0 and len(d.get("f", [])) == 2:
        k = f"{cls}:datum2fields"
    else:
        k = f"{cls}:other(c={d.get('c')},n={len(d.get('f', []))})"
    kind[k]["n"] += 1
    kind[k]["ada"] += int(u["value"]) / 1e6
    for a in (u.get("asset_list") or []):
        kind[k]["assets"][a["asset_name"][:12]] += int(a["quantity"])
    if k not in samples and hx:
        samples[k] = {"addr": u["address"], "value": int(u["value"]) / 1e6, "datum_head": hx[:220]}

print("\n=== V2 breakdown ===")
out = {}
for k, v in sorted(kind.items()):
    out[k] = {"n": v["n"], "ada": round(v["ada"], 2), "assets": dict(v["assets"])}
    print(f"{k:34s} n={v['n']:4d} ada={v['ada']:10.2f} assets={dict(list(v['assets'].items())[:4])}")
json.dump({"breakdown": out, "samples": samples}, open(f"{D}/v2_breakdown.json", "w"), indent=1)
for k, s in list(samples.items())[:4]:
    print("\n", k, "->", json.dumps(s)[:400])

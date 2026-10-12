#!/usr/bin/env python3
"""Enrich the live UTxO set: resolve datum witnesses via Koios /datum_info, decode PlutusData,
summarize per address and per validator class."""
import json, os, sys, time, urllib.request
from collections import defaultdict

KOIOS = "https://api.koios.rest/api/v1"
HDR = {"Content-Type": "application/json", "User-Agent": "readonly-research/1.0"}
import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))


def post(path, body, retries=4):
    for i in range(retries):
        try:
            req = urllib.request.Request(f"{KOIOS}{path}", data=json.dumps(body).encode(), headers=HDR, method="POST")
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read())
        except Exception as e:
            print(f"  retry {i+1} {path}: {e}", file=sys.stderr)
            time.sleep(3 * (i + 1))
    raise RuntimeError(f"failed {path}")


utxos = json.load(open(f"{D}/koios_address_utxos.json"))
dec = json.load(open(f"{D}/addresses_decoded.json"))
addr2name = {}
for k, v in dec["base_script_addresses"].items():
    addr2name[v["bech32"]] = k
for k, v in dec["bare_script_hashes"].items():
    addr2name[v["enterprise_address"]] = k
for k, v in dec["other"].items():
    addr2name[v["bech32"]] = k

# 1. collect datum hashes
hashes = sorted({u["datum_hash"] for u in utxos if u.get("datum_hash")})
print("distinct datum hashes:", len(hashes))
datums = {}
for i in range(0, len(hashes), 25):
    batch = hashes[i:i + 25]
    res = post("/datum_info", {"_datum_hashes": batch})
    for r in res:
        datums[r["datum_hash"]] = r.get("bytes")
    print(f"  datum batch {i//100}: got {len(res)}")
json.dump(datums, open(f"{D}/koios_datums.json", "w"), indent=1)

# 2. reference scripts (on-chain script bytes)
scripts = {}
for u in utxos:
    rs = u.get("reference_script")
    if rs:
        scripts[rs["hash"]] = rs
json.dump(scripts, open(f"{D}/koios_reference_scripts.json", "w"), indent=1)
print("distinct reference scripts:", len(scripts))
for h, s in scripts.items():
    open(f"{D}/script_{h}.hex", "w").write(s["bytes"])
    print("  ", h, s["type"], "size", s["size"])

# 3. per-address summary
summary = defaultdict(lambda: {"utxo_count": 0, "lovelace": 0, "assets": defaultdict(int), "datum_kinds": defaultdict(int)})
for u in utxos:
    name = addr2name.get(u["address"], u["address"])
    s = summary[name]
    s["utxo_count"] += 1
    s["lovelace"] += int(u["value"])
    for a in (u.get("asset_list") or []):
        key = a["policy_id"] + "." + a["asset_name"]
        s["assets"][key] += int(a["quantity"])
    s["datum_kinds"]["inline" if u.get("inline_datum") else ("hash" if u.get("datum_hash") else "none")] += 1

out = {}
for name, s in summary.items():
    out[name] = {
        "utxo_count": s["utxo_count"],
        "ada": s["lovelace"] / 1e6,
        "assets": {k: v for k, v in sorted(s["assets"].items(), key=lambda kv: -kv[1])},
        "datum_kinds": dict(s["datum_kinds"]),
    }
json.dump(out, open(f"{D}/live_summary_by_address.json", "w"), indent=1)
print(json.dumps(out, indent=1))

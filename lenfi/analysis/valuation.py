#!/usr/bin/env python3
"""Price the live Lenfi custody: ADA + tokens via DefiLlama (keyless), using Cardano fingerprints."""
import json, time, urllib.request, urllib.parse, sys
from collections import defaultdict

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))


def http(url, timeout=60, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "readonly-research/1.0"})
            return json.loads(urllib.request.urlopen(req, timeout=timeout).read())
        except Exception as e:
            print("retry", url[:80], e, file=sys.stderr)
            time.sleep(2 * (i + 1))
    return {}


utxos = json.load(open(f"{D}/koios_address_utxos.json"))
dec = json.load(open(f"{D}/addresses_decoded.json"))
addr2name = {}
for k, v in dec["base_script_addresses"].items():
    addr2name[v["bech32"]] = k
for k, v in dec["bare_script_hashes"].items():
    addr2name[v["enterprise_address"]] = k
for k, v in dec["other"].items():
    addr2name[v["bech32"]] = k

# collect per (address class, fingerprint) quantities + decimals, and fingerprints map (policy.name -> fp)
qty = defaultdict(int)
decimals = {}
fp_by_unit = {}
for u in utxos:
    cls = addr2name.get(u["address"], u["address"])
    for a in (u.get("asset_list") or []):
        unit = a["policy_id"] + "." + a["asset_name"]
        fp = a["fingerprint"]
        qty[(cls, fp)] += int(a["quantity"])
        decimals[fp] = int(a.get("decimals") or 0)
        fp_by_unit[unit] = fp

fps = sorted({fp for (_, fp) in qty})
print("distinct token fingerprints:", len(fps))

prices = {}
for i in range(0, len(fps), 40):
    chunk = fps[i:i + 40]
    enc = ",".join(urllib.parse.quote("cardano:" + f, safe="") for f in chunk)
    r = http("https://coins.llama.fi/prices/current/" + enc)
    for k, v in (r.get("coins") or {}).items():
        prices[k.split("cardano:", 1)[1]] = v.get("price")
    time.sleep(0.5)

ada_price = prices.get("ada")
if ada_price is None:
    r = http("https://coins.llama.fi/prices/current/coingecko:cardano")
    ada_price = (r.get("coins") or {}).get("coingecko:cardano", {}).get("price")
print("ADA price:", ada_price)

out = defaultdict(lambda: {"ada": 0.0, "ada_usd": 0.0, "tokens": {}, "tokens_usd": {}, "usd": 0.0})
missing = set()
for u in utxos:
    cls = addr2name.get(u["address"], u["address"])
    lovelace = int(u["value"]) / 1e6
    out[cls]["ada"] += lovelace
    out[cls]["ada_usd"] += lovelace * (ada_price or 0)
    for a in (u.get("asset_list") or []):
        unit = a["policy_id"] + "." + a["asset_name"]
        fp = a["fingerprint"]
        amt = int(a["quantity"]) / (10 ** decimals[fp])
        out[cls]["tokens"][unit] = out[cls]["tokens"].get(unit, 0) + amt
        p = prices.get(fp)
        if p is None:
            missing.add(fp)
        else:
            out[cls]["tokens_usd"][unit] = out[cls]["tokens_usd"].get(unit, 0) + amt * p
    out[cls]["usd"] = out[cls]["ada_usd"] + sum(out[cls]["tokens_usd"].values())

tot_ada = sum(v["ada"] for v in out.values())
tot_usd = sum(v["usd"] for v in out.values())
report = {"ada_price_usd": ada_price, "by_class": {}, "total_ada": tot_ada, "total_usd": tot_usd,
          "unpriced_fingerprints": sorted(missing)}
for cls, v in sorted(out.items()):
    report["by_class"][cls] = {
        "ada": round(v["ada"], 3), "ada_usd": round(v["ada_usd"], 2), "usd": round(v["usd"], 2),
        "tokens": {fp_by_unit.get(u, u): {"amount": round(a, 6), "usd": round(v["tokens_usd"].get(u, 0), 2)}
                   for u, a in sorted(v["tokens"].items(), key=lambda kv: -v["tokens_usd"].get(kv[0], 0))},
    }
json.dump(report, open(f"{D}/valuation.json", "w"), indent=1)
print(json.dumps({"total_ada": round(tot_ada, 2), "total_usd": round(tot_usd, 2),
                  "ada_price": ada_price, "missing": list(missing)[:10]}, indent=1))
for cls, v in report["by_class"].items():
    print(f"  {cls:20s} ada={v['ada']:12.2f} usd={v['usd']:10.2f}")

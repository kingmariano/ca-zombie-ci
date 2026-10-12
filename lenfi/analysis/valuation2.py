#!/usr/bin/env python3
"""Price the live Lenfi custody, keyed by DefiLlama cardano:<unit> (policy+name hex) + coingecko fallbacks."""
import json, time, urllib.request, urllib.parse, sys
from collections import defaultdict

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))

COINGECKO_FALLBACK = {
    # unit (policy+namehex) -> coingecko id  (best-effort for well-known Cardano assets)
    "8fef2d34078659493ce161a6c7fba4b56afefa8535296a5743f69587441414441": "coingecko:aada-finance",
    "5d16cc1a177b5d9ba9cfa9793b07e60f1fb70fea1f8aef064415d114494147": "coingecko:iagon",
    "577f0b1342f8f8f4aed3388b80a8535812950c7a892495c0ecdf0f1e0014df10464c4454": "coingecko:fluidtokens",
    "5dac8536653edc12f6f5e1045d8164b9f59998d3bdc300fc928434894e4d4b52": "coingecko:nft-maker",
    "da8c30857834c6ae7203935b89278c532b3995245295456f993e1d244c51": "coingecko:liqwid-finance",
    "95a427e384527065f2f8946f5e86320d0117839a5e98ea2c0b55fb0048554e54": "coingecko:hunt-token",
    "86abe45be4d8fb2e8f28e8047d17d0ba5592f2a6c8c452fc88c2c14358524159": "coingecko:xray-token",
    "b6a7467ea1deb012808ef4e87b5ff371e85f7142d7b356a40d9b42a0436f726e75636f70696173205b76696120436861696e506f72742e696f5d": "coingecko:cornucopias",
}


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

qty = defaultdict(int)
decimals = {}
for u in utxos:
    cls = addr2name.get(u["address"], u["address"])
    for a in (u.get("asset_list") or []):
        unit = a["policy_id"] + a["asset_name"]
        qty[(cls, unit)] += int(a["quantity"])
        decimals[unit] = int(a.get("decimals") or 0)

units = sorted({u for (_, u) in qty})
prices = {}
for i in range(0, len(units), 40):
    chunk = units[i:i + 40]
    enc = ",".join(urllib.parse.quote("cardano:" + u, safe="") for u in chunk)
    r = http("https://coins.llama.fi/prices/current/" + enc)
    for k, v in (r.get("coins") or {}).items():
        prices[k.replace("cardano:", "", 1)] = v.get("price")
    time.sleep(0.4)

# coingecko fallbacks for unpriced
missing = [u for u in units if prices.get(u) is None]
cg_ids = sorted({COINGECKO_FALLBACK[u] for u in missing if u in COINGECKO_FALLBACK})
cg_prices = {}
for i in range(0, len(cg_ids), 20):
    chunk = cg_ids[i:i + 20]
    r = http("https://coins.llama.fi/prices/current/" + ",".join(urllib.parse.quote(c, safe="") for c in chunk))
    for k, v in (r.get("coins") or {}).items():
        cg_prices[k] = v.get("price")
for u in missing:
    if u in COINGECKO_FALLBACK:
        prices[u] = cg_prices.get(COINGECKO_FALLBACK[u])

ada_price = prices.get("") if "" in prices else None
r = http("https://coins.llama.fi/prices/current/coingecko:cardano")
ada_price = (r.get("coins") or {}).get("coingecko:cardano", {}).get("price")

out = defaultdict(lambda: {"ada": 0.0, "ada_usd": 0.0, "tokens": {}, "usd_tok": {}, "usd": 0.0})
for u in utxos:
    cls = addr2name.get(u["address"], u["address"])
    lovelace = int(u["value"]) / 1e6
    out[cls]["ada"] += lovelace
    for a in (u.get("asset_list") or []):
        unit = a["policy_id"] + a["asset_name"]
        amt = int(a["quantity"]) / (10 ** decimals[unit])
        out[cls]["tokens"][unit] = out[cls]["tokens"].get(unit, 0) + amt
        p = prices.get(unit)
        if p:
            out[cls]["usd_tok"][unit] = out[cls]["usd_tok"].get(unit, 0) + amt * p

report = {"ada_price_usd": ada_price, "by_class": {}, "unpriced_units": [u for u in units if not prices.get(u)]}
tot_ada = 0.0
tot_usd = 0.0
for cls, v in sorted(out.items()):
    ada_usd = v["ada"] * (ada_price or 0)
    usd = ada_usd + sum(v["usd_tok"].values())
    tot_ada += v["ada"]
    tot_usd += usd
    report["by_class"][cls] = {
        "ada": round(v["ada"], 3), "ada_usd": round(ada_usd, 2), "usd": round(usd, 2),
        "tokens": {u: {"amount": round(a, 6), "usd": round(v["usd_tok"].get(u, 0), 2)}
                   for u, a in sorted(v["tokens"].items(), key=lambda kv: -v["usd_tok"].get(kv[0], 0))},
    }
report["total_ada"] = round(tot_ada, 3)
report["note"] = "priced via cardano:<unit> DefiLlama keys; coingecko fallbacks flagged per token"
report["total_usd"] = round(tot_usd, 2)
json.dump(report, open(f"{D}/valuation.json", "w"), indent=1)
print(json.dumps({"total_ada": report["total_ada"], "total_usd": report["total_usd"], "ada_price": ada_price}, indent=1))
for cls, v in report["by_class"].items():
    print(f"  {cls:20s} ada={v['ada']:12.2f} usd={v['usd']:10.2f}")
print("\ntop token USD contributions:")
alltok = []
for cls, v in report["by_class"].items():
    for u, d in v["tokens"].items():
        if d["usd"] > 1:
            alltok.append((d["usd"], cls, u, d["amount"]))
for x in sorted(alltok, reverse=True)[:15]:
    print(f"   ${x[0]:9.2f} {x[1]:18s} {x[2][:16]}..{x[2][-10:]} amt={x[3]}")

#!/usr/bin/env python3
"""Post-CI analysis: merge CI outputs into a per-protocol evidence file.
Run locally after ci-run.sh completes. Reads ci-out/*.json -> analysis/evidence.json
Also re-prices GoldRush items via llama where a contract address is known."""
import json, os, urllib.request
from collections import defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(BASE), "ci-out")
UA = {"User-Agent": "Mozilla/5.0"}

CHAIN_LLAMA = {"ethereum": "ethereum", "bsc": "bsc", "polygon": "polygon", "arbitrum": "arbitrum",
               "optimism": "optimism", "base": "base", "avalanche": "avax", "fantom": "fantom",
               "sei": "sei", "mantle": "mantle", "xdc": "xdc", "okc": "okexchain", "kava": "kava",
               "moonriver": "moonriver", "aurora": "aurora", "astar": "astar",
               "polygon-zkevm": "polygon_zkevm", "metis": "metis", "monad": "monad",
               "hyperliquid": "hyperliquid"}

def llama_prices(chain, addrs):
    lc = CHAIN_LLAMA.get(chain)
    if not lc or not addrs: return {}
    out = {}
    addrs = list(dict.fromkeys(a.lower() for a in addrs if a and a.startswith("0x")))
    for i in range(0, len(addrs), 80):
        chunk = addrs[i:i+80]
        try:
            url = "https://coins.llama.fi/prices/current/" + ",".join(f"{lc}:{a}" for a in chunk)
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode())
            for k, v in (d.get("coins") or {}).items():
                a = k.split(":")[-1].lower()
                if v.get("price") is not None:
                    out[a] = float(v["price"])
        except Exception:
            pass
    return out

def main():
    probe = json.load(open(os.path.join(OUT, "probe-results.json")))
    fac = json.load(open(os.path.join(OUT, "factories.json"))) if os.path.exists(os.path.join(OUT, "factories.json")) else {}
    spec = json.load(open(os.path.join(OUT, "special.json"))) if os.path.exists(os.path.join(OUT, "special.json")) else {}
    blocks = json.load(open(os.path.join(OUT, "blocks.json"))) if os.path.exists(os.path.join(OUT, "blocks.json")) else {}

    # collect all contracts for re-pricing per chain
    need = defaultdict(set)
    for rec in probe:
        for it in (rec.get("goldrush") or {}).get("items", []) or []:
            if it.get("contract"): need[rec["chain"]].add(it["contract"])
        for it in (rec.get("rpc_token_scan") or {}).get("items", []) or []:
            if it.get("contract"): need[rec["chain"]].add(it["contract"])
    prices = {}
    for ch, addrs in need.items():
        prices[ch] = llama_prices(ch, list(addrs))
        print(f"prices {ch}: {len(prices[ch])}")

    # per protocol evidence
    ev = defaultdict(lambda: {"chains": {}, "factory": [], "special": {}})
    for rec in probe:
        s, ch = rec["slug"], rec["chain"]
        c = ev[s]["chains"].setdefault(ch, {"contracts": []})
        gr = rec.get("goldrush") or {}
        rts = rec.get("rpc_token_scan") or {}
        items = []
        total = 0.0
        for it in gr.get("items", []) or []:
            bal = it.get("balance") or 0
            p = prices.get(ch, {}).get(it.get("contract", "").lower())
            usd = it.get("usd") or 0
            if p is not None and bal:
                usd = max(usd, bal * p)
            total += usd
            items.append({"sym": it.get("symbol"), "contract": it.get("contract"), "bal": bal,
                          "usd": round(usd, 2), "spam": it.get("spam")})
        for it in rts.get("items", []) or []:
            total += it.get("usd") or 0
            items.append({"sym": it.get("symbol"), "contract": it.get("contract"), "bal": it.get("balance"),
                          "usd": it.get("usd"), "spam": False})
        items.sort(key=lambda x: -(x["usd"] or 0))
        c["contracts"].append({
            "addr": rec["addr"], "roles": rec.get("roles"), "native_wei": rec.get("native_wei"),
            "getters": rec.get("getters") or {}, "total_usd": round(total, 2),
            "items": [i for i in items if (i["usd"] or 0) > 0.5][:12],
            "gr_error": gr.get("error"),
        })
    for k, v in fac.items():
        ev[v["slug"]]["factory"].append(v)
    for s, d in spec.items():
        if s.startswith("_"):
            ev["_api-probes"] = d
            continue
        ev[s]["special"] = d

    out = {"blocks": blocks, "protocols": {k: v for k, v in ev.items()}}
    json.dump(out, open(os.path.join(BASE, "evidence.json"), "w"), indent=1)

    # compact print
    for s, v in ev.items():
        if s.startswith("_"): continue
        tot = 0.0
        lines = []
        for ch, cd in v["chains"].items():
            for c in cd["contracts"]:
                tot += c["total_usd"]
                top = c["items"][:3]
                if c["total_usd"] > 1:
                    lines.append(f"    {ch:10} {c['addr'][:12]} ${c['total_usd']:>12,.2f} roles={c['roles']} top={[(i['sym'], round(i['usd'] or 0)) for i in top]}")
        for f in v["factory"]:
            tot += f.get("est_total_usd") or 0
            lines.append(f"    {f['chain']:10} FACTORY {f['factory'][:12]} n={f.get('n_pairs')} est=${f.get('est_total_usd')}")
        print(f"== {s}: ~${tot:,.0f}")
        for l in lines[:8]:
            print(l)

if __name__ == "__main__":
    main()

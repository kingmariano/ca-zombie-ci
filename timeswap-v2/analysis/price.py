#!/usr/bin/env python3
"""Price Timeswap V2 option-pair balances using DefiLlama coins API. Read-only.
Produces live-priced-<chain>.json and prints per-chain summaries."""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DLCHAIN = {
    "ethereum": "ethereum", "arbitrum": "arbitrum", "base": "base", "optimism": "optimism",
    "polygon": "polygon", "mantle": "mantle", "hyperliquid": "hyperevm",
    "xlayer": "xlayer", "polygon-zkevm": "polygon_zkevm", "inevm": "inevm",
}

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def price_tokens(chain, tokens):
    out = {}
    dl = DLCHAIN[chain]
    toks = sorted(set(t.lower() for t in tokens if t))
    for i in range(0, len(toks), 40):
        chunk = toks[i:i+40]
        keys = ",".join(f"{dl}:{t}" for t in chunk)
        try:
            d = get(f"https://coins.llama.fi/prices/current/{keys}")
            for k, v in (d.get("coins") or {}).items():
                out[k.split(":")[-1].lower()] = {"symbol": v.get("symbol"), "price": v.get("price"), "confidence": v.get("confidence")}
        except Exception as e:
            print(f"  price batch fail: {e}")
        time.sleep(0.3)
    return out

def main(chains):
    grand = {}
    for chain in chains:
        lf = os.path.join(HERE, f"live-{chain}.json")
        if not os.path.exists(lf):
            print(f"[{chain}] missing {lf}")
            continue
        d = json.load(open(lf))
        toks = []
        for p in d["pairs"]:
            if p.get("token0"): toks.append(p["token0"])
            if p.get("token1"): toks.append(p["token1"])
        prices = price_tokens(chain, toks)
        total = 0.0
        priced_pairs = []
        for p in d["pairs"]:
            v0 = v1 = 0.0
            for side in ("token0", "token1"):
                t = p.get(side)
                if not t: continue
                pr = prices.get(t.lower())
                human = p["balances"].get(side + "_human")
                if pr and pr.get("price") is not None and human is not None:
                    val = human * pr["price"]
                    if side == "token0": v0 = val
                    else: v1 = val
            pair_val = v0 + v1
            p["usd"] = {"token0": round(v0, 2), "token1": round(v1, 2), "total": round(pair_val, 2)}
            total += pair_val
            if pair_val > 0:
                priced_pairs.append(p)
        d["prices"] = prices
        d["total_usd"] = round(total, 2)
        priced_pairs.sort(key=lambda x: x["usd"]["total"], reverse=True)
        with open(os.path.join(HERE, f"live-priced-{chain}.json"), "w") as f:
            json.dump(d, f, indent=1)
        grand[chain] = round(total, 2)
        print(f"[{chain}] block {d['block']}: total ${total:,.2f} across {len(priced_pairs)} priced pairs")
        for p in priced_pairs[:6]:
            s0 = (p["token0_meta"] or {}).get("symbol")
            s1 = (p["token1_meta"] or {}).get("symbol")
            print(f"   {p['pair']} {s0}/{s1} = ${p['usd']['total']:,.2f}  ({p['balances'].get('token0_human')} | {p['balances'].get('token1_human')})")
    print("GRAND TOTAL:", json.dumps(grand, indent=1))

if __name__ == "__main__":
    main(sys.argv[1:] or list(DLCHAIN.keys()))

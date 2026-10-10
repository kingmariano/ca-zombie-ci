#!/usr/bin/env python3
"""Aggregate stablecoin holdings across Moonswap / Huckleberry AMM pairs and
value the Huckleberry lending markets. Outputs clean JSON summaries."""
import json, urllib.request, re

STABLE_RE = re.compile(r"^(usdc|usdt|dai|busd|mim|frax|ust|usdd|tusd|mai|usd|usdc\.m|usdt\.m|usdbc|usdp|gusd|lusd|susd|susds|usde|usds|fdusd|pyusd|rlusd)", re.I)
# exclude obvious non-stables
STABLE_RE2 = re.compile(r"(usdc|usdt|dai|busd|mim|frax)", re.I)


def get(url, timeout=60):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=timeout))


def aggregate(path):
    d = json.load(open(path))
    # group by token address
    agg = {}
    for p in d["pairs"]:
        for side in ("0", "1"):
            t = p[f"token{side}"]
            if not t:
                continue
            sym = p[f"symbol{side}"] or ""
            if not STABLE_RE2.search(sym):
                continue
            if not STABLE_RE.match(sym.strip()):
                continue
            dec = p[f"decimals{side}"] or 18
            bal = p[f"balance{side}"] or 0
            a = agg.setdefault(t, {"symbol": sym, "decimals": dec, "raw": 0, "pairs": []})
            a["raw"] += bal
            if bal:
                a["pairs"].append({"pair": p["pair"], "balance": bal})
    total = 0.0
    for t, a in agg.items():
        a["human"] = a["raw"] / 10 ** a["decimals"]
        total += a["human"]
        a["pair_count"] = len(a["pairs"])
        a["pairs"].sort(key=lambda x: -x["balance"])
    return {"file": path, "head": d.get("head"), "factory": d.get("factory"),
            "pair_count": d.get("pair_count"), "stable_tokens": agg,
            "stable_paper_total": round(total, 2)}


def price(ids):
    out = {}
    for s in range(0, len(ids), 30):
        part = ids[s:s + 30]
        try:
            r = get("https://coins.llama.fi/prices/current/" + ",".join(part))
            out.update(r.get("coins", {}))
        except Exception as e:
            out[part[0]] = {"error": str(e)}
    return out


if __name__ == "__main__":
    ms = aggregate("moonswap_pairs.json")
    ha = aggregate("huckleberry_amm_pairs.json")
    json.dump(ms, open("moonswap_stables.json", "w"), indent=2)
    json.dump(ha, open("huckleberry_amm_stables.json", "w"), indent=2)
    print("== Moonswap stables ==")
    for t, a in sorted(ms["stable_tokens"].items(), key=lambda kv: -kv[1]["human"]):
        print(f"  {a['symbol']:<10} {t} {a['decimals']:>2}d  {a['human']:>14,.4f}  ({a['pair_count']} pairs)")
    print(f"  TOTAL paper USD: ${ms['stable_paper_total']:,.2f}")
    print("== Huckleberry AMM stables ==")
    for t, a in sorted(ha["stable_tokens"].items(), key=lambda kv: -kv[1]["human"]):
        print(f"  {a['symbol']:<10} {t} {a['decimals']:>2}d  {a['human']:>14,.4f}  ({a['pair_count']} pairs)")
    print(f"  TOTAL paper USD: ${ha['stable_paper_total']:,.2f}")
    # prices for valuation
    ids = [
        "moonriver:0x98878b06940ae243284ca214f92bb71a2b032b8a",   # WMOVR
        "base:0x43feb74608334dda8c1a6500d185cfc3ea962b83",        # MOVR on Base (migrated)
        "coingecko:bitcoin", "coingecko:ethereum", "coingecko:usd-coin", "coingecko:tether",
        "coingecko:polkadot", "coingecko:kusama", "coingecko:frax", "coingecko:magic-internet-money",
        "moonriver:0x37619cc85325afea778830e184cb60a3abc9210b",   # TOM
        "moonriver:0x80a16016cc4a2e6a2caca8a4a498b1699ff0f844",   # DAI
        "moonriver:0xe3f5a90f9cb311505cd691a46596599aa1a0ad7d",   # USDC
        "moonriver:0xb44a9b6905af7c801311e8f4e76932ee959c663c",   # USDT
    ]
    p = price(ids)
    json.dump(p, open("prices.json", "w"), indent=2)
    print("== prices ==")
    for k, v in p.items():
        print(f"  {k:<70} {v.get('price')} ({v.get('confidence')}) symbol={v.get('symbol')}")

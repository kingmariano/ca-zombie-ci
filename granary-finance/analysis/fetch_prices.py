#!/usr/bin/env python3
"""Compare on-chain Granary oracle prices vs DefiLlama market prices. Keyless."""
import json, os, urllib.request, time

HERE = os.path.dirname(os.path.abspath(__file__))
LLAMA = "https://coins.llama.fi/prices/current/"

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "granary-audit/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

def main():
    st = json.load(open(os.path.join(HERE, "state-all.json")))
    keys = []
    meta = []
    for ch, s in st.items():
        for r in s.get("reserves", []):
            if isinstance(r, dict) and "config" in r:
                keys.append(f"{ch}:{r['asset']}")
                meta.append((ch, r))
    out = {"fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "rows": []}
    # llama accepts ~100 keys per call; chunk
    prices = {}
    for i in range(0, len(keys), 80):
        chunk = keys[i:i+80]
        try:
            d = get(LLAMA + ",".join(chunk))
            prices.update(d.get("coins", {}))
        except Exception as e:
            print("llama err", e)
        time.sleep(0.3)
    for ch, r in meta:
        k = f"{ch}:{r['asset']}"
        p = prices.get(k, {})
        oracle_price = r.get("oraclePrice")
        dec = r.get("assetDecimals") or 18
        o_usd = (oracle_price / 1e8) if oracle_price is not None else None
        m_usd = p.get("price")
        div = (o_usd / m_usd - 1.0) * 100 if (o_usd and m_usd) else None
        row = {
            "chain": ch, "asset": r["asset"], "symbol": r.get("assetSymbol"),
            "oracle_price_usd": round(o_usd, 8) if o_usd else None,
            "market_price_usd": m_usd, "llama_conf": p.get("confidence"),
            "divergence_pct": round(div, 3) if div is not None else None,
            "aTokenSupply": r.get("aTokenTotalSupply"), "cash": r.get("cash"),
            "stableDebt": r.get("stableDebtTotal"), "variableDebt": r.get("variableDebtTotal"),
            "decimals": dec,
        }
        out["rows"].append(row)
        print(f"{ch:>9} {str(row['symbol']):>8} oracle={row['oracle_price_usd']} market={m_usd} div={row['divergence_pct']}%")
    with open(os.path.join(HERE, "price-compare.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("saved price-compare.json")

if __name__ == "__main__":
    main()

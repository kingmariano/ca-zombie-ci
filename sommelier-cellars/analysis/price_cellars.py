#!/usr/bin/env python3
"""C2-28 — price the managed-cellar holdings (DefiLlama) + native ETH.

Reads analysis/cellar_balances.json (raw token amounts, rates null) and
analysis/local/raw/cork_v2_cellar_ids.json; prices every token contract via
DefiLlama (keyless); adds native ETH balances via a public RPC; writes
analysis/cellar_balances_priced.json.

Usage: python3 price_cellars.py [raw_json] [ids_json] [out_json]
"""
import json
import sys
import time
import urllib.request

UA = {"User-Agent": "zombie-hunt-ci/1.0 (read-only research)"}
ETH_RPC = "https://ethereum-rpc.publicnode.com"
RAW_JSON = sys.argv[1] if len(sys.argv) > 1 else "analysis/cellar_balances.json"
IDS_JSON = sys.argv[2] if len(sys.argv) > 2 else "analysis/local/raw/cork_v2_cellar_ids.json"
OUT_JSON = sys.argv[3] if len(sys.argv) > 3 else "analysis/cellar_balances_priced.json"


def http_json(url, data=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                 headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def eth_balance(addr):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_getBalance", "params": [addr, "latest"]}
    d = http_json(ETH_RPC, data=payload)
    return int(d.get("result", "0x0"), 16) / 1e18


def main():
    raw = json.load(open(RAW_JSON))
    ids = json.load(open(IDS_JSON))["cellar_ids"]

    # collect unique token contracts
    toks = set()
    for c in raw["cellars"]:
        for t in c["tokens"]:
            if t.get("address"):
                toks.add(t["address"].lower())
    toks = sorted(toks)
    print(f"unique token contracts: {len(toks)}")

    prices = {}
    CH = 60
    for i in range(0, len(toks), CH):
        chunk = toks[i:i + CH]
        q = ",".join("ethereum:" + a for a in chunk)
        try:
            d = http_json("https://coins.llama.fi/prices/current/" + q)
            prices.update(d.get("coins", {}))
        except Exception as e:
            print("price chunk error:", e)
        time.sleep(0.5)

    eth_price = None
    try:
        d = http_json("https://coins.llama.fi/prices/current/coingecko:ethereum")
        eth_price = d["coins"]["coingecko:ethereum"]["price"]
    except Exception as e:
        print("eth price error:", e)

    # native balances
    native = {}
    for i, a in enumerate(ids):
        try:
            native[a.lower()] = eth_balance(a)
        except Exception as e:
            native[a.lower()] = None
        if i % 8 == 7:
            time.sleep(0.3)

    total = 0.0
    out = {"source": "Blockscout token balances + DefiLlama prices + publicnode eth_getBalance",
           "eth_price_usd": eth_price, "cellars": []}
    for c in raw["cellars"]:
        addr = c["address"]
        row = {"address": addr, "usd": 0.0, "holdings": []}
        for t in c["tokens"]:
            ta = (t.get("address") or "").lower()
            key = "ethereum:" + ta
            p = prices.get(key, {}).get("price")
            usd = (t["amount"] * p) if p else 0.0
            if usd >= 0.01:
                row["holdings"].append({"symbol": t["symbol"], "address": ta,
                                        "amount": t["amount"], "price_usd": p, "usd": round(usd, 2)})
            row["usd"] += usd
        n = native.get(addr.lower())
        if n and eth_price and n > 1e-6:
            row["holdings"].append({"symbol": "ETH", "address": "native", "amount": n,
                                    "price_usd": eth_price, "usd": round(n * eth_price, 2)})
            row["usd"] += n * eth_price
        row["usd"] = round(row["usd"], 2)
        total += row["usd"]
        out["cellars"].append(row)
        if row["usd"] > 0:
            print(f"{addr} ${row['usd']:.2f} " +
                  ", ".join(f"{h['symbol']} {h['amount']:.6g} (${h['usd']})" for h in row["holdings"][:6]))
    out["total_usd"] = round(total, 2)
    out["cellars_with_value"] = sum(1 for c in out["cellars"] if c["usd"] > 0)
    json.dump(out, open(OUT_JSON, "w"), indent=1)
    print(f"TOTAL ${total:.2f} across {out['cellars_with_value']}/{len(ids)} cellars")


if __name__ == "__main__":
    main()

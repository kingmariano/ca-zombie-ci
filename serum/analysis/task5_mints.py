#!/usr/bin/env python3
"""Task 5: mint decimals/metadata + DefiLlama prices for top mints.
Writes mint_meta.json (decimals, supply, authorities) and prices.json."""
import gzip, json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

RPC = "https://api.mainnet-beta.solana.com"
AGG = os.path.join(HERE, "openbook_aggregates.json")
OUT_META = os.path.join(HERE, "openbook_mint_meta.json")
OUT_PRICES = os.path.join(HERE, "openbook_mint_prices.json")

def rpc_call(method, params, timeout=120, tries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                j = json.loads(r.read())
            if "error" in j:
                raise RuntimeError(str(j["error"])[:200])
            return j["result"]
        except Exception as e:
            last = e
            time.sleep(2 * (a + 1))
    raise RuntimeError(str(last))

def fetch(url, timeout=90, tries=4):
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "zombie-hunt/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except Exception as e:
            last = e
            time.sleep(2 * (a + 1))
    raise RuntimeError(str(last))

def top_mints():
    agg = json.load(open(AGG))
    mints = set()
    for e in agg["top50_mints_by_amount"]:
        mints.add(e["mint"])
    for e in agg["top50_mints_by_market_count"]:
        mints.add(e["mint"])
    for r in agg["top100_markets_by_deposits"]:
        mints.add(r["coin_mint"]); mints.add(r["pc_mint"])
    return sorted(mints)

def main():
    mints = top_mints()
    print(f"{len(mints)} unique mints to fetch")
    meta = {}
    for i in range(0, len(mints), 100):
        batch = mints[i:i + 100]
        res = rpc_call("getMultipleAccounts", [batch, {"encoding": "jsonParsed", "commitment": "finalized"}])
        for m, v in zip(batch, res["value"]):
            if v is None:
                meta[m] = None
                continue
            info = v["data"]["parsed"]["info"]
            meta[m] = {"decimals": info["decimals"], "supply_raw": info["supply"],
                       "mint_authority": info.get("mintAuthority"),
                       "freeze_authority": info.get("freezeAuthority"),
                       "owner": v["owner"], "lamports": v["lamports"]}
        time.sleep(0.3)
    with open(OUT_META, "w") as f:
        json.dump(meta, f, indent=1)
    print("wrote", OUT_META)

    # DefiLlama prices (solana:<mint>)
    prices = {}
    for i in range(0, len(mints), 50):
        batch = mints[i:i + 50]
        keys = ",".join("solana:" + m for m in batch)
        try:
            j = fetch(f"https://coins.llama.fi/prices/current/{keys}")
            coins = j.get("coins", {})
            for k, v in coins.items():
                prices[k.split(":", 1)[1]] = {"price": v["price"], "decimals": v.get("decimals"),
                                              "symbol": v.get("symbol"), "confidence": v.get("confidence")}
        except Exception as e:
            print("price batch failed", str(e)[:120])
        time.sleep(0.5)
    with open(OUT_PRICES, "w") as f:
        json.dump(prices, f, indent=1)
    print("wrote", OUT_PRICES, f"({len(prices)} priced)")
    # summary table row for known mints
    for m in mints[:20]:
        md = meta.get(m) or {}
        pr = prices.get(m) or {}
        print(f"{m[:12]}.. dec={md.get('decimals')} price={pr.get('price')} sym={pr.get('symbol')}")

if __name__ == "__main__":
    main()

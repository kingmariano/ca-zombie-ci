#!/usr/bin/env python3
"""Fresh valuation of all Mobius pools using ACTUAL on-chain token balances
(balanceOf) and current DefiLlama prices. Read-only, keyless RPC.
Output: analysis/valuation.json (+ printed table)
"""
import json, urllib.request, time, os

RPCS = ["https://forno.celo.org", "https://celo-rpc.publicnode.com",
        "https://rpc.ankr.com/celo", "https://celo.drpc.org"]
HERE = os.path.dirname(os.path.abspath(__file__))
STATE = json.load(open(os.path.join(HERE, "live-state.json")))
TOKENS = json.load(open(os.path.join(HERE, "tokens.json")))

# best-effort price overrides where DefiLlama lacks a price but one is known/derivable
PRICE_OVERRIDE = {
    # set by analysis, e.g. "0x...": 1.0
}
NOTES = {
    "0xd629eb00deced2a080b7ec630ef6ac117e614f1b": "Wrapped Bitcoin (Celo, 18dp) - DL price 82740.92",
}


def rpc_batch(calls, tries=6):
    res = []
    for i in range(0, len(calls), 8):
        chunk = calls[i:i + 8]
        body = json.dumps([{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                           for j, (m, p) in enumerate(chunk)]).encode()
        for t in range(tries):
            try:
                req = urllib.request.Request(RPCS[t % len(RPCS)], data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research)"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    d = json.loads(r.read().decode())
                by = {it["id"]: it for it in d}
                for j in range(len(chunk)):
                    it = by.get(j)
                    res.append(it.get("result") if it and "result" in it else None)
                break
            except Exception:
                time.sleep(0.8 + t)
        else:
            res.extend([None] * len(chunk))
    return res


def pad_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def dec_uint(s):
    if not isinstance(s, str) or s == "0x":
        return None
    try:
        return int(s[2:66], 16)
    except Exception:
        return None


def main():
    pools = STATE["pools"]
    # collect calls: balanceOf(pool) for each token; totalSupply of LP
    calls, keys = [], []
    for p, e in pools.items():
        for t in e.get("tokens") or []:
            calls.append(("eth_call", [{"to": t, "data": "0x70a08231" + pad_addr(p)}, "latest"]))
            keys.append((p, "bal", t))
        if e.get("lpToken"):
            calls.append(("eth_call", [{"to": e["lpToken"], "data": "0x18160ddd"}, "latest"]))
            keys.append((p, "lpSupply", e["lpToken"]))
    res = rpc_batch(calls)
    bn = int(rpc_batch([("eth_blockNumber", [])])[0], 16)

    # fresh prices
    all_tokens = sorted({t for e in pools.values() for t in (e.get("tokens") or [])})
    prices = {}
    for i in range(0, len(all_tokens), 20):
        ch = all_tokens[i:i + 20]
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"celo:{t}" for t in ch)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read().decode())
            for k, v in (d.get("coins") or {}).items():
                prices[k.split(":")[1].lower()] = v.get("price")
        except Exception as ex:
            print("price err", ex)
        time.sleep(0.2)
    # CELO price
    try:
        req = urllib.request.Request("https://coins.llama.fi/prices/current/coingecko:celo", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r:
            d = json.loads(r.read().decode())
        for k, v in (d.get("coins") or {}).items():
            prices["coingecko:celo"] = v.get("price")
    except Exception:
        pass

    # apply results
    vals = {}
    for (p, kind, t), r in zip(keys, res):
        vals.setdefault(p, {}).setdefault(kind, {})[t] = dec_uint(r)

    out = {"block": bn, "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "pools": {}}
    grand = 0.0
    grand_priced = 0.0
    for p, e in pools.items():
        toks = e.get("tokens") or []
        rows = []
        total = 0.0
        unpriced = []
        for t in toks:
            tl = t.lower()
            bal = vals.get(p, {}).get("bal", {}).get(t)
            dec = (TOKENS.get(tl) or {}).get("decimals")
            dec = dec if dec is not None else 18
            amt = (bal or 0) / (10 ** dec)
            price = prices.get(tl)
            if price is None:
                price = PRICE_OVERRIDE.get(tl)
            usd = (amt * price) if price is not None else None
            if usd is None:
                unpriced.append(t)
            else:
                total += usd
            rows.append({"token": t, "symbol": (TOKENS.get(tl) or {}).get("symbol"), "decimals": dec,
                         "amount": amt, "raw": str(bal), "price": price, "usd": round(usd, 2) if usd is not None else None})
        # admin fees = actual - stored
        admins = []
        for i, t in enumerate(toks):
            stored = (e.get("balances") or [None] * 4)[i]
            bal = vals.get(p, {}).get("bal", {}).get(t)
            if stored is not None and bal is not None:
                admins.append({"token": t, "admin_raw": str(bal - stored),
                               "admin_amount": (bal - stored) / (10 ** ((TOKENS.get(t.lower()) or {}).get("decimals") or 18)),
                               "usd": round((bal - stored) / (10 ** ((TOKENS.get(t.lower()) or {}).get("decimals") or 18)) * (prices.get(t.lower()) or 0), 2)})
        lp_supply = vals.get(p, {}).get("lpSupply", {}).get(e.get("lpToken")) if e.get("lpToken") else None
        out["pools"][p] = {"tokens": rows, "total_usd_priced": round(total, 2), "unpriced_tokens": unpriced,
                           "admin_fees": admins, "lp_supply_raw": str(lp_supply) if lp_supply is not None else None,
                           "lp_price_usd": (total / (lp_supply / 1e18)) if lp_supply else None,
                           "paused": e.get("paused"), "owner": e.get("owner")}
        grand_priced += total
        grand += total
        print(f"{p} total=${total:,.2f} unpriced={len(unpriced)}", flush=True)
    out["grand_total_usd_priced"] = round(grand_priced, 2)
    s = sum(v["total_usd_priced"] for v in out["pools"].values())
    print(f"GRAND TOTAL (priced only) = ${s:,.2f} at block {bn}")
    with open(os.path.join(HERE, "valuation.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote valuation.json")


if __name__ == "__main__":
    main()

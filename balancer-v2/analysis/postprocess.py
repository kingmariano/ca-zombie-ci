#!/usr/bin/env python3
"""Post-process Balancer V2 chain scan JSONs into a report of pools > ~$500 and
flagged rate-provider pools (ComposableStable / Linear / MetaStable).

Read-only. Outputs: analysis/_tables.md, analysis/_summary.json
"""
import json, os, time, urllib.request, urllib.parse
from decimal import Decimal

ANALYSIS = os.path.dirname(os.path.abspath(__file__))
CHAINS = [
    # (name, llama_chain, coingecko_platform, rpc, fallback_rpc)
    ("polygon", "polygon", "polygon", "https://polygon-bor-rpc.publicnode.com",
     "https://polygon-rpc.com"),
    ("gnosis", "gnosis", "xdai", "https://gnosis-rpc.publicnode.com",
     "https://rpc.gnosischain.com"),
    ("avalanche", "avax", "avalanche", "https://api.avax.network/ext/bc/C/rpc",
     "https://avalanche-c-chain-rpc.publicnode.com"),
]
NATIVE_MAP = {
    "polygon": "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270",   # WMATIC
    "gnosis": "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d",     # WXDAI
    "avalanche": "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7", # WAVAX
}
ZERO = "0x0000000000000000000000000000000000000000"
EEE = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

SEL_SYMBOL = "0x95d89b41"
SEL_DECIMALS = "0x313ce567"


def http_json(url, payload=None, retries=4, timeout=60, method=None):
    body = json.dumps(payload).encode() if payload is not None else None
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=body, method=method,
                                         headers={"Content-Type": "application/json",
                                                  "User-Agent": "Mozilla/5.0 bal-post"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except Exception as e:
            last = e
            time.sleep(1.2 * (i + 1))
    raise RuntimeError(f"http failed {url[:60]}: {last}")


def rpc_batch(rpc, calls, chunk=30, fallback=None):
    out = []
    rpcs = [rpc] + ([fallback] if fallback else [])
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                   for j, (m, p) in enumerate(part)]
        res = None
        for url in rpcs:
            try:
                res = http_json(url, payload)
                break
            except Exception:
                continue
        if res is None:
            out.extend([None] * len(part))
            continue
        by_id = {r.get("id"): r for r in res}
        for j in range(len(part)):
            r = by_id.get(j, {})
            out.append(r.get("result") if "result" in r else None)
        time.sleep(0.03)
    return out


def dec_symbol(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    h = hexstr[2:]
    try:
        if len(h) == 64:  # bytes32 symbol
            b = bytes.fromhex(h)
            s = b.split(b"\x00")[0].decode("utf-8", "replace")
            return s or None
        # dynamic string
        words = [h[i:i + 64] for i in range(0, len(h), 64)]
        if len(words) >= 3 and int(words[0], 16) == 32:
            ln = int(words[1], 16)
            data = b"".join(bytes.fromhex(w) for w in words[2:])
            return data[:ln].decode("utf-8", "replace")
        b = bytes.fromhex(h)
        return b.split(b"\x00")[0].decode("utf-8", "replace") or None
    except Exception:
        return None


def dec_uint(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    return int(hexstr, 16) & ((1 << 256) - 1)


def fetch_token_meta(rpc, fallback, addrs):
    """addr -> {symbol, decimals} via batched eth_call."""
    meta = {}
    addrs = [a.lower() for a in addrs if a and a.lower() not in (ZERO, EEE)]
    calls = []
    for a in addrs:
        calls.append(("eth_call", [{"to": a, "data": SEL_SYMBOL}, "latest"]))
        calls.append(("eth_call", [{"to": a, "data": SEL_DECIMALS}, "latest"]))
    res = rpc_batch(rpc, calls, chunk=30, fallback=fallback)
    for k, a in enumerate(addrs):
        sym = dec_symbol(res[2 * k])
        dec = dec_uint(res[2 * k + 1])
        if dec is None or dec > 40:
            dec = 18
        meta[a] = {"symbol": sym, "decimals": dec}
    return meta


def llama_prices(llama_chain, addrs):
    prices = {}
    addrs = sorted({a.lower() for a in addrs})
    for i in range(0, len(addrs), 40):
        chunk = addrs[i:i + 40]
        coins = ",".join(f"{llama_chain}:{a}" for a in chunk)
        url = f"https://coins.llama.fi/prices/current/{urllib.parse.quote(coins)}?searchWidth=4h"
        try:
            d = http_json(url)
        except Exception as e:
            print(f"  llama chunk failed: {e}")
            continue
        for key, v in (d.get("coins") or {}).items():
            prices[key.split(":", 1)[1].lower()] = v
    return prices


def cg_prices(cg_chain, addrs):
    prices = {}
    addrs = sorted({a.lower() for a in addrs})
    for i in range(0, len(addrs), 20):
        chunk = addrs[i:i + 20]
        url = ("https://api.coingecko.com/api/v3/simple/token_price/" + cg_chain +
               "?contract_addresses=" + ",".join(chunk) + "&vs_currencies=usd")
        try:
            d = http_json(url)
        except Exception as e:
            print(f"  coingecko chunk failed: {e}")
            continue
        for a, v in (d or {}).items():
            if isinstance(v, dict) and v.get("usd") is not None:
                prices[a.lower()] = {"price": v["usd"]}
    return prices


def fmt(x):
    d = Decimal(str(x))
    if d == 0:
        return "0"
    d = d.normalize()
    s = format(d, "f")
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return s


def main():
    summary = {}
    md = []
    for chain, llama_chain, cg_chain, rpc, fb in CHAINS:
        path = os.path.join(ANALYSIS, f"chain-{chain}.json")
        with open(path) as f:
            d = json.load(f)
        pools = d["pools"]
        all_toks = {t.lower() for p in pools for t in p.get("tokens", [])}
        print(f"[{chain}] {d['pools_registered']} registered, {len(pools)} live, "
              f"{len(all_toks)} unique tokens")
        prices = llama_prices(llama_chain, all_toks)
        missing = [a for a in all_toks if a not in prices and a not in (ZERO, EEE)]
        if missing:
            cg = cg_prices(cg_chain, missing)
            for a, v in cg.items():
                prices.setdefault(a, v)
        still_missing = [a for a in all_toks if a not in prices and a not in (ZERO, EEE)]
        meta = fetch_token_meta(rpc, fb, still_missing) if still_missing else {}
        print(f"[{chain}] priced {len(prices)}/{len(all_toks)}; on-chain meta for "
              f"{len(still_missing)}")

        def price_of(a):
            a = a.lower()
            if a in prices:
                return prices[a].get("price"), prices[a].get("symbol"), prices[a].get("decimals")
            if a in (ZERO, EEE):
                n = prices.get(NATIVE_MAP[chain])
                if n:
                    return n.get("price"), (n.get("symbol") or "NATIVE") + "/native", n.get("decimals")
            if a in meta:
                return None, meta[a]["symbol"], meta[a]["decimals"]
            return None, None, None

        def tok_view(a):
            a_l = a.lower()
            p, sym, dec = price_of(a)
            m = meta.get(a_l) or {}
            if not sym:
                sym = m.get("symbol")
            if not dec:
                dec = m.get("decimals") or 18
            if a_l in (ZERO, EEE):
                sym = (sym or "NATIVE") + " (native sentinel)"
            return p, (sym or a[:10] + "…"), int(dec)

        enriched = []
        for p in pools:
            usd = Decimal(0)
            unpriced = 0
            toks = []
            for t, b in zip(p.get("tokens", []), p.get("balances", [])):
                if b == 0:
                    continue
                pr, sym, dec = tok_view(t)
                human = Decimal(b) / (Decimal(10) ** dec)
                if pr is None:
                    unpriced += 1
                else:
                    usd += human * Decimal(str(pr))
                toks.append({"addr": t, "symbol": sym, "decimals": dec,
                             "raw": str(b), "human": fmt(human), "price": pr})
            e = dict(p)
            e["usd"] = float(usd)
            e["unpriced_tokens"] = unpriced
            e["token_view"] = toks
            enriched.append(e)
        enriched.sort(key=lambda x: -x["usd"])

        big = [p for p in enriched if p["usd"] >= 500]
        flagged = [p for p in enriched
                   if p.get("type") in ("ComposableStable", "Linear", "MetaStable")
                   or any(r not in (None, ZERO)
                          for r in (p.get("probe") or {}).get("rateProviders") or [])]
        summary[chain] = {
            "block": d.get("block"),
            "pools_registered": d["pools_registered"],
            "pools_live": d["pools_live"],
            "pools_ge_500": len(big),
            "flagged_pools": len(flagged),
        }
        md.append(f"\n### {chain} — pools ≥ ~$500 (n={len(big)})\n")
        md.append("| pool address | type | TVL (est USD) | tokens |")
        md.append("|---|---|---|---|")
        for p in big:
            toks = ", ".join(f"{t['symbol']} {t['human']}" + ("" if t["price"] is not None else " (no price)")
                             for t in p["token_view"])
            md.append(f"| `{p['address']}` | {p.get('type')} | {p['usd']:,.0f} | {toks} |")
        md.append(f"\n### {chain} — flagged pools w/ non-zero balances "
                  f"(ComposableStable/Linear/MetaStable/rate-provider, n={len(flagged)})\n")
        for p in sorted(flagged, key=lambda x: -x["usd"]):
            probe = p.get("probe") or {}
            extra = []
            if p.get("type") == "Linear":
                extra.append(f"mainToken={probe.get('mainToken')} wrappedToken={probe.get('wrappedToken')} targets={probe.get('targets')}")
            if probe.get("bptIndex") is not None:
                extra.append(f"bptIndex={probe.get('bptIndex')}")
            rps = [r for r in (probe.get("rateProviders") or []) if r not in (None, ZERO)]
            if rps:
                extra.append("rateProviders(non-zero)=" + ",".join(rps))
            md.append(f"- `{p['address']}` **{p.get('type')}** (est ${p['usd']:,.2f})"
                      + (" — " + "; ".join(extra) if extra else ""))
            for t in p["token_view"]:
                md.append(f"    - {t['symbol']}: {t['human']} (raw {t['raw']})"
                          + ("" if t["price"] is not None else " [price n/a]"))
        print(f"[{chain}] >= $500: {len(big)}; flagged: {len(flagged)}")
    with open(os.path.join(ANALYSIS, "_summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    with open(os.path.join(ANALYSIS, "_tables.md"), "w") as f:
        f.write("\n".join(md) + "\n")
    print("wrote _summary.json, _tables.md")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Build a real-market USD price map for every reserve mint in the Solend v1 program.

Sources (public, keyless):
  - Jupiter Price API v3 lite: https://lite-api.jup.ag/price/v3?ids=<mint,mint,...>
  - DexScreener:               https://api.dexscreener.com/latest/dex/tokens/<mint>

Reads : analysis/reserves.json  (array of reserve records with `mint`, `symbol`, ...)
Writes: analysis/prices.json    ({fetchedAt, source, prices: {mint: {...}}})
        analysis/prices.csv     (mint,symbol,usd,liquidityUsd,source)

No API keys, no writes outside this directory. Read-only market data.
"""

import csv
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent          # save-solend/
RESERVES = BASE / "analysis" / "reserves.json"
OUT_JSON = BASE / "analysis" / "prices.json"
OUT_CSV = BASE / "analysis" / "prices.csv"

JUP_BATCH = 50          # Jupiter ids per request (max allowed)
JUP_SLEEP = 1.0         # polite sleep between Jupiter calls
DS_SLEEP = 2.0          # DexScreener requires >= ~2s between calls
MAX_TRIES = 5           # retries on 429/5xx with exponential backoff
TIMEOUT = 30

UA = {"User-Agent": "save-solend-research/1.0 (read-only market price check)"}


def http_get_json(url):
    """GET a URL, retrying 429/5xx (and transient network errors) with backoff.
    Returns (parsed_json_or_None, status_or_error_string)."""
    last = None
    for attempt in range(MAX_TRIES):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                body = resp.read()
                return json.loads(body), "ok"
        except urllib.error.HTTPError as e:
            last = "http-%d" % e.code
            if e.code == 429 or 500 <= e.code < 600:
                time.sleep(2 ** attempt)     # 1,2,4,8,16s
                continue
            return None, last
        except Exception as e:               # timeout, conn reset, bad json, ...
            last = "err-%s" % type(e).__name__
            time.sleep(2 ** attempt)
    return None, last


def fetch_jupiter(mints):
    """Batch-query Jupiter v3 lite. Returns dict mint -> record, and set of mints seen in responses."""
    out = {}
    seen = set()
    for i in range(0, len(mints), JUP_BATCH):
        batch = mints[i:i + JUP_BATCH]
        url = "https://lite-api.jup.ag/price/v3?ids=" + ",".join(batch)
        data, status = http_get_json(url)
        n_found = 0
        if isinstance(data, dict):
            # Response maps mint -> {usdPrice, liquidity, blockId, decimals, ...}
            for mint in batch:
                rec = data.get(mint)
                seen.add(mint)
                if isinstance(rec, dict):
                    out[mint] = rec
                    if rec.get("usdPrice") is not None:
                        n_found += 1
        else:
            print("  jupiter batch %d status=%s (skipped)" % (i // JUP_BATCH + 1, status))
        print("  jupiter batch %d/%d: %d ids, %d priced"
              % (i // JUP_BATCH + 1, (len(mints) + JUP_BATCH - 1) // JUP_BATCH, len(batch), n_found))
        if i + JUP_BATCH < len(mints):
            time.sleep(JUP_SLEEP)
    return out, seen


def fetch_dexscreener(mint):
    """Highest-liquidity pair for a mint. Returns (usd_price, liquidity_usd, symbol, reason)."""
    data, status = http_get_json("https://api.dexscreener.com/latest/dex/tokens/" + mint)
    if not isinstance(data, dict):
        return None, None, None, "dexscreener-%s" % status
    pairs = data.get("pairs") or []
    sol = [p for p in pairs if p.get("chainId") == "solana"] or pairs
    if not sol:
        return None, None, None, "no-pairs"
    best = max(sol, key=lambda p: ((p.get("liquidity") or {}).get("usd") or 0))
    price = best.get("priceUsd")
    usd = float(price) if price is not None else None
    liq = (best.get("liquidity") or {}).get("usd")
    liq = float(liq) if liq is not None else None
    sym = (best.get("baseToken") or {}).get("symbol")
    if usd is None:
        return None, liq, sym, "dexscreener-no-price"
    return usd, liq, sym, "ok"


def main():
    reserves = json.loads(RESERVES.read_text())
    mints = []
    fallback_symbol = {}
    reserve_value = {}      # mint -> rough on-program USD value (for ranking missing mints)
    for r in reserves:
        m = r.get("mint")
        if not m:
            continue
        if m not in fallback_symbol:
            mints.append(m)
            fallback_symbol[m] = r.get("symbol") or ""
            reserve_value[m] = 0.0
        try:
            amt = float(r.get("availableTokens") or 0) + float(r.get("borrowedTokens") or 0)
        except (TypeError, ValueError):
            amt = 0.0
        p = r.get("storedPriceUsd")
        if p is not None:
            try:
                reserve_value[m] += amt * float(p)
            except (TypeError, ValueError):
                pass

    print("unique mints: %d" % len(mints))

    print("[jupiter]")
    jup, _seen = fetch_jupiter(mints)

    prices = {}
    missing = []
    for m in mints:
        rec = jup.get(m)
        if rec is not None and rec.get("usdPrice") is not None:
            usd = float(rec["usdPrice"])
            liq = rec.get("liquidity")
            prices[m] = {
                "symbol": fallback_symbol[m],           # Jupiter v3 lite has no symbol; DexScreener may fill it
                "usd": usd,
                "liquidityUsd": float(liq) if liq is not None else None,
                "source": "jupiter-v3",
                "checkedAt": int(time.time()),
            }
        else:
            missing.append(m)

    print("[dexscreener] %d mint(s) missing from jupiter" % len(missing))
    for idx, m in enumerate(missing, 1):
        usd, liq, sym, reason = fetch_dexscreener(m)
        if usd is not None:
            prices[m] = {
                "symbol": sym or fallback_symbol[m],
                "usd": usd,
                "liquidityUsd": liq,
                "source": "dexscreener",
                "checkedAt": int(time.time()),
            }
        else:
            prices[m] = {
                "symbol": sym or fallback_symbol[m],
                "usd": None,
                "liquidityUsd": liq,
                "source": None,
                "checkedAt": int(time.time()),
                "reason": "not-found-on-jupiter-or-dexscreener (%s)" % reason,
            }
        if idx % 20 == 0 or idx == len(missing):
            print("  dexscreener %d/%d" % (idx, len(missing)))
        if idx < len(missing):
            time.sleep(DS_SLEEP)

    fetched_at = int(time.time())
    OUT_JSON.write_text(json.dumps({
        "fetchedAt": fetched_at,
        "source": "jupiter-v3+dexscreener (keyless public APIs)",
        "prices": prices,
    }, indent=1))

    with open(OUT_CSV, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["mint", "symbol", "usd", "liquidityUsd", "source"])
        for m in mints:
            p = prices[m]
            w.writerow([m, p["symbol"], "" if p["usd"] is None else repr(p["usd"]),
                        "" if p["liquidityUsd"] is None else repr(p["liquidityUsd"]),
                        p["source"] or ""])

    # ---------------- summary ----------------
    priced_jup = sum(1 for m in prices if prices[m]["source"] == "jupiter-v3")
    priced_ds = sum(1 for m in prices if prices[m]["source"] == "dexscreener")
    still_missing = [m for m in prices if prices[m]["usd"] is None]
    print()
    print("SUMMARY")
    print("unique mints: %d | priced: %d (jupiter %d, dexscreener %d) | missing: %d"
          % (len(mints), priced_jup + priced_ds, priced_jup, priced_ds, len(still_missing)))

    print("\n15 largest-reserve-value missing mints (no market price found):")
    ranked = sorted(still_missing, key=lambda m: reserve_value.get(m, 0.0), reverse=True)[:15]
    for m in ranked:
        print("  %-44s %-12s reserveValueUsd=%12.2f" % (m, prices[m]["symbol"][:12], reserve_value.get(m, 0.0)))

    fame = ("USDC", "USDT", "SOL", "MSOL", "JITOSOL", "BONK", "JUP", "PYTH", "RAY",
            "SRM", "WIF", "STSOL", "USDS", "UXD", "USDR", "FRAX", "WSOL", "JLP",
            "INF", "BSOL", "JSOL", "HUH", "ORCA", "MNDE", "TULIP")
    print("\nfamous/stable symbol hints and decoded prices:")
    fam = [m for m in mints
           if any(k in (prices[m]["symbol"] or "").upper() for k in fame)
           or any(k in (fallback_symbol[m] or "").upper() for k in fame)]
    for m in fam:
        p = prices[m]
        tag = "STABLE-OK" if (p["usd"] is not None and abs(p["usd"] - 1.0) < 0.05
                              and any(k in (p["symbol"] or "").upper()
                                      for k in ("USD", "FRAX", "UXD"))) else ""
        warn = ""
        if p["usd"] is None:
            warn = " <-- MISSING"
        elif ("SOL" in (p["symbol"] or "").upper()) and p["usd"] < 10:
            warn = " <-- check"
        print("  %-12s %-44s usd=%-14s liq=%-14s %s%s"
              % ((p["symbol"] or "?")[:12], m,
                 ("%.6f" % p["usd"]) if p["usd"] is not None else "null",
                 ("%.0f" % p["liquidityUsd"]) if p["liquidityUsd"] is not None else "null",
                 p["source"] or "missing", warn + (" " + tag if tag else "")))
    print("\nwrote %s" % OUT_JSON)
    print("wrote %s" % OUT_CSV)


if __name__ == "__main__":
    main()

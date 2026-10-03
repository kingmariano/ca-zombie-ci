#!/usr/bin/env python3
"""Complete token balances + cross-checked USD valuation for the confirmed-drainable victims.
Uses Blockscout (balances) + DefiLlama (prices by address). Read-only."""
import json, urllib.request, time

VICTIMS = [
    "0x5623B873813b2f96416Cefd09d6A27cc5c938385",
    "0x7a359544e4031703a6149DB2994AfB4e324Bb242",
    "0xe789c5566b53546d46A0af48a4bD3F062d1fefd1",
    "0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1",
    "0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a",
    "0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d",
    "0xB02F39e382c90160Eb816DE5e0E428ac771d77B5",
]
HDR = {"User-Agent": "research"}


def get(url, tries=8):
    for i in range(tries):
        try:
            return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=HDR), timeout=45))
        except Exception as e:
            print("   retry", i, str(e)[:50], flush=True)
            time.sleep(min(20, 2 ** i))
    return {}


def balances(addr):
    cur = f"https://eth.blockscout.com/api/v2/addresses/{addr}/tokens?type=ERC-20"
    items, pages = [], 0
    while cur and pages < 400:
        d = get(cur)
        if not d:
            break
        for it in d.get("items", []):
            t = it.get("token") or {}
            try:
                v = int(it.get("value") or 0)
            except Exception:
                v = 0
            if v > 0:
                items.append({"tok": (t.get("address_hash") or "").lower(), "sym": t.get("symbol"),
                              "dec": int(t.get("decimals") or 0), "bal": str(v),
                              "rate": t.get("exchange_rate"), "rep": t.get("reputation")})
        pages += 1
        nxt = d.get("next_page_params")
        if not nxt:
            break
        q = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in nxt.items())
        cur = f"https://eth.blockscout.com/api/v2/addresses/{addr}/tokens?type=ERC-20&" + q
        time.sleep(0.4)
    return items, pages


def llama_prices(tokens):
    out = {}
    for i in range(0, len(tokens), 40):
        chunk = tokens[i:i + 40]
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"ethereum:{t}" for t in chunk)
        try:
            d = json.load(urllib.request.urlopen(url, timeout=60))
            for k, v in d.get("coins", {}).items():
                out[k.split(":")[1]] = v.get("price")
        except Exception as e:
            print("  llama err", str(e)[:60])
        time.sleep(0.3)
    return out


res = {}
alltoks = set()
for v in VICTIMS:
    print("balances", v, flush=True)
    items, pages = balances(v)
    res[v] = items
    alltoks |= {i["tok"] for i in items}
    print("  items", len(items), "pages", pages, flush=True)

print("pricing", len(alltoks), "tokens via DefiLlama", flush=True)
prices = llama_prices(sorted(alltoks))
json.dump({"balances": res, "llama": prices}, open("/home/heisenberg/CA/c-23/analysis/confirmed_valuation.json", "w"))

grand = 0.0
for v, items in res.items():
    tot = 0.0
    rows = []
    for i in items:
        price = prices.get(i["tok"])
        src = "llama"
        if price is None:
            try:
                price = float(i["rate"]) if i["rate"] is not None else None
            except Exception:
                price = None
            src = "blockscout" if price is not None else None
        if price is None:
            continue
        usd = price * int(i["bal"]) / 10 ** i["dec"]
        if usd > 0.001:
            rows.append((usd, i["sym"], int(i["bal"]) / 10 ** i["dec"], i["tok"], src))
            tot += usd
    grand += tot
    rows.sort(reverse=True)
    print(f"== {v} total_usd={tot:.2f}")
    for r in rows[:10]:
        print(f"   ${r[0]:.2f} {r[1]} {r[2]} {r[3]} [{r[4]}]")
print(f"GRAND TOTAL (7 confirmed victims, cross-priced): ${grand:.2f}")

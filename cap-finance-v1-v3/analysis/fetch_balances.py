#!/usr/bin/env python3
"""Enumerate live balances (GoldRush balances_v2) for Cap Finance addresses on Arbitrum.
Read-only. API key from env, never written to disk."""
import json, os, urllib.request, time

ADDRS = [
    "0x1058AFe66BB5b79C295CCCE51016586949Bc4e8d",  # Treasury v1
    "0x9BC357bc5b312AaCD41a84F3C687F031B8786853",  # Trading v3
    "0xA55Eee92a46A50A4C65908F28A0BE966D3e71633",  # Trading v1
    "0xCAEc650502F15c1a6bFf1C2288fC8F819776B2eC",  # Trading v2a
    "0xbEd32937D8A5D1421241F52809908f1a17D75bDb",  # Trading v2b
    "0xC8CDd2Ea6A5149ced1F2d225D16a775ee081C67D",  # PoolCAP
    "0xE0cCd451BB57851c1B2172c07d8b4A7c6952a54e",  # Pool ETH
    "0x958cc92297e6F087f41A86125BA8E121F0FbEcF2",  # Pool USDC
    "0xf16033d20adda47dc99ea291d0f4c4fef2ff47af",  # Store v3
    "0x031d35296154279dc1984dcd93e392b1f946737b",  # CAP token
]

key = os.environ["GOLD_RUSH_API_KEY"]
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")
os.makedirs(outdir, exist_ok=True)
out = {}
for a in ADDRS:
    url = (f"https://api.covalenthq.com/v1/42161/address/{a}/balances_v2/"
           f"?key={key}&nft=false&no-spam=true")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        d = json.load(urllib.request.urlopen(req, timeout=60))
        out[a] = d["data"]
        items = d["data"]["items"]
        print(f"\n== {a} tip={d['data'].get('chain_tip_height')}")
        for it in items:
            if float(it.get("balance", 0)) > 0:
                print(f"  {it['contract_ticker_symbol']:>10} {it['contract_address']} "
                      f"bal={it['balance']} ({it.get('balance_formatted')}) usd={it.get('quote')}")
    except Exception as e:
        print(a, "ERR", e)
        out[a] = {"error": str(e)}
    time.sleep(0.4)

with open(os.path.join(outdir, "goldrush-balances.json"), "w") as f:
    json.dump(out, f, indent=1)
print("\nsaved state/goldrush-balances.json")

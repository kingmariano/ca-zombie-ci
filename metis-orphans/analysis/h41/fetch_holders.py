#!/usr/bin/env python3
"""Paginate Blockscout v2 token holders for a token; aggregate and save."""
import json, sys, time
import requests

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def fetch_all(token, label):
    url = f"https://andromeda-explorer.metis.io/api/v2/tokens/{token}/holders"
    items = []
    params = None
    pages = 0
    while True:
        r = requests.get(url, headers=UA, params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
        page_items = data.get("items", [])
        items.extend(page_items)
        pages += 1
        np = data.get("next_page_params")
        if not np or pages > 80:
            break
        params = np
        time.sleep(0.25)
    out = {"token": token, "pages": pages, "count": len(items), "items": items}
    with open(f"raw/holders_{label}_full.json", "w") as f:
        json.dump(out, f, indent=1)
    # aggregate
    total = sum(int(it["value"]) for it in items)
    print(f"{label}: pages={pages} holders={len(items)} sum_value_raw={total} sum={total/1e18:.6f}")
    for it in items[:35]:
        addr = it["address"]["hash"]
        ic = it["address"].get("is_contract")
        nm = it["address"].get("name") or ""
        print(f"  {addr} {int(it['value'])/1e18:.6f} is_contract={ic} name={nm}")
    return items

if __name__ == "__main__":
    tok, label = sys.argv[1], sys.argv[2]
    fetch_all(tok, label)

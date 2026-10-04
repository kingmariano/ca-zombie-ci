#!/usr/bin/env python3
"""Crawl Blockscout v2 address logs for a topic with pagination. Read-only."""
import json, sys, time, urllib.request, urllib.parse

BASE = "https://andromeda-explorer.metis.io/api/v2"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"}

def get(url):
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.load(r)
        except Exception as e:
            sys.stderr.write(f"retry {attempt} {e}\n")
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("failed " + url)

def crawl(addr, topic, out_path, max_pages=200):
    items = []
    url = f"{BASE}/addresses/{addr}/logs?topic={topic}"
    page = 0
    while url and page < max_pages:
        d = get(url)
        batch = d.get("items", [])
        items.extend(batch)
        page += 1
        nxt = d.get("next_page_params")
        if not nxt:
            break
        url = f"{BASE}/addresses/{addr}/logs?" + urllib.parse.urlencode(nxt)
    with open(out_path, "w") as f:
        json.dump(items, f)
    print(f"{addr} topic={topic[:10]} pages={page} items={len(items)} -> {out_path}")

if __name__ == "__main__":
    addr = sys.argv[1]
    topic = sys.argv[2]
    out = sys.argv[3]
    crawl(addr, topic, out)

#!/usr/bin/env python3
"""Fetch token holders from GoldRush for the Narwhalswap token set. Saves raw JSON responses only (no keys)."""
import json, os, re, sys, time, urllib.request, urllib.error

CHAIN = "56"
ENV = "/home/heisenberg/CA/.env"
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw_goldrush")
os.makedirs(RAW, exist_ok=True)

def get_key():
    with open(ENV) as f:
        for line in f:
            if line.startswith("GOLD_RUSH_API_KEY="):
                return line.split("=", 1)[1].strip()
    raise SystemExit("no key")

KEY = get_key()

TOKENS = {
    "NAR": "0xa1303e6199b319a891b79685f0537d289af1fc83",
    "NLP_NARWBNB": "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
    "LP_WBNBTHUGS": "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
    "LP_WBNBBUSD": "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
    "rNLP5": "0x6451571cb5bee9fd575ad98506e96f3d09c66f91",
    "rNLP6": "0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a",
    "THUGS": "0xe10e9822a5de22f8761919310dda35cd997d63c0",
}

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) holder-scan"}

def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode())

def main():
    only = sys.argv[1:] or list(TOKENS)
    for name in only:
        addr = TOKENS[name]
        pages = []
        page = 0
        while True:
            url = (f"https://api.covalenthq.com/v1/{CHAIN}/tokens/{addr}/token_holders/"
                   f"?key={KEY}&page-size=100&page-number={page}")
            try:
                d = fetch(url)
            except urllib.error.HTTPError as e:
                print(name, "page", page, "HTTP", e.code, e.read()[:200])
                time.sleep(2)
                continue
            data = d.get("data") or {}
            items = data.get("items") or []
            pages.append(d)
            total = data.get("pagination", {}).get("total_count")
            print(f"{name} page {page}: {len(items)} items total_count={total}")
            if len(items) < 100:
                break
            page += 1
            if page >= 30:
                print(name, "STOP at 30 pages")
                break
            time.sleep(0.4)
        with open(os.path.join(RAW, f"holders_{name}.json"), "w") as f:
            json.dump(pages, f, indent=1)
        time.sleep(0.4)

if __name__ == "__main__":
    main()

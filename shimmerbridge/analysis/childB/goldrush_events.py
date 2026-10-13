#!/usr/bin/env python3
"""ChildB: find LAST SendToken/ReceiveToken per chain via GoldRush (Covalent) events/address.
Scans descending 1,000,000-block windows (API range limit) until each event type is found.
Reads GOLD_RUSH_API_KEY from /home/heisenberg/CA/.env at runtime (never printed/saved)."""
import json, time, urllib.request, re

ENV = "/home/heisenberg/CA/.env"
BRIDGE = "0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898"
WINDOW = 1_000_000
PAGE_SIZE = 1000
CHAINS = ["bsc-mainnet", "base-mainnet", "optimism-mainnet", "avalanche-mainnet", "fantom-mainnet"]
TYPES = ["SendToken", "ReceiveToken"]

def get_key():
    key = None
    for line in open(ENV):
        m = re.match(r'^GOLD_RUSH_API_KEY=(.*)$', line.strip())
        if m:
            key = m.group(1).strip().strip('"').strip("'")
    assert key, "GOLD_RUSH_API_KEY not found"
    return key

KEY = get_key()

def fetch(chain, start, end, page, tries=6):
    url = (f"https://api.covalenthq.com/v1/{chain}/events/address/{BRIDGE}/"
           f"?starting-block={start}&ending-block={end}&page-size={PAGE_SIZE}&page-number={page}")
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + KEY, "User-Agent": "childB/1.0"})
    for i in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code in (404, 429, 500, 502, 503, 504):
                time.sleep(2 + 2*i); continue
            raise
        except Exception:
            time.sleep(1 + i)
    raise RuntimeError(f"goldrush fetch failed {chain} {start}-{end} p{page}")

def get_tip(chain, pinned):
    """Get Covalent's exact indexed tip via single-block probes descending from pinned."""
    for k in (0, 1000, 10000, 100000, 1000000):
        blk = pinned - k
        if blk < 1: break
        url = (f"https://api.covalenthq.com/v1/{chain}/events/address/{BRIDGE}/"
               f"?starting-block={blk}&ending-block={blk}&page-size=1&page-number=0")
        req = urllib.request.Request(url, headers={"Authorization": "Bearer " + KEY, "User-Agent": "childB/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
        except Exception:
            time.sleep(2); continue
        if not d.get("error"):
            tip = ((d.get("data") or {}).get("chain_tip_height"))
            if tip:
                return int(tip)
        time.sleep(1)
    return None

def main():
    latest = {}
    for l in open("blocks.txt"):
        c, b = l.strip().split("|"); latest[c] = int(b)
    llama = {"bsc-mainnet":"bsc","base-mainnet":"base","optimism-mainnet":"optimism",
             "avalanche-mainnet":"avalanche","fantom-mainnet":"fantom"}
    out = {}
    for chain in CHAINS:
        cname = llama[chain]
        tip = get_tip(chain, latest[cname])
        top = min(latest[cname], tip) if tip else latest[cname]
        print(f"{chain}: covalent tip={tip} pinned={latest[cname]} scanning from top={top}", flush=True)
        found = {}
        windows = 0
        end = top
        while end > 0 and len(found) < len(TYPES):
            start = max(1, end - WINDOW + 1)
            page = 0
            items = []
            while True:
                d = fetch(chain, start, end, page)
                if d.get("error"):
                    raise RuntimeError(f"{chain}: {d.get('error_message')}")
                data = d.get("data") or {}
                its = data.get("items") or []
                items.extend(its)
                page += 1
                pag = data.get("pagination") or {}
                if not pag.get("has_more") or page > 60:
                    break
                time.sleep(0.35)
            windows += 1
            for ev in TYPES:
                evs = [it for it in items if (it.get("decoded") or {}).get("name") == ev]
                if evs and ev not in found:
                    mx = max(evs, key=lambda x: x["block_height"])
                    found[ev] = {"block": mx["block_height"], "tx": mx.get("tx_hash"),
                                 "time": mx.get("block_signed_at"),
                                 "log_offset": mx.get("log_offset"),
                                 "items_in_window": len(evs), "window": [start, end]}
                    print(f"{chain:20s} {ev:13s} last block {mx['block_height']} at {mx.get('block_signed_at')} (window {start}-{end}, {len(evs)} {ev} in window)", flush=True)
            end = start - 1
            time.sleep(0.35)
        out[cname] = {"windows_scanned": windows, "found": found}
        print(f"{chain}: done after {windows} windows; found={sorted(found)}", flush=True)
    json.dump(out, open("raw/goldrush-last-events.json", "w"), indent=1)

if __name__ == "__main__":
    main()

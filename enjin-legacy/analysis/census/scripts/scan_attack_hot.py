#!/usr/bin/env python3
"""Fine recursive re-scan of the hottest attack blocks 25,834,277-25,835,026.
Min chunk 25 blocks; splits recursively when a chunk exceeds the 10k Etherscan cap.
Appends to attack_window_events_fine.json (deduped by tx+logIndex)."""
import json, os, sys, time, urllib.request, urllib.parse

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(CENSUS, "raw")
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
TS_TOPIC = "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"
A0, A1 = 25_834_277, 25_835_026
MINCH = 25

def fetch(params, tries=6):
    url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(params)
    for t in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 census/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                body = json.load(r)
            if body.get("status") == "1" or str(body.get("message", "")).startswith("No records"):
                return body
            time.sleep(0.8 + t)
        except Exception as e:
            sys.stderr.write(f"retry {t}: {e}\n")
            time.sleep(0.8 + t)
    raise RuntimeError("fetch failed")

def scan(a, b, out, depth=0):
    """Fetch [a,b]; return set of logs; recursive split if >10k."""
    pages = []
    for page in range(1, 11):
        fn = os.path.join(RAW, f"ft_ts_fine_{a}_{b}_p{page}.json")
        if os.path.exists(fn):
            body = json.load(open(fn))
        else:
            body = fetch({"chainid": "1", "module": "logs", "action": "getLogs", "fromBlock": str(a), "toBlock": str(b),
                          "address": PA, "topic0": TS_TOPIC, "page": str(page), "offset": "1000",
                          "apikey": os.environ["ETHERSCANV2_API_KEY"]})
            with open(fn, "w") as f:
                json.dump(body, f)
            time.sleep(0.3)
        res = body.get("result") if isinstance(body.get("result"), list) else []
        pages.extend(res)
        if len(res) < 1000:
            return pages
    # 10k full -> split
    if b - a <= MINCH:
        sys.stderr.write(f"WARNING: {a}-{b} still 10k at min chunk; keeping first 10k\n")
        return pages[:10000]
    mid = (a + b) // 2
    print(f"  split {a}-{b} depth {depth}", flush=True)
    return scan(a, mid, out, depth + 1) + scan(mid + 1, b, out, depth + 1)

def main():
    logs = scan(A0, A1, None)
    # merge with previous, dedupe
    prev = []
    p = os.path.join(CENSUS, "attack_window_events.json")
    if os.path.exists(p):
        prev = json.load(open(p))["logs"]
    seen = set()
    merged = []
    for lg in prev + logs:
        k = (lg["transactionHash"], lg["logIndex"])
        if k not in seen:
            seen.add(k)
            merged.append(lg)
    with open(os.path.join(CENSUS, "attack_window_events_fine.json"), "w") as f:
        json.dump({"ranges": [[A0, A1]], "count": len(merged), "logs": merged}, f)
    print(f"fine scan added {len(logs)}; merged total {len(merged)}")

if __name__ == "__main__":
    main()

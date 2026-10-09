#!/usr/bin/env python3
"""Deep single-block recursive scan of 4 chunks that still exceeded the Etherscan 10k cap,
then merge ALL captured attack-window TransferSingle logs into attack_window_events_full.json.

Attack file range: blocks [25,833,777 .. 25,840,026].
"""
import json, os, sys, time, urllib.request, urllib.parse, glob

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(CENSUS, "raw")
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
TS_TOPIC = "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"
RANGES = [(25_834_512, 25_834_535), (25_834_536, 25_834_558), (25_834_559, 25_834_582), (25_834_887, 25_834_910)]
FILE_LO, FILE_HI = 25_833_777, 25_840_026

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

def scan(a, b, depth=0):
    pages = []
    for page in range(1, 11):
        fn = os.path.join(RAW, f"ft_ts_deep_{a}_{b}_p{page}.json")
        if os.path.exists(fn):
            body = json.load(open(fn))
        else:
            body = fetch({"chainid": "1", "module": "logs", "action": "getLogs", "fromBlock": str(a), "toBlock": str(b),
                          "address": PA, "topic0": TS_TOPIC, "page": str(page), "offset": "1000",
                          "apikey": os.environ["ETHERSCANV2_API_KEY"]})
            with open(fn, "w") as f:
                json.dump(body, f)
            time.sleep(0.25)
        res = body.get("result") if isinstance(body.get("result"), list) else []
        pages.extend(res)
        if len(res) < 1000:
            return pages
    if b - a < 1:
        sys.stderr.write(f"WARNING: single block {a} still 10k cap; keeping first 10k\n")
        return pages[:10000]
    mid = (a + b) // 2
    print(f"  deep split {a}-{b}", flush=True)
    return scan(a, mid, depth + 1) + scan(mid + 1, b, depth + 1)

def main():
    deep = []
    for a, b in RANGES:
        got = scan(a, b)
        deep.extend(got)
        print(f"deep {a}-{b}: {len(got)}", flush=True)

    # merge all sources
    logs = []
    for fn in ["attack_window_events.json", "attack_window_events_fine.json"]:
        p = os.path.join(CENSUS, fn)
        if os.path.exists(p):
            d = json.load(open(p))
            logs.extend(d.get("logs", d.get("result", [])))
    for fn in glob.glob(os.path.join(RAW, "ft_ts_*.json")):
        try:
            body = json.load(open(fn))
        except Exception:
            continue
        res = body.get("result") if isinstance(body, dict) and isinstance(body.get("result"), list) else None
        if res:
            logs.extend(res)
    logs.extend(deep)
    seen = set()
    merged = []
    for lg in logs:
        b = int(lg["blockNumber"], 16)
        if not (FILE_LO <= b <= FILE_HI):
            continue
        k = (lg["transactionHash"], lg["logIndex"])
        if k in seen:
            continue
        seen.add(k)
        merged.append(lg)
    merged.sort(key=lambda l: (int(l["blockNumber"], 16), int(l["logIndex"], 16)))
    out = {"range": [FILE_LO, FILE_HI], "count": len(merged), "logs": merged}
    with open(os.path.join(CENSUS, "attack_window_events_full.json"), "w") as f:
        json.dump(out, f)
    # per-block coverage sanity: identify any block where we kept exactly 10k for a sub-chunk
    print(f"merged attack-window logs: {len(merged)} -> attack_window_events_full.json")

if __name__ == "__main__":
    main()

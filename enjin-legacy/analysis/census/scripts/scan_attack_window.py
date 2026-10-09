#!/usr/bin/env python3
"""Complete re-scan of the truncated attack window 25833777-25840026 in 250-block chunks.
Writes raw pages ft_ts_fix_<a>_<b>_p<n>.json and a merged attack-window event file."""
import json, os, sys, time, urllib.request, urllib.parse

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(CENSUS, "raw")
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
TS_TOPIC = "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"
A0, A1 = 25_833_777, 25_840_026
CH = 250

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

def main():
    logs = []
    a = A0
    while a <= A1:
        b = min(a + CH - 1, A1)
        for page in range(1, 11):
            fn = os.path.join(RAW, f"ft_ts_fix_{a}_{b}_p{page}.json")
            if os.path.exists(fn):
                body = json.load(open(fn))
            else:
                body = fetch({"chainid": "1", "module": "logs", "action": "getLogs", "fromBlock": str(a), "toBlock": str(b),
                              "address": PA, "topic0": TS_TOPIC, "page": str(page), "offset": "1000",
                              "apikey": os.environ["ETHERSCANV2_API_KEY"]})
                with open(fn, "w") as f:
                    json.dump(body, f)
                time.sleep(0.35)
            res = body.get("result") if isinstance(body.get("result"), list) else []
            logs.extend(res)
            if len(res) < 1000:
                break
        else:
            sys.stderr.write(f"WARNING chunk {a}-{b} still 10k full\n")
        a = b + 1
    out = os.path.join(CENSUS, "attack_window_events.json")
    with open(out, "w") as f:
        json.dump({"from": A0, "to": A1, "count": len(logs), "logs": logs}, f)
    print(f"attack window {A0}-{A1}: {len(logs)} raw TransferSingle logs -> attack_window_events.json")

if __name__ == "__main__":
    main()

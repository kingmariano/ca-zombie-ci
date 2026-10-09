#!/usr/bin/env python3
"""Fetch all AdapterCreated(shell) logs from Enjin legacy PA (0xfaaf...) via Etherscan V2.

Topic0: 0xf5d46ba34659b65cffb502ef745b2bc248a71051e48eaf9d62bfa59def02afad
Reads ETHERSCANV2_API_KEY from environment. Never prints/writes the key.
Saves pages to analysis/census/raw/adapter_created_page_<N>.json
"""
import json, os, sys, time, urllib.request, urllib.parse

PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
TOPIC0 = "0xf5d46ba34659b65cffb502ef745b2bc248a71051e48eaf9d62bfa59def02afad"
OUTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "raw")
API = "https://api.etherscan.io/v2/api"

def fetch(params, tries=8):
    key = os.environ["ETHERSCANV2_API_KEY"]
    url = API + "?" + urllib.parse.urlencode(params)
    safe_url = API + "?" + urllib.parse.urlencode({k: v for k, v in params.items() if k != "apikey"})
    for t in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                body = json.load(r)
            st = body.get("status")
            msg = body.get("message", "")
            if st == "1":
                return body
            if msg.startswith("No ") or "No records" in msg:
                return body
            if "rate limit" in str(body).lower() or msg == "NOTOK":
                time.sleep(1.0 + t)
                continue
            return body  # e.g. max window errors handled by caller
        except Exception as e:
            sys.stderr.write(f"retry {t}: {e}\n")
            time.sleep(1.0 + t)
    raise RuntimeError("failed after retries")

def main():
    page = 1
    all_logs = []
    os.makedirs(OUTDIR, exist_ok=True)
    while True:
        params = {
            "chainid": "1", "module": "logs", "action": "getLogs",
            "fromBlock": "0", "toBlock": "latest",
            "address": PA, "topic0": TOPIC0,
            "page": str(page), "offset": "1000", "apikey": os.environ["ETHERSCANV2_API_KEY"],
        }
        body = fetch(params)
        logs = body.get("result")
        if not isinstance(logs, list):
            sys.stderr.write(f"page {page}: unexpected result: {str(body)[:300]}\n")
            break
        fn = os.path.join(OUTDIR, f"adapter_created_page_{page}.json")
        with open(fn, "w") as f:
            json.dump(body, f)
        all_logs.extend(logs)
        print(f"page {page}: {len(logs)} logs (total {len(all_logs)})", flush=True)
        if len(logs) < 1000:
            break
        page += 1
        time.sleep(0.35)
    # combined (strip the apikey-free result only)
    with open(os.path.join(OUTDIR, "adapter_created_all.json"), "w") as f:
        json.dump({"status": "1", "message": "OK", "result": all_logs}, f)
    print(f"TOTAL: {len(all_logs)} logs -> raw/adapter_created_all.json")

if __name__ == "__main__":
    main()

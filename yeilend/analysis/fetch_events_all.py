#!/usr/bin/env python3
"""Resume-paginate SeiScan getLogs until complete (bypasses 10k window limit)."""
import json, sys, time, urllib.parse, urllib.request

KEY = None
for line in open("/home/heisenberg/CA/.env"):
    if line.startswith("ETHERSCANV2_API_KEY="):
        KEY = line.strip().split("=", 1)[1].strip().strip('"').strip("'")

TOPICS = {
    "Borrow": "0xb3d084820fb1a9decffb176436bd02558d15fac9b0ddfed8c465bc7359d7dce0",
    "LiquidationCall": "0xe413a321e8681d831f4dbccbca790d2952b56f977908e45be37335533e005286",
    "ForcedLiquidationCall": "0xd4ef72ed764f4bbc7b40f798884e295eaa1a98ed662442e4bff5b6d5aeafca92",
    "Supply": "0x2b627736bca15cd5381dcf80b0bf11fd197d01a037c52b927a881a10fb73ba61",
    "Repay": "0xa534c8dbe71f871f9f3530e97a74601fea17b426cae02e1c5aee42c96c784051",
    "Withdraw": "0x3115d1449a7b732c986cba18244e897a450f61e1bb8d589cd2e69e6c8924f9f7",
    "DeficitCreated": "0x2bccfb3fad376d59d7accf970515eb77b2f27b082c90ed0fb15583dd5a942699",
}

def api(params):
    q = urllib.parse.urlencode({**params, "chainid": "1329", "module": "logs", "action": "getLogs", "apikey": KEY})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request("https://api.etherscan.io/v2/api?" + q, headers={"User-Agent": "Mozilla/5.0"}), timeout=60) as r:
                j = json.loads(r.read())
            if j.get("status") == "1":
                return j["result"]
            if j.get("message") == "No records found":
                return []
            if "window" in str(j.get("result", "")) or "rate limit" in str(j.get("result", "")).lower():
                time.sleep(2); continue
            if j.get("message") == "NOTOK":
                time.sleep(2); continue
            print("warn:", j.get("message"), str(j.get("result"))[:150])
            return []
        except Exception as e:
            time.sleep(2)
            if attempt == 5: raise
    return []

def fetch_all(address, topic_key, start=0):
    """Fetch all logs, resuming by block windows; dedup by txhash+logIndex."""
    topic0 = TOPICS[topic_key]
    seen = {}
    frm = start
    while True:
        rows = api({"fromBlock": str(frm), "toBlock": "latest", "address": address, "topic0": topic0, "page": 1, "offset": 1000})
        if not rows:
            break
        new = 0
        for r in rows:
            k = r["transactionHash"] + ":" + r.get("logIndex", "")
            if k not in seen:
                seen[k] = r; new += 1
        last_blk = int(rows[-1]["blockNumber"], 16)
        print(f"  window from {frm}: +{len(rows)} (new {new}), last block {last_blk}", flush=True)
        if len(rows) < 1000:
            break
        if last_blk <= frm:
            frm = last_blk + 1
        else:
            frm = last_blk + 1
        # avoid infinite loop if pagination stuck
        if len(seen) > 400000:
            print("hard cap reached"); break
    return list(seen.values())

if __name__ == "__main__":
    which, address = sys.argv[1], sys.argv[2]
    start = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    rows = fetch_all(address, which, start)
    rows.sort(key=lambda r: (int(r["blockNumber"], 16), int(r.get("logIndex", "0x0"), 16)))
    fn = f"analysis/events_{which}_{address[:10]}.json"
    json.dump(rows, open(fn, "w"), indent=1)
    print("wrote", fn, len(rows))

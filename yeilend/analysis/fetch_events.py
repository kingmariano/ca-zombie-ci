#!/usr/bin/env python3
"""Paginate SeiScan (Etherscan V2) getLogs for YeiLend events. Read-only."""
import json, sys, time, urllib.parse, urllib.request, os

KEY = None
for line in open("/home/heisenberg/CA/.env"):
    if line.startswith("ETHERSCANV2_API_KEY="):
        KEY = line.strip().split("=", 1)[1].strip().strip('"').strip("'")
assert KEY

TOPICS = {
    "Borrow": "0xb3d084820fb1a9decffb176436bd02558d15fac9b0ddfed8c465bc7359d7dce0",
    "LiquidationCall": "0xe413a321e8681d831f4dbccbca790d2952b56f977908e45be37335533e005286",
    "ForcedLiquidationCall": "0xd4ef72ed764f4bbc7b40f798884e295eaa1a98ed662442e4bff5b6d5aeafca92",
    "Supply": "0x2b627736bca15cd5381dcf80b0bf11fd197d01a037c52b927a881a10fb73ba61",
    "Repay": "0xa534c8dbe71f871f9f3530e97a74601fea17b426cae02e1c5aee42c96c784051",
    "Withdraw": "0x3115d1449a7b732c986cba18244e897a450f61e1bb8d589cd2e69e6c8924f9f7",
    "DeficitCreated": "0x2bccfb3fad376d59d7accf970515eb77b2f27b082c90ed0fb15583dd5a942699",
}

def get_logs(address, topic0, frm="80399496", to="latest"):
    out = []
    page = 1
    while True:
        q = urllib.parse.urlencode({
            "chainid": "1329", "module": "logs", "action": "getLogs",
            "fromBlock": str(frm), "toBlock": str(to), "address": address,
            "topic0": topic0, "page": page, "offset": 1000, "apikey": KEY,
        })
        url = "https://api.etherscan.io/v2/api?" + q
        for attempt in range(4):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=60) as r:
                    j = json.loads(r.read())
                break
            except Exception as e:
                if attempt == 3:
                    raise
                time.sleep(2)
        if j.get("status") != "1":
            if j.get("message") == "No records found":
                break
            # rate limit
            if "rate limit" in str(j.get("result", "")).lower() or j.get("message") == "NOTOK":
                time.sleep(2)
                continue
            print("warn:", j.get("message"), str(j.get("result"))[:200])
            break
        rows = j["result"]
        out.extend(rows)
        print(f"  {address} {topic0[:10]} page {page}: +{len(rows)} (total {len(out)})", flush=True)
        if len(rows) < 1000:
            break
        page += 1
        time.sleep(0.3)
    return out

if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "Borrow"
    address = sys.argv[2] if len(sys.argv) > 2 else "0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638"
    frm = sys.argv[3] if len(sys.argv) > 3 else "80399496"
    rows = get_logs(address, TOPICS[which], frm)
    fn = f"analysis/events_{which}_{address[:10]}.json"
    json.dump(rows, open(fn, "w"), indent=1)
    print("wrote", fn, len(rows))

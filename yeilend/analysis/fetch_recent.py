#!/usr/bin/env python3
"""Fetch recent Borrow events walking backwards from latest in block windows."""
import json, sys, time, urllib.parse, urllib.request

KEY = [l.split('=', 1)[1].strip().strip('"').strip("'") for l in open("/home/heisenberg/CA/.env") if l.startswith("ETHERSCANV2_API_KEY=")][0]
TOPIC = "0xb3d084820fb1a9decffb176436bd02558d15fac9b0ddfed8c465bc7359d7dce0"

def api(params):
    q = urllib.parse.urlencode({**params, "chainid": "1329", "module": "logs", "action": "getLogs", "apikey": KEY})
    for _ in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request("https://api.etherscan.io/v2/api?" + q, headers={"User-Agent": "Mozilla/5.0"}), timeout=60) as r:
                j = json.loads(r.read())
            if j.get("status") == "1":
                return j["result"]
            if j.get("message") == "No records found":
                return []
            time.sleep(2)
        except Exception:
            time.sleep(2)
    return []

addr = sys.argv[1]
out = open(sys.argv[2], "a")
top = int(sys.argv[3]) if len(sys.argv) > 3 else 0
if top == 0:
    top = int(__import__("subprocess").run(["cast", "block-number", "--rpc-url", "https://evm-rpc.sei-apis.com"], capture_output=True, text=True).stdout.strip())
lo_default = 130000000
lo = lo_default
blk = top
while blk > lo:
    start = max(lo, blk - 5_000_000)
    rows = []
    page_start = start
    while True:
        rs = api({"fromBlock": str(page_start), "toBlock": str(blk), "address": addr, "topic0": TOPIC, "page": 1, "offset": 1000})
        if not rs:
            break
        rows.extend(rs)
        if len(rs) < 1000:
            break
        page_start = int(rs[-1]["blockNumber"], 16) + 1
        if page_start > blk:
            break
    for r in rows:
        out.write(json.dumps(r) + "\n")
    out.flush()
    print(f"window {start}-{blk}: +{len(rows)}", flush=True)
    blk = start - 1
out.close()

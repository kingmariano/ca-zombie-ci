#!/usr/bin/env python3
"""H2-03 Nimiq: enumerate ALL Approval events granting allowance to either handler (Polygon).
No address filter: topic0=Approval, topic2=spender=handler. Saves raw logs.
"""
import json, os, urllib.request, time

KEY = os.environ["ETHERSCANV2_API_KEY"]
BASE = "https://api.etherscan.io/v2/api?chainid=137"
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
HANDLERS = {
    "H1": "0x0cFD862bE942846Cebad797d7c1BC6e47714959b",
    "H2": "0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f",
}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis", "nimiq", "logs")
os.makedirs(OUT, exist_ok=True)

def pad(a): return "0x" + a.lower().replace("0x", "").rjust(64, "0")

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for i in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read())
            if d.get("status") == "1" or d.get("message") == "No records found":
                return d
            if "Max rate limit" in str(d.get("result", "")):
                time.sleep(4); continue
            return d
        except Exception:
            time.sleep(3)
    return {"status": "0", "result": "failed"}

for hname, h in HANDLERS.items():
    all_logs = []
    page = 1
    while True:
        u = (f"{BASE}&module=logs&action=getLogs&fromBlock=0&toBlock=latest"
             f"&topic0={APPROVAL}&topic2={pad(h)}&page={page}&offset=1000&apikey={KEY}")
        d = fetch(u)
        r = d.get("result", [])
        if not isinstance(r, list) or len(r) == 0:
            break
        all_logs.extend(r)
        if len(r) < 1000:
            break
        page += 1
        time.sleep(0.3)
        if page > 100:
            print("WARN cap"); break
    fn = os.path.join(OUT, f"{hname}_Approval_all_tokens.json")
    json.dump(all_logs, open(fn, "w"))
    toks = {}
    for x in all_logs:
        t = x["address"].lower()
        toks[t] = toks.get(t, 0) + 1
    print(f"{hname}: {len(all_logs)} approval logs; distinct tokens: {json.dumps(toks, indent=1)}")

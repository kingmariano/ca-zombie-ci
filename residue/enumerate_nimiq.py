#!/usr/bin/env python3
"""H2-03 Nimiq: enumerate all HTLC events + all Approval events to both handlers (Polygon).
Saves raw logs to analysis/nimiq/logs/ and prints counts. Key from env (never written).
"""
import json, os, urllib.request, time, sys

KEY = os.environ["ETHERSCANV2_API_KEY"]
BASE = "https://api.etherscan.io/v2/api?chainid=137"
H1 = "0x0cFD862bE942846Cebad797d7c1BC6e47714959b"
H2 = "0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f"
HANDLERS = {"H1": H1, "H2": H2}
TOPICS = {
    "Open":   "0x940c1e3b52c3f6e79020026fe7bd974c4e37153e1aad368a8ec32bbdd8f5f03d",
    "Redeem": "0xfe5d8239fb4c0cba42eacd5004db0b95a5a23da7b699c7eedf948a398bbe2e85",
    "Refund": "0x3fbd469ec3a5ce074f975f76ce27e727ba21c99176917b97ae2e713695582a12",
    "Approval": "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
}

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis", "nimiq", "logs")
os.makedirs(OUT, exist_ok=True)

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for i in range(6):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read())
            if d.get("status") == "1" or d.get("message") == "No records found":
                return d
            if d.get("message") == "NOTOK" and "Max rate limit" in str(d.get("result", "")):
                time.sleep(3); continue
            return d
        except Exception as e:
            time.sleep(2)
    return {"status": "0", "result": "fetch failed"}

def get_logs(addr, topic0, topic2=None, extra=""):
    all_logs = []
    page = 1
    while True:
        url = f"{BASE}&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address={addr}&topic0={topic0}"
        if topic2:
            url += f"&topic2={topic2}"
        url += f"{extra}&page={page}&offset=1000&apikey={KEY}"
        d = fetch(url)
        r = d.get("result", [])
        if not isinstance(r, list) or len(r) == 0:
            break
        all_logs.extend(r)
        if len(r) < 1000:
            break
        page += 1
        if page > 200:
            print("  WARN page cap", addr, topic0); break
        time.sleep(0.25)
    return all_logs

def pad_topic(addr):
    return "0x" + addr.lower().replace("0x", "").rjust(64, "0")

summary = {}
for hname, h in HANDLERS.items():
    for ev in ["Open", "Redeem", "Refund"]:
        logs = get_logs(h, TOPICS[ev])
        fn = os.path.join(OUT, f"{hname}_{ev}.json")
        json.dump(logs, open(fn, "w"))
        print(f"{hname} {ev}: {len(logs)} logs -> {fn}")
        summary[f"{hname}_{ev}"] = len(logs)
    # Approvals TO this handler (spender = handler), all tokens
    logs = get_logs(h, TOPICS["Approval"], topic2=pad_topic(h))
    fn = os.path.join(OUT, f"{hname}_Approval_to_handler.json")
    json.dump(logs, open(fn, "w"))
    print(f"{hname} Approval(spender=handler): {len(logs)} logs -> {fn}")
    summary[f"{hname}_Approval"] = len(logs)

json.dump(summary, open(os.path.join(OUT, "counts.json"), "w"), indent=1)
print(json.dumps(summary, indent=1))

#!/usr/bin/env python3
"""Fetch full event history for a contract via Etherscan V2 getLogs with block-range chunking."""
import json, os, sys, urllib.request, urllib.parse, time

KEY = os.environ["ETHERSCANV2_API_KEY"]
OUTDIR = "/home/heisenberg/CA/defi-franc/analysis/events"
os.makedirs(OUTDIR, exist_ok=True)

def api(params):
    q = urllib.parse.urlencode(params)
    url = "https://api.etherscan.io/v2/api?" + q
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                d = json.load(r)
            if d.get("status") == "1":
                return d["result"]
            if "No records found" in str(d.get("message","")) or "No logs found" in str(d.get("message","")):
                return []
            if d.get("message") == "NOTOK" and "Max rate limit" in str(d.get("result","")):
                time.sleep(1.5); continue
            if "Result window is too large" in str(d.get("result","")):
                return {"__window__": True}
            return []
        except Exception as e:
            if attempt == 4: raise
            time.sleep(2*(attempt+1))

def get_logs(addr, topic0, from_block=0, to_block=99999999, extra=None):
    out = []
    frm = from_block
    chunk = 2000000
    while frm <= to_block:
        to = min(frm + chunk - 1, to_block)
        params = {"chainid":1,"module":"logs","action":"getLogs","address":addr,
                  "fromBlock":frm,"toBlock":to,"topic0":topic0,"offset":1000,"page":1}
        if extra: params.update(extra)
        res = api(params)
        if isinstance(res, dict) and res.get("__window__"):
            # shrink range
            chunk = max(10000, chunk//4)
            continue
        page = 1
        while True:
            params["page"] = page
            res = api(params)
            if not isinstance(res, list) or not res:
                break
            out.extend(res)
            if len(res) < 1000:
                break
            page += 1
            time.sleep(0.25)
        frm = to + 1
        time.sleep(0.25)
    return out

if __name__ == "__main__":
    addr = sys.argv[1]
    topic0 = sys.argv[2]
    name = sys.argv[3] if len(sys.argv) > 3 else topic0[:10]
    from_block = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    to_block = int(sys.argv[5]) if len(sys.argv) > 5 else 99999999
    logs = get_logs(addr, topic0, from_block, to_block)
    path = os.path.join(OUTDIR, f"{name}.json")
    json.dump(logs, open(path, "w"), indent=1)
    print(name, "logs:", len(logs), "->", path)

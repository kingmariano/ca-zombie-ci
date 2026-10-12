#!/usr/bin/env python3
"""Fetch ALL event logs for a contract via Etherscan V2, chunked. Robust."""
import os, json, sys, urllib.request, urllib.parse, time

KEY = os.environ["ETHERSCANV2_API_KEY"]
OUTDIR = "/home/heisenberg/CA/defi-franc/analysis/events"
os.makedirs(OUTDIR, exist_ok=True)

def api(params, tries=6):
    q = urllib.parse.urlencode(params)
    req = urllib.request.Request("https://api.etherscan.io/v2/api?" + q,
                                 headers={"User-Agent": "Mozilla/5.0"})
    for a in range(tries):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=45))
            st = d.get("status")
            if st == "1": return d["result"]
            msg = str(d.get("message","")) + str(d.get("result",""))
            if "No records" in msg or "No logs" in msg: return []
            if "rate limit" in msg.lower(): time.sleep(2); continue
            if "window" in msg.lower() or "timeout" in msg.lower(): return {"__shrink__": True}
            time.sleep(1)
        except Exception:
            time.sleep(2)
    return []

def fetch_all(addr, start, end, chunk=2000000):
    out = []
    frm = start
    while frm <= end:
        to = min(frm + chunk - 1, end)
        page = 1
        while True:
            res = api({"chainid":1,"module":"logs","action":"getLogs","address":addr,
                       "fromBlock":frm,"toBlock":to,"offset":1000,"page":page,"apikey":KEY})
            if isinstance(res, dict) and res.get("__shrink__"):
                if chunk > 10000:
                    chunk //= 4
                    break
                page = -1; break
            if not isinstance(res, list) or not res:
                break
            out.extend(res)
            if len(res) < 1000:
                break
            page += 1
            time.sleep(0.2)
        if page == -1:  # shrink and retry same range
            continue
        frm = to + 1
        time.sleep(0.2)
    return out

if __name__ == "__main__":
    addr, name, start, end = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    logs = [l for l in fetch_all(addr, start, end) if l.get("blockNumber","0x") not in ("0x","")]
    logs.sort(key=lambda l: (int(l["blockNumber"],16), int(l["logIndex"],16)))
    path = os.path.join(OUTDIR, f"{name}.json")
    json.dump(logs, open(path,"w"))
    print(f"{name}: {len(logs)} logs -> {path}")

#!/usr/bin/env python3
"""Crawl eth_getLogs for LP Transfer mint (topic1=0x0) / burn (topic2=0x0) events.
Chunked block ranges; read-only; saves JSON to raw/."""
import json, sys, time, urllib.request

RPC = "https://andromeda.metis.io/?owner=1088"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
      "Content-Type": "application/json"}
XFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
ZERO = "0x0000000000000000000000000000000000000000000000000000000000000000"

def rpc(method, params, tries=6):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:
            sys.stderr.write(f"retry {i} {method}: {e}\n")
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"failed {method}")

def get_logs(addr, topics, frm, to):
    return rpc("eth_getLogs", [{"address": addr, "fromBlock": hex(frm), "toBlock": hex(to), "topics": topics}])

def crawl(addr, kind, start, end, chunk=500000):
    # kind: mint (topic1=0) or burn (topic2=0)
    if kind == "mint":
        topics = [XFER, ZERO]
    else:
        topics = [XFER, None, ZERO]
    out = []
    b = start
    while b <= end:
        e = min(b + chunk - 1, end)
        logs = get_logs(addr, topics, b, e)
        out.extend(logs)
        b = e + 1
    return out

if __name__ == "__main__":
    addr, kind, start, end, outpath = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    logs = crawl(addr, kind, start, end)
    json.dump(logs, open(outpath, "w"))
    print(f"{addr} {kind}: {len(logs)} logs -> {outpath}")

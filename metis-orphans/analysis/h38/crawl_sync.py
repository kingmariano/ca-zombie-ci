#!/usr/bin/env python3
"""Crawl Sync events (reserve history) with adaptive chunking. Read-only."""
import json, sys, time, urllib.request

RPC = "https://andromeda.metis.io/?owner=1088"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
       "Content-Type": "application/json"}
SYNC = "0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1"

def rpc(method, params, tries=8):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers=HDR)
            with urllib.request.urlopen(req, timeout=90) as r:
                d = json.load(r)
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:
            sys.stderr.write(f"retry {i} {method}: {e}\n")
            time.sleep(2 * (i + 1))
    raise RuntimeError("failed " + method)

def get_logs(addr, frm, to):
    return rpc("eth_getLogs", [{"address": addr, "fromBlock": hex(frm), "toBlock": hex(to), "topics": [SYNC]}])

def crawl(addr, start, end):
    out = []
    stack = [(start, end)]
    while stack:
        b, e = stack.pop()
        try:
            logs = get_logs(addr, b, e)
            out.extend(logs)
        except Exception as ex:
            if e - b < 1000:
                raise
            mid = (b + e) // 2
            stack.append((b, mid))
            stack.append((mid + 1, e))
            sys.stderr.write(f"split {b}-{e}\n")
    out.sort(key=lambda l: (int(l["blockNumber"], 16), int(l["logIndex"], 16)))
    return out

if __name__ == "__main__":
    addr, start, end, outpath = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    logs = crawl(addr, start, end)
    json.dump(logs, open(outpath, "w"))
    print(f"{addr} sync: {len(logs)} logs -> {outpath}")

#!/usr/bin/env python3
"""Fetch logs from Blockscout MCP REST API (direct_api_call /api getLogs) with range pagination.

Usage: python3 bs_logs.py <address> <topic0> <fromBlock> <toBlock> <outfile> [max_pages]
Transforms: keeps address, blockNumber, timeStamp, transactionHash, topics, data.
"""
import json, sys, time, urllib.request, urllib.parse

BASE = "https://mcp.blockscout.com/v1/direct_api_call"
UA = "Blockscout-SkillGuidedScript/0.6.0"

def fetch(address, topic0, fb, tb, max_pages=200):
    out = []
    lo = fb
    pages = 0
    while lo <= tb and pages < max_pages:
        qp = {
            "module": "logs", "action": "getLogs",
            "address": address, "topic0": topic0,
            "fromBlock": str(lo), "toBlock": str(tb),
        }
        q = urllib.parse.urlencode({"chain_id": "100", "endpoint_path": "/api",
                                    **{f"query_params[{k}]": v for k, v in qp.items()}})
        req = urllib.request.Request(BASE + "?" + q, headers={"User-Agent": UA})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=90) as r:
                    d = json.loads(r.read())
                break
            except urllib.error.HTTPError as e:
                if e.code == 413:
                    # narrow range
                    mid = (lo + tb) // 2
                    out += fetch(address, topic0, lo, mid, max_pages - pages)
                    pages += 1
                    out += fetch(address, topic0, mid + 1, tb, max_pages - pages)
                    return out
                if 500 <= e.code < 600:
                    time.sleep(3); continue
                raise
            except Exception:
                time.sleep(3); continue
        else:
            raise RuntimeError("fetch failed")
        # unwrap MCP envelope
        if isinstance(d, dict) and "data" in d and isinstance(d["data"], dict):
            d = d["data"]
        res = d.get("result") if isinstance(d, dict) else None
        if res is None:
            # maybe MCP returned string result
            if isinstance(d, dict) and isinstance(d.get("content_text"), str):
                try:
                    res = json.loads(d["content_text"]).get("result")
                except Exception:
                    res = None
        if not res:
            break
        for lg in res:
            out.append({
                "address": lg.get("address"),
                "blockNumber": int(lg.get("blockNumber", "0x0"), 16) if str(lg.get("blockNumber","")).startswith("0x") else int(lg.get("blockNumber", 0)),
                "timeStamp": int(lg.get("timeStamp", "0x0"), 16) if str(lg.get("timeStamp","")).startswith("0x") else int(lg.get("timeStamp", 0)),
                "transactionHash": lg.get("transactionHash"),
                "topics": lg.get("topics"),
                "data": lg.get("data"),
            })
        pages += 1
        if len(res) < 1000:
            break
        last = int(res[-1].get("blockNumber", "0x0"), 16) if str(res[-1].get("blockNumber","")).startswith("0x") else int(res[-1].get("blockNumber", 0))
        if last >= tb:
            break
        lo = last + 1
        print(f"   ... {len(out)} logs, now at block {lo}", file=sys.stderr)
    return out

if __name__ == "__main__":
    address, topic0, fb, tb, outfile = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    logs = fetch(address, topic0, fb, tb)
    json.dump({"address": address, "topic0": topic0, "from": fb, "to": tb, "n": len(logs), "logs": logs}, open(outfile, "w"))
    print("saved", len(logs), "logs to", outfile)

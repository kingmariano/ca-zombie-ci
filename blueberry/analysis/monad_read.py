#!/usr/bin/env python3
"""Read-only Monad state reader (public RPC, no keys).

Usage: python3 monad_read.py <calls.json> <out.json>
calls.json: [{"to": "0x..", "data": "0x..", "label": "..."}]
"""
import json, sys, urllib.request

RPC = "https://rpc.monad.xyz"  # public keyless endpoint

def rpc_batch(calls):
    payload = []
    for i, c in enumerate(calls):
        payload.append({
            "jsonrpc": "2.0", "id": i, "method": "eth_call",
            "params": [{"to": c["to"], "data": c["data"]}, "latest"],
        })
    req = urllib.request.Request(
        RPC, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())

def main():
    calls = json.load(open(sys.argv[1]))
    out = []
    # batch <=10 per request
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        res = rpc_batch(chunk)
        by_id = {r["id"]: r for r in res}
        for j, c in enumerate(chunk):
            r = by_id.get(j, {})
            out.append({"label": c.get("label"), "to": c["to"], "data": c["data"],
                        "result": r.get("result"), "error": r.get("error")})
        print(f"batch {i//10+1} done ({len(chunk)} calls)", file=sys.stderr)
    json.dump(out, open(sys.argv[2], "w"), indent=1)
    print(f"wrote {sys.argv[2]} ({len(out)} results)")

if __name__ == "__main__":
    main()

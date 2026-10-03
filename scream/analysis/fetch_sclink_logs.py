#!/usr/bin/env python3
"""Chunked resumable log fetcher for scLINK. Writes JSONL incrementally."""
import json, sys, time, urllib.request, os

RPC = "https://rpcapi.fantom.network"
M = "0x2359012ebe36cca231203d78b914284947b58aa3"
OUT = "/home/heisenberg/CA/scream/analysis/sclink_logs.jsonl"
STATE = "/home/heisenberg/CA/scream/analysis/sclink_logs.state.json"
TOPICS = {
    "Borrow": "0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80",
    "RepayBorrow": "0x1a2a22cb034d26d1854bdc6666a5b91fe25efbbb5dcad3b0355478d6f5c362a1",
    "LiquidateBorrow": "0x298637f684da70674f26509b10f07ec2fbc77a335ab1e7d6215a4b2484d8bb52",
    "Mint": "0x4c209b5fc8ad50758f13e2e1088ba56a560dff690a1c6fef26394f4c03821c4f",
    "Redeem": "0xe5b754fb1abb7f01b499791d0b820ae3b6af3424ac1c59768edb53f4ec31a929",
}

def post(payload):
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    for a in range(5):
        try:
            raw = urllib.request.urlopen(req, timeout=90).read()
            return json.loads(raw)
        except Exception as e:
            if a == 4: raise
            time.sleep(1.5 * (a + 1))

def get_logs(addr, topic, lo, hi):
    r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
              "params": [{"fromBlock": hex(lo), "toBlock": hex(hi),
                          "address": addr, "topics": [topic]}]})
    if "result" not in r:
        raise RuntimeError(str(r)[:200])
    return r["result"]

def main():
    latest = int(post({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"], 16)
    st = {"latest": latest, "topics": {k: {"done_upto": 0, "chunk": 2_000_000} for k in TOPICS}}
    if os.path.exists(STATE):
        st = json.load(open(STATE))
        st["latest"] = latest
    fout = open(OUT, "a")
    for name, topic in TOPICS.items():
        s = st["topics"][name]
        lo = s["done_upto"]
        chunk = s["chunk"]
        while lo < latest:
            hi = min(lo + chunk, latest)
            try:
                logs = get_logs(M, topic, lo, hi)
            except Exception as e:
                if chunk > 25_000:
                    chunk = chunk // 4
                    s["chunk"] = chunk
                    print(f"{name}: shrink chunk to {chunk} ({e})", file=sys.stderr)
                    continue
                print(f"{name}: give up at {lo}-{hi}: {e}", file=sys.stderr)
                time.sleep(3)
                continue
            for lg in logs:
                fout.write(json.dumps({"topic": name, **lg}) + "\n")
            fout.flush()
            lo = hi + 1
            s["done_upto"] = lo
            if len(logs) > 5000:
                s["chunk"] = max(50_000, chunk // 2)
                chunk = s["chunk"]
            print(f"{name}: {lo}/{latest} got {len(logs)} (chunk {chunk})", file=sys.stderr)
            json.dump(st, open(STATE, "w"))
    json.dump(st, open(STATE, "w"))
    fout.close()
    print("DONE", latest)

if __name__ == "__main__":
    main()

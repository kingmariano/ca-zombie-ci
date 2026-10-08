"""Chunked-batch driver for rpc.py — avoids 429s on public Arbitrum RPC.
Read-only. Usage: python3 enum_chunked.py <comptroller> [out.json]
"""
import json, sys, time, random
import urllib.request
import rpc

URLS = [
    "https://arb1.arbitrum.io/rpc",
    "https://arbitrum-one.public.blastapi.io",
    "https://arbitrum.drpc.org",
]
CHUNK = 15

def _post(url, payload, timeout=60):
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body,
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def chunked_batch(url, calls):
    res = [None] * len(calls)
    for start in range(0, len(calls), CHUNK):
        chunk = calls[start:start + CHUNK]
        payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                    "params": [{"to": to, "data": data}, "latest"]}
                   for i, (to, data) in enumerate(chunk)]
        done = False
        last = None
        for attempt in range(6):
            u = URLS[attempt % len(URLS)] if attempt else url
            try:
                out = _post(u, payload)
                if isinstance(out, dict):
                    out = [out]
                for item in out:
                    if "result" in item and item["id"] is not None:
                        res[start + item["id"]] = item["result"]
                done = True
                break
            except Exception as e:
                last = str(e)
                time.sleep(0.5 + 0.7 * attempt + random.random() * 0.3)
        if not done:
            raise RuntimeError(f"chunk at {start} failed: {last}")
        time.sleep(0.25)
    return res

def latest_block(url):
    out = _post(url, {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})
    return int(out["result"], 16)

if __name__ == "__main__":
    comp = sys.argv[1]
    outfile = sys.argv[2] if len(sys.argv) > 2 else "arb-markets.json"
    rpc.batch = chunked_batch
    data = rpc.enumerate_comptroller(URLS[0], comp)
    data["latest_block"] = latest_block(URLS[0])
    data["market_count_allmarkets"] = data.get("market_count")
    with open(outfile, "w") as f:
        json.dump(data, f, indent=1)
    print("wrote", outfile, "block", data["latest_block"], "markets", data.get("market_count"))

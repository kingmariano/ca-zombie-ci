#!/usr/bin/env python3
"""Fast batch balance snapshot (10 calls/batch, endpoint rotation). Read-only."""
import json, os, sys, urllib.request

ENDPOINTS = ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth"]
ENDPOINTS = [e for e in ENDPOINTS if e]

TARGETS = json.load(open(os.path.join(os.path.dirname(__file__), "targets.json")))


def batch(addr_chunk):
    payload = []
    for i, (name, addr) in enumerate(addr_chunk):
        payload.append({"jsonrpc": "2.0", "id": f"b{i}", "method": "eth_getBalance", "params": [addr, "latest"]})
        payload.append({"jsonrpc": "2.0", "id": f"c{i}", "method": "eth_getCode", "params": [addr, "latest"]})
    last = None
    for url in ENDPOINTS:
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=20) as r:
                data = json.loads(r.read())
            return {d["id"]: d.get("result") for d in data if isinstance(d, dict)}
        except Exception as e:
            last = e
    raise RuntimeError(last)


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "balances_20261003.json"
    items = list(TARGETS.items())
    res = {"rpc_endpoints": ENDPOINTS, "contracts": {}}
    block = None
    for i in range(0, len(items), 5):
        chunk = items[i:i + 5]
        r = batch(chunk)
        for j, (name, addr) in enumerate(chunk):
            bal = r.get(f"b{j}")
            code = r.get(f"c{j}") or "0x"
            res["contracts"][name] = {"address": addr, "balance_wei": str(int(bal, 16)) if bal else None, "balance_eth": int(bal, 16) / 1e18 if bal else None, "code_size": max(0, len(code) // 2 - 1)}
    # latest block
    for url in ENDPOINTS:
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=15) as r:
                block = int(json.loads(r.read())["result"], 16)
            break
        except Exception:
            pass
    res["block"] = block
    json.dump(res, open(out_path, "w"), indent=1)
    for k, v in res["contracts"].items():
        print(f"{k:34s} {v['balance_eth']!s:24s} code={v['code_size']}")
    print("block", block)


if __name__ == "__main__":
    main()

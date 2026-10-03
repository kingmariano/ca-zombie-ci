#!/usr/bin/env python3
"""Fetch Borrow/RepayBorrow/LiquidateBorrow/Mint/Redeem logs for all Scream markets."""
import json, sys, time, urllib.request

RPC = "https://rpcapi.fantom.network"
CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"
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
    for a in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=120).read())
        except Exception:
            if a == 3: raise
            time.sleep(2)

def get_logs(addr, topic, from_block=0):
    r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
              "params": [{"fromBlock": hex(from_block), "toBlock": "latest",
                          "address": addr, "topics": [topic]}]})
    if "result" not in r:
        raise RuntimeError(r)
    return r["result"]

def main():
    d = json.load(open("/home/heisenberg/CA/scream/analysis/markets.json"))
    addrs = list(d["markets"].keys())
    out = {"block": d["block"], "markets": {}}
    for a in addrs:
        sym = d["markets"][a].get("symbol()")
        rec = {}
        for name, topic in TOPICS.items():
            try:
                logs = get_logs(a, topic)
            except Exception as e:
                logs = [{"error": str(e)}]
            rec[name] = logs
            print(f"{sym} {a} {name}: {len(logs)}", file=sys.stderr)
            time.sleep(0.3)
        out["markets"][a] = rec
    with open("/home/heisenberg/CA/scream/analysis/logs.json", "w") as f:
        json.dump(out, f)
    print("done")

if __name__ == "__main__":
    main()

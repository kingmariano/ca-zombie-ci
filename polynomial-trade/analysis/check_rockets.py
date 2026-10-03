#!/usr/bin/env python3
"""Collect Rocket addresses created by the Polynomial meta-deposit factory, check balances."""
import json, subprocess, urllib.request, time

FACTORY = "0x9a60fe0c1b5835e6165c563d737a90c63bcc9c57"
RPC = "https://mainnet.optimism.io"
TOKENS = {
    "USDC": "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
    "USDT": "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58",
    "DAI": "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
    "WETH": "0x4200000000000000000000000000000000000006",
    "sUSD": "0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9",
    "sETH": "0xE405de8F52ba7559f9df3C368500B6E6ae6CEE49".lower(),
    "sBTC": "0x298B9B95708152ff6968aafd889c6586e9169f1D",
    "OP": "0x4200000000000000000000000000000000000042",
}

def rpc_batch(calls):
    payload = []
    for i, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    body = json.dumps(payload).encode()
    for attempt in range(4):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as resp:
                d = json.loads(resp.read())
            out = [None] * len(calls)
            for item in d:
                out[item["id"]] = item.get("result")
            return out
        except Exception as e:
            time.sleep(2)
    return [None] * len(calls)

# addresses collected earlier (paste)
addrs = [l.strip() for l in open("/home/heisenberg/CA/polynomial-trade/analysis/rocket-candidates.txt") if l.strip().startswith("0x")]
print("checking", len(addrs), "addresses")

def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")

hits = []
B = 4
for i in range(0, len(addrs), B):
    chunk = addrs[i:i+B]
    calls = []
    for a in chunk:
        calls.append((TOKENS["USDC"], "0x70a08231" + enc(a)))
        calls.append((TOKENS["WETH"], "0x70a08231" + enc(a)))
        calls.append((TOKENS["sUSD"], "0x70a08231" + enc(a)))
        calls.append((TOKENS["sETH"], "0x70a08231" + enc(a)))
    res = rpc_batch(calls)
    for j, a in enumerate(chunk):
        vals = {}
        names = ["USDC", "WETH", "sUSD", "sETH"]
        for k, nm in enumerate(names):
            v = res[4*j + k]
            try:
                vals[nm] = int(v, 16) if v else 0
            except Exception:
                vals[nm] = -1
        if any(x > 0 for x in vals.values()):
            hits.append({"addr": a, **vals})
            print("HIT", a, vals)

json.dump(hits, open("/home/heisenberg/CA/polynomial-trade/analysis/rocket-funded.json", "w"), indent=1)
print("funded hits:", len(hits))

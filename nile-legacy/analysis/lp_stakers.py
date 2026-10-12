#!/usr/bin/env python3
"""Reconstruct current stakers of the ezETH/WETH gauge from LP Transfer events.
Pages Etherscan V2 logs (deposits: to=gauge, withdrawals: from=gauge), then verifies
each candidate's balance on-chain. Reads ETHERSCANV2_API_KEY from env (never written to files).
Output: analysis/lp_stakers.json
"""
import json, os, urllib.request, time

API = "https://api.etherscan.io/v2/api?chainid=59144"
KEY = os.environ["ETHERSCANV2_API_KEY"]
GAUGE = "0x01FB6B2FA528fE9fC5fF3aB092203953AA8a32Ff"
PAIR = "0xa9a1fb9f6664a0b6bfb1f52724fd7b23842248c5"
TOPIC0 = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
RPC = os.environ.get("LINEA_RPC_URL", "https://rpc.linea.build")
PAD = "0x" + "0" * 24 + GAUGE[2:].lower()

def fetch_logs(topic_pos, from_block):
    params = (f"&module=logs&action=getLogs&address={PAIR}&topic0={TOPIC0}"
              f"&topic0_2_opr=and&topic{topic_pos}={PAD}"
              f"&fromBlock={from_block}&toBlock=latest&apikey={KEY}")
    req = urllib.request.Request(API + params, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r)
    res = d.get("result")
    return res if isinstance(res, list) else []

def page(topic_pos):
    events, from_block = [], 0
    for _ in range(20):  # safety cap
        res = fetch_logs(topic_pos, from_block)
        if not res:
            break
        events += res
        last = int(res[-1]["blockNumber"], 16)
        if len(res) < 1000:
            break
        from_block = last + 1
    return events

print("paging deposits (to=gauge)...", flush=True)
dep = page(2)
print("deposit events:", len(dep), flush=True)
print("paging withdrawals (from=gauge)...", flush=True)
wd = page(1)
print("withdraw events:", len(wd), flush=True)

net = {}
for e in dep:
    a = "0x" + e["topics"][1][-40:]
    net[a] = net.get(a, 0) + int(e["data"], 16)
for e in wd:
    a = "0x" + e["topics"][2][-40:]
    net[a] = net.get(a, 0) - int(e["data"], 16)

cands = [a for a, v in net.items() if v > 0]
print("candidates with net>0:", len(cands), flush=True)

def bal(a):
    data = "0x70a08231" + a[2:].rjust(64, "0")
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
               "params": [{"to": GAUGE, "data": data}, "latest"]}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return int(json.load(r)["result"], 16)

stakers = []
for a in cands:
    b = bal(a)
    if b > 0:
        stakers.append({"address": a, "lp_wei": str(b), "lp": b / 1e18})
stakers.sort(key=lambda x: -x["lp"])
print("current stakers:", len(stakers))
for s in stakers[:20]:
    print(f"  {s['lp']:.9f}  {s['address']}")
print("total found:", sum(s["lp"] for s in stakers))
json.dump({"gauge": GAUGE, "pair": PAIR, "deposit_events": len(dep),
           "withdraw_events": len(wd), "stakers": stakers},
          open("analysis/lp_stakers.json", "w"), indent=1)

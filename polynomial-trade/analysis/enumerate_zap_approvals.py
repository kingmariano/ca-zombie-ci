#!/usr/bin/env python3
"""Enumerate USDC Approval events to the Polynomial Zap on Optimism (chunked, throttled, resumable)."""
import json, urllib.request, urllib.parse, time, sys, os

BASE = "https://explorer.optimism.io/api"
ZAP = "0x000000000000000000000000b162f01c5bda7a68292410aaa059e7ce28d77c82"
USDC = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
STATE = "/home/heisenberg/CA/polynomial-trade/analysis/zap-approvals-state.json"
OUT = "/home/heisenberg/CA/polynomial-trade/analysis/zap-usdc-approvals.json"

def fetch(params):
    qs = urllib.parse.urlencode(params)
    req = urllib.request.Request(BASE + "?" + qs, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                d = json.loads(resp.read())
            if d.get("status") == "0" and "Too many" in (d.get("message") or ""):
                time.sleep(8 * (attempt + 1)); continue
            return d
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(10 * (attempt + 1)); continue
            print(f"HTTP {e.code} attempt {attempt}", file=sys.stderr); time.sleep(4)
        except Exception as e:
            print(f"err attempt {attempt}: {e}", file=sys.stderr); time.sleep(4)
    raise RuntimeError("fetch failed")

state = {"chunk_start": 0, "logs": [], "seen": []}
if os.path.exists(STATE):
    state = json.load(open(STATE))
seen = set(tuple(x) for x in state["seen"])

LATEST = 157_800_000  # upper bound; fine if beyond tip
CHUNK = 4_000_000

start = state["chunk_start"]
while start < LATEST:
    end = min(start + CHUNK, LATEST)
    page = 1
    got = 0
    while page <= 12:
        d = fetch({
            "module": "logs", "action": "getLogs",
            "fromBlock": str(start), "toBlock": str(end),
            "address": USDC, "topic0": APPROVAL,
            "topic0_2_opr": "and", "topic2": ZAP,
            "page": str(page), "offset": "1000",
        })
        result = d.get("result") or []
        if not result:
            break
        for x in result:
            key = (x["transactionHash"], x["logIndex"])
            if key in seen: continue
            seen.add(key)
            state["logs"].append({
                "owner": "0x" + x["topics"][1][-40:],
                "value": int(x["data"], 16) if x["data"] not in (None, "0x") else 0,
                "block": int(x["blockNumber"], 16),
                "ts": int(x["timeStamp"], 16),
                "tx": x["transactionHash"],
            })
        got += len(result)
        if len(result) < 1000:
            break
        page += 1
        time.sleep(1.2)
    print(f"chunk {start}-{end}: +{got} (total {len(state['logs'])})", flush=True)
    start = end
    state["chunk_start"] = start
    state["seen"] = list(seen)
    json.dump(state, open(STATE, "w"))
    time.sleep(1.0)

json.dump(state["logs"], open(OUT, "w"), indent=1)
owners = sorted(set(o["owner"] for o in state["logs"]))
print("TOTAL events:", len(state["logs"]), "unique owners:", len(owners))
json.dump(owners, open("/home/heisenberg/CA/polynomial-trade/analysis/zap-usdc-approval-owners.json", "w"), indent=1)

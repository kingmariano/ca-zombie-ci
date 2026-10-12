#!/usr/bin/env python3
"""Analyze veNILE lock distribution: page Deposit events, aggregate per tokenId,
then read current owner/locked for the largest locks. Reads key from env.
Output: analysis/ve_locks.json
"""
import json, os, urllib.request

API = "https://api.etherscan.io/v2/api?chainid=59144"
KEY = os.environ["ETHERSCANV2_API_KEY"]
VE = "0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F"
RPC = os.environ.get("LINEA_RPC_URL", "https://rpc.linea.build")
# Deposit(address indexed provider, uint256 indexed tokenId, uint256 value, uint256 indexed locktime, uint8 depositType, uint256 ts)
TOPIC0 = "0x" + "ddf252ad"  # placeholder replaced below
DEP_TOPIC = None

def topic0_for(sig):
    import subprocess
    return subprocess.run(["cast", "keccak", sig], capture_output=True, text=True).stdout.strip()

DEP_TOPIC = topic0_for("Deposit(address,uint256,uint256,uint256,uint8,uint256)")
WITHDRAW_TOPIC = topic0_for("Withdraw(address,uint256,uint256,uint256)")

def fetch(topic0, from_block):
    params = (f"&module=logs&action=getLogs&address={VE}&topic0={topic0}"
              f"&fromBlock={from_block}&toBlock=latest&apikey={KEY}")
    req = urllib.request.Request(API + params, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r)
    res = d.get("result")
    return res if isinstance(res, list) else []

def page(topic0):
    ev, fb = [], 0
    for _ in range(80):
        res = fetch(topic0, fb)
        if not res:
            break
        ev += res
        last = int(res[-1]["blockNumber"], 16)
        if len(res) < 1000:
            break
        fb = last + 1
    return ev

print("paging deposits...", flush=True)
dep = page(DEP_TOPIC)
print("deposit events:", len(dep), flush=True)
print("paging withdrawals...", flush=True)
wd = page(WITHDRAW_TOPIC)
print("withdraw events:", len(wd), flush=True)

# Both Deposit and Withdraw encode tokenId/value in data:
#   data[0:66]=tokenId, data[66:130]=value
withdrawn = {}
for e in wd:
    d = e["data"]
    tid = int(d[2:66], 16)
    val = int(d[66:130], 16)
    withdrawn[tid] = withdrawn.get(tid, 0) + val

locked_hist = {}
for e in dep:
    d = e["data"]
    tid = int(d[2:66], 16)
    val = int(d[66:130], 16)
    locked_hist[tid] = locked_hist.get(tid, 0) + val

# candidates = tokenIds with deposits not fully withdrawn
cands = {t: v for t, v in locked_hist.items() if v > withdrawn.get(t, 0)}
print("candidate active tokenIds:", len(cands), flush=True)
top = sorted(cands.items(), key=lambda kv: -kv[1])[:60]

def call(to, data):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
               "params": [{"to": to, "data": data}, "latest"]}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r).get("result")

rows = []
for tid, hist in top:
    o = call(VE, "0x6352211e" + hex(tid)[2:].rjust(64, "0"))  # ownerOf(uint256)
    l = call(VE, "0xb45a3c0e" + hex(tid)[2:].rjust(64, "0"))  # locked(uint256) -> (uint256,uint256)
    if o and o != "0x":
        owner = "0x" + o[-40:]
        amt = int(l[:66], 16) if l and l != "0x" else 0
        end = int(l[66:130], 16) if l and len(l) >= 130 else 0
        rows.append({"tokenId": tid, "hist_deposit": hist, "owner": owner,
                     "locked_now": amt, "unlock": end})
print(json.dumps(rows[:25], indent=1))
json.dump(rows, open("analysis/ve_locks.json", "w"), indent=1)
tot = sum(r["locked_now"] for r in rows)
print("top-60 current locked sum:", tot / 1e18)

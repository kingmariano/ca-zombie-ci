#!/usr/bin/env python3
"""Enumerate USDC Approval events to the Polynomial Zap on Optimism via mainnet.optimism.io getLogs."""
import json, urllib.request, time, sys

RPCS = ["https://mainnet.optimism.io", "https://optimism.gateway.tenderly.co"]
USDC = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
ZAP = "0x000000000000000000000000b162f01c5bda7a68292410aaa059e7ce28d77c82"

def get_logs(frm, to):
    body = json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
        "params": [{
            "address": USDC, "fromBlock": hex(frm), "toBlock": hex(to),
            "topics": [APPROVAL, None, ZAP],
        }],
    }).encode()
    last_err = None
    for rpc in RPCS:
        for attempt in range(3):
            try:
                req = urllib.request.Request(rpc, data=body, headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=120) as resp:
                    d = json.loads(resp.read())
                if "result" in d:
                    return d["result"]
                last_err = d.get("error")
                if isinstance(last_err, dict) and "range" in str(last_err).lower():
                    break  # try next RPC
                time.sleep(1.5)
            except Exception as e:
                last_err = str(e); time.sleep(1.5)
    raise RuntimeError(f"getLogs {frm}-{to} failed: {last_err}")

LATEST = 157_800_000
# first, find the extent: query full range and see
logs = get_logs(0, LATEST)
print("full-range result:", len(logs))
if logs:
    print("first block", int(logs[0]["blockNumber"], 16), "last block", int(logs[-1]["blockNumber"], 16))

# if the node caps results, re-scan in chunks
if len(logs) >= 10000:
    print("likely capped at 10k; chunking")
    logs = []
    CHUNK = 2_000_000
    start = 30_000_000
    while start < 80_000_000:
        end = start + CHUNK
        try:
            res = get_logs(start, end)
        except Exception as e:
            print("chunk fail", start, end, e); break
        logs.extend(res)
        print(f"chunk {start}-{end}: {len(res)}")
        start = end
        time.sleep(0.5)

out = []
for x in logs:
    out.append({
        "owner": "0x" + x["topics"][1][-40:],
        "value": int(x["data"], 16) if x["data"] not in (None, "0x") else 0,
        "block": int(x["blockNumber"], 16),
        "tx": x.get("transactionHash"),
    })
json.dump(out, open("/home/heisenberg/CA/polynomial-trade/analysis/zap-usdc-approvals.json", "w"), indent=1)
owners = sorted(set(o["owner"] for o in out))
print("TOTAL events:", len(out), "unique owners:", len(owners))
json.dump(owners, open("/home/heisenberg/CA/polynomial-trade/analysis/zap-usdc-approval-owners.json", "w"), indent=1)

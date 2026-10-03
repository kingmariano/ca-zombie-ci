#!/usr/bin/env python3
"""Check current USDC allowance/balance for every address that ever approved the Polynomial Zap."""
import json, urllib.request, time

RPC = "https://mainnet.optimism.io"
USDC = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
ZAP = "0xb162f01c5bda7a68292410aaa059e7ce28d77c82"
SEL_ALLOWANCE = "0xdd62ed3e"  # allowance(address,address)
SEL_BALANCE = "0x70a08231"    # balanceOf(address)

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

owners = json.load(open("/home/heisenberg/CA/polynomial-trade/analysis/zap-usdc-approval-owners.json"))
print("owners:", len(owners))

def rpc_batch(calls):
    """calls: list of (to, data) -> list of results (hex)"""
    payload = []
    for i, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    body = json.dumps(payload).encode()
    for attempt in range(4):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as resp:
                d = json.loads(resp.read())
            out = [None] * len(calls)
            for item in d:
                out[item["id"]] = item.get("result")
            return out
        except Exception as e:
            print("batch err", e); time.sleep(2)
    raise RuntimeError("batch failed")

results = {}
B = 4
for i in range(0, len(owners), B):
    chunk = owners[i:i+B]
    calls = []
    for o in chunk:
        calls.append((USDC, SEL_ALLOWANCE + enc_addr(o) + enc_addr(ZAP)))
    for o in chunk:
        calls.append((USDC, SEL_BALANCE + enc_addr(o)))
    res = rpc_batch(calls)
    for j, o in enumerate(chunk):
        try:
            allow = int(res[j], 16) if res[j] else 0
            bal = int(res[B + j], 16) if res[B + j] else 0
        except Exception:
            allow, bal = -1, -1
        results[o] = {"allowance": allow, "balance": bal}
    if i % 400 == 0:
        print("...", i, flush=True)

json.dump(results, open("/home/heisenberg/CA/polynomial-trade/analysis/zap-usdc-live-allowances.json", "w"), indent=1)

live = []
total = 0
for o, v in results.items():
    if v["allowance"] > 0 and v["balance"] > 0:
        take = min(v["allowance"], v["balance"])
        live.append({"owner": o, "allowance": v["allowance"], "balance": v["balance"], "extractable": take})
        total += take
live.sort(key=lambda x: -x["extractable"])
print("\nLIVE (allowance>0 & balance>0):", len(live))
print("TOTAL extractable raw USDC:", total, "=", total / 1e6, "USDC")
for x in live[:25]:
    print(f"  {x['owner']} allow={x['allowance']/1e6:.6f} bal={x['balance']/1e6:.6f} take={x['extractable']/1e6:.6f}")
json.dump(live, open("/home/heisenberg/CA/polynomial-trade/analysis/zap-usdc-live-extractable.json", "w"), indent=1)

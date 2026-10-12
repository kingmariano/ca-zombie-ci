#!/usr/bin/env python3
"""For every token in SheepDex pools, find its PancakeSwap V2 pair (vs WBNB/BUSD/USDT) and reserves.
Identifies pools where one side is externally near-worthless but the pool holds the good side.
Writes token-markets.json."""
import json, os, urllib.request, time

RPC = os.environ["BSC_RPC"]
PCF = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56"
USDT = "0x55d398326f99059ff775485246999027b3197955"

vals = json.load(open("pool-values.json"))
tokens = list(vals["tokens"].keys())
dec = {t: (vals["tokens"][t].get("decimals") or 18) for t in tokens}
sym = {t: (vals["tokens"][t].get("symbol") or "?") for t in tokens}

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"})
    for a in range(3):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if "error" in d: return None
            return d["result"]
        except Exception:
            time.sleep(1)
    return None

def batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]} for i, (to, data) in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    for a in range(3):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                d = json.load(r)
            break
        except Exception:
            time.sleep(2)
    out = {}
    for item in d:
        out[item["id"]] = item.get("result") if "error" not in item else None
    return [out[i] for i in range(len(calls))]

# getPair(token, WBNB), getPair(token, BUSD)
calls, meta = [], []
for t in tokens:
    for quote, qname in ((WBNB, "WBNB"), (BUSD, "BUSD")):
        data = "0xe6a43905" + t[2:].rjust(64, "0") + quote[2:].rjust(64, "0")
        calls.append((PCF, data)); meta.append((t, qname))
res = batch(calls)
pairs = {}
for (t, qname), r in zip(meta, res):
    if isinstance(r, str) and len(r) >= 42:
        a = "0x" + r[-40:]
        if a != "0x0000000000000000000000000000000000000000":
            pairs.setdefault(t, {})[qname] = a

# reserves for each pair
pcalls, pmeta = [], []
for t, qs in pairs.items():
    for qname, paddr in qs.items():
        pcalls.append((paddr, "0x0902f1ac")); pmeta.append((t, qname, paddr))
pres = batch(pcalls) if pcalls else []
out = {}
for (t, qname, paddr), r in zip(pmeta, pres):
    if isinstance(r, str) and len(r) >= 2 + 64 * 3:
        h = r[2:]
        r0 = int(h[0:64], 16); r1 = int(h[64:128], 16)
        out.setdefault(t, {})[qname] = {"pair": paddr, "r0": r0, "r1": r1}
json.dump({"tokens": out}, open("token-markets.json", "w"), indent=1)
print(f"{'token':46} {'sym':10} {'PCS pair vs':12} {'reserve':>24}")
for t, qs in out.items():
    for qname, v in qs.items():
        print(f"{t} {sym.get(t,'?'):10} {qname:12} r0={v['r0']/10**18:>14.6g} r1={v['r1']/10**18:>14.6g}")

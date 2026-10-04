#!/usr/bin/env python3
"""Sweep all addresses referenced in Alpaca BSC mainnet.json for token balances (read-only)."""
import json, urllib.request, time, os, re

RPC = os.environ.get("BSC_RPC", "https://bsc-rpc.publicnode.com")
BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "misc_custody_sweep.json")

TOKENS = {
    "ALPACA": "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F",
    "AUSD": "0xDCEcf0664C33321CECA2effcE701E710A2D28A3F",
    "WBNB": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    "USDT": "0x55d398326f99059fF775485246999027B3197955",
    "BUSD": "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
    "USDC": "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",
    "CAKE": "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
    "BTCB": "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c",
    "TUSD": "0x14016E85a25aeb13065688cAFB43044C2ef86784",
}
SEL_BAL = "0x70a08231"

def pad(x): return x.lower().replace("0x", "").rjust(64, "0")

def rpc_batch(calls, chunk=30):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc":"2.0","id":j,"method":"eth_call","params":[c,"latest"]} for j,c in enumerate(part)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        for a in range(4):
            try:
                res = json.loads(urllib.request.urlopen(req, timeout=60).read()); break
            except Exception:
                if a == 3: raise
                time.sleep(2)
        byid = {r["id"]: r for r in (res if isinstance(res, list) else [res])}
        out += [byid.get(j, {}).get("result") for j in range(len(part))]
    return out

raw = open("/tmp/opencode/alpaca/mainnet.json").read()
addrs = sorted(set(a.lower() for a in re.findall(r"0x[0-9a-fA-F]{40}", raw)))
# exclude plain tokens themselves
excl = set(v.lower() for v in TOKENS.values()) | {"0x0000000000000000000000000000000000000000"}
cands = [a for a in addrs if a not in excl]
print("candidate addresses:", len(cands))

calls = []
for a in cands:
    for t in TOKENS.values():
        calls.append({"to": t, "data": SEL_BAL + pad(a)})
res = rpc_batch(calls, chunk=40)
result = {"block": None, "addresses": {}}
req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
result["block"] = int(json.loads(urllib.request.urlopen(req, timeout=30).read())["result"], 16)
i = 0
for a in cands:
    bals = {}
    for tn in TOKENS:
        v = res[i]; i += 1
        if v and v != "0x" and int(v, 16) > 0:
            bals[tn] = int(v, 16)
    if bals:
        result["addresses"][a] = bals
with open(OUT, "w") as f: json.dump(result, f, indent=1)
prices = {"ALPACA":0.0007522552407593493,"AUSD":None,"WBNB":784.7398859811035,"USDT":0.9998832471688096,"BUSD":1.0004270080050397,"USDC":0.99988,"CAKE":2.5172510948746707,"BTCB":84568.95254276636,"TUSD":0.9996906802247123}
for a, bals in sorted(result["addresses"].items(), key=lambda kv: -sum((bals_v/1e18)*(prices[k] or 0) for k,bals_v in kv[1].items())):
    usd = sum((v/1e18)*(prices[k] or 0) for k,v in bals.items())
    if usd > 500:
        print(f"{a} ${usd:,.0f} " + " ".join(f"{k}={v/1e18:,.2f}" for k,v in bals.items()))
print("saved", OUT)

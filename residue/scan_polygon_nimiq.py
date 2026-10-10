#!/usr/bin/env python3
"""Nimiq H2-03 residue scan — Polygon (keyless public RPC).
Reads: token balances, allowances to HTLC handlers, handler balances, code presence.
Writes JSON to analysis/nimiq/polygon_state_<block>.json
"""
import json, urllib.request, sys, time

RPC = "https://polygon-bor-rpc.publicnode.com"

VICTIM   = "0x24Cb173Ae221AeA93369f34bdcF0Ddb35b436773"
H1       = "0x0cFD862bE942846Cebad797d7c1BC6e47714959b"  # ERC20PermitHTLCHandler (USDC)
H2       = "0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f"  # ERC20MetaHTLCHandler (USDT0/USDC.e)
RELAYHUB = "0x6C28AfC105e65782D9Ea6F2cA68df84C9e7d750d"
TOKENS = {
    "USDC":   "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
    "USDCe":  "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    "USDT":   "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
}
EXTRA_HANDLERS = {
    # possibly other Nimiq handlers (to be confirmed from source/registry)
    "H1": H1,
    "H2": H2,
}

def rpc(method, params):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                out = json.loads(r.read())
            if "error" in out:
                return {"__error__": out["error"]}
            return out["result"]
        except Exception as e:
            if attempt == 3:
                return {"__error__": str(e)}
            time.sleep(1.5)

def batch(calls):
    """calls: list of (to, data). Returns list of hex results."""
    payload = []
    for i,(to,data) in enumerate(calls):
        payload.append({"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to,"data":data},"latest"]})
    body = json.dumps(payload).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read())
            res = [None]*len(calls)
            for item in out:
                res[item["id"]] = item.get("result") if "error" not in item else {"__error__": item["error"]}
            return res
        except Exception as e:
            if attempt == 3:
                return [{"__error__": str(e)}]*len(calls)
            time.sleep(2)

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def enc_uint(n): return hex(n)[2:].rjust(64,"0")
def dec_uint(h): return int(h,16) if isinstance(h,str) and h.startswith("0x") and len(h)>2 else 0

# selectors
BAL   = "0x70a08231"  # balanceOf(address)
ALLOW = "0xdd62ed3e"  # allowance(address,address)
TOTALSUPPLY = "0x18160ddd"

block = rpc("eth_blockNumber", [])
print("polygon latest block:", int(block,16))

calls = []
meta = []
def add(to, data, label):
    calls.append((to,data)); meta.append(label)

for name, tok in TOKENS.items():
    add(tok, BAL + enc_addr(VICTIM), f"balanceOf({name}) victim")
for name, tok in TOKENS.items():
    for hname, h in EXTRA_HANDLERS.items():
        add(tok, ALLOW + enc_addr(VICTIM) + enc_addr(h), f"allowance(victim,{hname}) {name}")
for name, tok in TOKENS.items():
    for hname, h in EXTRA_HANDLERS.items():
        add(tok, BAL + enc_addr(h), f"balanceOf({hname}) {name}")
# total supply sanity
for name, tok in TOKENS.items():
    add(tok, TOTALSUPPLY, f"totalSupply {name}")

res = batch(calls)
out = {"block": int(block,16), "rpc": "<polygon-public>", "victim": VICTIM, "handlers": EXTRA_HANDLERS, "tokens": TOKENS, "reads": {}}
for m, r in zip(meta, res):
    out["reads"][m] = r

# code presence
for label, addr in [("handler1",H1),("handler2",H2),("relayhub",RELAYHUB),("victim",VICTIM)]:
    c = rpc("eth_getCode", [addr, "latest"])
    out[f"code_{label}"] = {"addr": addr, "size": (len(c)-2)//2 if isinstance(c,str) else None, "prefix": (c[:42] if isinstance(c,str) else str(c))}

for m in sorted(out["reads"]):
    r = out["reads"][m]
    if isinstance(r,str) and r.startswith("0x") and len(r)>2:
        out["reads"][m+" (dec)"] = dec_uint(r)
        print(f"{m:45s} = {dec_uint(r)}")
    else:
        print(f"{m:45s} = {r}")
print("code sizes:", {k:v["size"] for k,v in out.items() if k.startswith("code_")})

import os
os.makedirs(os.path.join(os.path.dirname(__file__),"analysis","nimiq"), exist_ok=True)
p = os.path.join(os.path.dirname(__file__),"analysis","nimiq",f"polygon_state_{out['block']}.json")
json.dump(out, open(p,"w"), indent=1)
print("saved", p)

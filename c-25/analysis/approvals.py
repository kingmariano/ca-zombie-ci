#!/usr/bin/env python3
"""Enumerate Approval events with spender = proxy (topic2), per token and globally."""
import json, time, urllib.request, os, sys

def load_env(path="/home/heisenberg/CA/.env"):
    d = {}
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        d[k.strip()] = v.strip().strip('"').strip("'")
    return d

KEY = os.environ.get("ETHERSCANV2_API_KEY") or load_env()["ETHERSCANV2_API_KEY"]
PROXY = "0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756"
PADDED = "0x" + "00" * 12 + PROXY[2:].lower()
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
BASE = "https://api.etherscan.io/v2/api"

def get(params, tries=3):
    url = BASE + "?" + "&".join(f"{k}={v}" for k, v in params.items()) + f"&apikey={KEY}"
    for a in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=45) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if a == tries - 1:
                return {"status": "0", "message": str(e), "result": []}
            time.sleep(2)

def logs(params):
    out = []
    page = 1
    while True:
        p = dict(params); p["page"] = page; p["offset"] = 1000
        o = get(p)
        res = o.get("result")
        if not isinstance(res, list):
            break
        out.extend(res)
        if len(res) < 1000 or page >= 10:
            break
        page += 1
        time.sleep(0.3)
    return out

# 1) global: all Approval events with spender=proxy, no address filter
glob = logs({"chainid": 1, "module": "logs", "action": "getLogs", "fromBlock": 0, "toBlock": "latest",
             "topic0": APPROVAL, "topic0_2_opr": "and", "topic2": PADDED})
print(f"global Approval(spender=proxy) logs: {len(glob)}")
tok_ev = {}
for e in glob:
    tok_ev.setdefault(e["address"].lower(), []).append(e)
print(f"tokens with approvals: {len(tok_ev)}")
json.dump({"global_logs": glob, "tokens": tok_ev},
          open("/home/heisenberg/CA/c-25/analysis/approvals_spender_proxy.json", "w"), indent=2)
for t, evs in sorted(tok_ev.items()):
    print(f"  token {t}: {len(evs)} events")

# also impls as spender
for impl in ["0x88eb28009351fb414a5746f5d8ca91cdc02760d8", "0x88099fcf6acdcf530607874452e7ef6fadcef2eb",
             "0x6831d0e09460e123f80219e0cdf11ffef99b89c1"]:
    pad = "0x" + "00" * 12 + impl[2:]
    g = logs({"chainid": 1, "module": "logs", "action": "getLogs", "fromBlock": 0, "toBlock": "latest",
              "topic0": APPROVAL, "topic0_2_opr": "and", "topic2": pad})
    print(f"Approval(spender={impl}) logs: {len(g)}")
    json.dump(g, open(f"/home/heisenberg/CA/c-25/analysis/approvals_spender_{impl[:10]}.json", "w"), indent=2)

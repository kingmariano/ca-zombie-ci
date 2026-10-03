#!/usr/bin/env python3
"""Fetch verified source for every live Socket Gateway route impl + controller (Ethereum).
Read-only Etherscan API. Writes analysis/socket_impls/<addr>_<name>.sol and socket_impls.json
"""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV["ETHERSCANV2_API_KEY"]
UA = {"User-Agent": "zombie-hunt/read-only"}

scan = json.load(open(os.path.join(HERE, "socket_routes_26108903.json")))
addrs = sorted(set(scan["live_route_impls"] + scan["live_controller_impls"]))
print("impls to fetch:", len(addrs))
outdir = os.path.join(HERE, "socket_impls")
os.makedirs(outdir, exist_ok=True)
meta = {}
for a in addrs:
    url = ("https://api.etherscan.io/v2/api?chainid=1&module=contract&action=getsourcecode"
           f"&address={a}&apikey={KEY}")
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.load(r)
        res = d.get("result")
        r0 = res[0] if isinstance(res, list) else res
        name = r0.get("ContractName") if isinstance(r0, dict) else None
        src = r0.get("SourceCode") if isinstance(r0, dict) else ""
        proxy = r0.get("Proxy") if isinstance(r0, dict) else None
        impl = r0.get("Implementation") if isinstance(r0, dict) else None
        meta[a] = {"name": name, "proxy": proxy, "implementation": impl, "srclen": len(src or "")}
        if src:
            open(os.path.join(outdir, f"{a}_{name}.json"), "w").write(src)
        print(a, name, "proxy", proxy, "srclen", len(src or ""))
    except Exception as e:
        meta[a] = {"error": str(e)[:120]}
        print(a, "ERR", e)
    time.sleep(0.3)
json.dump(meta, open(os.path.join(HERE, "socket_impls.json"), "w"), indent=1)

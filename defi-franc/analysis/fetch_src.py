#!/usr/bin/env python3
"""Fetch verified sources for a list of addresses from Etherscan V2 (no keys printed)."""
import json, os, sys, urllib.request, urllib.parse, time

KEY = os.environ["ETHERSCANV2_API_KEY"]
OUT = "/home/heisenberg/CA/defi-franc/analysis/src"
ADDRS = sys.argv[1:]

def fetch(addr):
    q = urllib.parse.urlencode({
        "chainid": 1, "module": "contract", "action": "getsourcecode",
        "address": addr, "apikey": KEY})
    with urllib.request.urlopen("https://api.etherscan.io/v2/api?" + q, timeout=30) as r:
        return json.load(r)

for addr in ADDRS:
    try:
        d = fetch(addr)
        r = d["result"][0]
        name = r["ContractName"] or "UNKNOWN"
        src = r["SourceCode"] or ""
        if not src:
            print(addr, "NO SOURCE", "proxy=", r.get("Proxy"), "impl=", r.get("Implementation"))
            continue
        dstdir = os.path.join(OUT, addr)
        os.makedirs(dstdir, exist_ok=True)
        if src.startswith("{{"):
            j = json.loads(src[1:-1])
            for p, c in j.get("sources", {}).items():
                open(os.path.join(dstdir, p.replace("/", "__")), "w").write(c.get("content", ""))
            print(addr, name, len(j.get("sources", {})), "files")
        else:
            open(os.path.join(dstdir, name + ".sol"), "w").write(src)
            print(addr, name, "single")
        # also save metadata
        meta = {k: r.get(k) for k in ("ContractName", "CompilerVersion", "Proxy", "Implementation", "OptimizationUsed", "EVMVersion")}
        json.dump(meta, open(os.path.join(dstdir, "_meta.json"), "w"), indent=1)
    except Exception as e:
        print(addr, "ERROR", e)
    time.sleep(0.25)

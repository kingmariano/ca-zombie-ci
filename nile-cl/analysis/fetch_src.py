#!/usr/bin/env python3
"""Fetch verified sources from Etherscan V2 (Linea) and unpack into per-contract dirs.
Usage: python3 fetch_src.py <addr> [<addr> ...]
Env: ETHERSCANV2_API_KEY (never printed/written)."""
import json, os, sys, urllib.request

KEY = os.environ["ETHERSCANV2_API_KEY"]
OUT = os.path.dirname(os.path.abspath(__file__)) + "/src_files"
os.makedirs(OUT, exist_ok=True)

def get(addr):
    url = (f"https://api.etherscan.io/v2/api?chainid=59144&module=contract"
           f"&action=getsourcecode&address={addr}&apikey={KEY}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

for addr in sys.argv[1:]:
    d = get(addr)
    res = d.get("result") or []
    if not res:
        print(addr, "ERR", json.dumps(d)[:200])
        continue
    x = res[0]
    name = x.get("ContractName") or "unknown"
    sc = (x.get("SourceCode") or "").strip()
    base = f"{OUT}/{addr}_{name}"
    os.makedirs(base, exist_ok=True)
    open(f"{base}/abi.json", "w").write(x.get("ABI") or "[]")
    open(f"{base}/compiler.txt", "w").write(x.get("CompilerVersion") or "")
    # slot/link refs
    if sc.startswith("{{"):
        sc = sc[1:-1]
    if sc.startswith("{"):
        try:
            j = json.loads(sc)
            for f, v in j["sources"].items():
                p = f"{base}/" + f.replace("@", "AT_").replace("/", "__")
                open(p, "w").write(v["content"])
            print(addr, name, x.get("CompilerVersion"), "json-unpacked",
                  len(j["sources"]), "files")
            continue
        except Exception as e:
            print(addr, name, "json parse fail:", e)
    open(f"{base}/source.sol", "w").write(sc)
    print(addr, name, x.get("CompilerVersion"), "raw", len(sc))

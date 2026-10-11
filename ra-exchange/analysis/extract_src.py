#!/usr/bin/env python3
"""Extract standard-json sources from Etherscan V2 getsourcecode JSON dumps (case-insensitive)."""
import json, os, sys, glob

SRC = "/home/heisenberg/CA/ra-exchange/analysis/src"
OUT = "/home/heisenberg/CA/ra-exchange/analysis/decompiled"
os.makedirs(OUT, exist_ok=True)

def extract(addr):
    addr = addr.lower()
    matches = [f for f in glob.glob(SRC + "/*.json") if os.path.basename(f).lower().startswith(addr)]
    if not matches:
        print(addr, "no file"); return
    d = json.load(open(matches[0]))
    r = d.get("result")
    if not isinstance(r, list) or not r:
        print(addr, "no result"); return
    r0 = r[0]
    name = r0.get("ContractName") or "unnamed"
    sc = r0.get("SourceCode") or ""
    odir = os.path.join(OUT, f"{addr}_{name}")
    os.makedirs(odir, exist_ok=True)
    meta = {k: r0.get(k) for k in ("ContractName","CompilerVersion","OptimizationUsed","Runs","EVMVersion","Proxy","Implementation","ConstructorArguments")}
    json.dump(meta, open(os.path.join(odir, "_meta.json"), "w"), indent=1)
    if sc.startswith("{{"):
        sc = sc[1:-1]
    if sc.strip().startswith("{"):
        j = json.loads(sc)
        for path, body in j.get("sources", {}).items():
            open(os.path.join(odir, path.replace("/", "__")), "w").write(body.get("content", ""))
        print(f"{addr} {name}: {len(j.get('sources', {}))} sources")
    else:
        open(os.path.join(odir, "source.sol"), "w").write(sc)
        print(f"{addr} {name}: plain {len(sc)}")

if __name__ == "__main__":
    for a in sys.argv[1:]:
        extract(a)

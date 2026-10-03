#!/usr/bin/env python3
"""Extract multi-file Etherscan source bundles into per-contract dirs."""
import json, os, re, sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sources")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")

for fn in sorted(os.listdir(SRC)):
    if not fn.endswith(".json") or fn.startswith("abi"):
        continue
    label = fn.rsplit("_", 1)[0]
    cid = fn.rsplit("_", 1)[1].split(".")[0]
    d = json.load(open(os.path.join(SRC, fn)))
    r = d.get("result")
    if not (isinstance(r, list) and r):
        continue
    x = r[0]
    raw = x.get("SourceCode", "")
    outdir = os.path.join(OUT, f"{label}_{cid}")
    os.makedirs(outdir, exist_ok=True)
    files = {}
    if raw.startswith("{{"):
        try:
            bundle = json.loads(raw[1:-1])
            files = {k: v.get("content", "") for k, v in bundle.get("sources", {}).items()}
        except Exception as e:
            print(f"{fn}: parse error {e}")
            continue
    elif raw.startswith("{"):
        try:
            bundle = json.loads(raw)
            files = {k: v.get("content", "") for k, v in bundle.get("sources", {}).items()}
        except Exception:
            files = {"contract.sol": raw}
    else:
        files = {"contract.sol": raw}
    for k, v in files.items():
        safe = k.replace("/", "_").replace("@", "at_")
        with open(os.path.join(outdir, safe), "w") as f:
            f.write(v)
    print(f"{label}_{cid}: {x.get('ContractName')} -> {len(files)} files: {', '.join(files.keys())}")

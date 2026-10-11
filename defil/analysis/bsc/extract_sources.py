#!/usr/bin/env python3
"""Extract flattened/solidity sources from cached Etherscan V2 JSON responses into .sol files."""
import json, os, glob, re

os.makedirs("src/extracted", exist_ok=True)

for f in sorted(glob.glob("src/*.json")):
    base = os.path.basename(f)[:-5]
    try:
        d = json.load(open(f))
    except Exception as e:
        print("skip", f, e); continue
    r = d.get("result")
    if not isinstance(r, list) or not r:
        continue
    r = r[0]
    src = r.get("SourceCode") or ""
    name = r.get("ContractName") or "unknown"
    if not src.strip():
        print(base, "-> UNVERIFIED")
        continue
    out = f"src/extracted/{name}_{base.split('_')[-1]}.sol"
    if src.startswith("{{"):
        # multi-file JSON
        try:
            obj = json.loads(src[1:-1] if src.startswith("{{") else src)
            files = obj.get("sources", {})
            with open(out, "w") as fh:
                for fname, fobj in files.items():
                    fh.write(f"// ===== FILE: {fname} =====\n")
                    fh.write(fobj.get("content", "") + "\n")
            print(base, "->", name, f"multi-file {len(files)} files ->", out)
        except Exception as e:
            print(base, "multi-file parse err", e)
    else:
        txt = src
        if txt.startswith("{"):
            try:
                obj = json.loads(txt)
                txt = obj.get("content", txt)
            except Exception:
                pass
        with open(out, "w") as fh:
            fh.write(re.sub(r"^\s*// (SPDX|Submitted).*$", "", txt, flags=re.M))
        print(base, "->", name, "->", out, len(txt), "chars")

#!/usr/bin/env python3
"""Extract SourceCode blobs from nest_src/*.json into nest_src_extracted/<label>/<file>.
Handles Etherscan double-braced JSON, standard JSON, and single-file sources.
Also writes an index.json with label -> contract name -> files.
"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "nest_src")
OUT = os.path.join(HERE, "nest_src_extracted")
os.makedirs(OUT, exist_ok=True)

def parse_source_code(sc):
    """Return (sources_dict, settings) from an Etherscan SourceCode string."""
    if not sc:
        return {}, {}
    s = sc.strip()
    # Etherscan sometimes double-wraps: {{...}}
    for attempt in range(3):
        try:
            d = json.loads(s)
            if isinstance(d, dict) and "sources" in d:
                return d.get("sources", {}), d.get("settings", {})
            if isinstance(d, str):
                s = d.strip()
                continue
            return {}, {}
        except Exception:
            if s.startswith("{") and s.endswith("}") and attempt == 0:
                s = s[1:-1].strip()
                continue
            break
    # single-file solidity (non-JSON SourceCode)
    return {"__single__": {"content": sc}}, {}


index = {}
for fn in sorted(os.listdir(SRC)):
    if not fn.endswith(".json") or fn.startswith("_"):
        continue
    path = os.path.join(SRC, fn)
    try:
        d = json.load(open(path))
    except Exception as e:
        print("skip(bad json)", fn, e)
        continue
    res = d.get("result")
    if isinstance(res, list) and res:
        r0 = res[0]
    elif isinstance(res, dict):
        r0 = res
    else:
        continue
    if not isinstance(r0, dict):
        continue
    label = fn.split("__")[0]
    addr = fn.split("__")[1][:-5] if "__" in fn else ""
    sources, settings = parse_source_code(r0.get("SourceCode") or "")
    cname = r0.get("ContractName") or ""
    compiler = r0.get("CompilerVersion") or ""
    # output dir
    od = os.path.join(OUT, label)
    os.makedirs(od, exist_ok=True)
    files = []
    for spath, content in sources.items():
        if isinstance(content, dict):
            text = content.get("content", "")
        else:
            text = str(content)
        safe = spath.replace("/", "__").replace("\\", "__")
        if safe == "__single__":
            safe = (cname or "single") + ".sol"
            if not safe.endswith(".sol"):
                safe += ".sol"
        open(os.path.join(od, safe), "w", errors="replace").write(text)
        files.append(safe)
    # contract-level JSON presence
    if r0.get("ABI") and r0.get("ABI") != "Contract source code not verified":
        open(os.path.join(od, "_abi.json"), "w").write(r0["ABI"])
    index[label] = {"address": addr, "name": cname, "compiler": compiler,
                    "verified": bool(r0.get("SourceCode")), "files": files,
                    "single": "__single__" in sources,
                    "n_files": len(files)}
    print(f"{label:42s} {cname:45s} files={len(files)}")

json.dump(index, open(os.path.join(OUT, "_index.json"), "w"), indent=1)
print("done", len(index))
